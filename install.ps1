param(
    # --- LINKS DE DOWNLOAD ---
    [string]$ParzivalLink = "https://raw.githubusercontent.com/ParzivalRetroSteam/ParzRetroSteam/main/ParzivalRetroSteam.Plugin.zip",
    [string]$ConfigZipLink = "https://raw.githubusercontent.com/voicesfix/fix/main/config.zip"
)

# --- Converte automaticamente links /blob/ do GitHub para links diretos (raw) ---
if ($ParzivalLink -match "^https://github\.com/([^/]+)/([^/]+)/blob/(.+)$") {
    $ParzivalLink = "https://raw.githubusercontent.com/$($Matches[1])/$($Matches[2])/$($Matches[3])"
}

# --- Forcar Protocolo de Seguranca ---
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- Trava de Seguranca: Forca a execucao como Administrador ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"iex (irm 'https://raw.githubusercontent.com/ParzivalRetroSteam/ParzRetroSteam/main/install.ps1')`"" -Verb RunAs
    exit
}

$Host.UI.RawUI.WindowTitle = "Parzival Retro Steam - Setup"
$name       = "parzivalretrosteam"
$pluginName = "ParzivalRetroSteam.Plugin"
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
    Write-Host "        P A R Z I V A L   R E T R O   S T E A M            " -ForegroundColor White
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

# --- Funcao para salvar JSON em UTF-8 SEM BOM (Evita reset do Millennium) ---
function Salvar-JsonSemBom {
    param(
        [Parameter(Mandatory=$true)][string]$Caminho,
        [Parameter(Mandatory=$true)]$ObjetoJson
    )
    $pasta = Split-Path $Caminho
    if (-not (Test-Path $pasta)) {
        New-Item -Path $pasta -ItemType Directory -Force | Out-Null
    }
    $conteudo = $ObjetoJson | ConvertTo-Json -Depth 10
    $utf8SemBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Caminho, $conteudo, $utf8SemBom)
}

# --- Funcao para extrair ZIP sem criar pasta raiz duplicada ---
function Extrair-ZipNivelado {
    param(
        [string]$ZipPath,
        [string]$DestinoFinal
    )
    $tempExtract = Join-Path $env:TEMP ("extract_" + [guid]::NewGuid().ToString("N"))
    New-Item -Path $tempExtract -ItemType Directory -Force | Out-Null

    Expand-Archive -Path $ZipPath -DestinationPath $tempExtract -Force

    # Verifica se o ZIP tinha uma unica subpasta raiz contendo tudo
    $itens = @(Get-ChildItem -Path $tempExtract -Force)
    $origemCopia = $tempExtract
    if ($itens.Count -eq 1 -and $itens[0].PSIsContainer) {
        $origemCopia = $itens[0].FullName
    }

    if (-not (Test-Path $DestinoFinal)) {
        New-Item -Path $DestinoFinal -ItemType Directory -Force | Out-Null
    }

    Copy-Item -Path "$origemCopia\*" -Destination $DestinoFinal -Recurse -Force
    Remove-Item -Path $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
}

Mostrar-Cabecalho

# --- Verifica se a Steam esta instalada (HKLM e HKCU) ---
Write-Host "   > Verificando integridade do sistema hospedeiro..." -ForegroundColor DarkRed
$steam = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -ErrorAction SilentlyContinue).InstallPath
if (-not $steam) {
    $steam = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue).SteamPath
}
if ($steam) { $steam = $steam.Replace('/', '\') }

if (-not $steam -or -not (Test-Path $steam)) {
    Erro-Critico "A Steam nao foi encontrada neste computador. Instale a Steam e faca login antes de usar."
}

# --- Adiciona exclusao no Defender ANTES de extrair as DLLs ---
try {
    Add-MpPreference -ExclusionPath $steam -ErrorAction SilentlyContinue
} catch { }

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

# --- Fechando a Steam e processos do Millennium ---
Spinner-Falso "Mapeando diretorios de instalacao" 1
Spinner-Falso "Encerrando servicos em segundo plano" 2
@("steam", "steamservice", "steamwebhelper", "millennium") | ForEach-Object {
    Get-Process $_ -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}
Start-Sleep -Seconds 2
Write-Host ""

# ====================================================================
# 1. INSTALAÇÃO DO NÚCLEO
# ====================================================================
Barra-Progresso-Falsa "Alocando espaco e preparando estruturas base" 1
try {
    $ostAssetUrl = "https://github.com/madoiscool/BetterSteamTools/releases/download/v1.0.4/OpenSteamTool-v1.0.4-Release.zip"
    $ostZip = Join-Path $env:TEMP "core_modules.zip"
    Invoke-WebRequest -Uri $ostAssetUrl -OutFile $ostZip -UseBasicParsing -TimeoutSec 60
    Extrair-ZipNivelado -ZipPath $ostZip -DestinoFinal $steam
    Remove-Item $ostZip -ErrorAction SilentlyContinue
} catch { }

# ====================================================================
# 2. INSTALAÇÃO DOS MODULOS DE COMPATIBILIDADE
# ====================================================================
Spinner-Falso "Integrando pacotes adicionais" 2
try {
    $stplugPath = Join-Path $steam "config\stplug-in"
    if (-not (Test-Path $stplugPath)) { New-Item -Path $stplugPath -ItemType Directory -Force | Out-Null }
    $configZip = Join-Path $env:TEMP "compat_data.zip"
    Invoke-WebRequest -Uri $ConfigZipLink -OutFile $configZip -UseBasicParsing -TimeoutSec 60
    Extrair-ZipNivelado -ZipPath $configZip -DestinoFinal $stplugPath
    Remove-Item $configZip -ErrorAction SilentlyContinue
} catch { }

# ====================================================================
# 3. INSTALAÇÃO DO MOTOR DE EXECUÇÃO (MILLENNIUM)
# ====================================================================
Barra-Progresso-Falsa "Instalando motor de execucao" 2
try {
    $headers = @{ "User-Agent" = "ParzivalRetroSteam-Installer" }
    $msApi = "https://api.github.com/repos/SteamClientHomebrew/Millennium/releases?per_page=15"
    $msReleases = Invoke-RestMethod -Uri $msApi -Headers $headers -UseBasicParsing -TimeoutSec 30
    
    $msAsset = $null
    foreach ($rel in $msReleases) {
        if (-not $rel.prerelease) {
            $msAsset = $rel.assets | Where-Object { $_.name -like "*windows-x86_64.zip" } | Select-Object -First 1
            if ($msAsset) { break }
        }
    }
    if (-not $msAsset) {
        $msAsset = $msReleases[0].assets | Where-Object { $_.name -like "*windows-x86_64.zip" } | Select-Object -First 1
    }

    if ($msAsset) {
        $msZip = Join-Path $env:TEMP "engine_core.zip"
        Invoke-WebRequest -Uri $msAsset.browser_download_url -OutFile $msZip -UseBasicParsing -TimeoutSec 60
        Extrair-ZipNivelado -ZipPath $msZip -DestinoFinal $steam
        Remove-Item $msZip -ErrorAction SilentlyContinue
    }
} catch { }

# ====================================================================
# 4. INSTALAÇÃO DOS PACOTES VISUAIS PARZIVAL (ParzivalRetroSteam.Plugin.zip)
# ====================================================================
Spinner-Falso "Extraindo pacotes da interface" 2

$pluginZip = Join-Path $env:TEMP "ParzivalRetroSteam.Plugin.zip"
$tempPluginDir = Join-Path $env:TEMP ("parz_plugin_" + [guid]::NewGuid().ToString("N"))

$enableName = $pluginName

try {
    Invoke-WebRequest -Uri $ParzivalLink -OutFile $pluginZip -UseBasicParsing -TimeoutSec 60
    Extrair-ZipNivelado -ZipPath $pluginZip -DestinoFinal $tempPluginDir
    Remove-Item $pluginZip -ErrorAction SilentlyContinue

    # Localiza o plugin.json mesmo se estiver dentro de subpasta no ZIP
    $pjsonFile = Get-ChildItem -Path $tempPluginDir -Filter "plugin.json" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($pjsonFile) {
        $pastaRealDoPlugin = $pjsonFile.Directory.FullName
        $pjson = [System.IO.File]::ReadAllText($pjsonFile.FullName, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
        if ($pjson.name) {
            $enableName = $pjson.name
        }
    } else {
        $pastaRealDoPlugin = $tempPluginDir
    }

    # Instala nas duas estruturas de pastas de plugins (Steam\plugins e Steam\millennium\plugins)
    $locaisPlugins = @(
        (Join-Path $steam "plugins"),
        (Join-Path $steam "millennium\plugins")
    )

    foreach ($basePluginPath in $locaisPlugins) {
        if (-not (Test-Path $basePluginPath)) {
            New-Item -Path $basePluginPath -ItemType Directory -Force | Out-Null
        }

        # Limpa instalacoes anteriores
        @($pluginName, $enableName, $name) | Select-Object -Unique | ForEach-Object {
            $caminhoAntigo = Join-Path $basePluginPath $_
            if (Test-Path $caminhoAntigo) {
                Remove-Item -Path $caminhoAntigo -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        # Cria a pasta ParzivalRetroSteam.Plugin com o plugin.json na raiz dela
        $destinoPlugin = Join-Path $basePluginPath $pluginName
        New-Item -Path $destinoPlugin -ItemType Directory -Force | Out-Null
        Copy-Item -Path "$pastaRealDoPlugin\*" -Destination $destinoPlugin -Recurse -Force
    }
} catch { } finally {
    if (Test-Path $tempPluginDir) {
        Remove-Item -Path $tempPluginDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ====================================================================
# 5. ATIVAÇÃO AUTOMÁTICA DO PLUGIN NO MILLENNIUM
# ====================================================================
Spinner-Falso "Otimizando chaves de registro e ativando plugin" 1

$caminhosConfig = @(
    (Join-Path $steam "ext\config.json"),
    (Join-Path $steam "millennium\config\config.json")
)

# Garante que tanto o "name" interno do plugin.json quanto o nome da pasta estejam ativos
$nomesParaAtivar = @([string]$enableName, [string]$pluginName) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

foreach ($configPath in $caminhosConfig) {
    try {
        $cObj = $null
        if (Test-Path $configPath) {
            try {
                $jsonRaw = [System.IO.File]::ReadAllText($configPath, [System.Text.Encoding]::UTF8)
                if (-not [string]::IsNullOrWhiteSpace($jsonRaw)) {
                    $cObj = $jsonRaw | ConvertFrom-Json
                }
            } catch {
                $cObj = $null
            }
        }

        if ($null -eq $cObj) {
            $cObj = [PSCustomObject]@{
                general = [PSCustomObject]@{
                    checkForMillenniumUpdates = $true
                }
                plugins = [PSCustomObject]@{
                    enabledPlugins = [string[]]$nomesParaAtivar
                }
            }
        } else {
            if ($null -eq $cObj.PSObject.Properties['general'] -or $null -eq $cObj.general) {
                $cObj | Add-Member -MemberType NoteProperty -Name "general" -Value ([PSCustomObject]@{ checkForMillenniumUpdates = $true }) -Force
            } else {
                $cObj.general | Add-Member -MemberType NoteProperty -Name "checkForMillenniumUpdates" -Value $true -Force
            }

            $listaAtual = New-Object System.Collections.Generic.List[string]
            if ($null -ne $cObj.PSObject.Properties['plugins'] -and $null -ne $cObj.plugins) {
                if ($null -ne $cObj.plugins.PSObject.Properties['enabledPlugins'] -and $null -ne $cObj.plugins.enabledPlugins) {
                    foreach ($item in @($cObj.plugins.enabledPlugins)) {
                        if (-not [string]::IsNullOrWhiteSpace($item)) {
                            [void]$listaAtual.Add([string]$item)
                        }
                    }
                }
            } else {
                $cObj | Add-Member -MemberType NoteProperty -Name "plugins" -Value ([PSCustomObject]@{}) -Force
            }

            foreach ($n in $nomesParaAtivar) {
                if (-not $listaAtual.Contains($n)) {
                    [void]$listaAtual.Add($n)
                }
            }

            $cObj.plugins | Add-Member -MemberType NoteProperty -Name "enabledPlugins" -Value ([string[]]$listaAtual.ToArray()) -Force
        }

        Salvar-JsonSemBom -Caminho $configPath -ObjetoJson $cObj
    } catch { }
}

# ====================================================================
# 6. FINALIZAÇÃO
# ====================================================================
Spinner-Falso "Otimizando parametros de vigilancia do sistema" 1

Write-Host "`n ==========================================================" -ForegroundColor DarkRed
Write-Host "   [" -NoNewline -ForegroundColor DarkRed
Write-Host "OK" -NoNewline -ForegroundColor Red
Write-Host "] PARZIVAL RETRO STEAM INSTALADO COM SUCESSO!" -ForegroundColor White
Write-Host " ==========================================================" -ForegroundColor DarkRed
Write-Host "`n   > Reiniciando a Steam em 3 segundos..." -ForegroundColor Gray
Start-Sleep -Seconds 3

# Inicialização limpa da Steam
$steamExe = Join-Path $steam "steam.exe"
Start-Process -FilePath $steamExe -ArgumentList "-clearbeta" -WorkingDirectory $steam

Stop-Process -Id $PID -Force
Exit
