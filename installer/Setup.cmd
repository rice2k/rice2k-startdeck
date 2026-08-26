@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title Rice2k Startpage Setup

echo.
echo ==========================================
echo        Rice2k Startpage Setup
echo ==========================================
echo.

if not exist "%~dp0index.html" (
  echo ERROR: index.html was not found next to Setup.cmd.
  echo Extract the ENTIRE ZIP before running Setup.cmd.
  echo Expected file:
  echo   %~dp0index.html
  echo.
  pause
  exit /b 1
)

if not exist "%~dp0install.ps1" (
  echo ERROR: install.ps1 was not found next to Setup.cmd.
  echo Extract the ENTIRE ZIP before running Setup.cmd.
  echo.
  pause
  exit /b 1
)

where powershell.exe >nul 2>&1
if errorlevel 1 (
  echo ERROR: Windows PowerShell was not found.
  echo This installer requires Windows PowerShell 5.1 or newer.
  echo.
  pause
  exit /b 1
)

rem Do NOT pass %%~dp0 as a quoted -SourceDir argument here.
rem %%~dp0 always ends in a backslash, which can be misparsed before PowerShell
rem and was the cause of the previous "Illegal characters in path" error.
rem install.ps1 safely uses its own $PSScriptRoot instead.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
set "RC=%ERRORLEVEL%"

echo.
if not "%RC%"=="0" (
  echo Setup did not complete. Error code: %RC%
  echo Read the message above for the reason.
) else (
  echo Setup completed successfully.
)
echo.
pause
exit /b %RC%
