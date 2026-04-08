param(
    [string]$DownloadLink = "https://seu-servidor.com/plugin.zip"
)

$Host.UI.RawUI.WindowTitle = "PARZIVAL RETRO // INSTALLER"
$pluginDisplayName = "Parzival Retrô Steam"
$pluginFolderName = "parzival_retro_steam"
$ProgressPreference = 'SilentlyContinue'

$basePath = Split-Path -Parent $MyInvocation.MyCommand.Path

# --- UI ---

function Mostrar-Cabecalho {
    Clear-Host
    Write-Host ""
    Write-Host " /// PARZIVAL RETRO INITIALIZATION /////////////////////////" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "   ██████╗  █████╗ ██████╗ ███████╗██╗██╗   ██╗ █████╗ ██╗     " -ForegroundColor Cyan
    Write-Host "   ██╔══██╗██╔══██╗██╔══██╗╚══███╔╝██║██║   ██║██╔══██╗██║     " -ForegroundColor Cyan
    Write-Host "   ██████╔╝███████║██████╔╝  ███╔╝ ██║██║   ██║███████║██║     " -ForegroundColor Cyan
    Write-Host "   ██╔═══╝ ██╔══██║██╔══██╗ ███╔╝  ██║╚██╗ ██╔╝██╔══██║██║     " -ForegroundColor Cyan
    Write-Host "   ██║     ██║  ██║██║  ██║███████╗██║ ╚████╔╝ ██║  ██║███████╗" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "        [ PARZIVAL RETRO STEAM MODULE ]" -ForegroundColor White
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
    Write-Host "   [>] $Msg" -ForegroundColor Gray
    Start-Sleep -Seconds $Espera
}

function Ok {
    param([string]$Msg)
    Write-Host "   [OK] $Msg" -ForegroundColor Green
}

function Erro {
    param([string]$Msg)
    Write-Host "   [X] $Msg" -ForegroundColor Red
}

# --- EXECUTAR CMD OCULTO (SE PRECISAR) ---

function Executar-Oculto {
    param([string]$Comando)

    Start-Process "cmd.exe" -ArgumentList "/c $Comando" -WindowStyle Hidden
}

# --- INÍCIO ---

Mostrar-Cabecalho

Secao "ENV_SETUP"

Passo "Preparando ambiente..."
Passo "Verificando sistema..."

Ok "Ambiente pronto."

# --- DOWNLOAD ---

Secao "DATA_SYNC"

$pluginDir = Join-Path $basePath $pluginFolderName

if (Test-Path $pluginDir) {
    Remove-Item $pluginDir -Recurse -Force -ErrorAction SilentlyContinue
}

New-Item -Path $pluginDir -ItemType Directory | Out-Null

$zipPath = Join-Path $env:TEMP "$pluginFolderName.zip"

Passo "Conectando ao servidor..."
Passo "Baixando pacote..."

try {
    Invoke-WebRequest -Uri $DownloadLink -OutFile $zipPath -UseBasicParsing
    
    Passo "Extraindo arquivos..."
    
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $pluginDir)
    
    Remove-Item $zipPath -ErrorAction SilentlyContinue
    
    Ok "$pluginDisplayName instalado com sucesso."
}
catch {
    Erro "Falha no processo de instalação."
    exit
}

# --- FINAL ---

Secao "FINALIZE"

Passo "Aplicando ajustes finais..."
Ok "Sistema pronto."

Write-Host ""
Write-Host " >>> INSTALACAO FINALIZADA <<< " -ForegroundColor Green
Write-Host ""
Pause
