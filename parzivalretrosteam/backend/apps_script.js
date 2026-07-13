// ============================================================
//  Parzival Retrô Steam — Sistema de Licenças
//  Google Apps Script — Cole em: script.google.com
//
//  Planilha esperada:
//  Aba "Licenças" com colunas:
//  A: Key | B: HWID | C: Status | D: Data Registro | E: Observação
// ============================================================

var SHEET_NAME = "Licenças";
var SECRET     = "parz_secret_2025";  // mude isso — deve ser igual no config.py

// ── Ponto de entrada HTTP ─────────────────────────────────────────────────────
function doPost(e) {
  try {
    var body   = JSON.parse(e.postData.contents);
    var action = body.action || "";

    if (body.secret !== SECRET) {
      return resp({ok: false, error: "unauthorized"});
    }

    if (action === "validate")    return resp(validateKey(body.key, body.hwid));
    if (action === "generate")    return resp(generateKeys(body.count || 1, body.note || ""));
    if (action === "revoke")      return resp(revokeKey(body.key));
    if (action === "reset_hwid")  return resp(resetHwid(body.key));
    if (action === "list")        return resp(listKeys());

    return resp({ok: false, error: "unknown_action"});

  } catch(err) {
    return resp({ok: false, error: err.toString()});
  }
}

function doGet(e) {
  // Health check simples
  return resp({ok: true, service: "ParzivalRetroSteam License API"});
}

// ── Validar key + HWID ────────────────────────────────────────────────────────
function validateKey(key, hwid) {
  if (!key || !hwid) return {ok: false, error: "missing_params"};

  key  = key.trim().toUpperCase();
  hwid = hwid.trim();

  var sheet = getSheet();
  var data  = sheet.getDataRange().getValues();

  for (var i = 1; i < data.length; i++) {
    var rowKey    = String(data[i][0]).trim().toUpperCase();
    var rowHwid   = String(data[i][1]).trim();
    var rowStatus = String(data[i][2]).trim().toLowerCase();

    if (rowKey !== key) continue;

    // Key encontrada — verifica status
    if (rowStatus === "revogada" || rowStatus === "bloqueada") {
      return {ok: false, error: "key_revoked"};
    }

    // Sem HWID registrado → registra agora
    if (!rowHwid || rowHwid === "" || rowHwid === "undefined") {
      sheet.getRange(i + 1, 2).setValue(hwid);
      sheet.getRange(i + 1, 3).setValue("ativa");
      sheet.getRange(i + 1, 4).setValue(new Date().toISOString());
      SpreadsheetApp.flush();
      return {ok: true, status: "registered", message: "HWID registrado com sucesso."};
    }

    // HWID bate → aprova
    if (rowHwid === hwid) {
      return {ok: true, status: "valid", message: "Licença válida."};
    }

    // HWID diferente → bloqueia
    return {ok: false, error: "hwid_mismatch", message: "Esta key já está em uso em outro PC."};
  }

  return {ok: false, error: "key_not_found"};
}

// ── Gerar keys automaticamente ────────────────────────────────────────────────
function generateKeys(count, note) {
  var sheet = getSheet();
  var keys  = [];

  for (var i = 0; i < count; i++) {
    var key = generateRandomKey();
    sheet.appendRow([key, "", "pendente", "", note || ""]);
    keys.push(key);
  }

  SpreadsheetApp.flush();
  return {ok: true, keys: keys, count: keys.length};
}

function generateRandomKey() {
  var chars   = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // sem 0/O/1/I
  var segments = 4;
  var segLen   = 5;
  var parts    = [];
  for (var s = 0; s < segments; s++) {
    var part = "";
    for (var c = 0; c < segLen; c++) {
      part += chars[Math.floor(Math.random() * chars.length)];
    }
    parts.push(part);
  }
  return parts.join("-"); // ex: AB3KP-7MNQR-XY2WV-9PLKT
}

// ── Revogar key ───────────────────────────────────────────────────────────────
function revokeKey(key) {
  if (!key) return {ok: false, error: "missing_key"};
  key = key.trim().toUpperCase();

  var sheet = getSheet();
  var data  = sheet.getDataRange().getValues();

  for (var i = 1; i < data.length; i++) {
    if (String(data[i][0]).trim().toUpperCase() === key) {
      sheet.getRange(i + 1, 3).setValue("revogada");
      SpreadsheetApp.flush();
      return {ok: true, message: "Key revogada: " + key};
    }
  }
  return {ok: false, error: "key_not_found"};
}

// ── Resetar HWID (permite migrar de PC) ──────────────────────────────────────
function resetHwid(key) {
  if (!key) return {ok: false, error: "missing_key"};
  key = key.trim().toUpperCase();

  var sheet = getSheet();
  var data  = sheet.getDataRange().getValues();

  for (var i = 1; i < data.length; i++) {
    if (String(data[i][0]).trim().toUpperCase() === key) {
      sheet.getRange(i + 1, 2).setValue("");
      sheet.getRange(i + 1, 3).setValue("pendente");
      SpreadsheetApp.flush();
      return {ok: true, message: "HWID resetado. A key pode ser usada em novo PC."};
    }
  }
  return {ok: false, error: "key_not_found"};
}

// ── Listar keys ───────────────────────────────────────────────────────────────
function listKeys() {
  var sheet = getSheet();
  var data  = sheet.getDataRange().getValues();
  var list  = [];

  for (var i = 1; i < data.length; i++) {
    if (!data[i][0]) continue;
    list.push({
      key:    data[i][0],
      hwid:   data[i][1] ? "***registrado***" : "",
      status: data[i][2],
      date:   data[i][3],
      note:   data[i][4],
    });
  }
  return {ok: true, keys: list};
}

// ── Helpers ───────────────────────────────────────────────────────────────────
function getSheet() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sh = ss.getSheetByName(SHEET_NAME);
  if (!sh) {
    sh = ss.insertSheet(SHEET_NAME);
    sh.appendRow(["Key", "HWID", "Status", "Data Registro", "Observação"]);
    sh.setFrozenRows(1);
    // Formata cabeçalho
    sh.getRange(1, 1, 1, 5).setBackground("#1a0000").setFontColor("#e53e3e").setFontWeight("bold");
  }
  return sh;
}

function resp(data) {
  return ContentService
    .createTextOutput(JSON.stringify(data))
    .setMimeType(ContentService.MimeType.JSON);
}
