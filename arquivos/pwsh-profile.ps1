# ===========================================================================
#  Perfil do PowerShell 7
#
#  Oh My Posh ....... prompt  (tema powerlevel10k_rainbow)
#  Terminal-Icons ... icones no ls / Get-ChildItem  (lazy load)
#  Posh-Git ......... autocomplete de git  (so em repos git)
#  PSFzf ............ Ctrl+R (historico) e Ctrl+F (caminhos)  [exige binario fzf]
#  Zoxide ........... navegacao inteligente de diretorios
#  PSReadLine ....... Tab, setas de historico, previsoes e tooltips
#
#  Modulos (PSGallery, -Scope CurrentUser):
#    Terminal-Icons, Posh-Git, PSFzf
#  Binarios (Scoop):
#    oh-my-posh, fzf, zoxide, delta, lazygit
# ===========================================================================

# --- Saida ANSI ------------------------------------------------------------
# Sem isso o PowerShell CORTA as sequencias de escape dos comandos nativos
# (rg, delta, fzf...) quando a saida e capturada por um pipe ou pelo WSL.
if ($PSStyle -and $PSVersionTable.PSVersion -ge [version]'7.2') {
    $PSStyle.OutputRendering = 'Ansi'
}

# --- Editor padrao ---------------------------------------------------------
# Ferramentas que chamam $EDITOR / $VISUAL (git, lazygit, delta) usam isto.
$env:EDITOR   = 'code --wait'
$env:VISUAL   = 'code --wait'
$env:GIT_EDITOR = 'code --wait'

# --- Lazy load Terminal-Icons ----------------------------------------------
# O modulo Terminal-Icons custa ~500-1000ms no startup e so e util quando voce
# lista arquivos. Em vez de importar no startup, importamos na primeira
# chamada de Get-ChildItem/ls/dir. Apos a primeira chamada, o modulo ja esta
# carregado e as chamadas subsequentes sao diretas (sem overhead).
$global:__TI_Loaded = $false
function Get-ChildItem {
    [CmdletBinding()]
    param(
        [Parameter(Position=0, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [Alias('PSPath','LP')]
        [string[]]$Path,
        [Parameter(Position=1)]
        [string]$Filter,
        [string[]]$Include,
        [string[]]$Exclude,
        [switch]$Recurse,
        [switch]$Force,
        [switch]$Name,
        [switch]$File,
        [switch]$Directory,
        [switch]$Hidden,
        [switch]$ReadOnly,
        [switch]$System
    )
    if (-not $global:__TI_Loaded) {
        $global:__TI_Loaded = $true
        Import-Module Terminal-Icons -ErrorAction SilentlyContinue -Global
    }
    Microsoft.PowerShell.Management\Get-ChildItem @PSBoundParameters
}

# --- Posh-Git (condicional) ------------------------------------------------
# Posh-Git custa ~300-500ms. So importa se o diretorio atual (ou um pai)
# for um repositorio git. Fora de repos, o autocomplete de git nao esta
# disponivel, mas voce raramente precisa dele fora de um repo.
$inGitRepo = $false
$d = $PWD.Path
while ($d -and (Test-Path $d)) {
    if (Test-Path (Join-Path $d '.git')) { $inGitRepo = $true; break }
    $parent = Split-Path $d -Parent
    if ($parent -eq $d) { break }
    $d = $parent
}
if ($inGitRepo) {
    Import-Module Posh-Git -ErrorAction SilentlyContinue
}

# --- PSFzf (condicional) ---------------------------------------------------
# PSFzf so faz sentido se o binario 'fzf' estiver no PATH. Se nao estiver,
# o Import-Module falharia e seria ignorado (mas ainda custaria ~100ms).
if (Get-Command fzf -ErrorAction SilentlyContinue) {
    Import-Module PSFzf -ErrorAction SilentlyContinue
}

# --- PSReadLine ------------------------------------------------------------
# Guarda: quando a saida e redirecionada (pwsh -c, scripts, tarefas do VS Code,
# CI) nao existe console real, e essas chamadas estouram "invalid handle" no
# stderr. Num terminal interativo a guarda e transparente.
if (-not [Console]::IsOutputRedirected) {
    # Setas para cima/baixo navegam no historico
    Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    # Tab completa, previsao vem do historico
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

    # Consolidado em uma unica chamada (economia de ~50-100ms vs multiplas)
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd -ShowToolTips -EditMode Windows `
        -MaximumHistoryCount 10000 -PredictionSource History -PredictionViewStyle ListView

    # PSFzf: Ctrl+R = busca fuzzy no historico, Ctrl+F = caminhos
    if (Get-Command Set-PsFzfOption -ErrorAction SilentlyContinue) {
        Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+f' -PSReadlineChordReverseHistory 'Ctrl+r'
    }
}

# --- Oh My Posh ------------------------------------------------------------
# IMPORTANTE: precisa vir ANTES do Zoxide. O Zoxide sobrescreve a funcao
# 'prompt' guardando a anterior; se o Oh My Posh rodar depois, ele apaga o
# wrapper do zoxide e voce perde o rastreamento de diretorios.
#
# Gerenciado pelo Scoop:  scoop update oh-my-posh
#
# TEMA ATUAL: custom.omp.json, em %USERPROFILE%\.omp\ (mesmo arquivo usado pelo
# Git Bash e pelas duas distros WSL).
# Para voltar ao tema empacotado do Scoop, troque o nome do arquivo abaixo.
$OmpTheme = "$env:USERPROFILE\.omp\custom.omp.json"
$ompCache = "$env:USERPROFILE\.omp\init-cache.ps1"

$ompExe = $null
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) { $ompExe = 'oh-my-posh' }
elseif (Test-Path "$env:USERPROFILE\scoop\shims\oh-my-posh.exe") { $ompExe = "$env:USERPROFILE\scoop\shims\oh-my-posh.exe" }

if ($ompExe -and (Test-Path $OmpTheme)) {
    # Cache: gera o script de init uma vez e dot-source nas proximas execucoes.
    # Regenera se o tema ou o oh-my-posh mudou (comparacao por mtime).
    # Se o cache corromper, basta deletar: Remove-Item ~/.omp/init-cache.ps1
    $themeMtime = (Get-Item $OmpTheme).LastWriteTimeUtc
    $exePath = if ($ompExe -eq 'oh-my-posh') { (Get-Command oh-my-posh).Source } else { $ompExe }
    $exeMtime = (Get-Item $exePath).LastWriteTimeUtc
    $cacheMtime = if (Test-Path $ompCache) { (Get-Item $ompCache).LastWriteTimeUtc } else { [datetime]::MinValue }
    if (($themeMtime -gt $cacheMtime) -or ($exeMtime -gt $cacheMtime) -or (-not (Test-Path $ompCache))) {
        if ($ompExe -eq 'oh-my-posh') {
            oh-my-posh init pwsh --config $OmpTheme | Out-File $ompCache -Encoding utf8
        } else {
            & $ompExe init pwsh --config $OmpTheme | Out-File $ompCache -Encoding utf8
        }
    }
    . $ompCache
} elseif (Test-Path $OmpTheme) {
    # Fallback: shim do Scoop ainda nao esta no PATH desta sessao
    & "$env:USERPROFILE\scoop\shims\oh-my-posh.exe" init pwsh --config $OmpTheme | Invoke-Expression
}

# --- Zoxide ----------------------------------------------------------------
# Z = diretorio mais usado que casa com o texto digitado.  Aparece o ranking
# com Ctrl+R (PSFzf) ou direto pelo comando 'z <texto>'.
# Cache: mesmo padrao do Oh My Posh (gera uma vez, dot-source depois).
$zoxideCache = "$env:USERPROFILE\.zoxide-init.ps1"
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    $zoxideExe = (Get-Command zoxide).Source
    $zoxideMtime = (Get-Item $zoxideExe).LastWriteTimeUtc
    $cacheMtime = if (Test-Path $zoxideCache) { (Get-Item $zoxideCache).LastWriteTimeUtc } else { [datetime]::MinValue }
    if (($zoxideMtime -gt $cacheMtime) -or (-not (Test-Path $zoxideCache))) {
        zoxide init powershell | Out-File $zoxideCache -Encoding utf8
    }
    . $zoxideCache
}

# --- Atalhos ---------------------------------------------------------------
Set-Alias g git
Set-Alias ll ls
Set-Alias less "$env:ProgramFiles\Git\usr\bin\less.exe"
Set-Alias tig  "$env:ProgramFiles\Git\usr\bin\tig.exe"
Set-Alias lg lazygit
Set-Alias df diff
Set-Alias l  log

# which: melhor que o which.exe do Git porque enxerga tambem cmdlets,
# funcoes e aliases -- nao apenas executaveis no PATH.
function which {
    param([Parameter(Mandatory, Position = 0)][string]$Command)

    $found = Get-Command -Name $Command -ErrorAction SilentlyContinue
    if (-not $found) { return }

    foreach ($c in $found) {
        if ($c.CommandType -eq 'Application') { $c.Source }
        else { "[$($c.CommandType)] $($c.Name)" }
    }
}

# --- Chocolatey ------------------------------------------------------------
# ATENCAO: o choco altera o sistema e exige um terminal como ADMINISTRADOR.
#           Em terminal comum o comando falha com "requires administrative rights".
function Install-Choco {
    choco install @args
}
Set-Alias install Install-Choco

# --- Funcoes uteis ----------------------------------------------------------
# mkcd: cria a arvore de diretorios e ja entra nela.
function mkcd {
    param([Parameter(Mandatory, Position = 0)][string]$Path)

    if (Test-Path $Path) { Set-Location $Path; return }
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    Set-Location $Path
}

# touch: cria arquivo vazio, ou atualiza o timestamp se ele ja existir.
function touch {
    param([Parameter(Mandatory, Position = 0)][string]$Path)

    if (-not (Test-Path $Path)) {
        New-Item -ItemType File -Path $Path -Force | Out-Null
        return
    }
    (Get-Item $Path).LastWriteTime = Get-Date
}

# rm -rf com confirmacao: o padrao do PowerShell e NAO pedir confirmacao
# em Remove-Item -Recurse -Force, e esse e o comando que mais destroi coisa.
#
# ATENCAO -- por que o nome da funcao NAO e 'rm':
# no PowerShell a ordem de precedencia e Alias > Function > Cmdlet > Externo.
# Ja existe um alias 'rm' apontando para Remove-Item, que SEMPRE vence uma
# funcao chamada 'rm'. Se a funcao se chamasse 'rm', ela nunca rodaria.
# Por isso a funcao chama Remove-Rf e o alias 'rm' e apontado para ela.
#
# ATENCAO -- isso quebra scripts que usam 'rm' esperando Remove-Item:
# eles agora vao receber um prompt de confirmacao. Em scripts, use
# Remove-Item direto (e passe -Confirm:$false se precisar).
function Remove-Rf {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string[]]$Path
    )

    foreach ($p in $Path) {
        if (-not (Test-Path $p)) {
            Write-Verbose "rm: '$p' nao existe"
            continue
        }

        $item = Get-Item $p
        if ($item.PSIsContainer) {
            $what = 'DIRETORIO'
            $size = (Get-ChildItem $p -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object).Count
            $desc = "$($item.FullName)  ($size itens)"
        }
        else {
            $what = 'arquivo'
            $desc = "$($item.FullName)  ($([math]::Round($item.Length/1KB,1)) KB)"
        }

        if ($PSCmdlet.ShouldProcess($what, "REMOVER  $desc")) {
            Remove-Item $p -Recurse -Force -ErrorAction Stop
        }
    }
}

# sobrepoe o alias padrao 'rm' (veja a explicacao acima)
Set-Alias -Option AllScope -Scope Global rm Remove-Rf

# c: volta ao diretorio de codigo/config do repo atual.
function c {
    if ($PWD.Path -match '[\\/](\.git|src|lib|app|cmd|internal|pkg)([\\/]|$)') {
        Set-Location (Split-Path $PWD -Parent)
    }
    else { Write-Verbose "c: nada a subir a partir de '$PWD'" }
}

# --- Limpa a tela ----------------------------------------------------------
# Fica no fim de proposito: nao apaga nada do que ja foi escrito acima.
# clear-host mexe em $RawUI e tambem falha se a saida estiver redirecionada.
if (-not [Console]::IsOutputRedirected) {
    clear-host
}