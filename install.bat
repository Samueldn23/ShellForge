@echo off
setlocal EnableExtensions
title ShellForge - instalador
color 0A

:: ===========================================================================
:: install.bat - instalador one-shot
:: ===========================================================================
:: 1. Garante que o PowerShell 7 (pwsh) esta instalado (winget se faltar).
:: 2. Baixa o install.ps1 para %TEMP%.
:: 3. Executa o install.ps1 no PowerShell 7, repassando os argumentos.
::
:: Uso:
::   install.bat
::   install.bat -Simular
::   install.bat -SomenteConfig
:: ===========================================================================

:: --- 1. Localiza o pwsh.exe --------------------------------------------------
call :findPwsh
if not defined PWSH (
    echo.
    echo PowerShell 7 nao encontrado. Tentando instalar via winget...
    winget install --id Microsoft.PowerShell -e --silent --accept-package-agreements --accept-source-agreements
    if errorlevel 1 (
        echo.
        echo Falha ao instalar o PowerShell 7 via winget.
        echo Instale manualmente: https://aka.ms/powershell
        pause
        exit /b 1
    )
    call :findPwsh
    if not defined PWSH (
        echo.
        echo PowerShell 7 instalado, mas nao encontrado nesta sessao.
        echo Abra um NOVO prompt de comando e rode o install.bat de novo.
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
echo Usando PowerShell 7: %PWSH%
echo.

:: --- 3. Baixa o install.ps1 para %TEMP% -------------------------------------
set "INSTALL_PS1=%TEMP%\ShellForge-install.ps1"
echo Baixando install.ps1...
"%PWSH%" -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Samueldn23/ShellForge/main/install.ps1' -OutFile '%INSTALL_PS1%' -UseBasicParsing"
if errorlevel 1 (
    echo.
    echo Falha ao baixar o install.ps1.
    echo Verifique sua conexao com a internet.
    pause
    exit /b 1
)
if not exist "%INSTALL_PS1%" (
    echo.
    echo install.ps1 nao foi salvo em %INSTALL_PS1%.
    pause
    exit /b 1
)

:: --- 4. Executa o install.ps1 no PowerShell 7 --------------------------------
echo Executando install.ps1%ARGS%...
echo.
"%PWSH%" -NoProfile -ExecutionPolicy Bypass -File "%INSTALL_PS1%"%ARGS%
set "RC=%ERRORLEVEL%"

:: --- 5. Limpeza -------------------------------------------------------------
del "%INSTALL_PS1%" >nul 2>&1

echo.
echo ============================================================
echo  Codigo de saida: %RC%
echo ============================================================
pause
endlocal
exit /b %RC%

:: ===========================================================================
:: Sub-rotina: encontra o pwsh.exe (caminhos conhecidos + where filtrado)
:: ===========================================================================
:findPwsh
set "PWSH="
:: Caminhos conhecidos primeiro
for %%C in (
    "%ProgramFiles%\PowerShell\7\pwsh.exe"
    "%ProgramFiles(x86)%\PowerShell\7\pwsh.exe"
    "%LOCALAPPDATA%\Microsoft\WindowsApps\pwsh.exe"
) do (
    if exist %%C ( set "PWSH=%%~C" & goto :eof )
)
:: Fallback: where filtrado (ignora mensagens do console como "Pagina de codigo ativa")
where pwsh 2>nul | findstr /i /l "pwsh.exe" > "%TEMP%\_sf_pwsh.txt"
if exist "%TEMP%\_sf_pwsh.txt" (
    for /f "usebackq delims=" %%P in ("%TEMP%\_sf_pwsh.txt") do ( set "PWSH=%%P" & goto :eof )
    del "%TEMP%\_sf_pwsh.txt" 2>nul
)
goto :eof