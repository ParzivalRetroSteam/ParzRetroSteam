param(
    [string]$PluginLink = "https://parz-retro-steam.vercel.app/parzivalretrosteam.zip"
)

# --- Forçar Protocolo de Segurança ---
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- Trava de Segurança 1: Forçar a execução como Administrador ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm 'https://parz-retro-steam.vercel.app/install.ps1' | iex`"" -Verb RunAs
    exit
}

$Host.UI.RawUI.WindowTitle = "Parzival Retro Steam - Setup"
$name  = "parzivalretrosteam"
$ProgressPreference = 'SilentlyContinue'

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
    Write-Host "         P A R Z I V A L   R E T R O   S T E A M           " -ForegroundColor White
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
# --- SISTEMA DE LICENÇA ---
# ====================================================================
Write-Host "   > PROCESSO DE AUTENTICACAO" -ForegroundColor DarkRed
$chaveDigitada = Read-Host "   [?] Digite sua Chave de Acesso"
$chaveLimpa = $chaveDigitada.Trim().ToLower()
$tokenDb = "czFtcGxlcw==" 
$tokenValido = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($tokenDb))

if ($chaveLimpa -ne $tokenValido) {
    Erro-Critico "Chave de acesso invalida."
}
Write-Host "   [OK] Licenca verificada!" -ForegroundColor Green
Start-Sleep -Seconds 1

# --- Verificação da Steam ---
$steam = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -ErrorAction SilentlyContinue).InstallPath
if (-not $steam -or -not (Test-Path $steam)) { Erro-Critico "Steam nao encontrada." }

# --- Preparação ---
Write-Host "   > Encerrando servicos Steam..." -ForegroundColor Gray
@("steam", "steamservice", "steamwebhelper") | ForEach-Object { Get-Process $_ -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 2

# ====================================================================
# --- 1. INSTALANDO SEU PLUGIN (PARZIVAL RETRO) ---
# ====================================================================
$pluginsPath = Join-Path $steam "plugins"
if (!(Test-Path $pluginsPath)) { New-Item -Path $pluginsPath -ItemType Directory | Out-Null }

$pluginDir = Join-Path $pluginsPath $name
if (Test-Path $pluginDir) { Remove-Item -Path $pluginDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -Path $pluginDir -ItemType Directory | Out-Null

$zipPath = Join-Path $env:TEMP "$name.zip"
Write-Host "   > Baixando e extraindo seu plugin..." -ForegroundColor Cyan

try {
    Invoke-WebRequest -Uri $PluginLink -OutFile $zipPath -UseBasicParsing
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $pluginDir)
    Remove-Item $zipPath -ErrorAction SilentlyContinue
} catch { Erro-Critico "Falha ao baixar arquivos Parzival." }

# ====================================================================
# --- 2. RODANDO O COMANDO OFICIAL (STEAM.RUN) POR ÚLTIMO ---
# ====================================================================
Write-Host ""
Write-Host "   > Acionando motor estrutural final..." -ForegroundColor DarkRed
try {
    # Aqui entra o comando isolado para não travar seu script
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm steam.run | iex`"" -Wait
} catch { 
    Write-Host "   [!] Erro no comando final, mas o plugin ja esta na pasta." -ForegroundColor Yellow 
}

# --- Fim ---
Write-Host ""
Write-Host " ==========================================================" -ForegroundColor DarkRed
Write-Host "   [OK] INSTALACAO CONCLUIDA COM SUCESSO!" -ForegroundColor White
Write-Host " ==========================================================" -ForegroundColor DarkRed
Write-Host ""
Start-Sleep -Seconds 2

# Reinicia a Steam
$steamExe = Join-Path $steam "steam.exe"
Start-Process -FilePath $steamExe -ArgumentList "-clearbeta" -WorkingDirectory $steam

Stop-Process -Id $PID -Force
