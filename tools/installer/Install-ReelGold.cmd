@echo off
rem ReelGold installer: double-click to find WoW: Forever and install the addon.
rem Options: Install-ReelGold.cmd -Uninstall ^| -ListOnly ^| -DeepScan ^| -Path "D:\Games\World of Warcraft"
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
set "RC=%ERRORLEVEL%"
echo.
pause
exit /b %RC%
