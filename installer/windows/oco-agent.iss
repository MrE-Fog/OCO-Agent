; Script generated by the Inno Setup Script Wizard.
; SEE THE DOCUMENTATION FOR DETAILS ON CREATING INNO SETUP SCRIPT FILES!

#define MyAppName "OCO Agent"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Sieber Systems"
#define MyAppURL "https://github.com/schorschii/OCO-Agent"
#define MyAppSupportURL "https://sieber.systems/"
#define MyAppDir "C:\Program Files\OCO Agent"
#define AgentConfigFileName "oco-agent.ini"
#define AgentConfigFilePath MyAppDir+"\"+AgentConfigFileName
#define AgentApiEndpoint "/api-agent.php"

[Setup]
AppId={{7427E511-277A-45DC-B017-805A7F2FAB0F}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
;AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppSupportURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
WizardImageFile="installer-side-img.bmp"
WizardSmallImageFile="installer-top-img.bmp"
UninstallDisplayName={#MyAppName}
UninstallDisplayIcon="{#MyAppDir}\oco-agent.exe,0"
DefaultDirName={#MyAppDir}
DisableDirPage=yes
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
DisableWelcomePage=no
; Uncomment the following line to run in non administrative install mode (install for current user only.)
;PrivilegesRequired=lowest
OutputDir=".\"
OutputBaseFilename=oco-agent
CloseApplications=no
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"; LicenseFile: "..\..\LICENSE.txt"
; Name: "german"; MessagesFile: "compiler:Languages\German.isl"

[Files]
Source: "..\..\dist\oco-agent\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs
Source: "..\..\oco-agent.dist.ini"; DestDir: "{app}"; DestName: "oco-agent.ini"; Flags: ignoreversion onlyifdoesntexist
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Dirs]
Name: {app}\service-checks

[UninstallDelete]
Type: files; Name: "{app}\service-wrapper-old.exe"
Type: files; Name: "{app}\oco-agent-old.exe"
Type: filesandordirs; Name: "{app}.old"

[Code]
var
  CustomQueryPage: TInputQueryWizardPage;
  ResultCode: Integer;
  InstallService: bool;
  DoNotStartService: bool;

function FileReplaceString(const FileName, SearchString, ReplaceString: string):boolean;
var
  MyFile : TStrings;
  MyText : string;
begin
  MyFile := TStringList.Create;
  try
    result := true;
    try
      MyFile.LoadFromFile(FileName);
      MyText := MyFile.Text;
      if StringChangeEx(MyText, SearchString, ReplaceString, True) > 0 then
      begin;
        MyFile.Text := MyText;
        MyFile.SaveToFile(FileName);
      end;
    except
      result := false;
    end;
  finally
    MyFile.Free;
  end;
end;

procedure InitializeWizard();
var
  InfFile: string;
  DefaultServerName: string;
  DefaultAgentKey: string;
begin
  { do not register the service again if this is an update }
  InstallService := not FileExists('{#MyAppDir}\oco-agent.exe');

  { ask for configuration values if no config file is present }
  if not FileExists('{#AgentConfigFilePath}') then
  begin
    CustomQueryPage := CreateInputQueryPage(  
      wpLicense,
      'Agent Configuration',
      'Please enter your OCO server details',
      'You can change these values later by directly editing the config file "oco-agent.ini"'
    );
    CustomQueryPage.Add('DNS name (FQDN) of your OCO server: ', False);
    CustomQueryPage.Add('Agent key to authenticate against your OCO server: ', False);

    { load defaults from .ini if given }
    DefaultServerName := ''
    DefaultAgentKey   := ''
    InfFile := ExpandConstant('{param:LOADINF}');
    if InfFile <> '' then
    begin
      DefaultServerName := GetIniString('Setup', 'ServerName', DefaultServerName, InfFile)
      DefaultAgentKey   := GetIniString('Setup', 'AgentKey', DefaultAgentKey, InfFile)
      DoNotStartService := GetIniBool('Setup', 'DoNotStartService', false, InfFile)
    end;
    CustomQueryPage.Values[0] := DefaultServerName
    CustomQueryPage.Values[1] := DefaultAgentKey
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
  begin
    UninstallProgressForm.StatusLabel.Caption := 'Stopping and removing service...'
    Exec(ExpandConstant('{app}\service-wrapper.exe'), 'stop', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    Exec(ExpandConstant('{app}\service-wrapper.exe'), 'remove', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    Sleep(1000); { without this delay, windows screams that files are still in use }
    UninstallProgressForm.StatusLabel.Caption := 'Removing files...'
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ServerName: string;
begin
  { agent update: stop and remove old service }
  //if (CurStep = ssInstall) and FileExists(ExpandConstant('{app}\service-wrapper.exe')) then
  //begin
  //  Exec(ExpandConstant('{app}\service-wrapper.exe'), 'stop', '', SW_SHOW, ewWaitUntilTerminated, ResultCode);
  //  Exec(ExpandConstant('{app}\service-wrapper.exe'), 'remove', '', SW_SHOW, ewWaitUntilTerminated, ResultCode);
  //end;

  { agent update: rename existing/running agent because files of a running program can not be removed (restart needed to use new agent version) }
  if CurStep = ssInstall then
  begin
    { delete previous .old directory }
    if DirExists(ExpandConstant('{app}.old\')) then
    begin
      DelTree(ExpandConstant('{app}.old\'), True, True, True)
    end;
    { rename current program folder to .old }
    if DirExists(ExpandConstant('{app}\')) then
    begin
      RenameFile(ExpandConstant('{app}\'), ExpandConstant('{app}.old\'))
      CreateDir(ExpandConstant('{app}\'))
    end;
    { move config file back }
    if FileExists(ExpandConstant('{app}.old\{#AgentConfigFileName}')) then
    begin
      RenameFile(ExpandConstant('{app}.old\{#AgentConfigFileName}'), ExpandConstant('{#AgentConfigFilePath}'))
    end;
    { move service checks back }
    if DirExists(ExpandConstant('{app}.old\service-checks')) then
    begin
      RenameFile(ExpandConstant('{app}.old\service-checks'), ExpandConstant('{app}\service-checks'))
    end;
  end;

  { postinstall: replace placeholders in config file, deny user access }
  if CurStep = ssPostInstall then
  begin
    WizardForm.StatusLabel.Caption := 'Writing agent config file...'
    if not (CustomQueryPage = nil) then
    begin
      if CustomQueryPage.Values[0] <> '' then
      begin
        ServerName := 'https://'+CustomQueryPage.Values[0]+'{#AgentApiEndpoint}'
      end;
      FileReplaceString(ExpandConstant('{#AgentConfigFilePath}'), 'SERVERURL', ServerName);
      FileReplaceString(ExpandConstant('{#AgentConfigFilePath}'), 'AGENTKEY', CustomQueryPage.Values[1]);
    end;

    WizardForm.StatusLabel.Caption := 'Restrict permissions on agent config file...'
    Exec('icacls', '"'+ExpandConstant('{#AgentConfigFilePath}')+'" /inheritance:d', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    Exec('icacls', '"'+ExpandConstant('{#AgentConfigFilePath}')+'" /remove:g *S-1-5-32-545', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

    { install and start services if it is a new installation }
    if InstallService then
    begin
      WizardForm.StatusLabel.Caption := 'Register service...'
      Exec(ExpandConstant('{app}\service-wrapper.exe'), '--startup auto install', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

      { do not start service if corresponding parameter is set in .inf - for usage in $OEM$ Windows setup }
      if not DoNotStartService then
      begin
        WizardForm.StatusLabel.Caption := 'Start service...'
        Exec(ExpandConstant('{app}\service-wrapper.exe'), 'start', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
      end;
    end;
  end;
end;
