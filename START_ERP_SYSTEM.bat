@echo off
title Saark ERP - Master Launcher
echo ========================================================
echo Launching Saark Exploration ERP System...
echo ========================================================
echo 1. Starting Backend API Server (Port 3000)...
start "Saark ERP Backend Server" "%~dp01_START_BACKEND_SERVER.bat"
timeout /t 3 /nobreak >nul

echo 2. Opening Saark ERP Web Application...
start "" "http://localhost:3000"
