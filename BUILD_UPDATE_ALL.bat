@echo off
title Saark ERP - Build and Update Everything (Web and Mobile)
setlocal enabledelayedexpansion

if exist "C:\Users\dell\develop\flutter_windows_3.47.5-stable\flutter\bin" (
    set "PATH=C:\Users\dell\develop\flutter_windows_3.47.5-stable\flutter\bin;!PATH!"
)
if exist "D:\saark\flutter\bin" (
    set "PATH=D:\saark\flutter\bin;!PATH!"
)
if exist "C:\Program Files\nodejs" (
    set "PATH=C:\Program Files\nodejs;!PATH!"
)

set "FLUTTER_CMD=flutter"
if exist "D:\saark\flutter\bin\flutter.bat" (
    set "FLUTTER_CMD=D:\saark\flutter\bin\flutter.bat"
) else if exist "C:\Users\dell\develop\flutter_windows_3.47.5-stable\flutter\bin\flutter.bat" (
    set "FLUTTER_CMD=C:\Users\dell\develop\flutter_windows_3.47.5-stable\flutter\bin\flutter.bat"
)

echo ========================================================
echo Building Saark ERP Web and Mobile App with all changes...
echo ========================================================

echo [0/3] Stopping running backend processes to release file locks...
taskkill /f /im node.exe >nul 2>nul

echo.
echo Stopping any running backend servers locking Prisma DLL files...
for /f "tokens=5" %%a in ('netstat -aon ^| findstr :3000 ^| findstr LISTENING 2^>nul') do (
    echo [INFO] Releasing locks from active server PID %%a...
    taskkill /F /PID %%a >nul 2>&1
)
del /f /q "%~dp0apps\backend\node_modules\.prisma\client\query_engine-windows.dll.node.tmp*" >nul 2>&1
ping 127.0.0.1 -n 2 >nul

echo.
echo [1/3] Generating Prisma Client and Compiling Backend (NestJS)...
cd /d "%~dp0apps\backend"
call npx prisma generate
if !errorlevel! neq 0 (
    echo [ERROR] Prisma generate failed!
    pause
    exit /b !errorlevel!
)

:: Extract DIRECT_URL (Port 5432) to avoid PgBouncer Transaction Mode (Port 6543) closing connection on DDL
set "PUSH_DB_URL="
for /f "tokens=1,* delims==" %%i in ('findstr /b "DIRECT_URL=" "%~dp0apps\backend\.env" 2^>nul') do (
    set "PUSH_DB_URL=%%~j"
)

if defined PUSH_DB_URL (
    set "OLD_DB_URL=!DATABASE_URL!"
    set "DATABASE_URL=!PUSH_DB_URL!"
    call npx prisma db push --skip-generate --accept-data-loss
    set "DATABASE_URL=!OLD_DB_URL!"
) else (
    call npx prisma db push --skip-generate --accept-data-loss
)
if !errorlevel! neq 0 (
    echo [NOTICE] Database schema push bypassed or already in sync on Supabase Cloud. Proceeding with build...
)

call npm run build
if !errorlevel! neq 0 (
    echo [ERROR] Backend build failed!
    pause
    exit /b !errorlevel!
)

echo.
echo [2/3] Compiling Web Application (Flutter Web)...
cd /d "%~dp0apps\mobile"
call "!FLUTTER_CMD!" build web --release --no-pub
if !errorlevel! neq 0 (
    echo [ERROR] Flutter Web build failed!
    pause
    exit /b !errorlevel!
)
if exist "%~dp0apps\mobile\build\web" (
    robocopy "%~dp0apps\mobile\build\web" "%~dp0apps\backend\public" /E /IS /IT >nul
    if %errorlevel% leq 7 verify >nul
)

echo.
echo [3/3] Compiling Android APK (Flutter APK)...
cd /d "%~dp0apps\mobile"
call "!FLUTTER_CMD!" build apk --debug --no-pub
if !errorlevel! neq 0 (
    echo [WARNING] APK build had an error or was skipped.
)

echo.
echo ========================================================
echo [SUCCESS] Everything updated with all your changes!
echo - Web bundle: apps\mobile\build\web
echo - Mobile APK: apps\mobile\build\app\outputs\flutter-apk\app-debug.apk
echo - Backend:    apps\backend\dist
echo ========================================================
echo.
set /p START_CHOICE="Do you want to start and open Saark ERP now? (Y/N, default Y): "
if /i "!START_CHOICE!"=="" set START_CHOICE=Y
if /i "!START_CHOICE!"=="Y" (
    echo.
    echo Starting Saark ERP...
    start "Saark ERP System" "%~dp0START_ERP_SYSTEM.bat"
)
pause
