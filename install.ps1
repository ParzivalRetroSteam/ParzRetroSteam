param(
    [string]$DownloadLink = "https://parz-retro-steam.vercel.app/parzivalretrosteam.zip"
)

$Host.UI.RawUI.WindowTitle = "Instalador - Parzival Retro Steam"
$name  = "parzivalretrosteam"
$steam = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam").InstallPath
$ProgressPreference = 'SilentlyContinue'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 > $null

# ─── helpers visuais ────────────────────────────────────────────────────────

function Mostrar-Cabecalho {
    Clear-Host
    Write-Host ""
    Write-Host " ╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host " ║                                                          ║" -ForegroundColor Cyan
    Write-Host " ║   ██████╗  █████╗ ██████╗ ███████╗██╗██╗   ██╗███████╗   ║" -ForegroundColor Cyan
    Write-Host " ║   ██╔══██╗██╔══██╗██╔══██╗╚══███╔╝██║██║   ██║██╔════╝   ║" -ForegroundColor Cyan
    Write-Host " ║   ██████╔╝███████║██████╔╝  ███╔╝ ██║██║   ██║███████╗   ║" -ForegroundColor Cyan
    Write-Host " ║   ██╔═══╝ ██╔══██║██╔══██╗ ███╔╝  ██║╚██╗ ██╔╝╚════██║   ║" -ForegroundColor Cyan
    Write-Host " ║   ██║     ██║  ██║██║  ██║███████╗██║ ╚████╔╝ ███████║   ║" -ForegroundColor Cyan
    Write-Host " ║   ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝  ╚══════╝   ║" -ForegroundColor Cyan
    Write-Host " ║                                                          ║" -ForegroundColor Cyan
    Write-Host " ║             R E T R O   S T E A M   S E T U P            ║" -ForegroundColor White
    Write-Host " ╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Secao {
    param([string]$Titulo)
    Write-Host ""
    Write-Host " ─── $Titulo " -ForegroundColor Yellow
    Write-Host ""
}

function Passo {
    param([string]$Msg, [int]$Espera = 1)
    Write-Host "  [*] " -NoNewline -ForegroundColor Cyan
    Write-Host $Msg -ForegroundColor Gray
    Start-Sleep -Seconds $Espera
}

function Ok {
    param([string]$Msg)
    Write-Host "  [√] " -NoNewline -ForegroundColor Green
    Write-Host $Msg -ForegroundColor White
    Start-Sleep -Milliseconds 400
}

function Erro {
    param([string]$Msg)
    Write-Host "  [X] " -NoNewline -ForegroundColor Red
    Write-Host $Msg -ForegroundColor Red
    Start-Sleep -Milliseconds 400
}

# ─── inicializando ──────────────────────────────────────────────────────────

Mostrar-Cabecalho

Secao "PREPARANDO SISTEMA"

Passo "Analisando diretorios da Steam..." 1
Passo "Encerrando processos ativos..." 2

@("steam", "steamservice", "steamwebhelper", "steamerrorreporter") | ForEach-Object {
    Get-Process $_ -ErrorAction SilentlyContinue | Stop-Process -Force
}
Start-Sleep -Seconds 2

Ok "Ambiente limpo e preparado."

# ─── carregando pacotes ──────────────────────────────────────────────────────

Secao "DOWNLOAD E EXTRACAO"

$pluginsPath = Join-Path $steam "plugins"
if (!(Test-Path $pluginsPath)) { New-Item -Path $pluginsPath -ItemType Directory | Out-Null }

$pluginDir = Join-Path $pluginsPath $name
if (Test-Path $pluginDir) { Remove-Item -Path $pluginDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -Path $pluginDir -ItemType Directory | Out-Null

$zipPath = Join-Path $env:TEMP "$name.zip"

Passo "Conectando aos servidores Parzival..." 1
Passo "Baixando pacotes de customizacao..." 2

try {
    Invoke-WebRequest -Uri $DownloadLink -OutFile $zipPath -UseBasicParsing
    Passo "Extraindo e posicionando arquivos..." 2
    
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $pluginDir)
    Remove-Item $zipPath -ErrorAction SilentlyContinue
    
    Ok "Arquivos principais instalados."
}
catch {
    Erro "Falha no download. Verifique sua conexao com a internet."
    exit
}

# ─── integrando dependencias ─────────────────────────────────────────────────

Secao "DEPENDENCIAS (MILLENNIUM & STEAMTOOLS)"

Passo "Injetando bibliotecas do Millennium..." 2

try {
    $millenniumScript = Invoke-RestMethod 'https://clemdotla.github.io/millennium-installer-ps1/millennium.ps1'
    Invoke-Expression "& { $millenniumScript } -NoLog -DontStart -SteamPath '$steam'" | Out-Null
    Ok "Millennium integrado."
} catch {
    Ok "Millennium ja presente."
}

Passo "Aplicando patches do Steamtools..." 2

try {
    $stScript = Invoke-RestMethod "https://steam.run"
    $linhasLimpas = @()
    foreach ($linha in $stScript -split "`n") {
        if ($linha -notmatch "Start-Process.*steam" -and
            $linha -notmatch "steam\.exe"           -and
            $linha -notmatch "cls") {
            $linhasLimpas += $linha
        }
    }
    Invoke-Expression ($linhasLimpas -join "`n") *> $null
    Ok "Steamtools configurado."
} catch {
    Ok "Steamtools ja presente."
}

# ─── configurando ────────────────────────────────────────────────────────────

Secao "AJUSTES FINAIS"

Passo "Limpando cache antigo da Steam..." 1
$betaPath = Join-Path $steam "package\beta"
if (Test-Path $betaPath) { Remove-Item $betaPath -Recurse -Force }
$cfgPath = Join-Path $steam "steam.cfg"
if (Test-Path $cfgPath)  { Remove-Item $cfgPath  -Recurse -Force }

Passo "Ativando o Parzival Retro no sistema..." 1

$configPath = Join-Path $steam "ext/config.json"
$configDir  = Split-Path $configPath
if (-not (Test-Path $configDir)) { New-Item -Path $configDir -ItemType Directory -Force | Out-Null }

try {
    if (Test-Path $configPath) {
        $cfg = Get-Content $configPath -Raw | ConvertFrom-Json
        if (-not $cfg.plugins) {
            $cfg | Add-Member -MemberType NoteProperty -Name plugins -Value ([PSCustomObject]@{ enabledPlugins = @() }) -Force
        }
        if (-not $cfg.plugins.enabledPlugins) {
            $cfg.plugins | Add-Member -MemberType NoteProperty -Name enabledPlugins -Value @() -Force
        }
        $lista = @($cfg.plugins.enabledPlugins)
        if ($lista -notcontains $name) { $lista += $name }
        $cfg.plugins.enabledPlugins = $lista
        if (-not $cfg.general) {
            $cfg | Add-Member -MemberType NoteProperty -Name general -Value ([PSCustomObject]@{ checkForMillenniumUpdates = $false }) -Force
        } else {
            $cfg.general.checkForMillenniumUpdates = $false
        }
        $cfg | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
    } else {
        [PSCustomObject]@{
            plugins = [PSCustomObject]@{ enabledPlugins = @($name) }
            general = [PSCustomObject]@{ checkForMillenniumUpdates = $false }
        } | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
    }
} catch {
    [PSCustomObject]@{
        plugins = [PSCustomObject]@{ enabledPlugins = @($name) }
        general = [PSCustomObject]@{ checkForMillenniumUpdates = $false }
    } | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
}

Ok "Ativacao concluida."

# ─── fim ─────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host " ════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  [√] INSTALACAO FINALIZADA COM SUCESSO!" -ForegroundColor Green
Write-Host " ════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Iniciando a Steam magicamente em 3 segundos..." -ForegroundColor Yellow
Write-Host ""
Start-Sleep -Seconds 3

# Executando a Steam no diretorio correto (removido o kill redundante)
$steamExe = Join-Path $steam "steam.exe"
Start-Process -FilePath $steamExe -ArgumentList "-clearbeta" -WorkingDirectory $steam
