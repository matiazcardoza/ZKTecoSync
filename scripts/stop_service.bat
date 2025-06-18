@echo off
REM Script silencioso para detener servicio ZKTeco durante la desinstalación

REM Verificar si está ejecutándose
tasklist /FI "IMAGENAME eq zkteco_service.exe" 2>NUL | find /I /N "zkteco_service.exe">NUL
if not "%ERRORLEVEL%"=="0" (
    REM No está ejecutándose, salir silenciosamente
    exit /b 0
)

REM Intentar detener amigablemente usando la API
curl -X POST http://127.0.0.1:3322/shutdown -m 5 >nul 2>&1
if %ERRORLEVEL%==0 (
    REM Esperar a que se detenga
    timeout /t 3 /nobreak >nul 2>&1
)

REM Verificar si se detuvo
tasklist /FI "IMAGENAME eq zkteco_service.exe" 2>NUL | find /I /N "zkteco_service.exe">NUL
if not "%ERRORLEVEL%"=="0" (
    REM Ya se detuvo
    exit /b 0
) else (
    REM Forzar cierre si es necesario
    taskkill /F /IM "zkteco_service.exe" >nul 2>&1
    timeout /t 1 /nobreak >nul 2>&1
    exit /b 0
)