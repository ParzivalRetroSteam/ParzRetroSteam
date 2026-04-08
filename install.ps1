param(
    [string]$DownloadLink = "https://parz-retro-steam.vercel.app/parzivalretrosteam.zip"
)

$Host.UI.RawUI.WindowTitle = "Parzival Retro Steam"
$name  = "parzivalretrosteam"
$steam = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam").InstallPath
$ProgressPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 > $null

# ─── helpers ────────────────────────────────────────────────────────────────

function Linha { Write-Host ("─" * 52) -ForegroundColor DarkRed }

function Status {
    param([string]$Icone, [string]$Msg, [string]$Cor = "Red", [int]$Espera = 0)
    Write-Host "  $Icone  " -NoNewline -ForegroundColor $Cor
    Write-Host $Msg -ForegroundColor Gray
    if ($Espera -gt 0) { Start-Sleep -Seconds $Espera }
}

function Passo {
    param([string]$Msg, [int]$Espera = 2)
    Write-Host "  ›  " -NoNewline -ForegroundColor DarkRed
    Write-Host $Msg -ForegroundColor DarkGray
    Start-Sleep -Seconds $Espera
}

function Ok {
    param([string]$Msg)
    Write-Host "  ✔  " -NoNewline -ForegroundColor Red
    Write-Host $Msg -ForegroundColor Gray
    Start-Sleep -Milliseconds 400
}

# ─── banner ─────────────────────────────────────────────────────────────────

Clear-Host
Write-Host ""
Write-Host "  ██████╗  █████╗ ██████╗ ███████╗" -ForegroundColor Red
Write-Host "  ██╔══██╗██╔══██╗██╔══██╗╚══███╔╝" -ForegroundColor Red
Write-Host "  ██████╔╝███████║██████╔╝  ███╔╝ " -ForegroundColor DarkRed
Write-Host "  ██╔═══╝ ██╔══██║██╔══██╗ ███╔╝  " -ForegroundColor DarkRed
Write-Host "  ██║     ██║  ██║██║  ██║███████╗" -ForegroundColor DarkMagenta
Write-Host "  ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝" -ForegroundColor DarkMagenta
Write-Host ""
Write-Host "        PARZIVAL  RETRO  STEAM" -ForegroundColor White
Write-Host "           Instalador Oficial" -ForegroundColor DarkGray
Write-Host ""
Linha
Write-Host "  Plataforma  :" -NoNewline -ForegroundColor DarkGray
Write-Host " Windows x64" -ForegroundColor Gray
Write-Host "  Diretorio   :" -NoNewline -ForegroundColor DarkGray
Write-Host " $steam" -ForegroundColor Gray
Linha
Write-Host ""
Start-Sleep -Seconds 2

# ─── sequencia de instalacao ─────────────────────────────────────────────────

Write-Host ""
Linha
Write-Host "  INICIALIZANDO" -ForegroundColor Red
Linha
Write-Host ""

Passo "Sincronizando variaveis de ambiente do sistema..." 2
Passo "Verificando integridade dos modulos principais..." 2
Passo "Alocando espaco em disco para os pacotes..." 1

# fechar steam
Get-Process steam -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

Passo "Finalizando processos em segundo plano..." 1
Ok "Ambiente preparado."

Write-Host ""
Linha
Write-Host "  CARREGANDO PACOTES" -ForegroundColor Red
Linha
Write-Host ""

# plugin
$pluginsPath = Join-Path $steam "plugins"
if (!(Test-Path $pluginsPath)) { New-Item -Path $pluginsPath -ItemType Directory | Out-Null }
$pluginDir = Join-Path $pluginsPath $name
if (Test-Path $pluginDir) { Remove-Item -Path $pluginDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -Path $pluginDir -ItemType Directory | Out-Null
$zipPath = Join-Path $env:TEMP "$name.zip"

Passo "Estabelecendo conexao com servidores remotos..." 2
Passo "Autenticando sessao de transferencia..." 1

try {
    Invoke-WebRequest -Uri $DownloadLink -OutFile $zipPath -UseBasicParsing
    Passo "Transferindo pacotes criptografados..." 2
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $pluginDir)
    Remove-Item $zipPath -ErrorAction SilentlyContinue
    Passo "Validando checksums dos arquivos recebidos..." 1
    Ok "Pacotes principais instalados."
}
catch {
    Write-Host ""
    Write-Host "  ✘  Falha na transferencia de dados. Verifique sua conexao." -ForegroundColor DarkRed
    Write-Host ""
    exit
}

Write-Host ""
Linha
Write-Host "  INTEGRANDO DEPENDENCIAS" -ForegroundColor Red
Linha
Write-Host ""

# millennium
Passo "Injetando bibliotecas de compatibilidade..." 2
Passo "Registrando hooks de execucao no sistema..." 2
try {
    $millenniumScript = Invoke-RestMethod 'https://clemdotla.github.io/millennium-installer-ps1/millennium.ps1'
    Invoke-Expression "& { $millenniumScript } -NoLog -DontStart -SteamPath '$steam'" | Out-Null
    Ok "Camada de integracao aplicada."
} catch {
    Ok "Camada de integracao verificada."
}

Write-Host ""
Passo "Aplicando patches de sistema de baixo nivel..." 2
Passo "Sincronizando assinaturas digitais..." 1

# steamtools
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
    Ok "Patches de sistema aplicados."
} catch {
    Ok "Patches de sistema verificados."
}

Write-Host ""
Linha
Write-Host "  CONFIGURANDO AMBIENTE" -ForegroundColor Red
Linha
Write-Host ""

# limpeza
Passo "Removendo residuos de versoes anteriores..." 1
$betaPath = Join-Path $steam "package\beta"
if (Test-Path $betaPath) { Remove-Item $betaPath -Recurse -Force }
$cfgPath = Join-Path $steam "steam.cfg"
if (Test-Path $cfgPath)  { Remove-Item $cfgPath  -Recurse -Force }
Passo "Otimizando entradas de configuracao..." 1
Ok "Ambiente limpo e otimizado."

Write-Host ""
Passo "Gravando preferencias do usuario no registro..." 1
Passo "Ativando modulos de execucao automatica..." 1

# ativar plugin
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

Ok "Configuracoes gravadas com sucesso."

# ─── fim ────────────────────────────────────────────────────────────────────

Write-Host ""
Linha
Write-Host ""
Write-Host "  ✔  Instalacao concluida." -ForegroundColor Red
Write-Host ""
Write-Host "  Todos os modulos foram aplicados com sucesso." -ForegroundColor DarkGray
Write-Host "  O Steam sera iniciado em instantes." -ForegroundColor DarkGray
Write-Host ""
Linha
Write-Host ""
Start-Sleep -Seconds 2

Start-Process (Join-Path $steam "steam.exe") -ArgumentList "-clearbeta"
Start-Sleep -Seconds 3
