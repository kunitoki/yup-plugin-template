; ============================================================================
;  Inno Setup script for the YUP plugin template (Windows installer).
;
;  Build with Inno Setup's command line compiler (ISCC), passing the values
;  that normally come from CMake as /D defines, for example:
;
;    iscc packaging\windows\installer.iss ^
;         /DMyAppVersion=1.0.0 ^
;         /DBuildDir=..\..\build ^
;         /DConfig=Release
;
;  The helper script packaging\windows\build_installer.ps1 fills these in for
;  you from the VERSION file and CMake configuration.
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
#ifndef BuildDir
  #define BuildDir "..\..\build"
#endif
#ifndef Config
  #define Config "Release"
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
Name: "vst3";       Description: "VST3 plugin";          Types: full custom
Name: "clap";       Description: "CLAP plugin";          Types: full custom
Name: "lv2";        Description: "LV2 plugin";           Types: full custom
Name: "standalone"; Description: "Standalone application"; Types: full custom

[Files]
; VST3 lives in a format-specific subdirectory of the build tree.
Source: "{#BuildDir}\VST3\{#Config}\{#MyAppProject}_vst3_plugin.vst3\*"; \
    DestDir: "{commoncf64}\VST3\{#MyAppProject}_vst3_plugin.vst3"; \
    Flags: recursesubdirs createallsubdirs skipifsourcedoesntexist ignoreversion; Components: vst3

Source: "{#BuildDir}\{#Config}\{#MyAppProject}_clap_plugin.clap"; \
    DestDir: "{commoncf64}\CLAP"; \
    Flags: skipifsourcedoesntexist ignoreversion; Components: clap

Source: "{#BuildDir}\{#Config}\{#MyAppProject}_lv2_plugin.lv2\*"; \
    DestDir: "{commoncf64}\LV2\{#MyAppProject}_lv2_plugin.lv2"; \
    Flags: recursesubdirs createallsubdirs skipifsourcedoesntexist ignoreversion; Components: lv2

Source: "{#BuildDir}\{#Config}\{#MyAppProject}_standalone_plugin.exe"; \
    DestDir: "{app}"; DestName: "{#MyAppName}.exe"; \
    Flags: skipifsourcedoesntexist ignoreversion; Components: standalone

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppName}.exe"; Components: standalone
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"

[Run]
Filename: "{app}\{#MyAppName}.exe"; Description: "Launch {#MyAppName}"; \
    Flags: nowait postinstall skipifsilent; Components: standalone
