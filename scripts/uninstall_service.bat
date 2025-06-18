@echo off
echo Desinstalando servicio ZKTeco...

REM Detener proceso si está ejecutándose
taskkill /F /IM "zkteco_service.exe" 2>nul

REM Eliminar del registro de inicio automático
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "ZKTecoService" /f 2>nul

echo Servicio desinstalado correctamente.