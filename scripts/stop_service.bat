@echo off
setlocal

REM =========================================================
REM Script para detener el servicio ZKTeco de forma amigable.
REM =========================================================

echo Intentando detener el servicio ZKTeco de forma amigable...

REM Comprobar si el servicio ya no está en ejecución
tasklist /FI "IMAGENAME eq zkteco_service.exe" | find "zkteco_service.exe" >nul
if not %ERRORLEVEL%==0 (
    echo [INFO] El servicio ya esta detenido.
    exit /b 0
)

REM Intentar detener amigablemente usando la API de shutdown
powershell -command "try { Invoke-WebRequest -Uri http://127.0.0.1:3322/shutdown -Method POST -TimeoutSec 5 -ErrorAction Stop } catch { exit 1 }"
if %ERRORLEVEL%==0 (
    echo [EXITO] Peticion de apagado enviada. Esperando a que el servicio se detenga...
    timeout /t 5 /nobreak >nul
) else (
    echo [ALERTA] No se pudo conectar con el servicio.
)

REM Comprobar si se detuvo
tasklist /FI "IMAGENAME eq zkteco_service.exe" | find "zkteco_service.exe" >nul
if %ERRORLEVEL%==0 (
    echo [ALERTA] El servicio no se detuvo despues de la peticion. Forzando el cierre...
    taskkill /F /IM "zkteco_service.exe" >nul
    timeout /t 2 /nobreak >nul
    echo [EXITO] Servicio detenido.
    exit /b 0
) else (
    echo [EXITO] Servicio detenido correctamente.
    exit /b 0
)