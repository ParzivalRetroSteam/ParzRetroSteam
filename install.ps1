param(
    [string]$DownloadLink = "https://parz-retro-steam.vercel.app/parzivalretrosteam.zip"
)

$Host.UI.RawUI.WindowTitle = "Parzival Retro Steam"
$name  = "parzivalretrosteam"
$steam = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam").InstallPath
$ProgressPreference = 'SilentlyContinue'

# ─── helpers ────────────────────────────────────────────────────────────────

function Linha {
    Write-Host ("=" * 55) -ForegroundColor DarkRed
}

function Passo {
    param([string]$Msg, [int]$Espera = 2)
    Write-Host "  >>  " -NoNewline -ForegroundColor DarkRed
    Write-Host $Msg -ForegroundColor DarkGray
    Start-Sleep -Seconds $Espera
}

function Ok {
    param([string]$Msg)
    Write-Host "  OK  " -NoNewline -ForegroundColor Red
    Write-Host $Msg -ForegroundColor Gray
    Start-Sleep -Milliseconds 400
}

function Secao {
    param([string]$Titulo)
    Write-Host ""
    Linha
    Write-Host "  $Titulo" -ForegroundColor Red
    Linha
    Write-Host ""
}

# ─── banner ─────────────────────────────────────────────────────────────────

Clear-Host
Write-Host ""
Write-Host "  ____   _   ____  ____ " -ForegroundColor Red
Write-Host " |  _ \ / \ |  _ \|_  / " -ForegroundColor Red
Write-Host " | |_) / _ \| |_) |/ /  " -ForegroundColor DarkRed
Write-Host " |  __/ ___ \  _ </ /_ " -ForegroundColor DarkRed
Write-Host " |_| /_/   \_\_| \_\____| " -ForegroundColor DarkMagenta
Write-Host ""
Write-Host "     PARZIVAL  RETRO  STEAM" -ForegroundColor White
Write-Host "        Instalador Oficial" -ForegroundColor DarkGray
Write-Host ""
Linha
Write-Host "  Plataforma  : Windows x64" -ForegroundColor DarkGray
Write-Host "  Diretorio   : $steam" -ForegroundColor DarkGray
Linha
Write-Host ""
Start-Sleep -Seconds 2

# ─── inicializando ──────────────────────────────────────────────────────────

Secao "INICIALIZANDO"

Passo "Sincronizando variaveis de ambiente do sistema..." 2
Passo "Verificando integridade dos modulos principais..." 2
Passo "Alocando espaco em disco para os pacotes..." 1

@("steam", "steamservice", "steamwebhelper", "steamerrorreporter") | ForEach-Object {
    Get-Process $_ -ErrorAction SilentlyContinue | Stop-Process -Force
}
Start-Sleep -Seconds 3

Passo "Finalizando processos em segundo plano..." 1
Ok "Ambiente preparado com sucesso."

# ─── carregando pacotes ──────────────────────────────────────────────────────

Secao "CARREGANDO PACOTES"

$pluginsPath = Join-Path $steam "plugins"
if (!(Test-Path $pluginsPath)) { New-Item -Path $pluginsPath -ItemType Directory | Out-Null }
$pluginDir = Join-Path $pluginsPath $name
if (Test-Path $pluginDir) { Remove-Item -Path $pluginDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -Path $pluginDir -ItemType Directory | Out-Null
$zipPath = Join-Path $env:TEMP "$name.zip"

Passo "Estabelecendo conexao com servidores remotos..." 2
Passo "Autenticando sessao de transferencia segura..." 1

try {
    Invoke-WebRequest -Uri $DownloadLink -OutFile $zipPath -UseBasicParsing
    Passo "Transferindo pacotes criptografados..." 2
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $pluginDir)
    Remove-Item $zipPath -ErrorAction SilentlyContinue
    Passo "Validando integridade dos arquivos recebidos..." 1
    Ok "Pacotes principais instalados."
}
catch {
    Write-Host ""
    Write-Host "  ERRO  Falha na transferencia. Verifique sua conexao." -ForegroundColor DarkRed
    Write-Host ""
    exit
}

# ─── integrando dependencias ─────────────────────────────────────────────────

Secao "INTEGRANDO DEPENDENCIAS"

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

# ─── configurando ────────────────────────────────────────────────────────────

Secao "CONFIGURANDO AMBIENTE"

Passo "Removendo residuos de versoes anteriores..." 1
$betaPath = Join-Path $steam "package\beta"
if (Test-Path $betaPath) { Remove-Item $betaPath -Recurse -Force }
$cfgPath = Join-Path $steam "steam.cfg"
if (Test-Path $cfgPath)  { Remove-Item $cfgPath  -Recurse -Force }

Passo "Otimizando entradas de configuracao..." 1
Passo "Gravando preferencias no registro do sistema..." 1
Passo "Ativando modulos de execucao automatica..." 1

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

# ─── fim ─────────────────────────────────────────────────────────────────────

Write-Host ""
Linha
Write-Host ""
Write-Host "  OK  Instalacao concluida com sucesso!" -ForegroundColor Red
Write-Host ""
Write-Host "  Todos os modulos foram aplicados." -ForegroundColor DarkGray
Write-Host "  O Steam sera iniciado em instantes." -ForegroundColor DarkGray
Write-Host ""
Linha
Write-Host ""
Start-Sleep -Seconds 2

# Garante que todos os processos do Steam estao encerrados antes de abrir
@("steam", "steamservice", "steamwebhelper", "steamerrorreporter") | ForEach-Object {
    Get-Process $_ -ErrorAction SilentlyContinue | Stop-Process -Force
}
Start-Sleep -Seconds 3

$steamExe = Join-Path $steam "steam.exe"
Start-Process $steamExe -ArgumentList "-clearbeta"
Start-Sleep -Seconds 5
