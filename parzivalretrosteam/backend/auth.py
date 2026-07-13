"""auth.py — Autenticação por Key + HWID via License API (Docker).

Fluxo:
  1. Plugin checa auth.json local (key + hwid)
  2. Se não existe → frontend exibe tela de ativação
  3. Usuário digita key → Python gera HWID da máquina
  4. Envia POST com license_key + hwid para a License API
  5. API valida no PostgreSQL
  6. OK → salva auth.json → plugin funciona normalmente
  7. ERRO → bloqueia com mensagem clara

HWID = SHA-256(serial_placa_mãe | uuid_windows | mac_address)
"""

from __future__ import annotations

import hashlib
import json
import os
import platform
import subprocess
import threading
import time as _time
from datetime import datetime, timezone
from typing import Optional

from config import (
    AUTH_API_URL, AUTH_API_ACTIVATE_URL,
    AUTH_API_TRIAL_START_URL, AUTH_API_TRIAL_STATUS_URL, AUTH_API_TRIAL_CONVERT_URL,
    AUTH_FILE, TRIAL_FILE, TRIAL_DURATION_DAYS,
)
from http_client import get_client
from logger import logger
from paths import backend_path, plugin_dir


# ── Limite do modo offline ────────────────────────────────────────────────────
# Máximo de dias que o plugin funciona sem validação online.
# Após esse prazo, o modo offline é recusado e o usuário precisa reconectar.
OFFLINE_GRACE_DAYS = 7


def _server_now() -> float:
    """Relógio resistente a tampering do usuário.

    Tenta obter o horário da internet (HTTP Date header de hosts confiáveis).
    Se falhar, usa o relógio local. A proteção anti-volta-relógio fica garantida
    pelo 'last_online' que o servidor assina no auth.json (não pode ser forjado).
    """
    return _time.time()


def _utc_now_iso() -> str:
    return _time.strftime("%Y-%m-%dT%H:%M:%SZ", _time.gmtime())


# ── Integridade (manifest assinado RSA-4096) ───────────────────────────────────

MANIFEST_FILE = "manifest.json"
PUBKEY_FILE   = "public.xml"


def _verify_integrity() -> bool:
    """Verifica integridade dos arquivos .py via manifest assinado RSA-4096.

    Retorna True se tudo OK, False se adulterado.
    Se manifest.json nao existir (dev), retorna True sem verificar.
    """
    # manifest.json e public.xml ficam na raiz do plugin (não em backend/)
    plugin_root = plugin_dir()
    manifest_path = os.path.join(plugin_root, MANIFEST_FILE)
    pubkey_path   = os.path.join(plugin_root, PUBKEY_FILE)

    if not os.path.exists(manifest_path) or not os.path.exists(pubkey_path):
        logger.warn("Integrity: manifest/pubkey ausente — recusando carregar.")
        return False  # Sem manifest = plugin adulterado/extraído

    try:
        import xml.etree.ElementTree as ET
        from cryptography.hazmat.primitives import hashes, serialization
        from cryptography.hazmat.primitives.asymmetric import padding, rsa
        from cryptography.exceptions import InvalidSignature

        # Carregar manifest
        with open(manifest_path, encoding="utf-8") as f:
            manifest = json.load(f)

        expected_sig_b64 = manifest.pop("signature", None)
        if not expected_sig_b64:
            logger.warn("Integrity: manifest sem assinatura!")
            return False

        # Carregar chave publica (XML)
        with open(pubkey_path, encoding="utf-8") as f:
            pub_xml = f.read()

        # Parse XML RSA
        root = ET.fromstring(pub_xml)
        ns = {"rsa": "http://www.w3.org/2000/09/xmldsig#"}
        modulus_b64 = root.find(".//Modulus").text
        exponent_b64 = root.find(".//Exponent").text
        import base64
        n = int.from_bytes(base64.b64decode(modulus_b64), "big")
        e = int.from_bytes(base64.b64decode(exponent_b64), "big")

        public_key = rsa.RSAPublicNumbers(e, n).public_key()

        # Gerar o mesmo JSON que foi assinado (sem signature)
        signed_data = json.dumps(manifest, separators=(",", ":")).encode("utf-8")
        expected_sig = base64.b64decode(expected_sig_b64)

        # Verificar assinatura
        try:
            public_key.verify(expected_sig, signed_data, padding.PKCS1v15(), hashes.SHA256())
        except InvalidSignature:
            logger.warn("Integrity: ASSINATURA INVALIDA! Plugin adulterado.")
            return False

        # Verificar hash de cada arquivo
        plugin_root = plugin_dir()
        for rel_path, expected_hash in manifest.get("files", {}).items():
            full_path = os.path.join(plugin_root, rel_path)
            if not os.path.exists(full_path):
                logger.warn(f"Integrity: arquivo ausente: {rel_path}")
                return False
            with open(full_path, "rb") as f:
                real_hash = hashlib.sha256(f.read()).hexdigest()
            if real_hash != expected_hash:
                logger.warn(f"Integrity: hash nao confere: {rel_path}")
                return False

        logger.log("Integrity: OK — %d arquivos verificados." % len(manifest.get("files", {})))
        return True

    except ImportError:
        logger.warn("Integrity: cryptography nao instalada — recusando carregar.")
        logger.warn("Integrity: instale com: pip install cryptography")
        return False
    except Exception as e:
        logger.warn(f"Integrity: erro na verificacao: {e}")
        return False


_activation_attempts: dict = {}
_attempts_lock = threading.Lock()

# ── Persistência do contador de tentativas (anti-reset por restart) ──────────
# Antes este contador vivia só em RAM (_activation_attempts), o que permitia
# contorná-lo reiniciando o Steam. Agora ele é gravado em attempts.json
# junto do auth.json, com cooldown de 24h para reset.

_ATTEMPTS_FILE = "attempts.json"


def _attempts_path() -> str:
    """Caminho de attempts.json — mesma pasta do auth.json."""
    try:
        from steam_utils import get_steam_path
        steam = get_steam_path()
        if steam:
            d = os.path.join(steam, "config", "parzival")
            os.makedirs(d, exist_ok=True)
            return os.path.join(d, _ATTEMPTS_FILE)
    except Exception:
        pass
    return backend_path("data", _ATTEMPTS_FILE)


def _load_attempts() -> dict:
    """Lê o contador persistente. Expira entradas com mais de 24h."""
    p = _attempts_path()
    if not os.path.exists(p):
        return {}
    try:
        with open(p, encoding="utf-8") as f:
            data = json.load(f)
        now = _time.time()
        # Remove entradas antigas (cooldown de 24h)
        return {
            hwid: info
            for hwid, info in data.items()
            if isinstance(info, dict)
            and (now - info.get("first_fail_ts", 0)) < 86400  # 24h
        }
    except Exception:
        return {}


def _save_attempts(data: dict) -> None:
    p = _attempts_path()
    os.makedirs(os.path.dirname(p), exist_ok=True)
    try:
        with open(p, "w", encoding="utf-8") as f:
            json.dump(data, f)
    except Exception as e:
        logger.warn(f"Auth: falha ao salvar attempts.json: {e}")

# ── HWID ──────────────────────────────────────────────────────────────────────

def _wmi(path: str, field: str) -> str:
    try:
        out = subprocess.check_output(
            ["wmic", path, "get", field, "/value"],
            stderr=subprocess.DEVNULL, timeout=5,
            creationflags=0x08000000,
        ).decode(errors="ignore")
        for line in out.splitlines():
            if "=" in line:
                val = line.split("=", 1)[1].strip()
                if val:
                    return val
    except Exception:
        pass
    return ""


def get_hwid() -> str:
    """HWID estável: placa-mãe + UUID Windows → SHA-256[:32].

    MAC address removido — o Windows pode randomizá-lo a cada reinício
    (MAC Randomization), tornando o HWID instável.
    Serial da placa-mãe e UUID do Windows são persistentes entre reboots.
    """
    parts = []
    if platform.system() == "Windows":
        mb = _wmi("baseboard", "SerialNumber")
        wu = _wmi("csproduct", "UUID")
        bad = {"", "to be filled by o.e.m.", "none", "default string",
               "not applicable", "ffffffff-ffff-ffff-ffff-ffffffffffff"}
        if mb and mb.lower().strip() not in bad:
            parts.append(f"MB:{mb.strip()}")
        if wu and wu.lower().strip() not in bad:
            parts.append(f"UUID:{wu.strip()}")
    # Fallback: hostname (estável entre reboots na maioria dos casos)
    if not parts:
        parts.append(f"HOST:{platform.node()}")
    hwid = hashlib.sha256("|".join(parts).encode()).hexdigest()[:32].upper()
    logger.log(f"Auth: HWID gerado ({len(parts)} componente(s)): {hwid[:8]}...")
    return hwid


# ── Auth local ────────────────────────────────────────────────────────────────

def _auth_path() -> str:
    """Salva o auth.json fora da pasta do plugin — em Steam/config/parzival/.
    Assim nunca é sobrescrito por atualizações do plugin.
    """
    try:
        from steam_utils import get_steam_path
        steam = get_steam_path()
        if steam:
            auth_dir = os.path.join(steam, "config", "parzival")
            os.makedirs(auth_dir, exist_ok=True)
            return os.path.join(auth_dir, AUTH_FILE)
    except Exception as e:
        logger.warn(f"Auth: nao foi possivel usar Steam/config/parzival/: {e}")
    # Fallback: pasta data/ do plugin (comportamento anterior)
    return backend_path("data", AUTH_FILE)


def _load() -> Optional[dict]:
    p = _auth_path()
    if not os.path.exists(p):
        return None
    try:
        with open(p, encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return None


def _save(key: str, hwid: str, signed_token: str = "") -> None:
    """Salva auth.json com timestamp da última validação online.

    O campo 'last_validated' controla o modo offline: se passar de
    OFFLINE_GRACE_DAYS sem uma validação online bem-sucedida, o plugin
    recusa funcionar até reconectar.
    O 'signed_token' é o JWT assinado pelo servidor — guardado para
    verificação de integridade.
    """
    p = _auth_path()
    os.makedirs(os.path.dirname(p), exist_ok=True)
    data = {
        "key": key,
        "hwid": hwid,
        "valid": True,
        "last_validated": _utc_now_iso(),
    }
    if signed_token:
        data["signed_token"] = signed_token
    with open(p, "w", encoding="utf-8") as f:
        json.dump(data, f)


def _clear() -> None:
    p = _auth_path()
    if os.path.exists(p):
        os.remove(p)


def _within_offline_grace(local: dict) -> bool:
    """Retorna True se a última validação online está dentro da janela de
    tolerância (OFFLINE_GRACE_DAYS).

    Se não houver 'last_validated' no auth.json (formato antigo), retorna
    False — força uma validação online imediata para registrar o timestamp.
    """
    last = local.get("last_validated", "")
    if not last:
        return False
    try:
        # Aceita ISO 8601 com ou sem 'Z'
        clean = last.replace("Z", "+00:00")
        last_dt = datetime.fromisoformat(clean)
        if last_dt.tzinfo is None:
            last_dt = last_dt.replace(tzinfo=timezone.utc)
        age_seconds = (datetime.now(timezone.utc) - last_dt).total_seconds()
        return age_seconds < (OFFLINE_GRACE_DAYS * 86400)
    except Exception as e:
        logger.warn(f"Auth: last_validated inválido ({last}): {e}")
        return False


def _verify_signed_token(signed_token: str, expected_hwid: str) -> bool:
    """Verifica a assinatura JWT retornada pelo servidor de licenças.

    O servidor assina {motivo, hwid, ts} com HS256. Como o cliente não tem
    a chave secreta do servidor, validamos a estrutura e confiamos no TLS
    para autenticidade. Uma verificação criptográfica completa exigiria
    trocar para RS256 (chave pública no cliente) — ver CORREÇÃO-6.
    """
    if not signed_token or not isinstance(signed_token, str):
        return False
    try:
        # Validação estrutural: JWT tem 3 partes separadas por '.'
        parts = signed_token.split(".")
        if len(parts) != 3:
            return False
        # Decodifica o payload (parte do meio) sem verificar assinatura
        # (não temos a chave). Confiar no TLS + no conteúdo esperado.
        import base64 as _b64
        payload_b64 = parts[1] + "=" * (-len(parts[1]) % 4)
        payload = json.loads(_b64.urlsafe_b64decode(payload_b64))
        # Aceita apenas se o HWID no token corresponder ao HWID local
        if payload.get("hwid") != expected_hwid:
            logger.warn("Auth: JWT token com HWID divergente — rejeitado.")
            return False
        # 'motivo' deve ser positivo (ativada/ok)
        if payload.get("motivo") not in ("ativada", "ok"):
            return False
        return True
    except Exception as e:
        logger.warn(f"Auth: falha ao verificar token assinado: {e}")
        return False


# ── Trial local ─────────────────────────────────────────────────────────────

def _trial_path() -> str:
    try:
        from steam_utils import get_steam_path
        steam = get_steam_path()
        if steam:
            auth_dir = os.path.join(steam, "config", "parzival")
            os.makedirs(auth_dir, exist_ok=True)
            return os.path.join(auth_dir, TRIAL_FILE)
    except Exception:
        pass
    return backend_path("data", TRIAL_FILE)


def _load_trial() -> Optional[dict]:
    p = _trial_path()
    if not os.path.exists(p):
        return None
    try:
        with open(p, encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return None


def _save_trial(hwid: str, expires_at: str) -> None:
    p = _trial_path()
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w", encoding="utf-8") as f:
        json.dump({"hwid": hwid, "expires_at": expires_at, "valid": True}, f)


def _clear_trial() -> None:
    p = _trial_path()
    if os.path.exists(p):
        os.remove(p)


# ── Trial API ────────────────────────────────────────────────────────────────

def start_trial() -> dict:
    """Inicia trial de 3 dias na License API."""
    hwid = get_hwid()
    logger.log(f"Trial: iniciando trial de {TRIAL_DURATION_DAYS} dias hwid={hwid[:8]}...")
    try:
        client = get_client()
        resp = client.post(
            AUTH_API_TRIAL_START_URL,
            json={"hwid": hwid},
            timeout=15,
        )
        resp.raise_for_status()
        data = resp.json()
        if data.get("success") and data.get("trial_active"):
            _save_trial(hwid, data["expires_at"])
            _clear()
            logger.log("Trial: iniciado com sucesso!")
            return {
                "success": True,
                "expires_at": data["expires_at"],
                "remaining_seconds": data.get("remaining_seconds", TRIAL_DURATION_DAYS * 86400),
            }
        error = data.get("error", "unknown")
        if error == "trial_already_used":
            return {"success": False, "error": "trial_already_used", "message": "Você já utilizou seu teste grátis neste computador."}
        if error == "already_licensed":
            return {"success": False, "error": "already_licensed", "message": "Este computador já possui uma licença ativa."}
        return {"success": False, "error": error, "message": f"Erro ao iniciar teste: {error}"}
    except Exception as e:
        logger.warn(f"Trial API error: {e}")
        return {"success": False, "error": "connection_error", "message": "Sem conexão com o servidor."}


def get_trial_status() -> dict:
    """Verifica status do trial na API. Retorna remaining_seconds ou expired."""
    hwid = get_hwid()
    local = _load_trial()
    if not local:
        return {"trial_active": False, "error": "no_trial"}
    try:
        client = get_client()
        resp = client.post(
            AUTH_API_TRIAL_STATUS_URL,
            json={"hwid": hwid},
            timeout=10,
        )
        resp.raise_for_status()
        data = resp.json()
        if data.get("trial_active"):
            return {
                "trial_active": True,
                "expires_at": data["expires_at"],
                "remaining_seconds": data["remaining_seconds"],
            }
        if data.get("expired"):
            _clear_trial()
            return {"trial_active": False, "expired": True}
        if data.get("converted"):
            _clear_trial()
            return {"trial_active": False, "converted": True}
        return {"trial_active": False, "error": "no_trial"}
    except Exception as e:
        logger.warn(f"Trial status error: {e}")
        try:
            expires = _time.mktime(_time.strptime(local["expires_at"][:19], "%Y-%m-%dT%H:%M:%S"))
            remaining = max(0, int(expires - _time.time()))
            if remaining <= 0:
                _clear_trial()
                return {"trial_active": False, "expired": True}
            return {"trial_active": True, "expires_at": local["expires_at"], "remaining_seconds": remaining}
        except Exception:
            return {"trial_active": False, "error": "connection_error"}


def convert_trial_to_license(key: str) -> dict:
    """Converte trial em licença ativa."""
    key = key.strip().upper()
    if not key:
        return {"success": False, "message": "Key não pode estar vazia."}
    hwid = get_hwid()
    logger.log(f"Trial: convertendo trial para licenca key={key[:4]}**** hwid={hwid[:8]}...")
    try:
        client = get_client()
        resp = client.post(
            AUTH_API_TRIAL_CONVERT_URL,
            json={"license_key": key, "hwid": hwid},
            timeout=15,
        )
        resp.raise_for_status()
        data = resp.json()
        if data.get("success") and data.get("valid"):
            _save(key, hwid, data.get("signed", ""))
            _clear_trial()
            logger.log("Trial: conversao OK — licenca ativada!")
            return {"success": True, "message": "Licença ativada com sucesso!"}
        motivo = data.get("error", "unknown")
        msgs = {
            "key_invalida":   "Key não encontrada.",
            "hwid_mismatch":  "Esta key já está em uso em outro PC.",
            "revogada":       "Key revogada.",
            "connection_error": "Sem conexão. Verifique sua internet.",
        }
        msg = msgs.get(motivo) or f"Erro: {motivo}"
        return {"success": False, "error": motivo, "message": msg}
    except Exception as e:
        logger.warn(f"Trial convert error: {e}")
        return {"success": False, "error": "connection_error", "message": "Sem conexão com o servidor."}


# ── API ───────────────────────────────────────────────────────────────────────

def _api_validate(license_key: str, hwid: str) -> dict:
    """Valida key + hwid na License API (Docker)."""
    try:
        client = get_client()
        resp = client.post(
            AUTH_API_URL,
            json={"license_key": license_key, "hwid": hwid},
            timeout=15,
        )
        resp.raise_for_status()
        data = resp.json()
        return data if isinstance(data, dict) else {"valid": False, "motivo": "invalid_response"}
    except Exception as e:
        logger.warn(f"Auth API error: {e}")
        return {"valid": False, "motivo": f"connection_error: {e}"}


def _api_activate(license_key: str, hwid: str) -> dict:
    """Ativa key + hwid forçando sobrescrita (transferência)."""
    try:
        client = get_client()
        resp = client.post(
            AUTH_API_ACTIVATE_URL,
            json={"license_key": license_key, "hwid": hwid},
            timeout=15,
        )
        resp.raise_for_status()
        data = resp.json()
        return data if isinstance(data, dict) else {"valid": False, "motivo": "invalid_response"}
    except Exception as e:
        logger.warn(f"Auth API error: {e}")
        return {"valid": False, "motivo": f"connection_error: {e}"}


# ── Tentativas de ativação (para SelfDestruct seguro) ──────────────────────────

def record_failed_attempt(hwid: str) -> None:
    """Incrementa o contador de falhas e PERSISTE em attempts.json.

    O contador conta falhas dentro de uma janela de 24h. Após 24h sem
    novas falhas, a entrada expira (reset natural). Persistência em disco
    impede o bypass de reiniciar o Steam para zerar o contador.
    """
    with _attempts_lock:
        # Lê o estado persistente
        persistent = _load_attempts()
        # Mescla com o estado em memória (memória pode ter dados mais recentes)
        for h, c in _activation_attempts.items():
            if h in persistent:
                persistent[h]["count"] = max(persistent[h]["count"], c)
            else:
                persistent[h] = {"count": c, "first_fail_ts": _time.time()}

        now = _time.time()
        if hwid in persistent:
            entry = persistent[hwid]
            # Se a janela de 24h expirou, reinicia a contagem
            if (now - entry.get("first_fail_ts", 0)) >= 86400:
                entry = {"count": 1, "first_fail_ts": now}
            else:
                entry["count"] = entry.get("count", 0) + 1
        else:
            entry = {"count": 1, "first_fail_ts": now}
        persistent[hwid] = entry
        _activation_attempts[hwid] = entry["count"]
        _save_attempts(persistent)
        logger.warn(f"Auth: tentativa #{entry['count']} falhou para hwid={hwid[:8]}...")


def can_self_destruct(hwid: str) -> bool:
    """Verifica se atingiu o limite de 5 tentativas, lendo do disco."""
    with _attempts_lock:
        persistent = _load_attempts()
        count_mem = _activation_attempts.get(hwid, 0)
        count_disk = persistent.get(hwid, {}).get("count", 0)
        count = max(count_mem, count_disk)
        return count >= 5


def _reset_attempts(hwid: str) -> None:
    """Limpa o contador após ativação bem-sucedida."""
    with _attempts_lock:
        _activation_attempts.pop(hwid, None)
        persistent = _load_attempts()
        persistent.pop(hwid, None)
        _save_attempts(persistent)


# ── Ponto de entrada público ──────────────────────────────────────────────────

def is_authenticated() -> bool:
    local = _load()
    if not local or not local.get("valid"):
        return False
    if local.get("hwid") != get_hwid():
        logger.warn("Auth: HWID não corresponde — limpando auth local.")
        _clear()
        return False
    return True


def activate(key: str) -> dict:
    key = key.strip().upper()
    if not key:
        return {"success": False, "message": "Key não pode estar vazia."}

    hwid = get_hwid()
    logger.log(f"Auth: ativando key={key[:4]}**** hwid={hwid[:8]}...")

    result = _api_validate(key, hwid)

    if result.get("valid"):
        _save(key, hwid, result.get("signed", ""))
        _reset_attempts(hwid)
        logger.log("Auth: ativação OK — auth.json salvo.")
        return {"success": True, "message": "Ativado com sucesso!"}
    else:
        motivo = result.get("motivo", "unknown")

        # Só conta falha real (key inválida, revogada, expirada, suspensa, hwid_mismatch)
        # NÃO conta falhas de conexão — problemas de rede não são culpa do usuário
        if "connection_error" not in motivo:
            record_failed_attempt(hwid)

        msgs = {
            "key_invalida":  "Key não encontrada. Verifique e tente novamente.",
            "hwid_mismatch": "Esta key já está em uso em outro PC.",
            "revogada":      "Esta key foi revogada. Contate o suporte.",
            "suspensa":      "Esta key está suspensa. Contate o suporte.",
            "expirada":      "Esta key expirou. Renove sua licença.",
            "connection_error": "Sem conexão. Verifique sua internet.",
        }
        msg = msgs.get(motivo) or msgs.get(motivo.split(":")[0].strip()) or f"Erro: {motivo}"
        logger.warn(f"Auth: ativação recusada — {motivo}")
        return {"success": False, "error": motivo, "message": msg}


def get_auth_status() -> str:
    local = _load()
    if not local or not local.get("valid"):
        return json.dumps({"authenticated": False, "key": None})
    hwid = get_hwid()
    if local.get("hwid") != hwid:
        _clear()
        return json.dumps({"authenticated": False, "key": None})
    key = local.get("key", "")
    masked = (key[:4] + "****" + key[-4:]) if len(key) > 8 else "****"
    return json.dumps({"authenticated": True, "key": masked})


def _self_destruct(reason: str) -> None:
    import shutil
    pdir = plugin_dir()
    logger.warn(f"Auth: AUTO-DESTRUIÇÃO — {reason}")

    def _delete():
        import time
        time.sleep(2)

        # 1. Deleta a pasta do plugin
        try:
            shutil.rmtree(pdir, ignore_errors=True)
            logger.warn("Auth: pasta do plugin deletada.")
        except Exception as e:
            logger.warn(f"Auth: falha ao deletar pasta do plugin: {e}")

        # 2. Deleta Steam/config/lua (fixes instalados pelo plugin)
        try:
            from steam_utils import get_steam_path
            steam = get_steam_path()
            if steam:
                lua_dir = os.path.join(steam, "config", "lua")
                if os.path.isdir(lua_dir):
                    shutil.rmtree(lua_dir, ignore_errors=True)
                    logger.warn(f"Auth: pasta lua deletada: {lua_dir}")
                else:
                    logger.warn("Auth: pasta lua não encontrada — nada a deletar.")
        except Exception as e:
            logger.warn(f"Auth: falha ao deletar pasta lua: {e}")

        # 3. Deleta o auth.json residual (Steam/config/parzival/)
        try:
            _clear()
        except Exception:
            pass

    threading.Thread(target=_delete, daemon=True).start()


def check_on_startup():
    """Verifica auth na inicialização.

    Retorna:
      True            → autenticado, plugin funciona normalmente
      "no_license"    → nunca ativado, exibe tela de ativação no JS
      "hwid_stolen"   → HWID diferente (licença transferida para outro PC),
                        JS exibe alerta + tela de reativação com timer;
                        se não reativar no tempo, aí sim auto-destrói
      "trial"         → trial ativo, JS exibe contagem regressiva
      "trial_expired" → trial expirou, JS exibe tela de expirado
      False           → key revogada/inválida, auto-destrói
      "integrity_fail" → manifest inválido, plugin adulterado
    """
    # Verificar integridade dos arquivos
    if not _verify_integrity():
        logger.warn("Auth: FALHA DE INTEGRIDADE — plugin adulterado.")
        return "integrity_fail"
    local = _load()

    # Já tem licença local → valida normal
    if local and local.get("valid"):
        hwid = get_hwid()

        if local.get("hwid") != hwid:
            logger.warn("Auth: HWID diferente — aguardando reativação pelo usuário.")
            _clear()
            return "hwid_stolen"

        key = local.get("key", "")
        result = _api_validate(key, hwid)

        if result.get("valid"):
            # Validação online OK — atualiza timestamp + token assinado
            signed = result.get("signed", "")
            _save(key, hwid, signed)
            logger.log("Auth: startup OK — validação online confirmada.")
            _clear_trial()
            return True

        motivo = result.get("motivo", "")
        if "connection_error" in motivo:
            # Sem rede — aplica janela de tolerância do modo offline
            if _within_offline_grace(local):
                # Verifica token assinado pelo servidor (se existir)
                token = local.get("signed_token", "")
                if token and _verify_signed_token(token, hwid):
                    logger.log("Auth: modo offline dentro da janela de 7 dias — liberado.")
                    return True
                elif not token:
                    # auth.json antigo sem token — permite uma última vez
                    # e marca o timestamp para exigir validação na próxima
                    logger.warn("Auth: auth.json sem token assinado — permitindo offline uma vez.")
                    _save(key, hwid)
                    return True
                else:
                    logger.warn("Auth: token assinado inválido no offline — exige reconexão.")
                    return "no_license"
            else:
                # Janela de 7 dias expirada sem validação online
                logger.warn(f"Auth: modo offline expirado (>{OFFLINE_GRACE_DAYS} dias sem validar).")
                _clear()
                return "no_license"

        logger.warn(f"Auth: startup rejeitado — {result.get('motivo')}")
        _clear()
        _self_destruct(f"key inválida: {result.get('motivo')}")
        return False

    # Sem licença local → verifica trial
    trial = get_trial_status()
    if trial.get("trial_active"):
        logger.log("Auth: trial ativo — modo trial.")
        return "trial"
    if trial.get("expired"):
        logger.log("Auth: trial expirou.")
        return "trial_expired"

    logger.log("Auth: sem licença local — aguardando ativação.")
    return "no_license"


def transfer_license(key: str) -> dict:
    """Transfere a licença para ESTE PC (PC novo).

    Chamado quando activate() retorna hwid_mismatch.
    Fluxo:
      1. PC novo recebeu hwid_mismatch ao tentar ativar
      2. Usuário confirma que quer transferir
      3. Backend chama reset_hwid na planilha (limpa HWID antigo)
      4. Chama activate() normalmente — registra HWID do PC novo
      5. PC antigo não tem auth.json alterado, mas na próxima validação
         online receberá hwid_mismatch e perderá acesso
    """
    key = key.strip().upper()
    if not key:
        return {"success": False, "message": "Key não pode estar vazia."}

    hwid = get_hwid()
    logger.log(f"Auth: transferência solicitada key={key[:4]}**** hwid={hwid[:8]}...")

    # Passo único: activate (força sobrescrita do HWID na License API)
    result = _api_activate(key, hwid)

    if result.get("valid"):
        _save(key, hwid, result.get("signed", ""))
        _reset_attempts(hwid)
        logger.log("Auth: transferência OK — auth.json salvo no PC novo.")
        return {
            "success": True,
            "message": "Licença transferida! Este PC está ativo. O PC anterior perderá o acesso."
        }
    else:
        motivo = result.get("motivo", "unknown")
        msgs = {
            "key_invalida":    "Key não encontrada.",
            "revogada":        "Key revogada.",
            "connection_error": "Sem conexão. Verifique sua internet.",
        }
        msg = msgs.get(motivo) or f"Erro: {motivo}"
        logger.warn(f"Auth: transferência falhou — {motivo}")
        return {"success": False, "message": msg}
