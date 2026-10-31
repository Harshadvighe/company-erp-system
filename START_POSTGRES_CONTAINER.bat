@echo off
echo ========================================================
echo     SAARK ERP: STARTING POSTGRESQL 16 CONTAINER
echo ========================================================
echo.

docker-compose up -d postgres

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Failed to start Docker container. Ensure Docker Desktop is installed and running.
    echo If you are using an external or cloud PostgreSQL database (Render, Neon, Supabase, AWS),
    echo configure your DATABASE_URL directly in apps/backend/.env.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [SUCCESS] PostgreSQL 16 is running on localhost:5432!
echo Database: saark_erp_db
echo Username: saark
echo Password: saark_secure_password
echo URL: postgresql://saark:saark_secure_password@localhost:5432/saark_erp_db?schema=public
echo.
pause
