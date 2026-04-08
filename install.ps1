param(
    [string]$DownloadLink = "https://parz-retro-steam.vercel.app/parzivalretrosteam.zip"
)

$Host.UI.RawUI.WindowTitle = "PARZIVAL_OS // RETRO_SETUP"
$name  = "parzivalretrosteam"
$steam = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam").InstallPath
$ProgressPreference = 'SilentlyContinue'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 > $null

# --- Interface Futurista (Cyberpunk UI) ---

function Mostrar-Cabecalho {
    Clear-Host
    Write-Host ""
    Write-Host " /// SYSTEM OVERRIDE PROTOCOL INITIATED ////////////////////" -ForegroundColor Magenta
    Write-Host "                                                            " -ForegroundColor Magenta
    Write-Host "   ██████╗  █████╗ ██████╗ ███████╗██╗██╗   ██╗███████╗     " -ForegroundColor Cyan
    Write-Host "   ██╔══██╗██╔══██╗██╔══██╗╚══███╔╝██║██║   ██║██╔════╝     " -ForegroundColor Cyan
    Write-Host "   ██████╔╝███████║██████╔╝  ███╔╝ ██║██║   ██║███████╗     " -ForegroundColor Cyan
    Write-Host "   ██╔═══╝ ██╔══██║██╔══██╗ ███╔╝  ██║╚██╗ ██╔╝╚════██║     " -ForegroundColor Cyan
    Write-Host "   ██║     ██║  ██║██║  ██║███████╗██║ ╚████╔╝ ███████║     " -ForegroundColor Cyan
    Write-Host "   ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝  ╚══════╝     " -ForegroundColor Cyan
    Write-Host "                                                            " -ForegroundColor Magenta
    Write-Host "      [ N E X U S   G A M I N G   I N J E C T O R ]         " -ForegroundColor White
    Write-Host " ///////////////////////////////////////////////////////////" -ForegroundColor Magenta
    Write-Host ""
}

function Secao {
    param([string]$Titulo)
    Write-Host ""
    Write-Host " > $Titulo " -ForegroundColor Magenta -NoNewline
    Write-Host "......................................" -ForegroundColor DarkGray
    Write-Host ""
}

function Passo {
    param([string]$Msg, [int]$Espera = 1)
    Write-Host "   [>] " -NoNewline -ForegroundColor Cyan
    Write-Host $Msg -ForegroundColor Gray
    Start-Sleep -Seconds $Espera
}

function Ok {
    param([string]$Msg)
    Write-Host "   [√] " -NoNewline -ForegroundColor Green
    Write-Host $Msg -ForegroundColor White
    Start-Sleep -Milliseconds 400
}

function Erro {
    param([string]$Msg)
    Write-Host "   [X] " -NoNewline -ForegroundColor Red
    Write-Host $Msg -ForegroundColor Red
    Start-Sleep -Milliseconds 400
}

# --- Sequencia de Boot ---

Mostrar-Cabecalho

Secao "SYS_PREP"

Passo "Mapeando diretorios do hospedeiro..." 1
Passo "Isolando processos em segundo plano..." 2

@("steam", "steamservice", "steamwebhelper", "steamerrorreporter") | ForEach-Object {
    Get-Process $_ -ErrorAction SilentlyContinue | Stop-Process -Force
}
Start-Sleep -Seconds 2

Ok "Nuvem isolada. Ambiente seguro."

# --- Modulo de Uplink ---

Secao "UPLINK_SYNC"

$pluginsPath = Join-Path $steam "plugins"
if (!(Test-Path $pluginsPath)) { New-Item -Path $pluginsPath -ItemType Directory | Out-Null }

$pluginDir = Join-Path $pluginsPath $name
if (Test-Path $pluginDir) { Remove-Item -Path $pluginDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -Path $pluginDir -ItemType Directory | Out-Null

$zipPath = Join-Path $env:TEMP "$name.zip"

Passo "Estabelecendo conexao com servidor central..." 1
Passo "Baixando pacote de dados criptografados..." 2

try {
    Invoke-WebRequest -Uri $DownloadLink -OutFile $zipPath -UseBasicParsing
    Passo "Descompactando nucleo retro..." 2
    
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $pluginDir)
    Remove-Item $zipPath -ErrorAction SilentlyContinue
    
    Ok "Payload injetado com sucesso."
}
catch {
    Erro "Conexao perdida. Abortando injecao."
    exit
}

# --- Modulo de Override ---

Secao "SYS_OVERRIDE"

Passo "Limpando cache residual da matrix..." 1
$betaPath = Join-Path $steam "package\beta"
if (Test-Path $betaPath) { Remove-Item $betaPath -Recurse -Force }
$cfgPath = Join-Path $steam "steam.cfg"
if (Test-Path $cfgPath)  { Remove-Item $cfgPath  -Recurse -Force }

Passo "Otimizando rotas de execucao..." 1
Ok "Sistema hospedeiro modificado."

# --- Fim ---

Write-Host ""
Write-Host " ///////////////////////////////////////////////////////////" -ForegroundColor Cyan
Write-Host "   [OK] SINCRONIZACAO CONCLUIDA! ACESSO LIBERADO." -ForegroundColor Green
Write-Host " ///////////////////////////////////////////////////////////" -ForegroundColor Cyan
Write-Host ""
Write-Host "   [!] Iniciando sequencia de boot do cliente em 3s..." -ForegroundColor Yellow
Write-Host ""
Start-Sleep -Seconds 3

# Acionamento do arquivo .bat do Parzival Retro
$cmdPath = Join-Path $steam "plugins\$name\backend\restart_steam.cmd"

if (Test-Path $cmdPath) {
    Start-Process -FilePath $cmdPath -WorkingDirectory (Split-Path $cmdPath)
} else {
    $steamExe = Join-Path $steam "steam.exe"
    Start-Process -FilePath $steamExe -ArgumentList "-clearbeta" -WorkingDirectory $steam
}
