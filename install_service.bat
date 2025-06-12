@echo off
setlocal enabledelayedexpansion

echo ==========================================
echo Instalando servicio ZKTeco Sync...
echo ==========================================
echo.

REM Verificar privilegios de administrador
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Este script debe ejecutarse como Administrador
    echo.
    echo Solucion:
    echo 1. Click derecho en el archivo install_service.bat
    echo 2. Seleccionar "Ejecutar como administrador"
    echo.
    pause
    exit /b 1
)

REM Cambiar al directorio de la aplicación
cd /d "%~dp0"

REM Verificar si el ejecutable del servicio existe
if not exist "zkteco_service.exe" (
    echo ERROR: No se encontró zkteco_service.exe
    echo Verifique que el archivo esté presente en la carpeta de instalación.
    echo Directorio actual: %CD%
    pause
    exit /b 1
)

echo Verificando si el servicio ya existe...
sc query ZKTecoSync >nul 2>&1
if %errorlevel% == 0 (
    echo El servicio ya existe. Deteniéndolo primero...
    net stop ZKTecoSync >nul 2>&1
    if %errorlevel% == 0 (
        echo ✓ Servicio detenido
    ) else (
        echo ! El servicio no estaba ejecutándose
    )
    
    echo Eliminando servicio existente...
    zkteco_service.exe remove >nul 2>&1
    if %errorlevel% neq 0 (
        echo Intentando eliminación manual...
        sc delete ZKTecoSync >nul 2>&1
    )
    echo ✓ Servicio anterior eliminado
    timeout /t 3 /nobreak >nul
)

echo.
echo Instalando nuevo servicio...
zkteco_service.exe install
if %errorlevel% neq 0 (
    echo ERROR: No se pudo instalar el servicio.
    echo Código de error: %errorlevel%
    echo.
    echo Posibles causas:
    echo - Falta permisos de administrador
    echo - Antivirus bloqueando la instalación
    echo - Puerto 3322 ya está en uso por otro programa
    echo.
    pause
    exit /b 1
)

echo ✓ Servicio instalado correctamente

echo.
echo Configurando inicio automático...
sc config ZKTecoSync start= auto
if %errorlevel% neq 0 (
    echo ADVERTENCIA: No se pudo configurar el inicio automático.
    echo El servicio deberá iniciarse manualmente.
) else (
    echo ✓ Inicio automático configurado
)

echo.
echo Configurando descripción del servicio...
sc description ZKTecoSync "Servicio de sincronización para dispositivos ZKTeco - Proporciona API REST en puerto 3322"
if %errorlevel% == 0 (
    echo ✓ Descripción configurada
)

echo.
echo Iniciando servicio...
net start ZKTecoSync
if %errorlevel% neq 0 (
    echo ERROR: No se pudo iniciar el servicio.
    echo.
    echo Posibles causas:
    echo - Puerto 3322 ya está en uso
    echo - Faltan dependencias de Python
    echo - Error en la configuración del servicio
    echo.
    echo Revise el log del servicio en: logs\service.log
    echo También puede verificar en el Visor de eventos de Windows
    echo.
    pause
    exit /b 1
)

echo ✓ Servicio iniciado correctamente

REM Esperar un momento para que el servicio se inicie completamente
echo.
echo Verificando que el servicio esté funcionando...
timeout /t 5 /nobreak >nul

REM Intentar hacer una petición HTTP para verificar
curl -s "http://127.0.0.1:3322/estado" >nul 2>&1
if %errorlevel% == 0 (
    echo ✓ API REST funcionando correctamente
) else (
    echo ! No se pudo verificar la API REST
    echo   Esto es normal si curl no está instalado
)

echo.
echo ==========================================
echo ✓ Servicio ZKTeco Sync instalado correctamente
echo ==========================================
echo.
echo Estado del servicio:
sc query ZKTecoSync | findstr "STATE"
echo.
echo El servidor estará disponible en: http://127.0.0.1:3322
echo Para verificar el estado: http://127.0.0.1:3322/estado
echo.
echo Comandos útiles:
echo - Detener servicio: net stop ZKTecoSync
echo - Iniciar servicio: net start ZKTecoSync
echo - Ver logs: notepad logs\service.log
echo.
echo Presione cualquier tecla para continuar...
pause >nul
exit /b 0