@echo off
chcp 65001 >nul
cd /d "%~dp0"

echo Stopping rocker-bayes...
docker compose stop

echo.
echo [OK] Server stopped. The files in your home folder are kept. Double-click
echo      start_windows.bat to start the server again.
echo.
pause
