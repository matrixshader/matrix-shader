; Matrix Shader Installer
; Created with Inno Setup 6.x

[Setup]
AppName=Matrix Shader
AppVersion=2.0.0
AppPublisher=Matrix Shader Project
DefaultDirName={autopf}\MatrixShader
DefaultGroupName=Matrix Shader
OutputDir=output
OutputBaseFilename=MatrixShaderSetup
Compression=lzma2
SolidCompression=yes
ChangesEnvironment=yes
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "publish\wakeupneo.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "publish\redpill.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "publish\bluepill.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "publish\matrixlite.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "publish\matrix-hotkeys.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "publish\matrix-monitor.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\shaders\*.hlsl"; DestDir: "{app}\shaders"; Flags: ignoreversion recursesubdirs

[Registry]
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; \
    ValueType: expandsz; ValueName: "Path"; ValueData: "{olddata};{app}"; \
    Check: NeedsAddPath(ExpandConstant('{app}'))

[Code]
function NeedsAddPath(Param: string): boolean;
var
  OrigPath: string;
begin
  if not RegQueryStringValue(HKEY_LOCAL_MACHINE,
    'SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
    'Path', OrigPath)
  then begin
    Result := True;
    exit;
  end;
  { Ensure path not already present - case insensitive check }
  Result := Pos(';' + UpperCase(Param) + ';', ';' + UpperCase(OrigPath) + ';') = 0;
end;

[UninstallRegistry]
; PATH cleanup on uninstall handled by Inno Setup default behavior
