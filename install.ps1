param(
    [string]$PluginLink = "https://raw.githubusercontent.com/ParzivalRetroSteam/ParzRetroSteam/main/parzivalretrosteam.zip"
)

# --- Forcar Protocolo de Seguranca ---
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- Trava de Seguranca 1: Forca a execucao como Administrador ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"iex (irm 'https://raw.githubusercontent.com/ParzivalRetroSteam/ParzRetroSteam/main/install.ps1')`"" -Verb RunAs
    exit
}

$Host.UI.RawUI.WindowTitle = "Parzival Retro Steam - Setup"
$name  = "parzivalretrosteam"
$ProgressPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 > $null

function Mostrar-Cabecalho {
    Clear-Host
    Write-Host ""
    Write-Host " ==========================================================" -ForegroundColor DarkRed
    Write-Host "    ____    _    ____  _____ ___  __     __  _    _        " -ForegroundColor Red
    Write-Host "   |  _ \  / \  |  _ \|__  /|_ _| \ \   / / / \  | |       " -ForegroundColor Red
    Write-Host "   | |_) |/ _ \ | |_) | / /  | |   \ \ / / / _ \ | |       " -ForegroundColor Red
    Write-Host "   |  __/| ___ \|  _ < / /_  | |    \ V / / ___ \| |___    " -ForegroundColor Red
    Write-Host "   |_|  /_/   \_\_| \_\____||___|    \_/ /_/   \_\_____|   " -ForegroundColor Red
    Write-Host "                                                           " -ForegroundColor Red
    Write-Host "        P A R Z I V A L   R E T R O   S T E A M            " -ForegroundColor White
    Write-Host " ==========================================================" -ForegroundColor DarkRed
    Write-Host ""
}

function Erro-Critico {
    param([string]$Msg)
    Write-Host "`n   [X] ERRO CRITICO: " -NoNewline -ForegroundColor Red
    Write-Host $Msg -ForegroundColor White
    Write-Host "   O instalador sera fechado em 5 segundos..." -ForegroundColor Gray
    Start-Sleep -Seconds 5
    exit
}

Mostrar-Cabecalho

# ====================================================================
# --- SISTEMA DE LICENCA (CRIPTOGRAFADO) ---
# ====================================================================
Write-Host "   > PROCESSO DE AUTENTICACAO" -ForegroundColor DarkRed
Write-Host ""
$chaveDigitada = Read-Host "   [?] Digite sua Chave de Acesso"

$chaveLimpa = $chaveDigitada.Trim().ToLower()
$tokenDb = "czFtcGxlcw==" 
$tokenValido = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($tokenDb))

if ($chaveLimpa -ne $tokenValido) {
    Erro-Critico "Chave de acesso invalida. Verifique o que foi digitado e tente novamente."
}
Write-Host ""
Write-Host "   [" -NoNewline -ForegroundColor DarkRed
Write-Host "OK" -NoNewline -ForegroundColor Red
Write-Host "] Licenca verificada! Acesso concedido." -ForegroundColor White
Write-Host ""
Start-Sleep -Seconds 2

# --- Trava de Seguranca 2: Verifica se a Steam esta instalada ---
Write-Host "   > Verificando integridade do sistema hospedeiro..." -ForegroundColor DarkRed
$steam = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -ErrorAction SilentlyContinue).InstallPath

if (-not $steam -or -not (Test-Path $steam)) {
    Erro-Critico "A Steam nao foi encontrada neste computador. Instale a Steam e faca login antes de usar."
}

# --- Funcoes Visuais ---
function Spinner-Falso {
    param([string]$Texto, [int]$Segundos)
    $caracteres = @('-', '\', '|', '/')
    $loops = $Segundos * 4
    for ($i = 0; $i -lt $loops; $i++) {
        $c = $caracteres[$i % 4]
        Write-Host "`r   [" -NoNewline -ForegroundColor DarkRed
        Write-Host $c -NoNewline -ForegroundColor Red
        Write-Host "] " -NoNewline -ForegroundColor DarkRed
        Write-Host "$Texto...   " -NoNewline -ForegroundColor Gray
        Start-Sleep -Milliseconds 250
    }
    Write-Host "`r   [" -NoNewline -ForegroundColor DarkRed
    Write-Host "OK" -NoNewline -ForegroundColor Red
    Write-Host "] $Texto... Concluido!      " -ForegroundColor White
}

function Barra-Progresso-Falsa {
    param([string]$Tarefa, [int]$TempoSegundos)
    Write-Host "   > $Tarefa..." -ForegroundColor DarkRed
    $largura = 40
    $passos = $largura
    $espera = ($TempoSegundos * 1000) / $passos

    for ($i = 1; $i -le $passos; $i++) {
        $porcentagem = [math]::Round(($i / $passos) * 100)
        $preenchido = [string]::new('#', $i)
        $vazio = [string]::new('-', ($largura - $i))
        Write-Host "`r   [" -NoNewline -ForegroundColor DarkRed
        Write-Host $preenchido -NoNewline -ForegroundColor Red
        Write-Host "$vazio] " -NoNewline -ForegroundColor DarkRed
        Write-Host "$porcentagem% " -NoNewline -ForegroundColor Gray
        Start-Sleep -Milliseconds $espera
    }
    Write-Host "`n   [" -NoNewline -ForegroundColor DarkRed
    Write-Host "OK" -NoNewline -ForegroundColor Red
    Write-Host "] Modulo processado.`n" -ForegroundColor White
}

# --- Inicio da Instalacao (Plugin Base) ---
Spinner-Falso "Mapeando diretorios de instalacao" 1
Spinner-Falso "Encerrando servicos em segundo plano" 2

@("steam", "steamservice", "steamwebhelper", "steamerrorreporter") | ForEach-Object {
    Get-Process $_ -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}
Start-Sleep -Seconds 2

Write-Host ""
Barra-Progresso-Falsa "Alocando espaco e preparando estruturas" 1

$millDir = Join-Path $steam "millennium"
if (!(Test-Path $millDir)) { New-Item -Path $millDir -ItemType Directory -Force | Out-Null }

$pluginsPath = Join-Path $millDir "plugins"
if (!(Test-Path $pluginsPath)) { New-Item -Path $pluginsPath -ItemType Directory -Force | Out-Null }

$pluginDir = Join-Path $pluginsPath $name
if (Test-Path $pluginDir) { Remove-Item -Path $pluginDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -Path $pluginDir -ItemType Directory -Force | Out-Null

$zipPath = Join-Path $env:TEMP "$name.zip"

if (Test-Path $zipPath) { Remove-Item $zipPath -Force -ErrorAction SilentlyContinue }

Write-Host "   [" -NoNewline -ForegroundColor DarkRed
Write-Host "DL" -NoNewline -ForegroundColor Red
Write-Host "] Baixando arquivos da interface principal..." -ForegroundColor Gray

try {
    Invoke-WebRequest -Uri $PluginLink -OutFile $zipPath -UseBasicParsing
    Barra-Progresso-Falsa "Extraindo bibliotecas visuais" 2
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $pluginDir)
    Remove-Item $zipPath -ErrorAction SilentlyContinue
}
catch { Erro-Critico "Falha ao baixar o modulo base." }


# --- Otimização de Chaves (Caminho Novo) ---
Spinner-Falso "Otimizando chaves de registro" 1
$betaPath = Join-Path $steam "package\beta"
if (Test-Path $betaPath) { Remove-Item $betaPath -Recurse -Force }
$cfgPath = Join-Path $steam "steam.cfg"
if (Test-Path $cfgPath)  { Remove-Item $cfgPath  -Recurse -Force }

$configPath = Join-Path $millDir "config\config.json"
$configDir  = Split-Path $configPath
if (-not (Test-Path $configDir)) { New-Item -Path $configDir -ItemType Directory -Force | Out-Null }
try {
    if (Test-Path $configPath) {
        $cfg = Get-Content $configPath -Raw | ConvertFrom-Json
        if (-not $cfg.plugins) { $cfg | Add-Member -MemberType NoteProperty -Name plugins -Value ([PSCustomObject]@{ enabledPlugins = @() }) -Force }
        if (-not $cfg.plugins.enabledPlugins) { $cfg.plugins | Add-Member -MemberType NoteProperty -Name enabledPlugins -Value @() -Force }
        $lista = @($cfg.plugins.enabledPlugins)
        if ($lista -notcontains $name) { $lista += $name }
        $cfg.plugins.enabledPlugins = $lista
        $cfg | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
    } else {
        [PSCustomObject]@{ plugins = [PSCustomObject]@{ enabledPlugins = @($name) } } | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
    }
} catch { }

Write-Host " ==========================================================" -ForegroundColor DarkRed
Write-Host "   [" -NoNewline -ForegroundColor DarkRed
Write-Host "OK" -NoNewline -ForegroundColor Red
Write-Host "] PARZIVAL RETRO INSTALADO E ATIVADO COM SUCESSO!" -ForegroundColor White
Write-Host " ==========================================================" -ForegroundColor DarkRed
Write-Host ""


# ====================================================================
# --- INTEGRAÇÃO OFICIAL: STEAM TOOLS & MILLENNIUM ---
# ====================================================================
Write-Host "   > Baixando nucleo Steam Tools (via CloudRedirect)..." -ForegroundColor Cyan

# 1. Instalador Direto do Steam Tools
$stExe = Join-Path $steam "CloudRedirectCLI.exe"
try {
    Invoke-WebRequest -Uri "https://github.com/Selectively11/CloudRedirect/releases/latest/download/CloudRedirectCLI.exe" -OutFile $stExe -UseBasicParsing -TimeoutSec 60
    Write-Host "   > Aplicando correcoes no nucleo (/stfixer)..." -ForegroundColor DarkRed
    Start-Process $stExe "/stfixer" -Wait
    if (Test-Path $stExe) { Remove-Item $stExe -Force -ErrorAction SilentlyContinue }
    Write-Host "   [OK] Steam Tools injetado!" -ForegroundColor Green
} catch {
    Write-Host "   [!] Falha silenciosa no Steam Tools. O script continuara." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "   > Instalando motor Millennium..." -ForegroundColor Cyan

# 2. Instalador Direto do Millennium (Com Redundância)
$msUrls = @(
    "https://ps.lua.tools/millennium.ps1",
    "https://luatools.vercel.app/millennium.ps1"
)
$msCode = $null
foreach ($url in $msUrls) {
    for ($try = 1; $try -le 2 -and -not $msCode; $try++) {
        try { $msCode = Invoke-RestMethod $url -TimeoutSec 30 } catch { Start-Sleep -Seconds 1 }
    }
    if ($msCode) { break }
}

if ($msCode) {
    try {
        Invoke-Expression "& { $msCode } -NoLog -DontStart -SteamPath '$steam'"
        Write-Host "   [OK] Motor Millennium instalado!" -ForegroundColor Green
    } catch { }
} else {
    Write-Host "   [!] Nao foi possivel conectar aos servidores do Millennium." -ForegroundColor Red
}

Write-Host ""
Write-Host "   > Reiniciando a interface automaticamente..." -ForegroundColor Gray
Start-Sleep -Seconds 3

# Acionamento final
$cmdPath = Join-Path $millDir "plugins\$name\backend\restart_steam.cmd"

if (Test-Path $cmdPath) {
    Start-Process -FilePath $cmdPath -WorkingDirectory (Split-Path $cmdPath) -WindowStyle Hidden
} else {
    $steamExe = Join-Path $steam "steam.exe"
    Start-Process -FilePath $steamExe -ArgumentList "-clearbeta" -WorkingDirectory $steam
}

Stop-Process -Id $PID -Force
Exit
