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

$Host.UI.RawUI.WindowTitle = "Parzival Retro Steam - Setup Hibrido"
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

# --- Verifica se a Steam esta instalada ---
Write-Host "   > Verificando integridade do sistema hospedeiro..." -ForegroundColor DarkRed
$steam = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -ErrorAction SilentlyContinue).InstallPath

if (-not $steam -or -not (Test-Path $steam)) {
    Erro-Critico "A Steam nao foi encontrada neste computador."
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

# --- Fechando a Steam ---
Spinner-Falso "Encerrando servicos em segundo plano" 2
@("steam", "steamservice", "steamwebhelper") | ForEach-Object {
    Get-Process $_ -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}
Start-Sleep -Seconds 2

Write-Host ""

# ====================================================================
# 1. INSTALAÇÃO DO OPENSTEAMTOOLS (BUSCA AUTOMÁTICA NO GITHUB)
# ====================================================================
Write-Host "   > Instalando nucleo OpenSteamTools..." -ForegroundColor Cyan
try {
    $ostApi = "https://api.github.com/repos/OpenSteam001/OpenSteamTool/releases/latest"
    $ostJson = Invoke-RestMethod -Uri $ostApi -UseBasicParsing
    $ostAssetUrl = ($ostJson.assets | Where-Object { $_.name -like "*.zip" } | Select-Object -First 1).browser_download_url
    
    if ($ostAssetUrl) {
        $ostZip = Join-Path $env:TEMP "OpenSteamTool.zip"
        Invoke-WebRequest -Uri $ostAssetUrl -OutFile $ostZip -UseBasicParsing -TimeoutSec 60
        Expand-Archive -Path $ostZip -DestinationPath $steam -Force
        Remove-Item $ostZip -ErrorAction SilentlyContinue
        Write-Host "   [OK] OpenSteamTools injetado com sucesso (Ultima Versao)!" -ForegroundColor Green
    } else {
        Write-Host "   [!] Aviso: Nenhum .zip encontrado no repositorio OpenSteamTools." -ForegroundColor Yellow
    }
} catch {
    Write-Host "   [!] Aviso: Falha ao baixar ou extrair OpenSteamTools. $($_.Exception.Message)" -ForegroundColor Yellow
}

# ====================================================================
# 2. INSTALAÇÃO DO CONFIG.ZIP (VOICESFIX) NA RAIZ DA STEAM
# ====================================================================
Write-Host "   > Aplicando configuracoes personalizadas (config.zip)..." -ForegroundColor Cyan
try {
    $configZip = Join-Path $env:TEMP "config_custom.zip"
    Invoke-WebRequest -Uri $ConfigZipLink -OutFile $configZip -UseBasicParsing -TimeoutSec 60
    Expand-Archive -Path $configZip -DestinationPath $steam -Force
    Remove-Item $configZip -ErrorAction SilentlyContinue
    Write-Host "   [OK] Configuracoes aplicadas na raiz da Steam!" -ForegroundColor Green
} catch {
    Write-Host "   [!] Falha ao aplicar config.zip. Ignorando." -ForegroundColor Yellow
}

# ====================================================================
# 3. INSTALAÇÃO DO MILLENNIUM (VERSÃO LEGADA - PYTHON)
# ====================================================================
Write-Host "   > Instalando motor Millennium (Versao Python/Legacy)..." -ForegroundColor Cyan
try {
    $msCode = Invoke-RestMethod "https://ps.lua.tools/millennium-py.ps1" -TimeoutSec 30
    $ErrorActionPreference = "Continue" 
    Invoke-Expression "& { $msCode } -NoLog -DontStart -SteamPath '$steam'"
    $ErrorActionPreference = "SilentlyContinue"
    Write-Host "   [OK] Millennium Legacy instalado!" -ForegroundColor Green
} catch {
    Write-Host "   [!] Nao foi possivel instalar o Millennium Legacy." -ForegroundColor Red
}

# ====================================================================
# 4. INSTALAÇÃO DO PLUGIN PARZIVAL RETRO STEAM
# ====================================================================
Write-Host "   > Baixando e extraindo o plugin Parzival Retro..." -ForegroundColor Cyan
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
    Write-Host "   [OK] Parzival Retro instalado com sucesso!" -ForegroundColor Green
} catch { 
    Write-Host "   [!] Falha ao instalar o plugin Parzival Retro." -ForegroundColor Red
}

# ====================================================================
# 5. BLOQUEIO DE ATUALIZAÇÕES E ATIVAÇÃO DO PARZIVAL
# ====================================================================
Spinner-Falso "Otimizando chaves e bloqueando atualizacoes" 1

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
        
        # Garante que o objeto 'general' existe e bloqueia updates[cite: 1]
        if (-not $config.general) { $config | Add-Member -MemberType NoteProperty -Name "general" -Value ([PSCustomObject]@{}) -Force }
        $config.general | Add-Member -MemberType NoteProperty -Name "checkForMillenniumUpdates" -Value $false -Force
        
        # Adiciona o Parzival na lista de plugins ativados
        if (-not $config.plugins) { $config | Add-Member -MemberType NoteProperty -Name "plugins" -Value ([PSCustomObject]@{ enabledPlugins = @() }) -Force }
        if (-not $config.plugins.enabledPlugins) { $config.plugins | Add-Member -MemberType NoteProperty -Name "enabledPlugins" -Value @() -Force }
        
        $lista = @($config.plugins.enabledPlugins)
        if ($lista -notcontains $name) { $lista += $name }
        $config.plugins.enabledPlugins = $lista
        
        $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
    }
} catch { }

Write-Host "`n ==========================================================" -ForegroundColor DarkRed
Write-Host "   [" -NoNewline -ForegroundColor DarkRed
Write-Host "OK" -NoNewline -ForegroundColor Red
Write-Host "] PARZIVAL RETRO STEAM INSTALADO COM SUCESSO!" -ForegroundColor White
Write-Host " ==========================================================" -ForegroundColor DarkRed
Write-Host "`n   > Reiniciando a Steam em 3 segundos..." -ForegroundColor Gray
Start-Sleep -Seconds 3

# Inicialização limpa da Steam
$steamExe = Join-Path $steam "steam.exe"
Start-Process -FilePath $steamExe -ArgumentList "-clearbeta" -WorkingDirectory $steam

Stop-Process -Id $PID -Force
Exit
