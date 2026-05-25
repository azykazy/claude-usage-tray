@echo off
set SCRIPT_DIR=%~dp0
set STARTUP=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup
set LINK=%STARTUP%\claude-usage-tray.lnk
set VBS=%SCRIPT_DIR%launch-silent.vbs

if "%1"=="remove" goto REMOVE

:ADD
powershell -Command "$ws = New-Object -ComObject WScript.Shell; $s = $ws.CreateShortcut('%LINK%'); $s.TargetPath = '%VBS%'; $s.Description = 'Claude Usage Tray'; $s.Save()"
echo.
echo [OK] Registered to Startup: %LINK%
echo     The tray will launch automatically on next Windows login.
echo     To start now, double-click launch-silent.vbs
goto END

:REMOVE
if exist "%LINK%" (
    del "%LINK%"
    echo [OK] Removed from Startup.
) else (
    echo [INFO] No startup entry found.
)

:END
echo.
pause
