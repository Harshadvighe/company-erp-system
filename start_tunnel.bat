@echo off
title Saark ERP - Cloudflare Public Tunnel (4G/5G Access)
echo ========================================================
echo Starting Cloudflare Tunnel for Port 3000...
echo This provides a public HTTPS link for 4G/5G mobile data.
echo ========================================================
cd /d "%~dp0"
cloudflared.exe tunnel --url http://localhost:3000 --protocol http2
pause
