@echo off
setlocal

REM =========================================================
REM Script para iniciar el servicio ZKTeco.
REM Puede ser ejecutado de forma silenciosa o interactiva.
REM
REM Uso:
REM   start_service.bat            (Modo interactivo)
REM   start_service.bat SILENT     (Modo silencioso, sin pausa)
REM =========================================================

REM Cambiar al directorio de la aplicación
cd /d "%~dp0.."

REM Comprobar si el servicio ya está en ejecución
tasklist /FI "IMAGENAME eq zkteco_service.exe" | find "zkteco_service.exe" >nul
if %ERRORLEVEL%==0 (
    echo [ERROR] El servicio ZKTeco ya esta ejecutandose.
    if /I "%~1"=="SILENT" (
        exit /b 0
    ) else (
        echo Presione una tecla para salir...
        pause >nul
        exit /b 0
    )
)

echo Iniciando el servicio ZKTeco...

REM Iniciar el servicio
start /b "" "%~dp0..\zkteco_service.exe" start

REM Esperar un momento para la inicialización
timeout /t 5 /nobreak >nul

REM Comprobar si el servicio se inició correctamente
tasklist /FI "IMAGENAME eq zkteco_service.exe" | find "zkteco_service.exe" >nul
if %ERRORLEVEL%==0 (
    echo [EXITO] Servicio iniciado correctamente en el puerto 3322.
    if /I "%~1"=="SILENT" (
        exit /b 0
    ) else (
        echo El servicio ZKTeco esta en ejecucion.
        echo Presione una tecla para salir...
        pause >nul
        exit /b 0
    )
) else (
    echo [ERROR] No se pudo iniciar el servicio.
    if /I "%~1"=="SILENT" (
        exit /b 1
    ) else (
        echo Verifique los logs en el directorio de la aplicacion.
        echo Presione una tecla para salir...
        pause >nul
        exit /b 1
    )
)