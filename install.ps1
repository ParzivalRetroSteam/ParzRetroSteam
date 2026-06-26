param(
    [string]$PluginLink = "https://raw.githubusercontent.com/ParzivalRetroSteam/ParzRetroSteam/main/parzivalretrosteam.zip"
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"iex (irm 'https://raw.githubusercontent.com/ParzivalRetroSteam/ParzRetroSteam/main/install.ps1')`"" -Verb RunAs
    exit
}

$Host.UI.RawUI.WindowTitle = "Parzival Retro Steam - MODO DIAGNOSTICO"
$name  = "parzivalretrosteam"
$ProgressPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 > $null

Clear-Host
Write-Host "`n   [!] INICIANDO MODO RAIO-X (DIAGNOSTICO) [!]`n" -ForegroundColor Yellow

$steam = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -ErrorAction SilentlyContinue).InstallPath
if (-not $steam -or -not (Test-Path $steam)) {
    Write-Host "   [X] Steam não encontrada!" -ForegroundColor Red
    Read-Host "Pressione ENTER para sair"
    exit
}

Write-Host "   > Fechando a Steam..." -ForegroundColor DarkRed
@("steam", "steamservice", "steamwebhelper") | ForEach-Object {
    Get-Process $_ -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}
Start-Sleep -Seconds 2

$millDir = Join-Path $steam "millennium"
if (!(Test-Path $millDir)) { New-Item -Path $millDir -ItemType Directory -Force | Out-Null }
$pluginsPath = Join-Path $millDir "plugins"
if (!(Test-Path $pluginsPath)) { New-Item -Path $pluginsPath -ItemType Directory -Force | Out-Null }
$pluginDir = Join-Path $pluginsPath $name
if (Test-Path $pluginDir) { Remove-Item -Path $pluginDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -Path $pluginDir -ItemType Directory -Force | Out-Null

$zipPath = Join-Path $env:TEMP "$name.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force -ErrorAction SilentlyContinue }

Write-Host "   > Baixando Parzival Retro Steam..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $PluginLink -OutFile $zipPath -UseBasicParsing
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $pluginDir)
    Remove-Item $zipPath -ErrorAction SilentlyContinue
    Write-Host "   [OK] Plugin extraido com sucesso." -ForegroundColor Green
}
catch { 
    Write-Host "   [ERRO NO PLUGIN] $($_.Exception.Message)" -ForegroundColor Red 
}

$configPath = Join-Path $millDir "config\config.json"
$configDir  = Split-Path $configPath
if (-not (Test-Path $configDir)) { New-Item -Path $configDir -ItemType Directory -Force | Out-Null }
try {
    if (Test-Path $configPath) {
        $cfg = Get-Content $configPath -Raw | ConvertFrom-Json
        if (-not $cfg.plugins) { $cfg | Add-Member -MemberType NoteProperty -Name plugins -Value ([PSCustomObject]@{ enabledPlugins = @() }) -Force }
        if (-not $cfg.plugins.enabledPlugins) { $cfg.plugins | Add-Member -MemberType NoteProperty -Name enabledPlugins -Value @() -Force }
        $lista = @($cfg.plugins.enabledPlugins)
        if ($lista -notcontains $name) { $lista += $name }
        $cfg.plugins.enabledPlugins = $lista
        $cfg | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
    } else {
        [PSCustomObject]@{ plugins = [PSCustomObject]@{ enabledPlugins = @($name) } } | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
    }
    Write-Host "   [OK] Registro JSON configurado." -ForegroundColor Green
} catch { 
    Write-Host "   [ERRO NO JSON] $($_.Exception.Message)" -ForegroundColor Red 
}

Write-Host "   > Instalando Steam Tools..." -ForegroundColor Cyan
$stExe = Join-Path $steam "CloudRedirectCLI.exe"
try {
    Invoke-WebRequest -Uri "https://github.com/Selectively11/CloudRedirect/releases/latest/download/CloudRedirectCLI.exe" -OutFile $stExe -UseBasicParsing -TimeoutSec 60
    Start-Process $stExe "/stfixer" -Wait
    if (Test-Path $stExe) { Remove-Item $stExe -Force -ErrorAction SilentlyContinue }
    Write-Host "   [OK] Steam Tools injetado!" -ForegroundColor Green
} catch {
    Write-Host "   [ERRO STEAM TOOLS] $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "   > Instalando Millennium..." -ForegroundColor Cyan
$msUrls = @("https://ps.lua.tools/millennium.ps1", "https://luatools.vercel.app/millennium.ps1")
$msCode = $null
foreach ($url in $msUrls) {
    try { $msCode = Invoke-RestMethod $url -TimeoutSec 15; if ($msCode) { break } } catch { }
}

if ($msCode) {
    try {
        Invoke-Expression "& { $msCode } -NoLog -DontStart -SteamPath '$steam'"
        Write-Host "   [OK] Millennium instalado!" -ForegroundColor Green
    } catch { 
        Write-Host "   [ERRO MILLENNIUM] $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "   [ERRO MILLENNIUM] Falha ao baixar o script do motor." -ForegroundColor Red
}

Write-Host "`n   ==========================================================" -ForegroundColor DarkRed
Write-Host "   PROCESSO FINALIZADO. VEJA SE HOUVE ALGUM ERRO ACIMA." -ForegroundColor White
Write-Host "   ==========================================================`n" -ForegroundColor DarkRed

Read-Host "Pressione ENTER para fechar a janela e abrir a Steam..."

$steamExe = Join-Path $steam "steam.exe"
Start-Process -FilePath $steamExe -ArgumentList "-clearbeta" -WorkingDirectory $steam
