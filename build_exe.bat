@echo off
echo Construyendo ZKTeco Sync Application...
echo.

REM Crear el ejecutable con PyInstaller
pyinstaller --onefile --windowed --name "ZKTecoSync" --icon=icon.ico main.py

echo.
echo Build completado. El ejecutable se encuentra en la carpeta 'dist'
echo.
pause