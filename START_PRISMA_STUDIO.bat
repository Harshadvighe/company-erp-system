@echo off
title Saark ERP - Prisma Studio Database Browser
setlocal enabledelayedexpansion

set "PATH=C:\Program Files\nodejs;%PATH%"

echo ========================================================
echo Starting Prisma Studio (Visual Database GUI)...
echo ========================================================
echo [URL]: http://localhost:5555
echo ========================================================
cd /d "%~dp0apps\backend"
call npx.cmd prisma studio --port 5555
pause
