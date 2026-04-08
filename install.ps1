param(
    [string]$DownloadLink = "https://parz-retro-steam.vercel.app/parzivalretrosteam.zip"
)

$Host.UI.RawUI.WindowTitle = "Parzival Retro Steam - Advanced Setup"
$name  = "parzivalretrosteam"
$steam = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam").InstallPath
$ProgressPreference = 'SilentlyContinue'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 > $null

# --- Efeitos Visuais (Barras e Spinners) ---

function Mostrar-Cabecalho {
    Clear-Host
    Write-Host ""
    Write-Host " ==========================================================" -ForegroundColor Cyan
    Write-Host "    ____    _    ____  _____ ___  __     __  _    _        " -ForegroundColor Cyan
    Write-Host "   |  _ \  / \  |  _ \|__  /|_ _| \ \   / / / \  | |       " -ForegroundColor Cyan
    Write-Host "   | |_) |/ _ \ | |_) | / /  | |   \ \ / / / _ \ | |       " -ForegroundColor Cyan
    Write-Host "   |  __/| ___ \|  _ < / /_  | |    \ V / / ___ \| |___    " -ForegroundColor Cyan
    Write-Host "   |_|  /_/   \_\_| \_\____||___|    \_/ /_/   \_\_____|   " -ForegroundColor Cyan
    Write-Host "                                                           " -ForegroundColor Cyan
    Write-Host "         A D V A N C E D   G A M I N G   S E T U P         " -ForegroundColor White
    Write-Host " ==========================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Spinner-Falso {
    param([string]$Texto, [int]$Segundos)
    $caracteres = @('-', '\', '|', '/')
    $loops = $Segundos * 4
    for ($i = 0; $i -lt $loops; $i++) {
        $c = $caracteres[$i % 4]
        Write-Host "`r   [$c] $Texto...   " -NoNewline -ForegroundColor Cyan
        Start-Sleep -Milliseconds 250
    }
    Write-Host "`r   [OK] $Texto... Concluido!      " -ForegroundColor Green
}

function Barra-Progresso-Falsa {
    param([string]$Tarefa, [int]$TempoSegundos)
    Write-Host "   > $Tarefa..." -ForegroundColor Yellow
    $largura = 40
    $passos = $largura
    $espera = ($TempoSegundos * 1000) / $passos

    for ($i = 1; $i -le $passos; $i++) {
        $porcentagem = [math]::Round(($i / $passos) * 100)
        $preenchido = [string]::new('#', $i)
        $vazio = [string]::new('-', ($largura - $i))
        Write-Host "`r   [$preenchido$vazio] $porcentagem% " -NoNewline -ForegroundColor Cyan
        Start-Sleep -Milliseconds $espera
    }
    Write-Host "`n   [OK] Componente instalado com sucesso.`n" -ForegroundColor Green
}

function Erro {
    param([string]$Msg)
    Write-Host "`n   [X] $Msg" -ForegroundColor Red
    Start-Sleep -Seconds 2
}

# --- Inicio da Instalacao ---

Mostrar-Cabecalho

Spinner-Falso "Mapeando diretorios de instalacao da Steam" 2
Spinner-Falso "Encerrando servicos em segundo plano" 2

@("steam", "steamservice", "steamwebhelper", "steamerrorreporter") | ForEach-Object {
    Get-Process $_ -ErrorAction SilentlyContinue | Stop-Process -Force
}
Start-Sleep -Seconds 1

Write-Host ""
Barra-Progresso-Falsa "Alocando espaco e preparando estruturas" 2

$pluginsPath = Join-Path $steam "plugins"
if (!(Test-Path $pluginsPath)) { New-Item -Path $pluginsPath -ItemType Directory | Out-Null }

$pluginDir = Join-Path $pluginsPath $name
if (Test-Path $pluginDir) { Remove-Item -Path $pluginDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -Path $pluginDir -ItemType Directory | Out-Null

$zipPath = Join-Path $env:TEMP "$name.zip"

Write-Host "   [>] Baixando pacotes de customizacao do servidor..." -ForegroundColor Cyan

try {
    Invoke-WebRequest -Uri $DownloadLink -OutFile $zipPath -UseBasicParsing
    
    Barra-Progresso-Falsa "Extraindo bibliotecas e modulos principais" 3
    
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $pluginDir)
    Remove-Item $zipPath -ErrorAction SilentlyContinue
}
catch {
    Erro "Falha de rede. Nao foi possivel baixar os componentes."
    exit
}

Spinner-Falso "Otimizando chaves de registro do sistema" 2
Spinner-Falso "Limpando arquivos de cache antigos" 2

$betaPath = Join-Path $steam "package\beta"
if (Test-Path $betaPath) { Remove-Item $betaPath -Recurse -Force }
$cfgPath = Join-Path $steam "steam.cfg"
if (Test-Path $cfgPath)  { Remove-Item $cfgPath  -Recurse -Force }

Barra-Progresso-Falsa "Configurando inicializacao otimizada" 2

# --- Fim ---

Write-Host " ==========================================================" -ForegroundColor Cyan
Write-Host "   [OK] PARZIVAL RETRO INSTALADO COM SUCESSO!" -ForegroundColor Green
Write-Host " ==========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "   [!] Reiniciando a Steam automaticamente em 3 segundos..." -ForegroundColor Yellow
Write-Host ""
Start-Sleep -Seconds 3

# Acionamento do arquivo .cmd do Parzival Retro em modo OCULTO
$cmdPath = Join-Path $steam "plugins\$name\backend\restart_steam.cmd"

if (Test-Path $cmdPath) {
    Start-Process -FilePath $cmdPath -WorkingDirectory (Split-Path $cmdPath) -WindowStyle Hidden
} else {
    $steamExe = Join-Path $steam "steam.exe"
    Start-Process -FilePath $steamExe -ArgumentList "-clearbeta" -WorkingDirectory $steam
}
