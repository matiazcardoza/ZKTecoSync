@echo off
setlocal enabledelayedexpansion

echo ==========================================
echo Desinstalando servicio ZKTeco Sync...
echo ==========================================
echo.

REM Cambiar al directorio de la aplicación
cd /d "%~dp0"

REM Verificar si el servicio existe
sc query ZKTecoSync >nul 2>&1
if %errorlevel% neq 0 (
    echo El servicio ZKTecoSync no está instalado.
    goto :end
)

echo Detiendo servicio...
net stop ZKTecoSync >nul 2>&1
if %errorlevel% == 0 (
    echo ✓ Servicio detenido correctamente
) else (
    echo ! El servicio no estaba ejecutándose o hubo un error al detenerlo
)

REM Esperar un momento para asegurar que el servicio se detenga completamente
timeout /t 3 /nobreak >nul

echo Eliminando servicio...
if exist "zkteco_service.exe" (
    zkteco_service.exe remove
    if %errorlevel% == 0 (
        echo ✓ Servicio eliminado correctamente
    ) else (
        echo ! Error al eliminar el servicio usando el ejecutable
        echo Intentando eliminación manual...
        sc delete ZKTecoSync
    )
) else (
    echo Eliminando servicio manualmente...
    sc delete ZKTecoSync
)

:end
echo.
echo ==========================================
echo ✓ Proceso de desinstalación completado
echo ==========================================
echo.
echo Presione cualquier tecla para continuar...
pause >nul
exit /b 0