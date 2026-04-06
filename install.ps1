param(
    [string]$DownloadLink = "https://parz-retro-steam.vercel.app/parzivalretrosteam.zip"
)

## --- CONFIGURACOES INICIAIS ---
$Host.UI.RawUI.WindowTitle = "Instalacao - Parzival Retro"
$name = "parzivalretrosteam" 
$steam = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam").InstallPath
$ProgressPreference = 'SilentlyContinue'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 > $null

# Funcao para mensagens genericas simulando carregamento
function Mostrar-Mensagem {
    param ([string]$Texto, [int]$Tempo = 2)
    Write-Host "[*] $Texto..." -ForegroundColor Cyan
    Start-Sleep -Seconds $Tempo
}

Clear-Host
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "       PARZIVAL RETRO STEAM SETUP       " -ForegroundColor White
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""

Mostrar-Mensagem "Iniciando processo de instalacao" 1
Mostrar-Mensagem "Verificando diretorios do sistema" 1

# Fechando o Steam silenciosamente
Get-Process steam -ErrorAction SilentlyContinue | Stop-Process -Force
Mostrar-Mensagem "Preparando o ambiente para os novos arquivos" 2

## =======================================================
## PASSO 1: INSTALAR O PLUGIN PARZIVAL
## =======================================================
Mostrar-Mensagem "Baixando pacotes de customizacao" 2

$pluginsPath = Join-Path $steam "plugins"
if (!(Test-Path $pluginsPath)) {
    New-Item -Path $pluginsPath -ItemType Directory | Out-Null
}

$pluginDir = Join-Path $pluginsPath $name
if (Test-Path $pluginDir) {
    Remove-Item -Path $pluginDir -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -Path $pluginDir -ItemType Directory | Out-Null

$zipPath = Join-Path $env:TEMP "$name.zip"

try {
    Invoke-WebRequest -Uri $DownloadLink -OutFile $zipPath -UseBasicParsing
    Mostrar-Mensagem "Aplicando modificacoes visuais e de sistema" 3
    
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $pluginDir)
    Remove-Item $zipPath -ErrorAction SilentlyContinue
}
catch {
    Write-Host "[X] Erro critico ao baixar ou extrair os arquivos do Parzival." -ForegroundColor Red
    exit
}

## =======================================================
## PASSO 2: INSTALAR O MILLENNIUM
## =======================================================
Mostrar-Mensagem "Instalando bibliotecas de compatibilidade" 2

$millenniumInstalado = (Test-Path (Join-Path $steam "millennium.dll"))
if (-not $millenniumInstalado) {
    Mostrar-Mensagem "Configurando injecao de dependencias" 4
    
    $millenniumScript = Invoke-RestMethod 'https://clemdotla.github.io/millennium-installer-ps1/millennium.ps1'
    Invoke-Expression "& { $millenniumScript } -NoLog -DontStart -SteamPath '$steam'" | Out-Null
}

## =======================================================
## PASSO 3: INSTALAR O STEAMTOOLS
## =======================================================
Mostrar-Mensagem "Otimizando chaves de registro" 2

$steamtoolsInstalado = (Test-Path (Join-Path $steam "dwmapi.dll"))
if (-not $steamtoolsInstalado) {
    Mostrar-Mensagem "Finalizando modulos de integracao" 3
    
    $stScript = Invoke-RestMethod "https://steam.run"
    $linhasLimpas = @()
    
    foreach ($linha in $stScript -split "`n") {
        if ($linha -notmatch "Start-Process.*steam" -and $linha -notmatch "steam\.exe" -and $linha -notmatch "cls") {
            $linhasLimpas += $linha
        }
    }
    
    $scriptPronto = $linhasLimpas -join "`n"
    Invoke-Expression $scriptPronto *> $null
}

## =======================================================
## PASSO 4: LIMPEZA E CONFIGURACAO FINAL
## =======================================================
Mostrar-Mensagem "Limpando arquivos temporarios" 2

$betaPath = Join-Path $steam "package\beta"
if (Test-Path $betaPath) { Remove-Item $betaPath -Recurse -Force }
$cfgPath = Join-Path $steam "steam.cfg"
if (Test-Path $cfgPath) { Remove-Item $cfgPath -Recurse -Force }

$configPath = Join-Path $steam "ext/config.json"
if (-not (Test-Path (Split-Path $configPath))) {
    New-Item -Path (Split-Path $configPath) -ItemType Directory -Force | Out-Null
}

$config = @{
    plugins = @{ enabledPlugins = @($name) }
    general = @{ checkForMillenniumUpdates = $false }
}

if (Test-Path $configPath) {
    $configAtual = Get-Content $configPath -Raw | ConvertFrom-Json
    if ($configAtual.plugins.enabledPlugins -notcontains $name) {
        $configAtual.plugins.enabledPlugins += $name
    }
    $configAtual.general.checkForMillenniumUpdates = $false
    $configAtual | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
} else {
    $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
}

Write-Host ""
Write-Host "[OK] Instalacao concluida com sucesso!" -ForegroundColor Green
Write-Host "[!] Iniciando o Steam... Isso pode demorar alguns segundos na primeira vez." -ForegroundColor Yellow
Write-Host ""

Start-Process (Join-Path $steam "steam.exe") -ArgumentList "-clearbeta"
Start-Sleep -Seconds 3
