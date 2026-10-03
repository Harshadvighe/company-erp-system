@echo off
title Saark ERP - 4G/5G Online Access (Web, iOS, Android)
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0start_tunnel.ps1"
pause
