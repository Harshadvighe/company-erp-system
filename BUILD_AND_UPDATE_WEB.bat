@echo off
title Saark ERP - Build & Update Web App
echo ========================================================
echo Building Saark ERP Flutter Web Release...
echo ========================================================
cd /d "%~dp0apps\mobile"
call flutter build web --release
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Flutter build failed! Please make sure Flutter is in PATH.
    pause
    exit /b %errorlevel%
)
echo.
echo ========================================================
echo [SUCCESS] Web App updated successfully!
echo The NestJS backend and 4G/5G URL will now serve this updated web app.
echo ========================================================
pause
