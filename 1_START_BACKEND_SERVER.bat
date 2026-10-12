@echo off
title Saark ERP - Backend Server
setlocal enabledelayedexpansion

set "PATH=C:\Program Files\nodejs;%PATH%"

set "NODE_CMD=node"
if exist "C:\Program Files\nodejs\node.exe" (
    set "NODE_CMD=C:\Program Files\nodejs\node.exe"
)

echo ========================================================
echo Starting Saark Exploration ERP Backend (Port 3000)...
echo ========================================================
echo [Localhost API]: http://localhost:3000
echo [Swagger Docs]:  http://localhost:3000/api/docs
echo ========================================================
cd /d "%~dp0apps\backend"
"!NODE_CMD!" dist/src/main.js
pause

