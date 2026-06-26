# Parzival-Fixer.ps1
# Script dedicado para baixar e aplicar correções via generator.ryuu.lol

param(
    [Parameter(Mandatory=$true)]
    [string]$AppId,
    
    [Parameter(Mandatory=$true)]
    [string]$CaminhoJogo
)

$UrlSite = "https://generator.ryuu.lol/fixes"
$CaminhoTemp = "$env:TEMP\parzival_fix_$AppId.zip"

Write-Host "[Parzival Retrô] Buscando correção para o jogo (AppID: $AppId)..."

try {
    # 1. Acessa o site e puxa o código da página
    $Resposta = Invoke-WebRequest -Uri $UrlSite -UseBasicParsing
    $Conteudo = $Resposta.Content

    # 2. Busca o link exato do .zip atrelado ao AppID passado pelo seu plugin
    $Padrao = "(?is)<tr.*?>.*?$AppId.*?href=`"([^`"]+\.zip)`".*?</tr>"
    $Match = [regex]::Match($Conteudo, $Padrao)

    if ($Match.Success) {
        $UrlRelativa = $Match.Groups[1].Value
        
        # Garante que o link está completo
        if ($UrlRelativa.StartsWith("/")) {
            $UrlDownload = "https://generator.ryuu.lol$UrlRelativa"
        } else {
            $UrlDownload = $UrlRelativa
        }

        Write-Host "[Parzival Retrô] Fix encontrado! Link: $UrlDownload"
        Write-Host "Iniciando download..."
        
        # 3. Baixa o arquivo ZIP para a pasta temporária do Windows
        Invoke-WebRequest -Uri $UrlDownload -OutFile $CaminhoTemp -UseBasicParsing

        Write-Host "Aplicando os arquivos na pasta: $CaminhoJogo"
        
        # 4. Extrai e sobrescreve (-Force) os arquivos diretamente na pasta do jogo
        Expand-Archive -Path $CaminhoTemp -DestinationPath $CaminhoJogo -Force

        # 5. Apaga o ZIP para não deixar lixo no PC do usuário
        Remove-Item -Path $CaminhoTemp -Force

        Write-Host "[Parzival Retrô] Correção aplicada com sucesso!"
    } else {
        Write-Warning "[Parzival Retrô] Nenhum fix encontrado para este AppID no servidor."
    }
}
catch {
    Write-Error "[Parzival Retrô] Falha crítica ao tentar aplicar a correção: $_"
}
