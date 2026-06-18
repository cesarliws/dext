unit Dext.Testing.Design.Presenter;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.Threading,
  System.Diagnostics,
  Winapi.Windows,
  Dext.Testing.Design.Server,
  Dext.Testing.Design.AST,
  Dext.Testing.Integration;

type
  TTestDetailInfo = record
    TestName: string;
    Status: string;
    FileName: string;
    Line: Integer;
    DurationMs: Double;
    ErrorMessage: string;
    StackTrace: string;
  end;

  TGroupSummaryInfo = record
    TotalCount: Integer;
    PassedCount: Integer;
    FailedCount: Integer;
    DurationMs: Double;
  end;

  ITestExplorerView = interface
    ['{A8B3C4D1-E2F3-4C5E-BF6A-7B8C9D0E1F2A}']
    procedure ShowProgress(const AMsg: string; AMarquee: Boolean);
    procedure HideProgress;
    procedure UpdateProgressInfo(const ACompleted, ATotal: Integer);
    procedure ClearTestTree;
    procedure RefreshTestTree(const ALocations: TList<TTestLocation>);
    procedure AppendConsoleLine(const ALine: string);
    procedure UpdateSummary(APassed, AFailed, ASkipped, ATotal: Integer; ADuration: Double);
    procedure UpdateTestDetails(const ATestName, AStatus, ALocation, ADurationText, AErrorMsg, AStackTrace: string);
    procedure ForceRepaintNode(const APath: string);
    procedure UpdateTestNode(const APath, AStatus: string; ADuration: Double; const AErrorMsg, AStackTrace: string);
  end;

  TTestExplorerModel = class
  private
    FServer: TTestRunnerServer;
    FTestLocations: TList<TTestLocation>;
    FActiveProjectFile: string;
    FRunningProcessHandle: THandle;
    function GetProjectTargetInfo(const AProjFile: string; out AIsPackage: Boolean; out AOutput: string; const APlatform: string = 'Win32'; const AConfig: string = 'Debug'): Boolean;
    function ResolveExePath(const AProjFile, AOutput: string; const APlatform: string = 'Win32'; const AConfig: string = 'Debug'): string;
    function ExtractTagValue(const AContent, ATagName: string): string;
    function GetDelphiProductVersion: string;
    function ExecuteAndCapture(const ACommandLine, AWorkDir: string; out AOutput: string): Boolean;
    function CompileProjectDirect(const AProjFile: string; AOnConsole: TProc<string>): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure ScanProjectTests(const AProjFile: string; AOnScanFinished: TProc<TList<TTestLocation>>);
    procedure CompileAndRunTests(const AProjFile: string; const ATestFilter: string; ACheckedTests: TArray<string>; AOnStart: TProc; AOnFinished: TProc; AOnConsole: TProc<string>);
    procedure StopTests;
    property ActiveProjectFile: string read FActiveProjectFile write FActiveProjectFile;
    property Server: TTestRunnerServer read FServer;
    property TestLocations: TList<TTestLocation> read FTestLocations;
  end;

  TTestExplorerPresenter = class
  private
    FView: ITestExplorerView;
    FModel: TTestExplorerModel;
    FTestDetails: TDictionary<string, TTestDetailInfo>;
    FGroupSummaries: TDictionary<string, TGroupSummaryInfo>;
    FPassedCount: Integer;
    FFailedCount: Integer;
    FSkippedCount: Integer;
    FTotalTests: Integer;
    FCompletedTests: Integer;
    FDurationMs: Double;
    FStopwatch: TStopwatch;
    procedure OnTestResultReceived(const AJSONData: string);
    procedure ProcessSingleResult(const AJSON: string);
    procedure InitializeGroupSummaries;
    procedure UpdateGroupSummary(const ATestName, AStatus: string; ADurationMs: Double);
  public
    constructor Create(const AView: ITestExplorerView);
    destructor Destroy; override;
    procedure Initialize;
    procedure RunAllClick;
    procedure RunSelectedClick(const AFilter: string; AChecked: TArray<string>);
    procedure StopClick;
    procedure RefreshClick;
    procedure SelectTest(const ATestName: string);
    property Model: TTestExplorerModel read FModel;
    property TestDetails: TDictionary<string, TTestDetailInfo> read FTestDetails;
    property GroupSummaries: TDictionary<string, TGroupSummaryInfo> read FGroupSummaries;
  end;

implementation

uses
  System.JSON,
  System.IOUtils,
  System.Math,
  ToolsAPI;

{ TTestExplorerModel }

constructor TTestExplorerModel.Create;
begin
  inherited Create;
  FTestLocations := TList<TTestLocation>.Create;
  FServer := TTestRunnerServer.Create(8102);
end;

function TTestExplorerModel.GetDelphiProductVersion: string;
var
  BinDir: string;
  Split: TArray<string>;
  i: Integer;
begin
  BinDir := ExtractFilePath(ParamStr(0));
  Split := BinDir.Split(['\']);
  for i := 0 to Length(Split) - 1 do
  begin
    if SameText(Split[i], 'Studio') and (i < Length(Split) - 1) then
      Exit(Split[i + 1]);
  end;
  Result := '23.0';
end;

function TTestExplorerModel.ExecuteAndCapture(const ACommandLine, AWorkDir: string; out AOutput: string): Boolean;
var
  Sa: Winapi.Windows.TSecurityAttributes;
  ReadPipe, WritePipe: THandle;
  Si: Winapi.Windows.TStartUpInfo;
  Pi: Winapi.Windows.TProcessInformation;
  Buffer: array[0..4095] of AnsiChar;
  BytesRead: DWORD;
  Success: Boolean;
  CmdLine: string;
  ExitCode: DWORD;
begin
  Result := False;
  AOutput := '';

  Sa.nLength := SizeOf(TSecurityAttributes);
  Sa.bInheritHandle := True;
  Sa.lpSecurityDescriptor := nil;

  if not CreatePipe(ReadPipe, WritePipe, @Sa, 0) then Exit;

  try
    SetHandleInformation(ReadPipe, HANDLE_FLAG_INHERIT, 0);

    ZeroMemory(@Si, SizeOf(TStartUpInfo));
    Si.cb := SizeOf(TStartUpInfo);
    Si.hStdOutput := WritePipe;
    Si.hStdError := WritePipe;
    Si.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
    Si.wShowWindow := SW_HIDE;

    CmdLine := ACommandLine;
    UniqueString(CmdLine);

    if Winapi.Windows.CreateProcess(nil, PChar(CmdLine), nil, nil, True, CREATE_NO_WINDOW, nil,
      PChar(AWorkDir), Si, Pi) then
    begin
      CloseHandle(WritePipe);
      WritePipe := 0;

      repeat
        Success := ReadFile(ReadPipe, Buffer[0], SizeOf(Buffer) - 1, BytesRead, nil);
        if BytesRead > 0 then
        begin
          Buffer[BytesRead] := #0;
          AOutput := AOutput + string(AnsiString(Buffer));
        end;
      until not Success or (BytesRead = 0);

      WaitForSingleObject(Pi.hProcess, INFINITE);

      ExitCode := 0;
      GetExitCodeProcess(Pi.hProcess, ExitCode);
      Result := (ExitCode = 0);

      CloseHandle(Pi.hProcess);
      CloseHandle(Pi.hThread);
    end;
  finally
    if ReadPipe <> 0 then CloseHandle(ReadPipe);
    if WritePipe <> 0 then CloseHandle(WritePipe);
  end;
end;

function TTestExplorerModel.CompileProjectDirect(const AProjFile: string; AOnConsole: TProc<string>): Boolean;
var
  DccExe: string;
  Content: string;
  SearchPath, Defines, Namespaces, DcuOutput, ExeOutput: string;
  WorkDir: string;
  ProductVer: string;
  BDS: string;
  CommonDir: string;
  CmdLine: string;
  Output: string;
  ProjName: string;
  DprFile: string;

  function ResolvePaths(const APaths: string): string;
  var
    Parts: TArray<string>;
    i: Integer;
    Resolved: string;
    Part: string;
  begin
    Parts := APaths.Split([';']);
    Resolved := '';
    for i := 0 to Length(Parts) - 1 do
    begin
      Part := Parts[i].Trim;
      if Part = '' then Continue;
      if not TPath.IsPathRooted(Part) then
        Part := TPath.Combine(WorkDir, Part);
      Part := TPath.GetFullPath(Part);
      if Resolved <> '' then Resolved := Resolved + ';';
      Resolved := Resolved + Part;
    end;
    Result := Resolved;
  end;

begin
  Result := False;
  if not FileExists(AProjFile) then Exit;

  WorkDir := ExtractFilePath(AProjFile);
  ProjName := TPath.GetFileNameWithoutExtension(AProjFile);
  DprFile := TPath.Combine(WorkDir, ProjName + '.dpr');
  if not FileExists(DprFile) then
    DprFile := TPath.Combine(WorkDir, ProjName + '.dpk');

  if not FileExists(DprFile) then
  begin
    TThread.Queue(nil, TThreadProcedure(procedure
      begin
        AOnConsole('Error: DPR/DPK file not found: ' + DprFile);
      end));
    Exit;
  end;

  DccExe := ExtractFilePath(ParamStr(0)) + 'dcc32.exe';
  if not FileExists(DccExe) then
  begin
    TThread.Queue(nil, TThreadProcedure(procedure
      begin
        AOnConsole('Error: Compiler not found: ' + DccExe);
      end));
    Exit;
  end;

  try
    Content := TFile.ReadAllText(AProjFile);
  except
    on E: Exception do
    begin
      TThread.Queue(nil, TThreadProcedure(procedure
        begin
          AOnConsole('Error reading project file: ' + E.Message);
        end));
      Exit;
    end;
  end;

  SearchPath := ExtractTagValue(Content, 'DCC_UnitSearchPath');
  Defines := ExtractTagValue(Content, 'DCC_Define');
  Namespaces := ExtractTagValue(Content, 'DCC_Namespace');
  DcuOutput := ExtractTagValue(Content, 'DCC_DcuOutput');
  ExeOutput := ExtractTagValue(Content, 'DCC_ExeOutput');

  ProductVer := GetDelphiProductVersion;
  BDS := ExcludeTrailingPathDelimiter(ExtractFileDir(ExtractFileDir(ParamStr(0))));
  CommonDir := 'C:\Users\Public\Documents\Embarcadero\Studio\' + ProductVer;

  SearchPath := SearchPath.Replace('$(ProductVersion)', ProductVer)
                           .Replace('$(Platform)', 'Win32')
                           .Replace('$(Config)', 'Debug')
                           .Replace('$(BDS)', BDS)
                           .Replace('$(BDSCOMMONDIR)', CommonDir)
                           .Replace('$(DCC_UnitSearchPath)', '');

  Defines := Defines.Replace('$(DCC_Define)', '').Trim;
  if Defines.EndsWith(';') then
    Defines := Defines.Substring(0, Defines.Length - 1).Trim;

  Namespaces := Namespaces.Replace('$(DCC_Namespace)', '').Trim;
  if Namespaces.EndsWith(';') then
    Namespaces := Namespaces.Substring(0, Namespaces.Length - 1).Trim;

  DcuOutput := DcuOutput.Replace('$(ProductVersion)', ProductVer)
                          .Replace('$(Platform)', 'Win32')
                          .Replace('$(Config)', 'Debug');
  ExeOutput := ExeOutput.Replace('$(ProductVersion)', ProductVer)
                          .Replace('$(Platform)', 'Win32')
                          .Replace('$(Config)', 'Debug');

  SearchPath := ResolvePaths(SearchPath);
  if DcuOutput <> '' then
  begin
    if not TPath.IsPathRooted(DcuOutput) then
      DcuOutput := TPath.Combine(WorkDir, DcuOutput);
    DcuOutput := TPath.GetFullPath(DcuOutput);
    ForceDirectories(DcuOutput);
  end;
  if ExeOutput <> '' then
  begin
    if not TPath.IsPathRooted(ExeOutput) then
      ExeOutput := TPath.Combine(WorkDir, ExeOutput);
    ExeOutput := TPath.GetFullPath(ExeOutput);
    ForceDirectories(ExeOutput);
  end;

  if SearchPath <> '' then SearchPath := SearchPath + ';';
  SearchPath := SearchPath + WorkDir;

  CmdLine := Format('"%s" -Q -M -U"%s"', [DccExe, SearchPath]);
  if Defines <> '' then CmdLine := CmdLine + ' -D' + Defines;
  if Namespaces <> '' then CmdLine := CmdLine + ' -NS' + Namespaces;
  if DcuOutput <> '' then CmdLine := CmdLine + ' -N0"' + DcuOutput + '"';
  if ExeOutput <> '' then CmdLine := CmdLine + ' -E"' + ExeOutput + '"';
  CmdLine := CmdLine + ' "' + DprFile + '"';

  TThread.Queue(nil, TThreadProcedure(procedure
    begin
      AOnConsole('DCC Command: ' + CmdLine);
    end));

  if ExecuteAndCapture(CmdLine, WorkDir, Output) then
  begin
    TThread.Queue(nil, TThreadProcedure(procedure
      begin
        AOnConsole(Output);
        AOnConsole('Direct compilation successful.');
      end));
    Result := True;
  end
  else
  begin
    TThread.Queue(nil, TThreadProcedure(procedure
      begin
        AOnConsole(Output);
        AOnConsole('Direct compilation failed.');
      end));
  end;
end;

destructor TTestExplorerModel.Destroy;
begin
  StopTests;
  FServer.Stop;
  FServer.Free;
  FTestLocations.Free;
  inherited;
end;

function TTestExplorerModel.ExtractTagValue(const AContent, ATagName: string): string;
var
  LStart, LEnd: Integer;
begin
  Result := '';
  LStart := AContent.LastIndexOf('<' + ATagName + '>');
  if LStart >= 0 then
  begin
    Inc(LStart, Length(ATagName) + 2);
    LEnd := AContent.IndexOf('</' + ATagName + '>', LStart);
    if LEnd > LStart then
      Result := AContent.Substring(LStart, LEnd - LStart).Trim;
  end;
end;

function TTestExplorerModel.GetProjectTargetInfo(const AProjFile: string; out AIsPackage: Boolean; out AOutput: string; const APlatform: string; const AConfig: string): Boolean;
var
  LContent: string;
  LPlatformTag: string;
  LPlatformGroupStart, LPlatformGroupEnd: Integer;
  LPlatformGroup: string;
  LOutStart, LOutEnd: Integer;
  LBaseGroupStart, LBaseGroupEnd: Integer;
  LBaseGroup: string;
begin
  Result := False;
  AIsPackage := False;
  AOutput := '';
  if not FileExists(AProjFile) then Exit;
  try
    LContent := TFile.ReadAllText(AProjFile);
    AIsPackage := LContent.Contains('<AppType>Package</AppType>');

    // 1. Try platform-specific base property group
    LPlatformTag := 'Base_' + APlatform;
    LPlatformGroupStart := LContent.IndexOf('Condition="''$(' + LPlatformTag + ')''!=''''"');
    if LPlatformGroupStart < 0 then
      LPlatformGroupStart := LContent.IndexOf('Condition="''$(Platform)''==''' + APlatform + '''"');

    if LPlatformGroupStart >= 0 then
    begin
      LPlatformGroupStart := LContent.LastIndexOf('<PropertyGroup', LPlatformGroupStart);
      if LPlatformGroupStart >= 0 then
      begin
        LPlatformGroupEnd := LContent.IndexOf('</PropertyGroup>', LPlatformGroupStart);
        if LPlatformGroupEnd > LPlatformGroupStart then
        begin
          LPlatformGroup := LContent.Substring(LPlatformGroupStart, LPlatformGroupEnd - LPlatformGroupStart);
          LOutStart := LPlatformGroup.IndexOf('<DCC_ExeOutput>');
          if LOutStart >= 0 then
          begin
            Inc(LOutStart, Length('<DCC_ExeOutput>'));
            LOutEnd := LPlatformGroup.IndexOf('</DCC_ExeOutput>', LOutStart);
            if LOutEnd > LOutStart then
              AOutput := LPlatformGroup.Substring(LOutStart, LOutEnd - LOutStart).Trim;
          end;
        end;
      end;
    end;

    // 2. Try base configurations
    if AOutput = '' then
    begin
      LBaseGroupStart := LContent.IndexOf('Condition="''$(Base)''!=''''"');
      if LBaseGroupStart >= 0 then
      begin
        LBaseGroupStart := LContent.LastIndexOf('<PropertyGroup', LBaseGroupStart);
        if LBaseGroupStart >= 0 then
        begin
          LBaseGroupEnd := LContent.IndexOf('</PropertyGroup>', LBaseGroupStart);
          if LBaseGroupEnd > LBaseGroupStart then
          begin
            LBaseGroup := LContent.Substring(LBaseGroupStart, LBaseGroupEnd - LBaseGroupStart);
            LOutStart := LBaseGroup.IndexOf('<DCC_ExeOutput>');
            if LOutStart >= 0 then
            begin
              Inc(LOutStart, Length('<DCC_ExeOutput>'));
              LOutEnd := LBaseGroup.IndexOf('</DCC_ExeOutput>', LOutStart);
              if LOutEnd > LOutStart then
                AOutput := LBaseGroup.Substring(LOutStart, LOutEnd - LOutStart).Trim;
            end;
          end;
        end;
      end;
    end;

    // 3. Fallback
    if AOutput = '' then
      AOutput := ExtractTagValue(LContent, 'DCC_ExeOutput');

    Result := True;
  except
  end;
end;

function TTestExplorerModel.ResolveExePath(const AProjFile, AOutput: string; const APlatform: string; const AConfig: string): string;
var
  LWorkDir: string;
  LProjName: string;
  LOutDir: string;
begin
  LWorkDir := ExtractFilePath(AProjFile);
  LProjName := TPath.GetFileNameWithoutExtension(AProjFile);
  LOutDir := AOutput;
  if LOutDir = '' then
    LOutDir := LWorkDir;
  if not TPath.IsPathRooted(LOutDir) then
    LOutDir := TPath.Combine(LWorkDir, LOutDir);
  LOutDir := LOutDir.Replace('$(Platform)', APlatform).Replace('$(Config)', AConfig);
  Result := TPath.Combine(TPath.GetFullPath(LOutDir), LProjName + '.exe');
end;

procedure TTestExplorerModel.ScanProjectTests(const AProjFile: string; AOnScanFinished: TProc<TList<TTestLocation>>);
begin
  TTask.Run(TProc(procedure
    var
      List: TList<TTestLocation>;
      FileName: string;
      ProjectDirectory: string;
    begin
      List := TList<TTestLocation>.Create;
      try
        ProjectDirectory := ExtractFilePath(AProjFile);
        if TDirectory.Exists(ProjectDirectory) then
        begin
          for FileName in TDirectory.GetFiles(ProjectDirectory, '*.pas', TSearchOption.soAllDirectories) do
          begin
            TTestASTScanner.ScanFile(FileName, List);
          end;
        end;
      finally
        TThread.Queue(nil, TThreadProcedure(procedure
          begin
            AOnScanFinished(List);
          end));
      end;
    end));
end;

procedure TTestExplorerModel.CompileAndRunTests(const AProjFile: string; const ATestFilter: string; ACheckedTests: TArray<string>; AOnStart: TProc; AOnFinished: TProc; AOnConsole: TProc<string>);
begin
  TTask.Run(TProc(procedure
    var
      IsPackage: Boolean;
      Output: string;
      ExeFile: string;
      CmdLine: string;
      Params: string;
      JSON: string;
      Idx: Integer;
      SI: Winapi.Windows.TStartupInfo;
      PI: Winapi.Windows.TProcessInformation;
      PlatformVal: string;
      Config: string;
      ModuleServices: IOTAModuleServices;
      Group: IOTAProjectGroup;
      Proj: IOTAProject;
      Configs: IOTAProjectOptionsConfigurations;
      I: Integer;
    begin
      TThread.Queue(nil, TThreadProcedure(AOnStart));

      if not CompileProjectDirect(AProjFile, AOnConsole) then
      begin
        TThread.Queue(nil, TThreadProcedure(AOnFinished));
        Exit;
      end;

      PlatformVal := 'Win32';
      Config := 'Debug';
      Proj := nil;
      if Supports(BorlandIDEServices, IOTAModuleServices, ModuleServices) then
      begin
        Group := ModuleServices.MainProjectGroup;
        if Assigned(Group) then
        begin
          for I := 0 to Group.ProjectCount - 1 do
          begin
            if SameText(Group.Projects[I].FileName, AProjFile) then
            begin
              Proj := Group.Projects[I];
              Break;
            end;
          end;
        end;
      end;
      if Assigned(Proj) then
      begin
        if Supports(Proj.ProjectOptions, IOTAProjectOptionsConfigurations, Configs) then
        begin
          PlatformVal := Configs.ActivePlatformName;
          if Assigned(Configs.ActiveConfiguration) then
            Config := Configs.ActiveConfiguration.Name;
        end;
      end;

      GetProjectTargetInfo(AProjFile, IsPackage, Output, PlatformVal, Config);
      ExeFile := ResolveExePath(AProjFile, Output, PlatformVal, Config);

      if not FileExists(ExeFile) then
      begin
        TThread.Queue(nil, TThreadProcedure(procedure
          begin
            AOnConsole('Error: Executable not found at ' + ExeFile);
            AOnFinished();
          end));
        Exit;
      end;

      if ATestFilter <> '' then
        FServer.SelectedTestsJSON := '["' + ATestFilter + '"]'
      else if Length(ACheckedTests) > 0 then
      begin
        JSON := '[';
        for Idx := 0 to Length(ACheckedTests) - 1 do
        begin
          if Idx > 0 then JSON := JSON + ',';
          JSON := JSON + '"' + ACheckedTests[Idx] + '"';
        end;
        JSON := JSON + ']';
        FServer.SelectedTestsJSON := JSON;
      end
      else
        FServer.SelectedTestsJSON := '[]';

      Params := Format('--port %d -no-wait', [FServer.Port]);
      CmdLine := Format('"%s" %s', [ExeFile, Params]);
      TThread.Queue(nil, TThreadProcedure(procedure
        begin
          AOnConsole('Executing: ' + CmdLine);
        end));

      ZeroMemory(@SI, SizeOf(SI));
      SI.cb := SizeOf(SI);
      ZeroMemory(@PI, SizeOf(PI));

      if Winapi.Windows.CreateProcess(nil, PChar(CmdLine), nil, nil, False, CREATE_NO_WINDOW, nil, PChar(ExtractFilePath(ExeFile)), SI, PI) then
      begin
        FRunningProcessHandle := PI.hProcess;
        CloseHandle(PI.hThread);
        WaitForSingleObject(PI.hProcess, 120000);
        CloseHandle(PI.hProcess);
        FRunningProcessHandle := 0;
      end
      else
      begin
        TThread.Queue(nil, TThreadProcedure(procedure
          begin
            AOnConsole('Failed to start test process.');
          end));
      end;

      TThread.Queue(nil, TThreadProcedure(AOnFinished));
    end));
end;

procedure TTestExplorerModel.StopTests;
begin
  if FRunningProcessHandle <> 0 then
  begin
    TerminateProcess(FRunningProcessHandle, 0);
    CloseHandle(FRunningProcessHandle);
    FRunningProcessHandle := 0;
  end;
end;

{ TTestExplorerPresenter }

constructor TTestExplorerPresenter.Create(const AView: ITestExplorerView);
begin
  inherited Create;
  FView := AView;
  FModel := TTestExplorerModel.Create;
  FTestDetails := TDictionary<string, TTestDetailInfo>.Create;
  FGroupSummaries := TDictionary<string, TGroupSummaryInfo>.Create;
  FStopwatch := TStopwatch.Create;
end;

destructor TTestExplorerPresenter.Destroy;
begin
  FGroupSummaries.Free;
  FTestDetails.Free;
  FModel.Free;
  inherited;
end;

procedure TTestExplorerPresenter.Initialize;
begin
  FModel.Server.Start(OnTestResultReceived);
end;

procedure TTestExplorerPresenter.InitializeGroupSummaries;
var
  i: Integer;
  LTest: TTestLocation;
  LKey: string;
  LInfo: TGroupSummaryInfo;
begin
  FGroupSummaries.Clear;
  for i := 0 to FModel.TestLocations.Count - 1 do
  begin
    LTest := FModel.TestLocations[i];
    LKey := LTest.ClassName;
    if not FGroupSummaries.TryGetValue(LKey, LInfo) then
    begin
      LInfo.TotalCount := 0;
      LInfo.PassedCount := 0;
      LInfo.FailedCount := 0;
      LInfo.DurationMs := 0;
    end;
    Inc(LInfo.TotalCount);
    FGroupSummaries.AddOrSetValue(LKey, LInfo);
  end;
end;

procedure TTestExplorerPresenter.UpdateGroupSummary(const ATestName, AStatus: string; ADurationMs: Double);
var
  LClassName: string;
  LDotPos: Integer;
  LInfo: TGroupSummaryInfo;
  LIdx: Integer;
  LTest: TTestLocation;
begin
  LDotPos := ATestName.IndexOf('.');
  if LDotPos <= 0 then Exit;
  LClassName := ATestName.Substring(0, LDotPos);
  if not FGroupSummaries.TryGetValue(LClassName, LInfo) then
  begin
    LInfo.TotalCount := 0;
    LInfo.PassedCount := 0;
    LInfo.FailedCount := 0;
    LInfo.DurationMs := 0;
    for LIdx := 0 to FModel.TestLocations.Count - 1 do
    begin
      LTest := FModel.TestLocations[LIdx];
      if SameText(LTest.ClassName, LClassName) then
        Inc(LInfo.TotalCount);
    end;
  end;

  if SameText(AStatus, 'Passed') then
    Inc(LInfo.PassedCount)
  else if SameText(AStatus, 'Failed') or SameText(AStatus, 'Error') then
    Inc(LInfo.FailedCount);
  LInfo.DurationMs := LInfo.DurationMs + ADurationMs;
  FGroupSummaries.AddOrSetValue(LClassName, LInfo);
end;

procedure TTestExplorerPresenter.OnTestResultReceived(const AJSONData: string);
begin
  ProcessSingleResult(AJSONData);
end;

procedure TTestExplorerPresenter.ProcessSingleResult(const AJSON: string);
var
  LVal: TJSONValue;
  LObj: TJSONObject;
  LEvent: string;
  LTestName, LStatus: string;
  LDurationMs: Double;
  LErrMsg, LStackTrace: string;
  LErrObj: TJSONObject;
  LPassed, LFailed, LIgnored: Integer;
begin
  LVal := TJSONObject.ParseJSONValue(AJSON);
  if LVal = nil then Exit;
  try
    if LVal is TJSONObject then
    begin
      LObj := TJSONObject(LVal);
      if LObj.TryGetValue<string>('event', LEvent) then
      begin
        if SameText(LEvent, 'RunStart') then
        begin
          FTotalTests := LObj.GetValue<Integer>('totalTests');
          FCompletedTests := 0;
          FPassedCount := 0;
          FFailedCount := 0;
          FSkippedCount := 0;
          FDurationMs := 0;
          FStopwatch.Reset;
          FStopwatch.Start;
          InitializeGroupSummaries;
          FView.ShowProgress('Running tests...', False);
          FView.UpdateProgressInfo(0, FTotalTests);
          Exit;
        end
        else if SameText(LEvent, 'RunComplete') then
        begin
          LPassed := LObj.GetValue<Integer>('passed');
          LFailed := LObj.GetValue<Integer>('failed');
          LIgnored := LObj.GetValue<Integer>('ignored');
          FStopwatch.Stop;
          FView.HideProgress;
          FView.AppendConsoleLine(Format('Testing completed. Passed: %d, Failed: %d, Ignored: %d', [LPassed, LFailed, LIgnored]));
          FView.UpdateSummary(FPassedCount, FFailedCount, FSkippedCount, FTotalTests, FStopwatch.Elapsed.TotalSeconds);
          Exit;
        end;
      end;

      if LObj.TryGetValue<string>('testName', LTestName) then
      begin
        LObj.TryGetValue<string>('status', LStatus);
        LObj.TryGetValue<Double>('durationMs', LDurationMs);
        LErrMsg := '';
        LStackTrace := '';
        if LObj.TryGetValue<TJSONObject>('error', LErrObj) and (LErrObj <> nil) then
        begin
          LErrMsg := LErrObj.GetValue<string>('message');
          if LErrObj.TryGetValue<TJSONObject>('stackTrace', LErrObj) and (LErrObj <> nil) then
            LStackTrace := LErrObj.ToJSON;
        end;

        Inc(FCompletedTests);
        FView.UpdateProgressInfo(FCompletedTests, FTotalTests);

        if SameText(LStatus, 'Passed') then
          Inc(FPassedCount)
        else if SameText(LStatus, 'Failed') or SameText(LStatus, 'Error') then
          Inc(FFailedCount)
        else
          Inc(FSkippedCount);

        var LDetails: TTestDetailInfo;
        LDetails.TestName := LTestName;
        LDetails.Status := LStatus;
        LDetails.DurationMs := LDurationMs;
        LDetails.ErrorMessage := LErrMsg;
        LDetails.StackTrace := LStackTrace;
        FTestDetails.AddOrSetValue(LTestName, LDetails);

        UpdateGroupSummary(LTestName, LStatus, LDurationMs);
        FView.UpdateTestNode(LTestName, LStatus, LDurationMs, LErrMsg, LStackTrace);
        FView.ForceRepaintNode(LTestName);
      end;
    end;
  finally
    LVal.Free;
  end;
end;

procedure TTestExplorerPresenter.RunAllClick;
begin
  FView.ClearTestTree;
  FModel.CompileAndRunTests(FModel.ActiveProjectFile, '', [],
    procedure
    begin
      FView.ShowProgress('Compiling and launching tests...', True);
    end,
    procedure
    begin
      FView.HideProgress;
    end,
    procedure(AMsg: string)
    begin
      FView.AppendConsoleLine(AMsg);
    end);
end;

procedure TTestExplorerPresenter.RunSelectedClick(const AFilter: string; AChecked: TArray<string>);
begin
  FModel.CompileAndRunTests(FModel.ActiveProjectFile, AFilter, AChecked,
    procedure
    begin
      FView.ShowProgress('Compiling and running selection...', True);
    end,
    procedure
    begin
      FView.HideProgress;
    end,
    procedure(AMsg: string)
    begin
      FView.AppendConsoleLine(AMsg);
    end);
end;

procedure TTestExplorerPresenter.StopClick;
begin
  FModel.StopTests;
  FView.HideProgress;
  FView.AppendConsoleLine('Test run aborted by user.');
end;

procedure TTestExplorerPresenter.RefreshClick;
begin
  FView.ShowProgress('Scanning project files...', True);
  FModel.ScanProjectTests(FModel.ActiveProjectFile, procedure(AList: TList<TTestLocation>)
    begin
      FModel.TestLocations.Clear;
      FModel.TestLocations.AddRange(AList);
      FView.RefreshTestTree(FModel.TestLocations);
      FView.HideProgress;
    end);
end;

procedure TTestExplorerPresenter.SelectTest(const ATestName: string);
var
  LDetails: TTestDetailInfo;
  LLocText: string;
  LIdx: Integer;
  Loc: TTestLocation;
begin
  LLocText := 'Location: Unknown';
  for LIdx := 0 to FModel.TestLocations.Count - 1 do
  begin
    Loc := FModel.TestLocations[LIdx];
    if SameText(Loc.ClassName + '.' + Loc.MethodName, ATestName) or SameText(Loc.MethodName, ATestName) then
    begin
      LLocText := Format('Location: %s (Line %d)', [ExtractFileName(Loc.FileName), Loc.Line]);
      Break;
    end;
  end;

  if FTestDetails.TryGetValue(ATestName, LDetails) then
  begin
    FView.UpdateTestDetails(ATestName, LDetails.Status, LLocText,
      Format('%.2f ms', [LDetails.DurationMs]), LDetails.ErrorMessage, LDetails.StackTrace);
  end
  else
  begin
    FView.UpdateTestDetails(ATestName, 'Idle', LLocText, 'N/A', '', '');
  end;
end;

end.
