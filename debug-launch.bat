@echo off
set PS1=%~dp0claude-usage-tray.ps1
echo PS1 path: %PS1%
powershell.exe -ExecutionPolicy Bypass -STA -File "%PS1%"
echo Exit code: %ERRORLEVEL%
pause
