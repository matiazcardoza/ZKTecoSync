[Setup]
AppName=ZKTeco Sync
AppVersion=1.2
AppPublisher=Tu Empresa
AppPublisherURL=https://www.tuempresa.com
AppSupportURL=https://www.tuempresa.com/soporte
AppUpdatesURL=https://www.tuempresa.com/actualizaciones
DefaultDirName={autopf}\ZKTeco Sync
DefaultGroupName=ZKTeco Sync
AllowNoIcons=yes
LicenseFile=
OutputDir=output
OutputBaseFilename=ZKTeco-Sync-Setup
SetupIconFile=
Compression=lzma
SolidCompression=yes
WizardImageFile=
WizardSmallImageFile=
ArchitecturesInstallIn64BitMode=x64
UninstallDisplayIcon={app}\ZKTeco-Sync.exe
UninstallDisplayName=ZKTeco Sync v1.2
VersionInfoVersion=1.2.0.0
VersionInfoCompany=Tu Empresa
VersionInfoDescription=Sistema de sincronización ZKTeco
VersionInfoCopyright=Copyright (C) 2025
VersionInfoProductName=ZKTeco Sync
VersionInfoProductVersion=1.2.0.0

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Files]
; Ejecutables principales
Source: "dist\ZKTeco-Sync.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "dist\zkteco_service.exe"; DestDir: "{app}"; Flags: ignoreversion

; Scripts de manejo del servicio (versiones interactivas)
Source: "scripts\install_service.bat"; DestDir: "{app}\scripts"; Flags: ignoreversion
Source: "scripts\start_service.bat"; DestDir: "{app}\scripts"; Flags: ignoreversion
Source: "scripts\stop_service.bat"; DestDir: "{app}\scripts"; Flags: ignoreversion
Source: "scripts\uninstall_service.bat"; DestDir: "{app}\scripts"; Flags: ignoreversion

; Scripts silenciosos para instalación/desinstalación
Source: "scripts\start_service.bat"; DestDir: "{app}\scripts"; Flags: ignoreversion
Source: "scripts\stop_service.bat"; DestDir: "{app}\scripts"; Flags: ignoreversion

[Icons]
; Accesos directos en el menú inicio
Name: "{group}\ZKTeco Sync"; Filename: "{app}\ZKTeco-Sync.exe"; WorkingDir: "{app}"; Comment: "Aplicación principal ZKTeco Sync"
Name: "{group}\Iniciar Servicio ZKTeco"; Filename: "{app}\scripts\start_service.bat"; WorkingDir: "{app}"; Comment: "Iniciar servicio ZKTeco"
Name: "{group}\Detener Servicio ZKTeco"; Filename: "{app}\scripts\stop_service.bat"; WorkingDir: "{app}"; Comment: "Detener servicio ZKTeco"
Name: "{group}\Desinstalar ZKTeco Sync"; Filename: "{uninstallexe}"; Comment: "Desinstalar ZKTeco Sync"

; Accesos directos en el escritorio (opcional)
Name: "{autodesktop}\ZKTeco Sync"; Filename: "{app}\ZKTeco-Sync.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Crear acceso directo en el &escritorio"; GroupDescription: "Accesos directos adicionales:"
Name: "startupservice"; Description: "Iniciar servicio automáticamente con Windows"; GroupDescription: "Opciones de servicio:"

[Run]
; NO ejecutar scripts que requieren interacción durante la instalación
; En su lugar, usar scripts silenciosos

; Opción para ejecutar la aplicación al finalizar la instalación
Filename: "{app}\ZKTeco-Sync.exe"; Description: "Abrir ZKTeco Sync"; Flags: nowait postinstall skipifsilent; Check: IsServiceRunning

[UninstallRun]
; Detener servicio usando script silencioso
Filename: "{app}\scripts\stop_service.bat"; WorkingDir: "{app}"; Flags: runhidden waituntilterminated
; Eliminar del registro de inicio automático
Filename: "reg"; Parameters: "delete ""HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"" /v ""ZKTecoService"" /f"; Flags: runhidden

[UninstallDelete]
Type: filesandordirs; Name: "{app}\logs"

[Code]
// Función para verificar si el servicio ya está ejecutándose
function IsServiceRunning(): Boolean;
var
  ResultCode: Integer;
begin
  Result := False;
  if Exec('tasklist', '/FI "IMAGENAME eq zkteco_service.exe"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    Result := (ResultCode = 0);
  end;
end;

// Función para iniciar servicio silenciosamente
function StartService(): Boolean;
var
  ResultCode: Integer;
  ScriptPath: String;
begin
  Result := False;
  ScriptPath := ExpandConstant('{app}\scripts\start_service.bat');
  
  // Modificación aquí: pasar el parámetro "SILENT"
  if Exec(ScriptPath, 'SILENT', ExpandConstant('{app}\scripts'), SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    Result := (ResultCode = 0);
  end;
end;
// Función para detener servicio silenciosamente
function StopService(): Boolean;
var
  ResultCode: Integer;
  ScriptPath: String;
begin
  Result := False;
  ScriptPath := ExpandConstant('{app}\scripts\stop_service.bat'); // Corregido: eliminado el "_" extra
  
  if FileExists(ScriptPath) then
  begin
    if Exec(ScriptPath, '', ExpandConstant('{app}'), SW_HIDE, ewWaitUntilTerminated, ResultCode) then
    begin
      Result := True; // Consideramos éxito independientemente del código de salida
    end;
  end;
end;

// Función que se ejecuta antes de la instalación
function InitializeSetup(): Boolean;
var
  ResultCode: Integer; // ← AGREGADO: Declaración de variable faltante
begin
  Result := True;
  
  // Verificar si hay una instalación previa ejecutándose
  if IsServiceRunning() then
  begin
    if MsgBox('El servicio ZKTeco está actualmente ejecutándose. ¿Desea detenerlo para continuar con la instalación?', 
              mbConfirmation, MB_YESNO) = IDYES then
    begin
      // Intentar detener el servicio forzadamente
      Exec('taskkill', '/F /IM "zkteco_service.exe"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
      Sleep(2000); // Esperar 2 segundos
    end
    else
    begin
      Result := False;
    end;
  end;
end;

// Función que se ejecuta al inicio de la desinstalación
function InitializeUninstall(): Boolean;
begin
  Result := True;
  
  // Detener servicio silenciosamente
  if IsServiceRunning() then
  begin
    StopService();
  end;
end;

// Configurar el progreso y ejecutar acciones post-instalación
procedure CurStepChanged(CurStep: TSetupStep);
var
  ServiceStarted: Boolean;
  ResultCode: Integer;
begin
  if CurStep = ssPostInstall then
  begin
    // Crear directorio de logs
    CreateDir(ExpandConstant('{app}\logs'));
    
    // Configurar inicio automático si se seleccionó
    if IsTaskSelected('startupservice') then
    begin
      RegWriteStringValue(HKLM, 
        'SOFTWARE\Microsoft\Windows\CurrentVersion\Run', 
        'ZKTecoService', 
        ExpandConstant('"{app}\zkteco_service.exe" start'));
    end;
    
    // Iniciar servicio silenciosamente
    ServiceStarted := StartService();
    
    // Esperar un momento para que el servicio se inicie completamente
    if ServiceStarted then
    begin
      Sleep(3000); // Esperar 3 segundos
      
      // Verificar nuevamente si está ejecutándose
      if IsServiceRunning() then
      begin
        // El servicio se inició correctamente
        // No mostrar mensaje aquí, se mostrará en CurPageChanged
      end;
    end;
  end;
end;

// Personalizar la página de finalización
procedure CurPageChanged(CurPage: Integer);
begin
  if CurPage = wpFinished then
  begin
    // Verificar estado del servicio y mostrar información
    if IsServiceRunning() then
    begin
      MsgBox('Instalación completada exitosamente.' + #13#10 + #13#10 +
             '✓ El servicio ZKTeco se ha iniciado correctamente' + #13#10 +
             '✓ Puerto del servicio: 3322' + #13#10 +
             '✓ URL de estado: http://127.0.0.1:3322/estado' + #13#10 + #13#10 +
             'Puede administrar el servicio desde el menú de inicio.' + #13#10 +
             'La aplicación principal se puede ejecutar independientemente.', 
             mbInformation, MB_OK);
    end
    else
    begin
      MsgBox('Instalación completada.' + #13#10 + #13#10 +
             '⚠ El servicio no se pudo iniciar automáticamente' + #13#10 +
             'Puede iniciarlo manualmente desde el menú de inicio.' + #13#10 + #13#10 +
             'Puerto configurado: 3322' + #13#10 +
             'Consulte los logs en: ' + ExpandConstant('{app}\logs'), 
             mbInformation, MB_OK);
    end;
  end;
end;