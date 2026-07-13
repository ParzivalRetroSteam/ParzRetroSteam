"""Carrega e gerencia as APIs de download de manifesto."""

from __future__ import annotations

import json
import os
from typing import List, Dict

from config import API_JSON_FILE
from logger import logger
from paths import backend_path

_DEFAULT_APIS = [
    {
        "name": "Ryuu",
        "url": "http://167.235.229.108/<appid>",
        "success_code": 200,
        "unavailable_code": 404,
        "enabled": True,
    },
    {
        "name": "TwentyTwo Cloud",
        "url": "https://twentytwocloud.com/secure_download?auth=1771526723_73652ce834428eea993e88dd1ccbe5be_442b8efb5c05f1bf8ea5ca46&appid=<appid>",
        "success_code": 200,
        "unavailable_code": 404,
        "enabled": True,
    },
    {
        "name": "Sushi",
        "url": "https://raw.githubusercontent.com/sushi-dev55-alt/sushitools-games-repo-alt/refs/heads/main/<appid>.zip",
        "success_code": 200,
        "unavailable_code": 404,
        "enabled": True,
    },
    {
        "name": "Morrenus",
        "url": "https://manifest.morrenus.xyz/api/v1/manifest/<appid>?api_key=<moapikey>",
        "success_code": 200,
        "unavailable_code": 404,
        "enabled": True,
    },
]


def load_apis(morrenus_key: str = "") -> List[Dict]:
    """Carrega APIs do arquivo JSON, com fallback para defaults."""
    path = backend_path(API_JSON_FILE)
    apis: List[Dict] = []

    if os.path.exists(path):
        try:
            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)
            apis = data.get("api_list", [])
        except Exception as e:
            logger.warn(f"GameFixer: erro ao ler api.json: {e}")

    if not apis:
        apis = _DEFAULT_APIS

    enabled = []
    for api in apis:
        if not api.get("enabled", True):
            continue
        url = api.get("url", "")
        if "<moapikey>" in url:
            if not morrenus_key:
                logger.log(f"GameFixer: pulando API '{api.get('name')}' (sem chave Morrenus)")
                continue
            url = url.replace("<moapikey>", morrenus_key)
        enabled.append({**api, "url": url})

    return enabled


# URLs do manifesto público de APIs gratuitas (mesmo do LuaTools)
_MANIFEST_URL       = "https://raw.githubusercontent.com/madoiscool/lt_api_links/refs/heads/main/load_free_manifest_apis"
_MANIFEST_PROXY_URL = "https://luatools.vercel.app/load_free_manifest_apis"


def fetch_free_apis_now() -> str:
    """Força atualização do api.json baixando o manifesto público de servidores gratuitos."""
    from http_client import get_client
    client = get_client()
    manifest_text = ""
    try:
        try:
            resp = client.get(_MANIFEST_URL, timeout=15, follow_redirects=True)
            resp.raise_for_status()
            manifest_text = resp.text
            logger.log(f"GameFixer: manifesto baixado de {_MANIFEST_URL}")
        except Exception as primary_err:
            logger.warn(f"GameFixer: URL primária falhou ({primary_err}), tentando proxy...")
            resp = client.get(_MANIFEST_PROXY_URL, timeout=20, follow_redirects=True)
            resp.raise_for_status()
            manifest_text = resp.text
            logger.log(f"GameFixer: manifesto baixado do proxy")
    except Exception as e:
        logger.warn(f"GameFixer: FetchFreeApisNow falhou: {e}")
        return json.dumps({"success": False, "error": str(e)})

    if not manifest_text.strip():
        return json.dumps({"success": False, "error": "Manifesto vazio"})

    # Reordena: Ryuu sempre primeiro, SkyApi em seguida, resto na ordem original.
    # Remove entradas que são links de download de FIX (crack/bypass), não de
    # manifesto .lua/.manifest — ex: generator.ryuu.lol e online-fix.me, que
    # servem arquivos de fix e não devem ficar misturados nas APIs de manifesto.
    _BLOCKED_URL_PATTERNS = ["generator.ryuu.lol", "online-fix.me"]

    try:
        data = json.loads(manifest_text)
        api_list = data.get("api_list", [])

        api_list = [
            api for api in api_list
            if not any(p in api.get("url", "") for p in _BLOCKED_URL_PATTERNS)
        ]

        def _priority(api: Dict) -> int:
            name = api.get("name", "").lower()
            if "ryuu" in name:
                return 0
            if "sky" in name:
                return 1
            return 2

        api_list_sorted = sorted(enumerate(api_list), key=lambda x: (_priority(x[1]), x[0]))
        data["api_list"] = [api for _, api in api_list_sorted]
        manifest_text = json.dumps(data, indent=4, ensure_ascii=False)
    except Exception as e:
        logger.warn(f"GameFixer: falha ao reordenar/filtrar api_list: {e}")

    path = backend_path(API_JSON_FILE)
    try:
        local_apis = []
        if os.path.exists(path):
            with open(path, "r", encoding="utf-8") as f:
                local_data = json.load(f)
            local_apis = local_data.get("api_list", [])
        local_names = {a.get("name") for a in local_apis if a.get("name")}
        before = len(local_apis)

        for api in api_list:
            if api.get("name") and api["name"] not in local_names:
                local_apis.append(api)
                local_names.add(api["name"])

        merged = {"api_list": local_apis}
        with open(path, "w", encoding="utf-8") as f:
            json.dump(merged, f, indent=4, ensure_ascii=False)

        count = len([a for a in local_apis if a.get("enabled", True)])
        added = len(local_apis) - before
        logger.log(f"GameFixer: api.json atualizado — {count} servidores ({added} novos do manifesto)")
        return json.dumps({"success": True, "count": count, "added": added})
    except Exception as e:
        logger.warn(f"GameFixer: falha ao mesclar api.json: {e}")
        return json.dumps({"success": False, "error": f"Falha ao salvar: {e}"})
