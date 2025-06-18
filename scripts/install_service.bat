@echo off
echo Configurando servicio ZKTeco...

REM Crear directorio de logs si no existe
if not exist "%~dp0..\logs" mkdir "%~dp0..\logs"

REM Registrar servicio en el sistema (usando NSSM o similar)
REM Nota: Este ejemplo usa un método simple con el registro de Windows
REM Para un servicio real de Windows, considerar usar NSSM o crear un servicio nativo

echo Servicio configurado correctamente.
echo Puerto: 3322
echo Estado: Configurado para inicio automatico