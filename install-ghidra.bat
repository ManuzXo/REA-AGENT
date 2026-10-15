@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\setup-ghidra.ps1" %*
set "setup_exit=%ERRORLEVEL%"
if "%~1"=="" pause
exit /b %setup_exit%
