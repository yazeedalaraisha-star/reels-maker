; مثبّت ويندوز لصانع الريلز (Inno Setup)
#define AppName "Reels Maker"
#define AppVersion "1.0.0"
#define AppExe "ReelsMaker.exe"

[Setup]
AppId={{6C1B7D2E-9F4A-4E8B-A3C1-5D7E9F2B4A60}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=Yazeed
DefaultDirName={autopf}\ReelsMaker
DefaultGroupName={#AppName}
OutputBaseFilename=ReelsMaker-Setup
Compression=lzma2/max
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequiredOverridesAllowed=dialog
WizardStyle=modern
UninstallDisplayIcon={app}\{#AppExe}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
