[Setup]
AppName=ZKTeco Sync
AppVersion=1.1
AppPublisher=Sistema de Asistencias
DefaultDirName={autopf}\ZKTeco Sync
DefaultGroupName=ZKTeco Sync
AllowNoIcons=yes
LicenseFile=LICENSE.txt
InfoBeforeFile=README.txt
OutputDir=output
OutputBaseFilename=ZKTeco-Sync-Setup-v1.1
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
SetupLogging=yes

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "Crear acceso directo en el escritorio"; GroupDescription: "Accesos directos adicionales:"; Flags: unchecked
Name: "installservice"; Description: "Instalar servicio de Windows (recomendado)"; GroupDescription: "Servicios:"; Flags: checkedonce

[Files]
; Archivo principal ejecutable (GUI)
Source: "dist\ZKTeco-Sync.exe"; DestDir: "{app}"; Flags: ignoreversion
; Servicio de Windows
Source: "dist\zkteco_service.exe"; DestDir: "{app}"; Flags: ignoreversion
; Scripts de instalación/desinstalación del servicio
Source: "install_service.bat"; DestDir: "{app}"; DestName: "install_service.bat"; Flags: ignoreversion
Source: "uninstall_service.bat"; DestDir: "{app}"; DestName: "uninstall_service.bat"; Flags: ignoreversion
; Documentación
Source: "README.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "requirements.txt"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\ZKTeco Sync"; Filename: "{app}\ZKTeco-Sync.exe"
Name: "{group}\Instalar Servicio"; Filename: "{app}\install_service.bat"; IconFilename: "{sys}\shell32.dll"; IconIndex: 21
Name: "{group}\Desinstalar Servicio"; Filename: "{app}\uninstall_service.bat"; IconFilename: "{sys}\shell32.dll"; IconIndex: 131
Name: "{group}\Verificar Estado"; Filename: "http://127.0.0.1:3322/estado"; IconFilename: "{sys}\shell32.dll"; IconIndex: 14
Name: "{group}\Desinstalar ZKTeco Sync"; Filename: "{uninstallexe}"
Name: "{autodesktop}\ZKTeco Sync"; Filename: "{app}\ZKTeco-Sync.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\ZKTeco-Sync.exe"; Description: "Ejecutar ZKTeco Sync"; Flags: nowait postinstall skipifsilent unchecked

[UninstallDelete]
Type: filesandordirs; Name: "{app}\logs"
Type: filesandordirs; Name: "{app}\config"

[Code]
// Función para logging simple (sin timestamp para evitar errores)
procedure LogMessage(Msg: String);
var
  LogFile: String;
  LogContent: TStringList;
begin
  try
    LogFile := ExpandConstant('{app}\logs\installer.log');
    CreateDir(ExtractFileDir(LogFile));
    
    LogContent := TStringList.Create;
    try
      if FileExists(LogFile) then
        LogContent.LoadFromFile(LogFile);
      
      LogContent.Add(Msg);
      LogContent.SaveToFile(LogFile);
    finally
      LogContent.Free;
    end;
  except
    // Ignorar errores de logging
  end;
end;

// Crear configuración por defecto
procedure CreateDefaultConfig();
var
  ConfigDir, ConfigFile: String;
  ConfigContent: TStringList;
begin
  try
    ConfigDir := ExpandConstant('{app}\config');
    ConfigFile := ConfigDir + '\device.json';
    
    CreateDir(ConfigDir);
    
    if not FileExists(ConfigFile) then
    begin
      ConfigContent := TStringList.Create;
      try
        ConfigContent.Add('{');
        ConfigContent.Add('  "id": "1",');
        ConfigContent.Add('  "name": "Dispositivo ZKTeco",');
        ConfigContent.Add('  "ip_address": "192.168.1.100",');
        ConfigContent.Add('  "port": 4370');
        ConfigContent.Add('}');
        
        ConfigContent.SaveToFile(ConfigFile);
        LogMessage('Configuración por defecto creada');
      finally
        ConfigContent.Free;
      end;
    end;
  except
    LogMessage('Error creando configuración: ' + GetExceptionMessage);
  end;
end;

// Función simplificada para instalar el servicio
function InstallService(): Boolean;
var
  ResultCode: Integer;
  ServiceExe: String;
begin
  Result := False;
  ServiceExe := ExpandConstant('{app}\zkteco_service.exe');
  
  LogMessage('Iniciando instalación del servicio...');
  
  // Verificar que el ejecutable existe
  if not FileExists(ServiceExe) then
  begin
    LogMessage('ERROR: No se encuentra el ejecutable del servicio');
    Exit;
  end;
  
  // Crear directorios necesarios
  CreateDir(ExpandConstant('{app}\logs'));
  CreateDir(ExpandConstant('{app}\config'));
  CreateDefaultConfig();
  
  // Detener servicio existente si está corriendo
  LogMessage('Deteniendo servicio existente...');
  Exec(ExpandConstant('{cmd}'), '/c net stop ZKTecoSync', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Sleep(2000);
  
  // Remover servicio existente
  LogMessage('Removiendo servicio existente...');
  Exec(ServiceExe, 'remove', ExpandConstant('{app}'), SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Sleep(2000);
  
  // Instalar servicio usando Python
  LogMessage('Instalando servicio...');
  if Exec(ServiceExe, 'install', ExpandConstant('{app}'), SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    if ResultCode = 0 then
    begin
      LogMessage('Servicio instalado correctamente');
      Sleep(2000);
      
      // Configurar inicio automático
      Exec(ExpandConstant('{cmd}'), '/c sc config ZKTecoSync start= auto', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
      LogMessage('Configuración de inicio automático: ' + IntToStr(ResultCode));
      
      // Iniciar servicio usando Python
      LogMessage('Iniciando servicio...');
      if Exec(ServiceExe, 'start', ExpandConstant('{app}'), SW_HIDE, ewWaitUntilTerminated, ResultCode) then
      begin
        if ResultCode = 0 then
        begin
          LogMessage('Servicio iniciado correctamente');
          Result := True;
        end else
        begin
          LogMessage('Error iniciando servicio, código: ' + IntToStr(ResultCode));
        end;
      end else
      begin
        LogMessage('Error ejecutando comando de inicio');
      end;
    end else
    begin
      LogMessage('Error instalando servicio, código: ' + IntToStr(ResultCode));
    end;
  end else
  begin
    LogMessage('Error ejecutando comando de instalación');
  end;
end;

// Verificar si el servicio está corriendo
function IsServiceRunning(): Boolean;
var
  ResultCode: Integer;
  Attempts: Integer;
begin
  Result := False;
  Attempts := 0;
  
  while (Attempts < 10) and (not Result) do
  begin
    // Verificar puerto 3322
    if Exec(ExpandConstant('{cmd}'), 
           '/c netstat -ano | findstr ":3322.*LISTENING"', 
           '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
    begin
      if ResultCode = 0 then
      begin
        Result := True;
        LogMessage('Servicio verificado - puerto 3322 activo');
        Break;
      end;
    end;
    
    Sleep(3000);
    Attempts := Attempts + 1;
  end;
  
  if not Result then
    LogMessage('Servicio no responde en puerto 3322 después de 30 segundos');
end;

// Evento principal de instalación
procedure CurStepChanged(CurStep: TSetupStep);
var
  InstallSuccess: Boolean;
  StatusMsg: String;
begin
  if CurStep = ssPostInstall then
  begin
    if IsTaskSelected('installservice') then
    begin
      LogMessage('=== INICIO INSTALACIÓN SERVICIO ===');
      
      InstallSuccess := InstallService();
      
      if InstallSuccess then
      begin
        LogMessage('Verificando estado del servicio...');
        // Dar tiempo adicional para que el servicio se inicie
        Sleep(5000);
        
        if IsServiceRunning() then
        begin
          StatusMsg := 'Instalación completada exitosamente!' + #13#10 + #13#10 +
                      '✓ Servicio ZKTeco Sync instalado' + #13#10 +
                      '✓ Servicio iniciado correctamente' + #13#10 +
                      '✓ API REST disponible en: http://127.0.0.1:3322' + #13#10 + #13#10 +
                      'Verificar estado: http://127.0.0.1:3322/estado' + #13#10 + #13#10 +
                      'Configurar dispositivo en:' + #13#10 +
                      ExpandConstant('{app}\config\device.json');
          LogMessage('INSTALACIÓN EXITOSA - Servicio funcionando');
        end else
        begin
          StatusMsg := 'Servicio instalado pero no responde.' + #13#10 + #13#10 +
                      'El servicio puede tardar unos minutos en iniciarse.' + #13#10 +
                      'Verifique en: http://127.0.0.1:3322/estado' + #13#10 + #13#10 +
                      'Si no funciona, use "Instalar Servicio" del menú inicio.';
          LogMessage('INSTALACIÓN PARCIAL - Servicio no responde');
        end;
      end else
      begin
        StatusMsg := 'No se pudo instalar el servicio automáticamente.' + #13#10 + #13#10 +
                    'Instalación manual:' + #13#10 +
                    '1. Abrir "Instalar Servicio" del menú inicio' + #13#10 +
                    '2. Ejecutar como Administrador' + #13#10 + #13#10 +
                    'Log de errores: ' + ExpandConstant('{app}\logs\installer.log');
        LogMessage('INSTALACIÓN FALLIDA');
      end;
      
      MsgBox(StatusMsg, mbInformation, MB_OK);
      LogMessage('=== FIN INSTALACIÓN ===');
    end;
  end;
end;

// Desinstalación
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  ResultCode: Integer;
  ServiceExe: String;
begin
  if CurUninstallStep = usUninstall then
  begin
    if MsgBox('¿Desea eliminar también el servicio ZKTeco Sync?', 
              mbConfirmation, MB_YESNO) = IDYES then
    begin
      ServiceExe := ExpandConstant('{app}\zkteco_service.exe');
      
      // Usar el ejecutable Python para detener y remover
      if FileExists(ServiceExe) then
      begin
        Exec(ServiceExe, 'stop', ExpandConstant('{app}'), SW_HIDE, ewWaitUntilTerminated, ResultCode);
        Sleep(3000);
        Exec(ServiceExe, 'remove', ExpandConstant('{app}'), SW_HIDE, ewWaitUntilTerminated, ResultCode);
      end else
      begin
        // Método manual como respaldo
        Exec(ExpandConstant('{cmd}'), '/c net stop ZKTecoSync', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
        Sleep(2000);
        Exec(ExpandConstant('{cmd}'), '/c sc delete ZKTecoSync', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
      end;
    end;
  end;
end;