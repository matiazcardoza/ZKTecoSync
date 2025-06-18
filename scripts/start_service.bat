@echo off
REM Script silencioso para iniciar servicio ZKTeco durante la instalación

REM Cambiar al directorio de la aplicación
cd /d "%~dp0.."

REM Verificar si ya está ejecutándose
tasklist /FI "IMAGENAME eq zkteco_service.exe" 2>NUL | find /I /N "zkteco_service.exe">NUL
if "%ERRORLEVEL%"=="0" (
    REM Ya está ejecutándose, salir silenciosamente
    exit /b 0
)

REM Crear directorio de logs si no existe
if not exist "logs" mkdir "logs"

REM Iniciar servicio en segundo plano sin ventana
start /B "" "%~dp0..\zkteco_service.exe" start > "logs\service_start.log" 2>&1

REM Esperar brevemente para verificar inicio
timeout /t 2 /nobreak >nul 2>&1

REM Verificar si se inició correctamente
tasklist /FI "IMAGENAME eq zkteco_service.exe" 2>NUL | find /I /N "zkteco_service.exe">NUL
if "%ERRORLEVEL%"=="0" (
    REM Servicio iniciado correctamente
    echo Servicio iniciado exitosamente > "logs\install_status.log"
    exit /b 0
) else (
    REM Error al iniciar
    echo Error al iniciar servicio >> "logs\install_status.log"
    exit /b 1
)