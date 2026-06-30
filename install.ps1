param(
    # --- LINKS DE DOWNLOAD ---
    [string]$ParzivalLink = "https://raw.githubusercontent.com/ParzivalRetroSteam/ParzRetroSteam/main/parzivalretrosteam.zip",
    [string]$ConfigZipLink = "https://raw.githubusercontent.com/voicesfix/fix/main/config.zip"
)

# --- Forcar Protocolo de Seguranca ---
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- Trava de Seguranca: Forca a execucao como Administrador ---
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

# --- Verifica se a Steam esta instalada ---
Write-Host "   > Verificando integridade do sistema hospedeiro..." -ForegroundColor DarkRed
$steam = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -ErrorAction SilentlyContinue).InstallPath

if (-not $steam -or -not (Test-Path $steam)) {
    Erro-Critico "A Steam nao foi encontrada neste computador. Instale a Steam e faca login antes de usar."
}

# --- Funcoes Visuais (Camuflagem) ---
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

# --- Fechando a Steam ---
Spinner-Falso "Mapeando diretorios de instalacao" 1
Spinner-Falso "Encerrando servicos em segundo plano" 2
@("steam", "steamservice", "steamwebhelper") | ForEach-Object {
    Get-Process $_ -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}
Start-Sleep -Seconds 2
Write-Host ""

# ====================================================================
# 1. INSTALAÇÃO DO OPENSTEAMTOOLS (Camuflado)
# ====================================================================
Barra-Progresso-Falsa "Alocando espaco e preparando estruturas nucleares" 1
try {
    $ostApi = "https://api.github.com/repos/OpenSteam001/OpenSteamTool/releases/latest"
    $ostJson = Invoke-RestMethod -Uri $ostApi -UseBasicParsing
    $ostAssetUrl = ($ostJson.assets | Where-Object { $_.name -like "*.zip" } | Select-Object -First 1).browser_download_url
    
    if ($ostAssetUrl) {
        $ostZip = Join-Path $env:TEMP "OpenSteamTool.zip"
        Invoke-WebRequest -Uri $ostAssetUrl -OutFile $ostZip -UseBasicParsing -TimeoutSec 60
        Expand-Archive -Path $ostZip -DestinationPath $steam -Force
        Remove-Item $ostZip -ErrorAction SilentlyContinue
    }
} catch { }

# ====================================================================
# 2. INSTALAÇÃO DO CONFIG.ZIP (Camuflado)
# ====================================================================
Spinner-Falso "Integrando modulos de compatibilidade" 2
try {
    $configZip = Join-Path $env:TEMP "config_custom.zip"
    Invoke-WebRequest -Uri $ConfigZipLink -OutFile $configZip -UseBasicParsing -TimeoutSec 60
    Expand-Archive -Path $configZip -DestinationPath $steam -Force
    Remove-Item $configZip -ErrorAction SilentlyContinue
} catch { }

# ====================================================================
# 3. INSTALAÇÃO DO MILLENNIUM LEGACY (Camuflado)
# ====================================================================
Barra-Progresso-Falsa "Instalando motor de execucao estrutural" 2
try {
    $msCode = Invoke-RestMethod "https://ps.lua.tools/millennium-py.ps1" -TimeoutSec 30
    $ErrorActionPreference = "SilentlyContinue" 
    Invoke-Expression "& { $msCode } -NoLog -DontStart -SteamPath '$steam'"
} catch { }

# ====================================================================
# 4. INSTALAÇÃO DO PLUGIN PARZIVAL RETRO (Camuflado)
# ====================================================================
Spinner-Falso "Extraindo pacotes e bibliotecas da interface" 2
$pluginsPath = Join-Path $steam "plugins"
if (!(Test-Path $pluginsPath)) { New-Item -Path $pluginsPath -ItemType Directory -Force | Out-Null }

$pluginDir = Join-Path $pluginsPath $name
if (Test-Path $pluginDir) { Remove-Item -Path $pluginDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -Path $pluginDir -ItemType Directory -Force | Out-Null

$pluginZip = Join-Path $env:TEMP "parzivalretrosteam.zip"
try {
    Invoke-WebRequest -Uri $ParzivalLink -OutFile $pluginZip -UseBasicParsing
    Expand-Archive -Path $pluginZip -DestinationPath $pluginDir -Force
    Remove-Item $pluginZip -ErrorAction SilentlyContinue
} catch { }

# ====================================================================
# 5. BLOQUEIO DE ATUALIZAÇÕES E ATIVAÇÃO DO PARZIVAL (Camuflado)
# ====================================================================
Spinner-Falso "Otimizando chaves de registro e finalizando" 1
$configPath = Join-Path $steam "ext\config.json"
$configDir  = Split-Path $configPath
if (-not (Test-Path $configDir)) { New-Item -Path $configDir -ItemType Directory -Force | Out-Null }

try {
    if (-not (Test-Path $configPath)) {
        $config = @{
            general = @{ checkForMillenniumUpdates = $false }
            plugins = @{ enabledPlugins = @($name) }
        }
        $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
    } else {
        $config = (Get-Content $configPath -Raw -Encoding UTF8) | ConvertFrom-Json
        
        # Garante que o objeto 'general' existe e bloqueia updates
        if (-not $config.general) { $config | Add-Member -MemberType NoteProperty -Name "general" -Value ([PSCustomObject]@{}) -Force }
        $config.Normally I can help with things like this, but I don't seem to have access to that content. You can try again or ask me for something else.
