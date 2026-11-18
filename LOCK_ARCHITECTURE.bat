@echo off
title Saark ERP - Author Security Locker
color 0c
echo ======================================================================
echo       SAARK EXPLORATION ERP - AUTHOR GOVERNANCE ^& FILE LOCKER
echo ======================================================================
echo.
echo Locking architectural blueprint and resetting author lease...
node apps\backend\scripts\author_file_guard.js lock
echo.
pause
