@echo off
title Saark ERP - Web Application (Port 8085)
echo ========================================================
echo Starting Saark ERP Web Application on Port 8085...
echo Access via browser: http://localhost:8085
echo Access via phone:   http://192.168.1.101:8085
echo ========================================================
cd /d "%~dp0\apps\mobile\build\web"
python -m http.server 8085
pause
