<#
.SYNOPSIS
    Instalador one-shot do ShellForge.

.DESCRIPTION
    Baixa o repositorio do GitHub (zip da branch main) para uma pasta temporaria
    e executa o ShellForge.ps1 de la, repassando os parametros.

    Como o ShellForge e multi-arquivo (perfis, temas, fontes, listas, script WSL),
    nao basta fazer "irm .../ShellForge.ps1 | iex": o script precisa das pastas
    arquivos/, listas/ e scripts/ ao lado dele. Este bootstrap resolve isso.

.PARAMETER SomenteConfig
    Repassado ao ShellForge.ps1 (pula Scoop/modulos/fonte, mas aplica WSL).

.PARAMETER Simular
    Repassado ao ShellForge.ps1 (dry-run).

.EXAMPLE
    irm https://raw.githubusercontent.com/Samueldn23/ShellForge/main/install.ps1 | iex

    Instala tudo (modo padrao).

.EXAMPLE
    & ([ScriptBlock]::Create((irm https://raw.githubusercontent.com/Samueldn23/ShellForge/main/install.ps1))) -Simular

    Dry-run (mostra o que seria feito, sem alterar nada).

.EXAMPLE
    & ([ScriptBlock]::Create((irm https://raw.githubusercontent.com/Samueldn23/ShellForge/main/install.ps1))) -SomenteConfig

    So arquivos de configuracao + WSL.
#>

param(
    [switch]$SomenteConfig,
    [switch]$Simular
)

$ErrorActionPreference = 'Stop'

# --- 1. PowerShell 7 ---------------------------------------------------------
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host ''
    Write-Host 'Este instalador precisa do PowerShell 7 (pwsh).' -ForegroundColor Yellow
    Write-Host 'Instale em: https://aka.ms/powershell' -ForegroundColor Yellow
    Write-Host ''
    return
}

# TLS 1.2 (PowerShell antigo negocia TLS 1.0, que o GitHub rejeita)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- 2. Execution Policy ------------------------------------------------------
$policy = Get-ExecutionPolicy -Scope CurrentUser -ErrorAction SilentlyContinue
if (-not $policy -or $policy -eq 'Restricted') {
    Write-Host 'Habilitando execucao de scripts (CurrentUser, RemoteSigned)...' -ForegroundColor Yellow
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
}

# --- Funcao: menu grafico (WPF), estilo winutil -------------------------------
function Show-ShellForgeMenuWpf {
    # Retorna 'Full', 'Config', 'Sim' ou 'Cancel'. Retorna $null se falhar.
    $xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="ShellForge" Height="340" Width="540"
        WindowStartupLocation="CenterScreen" ResizeMode="NoResize"
        Background="#1E1E2E">
  <Grid Margin="24">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <TextBlock Grid.Row="0" Text="ShellForge" FontSize="24" FontWeight="Bold" Foreground="#89B4FA" Margin="0,0,0,2"/>
    <TextBlock Grid.Row="1" Text="Personalizacao do shell - escolha o modo de instalacao" Foreground="#CDD6F4" Margin="0,0,0,16" FontSize="12"/>
    <StackPanel Grid.Row="2">
      <RadioButton x:Name="rbFull" IsChecked="True" Foreground="#CDD6F4" Margin="0,6" FontSize="13">
        <TextBlock Text="Instalacao completa (Scoop, modulos, fonte, configs, WSL)"/>
      </RadioButton>
      <RadioButton x:Name="rbConfig" Foreground="#CDD6F4" Margin="0,6" FontSize="13">
        <TextBlock Text="Somente configuracao (pula Scoop/modulos/fonte, aplica WSL)"/>
      </RadioButton>
      <RadioButton x:Name="rbSim" Foreground="#CDD6F4" Margin="0,6" FontSize="13">
        <TextBlock Text="Simulacao (dry-run: mostra tudo, nao altera nada)"/>
      </RadioButton>
    </StackPanel>
    <StackPanel Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,20,0,0">
      <Button x:Name="btnCancel" Content="Cancelar" Width="100" Margin="0,0,10,0" Padding="8,5"/>
      <Button x:Name="btnRun" Content="Executar" Width="100" Padding="8,5" IsDefault="True" Background="#89B4FA" Foreground="#1E1E2E" FontWeight="Bold"/>
    </StackPanel>
  </Grid>
</Window>
'@
    try {
        $x = [xml]$xaml
        $reader = New-Object System.Xml.XmlNodeReader $x
        $window = [System.Windows.Markup.XamlReader]::Load($reader)
    } catch {
        return $null
    }

    $rbFull    = $window.FindName('rbFull')
    $rbConfig  = $window.FindName('rbConfig')
    $rbSim     = $window.FindName('rbSim')
    $btnRun    = $window.FindName('btnRun')
    $btnCancel = $window.FindName('btnCancel')

    $state = [hashtable]::Synchronized(@{ Result = $null })
    $btnRun.Add_Click({
        if ($rbFull.IsChecked)        { $state.Result = 'Full' }
        elseif ($rbConfig.IsChecked)  { $state.Result = 'Config' }
        elseif ($rbSim.IsChecked)     { $state.Result = 'Sim' }
        $window.Close()
    }.GetNewClosure())
    $btnCancel.Add_Click({ $window.Close() }.GetNewClosure())

    $window.ShowDialog() | Out-Null
    if ($null -eq $state.Result) { return 'Cancel' }
    return $state.Result
}

# --- 2b. Menu (WPF se disponivel, senao texto) -------------------------------
# Tenta carregar WPF
$wpfOk = $false
try {
    Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
    Add-Type -AssemblyName PresentationCore       -ErrorAction Stop
    Add-Type -AssemblyName WindowsBase           -ErrorAction Stop
    $wpfOk = $true
} catch { $wpfOk = $false }

if (-not $SomenteConfig -and -not $Simular -and -not [Console]::IsInputRedirected) {
    if ($wpfOk) {
        $choice = Show-ShellForgeMenuWpf
        if ($choice -eq 'Cancel' -or $null -eq $choice) {
            Write-Host 'Cancelado.' -ForegroundColor Yellow
            return
        }
        switch ($choice) {
            'Config' { $SomenteConfig = $true }
            'Sim'    { $Simular       = $true }
        }
    } else {
        # Fallback: menu de texto
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
            '4' { Write-Host 'Cancelado.' -ForegroundColor Yellow; return }
        }
        Write-Host ''
    }
}

# --- 3. Baixa o repo (zip da branch main) ------------------------------------
$repoZip = 'https://github.com/Samueldn23/ShellForge/archive/refs/heads/main.zip'
$stamp   = Get-Date -Format 'yyyyMMdd-HHmmss'
$tempDir = Join-Path $env:TEMP "ShellForge-$stamp"
$zipFile = Join-Path $env:TEMP "ShellForge-$stamp.zip"

Write-Host ''
Write-Host '===========================================================' -ForegroundColor Cyan
Write-Host '  ShellForge - instalador' -ForegroundColor Cyan
Write-Host '===========================================================' -ForegroundColor Cyan
Write-Host "  Origem : $repoZip"
Write-Host "  Destino: $tempDir"
Write-Host ''

try {
    Write-Host 'Baixando repositorio...' -ForegroundColor Cyan
    Invoke-WebRequest -Uri $repoZip -OutFile $zipFile -UseBasicParsing

    Write-Host 'Extraindo...' -ForegroundColor Cyan
    Expand-Archive -Path $zipFile -DestinationPath $tempDir -Force

    $raiz = Get-ChildItem -Path $tempDir -Directory | Select-Object -First 1
    if (-not $raiz) { throw 'Nenhuma pasta encontrada no zip.' }

    $script = Join-Path $raiz.FullName 'ShellForge.ps1'
    if (-not (Test-Path $script)) { throw "ShellForge.ps1 nao encontrado em $($raiz.FullName)." }

    # --- 4. Repasse dos parametros -------------------------------------------
    # Hashtable (splatting nomeado) - array de strings seria tratado como
    # argumentos posicionais e falharia ao casar com os switches.
    $forward = @{}
    if ($SomenteConfig) { $forward['SomenteConfig'] = $true }
    if ($Simular)       { $forward['Simular']       = $true }

    Write-Host ''
    $flags = $forward.Keys | ForEach-Object { "-$_" }
    Write-Host "Executando: pwsh -File ShellForge.ps1 $($flags -join ' ')" -ForegroundColor Cyan
    Write-Host ''

    & $script @forward

    Write-Host ''
    Write-Host "Fontes baixadas em: $($raiz.FullName)" -ForegroundColor DarkGray
    Write-Host 'Pode apagar essa pasta depois; os arquivos ja foram copiados para os destinos.' -ForegroundColor DarkGray
}
catch {
    Write-Host ''
    Write-Host "[ERRO] $($_.Exception.Message)" -ForegroundColor Red
    throw
}
finally {
    Remove-Item $zipFile -Force -ErrorAction SilentlyContinue
}