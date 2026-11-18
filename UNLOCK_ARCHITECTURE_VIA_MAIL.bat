@echo off
title Saark ERP - Author Security Unlocker
color 0b
echo ======================================================================
echo    SAARK EXPLORATION ERP - AUTHOR GOVERNANCE ^& FILE UNLOCKER
echo ======================================================================
echo.
echo Primary Author Email: sonwanep968@gmail.com
echo Protected Document  : SAARK_ERP_ARCHITECTURAL_BLUEPRINT_AND_WORKFLOWS.md
echo.
echo [1/2] Initiating permission request to author...
node apps\backend\scripts\author_file_guard.js request-otp pooja.saark@gmail.com
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Failed to connect to ERP backend server on http://127.0.0.1:3000.
    echo Please make sure the backend server is running (1_START_BACKEND_SERVER.bat).
    pause
    exit /b %errorlevel%
)

echo.
echo ======================================================================
echo An authorization OTP (6 digits) has been sent to sonwanep968@gmail.com
echo Delivery copy also dispatched to pooja.saark@gmail.com via Resend.
echo ======================================================================
echo.
set /p USER_OTP="Enter the 6-digit OTP from email: "

if "%USER_OTP%"=="" (
    echo [ERROR] No OTP entered. Operation aborted.
    pause
    exit /b 1
)

echo.
echo [2/2] Validating OTP and decrypting architectural blueprint...
node apps\backend\scripts\author_file_guard.js unlock %USER_OTP% pooja.saark@gmail.com
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] OTP verification failed or challenge expired.
    pause
    exit /b %errorlevel%
)

echo.
echo ======================================================================
echo [SUCCESS] File unlocked and decrypted! You may now open and edit:
echo SAARK_ERP_ARCHITECTURAL_BLUEPRINT_AND_WORKFLOWS.md
echo.
echo NOTE: When finished, run LOCK_ARCHITECTURE.bat to re-encrypt and lock!
echo ======================================================================
pause

