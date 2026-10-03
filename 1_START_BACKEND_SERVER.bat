@echo off
title Saark ERP - Backend Server
echo ========================================================
echo Starting Saark Exploration ERP Backend (Port 3000)...
echo ========================================================
echo [Localhost API]: http://localhost:3000
echo [Swagger Docs]:  http://localhost:3000/api/docs
echo ========================================================
cd /d "%~dp0\apps\backend"
node dist/src/main.js
pause
