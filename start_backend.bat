@echo off
title Saark ERP - Backend Server
echo ====================================================
echo Starting Saark Exploration ERP Backend (Port 3000)...
echo ====================================================
cd /d "%~dp0\apps\backend"
node dist/src/main.js
pause
