unit Dext.Hosting.CLI.Config;

interface

uses
  System.Classes,
  System.Generics.Collections,
  System.IOUtils,
  System.JSON,
  System.SysUtils,
  {$IFDEF MSWINDOWS}
  System.Win.Registry,
  Winapi.Windows,
  {$ENDIF}
  Dext.Yaml,
  Dext.Collections,
  Dext.Configuration.Yaml;

type
  TDextTestConfig = record
    Project: string;
    ReportDir: string;
    CoverageExclude: TArray<string>;
    CoverageThreshold: Double;
  end;

  TDextEnvironment = record
    Version: string;
    Name: string;
    Path: string;
    IsDefault: Boolean;
    Platforms: TArray<string>;
  end;

  TDextConfig = class
  private
    FTest: TDextTestConfig;
    function LoadTestConfig(Json: TJSONObject): TDextTestConfig;
  public
    constructor Create;
    procedure LoadFromFile(const FileName: string);
    property Test: TDextTestConfig read FTest;
  end;

  TDextGlobalConfig = class
  private
    FEnvironments: IList<TDextEnvironment>;
    FDextPath: string;
    FCoveragePath: string;
    FStartMinimized: Boolean;
    procedure LoadEnvironments(Doc: TYamlDocument);
    function FindNode(Parent: TYamlNode; const Key: string): TYamlNode;
    function GetScalarValue(Node: TYamlNode; const Def: string = ''): string;
    function CleanYamlValue(const S: string): string;
    // Scan Helpers
{$IFDEF MSWINDOWS}
    class function GetDelphiName(const RegVersion: string): string;
    class function GetCompilerPath(const BinDir, Platform: string): string;
{$ENDIF}
 public
    constructor Create;
    destructor Destroy; override;
    
    procedure Load;
    procedure Save; // Added
    function GetDelphiRoot(const VersionOrName: string = ''): string;
    
    // Returns log output
    function ScanEnvironments: string; 
    
    property DextPath: string read FDextPath write FDextPath; // Added write
    property CoveragePath: string read FCoveragePath write FCoveragePath; // Added write
    property StartMinimized: Boolean read FStartMinimized write FStartMinimized;
    property Environments: IList<TDextEnvironment> read FEnvironments;
  end;

implementation

{ TDextConfig }

constructor TDextConfig.Create;
begin
  // Defaults
  FTest.Project := '';
  FTest.ReportDir := 'TestOutput\report'; 
  FTest.CoverageExclude := [];
  FTest.CoverageThreshold := 0;
end;

procedure TDextConfig.LoadFromFile(const FileName: string);
var
  Content: string;
  VerifyJson, Section: TJSONValue;
  MainObj: TJSONObject;
begin
  if not FileExists(FileName) then Exit;
  
  Content := TFile.ReadAllText(FileName);
  VerifyJson := TJSONObject.ParseJSONValue(Content);
  if VerifyJson = nil then Exit;
  
  try
    if VerifyJson is TJSONObject then
    begin
      MainObj := VerifyJson as TJSONObject;
      if MainObj.TryGetValue('test', Section) and (Section is TJSONObject) then
        FTest := LoadTestConfig(Section as TJSONObject);
    end;
  finally
    VerifyJson.Free;
  end;
end;

function TDextConfig.LoadTestConfig(Json: TJSONObject): TDextTestConfig;
var
  Val: TJSONValue;
  Arr: TJSONArray;
  I: Integer;
  CovObj: TJSONObject;
begin
  Result := FTest; // Start with current/defaults
  
  if Json.TryGetValue('project', Val) then
    Result.Project := Val.Value;
    
  if Json.TryGetValue('report_dir', Val) then
    Result.ReportDir := Val.Value;

  if Json.TryGetValue('coverage', Val) and (Val is TJSONObject) then
  begin
    CovObj := Val as TJSONObject;
    if CovObj.TryGetValue('exclude', Arr) then
    begin
      SetLength(Result.CoverageExclude, Arr.Count);
      for I := 0 to Arr.Count - 1 do
        Result.CoverageExclude[I] := Arr.Items[I].Value;
    end;
    
    if CovObj.TryGetValue('threshold', Val) and (Val is TJSONNumber) then
       Result.CoverageThreshold := (Val as TJSONNumber).AsDouble;
  end;
end;

{ TDextGlobalConfig }

constructor TDextGlobalConfig.Create;
begin
  FEnvironments := TCollections.CreateList<TDextEnvironment>;
end;

destructor TDextGlobalConfig.Destroy;
begin
  inherited;
end;

procedure TDextGlobalConfig.Load;
var
  UserDir, ConfigFile: string;
  Doc: TYamlDocument;
  Parser: TYamlParser;
  Content: string;
begin
  UserDir := TPath.Combine(TPath.GetHomePath, '.dext');
  ConfigFile := TPath.Combine(UserDir, 'config.yaml');
  
  if not FileExists(ConfigFile) then Exit;
  
  Content := TFile.ReadAllText(ConfigFile);
  Parser := TYamlParser.Create;
  try
    try
      Doc := Parser.Parse(Content);
     
      if Doc <> nil then
      begin
        try
          FDextPath := GetScalarValue(FindNode(Doc.Root, 'dext_path'));
          FCoveragePath := GetScalarValue(FindNode(Doc.Root, 'coverage_path'));
          FStartMinimized := StrToBoolDef(GetScalarValue(FindNode(Doc.Root, 'start_minimized'), 'false'), False);
          
          LoadEnvironments(Doc);
        finally
          Doc.Free;
        end;
      end;
    except
      // Ignore parse errors to prevent crash on bad user config
    end;
  finally
    Parser.Free;
  end;
end;

procedure TDextGlobalConfig.Save;
var
  UserDir, ConfigFile: string;
  SB: TStringBuilder;
  Env: TDextEnvironment;
  P: string;
begin
  UserDir := TPath.Combine(TPath.GetHomePath, '.dext');
  if not TDirectory.Exists(UserDir) then TDirectory.CreateDirectory(UserDir);
  ConfigFile := TPath.Combine(UserDir, 'config.yaml');
  
  SB := TStringBuilder.Create;
  try
    if FDextPath <> '' then
      SB.AppendLine('dext_path: "' + FDextPath.Replace('\', '\\') + '"');
    if FCoveragePath <> '' then
      SB.AppendLine('coverage_path: "' + FCoveragePath.Replace('\', '\\') + '"');
    SB.AppendLine('start_minimized: ' + BoolToStr(FStartMinimized, True).ToLower);
      
    SB.AppendLine('environments:');
    for Env in FEnvironments do
    begin
        SB.AppendLine('  - ');
        SB.AppendLine(Format('    version: "%s"', [Env.Version]));
        SB.AppendLine(Format('    name: "%s"', [Env.Name]));
        SB.AppendLine(Format('    path: "%s"', [Env.Path.Replace('\', '\\')]));
        SB.AppendLine(Format('    default: %s', [BoolToStr(Env.IsDefault, True).ToLower]));
        
        if Length(Env.Platforms) > 0 then
        begin
          SB.AppendLine('    platforms:');
          for P in Env.Platforms do
            SB.AppendLine(Format('      - "%s"', [P]));
        end;
    end;
    
    TFile.WriteAllText(ConfigFile, SB.ToString);
  finally
    SB.Free;
  end;
end;

function TDextGlobalConfig.CleanYamlValue(const S: string): string;
begin
  Result := S.Trim;
  while (Result.Length >= 2) and 
        ((Result.StartsWith('"') and Result.EndsWith('"')) or 
         (Result.StartsWith('''') and Result.EndsWith(''''))) do
  begin
    Result := Result.Substring(1, Result.Length - 2);
  end;
    
  // Unescape backslashes
  Result := Result.Replace('\\', '\');
end;

function TDextGlobalConfig.FindNode(Parent: TYamlNode; const Key: string): TYamlNode;
begin
  Result := nil;
  if (Parent <> nil) and (Parent is TYamlMapping) then
    (Parent as TYamlMapping).TryGet(Key, Result);
end;

function TDextGlobalConfig.GetScalarValue(Node: TYamlNode; const Def: string): string;
begin
  if (Node <> nil) and (Node is TYamlScalar) then
    Result := CleanYamlValue((Node as TYamlScalar).Value)
  else
    Result := Def;
end;

procedure TDextGlobalConfig.LoadEnvironments(Doc: TYamlDocument);
var
  Root, EnvNode: TYamlNode;
  EnvSeq: TYamlSequence;
  I, J: Integer;
  Env: TDextEnvironment;
  SeqNode: TYamlNode;
  PlatformsSeq: TYamlSequence;
  PlatNode: TYamlNode;
  PlatSeqNode: TYamlNode;
begin
  Root := Doc.Root;
  if Root = nil then Exit;
  
  // Environments
  EnvNode := FindNode(Root, 'environments');
  
  if (EnvNode <> nil) and (EnvNode is TYamlSequence) then
  begin
    EnvSeq := EnvNode as TYamlSequence;
    
    for I := 0 to EnvSeq.Items.Count - 1 do
    begin
      SeqNode := EnvSeq.Items[I];
      if SeqNode is TYamlMapping then
      begin
        Env.Version := GetScalarValue(FindNode(SeqNode, 'version'));
        Env.Name := GetScalarValue(FindNode(SeqNode, 'name'));
        Env.Path := GetScalarValue(FindNode(SeqNode, 'path'));
        Env.IsDefault := StrToBoolDef(GetScalarValue(FindNode(SeqNode, 'default'), 'false'), False);
        Env.Platforms := [];

        PlatSeqNode := FindNode(SeqNode, 'platforms');
        if (PlatSeqNode <> nil) and (PlatSeqNode is TYamlSequence) then
        begin
          PlatformsSeq := PlatSeqNode as TYamlSequence;
          SetLength(Env.Platforms, PlatformsSeq.Items.Count);
          for J := 0 to PlatformsSeq.Items.Count - 1 do
          begin
             PlatNode := PlatformsSeq.Items[J];
             if PlatNode is TYamlScalar then
               Env.Platforms[J] := CleanYamlValue((PlatNode as TYamlScalar).Value);
          end;
        end;
        
        FEnvironments.Add(Env);
      end;
    end;
  end;
end;

function TDextGlobalConfig.GetDelphiRoot(const VersionOrName: string): string;
var
  Env: TDextEnvironment;
begin
  Result := '';
  
  if VersionOrName = '' then
  begin
    for Env in FEnvironments do
      if Env.IsDefault then Exit(Env.Path);
    if FEnvironments.Count > 0 then Exit(FEnvironments[0].Path);
    Exit;
  end;
  
  for Env in FEnvironments do
  begin
    if (Env.Version = VersionOrName) or (Env.Name = VersionOrName) then 
       Exit(Env.Path);
    
    if Env.Version.StartsWith(VersionOrName) then Exit(Env.Path);
    if Env.Name.ToLower.Contains(VersionOrName.ToLower) then Exit(Env.Path);
  end;
end;

{$IFDEF MSWINDOWS}
class function TDextGlobalConfig.GetDelphiName(const RegVersion: string): string;
begin
  if RegVersion = '8.0' then Exit('Delphi XE');
  if RegVersion = '9.0' then Exit('Delphi XE2');
  if RegVersion = '10.0' then Exit('Delphi XE3');
  if RegVersion = '11.0' then Exit('Delphi XE4');
  if RegVersion = '12.0' then Exit('Delphi XE5');
  if RegVersion = '14.0' then Exit('Delphi XE6');
  if RegVersion = '15.0' then Exit('Delphi XE7');
  if RegVersion = '16.0' then Exit('Delphi XE8');
  if RegVersion = '17.0' then Exit('Delphi 10 Seattle');
  if RegVersion = '18.0' then Exit('Delphi 10.1 Berlin');
  if RegVersion = '19.0' then Exit('Delphi 10.2 Tokyo');
  if RegVersion = '20.0' then Exit('Delphi 10.3 Rio');
  if RegVersion = '21.0' then Exit('Delphi 10.4 Sydney');
  if RegVersion = '22.0' then Exit('Delphi 11 Alexandria');
  if RegVersion = '23.0' then Exit('Delphi 12 Athens');
  if RegVersion = '24.0' then Exit('Delphi 13'); // Speculative
  if RegVersion = '25.0' then Exit('Delphi 14');
  if RegVersion = '37.0' then Exit('Delphi 13'); // As per user environment
  Result := 'Delphi ' + RegVersion;
end;
{$ENDIF}

{$IFDEF MSWINDOWS}
class function TDextGlobalConfig.GetCompilerPath(const BinDir, Platform: string): string;
var
  ExeName: string;
begin
  ExeName := '';
  if Platform = 'Win32' then ExeName := 'dcc32.exe'
  else if Platform = 'Win64' then ExeName := 'dcc64.exe'
  else if Platform = 'OSX64' then ExeName := 'dccosx64.exe'
  else if Platform = 'OSXARM64' then ExeName := 'dccosxarm64.exe'
  else if Platform = 'Linux64' then ExeName := 'dcclinux64.exe'
  else if Platform = 'Android' then ExeName := 'dccaarm.exe'
  else if Platform = 'Android64' then ExeName := 'dccaarm64.exe'
  else if Platform = 'iOSDevice64' then ExeName := 'dcciosarm64.exe'
  else if Platform = 'iOSSimARM64' then ExeName := 'dcciossimarm64.exe';

  if ExeName <> '' then
    Result := TPath.Combine(BinDir, ExeName)
  else
    Result := '';
end;
{$ENDIF}

function TDextGlobalConfig.ScanEnvironments: string;
{$IFDEF MSWINDOWS}
var
  Reg: TRegistry;
  Versions: TStringList;
  Ver, RootDir, ConfigDir, ConfigFile: string;
  YamlContent, LogContent: TStringBuilder;
  FoundAny: Boolean;
  KnownPlatforms: TArray<string>;
  P: string;
  BinDir: string;
  CompilerPath: string;
  MaxVer: Double;
  CurVerDbl: Double;
  IsDefault: Boolean;
  VerName: string;
  RootKey: HKEY;
  RootKeys: TArray<HKEY>;
  KeyPath: string;
  
  procedure Log(const S: string);
  begin
    LogContent.AppendLine(S);
  end;
begin
  Result := '';
  LogContent := TStringBuilder.Create;
  YamlContent := TStringBuilder.Create;
  Versions := TStringList.Create;
  Reg := TRegistry.Create;
  try
    KnownPlatforms := ['Win32', 'Win64', 'Linux64', 'OSX64', 'OSXARM64', 'Android', 'Android64', 'iOSDevice64', 'iOSSimARM64'];
    
    YamlContent.AppendLine('environments:');
    FoundAny := False;
    
    RootKeys := [HKEY_CURRENT_USER, HKEY_LOCAL_MACHINE];
    KeyPath := 'Software\Embarcadero\BDS';

    for RootKey in RootKeys do
    begin
       Reg.RootKey := RootKey;
       
       if RootKey = HKEY_CURRENT_USER then Log('Checking HKCU\' + KeyPath + '...')
       else Log('Checking HKLM\' + KeyPath + '...');

       if Reg.OpenKeyReadOnly(KeyPath) then
       begin
         Reg.GetKeyNames(Versions);
         Reg.CloseKey;
         
         if Versions.Count = 0 then
         begin
           Log('  No subkeys found.');
           Continue;
         end;

         MaxVer := 0;
         for Ver in Versions do
           if TryStrToFloat(Ver, CurVerDbl, TFormatSettings.Invariant) then
              if CurVerDbl > MaxVer then MaxVer := CurVerDbl;
         
         for Ver in Versions do
         begin
            if not TryStrToFloat(Ver, CurVerDbl, TFormatSettings.Invariant) then Continue;

            if Reg.OpenKeyReadOnly(KeyPath + '\' + Ver) then
            begin
              try
                if Reg.ValueExists('RootDir') then
                begin
                  RootDir := Reg.ReadString('RootDir');
                  Reg.CloseKey; // Closes Ver key
                  
                  // Try to get official name from Personalities
                  VerName := '';
                  if Reg.OpenKeyReadOnly(KeyPath + '\' + Ver + '\Personalities') then
                  begin
                     if Reg.ValueExists('Delphi.Win32') then
                       VerName := Reg.ReadString('Delphi.Win32')
                     else 
                       try
                         VerName := Reg.ReadString(''); // Default value
                       except
                       end;
                     Reg.CloseKey;
                  end;
                  
                  if VerName = '' then
                    VerName := GetDelphiName(Ver);
                  
                  Log(Format('  -> Detected: %s (%s)', [VerName, Ver]));
                  Log(Format('     Path: %s', [RootDir]));
                  IsDefault := (CurVerDbl = MaxVer);
                  if IsDefault then Log('     (Default)');

                  // Adjusted YAML format to work with basic parser: Block style
                  YamlContent.AppendLine('  - ');
                  YamlContent.AppendLine(Format('    version: "%s"', [Ver]));
                  YamlContent.AppendLine(Format('    name: "%s"', [VerName]));
                  YamlContent.AppendLine(Format('    path: "%s"', [RootDir.Replace('\', '\\')])); 
                  YamlContent.AppendLine(Format('    default: %s', [BoolToStr(IsDefault, True).ToLower]));
                  
                  YamlContent.AppendLine('    platforms:');
                  BinDir := TPath.Combine(RootDir, 'bin');
                  for P in KnownPlatforms do
                  begin
                    CompilerPath := GetCompilerPath(BinDir, P);
                    if (CompilerPath <> '') and FileExists(CompilerPath) then
                       YamlContent.AppendLine(Format('      - "%s"', [P]));
                  end;
                  
                  FoundAny := True;
                end;
              finally
                Reg.CloseKey; 
              end;
            end;
          end;
       end
       else
       begin
         Log('Not found or access denied.');
       end;
       
       if FoundAny then Break; 
    end;
    
    if FoundAny then
    begin
       ConfigDir := TPath.Combine(TPath.GetHomePath, '.dext');
       if not TDirectory.Exists(ConfigDir) then
         TDirectory.CreateDirectory(ConfigDir);
         
       ConfigFile := TPath.Combine(ConfigDir, 'config.yaml');
       TFile.WriteAllText(ConfigFile, YamlContent.ToString);
       Log('Environments saved to ' + ConfigFile);
    end
    else
    begin
       Log('No Delphi installations found.');
    end;
    
    Result := LogContent.ToString;
  finally
    Reg.Free;
    Versions.Free;
    YamlContent.Free;
    LogContent.Free;
  end;
end;
{$ELSE}
begin
  Result := 'Environment scanning is only supported on Windows.';
end;
{$ENDIF}

end.

