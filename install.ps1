<#
.SYNOPSIS
    Instalador one-shot do ShellForge.

.DESCRIPTION
    Baixa o repositorio do GitHub (zip da branch main) para uma pasta temporaria
    e executa o ShellForge.ps1 de la, repassando os parametros.

    O ShellForge.ps1 exibe o menu grafico (WPF) com checkboxes para escolher
    os componentes. Se rodado com -Simular/-SomenteConfig, o menu e pulado.

.PARAMETER SomenteConfig
    Repassado ao ShellForge.ps1 (pula Scoop/modulos/fonte, mas aplica WSL).

.PARAMETER Simular
    Repassado ao ShellForge.ps1 (dry-run).

.EXAMPLE
    irm https://is.gd/shellforge | iex
    irm https://raw.githubusercontent.com/Samueldn23/ShellForge/main/install.ps1 | iex

.EXAMPLE
    & ([ScriptBlock]::Create((irm https://is.gd/shellforge))) -Simular
    & ([ScriptBlock]::Create((irm https://is.gd/shellforge))) -SomenteConfig
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

# TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- 2. Execution Policy ------------------------------------------------------
$policy = Get-ExecutionPolicy -Scope CurrentUser -ErrorAction SilentlyContinue
if (-not $policy -or $policy -eq 'Restricted') {
    Write-Host 'Habilitando execucao de scripts (CurrentUser, RemoteSigned)...' -ForegroundColor Yellow
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
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

    # --- 4. Repassa os parametros e executa ----------------------------------
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