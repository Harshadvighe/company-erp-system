@echo off
title Saark ERP - Web Application (Port 8085)
echo ========================================================
echo Starting Saark ERP Web Application on Port 8085...
echo Access via browser: http://localhost:8085
echo Access via phone:   http://192.168.1.104:8085 (or http://192.168.1.104:3000)
echo Access via tunnel:  Check start_tunnel.bat for public HTTPS
echo ========================================================
cd /d "%~dp0\apps\mobile\build\web"
python -m http.server 8085 --bind 0.0.0.0
pause

