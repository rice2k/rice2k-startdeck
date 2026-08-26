@echo off
setlocal EnableExtensions
title Restore Browser Homepage Settings

if exist "C:\Startpage\restore.ps1" (
  powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "C:\Startpage\restore.ps1"
) else if exist "%~dp0restore.ps1" (
  powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0restore.ps1"
) else (
  echo ERROR: restore.ps1 was not found.
  pause
  exit /b 1
)

set "RC=%ERRORLEVEL%"
echo.
pause
exit /b %RC%
