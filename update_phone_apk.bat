@echo off
title Saark ERP - Update Phone APK
echo ========================================================
echo Installing updated Saark ERP APK to connected phone...
echo ========================================================
"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" install -r "%~dp0apps\mobile\build\app\outputs\flutter-apk\app-debug.apk"
echo.
echo Launching Saark ERP on device...
"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" shell monkey -p com.example.saark_erp_mobile -c android.intent.category.LAUNCHER 1
echo.
echo ========================================================
echo Done! App is updated and running on your phone.
echo ========================================================
pause
