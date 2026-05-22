@echo off
REM Run setup from repo root without needing ".\portable_setup.ps1" in PowerShell.
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0portable_setup.ps1" %*
exit /b %ERRORLEVEL%
