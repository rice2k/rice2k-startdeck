@echo off
if exist "C:\Startpage\index.html" (
  start "" "C:\Startpage\index.html"
) else (
  start "" "%~dp0index.html"
)
