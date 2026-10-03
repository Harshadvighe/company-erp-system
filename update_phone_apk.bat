@echo off
title Saark ERP - Direct USB Phone Installer
setlocal enabledelayedexpansion

echo ========================================================
echo        Saark ERP - Direct USB Phone APK Installer       
echo ========================================================

:: 1. Setup Environment Paths
set "PATH=D:\saark\flutter\bin;C:\Users\HP\AppData\Local\Android\sdk\platform-tools;C:\Program Files\nodejs;%PATH%"

set "FLUTTER_CMD=flutter"
if exist "D:\saark\flutter\bin\flutter.bat" (
    set "FLUTTER_CMD=D:\saark\flutter\bin\flutter.bat"
)

set "ADB_CMD=adb"
if exist "C:\Users\HP\AppData\Local\Android\sdk\platform-tools\adb.exe" (
    set "ADB_CMD=C:\Users\HP\AppData\Local\Android\sdk\platform-tools\adb.exe"
)

:: 2. Check Device Connection
echo [1/3] Restarting ADB server and detecting connected phone...
"!ADB_CMD!" kill-server >nul 2>nul
"!ADB_CMD!" start-server >nul 2>nul

echo.
echo Connected devices:
"!ADB_CMD!" devices
echo.

:: 3. Build Fresh APK
echo [2/3] Compiling latest Saark ERP APK...
cd /d "%~dp0apps\mobile"
call !FLUTTER_CMD! build apk --debug
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Flutter compilation failed!
    pause
    exit /b %errorlevel%
)

set "APK_SOURCE=%~dp0apps\mobile\build\app\outputs\flutter-apk\app-debug.apk"
set "APK_DEST=%~dp0Saark_ERP.apk"
if exist "!APK_SOURCE!" (
    copy /y "!APK_SOURCE!" "!APK_DEST!" >nul
)

:: 4. Direct Install to Phone
echo.
echo [3/3] Installing Saark ERP directly to your phone via USB...

:: Try ADB direct install with -r (replace), -t (allow test/debug APK), -d (allow downgrade)
"!ADB_CMD!" install -r -t -d "!APK_SOURCE!"
if !errorlevel! equ 0 (
    goto :SUCCESS
)

echo.
echo [!] Retrying with clean reinstall (uninstalling old package cache first)...
"!ADB_CMD!" uninstall com.example.saark_erp_mobile >nul 2>nul
"!ADB_CMD!" install -r -t "!APK_SOURCE!"
if !errorlevel! equ 0 (
    goto :SUCCESS
)

echo.
echo [!] Attempting Flutter Native Device Install...
cd /d "%~dp0apps\mobile"
call !FLUTTER_CMD! install
if !errorlevel! equ 0 (
    goto :SUCCESS
)

echo.
echo ========================================================
echo [FAILURE] Could not install directly to device.
echo.
echo Please verify on your phone:
echo 1. In Settings -^> Developer Options:
echo    - USB Debugging is ON
echo    - "Install via USB" is ON (Crucial for Xiaomi/Vivo/Realme/Oppo)
echo 2. When plugged in, unlock phone screen and tap "ALLOW" on prompt.
echo ========================================================
pause
exit /b 1

:SUCCESS
echo.
echo Launching Saark ERP on device screen...
"!ADB_CMD!" shell monkey -p com.example.saark_erp_mobile -c android.intent.category.LAUNCHER 1 >nul 2>nul
echo.
echo ========================================================
echo [SUCCESS] Saark ERP has been INSTALLED and OPENED on your phone!
echo ========================================================
pause
