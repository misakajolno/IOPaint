@echo off
setlocal
cd /d "%~dp0"

if exist "%~dp0IOPaint Launcher.exe" (
    start "" "%~dp0IOPaint Launcher.exe" --stop
    exit /b 0
)

set "PS_EXE=powershell.exe"
where pwsh.exe >nul 2>nul && set "PS_EXE=pwsh.exe"

if not exist "%~dp0windows\stop-iopaint.ps1" (
    echo [IOPaint] Missing stop script: "%~dp0windows\stop-iopaint.ps1"
    pause
    exit /b 1
)

"%PS_EXE%" -NoLogo -ExecutionPolicy Bypass -File "%~dp0windows\stop-iopaint.ps1"
set "EXIT_CODE=%ERRORLEVEL%"

if not "%EXIT_CODE%"=="0" (
    echo.
    echo [IOPaint] Stop script exited with code %EXIT_CODE%.
    pause
)

exit /b %EXIT_CODE%
