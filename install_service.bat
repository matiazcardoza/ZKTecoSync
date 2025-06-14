@echo off
echo ========================================
echo    INSTALADOR DE SERVICIO ZKTECO SYNC
echo ========================================
echo.

REM Verificar permisos de administrador
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: Este script debe ejecutarse como Administrador
    echo.
    echo Haga clic derecho en este archivo y seleccione "Ejecutar como administrador"
    echo.
    pause
    exit /b 1
)

echo ✓ Permisos de administrador confirmados
echo.

REM Obtener directorio del script
set "SCRIPT_DIR=%~dp0"
set "SERVICE_EXE=%SCRIPT_DIR%zkteco_service.exe"

echo Directorio: %SCRIPT_DIR%
echo Ejecutable: %SERVICE_EXE%
echo.

REM Verificar que existe el ejecutable del servicio
if not exist "%SERVICE_EXE%" (
    echo ERROR: No se encuentra el archivo zkteco_service.exe
    echo Verifique que la instalación esté completa
    pause
    exit /b 1
)

echo ✓ Archivo del servicio encontrado
echo.

REM Crear directorios necesarios
echo Creando directorios necesarios...
if not exist "%SCRIPT_DIR%logs" mkdir "%SCRIPT_DIR%logs"
if not exist "%SCRIPT_DIR%config" mkdir "%SCRIPT_DIR%config"

REM Crear configuración por defecto si no existe
if not exist "%SCRIPT_DIR%config\device.json" (
    echo Creando configuración por defecto...
    echo { > "%SCRIPT_DIR%config\device.json"
    echo   "id": "1", >> "%SCRIPT_DIR%config\device.json"
    echo   "name": "Dispositivo ZKTeco", >> "%SCRIPT_DIR%config\device.json"
    echo   "ip_address": "192.168.1.100", >> "%SCRIPT_DIR%config\device.json"
    echo   "port": 4370 >> "%SCRIPT_DIR%config\device.json"
    echo } >> "%SCRIPT_DIR%config\device.json"
    echo ✓ Configuración por defecto creada
) else (
    echo ✓ Configuración existente encontrada
)
echo.

REM Detener servicio si está ejecutándose
echo Verificando servicios existentes...
sc query ZKTecoSync >nul 2>&1
if %errorLevel% equ 0 (
    echo Deteniendo servicio existente...
    net stop ZKTecoSync >nul 2>&1
    timeout /t 3 /nobreak >nul
    
    echo Removiendo servicio existente...
    "%SERVICE_EXE%" remove
    timeout /t 3 /nobreak >nul
    
    echo ✓ Servicio existente removido
) else (
    echo ✓ No hay servicio existente
)
echo.

REM Instalar servicio
echo Instalando servicio ZKTeco Sync...
cd /d "%SCRIPT_DIR%"
"%SERVICE_EXE%" install

if %errorLevel% equ 0 (
    echo ✓ Servicio instalado correctamente
    
    REM Configurar inicio automático
    echo Configurando inicio automático...
    sc config ZKTecoSync start= auto
    
    timeout /t 2 /nobreak >nul
    
    REM Iniciar servicio
    echo Iniciando servicio...
    "%SERVICE_EXE%" start
    
    if %errorLevel% equ 0 (
        echo ✓ Servicio iniciado correctamente
        
        REM Verificar que esté funcionando
        echo.
        echo Verificando funcionamiento del servicio...
        timeout /t 5 /nobreak >nul
        
        REM Verificar puerto 3322
        netstat -ano | findstr ":3322.*LISTENING" >nul 2>&1
        if %errorLevel% equ 0 (
            echo ✓ Servicio funcionando correctamente
            echo ✓ API REST activa en http://127.0.0.1:3322
            echo.
            echo ========================================
            echo           INSTALACIÓN EXITOSA
            echo ========================================
            echo.
            echo El servicio ZKTeco Sync está instalado y funcionando.
            echo.
            echo Verificar estado: http://127.0.0.1:3322/estado
            echo.
            echo Configure su dispositivo editando:
            echo %SCRIPT_DIR%config\device.json
            echo.
        ) else (
            echo ⚠ Servicio instalado pero la API puede tardar en responder
            echo   Espere unos minutos y verifique: http://127.0.0.1:3322/estado
            echo.
        )
        
    ) else (
        echo ⚠ Servicio instalado pero no se pudo iniciar automáticamente
        echo.
        echo Para iniciar manualmente:
        echo   net start ZKTecoSync
        echo.
    )
    
) else (
    echo ✗ Error instalando el servicio
    echo.
    echo Revise los logs en: %SCRIPT_DIR%logs\
    echo.
)

echo.
echo Presione cualquier tecla para continuar...
pause >nul