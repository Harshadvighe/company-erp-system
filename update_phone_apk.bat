@echo off
title Saark ERP - Build & Update Phone APK
echo ========================================================
echo 1/2 Compiling latest Saark ERP APK...
echo ========================================================
cd /d "%~dp0apps\mobile"
call flutter build apk --debug
if %errorlevel% neq 0 (
    echo [ERROR] Flutter APK build failed!
    pause
    exit /b %errorlevel%
)

echo.
echo ========================================================
echo 2/2 Installing updated Saark ERP APK to connected phone...
echo ========================================================
cd /d "%~dp0"
"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" install -r "%~dp0apps\mobile\build\app\outputs\flutter-apk\app-debug.apk"
echo.
echo Launching Saark ERP on device...
"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" shell monkey -p com.example.saark_erp_mobile -c android.intent.category.LAUNCHER 1
echo.
echo ========================================================
echo Done! App is updated and running on your phone.
echo ========================================================
pause
