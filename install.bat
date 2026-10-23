@echo off
setlocal EnableExtensions
title ShellForge - instalador
color 0A

:: ===========================================================================
:: install.bat - instalador one-shot (equivalente ao install.ps1)
:: ===========================================================================
:: Baixa o repositorio e roda o ShellForge.ps1. Use este .bat se voce so tem
:: este arquivo (sem o repo). Se voce ja tem a pasta do repo, use ShellForge.bat.
::
:: Uso:
::   install.bat
::   install.bat -Simular
::   install.bat -SomenteConfig
:: ===========================================================================

:: --- 1. Localiza o pwsh.exe --------------------------------------------------
set "PWSH="
where pwsh >nul 2>&1
if not errorlevel 1 (
    for /f "delims=" %%P in ('where pwsh') do set "PWSH=%%P" & goto :foundPwsh
)
for %%C in (
    "%ProgramFiles%\PowerShell\7\pwsh.exe"
    "%ProgramFiles(x86)%\PowerShell\7\pwsh.exe"
) do (
    if exist %%C ( set "PWSH=%%~C" & goto :foundPwsh )
)

:foundPwsh
if not defined PWSH (
    echo PowerShell 7 nao encontrado. Tentando instalar via winget...
    winget install --id Microsoft.PowerShell -e --silent --accept-package-agreements --accept-source-agreements
    if errorlevel 1 (
        echo Falha ao instalar o PowerShell 7. Instale manualmente: https://aka.ms/powershell
        pause
        exit /b 1
    )
    for %%C in (
        "%ProgramFiles%\PowerShell\7\pwsh.exe"
        "%ProgramFiles(x86)%\PowerShell\7\pwsh.exe"
    ) do (
        if exist %%C ( set "PWSH=%%~C" & goto :foundPwsh2 )
    )
    :foundPwsh2
    if not defined PWSH (
        echo PowerShell 7 instalado, mas nao encontrado. Abra um NOVO prompt.
        pause
        exit /b 1
    )
)

:: --- 2. Repassa os argumentos ------------------------------------------------
set "ARGS="
:collectArgs
if "%~1"=="" goto :run
set "ARGS=%ARGS% %1"
shift
goto :collectArgs
:run

echo.
echo Baixando e executando o ShellForge (is.gd/shellforge)...
echo.
"%PWSH%" -NoProfile -ExecutionPolicy Bypass -Command "irm https://is.gd/shellforge | iex" %ARGS%
:: Nota: argumentos para o script remoto nao sao repassados pelo irm|iex.
:: Para usar -Simular/-SomenteConfig, prefira ShellForge.bat ao lado do repo,
:: ou rode: pwsh -File install.ps1 -Simular
set "RC=%ERRORLEVEL%"

echo.
echo ============================================================
echo  Codigo de saida: %RC%
echo ============================================================
pause
endlocal
exit /b %RC%