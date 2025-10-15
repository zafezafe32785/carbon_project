@echo off
REM =============================================================================
REM Carbon Project - Deploy Frontend to NIPA Cloud (Windows)
REM =============================================================================

REM Configuration
set SERVER=103.29.190.75
set USER=nc-user
set REMOTE_PATH=/home/nc-user/carbon_project

echo ================================
echo Carbon Project - Deploy Frontend
echo ================================
echo.

REM Check if frontend build exists
if not exist "frontend\build\web\" (
    echo [ERROR] frontend\build\web directory not found!
    echo Please run 'flutter build web' first.
    pause
    exit /b 1
)

echo [OK] Frontend build found
echo.

REM Upload frontend files
echo Step 1: Uploading frontend files to server...
scp -r frontend\build\web\* %USER%@%SERVER%:%REMOTE_PATH%/frontend/build/web/

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Upload failed
    pause
    exit /b 1
)

echo [OK] Files uploaded successfully
echo.

REM Restart nginx container on server
echo Step 2: Restarting nginx container...
ssh %USER%@%SERVER% "cd %REMOTE_PATH% && docker-compose restart nginx"

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Restart failed
    pause
    exit /b 1
)

echo [OK] Nginx restarted successfully
echo.

REM Check container status
echo Step 3: Checking container status...
ssh %USER%@%SERVER% "cd %REMOTE_PATH% && docker-compose ps"
echo.

echo ================================
echo Deployment Complete!
echo ================================
echo.
echo Visit: http://%SERVER%
echo.
pause
