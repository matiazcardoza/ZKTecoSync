@echo off
echo ==========================================
echo Verificador de Instalación ZKTeco Sync
echo ==========================================
echo.

REM Verificar si los archivos están presentes
echo 1. Verificando archivos...
if exist "ZKTeco-Sync.exe" (
    echo   ✓ ZKTeco-Sync.exe encontrado
) else (
    echo   ✗ ZKTeco-Sync.exe NO encontrado
)

if exist "zkteco_service.exe" (
    echo   ✓ zkteco_service.exe encontrado
) else (
    echo   ✗ zkteco_service.exe NO encontrado
)

echo.

REM Verificar estado del servicio
echo 2. Verificando servicio Windows...
sc query ZKTecoSync >nul 2>&1
if %errorlevel% == 0 (
    echo   ✓ Servicio ZKTecoSync instalado
    
    REM Obtener estado del servicio
    for /f "tokens=3" %%i in ('sc query ZKTecoSync ^| findstr "STATE"') do set SERVICE_STATE=%%i
    if "!SERVICE_STATE!"=="RUNNING" (
        echo   ✓ Servicio está ejecutándose
    ) else (
        echo   ! Servicio instalado pero no está ejecutándose
        echo   Estado: !SERVICE_STATE!
    )
) else (
    echo   ✗ Servicio ZKTecoSync NO instalado
)

echo.

REM Verificar conectividad del servidor
echo 3. Verificando servidor REST API...
curl -s -m 5 http://127.0.0.1:3322/estado >nul 2>&1
if %errorlevel% == 0 (
    echo   ✓ Servidor REST API respondiendo en puerto 3322
    echo   URL: http://127.0.0.1:3322/estado
) else (
    echo   ✗ Servidor REST API no responde en puerto 3322
    echo   Verifique que el servicio esté ejecutándose
)

echo.

REM Verificar logs
echo 4. Verificando logs...
if exist "logs\service.log" (
    echo   ✓ Archivo de log encontrado: logs\service.log
    echo   Últimas 3 líneas del log:
    echo   ----------------------------------------
    for /f "skip=0 tokens=*" %%i in ('powershell "Get-Content logs\service.log -Tail 3"') do echo   %%i
    echo   ----------------------------------------
) else (
    echo   ! No se encontró archivo de log (normal si el servicio no ha ejecutado)
)

echo.
echo ==========================================
echo Verificación completada
echo ==========================================
echo.

REM Ofrecer acciones
echo Acciones disponibles:
echo 1. Abrir aplicación GUI
echo 2. Verificar estado en navegador
echo 3. Ver logs completos
echo 4. Reinstalar servicio
echo 5. Salir
echo.
set /p choice="Seleccione una opción (1-5): "

if "%choice%"=="1" (
    start ZKTeco-Sync.exe
) else if "%choice%"=="2" (
    start http://127.0.0.1:3322/estado
) else if "%choice%"=="3" (
    if exist "logs\service.log" (
        notepad logs\service.log
    ) else (
        echo No hay logs disponibles
    )
) else if "%choice%"=="4" (
    call uninstall_service.bat
    timeout /t 3 /nobreak >nul
    call install_service.bat
) else (
    echo Saliendo...
)

pause