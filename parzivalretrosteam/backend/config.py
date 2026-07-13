"""Configurações centrais do GameFixer."""

PLUGIN_NAME        = "Parzival Retrô Steam"
PLUGIN_VERSION     = "2.3"

# ── Autenticação por Key + HWID ───────────────────────────────────────────────
AUTH_API_URL              = "https://parzivalalicenses.dnsfollowme.uk/api/v1/validate"
AUTH_API_ACTIVATE_URL     = "https://parzivalalicenses.dnsfollowme.uk/api/v1/activate"
AUTH_API_TRIAL_START_URL  = "https://parzivalalicenses.dnsfollowme.uk/api/v1/trial/start"
AUTH_API_TRIAL_STATUS_URL = "https://parzivalalicenses.dnsfollowme.uk/api/v1/trial/status"
AUTH_API_TRIAL_CONVERT_URL = "https://parzivalalicenses.dnsfollowme.uk/api/v1/trial/convert"
AUTH_FILE                 = "auth.json"
TRIAL_FILE                = "trial.json"
TRIAL_DURATION_DAYS       = 3

GITHUB_REPO        = "ParzivalRetroSteam/ParzRetroSteam"
GITHUB_API_RELEASES = f"https://api.github.com/repos/{GITHUB_REPO}/releases"

# SHA-256 checksums para releases (tag → sha256 do .zip).
# Popule com os hashes reais quando os releases forem gerados.
# Tag ausente = permissive mode (log warn + prossegue sem verificação).
RELEASE_CHECKSUMS: dict = {
    # "v2.1":  "abc123...",
    # "v2.2":  "def456...",
}

# OpenSteamTool — dependência externa que o plugin precisa para funcionar.
# Mantida atualizada separadamente (DLLs na raiz da Steam, não dentro do plugin).
OST_GITHUB_REPO       = "OpenSteam001/OpenSteamTool"
OST_GITHUB_API_LATEST = f"https://api.github.com/repos/{OST_GITHUB_REPO}/releases/latest"
OST_FILES             = ["dwmapi.dll", "xinput1_4.dll", "OpenSteamTool.dll"]
OST_VERSION_FILE       = "ost_version.json"  # salvo em backend/data/, guarda a tag instalada

WEBKIT_DIR_NAME    = "ParzivalRetroSteam"
WEB_UI_JS_FILE     = "gamefixer.js"
WEB_UI_ICON_FILE   = "gamefixer-icon.png"

# APIs para download de manifesto Lua
API_JSON_FILE      = "api.json"

# Fixes index (mesmos endpoints do luatools)
FIXES_INDEX_URL    = "https://index.luatools.work/fixes-index.json"
GENERIC_FIX_BASE   = "https://files.luatools.work/GameBypasses/{appid}.zip"
ONLINE_FIX_BASE    = "https://files.luatools.work/OnlineFix1/{appid}.zip"

# DRM que o plugin detecta.
# Cada entrada tem:
#   pattern  — string exata a buscar no JSON da Steam API (lowercase)
#   fields   — lista de campos onde buscar (None = busca em tudo, mais lento e falso-positivo-prone)
#              use ["legal_notice", "drm_notice", "dlc"] para ser preciso
UNSUPPORTED_DRM = [
    {"id": "denuvo",    "name": "Denuvo",              "pattern": "denuvo",             "fields": ["legal_notice", "drm_notice", "name", "detailed_description"]},
    {"id": "ea",        "name": "EA Anti-Cheat",        "pattern": "ea anticheat",       "fields": ["legal_notice", "drm_notice", "detailed_description"]},
    {"id": "eac",       "name": "Easy Anti-Cheat",      "pattern": "easy anti-cheat",    "fields": ["legal_notice", "drm_notice", "detailed_description"]},
    {"id": "battleye",  "name": "BattlEye",             "pattern": "battleye",           "fields": ["legal_notice", "drm_notice", "detailed_description"]},
    {"id": "ubisoft",   "name": "Ubisoft Connect",      "pattern": "ubisoft connect",    "fields": ["legal_notice", "drm_notice", "detailed_description"]},
    {"id": "rockstar",  "name": "Rockstar Launcher",    "pattern": "rockstar games launcher", "fields": ["legal_notice", "drm_notice", "detailed_description"]},
    {"id": "epicgames", "name": "Epic Games Launcher",  "pattern": "epic games launcher","fields": ["legal_notice", "drm_notice", "detailed_description"]},
    {"id": "vac",       "name": "VAC (Valve Anti-Cheat)","pattern": "valve anti-cheat",  "fields": ["legal_notice", "drm_notice", "detailed_description"]},
    {"id": "steamdrm",  "name": "Steam DRM",            "pattern": "steam drm",          "fields": ["drm_notice"]},
]

# DRM detection API (Steam store page tags)
STEAM_APP_DETAILS_URL = "https://store.steampowered.com/api/appdetails?appids={appid}&l=portuguese"

# Busca de jogos por nome (retorna appid, nome, capsule image, metascore, preço)
STEAM_STORESEARCH_URL = "https://store.steampowered.com/api/storesearch/?term={term}&l=portuguese&cc=BR"

# ── Catálogo de jogos (fontes do SFF —inclui delistados como Deadpool) ─────────
# GitHub mirrors usados pelo SFF (game_list_fallback.py / web_bridge.py)
GAMES_CACHE_URL     = "https://raw.githubusercontent.com/SteamTools-Team/GameList/refs/heads/main/games.json"
GAMES_APPID_URL     = "https://raw.githubusercontent.com/jsnli/steamappidlist/refs/heads/master/data/games_appid.json"
SOFTWARE_APPID_URL  = "https://raw.githubusercontent.com/jsnli/steamappidlist/refs/heads/master/data/software_appid.json"

# Nomes dos arquivos de cache local (em backend/data/)
GAMES_CACHE_FILE    = "games_cache.json"
GAMES_APPID_FILE    = "appid_cache.json"
SOFTWARE_APPID_FILE = "software_cache.json"

# URL base para foto de capa (funciona mesmo para jogos delistados)
STEAM_HEADER_IMG_URL = "https://cdn.cloudflare.steamstatic.com/steam/apps/{appid}/header.jpg"

# Temp + data
TEMP_DL_DIR        = "temp_dl"

# HTTP
HTTP_TIMEOUT       = 20
USER_AGENT         = "discord(dot)gg/luatools"
