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

[Run]
; Copy shaders to user's LocalAppData for consistent path resolution
Filename: "cmd.exe"; Parameters: "/c mkdir ""{localappdata}\MatrixShader\shaders"" 2>nul & xcopy ""{app}\shaders\*"" ""{localappdata}\MatrixShader\shaders"" /E /Y /Q"; \
    Flags: runhidden waituntilterminated; StatusMsg: "Setting up shader files..."

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

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssDone then
  begin
    MsgBox('Matrix Shader installed successfully!' + #13#10 + #13#10 +
           'Open a NEW terminal window to use the commands:' + #13#10 +
           '  - wakeupneo (setup wizard)' + #13#10 +
           '  - bluepill (quick launch)' + #13#10 +
           '  - redpill (control panel)' + #13#10 +
           '  - matrixlite (text fallback)', mbInformation, MB_OK);
  end;
end;

[UninstallRegistry]
; PATH cleanup on uninstall handled by Inno Setup default behavior

[UninstallDelete]
; Clean up LocalAppData files created during installation and runtime
Type: filesandordirs; Name: "{localappdata}\MatrixShader"
