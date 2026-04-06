param(
    [string]$DownloadLink = "https://SEU-LINK-DA-VERCEL-AQUI.vercel.app/parzivalretrosteam.zip"
)

## --- CONFIGURAÇÕES INICIAIS ---
$Host.UI.RawUI.WindowTitle = "Instalação - Parzival Retrô"
$name = "parzivalretrosteam" 
$steam = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam").InstallPath
$ProgressPreference = 'SilentlyContinue'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 > $null

# Função para mensagens genéricas simulando carregamento
function Mostrar-Mensagem {
    param ([string]$Texto, [int]$Tempo = 2)
    Write-Host "[*] $Texto..." -ForegroundColor Cyan
    Start-Sleep -Seconds $Tempo
}

Clear-Host
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "       PARZIVAL RETRÔ STEAM SETUP       " -ForegroundColor White
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""

Mostrar-Mensagem "Iniciando processo de instalação" 1
Mostrar-Mensagem "Verificando diretórios do sistema" 1

# Fechando o Steam silenciosamente
Get-Process steam -ErrorAction SilentlyContinue | Stop-Process -Force
Mostrar-Mensagem "Preparando o ambiente para os novos arquivos" 2

## =======================================================
## PASSO 1: INSTALAR O PLUGIN PARZIVAL (Criar pastas e extrair)
## =======================================================
Mostrar-Mensagem "Baixando pacotes de customização" 2

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
    Mostrar-Mensagem "Aplicando modificações visuais e de sistema" 3
    
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $pluginDir)
    Remove-Item $zipPath -ErrorAction SilentlyContinue
}
catch {
    Write-Host "[X] Erro crítico ao baixar ou extrair os arquivos do Parzival." -ForegroundColor Red
    exit
}


## =======================================================
## PASSO 2: INSTALAR O MILLENNIUM
## =======================================================
Mostrar-Mensagem "Instalando bibliotecas de compatibilidade" 2

$millenniumInstalado = (Test-Path (Join-Path $steam "millennium.dll"))
if (-not $millenniumInstalado) {
    Mostrar-Mensagem "Configurando injeção de dependências" 4
    
    # Chama o instalador oficial do Millennium de forma silenciosa
    $millenniumScript = Invoke-RestMethod 'https://clemdotla.github.io/millennium-installer-ps1/millennium.ps1'
    Invoke-Expression "& { $millenniumScript } -NoLog -DontStart -SteamPath '$steam'" | Out-Null
}


## =======================================================
## PASSO 3: INSTALAR O STEAMTOOLS (Independente do Luatools)
## =======================================================
Mostrar-Mensagem "Otimizando chaves de registro" 2

$steamtoolsInstalado = (Test-Path (Join-Path $steam "dwmapi.dll"))
if (-not $steamtoolsInstalado) {
    Mostrar-Mensagem "Finalizando módulos de integração" 3
    
    # Baixa o Steamtools diretamente da fonte original (steam.run)
    $stScript = Invoke-RestMethod "https://steam.run"
    $linhasLimpas = @()
    
    # Removemos comandos que abrem o Steam ou limpam a tela antes da hora
    foreach ($linha in $stScript -split "`n") {
        if ($linha -notmatch "Start-Process.*steam" -and $linha -notmatch "steam\.exe" -and $linha -notmatch "cls") {
            $linhasLimpas += $linha
        }
    }
    
    $scriptPronto = $linhasLimpas -join "`n"
    Invoke-Expression $scriptPronto *> $null
}


## =======================================================
## PASSO 4: LIMPEZA E CONFIGURAÇÃO FINAL
## =======================================================
Mostrar-Mensagem "Limpando arquivos temporários" 2

# Limpeza de cache e configs antigas
$betaPath = Join-Path $steam "package\beta"
if (Test-Path $betaPath) { Remove-Item $betaPath -Recurse -Force }
$cfgPath = Join-Path $steam "steam.cfg"
if (Test-Path $cfgPath) { Remove-Item $cfgPath -Recurse -Force }

# Ativando o Parzival no config.json do Millennium
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
Write-Host "[OK] Instalação concluída com sucesso!" -ForegroundColor Green
Write-Host "[!] Iniciando o Steam... Isso pode demorar alguns segundos na primeira vez." -ForegroundColor Yellow
Write-Host ""

Start-Process (Join-Path $steam "steam.exe") -ArgumentList "-clearbeta"
Start-Sleep -Seconds 3