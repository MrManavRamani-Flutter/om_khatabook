; Script generated for OM Mavtar Group Khata Book
; Inno Setup 6.x Installer Script for Windows 10/11 Desktop

#define MyAppName "OM Mavtar Group Khata Book"
#define MyAppVersion "2.0.0"
#define MyAppPublisher "OM Mavtar Group"
#define MyAppExeName "om_khatabook.exe"

[Setup]
; App unique identifier (DO NOT CHANGE to ensure clean upgrades and uninstalls)
AppId={{8B2F3E74-63D9-4E61-A7C1-02F5299D2D44}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} v{#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\OM Mavtar Group Khata Book
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
OutputDir=..\..\build\installer
OutputBaseFilename=OmMavtarKhataBook_Setup
SetupIconFile=..\runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Flutter Windows Release build artifacts
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Fallback in case Flutter output is not under x64 folder
; Source: "..\..\build\windows\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

