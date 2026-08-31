@echo off
:: Set console to UTF-8
chcp 65001 >nul
cd /d "%~dp0"

echo Starting rocker-bayes...

:: Resolve the host port the same way docker compose does: shell environment
:: first, then .env, then the default.
set "PORT=8787"
if exist .env for /f "usebackq tokens=1,* delims==" %%a in (".env") do if /i "%%a"=="RS_PORT" set "PORT=%%b"
if defined RS_PORT set "PORT=%RS_PORT%"

:: Make sure Docker is running before doing anything else
docker info >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo [X] Docker does not appear to be running.
    echo     Please open Docker Desktop, wait for it to finish starting,
    echo     then double-click this file again.
    echo.
    pause
    exit /b 1
)

:: Get the latest image, then start the server and wait until it is healthy
docker compose pull
docker compose up -d --wait --wait-timeout 180
if %errorlevel% neq 0 (
    echo.
    echo [X] The server did not become ready in time. Please try again,
    echo     or check Docker Desktop for errors.
    echo.
    pause
    exit /b 1
)

echo.
echo ============================================================
echo [OK] RStudio Server is running at http://localhost:%PORT%
echo Opening your web browser...
echo ============================================================
echo.

start http://localhost:%PORT%
timeout /t 3 >nul
