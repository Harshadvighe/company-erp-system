@echo off
title Saark ERP - Build & Update Everything (Web & Mobile)
echo ========================================================
echo Building Saark ERP Web & Mobile App with all changes...
echo ========================================================

echo.
echo [1/3] Compiling Backend (NestJS)...
cd /d "%~dp0apps\backend"
call npm run build
if %errorlevel% neq 0 (
    echo [ERROR] Backend build failed!
    pause
    exit /b %errorlevel%
)

echo.
echo [2/3] Compiling Web Application (Flutter Web)...
cd /d "%~dp0apps\mobile"
call flutter build web --release
if %errorlevel% neq 0 (
    echo [ERROR] Flutter Web build failed!
    pause
    exit /b %errorlevel%
)
if exist "%~dp0apps\mobile\build\web" (
    xcopy "%~dp0apps\mobile\build\web" "%~dp0apps\backend\public\" /E /I /Y >nul
)

echo.
echo [3/3] Compiling Android APK (Flutter APK)...
cd /d "%~dp0apps\mobile"
call flutter build apk --debug
if %errorlevel% neq 0 (
    echo [WARNING] APK build had an error or was skipped.
)

echo.
echo ========================================================
echo [SUCCESS] Everything updated with all your changes!
echo - Web bundle: apps\mobile\build\web
echo - Mobile APK: apps\mobile\build\app\outputs\flutter-apk\app-debug.apk
echo - Backend:    apps\backend\dist
echo ========================================================
pause
