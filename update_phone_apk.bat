@echo off
title Saark ERP - Build & Update Phone APK
setlocal enabledelayedexpansion

echo ========================================================
echo        Saark ERP - Smartphone APK Builder & Installer    
echo ========================================================

:: 1. Find Flutter
set "FLUTTER_CMD=flutter"
where flutter >nul 2>nul
if %errorlevel% neq 0 (
    if exist "D:\saark\flutter\bin\flutter.bat" (
        set "FLUTTER_CMD=D:\saark\flutter\bin\flutter.bat"
    ) else (
        echo [ERROR] Flutter SDK not found in PATH or D:\saark\flutter\bin.
        echo Please ensure Flutter is installed.
        pause
        exit /b 1
    )
)

:: 2. Build Updated APK
echo.
echo [1/3] Compiling latest Saark ERP APK with all recent changes...
cd /d "%~dp0apps\mobile"
call !FLUTTER_CMD! build apk --debug
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Flutter APK compilation failed!
    pause
    exit /b %errorlevel%
)

:: 3. Copy APK to root folder for easy access
set "APK_SOURCE=%~dp0apps\mobile\build\app\outputs\flutter-apk\app-debug.apk"
set "APK_DEST=%~dp0Saark_ERP.apk"
if exist "!APK_SOURCE!" (
    copy /y "!APK_SOURCE!" "!APK_DEST!" >nul
    echo.
    echo [2/3] Latest APK copied to: !APK_DEST!
)

:: 4. Locate ADB
echo.
echo [3/3] Checking connected phone via USB ADB...
set "ADB_CMD="
where adb >nul 2>nul
if %errorlevel% equ 0 (
    set "ADB_CMD=adb"
) else if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" (
    set "ADB_CMD=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
) else if exist "C:\Android\Sdk\platform-tools\adb.exe" (
    set "ADB_CMD=C:\Android\Sdk\platform-tools\adb.exe"
) else if exist "D:\Android\Sdk\platform-tools\adb.exe" (
    set "ADB_CMD=D:\Android\Sdk\platform-tools\adb.exe"
)

if defined ADB_CMD (
    echo Using ADB: !ADB_CMD!
    echo.
    echo Connected devices:
    "!ADB_CMD!" devices
    echo.

    echo Installing APK to your phone...
    "!ADB_CMD!" install -r "!APK_SOURCE!"
    if !errorlevel! equ 0 (
        echo.
        echo Launching Saark ERP on device...
        "!ADB_CMD!" shell monkey -p com.example.saark_erp_mobile -c android.intent.category.LAUNCHER 1 >nul 2>nul
        echo.
        echo ========================================================
        echo [SUCCESS] Saark ERP has been installed & launched on your phone!
        echo ========================================================
    ) else (
        echo.
        echo [NOTICE] ADB install failed or phone not authorized.
        echo Please make sure:
        echo   1. USB Debugging is ON in Android Developer Options.
        echo   2. You tapped 'Allow USB Debugging' on your phone screen.
        echo.
        echo ALTERNATIVE: You can copy 'Saark_ERP.apk' directly to your phone,
        echo or download it via browser at: http://192.168.1.104:3000/download/apk
    )
) else (
    echo ADB tool not found directly. Attempting Flutter Install...
    cd /d "%~dp0apps\mobile"
    call !FLUTTER_CMD! install
    if !errorlevel! equ 0 (
        echo ========================================================
        echo [SUCCESS] App installed on phone via Flutter!
        echo ========================================================
    ) else (
        echo.
        echo [NOTE] Could not install via USB automatically.
        echo You can manually copy '%APK_DEST%' to your phone,
        echo or download it from phone browser at: http://192.168.1.104:3000/download/apk
    )
)

echo.
pause
