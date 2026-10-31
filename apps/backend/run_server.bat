@echo off
cd /d "d:\saark_ERP\company-erp-system\apps\backend"
"C:\Program Files\nodejs\node.exe" dist\src\main.js > out.log 2>&1
