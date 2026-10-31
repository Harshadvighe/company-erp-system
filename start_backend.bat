@echo off
title Saark ERP - Backend Server
setlocal enabledelayedexpansion

set "PATH=C:\Program Files\nodejs;%PATH%"

set "NODE_CMD=node"
if exist "C:\Program Files\nodejs\node.exe" (
    set "NODE_CMD=C:\Program Files\nodejs\node.exe"
)

echo ========================================================
echo Checking and releasing Port 3000...
powershell -NoProfile -Command "Get-NetTCPConnection -LocalPort 3000 -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }"
for /f "tokens=5" %%a in ('netstat -aon ^| findstr :3000 ^| findstr LISTENING 2^>nul') do (
    echo [INFO] Releasing previous server PID %%a...
    taskkill /F /PID %%a >nul 2>&1
)
timeout /t 2 /nobreak >nul

echo Starting Saark Exploration ERP Backend (Port 3000)...
echo ========================================================
echo [Localhost API]: http://localhost:3000
echo [Swagger Docs]:  http://localhost:3000/api/docs
echo ========================================================
cd /d "%~dp0apps\backend"
"!NODE_CMD!" dist/src/main.js
pause
