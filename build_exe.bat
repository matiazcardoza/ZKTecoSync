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
; Opción para instalar servicio al final (con privilegios heredados)
Filename: "{app}\install_service.bat"; Description: "Instalar servicio ZKTeco Sync"; Flags: postinstall skipifsilent runascurrentuser; Tasks: installservice
; Opción para ejecutar la aplicación
Filename: "{app}\ZKTeco-Sync.exe"; Description: "Ejecutar ZKTeco Sync"; Flags: nowait postinstall skipifsilent unchecked

[UninstallDelete]
Type: filesandordirs; Name: "{app}\logs"
Type: filesandordirs; Name: "{app}\config"

[Code]
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    // Solo crear carpetas necesarias
    CreateDir(ExpandConstant('{app}\logs'));
    CreateDir(ExpandConstant('{app}\config'));
    
    // Mostrar mensaje informativo sobre el servicio
    if IsTaskSelected('installservice') then
    begin
      MsgBox('La instalación se completó correctamente.' + #13#10 + #13#10 +
             'IMPORTANTE: Para instalar el servicio, seleccione "Instalar servicio ZKTeco Sync" ' +
             'en la siguiente pantalla.' + #13#10 + #13#10 +
             'El servicio proporcionará una API REST en: http://127.0.0.1:3322',
             mbInformation, MB_OK);
    end;
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  ResultCode: Integer;
begin
  if CurUninstallStep = usUninstall then
  begin
    // Intentar detener y eliminar servicio antes de desinstalar
    if MsgBox('¿Desea eliminar también el servicio ZKTeco Sync?' + #13#10 + 
              '(Recomendado para una desinstalación completa)', 
              mbConfirmation, MB_YESNO) = IDYES then
    begin
      // Detener servicio
      Exec(ExpandConstant('{cmd}'), '/c net stop ZKTecoSync', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
      Sleep(2000);
      
      // Intentar eliminar usando el ejecutable
      if FileExists(ExpandConstant('{app}\zkteco_service.exe')) then
      begin
        Exec(ExpandConstant('{app}\zkteco_service.exe'), 'remove', 
             ExpandConstant('{app}'), SW_HIDE, ewWaitUntilTerminated, ResultCode);
      end;
      
      // Si falla, intentar eliminación manual
      if ResultCode <> 0 then
        Exec(ExpandConstant('{cmd}'), '/c sc delete ZKTecoSync', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    end;
  end;
end;