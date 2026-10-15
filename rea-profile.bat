@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\invoke-rea.ps1" %*
exit /b %ERRORLEVEL%
