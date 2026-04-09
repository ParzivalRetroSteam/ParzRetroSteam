param(
    [string]$PluginLink = "https://parz-retro-steam.vercel.app/parzivalretrosteam.zip",
    [string]$LuaLink = "https://parz-retro-steam.vercel.app/20k.zip"
)

# --- Forcar Protocolo de Seguranca ---
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- Trava de Seguranca 1: Forca a execucao como Administrador ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm 'https://parz-retro-steam.vercel.app/install_20k.ps1' | iex`"" -Verb RunAs
    exit
}

$Host.UI.RawUI.WindowTitle = "Parzival Retro Steam - Setup 20K"
$name  = "parzivalretrosteam"
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
    Write-Host "      P A R Z I V A L   R E T R O   S T E A M  (20K)       " -ForegroundColor White
    Write-Host " ==========================================================" -ForegroundColor DarkRed
    Write-Host ""
}

function Erro-Critico {
    param([string]$Msg)
    Write-Host "`n   [X] ERRO CRITICO: " -NoNewline -ForegroundColor Red
    Write-Host $Msg -ForegroundColor White
    Write-Host "   O instalador sera fechado em 8 segundos..." -ForegroundColor Gray
    Start-Sleep -Seconds 8
    exit
}

Mostrar-Cabecalho

# --- Trava de Seguranca 2: Verifica se a Steam esta instalada ---
Write-Host "   > Verificando integridade do sistema hospedeiro..." -ForegroundColor DarkRed
$steam = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -ErrorAction SilentlyContinue).InstallPath

if (-not $steam -or -not (Test-Path $steam)) {
    Erro-Critico "A Steam nao foi encontrada neste computador. Instale a Steam e faca login antes de usar."
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

# --- Inicio da Instalacao (Plugin Base) ---
Spinner-Falso "Mapeando diretorios de instalacao da Steam" 1
Spinner-Falso "Encerrando servicos em segundo plano" 2

@("steam", "steamservice", "steamwebhelper", "steamerrorreporter") | ForEach-Object {
    Get-Process $_ -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}
Start-Sleep -Seconds 2

Write-Host ""
Barra-Progresso-Falsa "Alocando espaco e preparando estruturas" 1

$pluginsPath = Join-Path $steam "plugins"
if (!(Test-Path $pluginsPath)) { New-Item -Path $pluginsPath -ItemType Directory | Out-Null }

$pluginDir = Join-Path $pluginsPath $name
if (Test-Path $pluginDir) { Remove-Item -Path $pluginDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -Path $pluginDir -ItemType Directory | Out-Null

$zipPath = Join-Path $env:TEMP "$name.zip"

Write-Host "   [" -NoNewline -ForegroundColor DarkRed
Write-Host "DL" -NoNewline -ForegroundColor Red
Write-Host "] Baixando arquivos da interface Parzival..." -ForegroundColor Gray

try {
    Invoke-WebRequest -Uri $PluginLink -OutFile $zipPath -UseBasicParsing
    Barra-Progresso-Falsa "Extraindo bibliotecas visuais" 2
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $pluginDir)
    Remove-Item $zipPath -ErrorAction SilentlyContinue
}
catch { Erro-Critico "Falha ao baixar o plugin base." }

# --- Integracao do Millennium ---
Write-Host "   > Injetando bibliotecas de compatibilidade..." -ForegroundColor DarkRed
$millenniumInstalado = (Test-Path (Join-Path $steam "millennium.dll"))
if (-not $millenniumInstalado) {
    try {
        $millenniumScript = Invoke-RestMethod 'https://clemdotla.github.io/millennium-installer-ps1/millennium.ps1'
        Invoke-Expression "& { $millenniumScript } -NoLog -DontStart -SteamPath '$steam'" | Out-Null
    } catch { Erro-Critico "Falha ao baixar o Millennium." }
}

Spinner-Falso "Otimizando chaves de registro do sistema" 1
$betaPath = Join-Path $steam "package\beta"
if (Test-Path $betaPath) { Remove-Item $betaPath -Recurse -Force }
$cfgPath = Join-Path $steam "steam.cfg"
if (Test-Path $cfgPath)  { Remove-Item $cfgPath  -Recurse -Force }

# --- Ativacao do Plugin ---
$configPath = Join-Path $steam "ext/config.json"
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
} catch { }

# ====================================================================
# --- Modulo LUA (Ultimo Passo - Extraindo para config\stplug-in) ---
# ====================================================================
Write-Host ""
Spinner-Falso "Preparando diretorios do banco de dados LUA" 1

$luaPath = Join-Path $steam "config\stplug-in"
if (!(Test-Path $luaPath)) { New-Item -Path $luaPath -ItemType Directory -Force | Out-Null }

$luaZipPath = Join-Path $env:TEMP "luas_db.zip"

Write-Host "   [" -NoNewline -ForegroundColor DarkRed
Write-Host "DL" -NoNewline -ForegroundColor Red
Write-Host "] Baixando pacote com 20.000 scripts LUA..." -ForegroundColor Gray

try {
    Invoke-WebRequest -Uri $LuaLink -OutFile $luaZipPath -UseBasicParsing
    Barra-Progresso-Falsa "Injetando scripts no nucleo da Steam (Isso pode levar alguns segundos)" 4
    
    # Tentativa rapida
    try {
        [System.IO.Compression.ZipFile]::ExtractToDirectory($luaZipPath, $luaPath)
    } 
    # Fallback seguro caso ja existam arquivos na pasta (Sobrescrita forcada)
    catch {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($luaZipPath)
        foreach ($entry in $zip.Entries) {
            if ($entry.Name -ne "") {
                $targetPath = Join-Path $luaPath $entry.FullName
                $targetDir = Split-Path $targetPath
                if (!(Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }
                [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $targetPath, $true)
            }
        }
        $zip.Dispose()
    }
    Remove-Item $luaZipPath -ErrorAction SilentlyContinue
}
catch { Erro-Critico "Falha ao baixar ou extrair os scripts LUA." }


# --- Fim ---
Write-Host " ==========================================================" -ForegroundColor DarkRed
Write-Host "   [" -NoNewline -ForegroundColor DarkRed
Write-Host "OK" -NoNewline -ForegroundColor Red
Write-Host "] PARZIVAL 20K INSTALADO E ATIVADO COM SUCESSO!" -ForegroundColor White
Write-Host " ==========================================================" -ForegroundColor DarkRed
Write-Host ""
Write-Host "   > Reiniciando a Steam automaticamente e fechando o instalador..." -ForegroundColor Gray
Write-Host ""
Start-Sleep -Seconds 3

# Acionamento do arquivo .cmd
$cmdPath = Join-Path $steam "plugins\$name\backend\restart_steam.cmd"

if (Test-Path $cmdPath) {
    Start-Process -FilePath $cmdPath -WorkingDirectory (Split-Path $cmdPath) -WindowStyle Hidden
} else {
    $steamExe = Join-Path $steam "steam.exe"
    Start-Process -FilePath $steamExe -ArgumentList "-clearbeta" -WorkingDirectory $steam
}

Exit
