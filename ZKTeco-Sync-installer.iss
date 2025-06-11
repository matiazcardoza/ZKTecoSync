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

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "Crear acceso directo en el escritorio"; GroupDescription: "Accesos directos adicionales:"; Flags: unchecked

[Files]
; Archivo principal ejecutable
Source: "dist\ZKTeco-Sync.exe"; DestDir: "{app}"; Flags: ignoreversion

; Documentación
Source: "README.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "requirements.txt"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\ZKTeco Sync"; Filename: "{app}\ZKTeco-Sync.exe"
Name: "{group}\Desinstalar ZKTeco Sync"; Filename: "{uninstallexe}"
Name: "{autodesktop}\ZKTeco Sync"; Filename: "{app}\ZKTeco-Sync.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\ZKTeco-Sync.exe"; Description: "Ejecutar ZKTeco Sync"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}\logs"
Type: filesandordirs; Name: "{app}\config"

[Code]
// Configuración post-instalación
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    // Crear carpetas necesarias
    CreateDir(ExpandConstant('{app}\logs'));
    CreateDir(ExpandConstant('{app}\config'));
  end;
end;