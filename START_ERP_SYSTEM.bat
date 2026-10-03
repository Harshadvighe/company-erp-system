@echo off
title Saark ERP - Master Launcher
echo ========================================================
echo Launching Saark Exploration ERP System...
echo ========================================================
echo 1. Starting Backend API Server (Port 3000)...
start "Saark ERP Backend Server" "%~dp01_START_BACKEND_SERVER.bat"
timeout /t 3 /nobreak >nul

echo 2. Starting 4G/5G Online Access (Web, iOS, Android)...
call "%~dp02_START_4G_5G_AND_WEB.bat"
