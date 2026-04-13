param(
    # Link direto do pacote de teste no GitHub
    [string]$TrialLink = "https://raw.githubusercontent.com/ParzivalRetroSteam/ParzRetroSteam/main/trial_data.zip"
)

# --- Forcar Protocolo de Seguranca ---
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- Trava de Seguranca 1: Forca a execucao como Administrador ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm 'https://raw.githubusercontent.com/ParzivalRetroSteam/ParzRetroSteam/main/install_trial.ps1' | iex`"" -Verb RunAs
    exit
}

$Host.UI.RawUI.WindowTitle = "Parzival Retro Steam - TRIAL DEMO"
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
    Write-Host "    P A R Z I V A L   R E T R O   S T E A M  ( D E M O )   " -ForegroundColor White
    Write-Host " ==========================================================" -ForegroundColor DarkRed
    Write-Host ""
    Write-Host "   BEM-VINDO AO TEST DRIVE GRATUITO!" -ForegroundColor Yellow
    Write-Host "   Esta versao instalara um pacote basico de demonstracao." -ForegroundColor Gray
    Write-Host ""
    Start-Sleep -Seconds 3
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

# --- Trava de Seguranca 2: Verifica se a Steam esta instalada ---
Write-Host "   > Verificando integridade do sistema hospedeiro..." -ForegroundColor DarkRed
$steam = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -ErrorAction SilentlyContinue).InstallPath

if (-not $steam -or -not (Test-Path $steam)) {
    Erro-Critico "A Steam nao foi encontrada neste computador. Instale a Steam e faca login antes de testar."
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

# --- 1. PREPARACAO ---
Spinner-Falso "Mapeando diretorios de instalacao" 1
Spinner-Falso "Encerrando servicos em segundo plano" 2

@("steam", "steamservice", "steamwebhelper", "steamerrorreporter") | ForEach-Object {
    Get-Process $_ -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}
Start-Sleep -Seconds 2

# ====================================================================
# --- 2. MODULO TRIAL (.LUAS) - AGORA VEM PRIMEIRO ---
# ====================================================================
Write-Host ""
Spinner-Falso "Preparando diretorios de expansao" 1

$dbPath = Join-Path $steam "config\stplug-in"
if (!(Test-Path $dbPath)) { New-Item -Path $dbPath -ItemType Directory -Force | Out-Null }

$trialZipPath = Join-Path $env:TEMP "trial_data.zip"

Write-Host "   [" -NoNewline -ForegroundColor DarkRed
Write-Host "DL" -NoNewline -ForegroundColor Red
Write-Host "] Baixando pacote de demonstracao..." -ForegroundColor Gray

try {
    Invoke-WebRequest -Uri $TrialLink -OutFile $trialZipPath -UseBasicParsing
    Barra-Progresso-Falsa "Injetando expansoes no nucleo do sistema" 3
    
    try {
        [System.IO.Compression.ZipFile]::ExtractToDirectory($trialZipPath, $dbPath)
    } 
    catch {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($trialZipPath)
        foreach ($entry in $zip.Entries) {
            if ($entry.Name -ne "") {
                $targetPath = Join-Path $dbPath $entry.FullName
                $targetDir = Split-Path $targetPath
                if (!(Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }
                [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $targetPath, $true)
            }
        }
        $zip.Dispose()
    }
    Remove-Item $trialZipPath -ErrorAction SilentlyContinue
}
catch { Erro-Critico "Falha ao extrair o banco de dados de teste." }

# ====================================================================
# --- 3. INSTALACAO DO STEAMTOOLS - AGORA VEM POR ULTIMO ---
# ====================================================================
Write-Host ""
Write-Host "   > Injetando motor estrutural avancado (Isso pode levar alguns segundos)..." -ForegroundColor DarkRed
try {
    # Comando puro e sem filtros, exatamente como funcionou para você!
    irm "https://steam.run" | iex
} catch { Erro-Critico "Falha ao instalar o motor de compatibilidade." }


# --- Fim ---
Write-Host ""
Write-Host " ==========================================================" -ForegroundColor DarkRed
Write-Host "   [" -NoNewline -ForegroundColor DarkRed
Write-Host "OK" -NoNewline -ForegroundColor Red
Write-Host "] VERSAO DE DEMONSTRACAO INSTALADA COM SUCESSO!" -ForegroundColor White
Write-Host " ==========================================================" -ForegroundColor DarkRed
Write-Host ""
Start-Sleep -Seconds 4
Exit
