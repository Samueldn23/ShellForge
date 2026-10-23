@echo off
setlocal EnableExtensions
title ShellForge
color 0A

:: ===========================================================================
:: ShellForge.bat - launcher para o ShellForge.ps1
:: ===========================================================================
:: Este .bat NAO reimplementa a logica (ela esta no ShellForge.ps1). Ele apenas:
::   1. Garante que o PowerShell 7 (pwsh) esta instalado.
::   2. Repassa os argumentos (-Simular, -SomenteConfig) para o script.
::   3. Mantem a janela aberta ao final para voce ver o resultado.
::
:: Uso:
::   ShellForge.bat
::   ShellForge.bat -Simular
::   ShellForge.bat -SomenteConfig
:: ===========================================================================

:: --- 1. Localiza o pwsh.exe --------------------------------------------------
set "PWSH="
:: Filtra a saida do 'where' para ignorar mensagens do console (ex.: "Pagina de
:: codigo ativa: 65001") e capturar apenas linhas que contenham pwsh.exe.
where pwsh 2>nul | findstr /i /l "pwsh.exe" > "%TEMP%\_sf_pwsh.txt"
if exist "%TEMP%\_sf_pwsh.txt" (
    for /f "usebackq delims=" %%P in ("%TEMP%\_sf_pwsh.txt") do ( set "PWSH=%%P" & goto :foundPwsh )
    del "%TEMP%\_sf_pwsh.txt" 2>nul
)
:: Tenta caminhos conhecidos do PowerShell 7
for %%C in (
    "%ProgramFiles%\PowerShell\7\pwsh.exe"
    "%ProgramFiles(x86)%\PowerShell\7\pwsh.exe"
    "%LOCALAPPDATA%\Microsoft\WindowsApps\pwsh.exe"
) do (
    if exist %%C ( set "PWSH=%%~C" & goto :foundPwsh )
)

:foundPwsh
if not defined PWSH (
    echo.
    echo PowerShell 7 nao encontrado no PATH.
    echo Tentando instalar via winget...
    winget install --id Microsoft.PowerShell -e --silent --accept-package-agreements --accept-source-agreements
    if errorlevel 1 (
        echo.
        echo Falha ao instalar o PowerShell 7.
        echo Instale manualmente: https://aka.ms/powershell
        pause
        exit /b 1
    )
    :: re-procura apos a instalacao
    for %%C in (
        "%ProgramFiles%\PowerShell\7\pwsh.exe"
        "%ProgramFiles(x86)%\PowerShell\7\pwsh.exe"
    ) do (
        if exist %%C ( set "PWSH=%%~C" & goto :foundPwsh2 )
    )
    :foundPwsh2
    if not defined PWSH (
        echo PowerShell 7 instalado, mas nao encontrado. Abra um NOVO prompt e rode de novo.
        pause
        exit /b 1
    )
)

:: --- 2. Verifica se o script existe ao lado do .bat --------------------------
set "SCRIPT=%~dp0ShellForge.ps1"
if not exist "%SCRIPT%" (
    echo.
    echo ShellForge.ps1 nao encontrado em: %~dp0
    echo Coloque o .bat na mesma pasta do ShellForge.ps1.
    pause
    exit /b 1
)

:: --- 2b. Garante ExecutionPolicy (RemoteSigned) para o usuario ---------------
"%PWSH%" -NoProfile -Command "Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force" >nul 2>&1

:: --- 3. Repassa os argumentos e executa --------------------------------------
set "ARGS="
:collectArgs
if "%~1"=="" goto :run
set "ARGS=%ARGS% %1"
shift
goto :collectArgs
:run
echo.
echo Executando: "%PWSH%" -File "%SCRIPT%"%ARGS%
echo.
"%PWSH%" -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"%ARGS%
set "RC=%ERRORLEVEL%"

echo.
echo ============================================================
echo  Codigo de saida: %RC%
echo ============================================================
pause
endlocal
exit /b %RC%