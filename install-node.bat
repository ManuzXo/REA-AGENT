@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\install-tools.ps1" -Tool Node %*
set "setup_exit=%ERRORLEVEL%"
if "%~1"=="" pause
exit /b %setup_exit%
