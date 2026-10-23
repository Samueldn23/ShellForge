<#
.SYNOPSIS
    Restaura a personalizacao do shell (Oh My Posh, PSReadLine, modulos, git,
    Windows Terminal, Clink) em outra maquina Windows.

.DESCRIPTION
    Script idempotente: pode rodar mais de uma vez sem estragar nada.
    Nao sobrescreve nada sem antes gravar um .bak do arquivo original.

.PARAMETER SomenteConfig
    Nao instala ferramentas (Scoop / Chocolatey / modulos / fonte). So copia
    os arquivos de configuracao e ajusta registro e variaveis de ambiente.

.PARAMETER Simular
    Mostra o que seria feito, sem alterar nada.

.EXAMPLE
    pwsh -File ShellForge.ps1
    pwsh -File ShellForge.ps1 -SomenteConfig
    pwsh -File ShellForge.ps1 -Simular

    # Instalacao com um comando (requer install.ps1 do repo):
    # irm https://is.gd/shellforge | iex
    # irm https://raw.githubusercontent.com/Samueldn23/ShellForge/main/install.ps1 | iex
#>

[CmdletBinding()]
param(
    [switch]$SomenteConfig,
    [switch]$Simular
)

$ErrorActionPreference = 'Continue'
$raiz = $PSScriptRoot
$arquivos = Join-Path $raiz 'arquivos'
$listas = Join-Path $raiz 'listas'

# Mapa de apps Scoop para IDs do winget (usado quando o Scoop nao esta instalado).
# Apps sem equivalencia no winget (gradle, openjdk21) sao pulados com aviso.
$wingetMap = @{
    '7zip' = '7zip.7zip'
    'clink' = 'chrisant996.Clink'
    'delta' = 'dandavison.delta'
    'ffmpeg' = 'Gyan.FFmpeg'
    'fzf' = 'junegunn.fzf'
    'git' = 'Git.Git'
    'jq' = 'jqlang.jq'
    'lazygit' = 'JesseDuffield.lazygit'
    'nodejs' = 'OpenJS.NodeJS'
    'oh-my-posh' = 'JanDeDobbeleer.OhMyPosh'
    'zoxide' = 'ajeetdsouza.zoxide'
}

$falhas = 0
function Ok   { param($m) Write-Host "  [ok]   $m" -ForegroundColor Green }
function Aviso { param($m) Write-Host "  [aviso] $m" -ForegroundColor Yellow }
function Erro { param($m) Write-Host "  [ERRO] $m" -ForegroundColor Red; $script:falhas++ }
function Foco { param($m) Write-Host "`n$m" -ForegroundColor Cyan }

function Executar {
    param([string]$Descricao, [scriptblock]$Acao)
    if ($Simular) { Write-Host "  [simular] $Descricao" -ForegroundColor DarkGray; return }
    try { & $Acao; Ok $Descricao }
    catch { Erro "$Descricao -> $($_.Exception.Message)" }
}

# Verifica se um comando ja esta disponivel no PATH
function ComandoExiste {
    param([string]$Nome)
    return [bool](Get-Command $Nome -ErrorAction SilentlyContinue)
}

# Mapeia nome do app Scoop para o comando que ele instala
$appComando = @{
    '7zip' = '7z'
    'clink' = 'clink'
    'delta' = 'delta'
    'ffmpeg' = 'ffmpeg'
    'fzf' = 'fzf'
    'git' = 'git'
    'jq' = 'jq'
    'lazygit' = 'lazygit'
    'nodejs' = 'node'
    'oh-my-posh' = 'oh-my-posh'
    'zoxide' = 'zoxide'
}

# Apps sem equivalente no winget: aponta para instalacao manual
$manualMap = @{
    'gradle' = 'https://gradle.org/install/'
    'openjdk21' = 'https://adoptium.net/'
}

# Testa conexao TCP (nao precisa de ICMP nem de admin)
function RedeOk {
    param([string]$Servidor = 'github.com', [int]$Porta = 443)
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $iar = $tcp.BeginConnect($Servidor, $Porta, $null, $null)
        $ok = $iar.AsyncWaitHandle.WaitOne(3000, $false)
        if ($ok -and $tcp.Connected) { $tcp.EndConnect($iar); $tcp.Close(); return $true }
        $tcp.Close(); return $false
    } catch { return $false }
}

# Verifica Execution Policy do PowerShell (bloqueia execucao de scripts por padrÃ£o)
$execPolicy = Get-ExecutionPolicy -Scope CurrentUser -ErrorAction SilentlyContinue
if (-not $execPolicy -or $execPolicy -eq 'Restricted') {
    Write-Host ''
    Write-Host '===========================================================' -ForegroundColor Yellow
    Write-Host '  ERRO: Execucao de scripts esta bloqueada no PowerShell' -ForegroundColor Yellow
    Write-Host '===========================================================' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  PolÃ­tica atual: $execPolicy'
    Write-Host ''
    Write-Host '  Para habilitar a execucao de scripts (apenas para seu usuario, sem admin):'
    Write-Host ''
    Write-Host '      Set-ExecutionPolicy RemoteSigned -Scope CurrentUser'
    Write-Host ''
    Write-Host '  Ou, se preferir desabilitar completamente (nao recomendado):'
    Write-Host ''
    Write-Host '      Set-ExecutionPolicy Unrestricted -Scope CurrentUser'
    Write-Host ''
    Write-Host '  Depois de executar o comando acima, abra um NOVO PowerShell e rode este script novamente.'
    Write-Host '===========================================================' -ForegroundColor Yellow
    exit 1
}

# PowerShell 7 e necessario (perfis e recursos usados pelo script)
if ($PSVersionTable.PSVersion.Major -lt 7) {
    # Se ja tentamos instalar e estamos rodando no pwsh, nao faca nada (evita loop infinito)
    $jaTentouInstalar = $env:SHELLFORGE_INSTALOU_PW7 -eq '1'

    if (-not $jaTentouInstalar) {
        # Tenta instalar via winget
        $redeOk = RedeOk
        if (-not $redeOk) {
            Erro "PowerShell 7 nao esta instalado e nao ha conexao com a internet para baixar."
            Erro 'Instale manualmente: winget install Microsoft.PowerShell'
            exit 1
        }
        Executar 'Instalar PowerShell 7 via winget' {
            & winget install --id Microsoft.PowerShell -e --silent --accept-package-agreements --accept-source-agreements | Out-Null
        }
        # Marca que ja instalamos para nao loopar
        $env:SHELLFORGE_INSTALOU_PW7 = '1'
    }

    # Procura o pwsh.exe
    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
    if (-not $pwsh) {
        # winget pode nao atualizar o PATH desta sessao; procura o exe direto
        $pwshExe = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter 'pwsh.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($pwshExe) { $pwsh = $pwshExe.FullName }
    }

    if (-not $pwsh) {
        Erro "Falha ao instalar o PowerShell 7 via winget."
        Erro 'Instale manualmente: winget install Microsoft.PowerShell'
        exit 1
    }

    Ok "PowerShell 7 encontrado: $pwsh"

    # Reinicia o proprio script usando o PowerShell 7 recem instalado
    $scriptPath = $PSScriptRoot
    $scriptFile = Join-Path $scriptPath 'ShellForge.ps1'

    # Verifica se precisamos de administrador (para gravaÃ§Ã£o em HKCR, por exemplo)
    $precisaAdmin = $false
    $identidade = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identidade)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        $precisaAdmin = $true
    }

    if ($precisaAdmin) {
        Write-Host ''
        Write-Host '===========================================================' -ForegroundColor Yellow
        Write-Host '  Requisito: privilegios de administrador' -ForegroundColor Yellow
        Write-Host '===========================================================' -ForegroundColor Yellow
        Write-Host ''
        Write-Host '  O PowerShell 7 sera executado como administrador para poder'
        Write-Host '  gravar no registro do Windows (menu de contexto do Explorer).'
        Write-Host ''
        Write-Host '  Uma janela sera aberta solicitando confirmacao de UAC.'
        Write-Host '===========================================================' -ForegroundColor Yellow

        # RelanÃ§a o script via pwsh.exe com RunAs (elevado)
        Start-Process -FilePath $pwsh -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptFile`"" -Verb RunAs -Wait
    } else {
        # RelanÃ§a o script via pwsh.exe sem elevacao
        & $pwsh -NoProfile -ExecutionPolicy Bypass -File $scriptFile
    }

    # Sai do script atual (Windows PowerShell 5.1) apos lanÃ§ar o pwsh
    exit 0
}

# --- Funcao: menu grafico (WPF) com checkboxes por categoria ---------------

function Show-ShellForgeMenuWpf {

    param([string[]]$ScoopApps)



    try {

        Add-Type -AssemblyName PresentationFramework -ErrorAction Stop

        Add-Type -AssemblyName PresentationCore       -ErrorAction Stop

        Add-Type -AssemblyName WindowsBase           -ErrorAction Stop

    } catch { return $null }



    $xaml = @'

<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"

        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"

        Title="ShellForge" Height="640" Width="560"

        WindowStartupLocation="CenterScreen" ResizeMode="NoResize"

        Background="#1E1E2E">

  <Grid Margin="20">

    <Grid.RowDefinitions>

      <RowDefinition Height="Auto"/>

      <RowDefinition Height="Auto"/>

      <RowDefinition Height="Auto"/>

      <RowDefinition Height="*"/>

      <RowDefinition Height="Auto"/>

    </Grid.RowDefinitions>

    <TextBlock Grid.Row="0" Text="ShellForge" FontSize="22" FontWeight="Bold" Foreground="#89B4FA" Margin="0,0,0,2"/>

    <TextBlock Grid.Row="1" Text="Personalizacao do shell - modo e componentes" Foreground="#CDD6F4" Margin="0,0,0,10" FontSize="12"/>

    <StackPanel Grid.Row="2" Orientation="Horizontal" Margin="0,0,0,8">

      <RadioButton x:Name="rbFull"   IsChecked="True" Content="Completo"  Foreground="#CDD6F4" Margin="0,0,14,0" FontSize="12"/>

      <RadioButton x:Name="rbConfig" Content="So config"  Foreground="#CDD6F4" Margin="0,0,14,0" FontSize="12"/>

      <RadioButton x:Name="rbSim"    Content="Simulacao"  Foreground="#CDD6F4" FontSize="12"/>

    </StackPanel>

    <ScrollViewer Grid.Row="3" VerticalScrollBarVisibility="Auto">

      <StackPanel x:Name="panelGroups"/>

    </ScrollViewer>

    <StackPanel Grid.Row="4" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,12,0,0">

      <Button x:Name="btnCancel" Content="Cancelar" Width="96" Margin="0,0,10,0" Padding="6,4"/>

      <Button x:Name="btnRun"    Content="Executar" Width="96" Padding="6,4" IsDefault="True" Background="#89B4FA" Foreground="#1E1E2E" FontWeight="Bold"/>

    </StackPanel>

  </Grid>

</Window>

'@

    try {

        $x = [xml]$xaml

        $reader = New-Object System.Xml.XmlNodeReader $x

        $window = [System.Windows.Markup.XamlReader]::Load($reader)

    } catch { return $null }



    $rbFull    = $window.FindName('rbFull')

    $rbConfig  = $window.FindName('rbConfig')

    $rbSim     = $window.FindName('rbSim')

    $panel     = $window.FindName('panelGroups')

    $btnRun    = $window.FindName('btnRun')

    $btnCancel = $window.FindName('btnCancel')



    $state = [hashtable]::Synchronized(@{ Result = $null; Mode = 'Full'; ScoopApps = @(); Modulos = $true; Fonte = $true; Configs = $true; Wsl = $true; RegClinkAutorun = $true; RegExplorerMenu = $true; EnvPath = $true; EnvPoshThemes = $true; EnvClinkDir = $true; EnvTelemetry = $true })



    function New-Cb {

        param([string]$Label, [bool]$Checked, [string]$Tag)

        $cb = New-Object System.Windows.Controls.CheckBox

        $cb.Content = $Label

        $cb.IsChecked = $Checked

        $cb.Foreground = [System.Windows.Media.Brushes]::White

        $cb.Margin = [System.Windows.Thickness]::new(0,2,0,2)

        $cb.FontSize = 12

        if ($Tag) { $cb.Tag = $Tag }

        return $cb

    }

    function New-GroupHeader {

        param([string]$Text)

        $tb = New-Object System.Windows.Controls.TextBlock

        $tb.Text = $Text

        $tb.FontWeight = 'Bold'

        $tb.Foreground = [System.Windows.Media.Brushes]::LightBlue

        $tb.Margin = [System.Windows.Thickness]::new(0,10,0,4)

        $tb.FontSize = 13

        return $tb

    }



    $panel.Children.Add((New-GroupHeader "Ferramentas (Scoop)")) | Out-Null

    $cbAllScoop = New-Cb "Selecionar tudo" $true "all-scoop"

    $panel.Children.Add($cbAllScoop) | Out-Null

    $scoopCbs = @()

    foreach ($app in $ScoopApps) {

        $cb = New-Cb "  $app" $true "scoop:$app"

        $panel.Children.Add($cb) | Out-Null

        $scoopCbs += $cb

    }

    $cbAllScoop.Add_Checked({ foreach ($c in $scoopCbs) { $c.IsChecked = $true } }.GetNewClosure())

    $cbAllScoop.Add_Unchecked({ foreach ($c in $scoopCbs) { $c.IsChecked = $false } }.GetNewClosure())



    $panel.Children.Add((New-GroupHeader "Modulos PowerShell")) | Out-Null

    $cbAllMod = New-Cb "Selecionar tudo" $true "all-mod"

    $panel.Children.Add($cbAllMod) | Out-Null

    $modCbs = @()

    foreach ($m in @('Terminal-Icons','Posh-Git','PSFzf')) {

        $cb = New-Cb "  $m" $true "mod:$m"

        $panel.Children.Add($cb) | Out-Null

        $modCbs += $cb

    }

    $cbAllMod.Add_Checked({ foreach ($c in $modCbs) { $c.IsChecked = $true } }.GetNewClosure())

    $cbAllMod.Add_Unchecked({ foreach ($c in $modCbs) { $c.IsChecked = $false } }.GetNewClosure())



    $panel.Children.Add((New-GroupHeader "Fonte")) | Out-Null

    $cbFonte = New-Cb "Hack Nerd Font" $true "fonte"

    $panel.Children.Add($cbFonte) | Out-Null



    $panel.Children.Add((New-GroupHeader "Configuracoes")) | Out-Null

    $cbConfigs = New-Cb "Perfis, .bashrc, .gitconfig, tema, Windows Terminal, Clink" $true "configs"

    $panel.Children.Add($cbConfigs) | Out-Null



    $panel.Children.Add((New-GroupHeader "WSL")) | Out-Null

    $cbWsl = New-Cb "Aplicar tema Oh My Posh nas distros WSL" $true "wsl"

    $panel.Children.Add($cbWsl) | Out-Null

    # --- Grupo: Registro ---
    $panel.Children.Add((New-GroupHeader "Registro (CMD / Explorer)")) | Out-Null
    $cbRegClink = New-Cb "Clink AutoRun (chcp 65001 + clink inject)" $true "reg-clink"
    $panel.Children.Add($cbRegClink) | Out-Null
    $cbRegExplorer = New-Cb "Menu de contexto do Explorer (Abrir com PowerShell 7)" $true "reg-explorer"
    $panel.Children.Add($cbRegExplorer) | Out-Null

    # --- Grupo: Variaveis de ambiente ---
    $panel.Children.Add((New-GroupHeader "Variaveis de ambiente")) | Out-Null
    $cbEnvPath = New-Cb "PATH += scoop\\shims" $true "env-path"
    $panel.Children.Add($cbEnvPath) | Out-Null
    $cbEnvPosh = New-Cb "POSH_THEMES_PATH" $true "env-posh"
    $panel.Children.Add($cbEnvPosh) | Out-Null
    $cbEnvClink = New-Cb "CLINK_DIR" $true "env-clink"
    $panel.Children.Add($cbEnvClink) | Out-Null
    $cbEnvTelem = New-Cb "POWERSHELL_TELEMETRY_OPTOUT = 1" $true "env-telem"
    $panel.Children.Add($cbEnvTelem) | Out-Null

    $applyMode = {

        param($mode)

        if ($mode -eq 'Full') {

            $cbAllScoop.IsChecked = $true

            $cbAllMod.IsChecked   = $true

            $cbFonte.IsChecked    = $true

            $cbConfigs.IsChecked  = $true

            $cbWsl.IsChecked      = $true
            $cbRegClink.IsChecked    = $true
            $cbRegExplorer.IsChecked = $true
            $cbEnvPath.IsChecked    = $true
            $cbEnvPosh.IsChecked    = $true
            $cbEnvClink.IsChecked   = $true
            $cbEnvTelem.IsChecked   = $true

        } elseif ($mode -eq 'Config') {

            $cbAllScoop.IsChecked = $false

            $cbAllMod.IsChecked   = $false

            $cbFonte.IsChecked    = $false

            $cbConfigs.IsChecked  = $true

            $cbWsl.IsChecked      = $true
            $cbRegClink.IsChecked    = $true
            $cbRegExplorer.IsChecked = $true
            $cbEnvPath.IsChecked    = $true
            $cbEnvPosh.IsChecked    = $true
            $cbEnvClink.IsChecked   = $true
            $cbEnvTelem.IsChecked   = $true

        }

    }.GetNewClosure()



    & $applyMode 'Full'



    $rbFull.Add_Checked({ & $applyMode 'Full' }.GetNewClosure())

    $rbConfig.Add_Checked({ & $applyMode 'Config' }.GetNewClosure())



    $btnRun.Add_Click({

        $mode = 'Full'

        if ($rbConfig.IsChecked) { $mode = 'Config' }

        elseif ($rbSim.IsChecked) { $mode = 'Sim' }



        $selectedApps = @()

        foreach ($cb in $scoopCbs) {

            if ($cb.IsChecked) { $selectedApps += ($cb.Tag -replace '^scoop:','') }

        }



        $state.Mode       = $mode

        $state.ScoopApps  = $selectedApps

        $state.Modulos    = (@($modCbs | Where-Object { $_.IsChecked })).Count -gt 0

        $state.Fonte      = ($cbFonte.IsChecked -eq $true)

        $state.Configs    = ($cbConfigs.IsChecked -eq $true)

        $state.Wsl        = ($cbWsl.IsChecked -eq $true)
        $state.RegClinkAutorun = ($cbRegClink.IsChecked -eq $true)
        $state.RegExplorerMenu = ($cbRegExplorer.IsChecked -eq $true)
        $state.EnvPath        = ($cbEnvPath.IsChecked -eq $true)
        $state.EnvPoshThemes  = ($cbEnvPosh.IsChecked -eq $true)
        $state.EnvClinkDir    = ($cbEnvClink.IsChecked -eq $true)
        $state.EnvTelemetry   = ($cbEnvTelem.IsChecked -eq $true)
        $state.Result     = 'OK'

        $window.Close()

    }.GetNewClosure())



    $btnCancel.Add_Click({ $window.Close() }.GetNewClosure())



    $window.ShowDialog() | Out-Null

    if ($state.Result -ne 'OK') { return $null }

    return $state

}



# --- Menu (WPF se disponivel, senao texto) ------------------------------------

$wpfOk = $false

try {

    Add-Type -AssemblyName PresentationFramework -ErrorAction Stop

    Add-Type -AssemblyName PresentationCore       -ErrorAction Stop

    Add-Type -AssemblyName WindowsBase           -ErrorAction Stop

    $wpfOk = $true

} catch { $wpfOk = $false }



$scoopAppNames = @()

$arqScoopTmp = Join-Path $listas 'scoop-apps.txt'

if (Test-Path $arqScoopTmp) {

    $scoopAppNames = Get-Content $arqScoopTmp | Where-Object { $_ -and $_ -notmatch '^#' } | ForEach-Object {

        $p = $_ -split '\|'; $p[0]

    } | Where-Object { $_ -notin @('scoop','scoop-search','winget') }

}



if (-not $SomenteConfig -and -not $Simular -and -not $PularMenu -and -not $SelecaoArquivo -and -not [Console]::IsInputRedirected) {

    if ($wpfOk) {

        $menuResult = Show-ShellForgeMenuWpf -ScoopApps $scoopAppNames

        if ($null -eq $menuResult) {

            Write-Host 'Cancelado.' -ForegroundColor Yellow

            exit 0

        }

        $modo = $menuResult.Mode

        if ($modo -eq 'Config') { $SomenteConfig = $true }

        if ($modo -eq 'Sim')    { $Simular       = $true }

        $selecao = @{

            ScoopApps = $menuResult.ScoopApps

            Modulos   = $menuResult.Modulos

            Fonte     = $menuResult.Fonte

            Configs   = $menuResult.Configs

            Wsl       = $menuResult.Wsl
            RegClinkAutorun = $menuResult.RegClinkAutorun
            RegExplorerMenu = $menuResult.RegExplorerMenu
            EnvPath        = $menuResult.EnvPath
            EnvPoshThemes  = $menuResult.EnvPoshThemes
            EnvClinkDir    = $menuResult.EnvClinkDir
            EnvTelemetry   = $menuResult.EnvTelemetry
        }

    } else {

        Write-Host ''

        Write-Host '===========================================================' -ForegroundColor Cyan

        Write-Host '  ShellForge - escolha o modo de instalacao' -ForegroundColor Cyan

        Write-Host '===========================================================' -ForegroundColor Cyan

        Write-Host '  1. Instalacao completa (Scoop, modulos, fonte, configs, WSL)'

        Write-Host '  2. Somente configuracao (pula Scoop/modulos/fonte, aplica WSL)'

        Write-Host '  3. Simulacao (dry-run: mostra tudo, nao altera nada)'

        Write-Host '  4. Sair'

        Write-Host '===========================================================' -ForegroundColor Cyan

        do {

            $escolha = Read-Host 'Opcao [1-4] (padrao: 1)'

            if ([string]::IsNullOrWhiteSpace($escolha)) { $escolha = '1' }

        } while ($escolha -notin @('1','2','3','4'))

        switch ($escolha) {

            '2' { $SomenteConfig = $true }

            '3' { $Simular       = $true }

            '4' { Write-Host 'Cancelado.' -ForegroundColor Yellow; exit 0 }

        }

        $selecao = @{

            ScoopApps = $null

            Modulos   = (-not $SomenteConfig)

            Fonte     = (-not $SomenteConfig)

            Configs   = $true

            Wsl       = $true
            RegClinkAutorun = $true
            RegExplorerMenu = $true
            EnvPath        = $true
            EnvPoshThemes  = $true
            EnvClinkDir    = $true
            EnvTelemetry   = $true
        }

        Write-Host ''

    }

} else {

    if (-not $selecao) {

        $selecao = @{

            ScoopApps = $null

            Modulos   = (-not $SomenteConfig)

            Fonte     = (-not $SomenteConfig)

            Configs   = $true

            Wsl       = $true
            RegClinkAutorun = $true
            RegExplorerMenu = $true
            EnvPath        = $true
            EnvPoshThemes  = $true
            EnvClinkDir    = $true
            EnvTelemetry   = $true
        }

    }

}



if ($SelecaoArquivo -and (Test-Path $SelecaoArquivo)) {

    try {

        $loaded = Get-Content $SelecaoArquivo -Raw | ConvertFrom-Json -AsHashtable

        if ($loaded) { $selecao = $loaded }

    } catch { }

}



if (-not $selecao) {

    $selecao = @{ ScoopApps = $null; Modulos = (-not $SomenteConfig); Fonte = (-not $SomenteConfig); Configs = $true; Wsl = $true; RegClinkAutorun = $true; RegExplorerMenu = $true; EnvPath = $true; EnvPoshThemes = $true; EnvClinkDir = $true; EnvTelemetry = $true }

}



# Log de execucao em arquivo (facilita depuracao em outra maquina)
$logFile = Join-Path $env:TEMP "ShellForge-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
try { Start-Transcript -Path $logFile -ErrorAction Stop | Out-Null } catch { $logFile = $null }

# Copia um arquivo, guardando o anterior como .bak
function InstalarArquivo {
    param([string]$Origem, [string]$Destino)

    if ($Simular) { Write-Host "  [simular] gravaria $Destino" -ForegroundColor DarkGray; return }

    if (-not (Test-Path $Origem)) { Erro "fonte ausente: $Origem"; return }

    $dir = Split-Path $Destino -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    if (Test-Path $Destino) {
        $antigo = (Get-FileHash $Destino -Algorithm SHA256).Hash
        $novo   = (Get-FileHash $Origem  -Algorithm SHA256).Hash
        if ($antigo -eq $novo) { Ok "$([System.IO.Path]::GetFileName($Destino)) ja esta igual"; return }
        Copy-Item $Destino "$Destino.bak.$(Get-Date -Format 'yyyyMMdd-HHmmss')" -Force
    }
    Copy-Item $Origem $Destino -Force
}

Write-Host ''
Write-Host '===========================================================' -ForegroundColor Cyan
Write-Host '  Restauracao da personalizacao do shell' -ForegroundColor Cyan
Write-Host '===========================================================' -ForegroundColor Cyan
Write-Host "  Origem : $raiz"
Write-Host "  Destino: $env:USERPROFILE"
if ($SomenteConfig) { Write-Host '  Modo   : SOMENTE CONFIGURACAO (sem instalar ferramentas)' -ForegroundColor Yellow }
if ($Simular)      { Write-Host '  Modo   : SIMULACAO (nada sera alterado)' -ForegroundColor Yellow }

# ===========================================================================
Foco '[1/7] Ferramentas via Scoop'
# ===========================================================================
$scoopApps = @()
$arqScoop = Join-Path $listas 'scoop-apps.txt'
if (Test-Path $arqScoop) {
    $scoopApps = Get-Content $arqScoop | Where-Object { $_ -and $_ -notmatch '^#' } | ForEach-Object {
        $p = $_ -split '\|'; @{ nome = $p[0]; bucket = if ($p.Count -gt 2) { $p[2] } else { 'main' } }
    }
}
# Scoop-search e winget ja vem com a propria instalacao do Scoop; instalar de novo causa conflito
$scoopApps = $scoopApps | Where-Object { $_.nome -notin @('scoop', 'scoop-search', 'winget') }

# Filtra pelos apps selecionados no menu (se houver selecao explicita)
if ($null -ne $selecao.ScoopApps) {
    $scoopApps = $scoopApps | Where-Object { $_.nome -in $selecao.ScoopApps }
}

if (-not $SomenteConfig -and $scoopApps) {
    $redeOk = RedeOk
    $scoop = Join-Path $env:USERPROFILE 'scoop\shims\scoop.cmd'
    if (-not (Test-Path $scoop)) {
        if (-not $redeOk) {
            Aviso 'Sem conexao com github.com:443. Instale o Scoop manualmente e rode de novo.'
        } else {
            # O instalador oficial aborta se C:\Users\...\scoop existe e nao esta vazio.
            # Se o diretorio existe mas nao tem scoop.cmd (instalacao parcial), renomeia para backup
            # e libera o caminho sem apagar dados.
            $scoopDir = Join-Path $env:USERPROFILE 'scoop'
            if (Test-Path $scoopDir) {
                Executar "renomeia instalacao parcial do Scoop para backup: $scoopDir" {
                    Rename-Item $scoopDir "$scoopDir.bak.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                }
            }
            # Scoop e o caminho padrao para os apps; instala se faltar
            Executar 'Instalar Scoop' {
                Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
                Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
            }
            $scoop = Join-Path $env:USERPROFILE 'scoop\shims\scoop.cmd'
        }
    }
    if (Test-Path $scoop) {
        # 'main' ja vem junto com a instalacao do Scoop; adicionar de novo so gera aviso
        $buckets = $scoopApps | ForEach-Object { $_.bucket } | Sort-Object -Unique |
                   Where-Object { $_ -match '^[a-z]' -and $_ -ne 'main' }
        foreach ($b in $buckets) { Executar "adiciona bucket $b" { & $scoop bucket add $b | Out-Null } }
        foreach ($a in $scoopApps) {
            $cmd = $appComando[$a.nome]
            if ($cmd -and (ComandoExiste $cmd)) {
                Ok "$($a.nome) ja instalado ($cmd encontrado)"
                continue
            }
            Executar "scoop install $($a.nome)" { & $scoop install $a.nome | Out-Null }
        }
    } else {
        Aviso 'Scoop nao instalado. Tentando instalar os apps via winget...'
        foreach ($a in $scoopApps) {
            $id = $wingetMap[$a.nome]
            if (-not $id) {
                $url = $manualMap[$a.nome]
                if ($url) { Aviso "$($a.nome) : sem equivalente no winget. Instale manualmente: $url" }
                else { Aviso "$($a.nome) : sem equivalente no winget (pule)" }
                continue
            }
            $cmd = $appComando[$a.nome]
            if ($cmd -and (ComandoExiste $cmd)) {
                Ok "$($a.nome) ja instalado ($cmd encontrado)"
                continue
            }
            Executar "winget install $id" {
                & winget install --id $id -e --silent --accept-package-agreements --accept-source-agreements | Out-Null
            }
        }
    }
} elseif ($SomenteConfig) {
    Aviso "pulado (SomenteConfig). Para instalar: $($scoopApps.Count) apps via Scoop"
} elseif (-not $selecao.ScoopApps -or $selecao.ScoopApps.Count -eq 0) {
    Aviso 'pulado (nenhum app selecionado no menu)'
}

# ===========================================================================
Foco '[2/7] Modulos do PowerShell (Terminal-Icons, Posh-Git, PSFzf)'
# ===========================================================================
if (-not $SomenteConfig -and $selecao.Modulos) {
    $modulos = @('Terminal-Icons', 'Posh-Git', 'PSFzf')
    $modulosFaltantes = @()
    foreach ($m in $modulos) {
        if (Get-Module -ListAvailable -Name $m -ErrorAction SilentlyContinue) {
            Ok "$m ja instalado"
        } else {
            $modulosFaltantes += $m
        }
    }
    if ($modulosFaltantes.Count -gt 0) {
        Executar "Install-Module $($modulosFaltantes -join ', ')" {
            Install-Module -Name $modulosFaltantes -Scope CurrentUser -Repository PSGallery -Force -AllowClobber
        }
    }
} else { Aviso 'pulado (SomenteConfig ou desmarcado no menu)' }

# ===========================================================================
Foco '[3/7] Fonte Nerd (FiraCode ou Hack Nerd Font)'
# ===========================================================================
$temFonte = $false
$fonteNerd = ''
try {
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop
    $instaladas = (New-Object System.Drawing.Text.InstalledFontCollection).Families.Name
    if ($instaladas -contains 'FiraCode Nerd Font') { $temFonte = $true; $fonteNerd = 'FiraCode Nerd Font' }
    elseif ($instaladas -contains 'Hack Nerd Font') { $temFonte = $true; $fonteNerd = 'Hack Nerd Font' }
} catch {
    $temFonte = $false
}
if (-not $selecao.Fonte) {
    Aviso 'pulado (desmarcado no menu)'
} elseif ($temFonte) {
    Ok "$fonteNerd ja instalada"
} elseif ($Simular) {
    Aviso 'instalaria uma fonte Nerd (FiraCode ou Hack) - veja README.md'
} else {
    Aviso 'Fonte Nerd NAO instalada (FiraCode ou Hack).'
    Aviso '  Baixe em: https://github.com/ryanoasis/nerd-fonts/releases'
    Aviso '  Instale a fonte com duplo clique > Install for all users'
    Aviso '  Sem ela os icones do prompt viram quadradinhos.'
}

# Se a fonte nao estiver instalada, tenta instalar da pasta arquivos/Hack/
if (-not $temFonte -and -not $SomenteConfig -and $selecao.Fonte) {
    $pastaFontes = Join-Path $arquivos 'Hack'
    if (Test-Path $pastaFontes) {
        Add-Type -AssemblyName System.Drawing
        $fontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
        $regPath = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
        New-Item -ItemType Directory -Force -Path $fontDir | Out-Null

        Get-ChildItem $pastaFontes -Filter *.ttf | ForEach-Object {
            $destino = Join-Path $fontDir $_.Name
            if (-not (Test-Path $destino)) {
                Copy-Item $_.FullName $destino -Force
            }

            # Registra a fonte no HKCU (fonte por usuario)
            $pfc = New-Object System.Drawing.Text.PrivateFontCollection
            $pfc.AddFontFile($destino)
            $nomeFonte = $pfc.Families[0].Name
            $estilo = $_.BaseName -replace '^HackNerdFont-?', '' -replace '^HackNerdFontMono-?', 'Mono ' -replace '^HackNerdFontPropo-?', 'Propo '
            if ($estilo -eq 'Regular') { $regName = "$nomeFonte (TrueType)" }
            else { $regName = "$nomeFonte $estilo (TrueType)" }
            New-ItemProperty -Path $regPath -Name $regName -Value $destino -PropertyType String -Force | Out-Null
            Ok "Fonte instalada: $regName"
        }
    } else {
        Aviso "Pasta arquivos/Hack nao encontrada. Baixe em: https://github.com/ryanoasis/nerd-fonts/releases"
    }
}

# ===========================================================================
Foco '[4/7] Arquivos de configuracao'
# ===========================================================================
$home_ = $env:USERPROFILE
if (-not $selecao.Configs) {
    Aviso 'pulado (desmarcado no menu)'
} else {
# Documents pode estar redirecionado: usa o caminho real em vez de $HOME\Documents
$docs = [Environment]::GetFolderPath('MyDocuments')

InstalarArquivo (Join-Path $arquivos 'pwsh-profile.ps1')      (Join-Path $docs 'PowerShell\Microsoft.PowerShell_profile.ps1')
InstalarArquivo (Join-Path $arquivos 'powershell51-profile.ps1') (Join-Path $docs 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1')
InstalarArquivo (Join-Path $arquivos 'bashrc')                 (Join-Path $home_ '.bashrc')
InstalarArquivo (Join-Path $arquivos 'bash_profile')           (Join-Path $home_ '.bash_profile')
InstalarArquivo (Join-Path $arquivos 'gitconfig')              (Join-Path $home_ '.gitconfig')
InstalarArquivo (Join-Path $arquivos 'custom.omp.json')        (Join-Path $home_ '.omp\custom.omp.json')

# Clink: o diretorio de estado e %LOCALAPPDATA%\clink
InstalarArquivo (Join-Path $arquivos 'clink_settings') (Join-Path $env:LOCALAPPDATA 'clink\clink_settings')

# Windows Terminal: o LocalState muda com o usuario, procura o caminho real
$pkg = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
if (Test-Path $pkg) {
    InstalarArquivo (Join-Path $arquivos 'settings-terminal.json') $pkg
    Aviso 'Se algum perfil nao aparecer no Windows Terminal, confira os GUIDs em arquivos\settings-terminal.json.'
} else {
    Aviso 'Windows Terminal nao encontrado (pacote MSIX ausente). settings-terminal.json ficou em arquivos\ para aplicar manualmente.'
}
} # fim Configs

# Validacao do tema: o WSL tambem valida, mas no Windows vale garantir aqui
$temaDestino = Join-Path $home_ '.omp\custom.omp.json'
if ((Test-Path $temaDestino) -and (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
    $saidaTema = & oh-my-posh print primary --config $temaDestino 2>&1 | Out-String
    if ($saidaTema -match 'unable to create text') { Erro 'custom.omp.json tem template invalido' }
    else { Ok 'custom.omp.json renderiza sem erro' }
}

# ===========================================================================
Foco '[5/7] Registro do CMD (Clink + codepage 65001)'
# ===========================================================================
$clinkBat = Join-Path $env:USERPROFILE 'scoop\apps\clink\current\clink.bat'
if (-not (Test-Path $clinkBat)) {
    # Se o Clink nao estiver no caminho do Scoop, tenta instalar via winget.
    $clinkCmd = Get-Command clink -ErrorAction SilentlyContinue
    if (-not $clinkCmd) {
        Executar 'winget install chrisant996.Clink' {
            & winget install --id chrisant996.Clink -e --silent --accept-package-agreements --accept-source-agreements | Out-Null
        }
        $clinkCmd = Get-Command clink -ErrorAction SilentlyContinue
    }
    if (-not $clinkCmd) {
        # winget pode nao atualizar o PATH nesta sessao; procura o exe direto
        $clinkExe = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter 'clink.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($clinkExe) { $clinkBat = $clinkExe.FullName }
    } else { $clinkBat = $clinkCmd.Source }
}
if (-not $selecao.RegClinkAutorun) {
    Aviso 'pulado (desmarcado no menu)'
} elseif ($Simular) {
    Aviso 'gravaria AutoRun do Command Processor (chcp 65001 + clink inject)'
} elseif ($clinkBat -and (Test-Path $clinkBat)) {
    Executar 'AutoRun = chcp 65001 && clink inject --autorun' {
        # A chave pode nao existir em instalacoes limpas; cria antes de gravar
        $regCmd = 'HKCU:\Software\Microsoft\Command Processor'
        if (-not (Test-Path $regCmd)) { New-Item -Path $regCmd -Force | Out-Null }
        $valor = "chcp 65001 && `"$clinkBat`" inject --autorun"
        Set-ItemProperty -Path $regCmd -Name AutoRun -Value $valor -Type String
    }
} else {
    Aviso 'Clink nao instalado: AutoRun do CMD fica sem configuracao.'
    Aviso '  Depois de instalar o clink, rode:  clink autorun install'
}

# ===========================================================================
Foco '[6/7] Variaveis de ambiente e PATH'
# ===========================================================================
$shims = Join-Path $env:USERPROFILE 'scoop\shims'
if ($Simular) {
    Aviso 'setaria POSH_THEMES_PATH, CLINK_DIR e a entrada scoop\shims no PATH'
} else {
    if ($selecao.EnvPath) {
        Executar 'PATH de usuario contem scoop\shims' {
            $p = [Environment]::GetEnvironmentVariable('Path','User') -split ';' | Where-Object { $_ }
            if ($p -notcontains $shims) {
                [Environment]::SetEnvironmentVariable('Path', (($p + $shims) -join ';'), 'User')
            }
        }
    } else { Aviso 'pulado (desmarcado no menu): PATH scoop\shims' }
    if ($selecao.EnvPoshThemes) {
        Executar 'POSH_THEMES_PATH' {
            # Procura os temas do Oh My Posh no Scoop ou no winget (MSIX/programa)
            $temas = @(
                (Join-Path $env:USERPROFILE 'scoop\apps\oh-my-posh\current\themes'),
                (Join-Path $env:LOCALAPPDATA 'Programs\oh-my-posh\themes'),
                (Join-Path $env:LOCALAPPDATA 'oh-my-posh\themes')
            ) | Where-Object { Test-Path $_ } | Select-Object -First 1
            if ($temas) { [Environment]::SetEnvironmentVariable('POSH_THEMES_PATH', $temas, 'User') }
        }
    } else { Aviso 'pulado (desmarcado no menu): POSH_THEMES_PATH' }
    if ($selecao.EnvClinkDir) {
        Executar 'CLINK_DIR' {
            $c = Join-Path $env:USERPROFILE 'scoop\apps\clink\current'
            if (-not (Test-Path $c)) {
                # Clink instalado via winget fica em outro lugar; usa o dir do exe
                $clinkCmd = Get-Command clink -ErrorAction SilentlyContinue
                if ($clinkCmd) { $c = Split-Path $clinkCmd.Source }
            }
            if (Test-Path $c) { [Environment]::SetEnvironmentVariable('CLINK_DIR', $c, 'User') }
        }
    } else { Aviso 'pulado (desmarcado no menu): CLINK_DIR' }
    if ($selecao.EnvTelemetry) {
        Executar 'POWERSHELL_TELEMETRY_OPTOUT = 1' {
            [Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', '1', 'User')
        }
    } else { Aviso 'pulado (desmarcado no menu): POWERSHELL_TELEMETRY_OPTOUT' }
}

# ===========================================================================
Foco '[7/7] Distros WSL'
# ===========================================================================
if (-not $selecao.Wsl) {
    Aviso 'pulado (desmarcado no menu)'
} else {
$arqDistros = Join-Path $listas 'wsl-distros.txt'
$scriptWsl  = Join-Path $raiz 'scripts\restaurar-wsl.sh'
$temaWsl    = Join-Path $arquivos 'custom.omp.json'

if (Test-Path $arqDistros) {
    $distros = Get-Content $arqDistros | Where-Object { $_ }
    if (-not $distros) { Aviso 'nenhuma distro WSL registrada' }
    if (-not $Simular -and -not (RedeOk)) {
        Aviso 'Sem conexao com github.com:443. Pulando restauracao WSL (precisa baixar oh-my-posh).'
        $distros = @()
    }
    foreach ($d in $distros) {
        $existe = (wsl.exe --list --quiet 2>$null | Out-String) -replace "`0",'' -split "`r?`n" |
                  Where-Object { $_.Trim() -eq $d }
        if (-not $existe) {
            Aviso "$d : distro nao existe nesta maquina (pule)"
            continue
        }
        if ($Simular) { Aviso "$d : restauraria o tema"; continue }

        # copia o script e o tema para um caminho visivel de dentro do WSL
        $tmp = Join-Path $env:TEMP "omp-restore-$d.sh"
        Copy-Item $scriptWsl $tmp -Force

        # O tema viaja como BASE64, e nao como caminho /mnt/...:
        #  - nem toda distro monta os drives do Windows (a OpenClawGateway
        #    deste PC nao monta nenhum);
        #  - no Linux /mnt/d e /mnt/D sao caminhos diferentes.
        $temaB64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($temaWsl))

        Executar "$d : restaura Oh My Posh" {
            $saida = (Get-Content $tmp -Raw | wsl.exe -d $d -e bash -s -- "$temaB64" 2>&1 | Out-String)
            $saida -split "`r?`n" | Where-Object { $_ -and $_ -notmatch 'systemd user session' } |
                ForEach-Object { Write-Host "        $_" -ForegroundColor DarkGray }
            if ($saida -notmatch '(?m)^OK\s*$') { throw 'o script nao confirmou sucesso' }
        }
    }
} else { Aviso 'lista de distros WSL ausente' }
} # fim Wsl

# ===========================================================================
Foco '[8/8] PowerShell 7 como padrao do sistema'
# ===========================================================================
if ($Simular) {
    Aviso 'definiria PowerShell 7 como perfil padrao do Windows Terminal e do Windows Explorer'
} else {
    # --- 8a: Windows Terminal - definir PowerShell 7 como perfil padrao ---
    $wtPkg = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
    if (Test-Path $wtPkg) {
        Executar 'Windows Terminal: definir PowerShell 7 como perfil padrao' {
            $wtJson = Get-Content $wtPkg -Raw | ConvertFrom-Json
            $pwshGuid = $null

            # Procurar perfil do PowerShell 7 (source Windows.Terminal.PowershellCore)
            foreach ($p in $wtJson.profiles.list) {
                if ($p.source -eq 'Windows.Terminal.PowershellCore') {
                    $pwshGuid = $p.guid
                    break
                }
                # Fallback: procurar por commandline com pwsh.exe
                if ($p.commandline -and $p.commandline -like '*pwsh*') {
                    $pwshGuid = $p.guid
                    break
                }
            }

            if ($pwshGuid) {
                if ($wtJson.defaultProfile -ne $pwshGuid) {
                    $wtJson.defaultProfile = $pwshGuid
                    $wtJson | ConvertTo-Json -Depth 10 | Set-Content $wtPkg -Encoding UTF8 -NoNewline
                    Ok "defaultProfile definido para: $pwshGuid"
                } else {
                    Ok "PowerShell 7 ja e o perfil padrao do Windows Terminal"
                }
            } else {
                Aviso 'Perfil do PowerShell 7 nao encontrado no Windows Terminal'
            }
        }
    } else {
        Aviso 'Windows Terminal nao encontrado (pacote MSIX ausente)'
    }

    # --- 8b: Windows Explorer - adicionar PowerShell 7 ao menu de contexto ---
    if (-not $selecao.RegExplorerMenu) {
        Aviso 'pulado (desmarcado no menu)'
    } else {
    Executar 'Windows Explorer: adicionar PowerShell 7 ao menu de contexto (pastas e drives)' {
        $pwshExe = Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'
        if (-not (Test-Path $pwshExe)) {
            $pwshExe = Join-Path $env:LOCALPROGRAMFILES 'PowerShell\7\pwsh.exe'
        }
        if (-not (Test-Path $pwshExe)) {
            Aviso 'pwsh.exe nao encontrado em C:\Program Files\PowerShell\7. Pulando menu de contexto.'
            return
        }

        # Comando para o menu de contexto do Explorer
        $comando = '"' + $pwshExe + '" -NoExit -Command "Set-Location ''%V''"'

        # Caminho do Ã­cone com Ã­ndice (o PowerShell 7 tem o Ã­cone azul no Ã­ndice 0 do executÃ¡vel)
        $iconePwsh = $pwshExe + ',0'

        try {
            # Directory (pastas)
            $regDir = 'HKCR:\Directory\shell\PowerShell7'
            if (-not (Test-Path $regDir)) { New-Item -Path $regDir -Force | Out-Null }
            Set-ItemProperty -Path $regDir -Name 'MUIVerb' -Value 'Abrir com PowerShell 7' -Type String -Force
            Set-ItemProperty -Path $regDir -Name 'Icon' -Value $iconePwsh -Type String -Force
            Set-ItemProperty -Path $regDir -Name 'Position' -Value 'Bottom' -Type String -Force
            New-Item -Path "$regDir\command" -Force | Out-Null
            Set-ItemProperty -Path "$regDir\command" -Name '' -Value $comando -Type String -Force

            # Drive (unidades)
            $regDrv = 'HKCR:\Drive\shell\PowerShell7'
            if (-not (Test-Path $regDrv)) { New-Item -Path $regDrv -Force | Out-Null }
            Set-ItemProperty -Path $regDrv -Name 'MUIVerb' -Value 'Abrir com PowerShell 7' -Type String -Force
            Set-ItemProperty -Path $regDrv -Name 'Icon' -Value $iconePwsh -Type String -Force
            Set-ItemProperty -Path $regDrv -Name 'Position' -Value 'Bottom' -Type String -Force
            New-Item -Path "$regDrv\command" -Force | Out-Null
            Set-ItemProperty -Path "$regDrv\command" -Name '' -Value $comando -Type String -Force

            Ok "PowerShell 7 adicionado ao menu de contexto do Explorer"
        } catch {
            Aviso "Falha ao configurar menu de contexto: $($_.Exception.Message)"
        }
    } # fim RegExplorerMenu
    }
}

# ===========================================================================
Write-Host ''
Write-Host '===========================================================' -ForegroundColor Cyan
if ($falhas -eq 0) {
    Write-Host '  Restauracao concluida' -ForegroundColor Green
} else {
    Write-Host "  Concluida com $falhas problema(s) -- veja as linhas [ERRO]" -ForegroundColor Yellow
}
Write-Host ''
Write-Host '  PROXIMOS PASSOS:'
Write-Host '   1. Abra um terminal NOVO (o PATH so vale para processos novos)'
Write-Host '   2. Confira se a Hack Nerd Font esta selecionada no terminal'
Write-Host '   3. Se o git reclamar do editor, ajuste:'
Write-Host '        git config --global core.editor "code --wait"'
Write-Host '   4. Se o Windows Terminal nao Apply, abra o JSON e cole arquivos\settings-terminal.json'
Write-Host '   5. Clique com o botao direito em uma pasta/disco: "Abrir com PowerShell 7"'
Write-Host '===========================================================' -ForegroundColor Cyan
if ($logFile) {
    Stop-Transcript | Out-Null
    Write-Host "`nLog salvo em: $logFile" -ForegroundColor DarkGray
}
