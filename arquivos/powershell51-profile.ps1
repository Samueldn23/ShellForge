# ===========================================================================
#  Perfil do Windows PowerShell 5.1
#
#  Contem o Oh My Posh e os atalhos. Terminal-Icons, Posh-Git, PSFzf e o
#  Zoxide ficam so no PowerShell 7: os modulos suportam o 5.1, mas o
#  PowerShellGet deste shell e o legado 1.0.0.1, que costuma falhar na
#  instalacao.
#
#  Se quiser os modulos aqui tambem, instale pelo PS 7 e copie a pasta:
#    Copy-Item "$HOME\Documents\PowerShell\Modules\Terminal-Icons" `
#              "$HOME\Documents\WindowsPowerShell\Modules\" -Recurse
#    Copy-Item "$HOME\Documents\PowerShell\Modules\posh-git" `
#              "$HOME\Documents\WindowsPowerShell\Modules\" -Recurse
#    Copy-Item "$HOME\Documents\PowerShell\Modules\PSFzf" `
#              "$HOME\Documents\WindowsPowerShell\Modules\" -Recurse
#  (lembre-se que neste PC Documents aponta para D:\USER\Documents)
# ===========================================================================

# --- Oh My Posh ------------------------------------------------------------
# Troque o tema trocando o nome do arquivo .omp.json abaixo.
# Gerenciado pelo Scoop:  scoop update oh-my-posh
#
# TEMA ATUAL: custom.omp.json, em %USERPROFILE%\.omp\
# Para voltar ao tema empacotado do Scoop, troque a linha abaixo por:
#   $OmpTheme = Join-Path $env:POSH_THEMES_PATH 'powerlevel10k_rainbow.omp.json'
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

# --- Atalhos ---------------------------------------------------------------
Set-Alias g git
Set-Alias ll ls
Set-Alias less "$env:ProgramFiles\Git\usr\bin\less.exe"
Set-Alias tig  "$env:ProgramFiles\Git\usr\bin\tig.exe"

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
function Install-Choco {
    choco install @args
}
Set-Alias install Install-Choco