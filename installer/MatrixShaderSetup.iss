; Matrix Shader Installer
; Created with Inno Setup 6.x

[Setup]
AppName=Matrix Shader
AppVersion=1.0.0
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

; Matrix theming
WizardStyle=modern
WizardSizePercent=100
WizardResizable=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[CustomMessages]
english.WelcomeLabel1=Welcome to the Matrix
english.WelcomeLabel2=You take the Red Pill - you stay in Wonderland, and I show you how deep the rabbit hole goes.%n%nThis wizard will install Matrix Shader on your computer.

[Files]
; All runtime files (DLLs, .NET runtime, etc.) go to app directory
Source: "publish\*"; DestDir: "{app}"; Excludes: "shaders"; Flags: ignoreversion recursesubdirs createallsubdirs
; Shaders go directly to LocalAppData (where code looks for them)
Source: "publish\shaders\*.hlsl"; DestDir: "{localappdata}\MatrixShader\shaders"; Flags: ignoreversion

[Run]
; No xcopy needed - shaders installed directly to LocalAppData above

[Registry]
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; \
    ValueType: expandsz; ValueName: "Path"; ValueData: "{olddata};{app}"; \
    Check: NeedsAddPath(ExpandConstant('{app}'))

[Code]
procedure InitializeWizard;
begin
  { Set dark background }
  WizardForm.Color := $000000;  { Black }
  WizardForm.MainPanel.Color := $001100;  { Dark green tint }
  WizardForm.InnerPage.Color := $000000;

  { Green text for labels where possible }
  WizardForm.WelcomeLabel1.Font.Color := $00FF00;  { Bright green }
  WizardForm.WelcomeLabel2.Font.Color := $00AA00;  { Dimmer green }
  WizardForm.PageDescriptionLabel.Font.Color := $00AA00;
  WizardForm.PageNameLabel.Font.Color := $00FF00;
end;

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
    MsgBox('Welcome to the Matrix.' + #13#10 + #13#10 +
           'Open a NEW terminal window and type:' + #13#10 +
           '  wakeupneo' + #13#10 + #13#10 +
           'Other commands:' + #13#10 +
           '  bluepill  - Quick launch your Matrix session' + #13#10 +
           '  redpill   - Full control panel' + #13#10 +
           '  matrixlite - Text fallback mode', mbInformation, MB_OK);
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  AppDir: string;
  LocalDir: string;
begin
  if CurUninstallStep = usPostUninstall then
  begin
    AppDir := ExpandConstant('{app}');
    LocalDir := ExpandConstant('{localappdata}\MatrixShader');

    { Check if app directory still exists (means some files couldn't be removed) }
    if DirExists(AppDir) then
    begin
      MsgBox('WHAT: Some files could not be removed from the installation directory.' + #13#10 + #13#10 +
             'WHERE: ' + AppDir + #13#10 + #13#10 +
             'WHY: Files may be in use by another process, or you may not have delete permissions.' + #13#10 + #13#10 +
             'HOW TO FIX:' + #13#10 +
             '1. Close all terminal windows (Windows Terminal, PowerShell, cmd)' + #13#10 +
             '2. Open File Explorer and navigate to: ' + AppDir + #13#10 +
             '3. Delete the MatrixShader folder manually' + #13#10 +
             '4. If files are still locked, restart your computer and try again',
             mbError, MB_OK);
    end;

    { Check if LocalAppData directory still exists }
    if DirExists(LocalDir) then
    begin
      MsgBox('WHAT: Some user data files could not be removed.' + #13#10 + #13#10 +
             'WHERE: ' + LocalDir + #13#10 + #13#10 +
             'WHY: Files may be in use, or were created after installation.' + #13#10 + #13#10 +
             'HOW TO FIX:' + #13#10 +
             '1. Close all applications' + #13#10 +
             '2. Open File Explorer and navigate to: ' + LocalDir + #13#10 +
             '3. Delete the MatrixShader folder manually',
             mbInformation, MB_OK);
    end;
  end;
end;

function InitializeSetup(): Boolean;
var
  AppDir: string;
  ExePath: string;
  MsgResult: Integer;
  UninstallKey: string;
  UninstallString: string;
  ResultCode: Integer;
begin
  Result := True;

  { Check if already installed by looking for main executable }
  AppDir := ExpandConstant('{autopf}\MatrixShader');
  ExePath := AppDir + '\wakeupneo.exe';

  if FileExists(ExePath) then
  begin
    { Existing installation detected - show Matrix-themed options }
    MsgResult := MsgBox('Matrix Shader is already installed.' + #13#10 + #13#10 +
                        'Choose your path:' + #13#10 + #13#10 +
                        'YES = Update (Blue Pill - keep your config, recommended)' + #13#10 +
                        'NO = Clean Reinstall (Red Pill - start fresh)' + #13#10 + #13#10 +
                        'Close window to cancel.',
                        mbConfirmation, MB_YESNO);

    case MsgResult of
      IDYES:
        begin
          { Blue Pill: Continue with update/repair - installer will overwrite files }
          Result := True;
        end;
      IDNO:
        begin
          { Red Pill: Run uninstaller first for clean install }
          UninstallKey := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\Matrix Shader_is1';
          if RegQueryStringValue(HKLM, UninstallKey, 'UninstallString', UninstallString) then
          begin
            { Remove quotes if present }
            if (Length(UninstallString) > 0) and (UninstallString[1] = '"') then
            begin
              Delete(UninstallString, 1, 1);
              if Pos('"', UninstallString) > 0 then
                Delete(UninstallString, Pos('"', UninstallString), Length(UninstallString));
            end;

            MsgBox('The uninstaller will run now. After it completes, run this installer again.',
                   mbInformation, MB_OK);

            { Run uninstaller with /SILENT for automated uninstall }
            Exec(UninstallString, '/SILENT', '', SW_SHOW, ewWaitUntilTerminated, ResultCode);

            { Exit this installer - user should run again after uninstall }
            Result := False;
          end
          else
          begin
            MsgBox('Could not find uninstaller. Please manually uninstall Matrix Shader first, then run this installer again.',
                   mbError, MB_OK);
            Result := False;
          end;
        end;
    end;
  end;
end;

[UninstallRegistry]
; PATH cleanup on uninstall handled by Inno Setup default behavior

[UninstallDelete]
; Clean up LocalAppData files created during installation and runtime
Type: filesandordirs; Name: "{localappdata}\MatrixShader"
; Clean up the entire application directory (all DLLs, executables, etc.)
Type: filesandordirs; Name: "{app}"
