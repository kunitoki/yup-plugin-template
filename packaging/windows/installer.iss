; ============================================================================
;  Inno Setup script for the YUP plugin template (Windows installer).
;
;  This script installs the plugin formats and standalone application from a
;  staging directory that packaging\windows\build_installer.ps1 populates from
;  the CMake build tree. The helper script passes the staging path and the
;  Have* defines (one per format that was actually built):
;
;    iscc packaging\windows\installer.iss ^
;         /DMyAppId=28F190D9-1045-4E2D-B7BC-F7D875542C27 ^
;         /DMyAppVersion=1.0.0 ^
;         /DStageDir=C:\path\to\dist\win-stage ^
;         /DHaveVst3=1 /DHaveClap=1 /DHaveLv2=1 /DHaveStandalone=1
;
;  Run it through packaging\windows\build_installer.ps1 rather than by hand.
; ============================================================================

; Unique application id. Generate your own GUID for a real product (e.g. `powershell [guid]::NewGuid()`).
#ifndef MyAppId
  #define MyAppId "28F190D9-1045-4E2D-B7BC-F7D875542C27"
#endif
#ifndef MyAppName
  #define MyAppName "YUP Instrument"
#endif
#ifndef MyAppProject
  #define MyAppProject "YupPlugin"
#endif
#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif
#ifndef MyCompany
  #define MyCompany "YUP Audio"
#endif
#ifndef MyAppURL
  #define MyAppURL "https://github.com/kunitoki/yup-plugin-template"
#endif
#ifndef StageDir
  #define StageDir "..\..\dist\win-stage"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\dist"
#endif
#ifndef IconFile
  #define IconFile "..\..\assets\app-icon.ico"
#endif

[Setup]
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyCompany}
AppPublisherURL={#MyAppURL}
DefaultDirName={autopf}\{#MyCompany}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename={#MyAppProject}-{#MyAppVersion}-windows-x64
Compression=lzma2
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible
SetupIconFile={#IconFile}
WizardStyle=modern

[Types]
Name: "full"; Description: "Full installation"
Name: "custom"; Description: "Custom installation"; Flags: iscustom

[Components]
#ifdef HaveVst3
Name: "vst3";       Description: "VST3 plugin";            Types: full custom
#endif
#ifdef HaveClap
Name: "clap";       Description: "CLAP plugin";            Types: full custom
#endif
#ifdef HaveLv2
Name: "lv2";        Description: "LV2 plugin";             Types: full custom
#endif
#ifdef HaveStandalone
Name: "standalone"; Description: "Standalone application"; Types: full custom
#endif

[Files]
#ifdef HaveVst3
; VST3 is a single "<name>.vst3" DLL (or a bundle folder); install it into the
; shared VST3 directory read by every host.
Source: "{#StageDir}\VST3\*"; DestDir: "{commoncf64}\VST3"; \
    Flags: recursesubdirs createallsubdirs ignoreversion; Components: vst3
#endif
#ifdef HaveClap
Source: "{#StageDir}\CLAP\*"; DestDir: "{commoncf64}\CLAP"; \
    Flags: ignoreversion; Components: clap
#endif
#ifdef HaveLv2
Source: "{#StageDir}\LV2\*"; DestDir: "{commoncf64}\LV2"; \
    Flags: recursesubdirs createallsubdirs ignoreversion; Components: lv2
#endif
#ifdef HaveStandalone
Source: "{#StageDir}\Standalone\*"; DestDir: "{app}"; \
    Flags: ignoreversion; Components: standalone
#endif

[Icons]
#ifdef HaveStandalone
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppName}.exe"; Components: standalone
#endif
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"

[Run]
#ifdef HaveStandalone
Filename: "{app}\{#MyAppName}.exe"; Description: "Launch {#MyAppName}"; \
    Flags: nowait postinstall skipifsilent; Components: standalone
#endif
