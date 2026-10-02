@echo off
title Saark ERP - Master Launcher
echo ========================================================
echo Launching all Saark Exploration ERP Services...
echo ========================================================
start "Saark ERP Backend" "%~dp0start_backend.bat"
start "Saark ERP Web" "%~dp0start_web.bat"
echo All services launched!
echo Backend Swagger API: http://localhost:3000/api/docs
echo Web App:            http://localhost:8085
echo.
pause
