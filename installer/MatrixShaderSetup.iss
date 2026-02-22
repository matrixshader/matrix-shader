; Matrix Shader Installer
; Created with Inno Setup 6.x

[Setup]
AppName=Matrix Shader
AppVersion=1.0.1
AppPublisher=MatrixShader
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
english.WelcomeLabel1=Welcome to Matrix Shader
english.WelcomeLabel2=Real-time GPU-powered Matrix rain effects for Windows Terminal.%n%nThis wizard will install Matrix Shader on your computer.

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

{ Remove a directory from User PATH }
procedure RemoveFromUserPath(DirToRemove: string);
var
  UserPath: string;
  UpperDir: string;
  NewPath: string;
  P: Integer;
begin
  if not RegQueryStringValue(HKEY_CURRENT_USER,
    'Environment', 'Path', UserPath) then
    exit;

  UpperDir := UpperCase(DirToRemove);

  { Check if present (with semicolons) }
  if Pos(UpperDir, UpperCase(UserPath)) = 0 then
    exit;

  { Rebuild PATH without the target directory }
  NewPath := '';
  while Length(UserPath) > 0 do
  begin
    P := Pos(';', UserPath);
    if P = 0 then
    begin
      if UpperCase(Trim(UserPath)) <> UpperDir then
      begin
        if NewPath <> '' then
          NewPath := NewPath + ';';
        NewPath := NewPath + UserPath;
      end;
      UserPath := '';
    end
    else
    begin
      if UpperCase(Trim(Copy(UserPath, 1, P - 1))) <> UpperDir then
      begin
        if NewPath <> '' then
          NewPath := NewPath + ';';
        NewPath := NewPath + Copy(UserPath, 1, P - 1);
      end;
      Delete(UserPath, 1, P);
    end;
  end;

  RegWriteStringValue(HKEY_CURRENT_USER, 'Environment', 'Path', NewPath);
end;

{ Kill running Matrix processes before install }
procedure KillMatrixProcesses;
var
  ResultCode: Integer;
begin
  Exec('taskkill', '/F /IM matrix-hotkeys.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Exec('taskkill', '/F /IM matrix-monitor.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Exec('taskkill', '/F /IM redpill.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Exec('taskkill', '/F /IM bluepill.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Exec('taskkill', '/F /IM wakeupneo.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Exec('taskkill', '/F /IM matrixlite.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Sleep(500); { Brief pause for file handles to release }
end;

{ Remove CLI one-liner install (LocalAppData\Programs\MatrixShader) }
procedure RemoveCliInstall;
var
  CliDir: string;
  ResultCode: Integer;
begin
  CliDir := ExpandConstant('{localappdata}\Programs\MatrixShader');
  if DirExists(CliDir) then
  begin
    DelTree(CliDir, True, True, True);
    RemoveFromUserPath(CliDir);
    Log('Removed CLI install at: ' + CliDir);
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
begin
  if CurStep = ssInstall then
  begin
    { Kill running Matrix processes to release file locks }
    KillMatrixProcesses;
    { Remove CLI one-liner install before installing GUI version }
    RemoveCliInstall;
  end;

  if CurStep = ssDone then
  begin
    { Auto-launch wakeupneo — matching CLI install behavior }
    Exec(ExpandConstant('{app}\wakeupneo.exe'), '', '', SW_SHOW, ewNoWait, ResultCode);
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  AppDir: string;
  LocalDir: string;
  ResultCode: Integer;
begin
  if CurUninstallStep = usUninstall then
  begin
    { Kill running Matrix processes and Windows Terminal BEFORE removing files }
    KillMatrixProcesses;
    Exec('taskkill', '/F /IM WindowsTerminal.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    Sleep(1000); { Wait for cached handles to release }
  end;

  if CurUninstallStep = usPostUninstall then
  begin
    AppDir := ExpandConstant('{app}');
    LocalDir := ExpandConstant('{localappdata}\MatrixShader');

    { Also clean up any CLI one-liner install }
    RemoveCliInstall;

    { Clean up CLI registry entry if present }
    RegDeleteKeyIncludingSubkeys(HKEY_CURRENT_USER, 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\MatrixShader');

    { Check if app directory still exists (means some files couldn't be removed) }
    if DirExists(AppDir) then
    begin
      MsgBox('Some files could not be removed from: ' + AppDir + #13#10 + #13#10 +
             'Close all terminal windows, then delete the folder manually.',
             mbError, MB_OK);
    end;

    { Check if LocalAppData directory still exists }
    if DirExists(LocalDir) then
    begin
      MsgBox('User data could not be removed from: ' + LocalDir + #13#10 + #13#10 +
             'Close all applications, then delete the folder manually.',
             mbInformation, MB_OK);
    end;
  end;
end;

function InitializeSetup(): Boolean;
var
  AppDir: string;
  ExePath: string;
  CliDir: string;
  MsgResult: Integer;
  UninstallKey: string;
  UninstallString: string;
  ResultCode: Integer;
begin
  Result := True;

  { Check for CLI one-liner install }
  CliDir := ExpandConstant('{localappdata}\Programs\MatrixShader');
  if DirExists(CliDir) then
  begin
    MsgBox('A CLI install of Matrix Shader was detected at:' + #13#10 +
           CliDir + #13#10 + #13#10 +
           'It will be removed automatically and replaced with the GUI version.',
           mbInformation, MB_OK);
    { Actual removal happens in CurStepChanged(ssInstall) }
  end;

  { Check if GUI version already installed }
  AppDir := ExpandConstant('{autopf}\MatrixShader');
  ExePath := AppDir + '\wakeupneo.exe';

  if FileExists(ExePath) then
  begin
    MsgResult := MsgBox('Matrix Shader is already installed.' + #13#10 + #13#10 +
                        'Choose your path:' + #13#10 + #13#10 +
                        'YES = Update (keep your config)' + #13#10 +
                        'NO = Clean Reinstall (start fresh)' + #13#10 + #13#10 +
                        'Close window to cancel.',
                        mbConfirmation, MB_YESNO);

    case MsgResult of
      IDYES:
        begin
          Result := True;
        end;
      IDNO:
        begin
          UninstallKey := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\Matrix Shader_is1';
          if RegQueryStringValue(HKLM, UninstallKey, 'UninstallString', UninstallString) then
          begin
            if (Length(UninstallString) > 0) and (UninstallString[1] = '"') then
            begin
              Delete(UninstallString, 1, 1);
              if Pos('"', UninstallString) > 0 then
                Delete(UninstallString, Pos('"', UninstallString), Length(UninstallString));
            end;

            MsgBox('The uninstaller will run now. After it completes, run this installer again.',
                   mbInformation, MB_OK);

            Exec(UninstallString, '/SILENT', '', SW_SHOW, ewWaitUntilTerminated, ResultCode);
            Result := False;
          end
          else
          begin
            MsgBox('Could not find uninstaller. Please manually uninstall first.',
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
