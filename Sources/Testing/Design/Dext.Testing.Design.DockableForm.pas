unit Dext.Testing.Design.DockableForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ComCtrls, Vcl.StdCtrls,
  Vcl.ExtCtrls, Vcl.Buttons, DockForm, ToolsAPI, Dext.Testing.Design.Server, Dext.Testing.Design.AST,
  System.JSON, System.Generics.Collections, System.IOUtils, System.Threading,
  System.ImageList, Vcl.ImgList, Vcl.Menus, System.Math, System.Diagnostics, System.TimeSpan;

type
  TFormDextTestRunner = class;

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

  TTestTreeNodeInfo = class
  public
    FullTestName: string;
    TestIndex: Integer;
    Status: string;
    DurationMs: Double;
    IsGroup: Boolean;
    GroupTestCount: Integer;
    GroupPassedCount: Integer;
    GroupFailedCount: Integer;
    GroupDurationMs: Double;
    constructor Create;
  end;

  TDextProjectInfo = class
  public
    FileName: string;
    constructor Create(const AFileName: string);
  end;

  TDextProjectNotifier = class(TNotifierObject, IOTAModuleNotifier, IOTAProjectNotifier)
  private
    FForm: TFormDextTestRunner;
    FProjectFile: string;
  public
    constructor Create(AForm: TFormDextTestRunner; const AProjectFile: string);
    // IOTAModuleNotifier
    function CheckOverwrite: Boolean;
    procedure ModuleRenamed(const NewName: string); overload;
    // IOTAProjectNotifier
    procedure ModuleAdded(const AFileName: string);
    procedure ModuleRemoved(const AFileName: string);
    procedure ModuleRenamed(const AOldFileName, ANewFileName: string); overload;
  end;

  TTestSession = class
  public
    TabSheet: TTabSheet;
    TreeView: TTreeView;
    TestLocations: TList<TTestLocation>;
    ActiveProjectFile: string;
    FilterEdit: TEdit;
    ClearFilterButton: TSpeedButton;
    constructor Create(APageControl: TPageControl; const AName: string); overload;
    constructor CreateFromExisting(ATabSheet: TTabSheet; ATreeView: TTreeView; ALocations: TList<TTestLocation>; const AProjFile: string); overload;
    destructor Destroy; override;
  end;

  TFileScanCache = class
  public
    Timestamp: TDateTime;
    Tests: TList<TTestLocation>;
    constructor Create(ATimestamp: TDateTime; ATests: TList<TTestLocation>);
    destructor Destroy; override;
  end;

  TTelemetryTracker = class
  public
    class procedure RecordTestResult(const AProjectFile, ATestName, AStatus: string; ADurationMs: Integer);
    class procedure AnalyzeHistory(const AProjectFile: string; AMemo: TMemo);
  end;

  TTestExplorerLayout = (telCompact, telSplitBottom, telSplitRight);
  TTestGroupingMode = (tgmCodeStructure, tgmStatus);

  TFormDextTestRunner = class(TDockableForm)
    ActionsButton: TButton;
    ActionsPopupMenu: TPopupMenu;
    ButtonsPanel: TPanel;
    ClearMenuItem: TMenuItem;
    ClearSeparator: TMenuItem;
    ConfigScroll: TScrollBox;
    ConfigTab: TTabSheet;
    ConsoleTab: TTabSheet;
    CreateaNewSessionMenuItem: TMenuItem;
    CustomParamsEdit: TEdit;
    CustomParamsLabel: TLabel;
    DefaultSessionTabSheet: TTabSheet;
    DetailsMemo: TMemo;
    DetailsPageControl: TPageControl;
    DetailsPanel: TPanel;
    DurationLabel: TLabel;
    EnabledCheckBox: TCheckBox;
    EnableDisableTestExplorerMenuItem: TMenuItem;
    ErrorHeaderLabel: TLabel;
    ErrorMemo: TMemo;
    ExportSeparator: TMenuItem;
    ExportToHtmlReportMenuItem: TMenuItem;
    ExportToJsonMenutem: TMenuItem;
    ExportToJUnitXmlMenutem: TMenuItem;
    ExportToSonarQubeXmlMenutem: TMenuItem;
    ExportToXUnitXMLMenutem: TMenuItem;
    GroupByClassMenuItem: TMenuItem;
    GroupByTestStatusMenuItem: TMenuItem;
    InfoPanel: TPanel;
    InspectorScroll: TScrollBox;
    InspectorTab: TTabSheet;
    LayoutSeparator: TMenuItem;
    LocationLabel: TLabel;
    NameSplitter: TSplitter;
    ProgressBar: TProgressBar;
    ProgressLabel: TLabel;
    ProgressPanel: TPanel;
    ProjectsComboBox: TComboBox;
    RefreshButton: TButton;
    RunAllButton: TButton;
    RunOnIdleCheckBox: TCheckBox;
    RunOnSaveCheckBox: TCheckBox;
    RunSelectedButton: TButton;
    SessionsPageControl: TPageControl;
    SplitBottomLayoutMenuItem: TMenuItem;
    SplitRightLayoutMenuItem: TMenuItem;
    StatusLabel: TLabel;
    StopButton: TButton;
    SummaryFailedLabel: TLabel;
    SummaryPanel: TPanel;
    SummarySelectedLabel: TLabel;
    SummarySkippedLabel: TLabel;
    SummarySuccessLabel: TLabel;
    SummaryTimeLabel: TLabel;
    SummaryTotalLabel: TLabel;
    SummaryTotalTimeLabel: TLabel;
    TabbedLayoutMenuItem: TMenuItem;
    TestNameLabel: TLabel;
    TestsTreeView: TTreeView;
    procedure ActionsButtonClick(Sender: TObject);
    procedure ProjectsComboBoxChange(Sender: TObject);
    procedure RunAllButtonClick(Sender: TObject);
    procedure RunSelectedButtonClick(Sender: TObject);
    procedure StopButtonClick(Sender: TObject);
    procedure TestsTreeViewDblClick(Sender: TObject);
    procedure RefreshButtonClick(Sender: TObject);
    procedure ExpandAllMenuItemClick(Sender: TObject);
    procedure CollapseAllMenuItemClick(Sender: TObject);
  private
    FServer: TTestRunnerServer;
    FTestLocations: TList<TTestLocation>;
    FActiveProjectFile: string;
    FScanGeneration: Integer;
    FHoverNode: TTreeNode;

    // Process handling
    FRunningProcessHandle: THandle;

    // Project changes notification
    FActiveProjectNotifierIndex: Integer;
    FActiveProjectForNotifier: IOTAProject;

    // Sessions
    FSessions: TObjectList<TTestSession>;
    FActiveSession: TTestSession;
    FGroupNodes: TDictionary<string, TTreeNode>;

    // Test Inspector components
    FTestDetails: TDictionary<string, TTestDetailInfo>;
    FGroupSummaries: TDictionary<string, TGroupSummaryInfo>;
    // Progress tracking
    FTotalTests: Integer;
    FCompletedTests: Integer;
    FInspectorSplitter: TSplitter;
    FCurrentLayout: TTestExplorerLayout;
    //LayoutButton: TButton;
    // Async compile state
    FPendingTestFilter: string;
    FWaitingForCompile: Boolean;
    FPendingProject: IOTAProject;
    FThemeNotifierIndex: Integer;
    FGroupingMode: TTestGroupingMode;
    FRunningTests: Boolean;

    // Disabled/Enabled Mode
    FEnabled: Boolean;
    FDisabledPanel: TPanel;
    FDisabledContainer: TPanel;

    // Configurations/Startup Tab
    FIdleTimer: TTimer;
    FSaveTimer: TTimer;
    FPendingSaveFiles: TStringList;

    // Execution Stopwatch & Counts
    FStopwatch: TStopwatch;
    FTestExecutionDurationMs: Double;
    FPassedCount: Integer;
    FFailedCount: Integer;
    FSkippedCount: Integer;

    // File scan AST cache (thread-safe performance optimization)
    FScanCache: TObjectDictionary<string, TFileScanCache>;

    function ActiveFilterEdit: TEdit;
    function CompileProjectDirect(const AProjFile: string): Boolean;
    function FindMethodImplementationLine(const AFileName, AClassName, AMethodName: string; ADefaultLine: Integer): Integer;
    function FindNodeByPath(const APath: string): TTreeNode;
    function GetCheckedTests: TArray<string>;
    function GetNodeFullTestName(ANode: TTreeNode): string;
    function GetRunButtonRect(ANode: TTreeNode): TRect;

    procedure AddSessionButtonClick(Sender: TObject);
    procedure ApplyIDETheme;
    procedure ApplyLayout(ALayout: TTestExplorerLayout);
    procedure ClearLogsClick(Sender: TObject);
    procedure ClearTestStatus;
    procedure CloseActiveSessionClick(Sender: TObject);
    procedure CloseSession(ASession: TTestSession);
    procedure CollapseSuccessAndFocusFailures;
    procedure ConfigChangeHandler(Sender: TObject);
    procedure CreateNewSession(const AName: string);
    procedure DebugSelectedClick(Sender: TObject);
    procedure EnableBtnClick(Sender: TObject);
    procedure ExpandTestsTreeView;
    procedure ExportMenuClick(Sender: TObject);
    procedure ExportResults(const ExportFormat, FileName: string);
    procedure FilterEditChange(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure GroupingMenuClick(Sender: TObject);
    procedure IdleTimerTimer(Sender: TObject);
    procedure InitializeGroupSummaries;
    procedure InvalidateGroupNode(const ATestName: string);
    procedure LaunchTestExe(const ATestFilter: string);
    procedure LayoutMenuClick(Sender: TObject);
    procedure LogMsg(const AMsg: string);
    procedure LogPerformance(const AMessage: string);
    procedure NotifyProcessExited;
    procedure OnTestResultReceived(const AJSONData: string);
    procedure RebuildStatusImages;
    procedure RefreshTreeView;
    procedure RunAllProjectsClick(Sender: TObject);
    procedure RunAllProjectsTests;
    procedure RunFailedTestsClick(Sender: TObject);
    procedure SaveTimerTimer(Sender: TObject);
    procedure SessionsPageControlChange(Sender: TObject);
    procedure SessionTabContextPopup(Sender: TObject; MousePos: TPoint; var Handled: Boolean);
    procedure SetActiveSession(ASession: TTestSession);
    procedure SetEnabledState(AValue: Boolean);
    procedure TestsTreeViewAdvancedCustomDrawItem(Sender: TCustomTreeView; Node: TTreeNode; State: TCustomDrawState; Stage: TCustomDrawStage; var PaintImages, DefaultDraw: Boolean);
    procedure TestsTreeViewChange(Sender: TObject; Node: TTreeNode);
    procedure TestsTreeViewMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure TestsTreeViewMouseLeave(Sender: TObject);
    procedure TestsTreeViewMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure TestsTreeViewMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure ToggleEnabledClick(Sender: TObject);
    procedure TryLoadCoverage;
    procedure UpdateGroupSummary(const ATestName, AStatus: string; ADurationMs: Double);
    procedure UpdateNodeResultCache(const ATestName, AStatus: string; ADurationMs: Double);
    procedure UpdateSummaryCounts;
    procedure UpdateTabVisibility;
    procedure UpdateTestInspector(const ATestName: string);
    procedure UpdateTestNode(const ATestName, AStatus, AMessage, AStackTrace: string);
    procedure UpdateTimingLabels;
    procedure UpdateTotalTimeLabel;
    procedure ApplyDpiScaling;
    procedure ClearFilterButtonClick(Sender: TObject);

    // Process handling
    function GetProjectByFileName(const AFileName: string): IOTAProject;
    procedure RefreshActiveProjectTestsList;
    procedure ResetSummaryLabels;
  protected
    procedure CMStyleChanged(var Message: TMessage); message CM_STYLECHANGED;
    procedure DoShow; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure HandleFileSaved(const AFileName: string);
    procedure RunActiveProjectTests(const TestFilter: string = ''; AutoSave: Boolean = True);
    procedure RunImpactedTests(const ATests: TArray<string>);
    // Called by the IDE AfterCompile notifier
    procedure NotifyCompileComplete(ASucceeded: Boolean);
    procedure RefreshProjects;
  end;

procedure ShowDextTestExplorer;
procedure RegisterDockableForm;
procedure UnregisterDockableForm;
procedure LogToFile(const AMsg: string);

var
  FormDextTestRunner: TFormDextTestRunner = nil;

implementation

{$R *.dfm}

{.$DEFINE DEXT_TEST_EXPLORER_PERF_LOG}

uses
  DeskUtil, Dext.Utils, System.Actions, Vcl.ActnList, Dext.Testing.Design.Coverage, System.IniFiles,
  Winapi.CommCtrl, Dext.Testing.Report, Dext.Testing.Runner, Dext.Testing.Integration;

{$IFDEF DEXT_TEST_EXPLORER_PERF_LOG}
var
  PerfLogLock: TObject;
{$ENDIF}

{$IF CompilerVersion < 35.0}
type
  TTreeViewHelper = class helper for TTreeView
  private
    function GetCheckboxes: Boolean;
    procedure SetCheckboxes(Value: Boolean);
  public
    property Checkboxes: Boolean read GetCheckboxes write SetCheckboxes;
  end;

  TTreeNodeHelper = class helper for TTreeNode
  private
    function GetChecked: Boolean;
    procedure SetChecked(Value: Boolean);
  public
    property Checked: Boolean read GetChecked write SetChecked;
  end;

function TTreeViewHelper.GetCheckboxes: Boolean;
begin
  Result := (GetWindowLong(Handle, GWL_STYLE) and TVS_CHECKBOXES) <> 0;
end;

procedure TTreeViewHelper.SetCheckboxes(Value: Boolean);
var
  Style: Longint;
begin
  Style := GetWindowLong(Handle, GWL_STYLE);
  if Value then
    Style := Style or TVS_CHECKBOXES
  else
    Style := Style and not TVS_CHECKBOXES;
  SetWindowLong(Handle, GWL_STYLE, Style);
end;

function TTreeNodeHelper.GetChecked: Boolean;
var
  TVItem: TTVItem;
begin
  Result := False;
  if (TreeView <> nil) and (TreeView.HandleAllocated) then
  begin
    TVItem.mask := TVIF_STATE or TVIF_HANDLE;
    TVItem.hItem := ItemId;
    TVItem.stateMask := TVIS_STATEIMAGEMASK;
    if TreeView_GetItem(TreeView.Handle, TVItem) then
      Result := ((TVItem.state and TVIS_STATEIMAGEMASK) shr 12) = 2;
  end;
end;

procedure TTreeNodeHelper.SetChecked(Value: Boolean);
var
  TVItem: TTVItem;
begin
  if (TreeView <> nil) and (TreeView.HandleAllocated) then
  begin
    TVItem.mask := TVIF_STATE or TVIF_HANDLE;
    TVItem.hItem := ItemId;
    TVItem.stateMask := TVIS_STATEIMAGEMASK;
    if Value then
      TVItem.state := 2 shl 12
    else
      TVItem.state := 1 shl 12;
    TreeView_SetItem(TreeView.Handle, TVItem);
  end;
end;
{$ENDIF}

type
  TDextThemeNotifier = class(TNotifierObject, INTAIDEThemingServicesNotifier)
  private
    FForm: TFormDextTestRunner;
  public
    constructor Create(AForm: TFormDextTestRunner);
    // INTAIDEThemingServicesNotifier
    procedure ChangingTheme;
    procedure ChangedTheme;
  end;

constructor TDextThemeNotifier.Create(AForm: TFormDextTestRunner);
begin
  inherited Create;
  FForm := AForm;
end;

procedure TDextThemeNotifier.ChangingTheme;
begin
end;

procedure TDextThemeNotifier.ChangedTheme;
begin
  if Assigned(FForm) then
  begin
    TThread.ForceQueue(nil, TThreadProcedure(procedure
      begin
        FForm.ApplyIDETheme;
      end));
  end;
end;

procedure ShowDextTestExplorer;
begin
  if not Assigned(FormDextTestRunner) then
    FormDextTestRunner := TFormDextTestRunner.Create(nil);
  ShowDockableForm(FormDextTestRunner);
end;

procedure RegisterDockableForm;
var
  ThemingServices: IOTAIDEThemingServices;
begin
  if @RegisterFieldAddress <> nil then
    RegisterFieldAddress('FormDextTestRunner', @FormDextTestRunner);
  RegisterDesktopFormClass(TFormDextTestRunner, 'FormDextTestRunner', 'FormDextTestRunner');

  if Supports(BorlandIDEServices, IOTAIDEThemingServices, ThemingServices) then
    ThemingServices.RegisterFormClass(TFormDextTestRunner);
end;

procedure UnregisterDockableForm;
begin
  if @UnRegisterFieldAddress <> nil then
    UnRegisterFieldAddress(@FormDextTestRunner);
  if Assigned(FormDextTestRunner) then
  begin
    FormDextTestRunner.Free;
    FormDextTestRunner := nil;
  end;
end;

function GetModuleBuildTime: string;
var
  FilePath: array[0..MAX_PATH] of Char;
  FileTime: TFileTime;
  SystemTime: TSystemTime;
  LocalTime: TSystemTime;
  Handle: THandle;
begin
  Result := '';
  if GetModuleFileName(HInstance, FilePath, Length(FilePath)) > 0 then
  begin
    Handle := CreateFile(FilePath, GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
    if Handle <> INVALID_HANDLE_VALUE then
    begin
      try
        if GetFileTime(Handle, nil, nil, @FileTime) then
        begin
          if FileTimeToSystemTime(FileTime, SystemTime) then
          begin
            if SystemTimeToTzSpecificLocalTime(nil, SystemTime, LocalTime) then
            begin
              Result := Format('%.4d-%.2d-%.2d %.2d:%.2d:%.2d',
                [LocalTime.wYear, LocalTime.wMonth, LocalTime.wDay,
                 LocalTime.wHour, LocalTime.wMinute, LocalTime.wSecond]);
            end;
          end;
        end;
      finally
        CloseHandle(Handle);
      end;
    end;
  end;
end;

{ TDextProjectInfo }

constructor TDextProjectInfo.Create(const AFileName: string);
begin
  inherited Create;
  FileName := AFileName;
end;

constructor TTestTreeNodeInfo.Create;
begin
  inherited Create;
  TestIndex := -1;
end;

{ TDextProjectNotifier }

constructor TDextProjectNotifier.Create(AForm: TFormDextTestRunner; const AProjectFile: string);
begin
  inherited Create;
  FForm := AForm;
  FProjectFile := AProjectFile;
end;

function TDextProjectNotifier.CheckOverwrite: Boolean;
begin
  Result := True;
end;

procedure TDextProjectNotifier.ModuleRenamed(const NewName: string);
begin
end;

procedure TDextProjectNotifier.ModuleAdded(const AFileName: string);
begin
  if Assigned(FForm) then
  begin
    TThread.ForceQueue(nil, TThreadProcedure(procedure
      begin
        if Assigned(FormDextTestRunner) then
          FormDextTestRunner.RefreshActiveProjectTestsList;
      end));
  end;
end;

procedure TDextProjectNotifier.ModuleRemoved(const AFileName: string);
begin
  if Assigned(FForm) then
  begin
    TThread.ForceQueue(nil, TThreadProcedure(procedure
      begin
        if Assigned(FormDextTestRunner) then
          FormDextTestRunner.RefreshActiveProjectTestsList;
      end));
  end;
end;

procedure TDextProjectNotifier.ModuleRenamed(const AOldFileName, ANewFileName: string);
begin
end;

{ TTestSession }

constructor TTestSession.Create(APageControl: TPageControl; const AName: string);
var
  PPI: Integer;
  FilterPanel: TPanel;
begin
  inherited Create;
  TestLocations := TList<TTestLocation>.Create;

  TabSheet := TTabSheet.Create(APageControl.Owner);
  TabSheet.PageControl := APageControl;
  TabSheet.Caption := AName;

  PPI := 96;
  if APageControl.Owner is TFormDextTestRunner then
    PPI := TFormDextTestRunner(APageControl.Owner).CurrentPPI;

  FilterPanel := TPanel.Create(TabSheet);
  FilterPanel.Parent := TabSheet;
  FilterPanel.Align := alTop;
  FilterPanel.Height := MulDiv(28, PPI, 96);
  FilterPanel.BevelOuter := bvNone;

  ClearFilterButton := TSpeedButton.Create(TabSheet);
  ClearFilterButton.Parent := FilterPanel;
  ClearFilterButton.Align := alRight;
  ClearFilterButton.Width := MulDiv(22, PPI, 96);
  ClearFilterButton.Caption := 'X';
  ClearFilterButton.Flat := True;
  ClearFilterButton.Hint := 'Clear filter';
  ClearFilterButton.ShowHint := True;
  ClearFilterButton.Visible := False;
  if APageControl.Owner is TFormDextTestRunner then
    ClearFilterButton.OnClick := TFormDextTestRunner(APageControl.Owner).ClearFilterButtonClick;

  FilterEdit := TEdit.Create(TabSheet);
  FilterEdit.Parent := FilterPanel;
  FilterEdit.Align := alClient;
  FilterEdit.AlignWithMargins := True;
  FilterEdit.Margins.Left := 0;
  FilterEdit.Margins.Right := 2;
  FilterEdit.Margins.Top := 3;
  FilterEdit.Margins.Bottom := 3;
  FilterEdit.TextHint := 'Filter tests (Ctrl+F)...';
  if APageControl.Owner is TFormDextTestRunner then
    FilterEdit.OnChange := TFormDextTestRunner(APageControl.Owner).FilterEditChange;

  TreeView := TTreeView.Create(TabSheet);
  TreeView.Parent := TabSheet;
  TreeView.Align := alClient;
  TreeView.ReadOnly := True;
  TreeView.HideSelection := False;
  TreeView.Checkboxes := True;
  TreeView.DoubleBuffered := True;
  TreeView.StyleElements := [];
end;

constructor TTestSession.CreateFromExisting(ATabSheet: TTabSheet; ATreeView: TTreeView; ALocations: TList<TTestLocation>; const AProjFile: string);
var
  PPI: Integer;
  FilterPanel: TPanel;
begin
  inherited Create;
  TabSheet := ATabSheet;
  TreeView := ATreeView;
  TestLocations := ALocations;
  ActiveProjectFile := AProjFile;

  PPI := 96;
  if ATabSheet.Owner is TFormDextTestRunner then
    PPI := TFormDextTestRunner(ATabSheet.Owner).CurrentPPI;

  FilterPanel := TPanel.Create(ATabSheet);
  FilterPanel.Parent := ATabSheet;
  FilterPanel.Align := alTop;
  FilterPanel.Height := MulDiv(28, PPI, 96);
  FilterPanel.BevelOuter := bvNone;

  ClearFilterButton := TSpeedButton.Create(ATabSheet);
  ClearFilterButton.Parent := FilterPanel;
  ClearFilterButton.Align := alRight;
  ClearFilterButton.Width := MulDiv(22, PPI, 96);
  ClearFilterButton.Caption := 'X';
  ClearFilterButton.Flat := True;
  ClearFilterButton.Hint := 'Clear filter';
  ClearFilterButton.ShowHint := True;
  ClearFilterButton.Visible := False;
  if ATabSheet.Owner is TFormDextTestRunner then
    ClearFilterButton.OnClick := TFormDextTestRunner(ATabSheet.Owner).ClearFilterButtonClick;

  FilterEdit := TEdit.Create(ATabSheet);
  FilterEdit.Parent := FilterPanel;
  FilterEdit.Align := alClient;
  FilterEdit.AlignWithMargins := True;
  FilterEdit.Margins.Left := 0;
  FilterEdit.Margins.Right := 2;
  FilterEdit.Margins.Top := 3;
  FilterEdit.Margins.Bottom := 3;
  FilterEdit.TextHint := 'Filter tests (Ctrl+F)...';
  if ATabSheet.Owner is TFormDextTestRunner then
    FilterEdit.OnChange := TFormDextTestRunner(ATabSheet.Owner).FilterEditChange;
end;

destructor TTestSession.Destroy;
begin
  if (TabSheet <> nil) and not (csDestroying in TabSheet.ComponentState) then
  begin
    TabSheet.Free;
  end;
  TestLocations.Free;
  inherited;
end;

procedure TFormDextTestRunner.RebuildStatusImages;
var
  BgColor: TColor;
  Bitmap: TBitmap;
  i: Integer;
  ImageList: TImageList;
  OldImages: TCustomImageList;

  procedure DrawSmoothCircle(AColor: TColor; ADest: TBitmap);
  var
    LargeBmp: TBitmap;
  begin
    LargeBmp := TBitmap.Create;
    try
      LargeBmp.SetSize(64, 64);
      LargeBmp.Canvas.Brush.Color := BgColor;
      LargeBmp.Canvas.FillRect(Rect(0, 0, 64, 64));

      LargeBmp.Canvas.Pen.Color := AColor;
      LargeBmp.Canvas.Brush.Color := AColor;
      LargeBmp.Canvas.Ellipse(16, 16, 48, 48);

      ADest.Canvas.Brush.Color := BgColor;
      ADest.Canvas.FillRect(Rect(0, 0, 16, 16));

      SetStretchBltMode(ADest.Canvas.Handle, HALFTONE);
      SetBrushOrgEx(ADest.Canvas.Handle, 0, 0, nil);
      StretchBlt(ADest.Canvas.Handle, 0, 0, 16, 16, LargeBmp.Canvas.Handle, 0, 0, 64, 64, SRCCOPY);
    finally
      LargeBmp.Free;
    end;
  end;

begin
  if TestsTreeView <> nil then
    BgColor := TestsTreeView.Color
  else
    BgColor := clWindow;

  ImageList := TImageList.Create(Self);
  ImageList.Width := 16;
  ImageList.Height := 16;

  Bitmap := TBitmap.Create;
  try
    Bitmap.SetSize(16, 16);

    // 0: Idle (Gray circle)
    DrawSmoothCircle(clGray, Bitmap);
    ImageList.AddMasked(Bitmap, BgColor);

    // 1: Pass (Green circle)
    DrawSmoothCircle(TColor($5EC522), Bitmap);
    ImageList.AddMasked(Bitmap, BgColor);

    // 2: Fail (Red circle)
    DrawSmoothCircle(TColor($4444EF), Bitmap);
    ImageList.AddMasked(Bitmap, BgColor);

    // 3: Fixture (Blue circle)
    DrawSmoothCircle(TColor($F6823B), Bitmap);
    ImageList.AddMasked(Bitmap, BgColor);
  finally
    Bitmap.Free;
  end;

  OldImages := TestsTreeView.Images;
  TestsTreeView.Images := ImageList;

  if Assigned(FSessions) then
  begin
    for i := 0 to FSessions.Count - 1 do
      if Assigned(FSessions[i].TreeView) then
        FSessions[i].TreeView.Images := ImageList;
  end;

  if Assigned(OldImages) then
    OldImages.Free;
end;

{ TFileScanCache }

constructor TFileScanCache.Create(ATimestamp: TDateTime; ATests: TList<TTestLocation>);
begin
  inherited Create;
  Timestamp := ATimestamp;
  Tests := ATests;
end;

destructor TFileScanCache.Destroy;
begin
  Tests.Free;
  inherited Destroy;
end;

{ TFormDextTestRunner }

constructor TFormDextTestRunner.Create(AOwner: TComponent);
var
  ThemingServices: IOTAIDEThemingServices;
  RunAllMenu: TPopupMenu;
  RunAllItem1, RunAllItem2, RunAllItem3: TMenuItem;
  PopupMenu: TPopupMenu;
  MenuItem: TMenuItem;
  DisabledMsgLabel: TLabel;
  EnableButton: TButton;
  LayoutMode: Integer;
  GroupingMode: Integer;
  IniFile: string;
  Ini: TMemIniFile;
begin
  FormDextTestRunner := Self;
  FRunningProcessHandle := 0;
  FActiveProjectNotifierIndex := -1;
  FActiveProjectForNotifier := nil;
  FStopwatch := TStopwatch.Create;
  FScanCache := TObjectDictionary<string, TFileScanCache>.Create([doOwnsValues]);
  FGroupNodes := TDictionary<string, TTreeNode>.Create;

  inherited Create(AOwner);
  Caption := 'Test Explorer' {$IFDEF DEBUG} + '(Compiled: ' + GetModuleBuildTime + ')'{$ENDIF};
  Name := 'FormDextTestRunner';
  DeskSection := 'FormDextTestRunner';
  AutoSave := True;
  SaveStateNecessary := True;

  // Set button captions with elegant symbols and hints
  RefreshButton.Caption := #$21BB + ' Refresh';
  RefreshButton.Hint := 'Scan project files and discover tests';
  RefreshButton.ShowHint := True;

  RunAllButton.Caption := #$25B6 + ' Run All';
  RunAllButton.Hint := 'Run all tests in the selected project (Click dropdown arrow for more options)';
  RunAllButton.ShowHint := True;

  RunAllMenu := TPopupMenu.Create(Self);
  RunAllItem1 := TMenuItem.Create(RunAllMenu);
  RunAllItem1.Caption := 'Run Selected Project';
  RunAllItem1.OnClick := RunAllButtonClick;
  RunAllMenu.Items.Add(RunAllItem1);

  RunAllItem2 := TMenuItem.Create(RunAllMenu);
  RunAllItem2.Caption := 'Run All Test Projects';
  RunAllItem2.OnClick := RunAllProjectsClick;
  RunAllMenu.Items.Add(RunAllItem2);

  RunAllItem3 := TMenuItem.Create(RunAllMenu);
  RunAllItem3.Caption := 'Run Failed Tests';
  RunAllItem3.OnClick := RunFailedTestsClick;
  RunAllMenu.Items.Add(RunAllItem3);

  RunAllButton.Style := bsSplitButton;
  RunAllButton.DropDownMenu := RunAllMenu;

  RunSelectedButton.Caption := #$25B6 + ' Selected';
  RunSelectedButton.Hint := 'Run checked tests only';
  RunSelectedButton.ShowHint := True;

  StopButton.Caption := #$25A0 + ' Stop';
  StopButton.Hint := 'Cancel current test execution';
  StopButton.ShowHint := True;

  RebuildStatusImages;
  TestsTreeView.Checkboxes := True;
  TestsTreeView.DoubleBuffered := True;
  TestsTreeView.StyleElements := [];

  // Assign advanced dynamic event handlers
  TestsTreeView.OnMouseMove := TestsTreeViewMouseMove;
  TestsTreeView.OnMouseLeave := TestsTreeViewMouseLeave;
  TestsTreeView.OnMouseDown := TestsTreeViewMouseDown;
  TestsTreeView.OnMouseUp := TestsTreeViewMouseUp;
  TestsTreeView.OnAdvancedCustomDrawItem := TestsTreeViewAdvancedCustomDrawItem;
  TestsTreeView.OnChange := TestsTreeViewChange;

  // Build context menu for TreeView
  PopupMenu := TPopupMenu.Create(Self);
  MenuItem := TMenuItem.Create(PopupMenu);
  MenuItem.Caption := #$25B6 + ' Run';
  MenuItem.OnClick := RunSelectedButtonClick;
  PopupMenu.Items.Add(MenuItem);

  MenuItem := TMenuItem.Create(PopupMenu);
  MenuItem.Caption := 'Debug';
  MenuItem.OnClick := DebugSelectedClick;
  PopupMenu.Items.Add(MenuItem);

  MenuItem := TMenuItem.Create(PopupMenu);
  MenuItem.Caption := '-';
  PopupMenu.Items.Add(MenuItem);

  MenuItem := TMenuItem.Create(PopupMenu);
  MenuItem.Caption := 'Expand All';
  MenuItem.OnClick := ExpandAllMenuItemClick;
  PopupMenu.Items.Add(MenuItem);

  MenuItem := TMenuItem.Create(PopupMenu);
  MenuItem.Caption := 'Collapse All';
  MenuItem.OnClick := CollapseAllMenuItemClick;
  PopupMenu.Items.Add(MenuItem);

  MenuItem := TMenuItem.Create(PopupMenu);
  MenuItem.Caption := 'Go to Source';
  MenuItem.OnClick := TestsTreeViewDblClick;
  PopupMenu.Items.Add(MenuItem);

  TestsTreeView.PopupMenu := PopupMenu;

  FTestLocations := TList<TTestLocation>.Create;
  FSessions := TObjectList<TTestSession>.Create(True);
  FActiveSession := TTestSession.CreateFromExisting(DefaultSessionTabSheet, TestsTreeView, FTestLocations, FActiveProjectFile);
  FSessions.Add(FActiveSession);

  SessionsPageControl.OnChange := SessionsPageControlChange;
  SessionsPageControl.OnContextPopup := SessionTabContextPopup;

  FServer := TTestRunnerServer.Create(8102);

  // Initialize Inspector UI dynamically
  FTestDetails := TDictionary<string, TTestDetailInfo>.Create;
  FGroupSummaries := TDictionary<string, TGroupSummaryInfo>.Create;
  FTotalTests := 0;
  FCompletedTests := 0;

  // Setup event handlers and non-design property values
  ProgressPanel.Visible := False;
  ProgressPanel.BringToFront;

  ResetSummaryLabels;

  EnableDisableTestExplorerMenuItem.OnClick := ToggleEnabledClick;
  ClearMenuItem.OnClick := ClearLogsClick;

  CustomParamsEdit.TextHint := 'e.g. --filter mytest* --verbose';
  CustomParamsEdit.OnChange := ConfigChangeHandler;

  RunOnSaveCheckBox.OnClick := ConfigChangeHandler;
  RunOnIdleCheckBox.OnClick := ConfigChangeHandler;
  EnabledCheckBox.OnClick := ToggleEnabledClick;

  ExportToJUnitXmlMenutem.OnClick := ExportMenuClick;
  ExportToXUnitXMLMenutem.OnClick := ExportMenuClick;
  ExportToJsonMenutem.OnClick := ExportMenuClick;
  ExportToSonarQubeXmlMenutem.OnClick := ExportMenuClick;
  ExportToHtmlReportMenuItem.OnClick := ExportMenuClick;

  if Supports(BorlandIDEServices, IOTAIDEThemingServices, ThemingServices) then
  begin
    if ThemingServices.IDEThemingEnabled then
      ThemingServices.ApplyTheme(Self);
  end;

  // Reposition layout & session buttons
  RefreshButton.Left   := 2;
  RefreshButton.Top    := 5;
  RefreshButton.Width  := 75;
  RefreshButton.Height := 25;

  RunAllButton.Left   := 80;
  RunAllButton.Top    := 5;
  RunAllButton.Width  := 85;
  RunAllButton.Height := 25;

  RunSelectedButton.Left   := 168;
  RunSelectedButton.Top    := 5;
  RunSelectedButton.Width  := 75;
  RunSelectedButton.Height := 25;

  StopButton.Left   := 246;
  StopButton.Top    := 5;
  StopButton.Width  := 50;
  StopButton.Height := 25;

  CreateaNewSessionMenuItem.OnClick := AddSessionButtonClick;

  TabbedLayoutMenuItem.Tag := Ord(telCompact);
  TabbedLayoutMenuItem.OnClick := LayoutMenuClick;
  TabbedLayoutMenuItem.Checked := True;
  SplitBottomLayoutMenuItem.Tag := Ord(telSplitBottom);
  SplitBottomLayoutMenuItem.OnClick := LayoutMenuClick;
  SplitBottomLayoutMenuItem.Checked := True;
  SplitRightLayoutMenuItem.Tag := Ord(telSplitRight);
  SplitRightLayoutMenuItem.OnClick := LayoutMenuClick;
  SplitRightLayoutMenuItem.Checked := True;

  GroupByClassMenuItem.Tag := 100 + Ord(tgmCodeStructure);
  GroupByClassMenuItem.OnClick := GroupingMenuClick;
  GroupByClassMenuItem.Checked := True;
  GroupbyTestStatusMenuItem.Tag := 100 + Ord(tgmStatus);
  GroupbyTestStatusMenuItem.OnClick := GroupingMenuClick;
  GroupbyTestStatusMenuItem.Checked := False;

  FInspectorSplitter := TSplitter.Create(Self);
  FInspectorSplitter.Parent := DetailsPanel;
  FInspectorSplitter.Visible := False;
  FCurrentLayout := telCompact;

  // Disabled overlay banner/panel
  FDisabledPanel := TPanel.Create(Self);
  FDisabledPanel.Parent := Self;
  FDisabledPanel.Align := alClient;
  FDisabledPanel.BevelOuter := bvNone;
  FDisabledPanel.Visible := False;
  FDisabledPanel.Color := clWindow;
  FDisabledPanel.ParentBackground := False;

  FDisabledContainer := TPanel.Create(Self);
  FDisabledContainer.Parent := FDisabledPanel;
  FDisabledContainer.Width := 300;
  FDisabledContainer.Height := 100;
  FDisabledContainer.BevelOuter := bvNone;
  FDisabledContainer.ParentBackground := True;

  DisabledMsgLabel := TLabel.Create(Self);
  DisabledMsgLabel.Parent := FDisabledContainer;
  DisabledMsgLabel.Align := alTop;
  DisabledMsgLabel.Alignment := taCenter;
  DisabledMsgLabel.Caption := 'Dext Test Explorer is currently disabled.' + #13#10 + 'Enable it to load projects and run tests.';
  DisabledMsgLabel.Font.Size := 10;
  DisabledMsgLabel.Height := 40;

  EnableButton := TButton.Create(Self);
  EnableButton.Parent := FDisabledContainer;
  EnableButton.Left := (FDisabledContainer.Width - 120) div 2;
  EnableButton.Top := 50;
  EnableButton.Width := 120;
  EnableButton.Height := 30;
  EnableButton.Caption := 'Enable';
  EnableButton.OnClick := EnableBtnClick;
  EnableDisableTestExplorerMenuItem.OnClick := ToggleEnabledClick;
  EnableDisableTestExplorerMenuItem.Visible := True;

  // Initialize Idle Timer
  FIdleTimer := TTimer.Create(Self);
  FIdleTimer.Interval := 2500; // 2.5 seconds debounce
  FIdleTimer.Enabled := False;
  FIdleTimer.OnTimer := IdleTimerTimer;

  // Initialize Save Timer and list
  FSaveTimer := TTimer.Create(Self);
  FSaveTimer.Interval := 250; // 250ms debounce
  FSaveTimer.Enabled := False;
  FSaveTimer.OnTimer := SaveTimerTimer;

  FPendingSaveFiles := TStringList.Create;
  FPendingSaveFiles.Sorted := True;
  FPendingSaveFiles.Duplicates := dupIgnore;

  // Load layout and configs from ini file
  LayoutMode := Ord(telCompact);
  GroupingMode := Ord(tgmCodeStructure);
  IniFile := TPath.Combine(TPath.GetHomePath, 'DextTestExplorer.ini');
  try
    Ini := TMemIniFile.Create(IniFile);
    try
      FEnabled := Ini.ReadBool('General', 'Enabled', True);
      LayoutMode := Ini.ReadInteger('Layout', 'Mode', Ord(telCompact));
      GroupingMode := Ini.ReadInteger('Grouping', 'Mode', Ord(tgmCodeStructure));
      CustomParamsEdit.Text := Ini.ReadString('General', 'CustomParams', '');
      RunOnSaveCheckBox.Checked := Ini.ReadBool('General', 'RunOnSave', False);
      RunOnIdleCheckBox.Checked := Ini.ReadBool('General', 'RunOnIdle', False);
    finally
      Ini.Free;
    end;
  except
    FEnabled := True;
  end;

  SetEnabledState(FEnabled);
  ApplyLayout(TTestExplorerLayout(LayoutMode));
  FGroupingMode := TTestGroupingMode(GroupingMode);
  FIdleTimer.Enabled := RunOnIdleCheckBox.Checked;

  // Sync menu Checked states based on loaded configurations
  TabbedLayoutMenuItem.Checked := TTestExplorerLayout(LayoutMode) = telCompact;
  SplitBottomLayoutMenuItem.Checked := TTestExplorerLayout(LayoutMode) = telSplitBottom;
  SplitRightLayoutMenuItem.Checked := TTestExplorerLayout(LayoutMode) = telSplitRight;

  GroupByClassMenuItem.Checked := TTestGroupingMode(GroupingMode) = tgmCodeStructure;
  GroupByTestStatusMenuItem.Checked := TTestGroupingMode(GroupingMode) = tgmStatus;

  Self.KeyPreview := True;
  Self.OnKeyDown := FormKeyDown;

  FThemeNotifierIndex := -1;
  ApplyIDETheme;

  if Supports(BorlandIDEServices, IOTAIDEThemingServices, ThemingServices) then
  begin
    FThemeNotifierIndex := ThemingServices.AddNotifier(TDextThemeNotifier.Create(Self) as INTAIDEThemingServicesNotifier);
  end;

  if FEnabled then
  begin
    RefreshProjects;
  end;
  UpdateTabVisibility;
  FServer.Start(OnTestResultReceived);
end;

destructor TFormDextTestRunner.Destroy;
var
  LThemingServices: IOTAIDEThemingServices;
  I: Integer;
begin
  if (FActiveProjectNotifierIndex <> -1) and Assigned(FActiveProjectForNotifier) then
  begin
    try
      FActiveProjectForNotifier.RemoveNotifier(FActiveProjectNotifierIndex);
    except
    end;
    FActiveProjectNotifierIndex := -1;
    FActiveProjectForNotifier := nil;
  end;

  if FRunningProcessHandle <> 0 then
  begin
    TerminateProcess(FRunningProcessHandle, 0);
    CloseHandle(FRunningProcessHandle);
    FRunningProcessHandle := 0;
  end;

  if Supports(BorlandIDEServices, IOTAIDEThemingServices, LThemingServices) and (FThemeNotifierIndex <> -1) then
  begin
    LThemingServices.RemoveNotifier(FThemeNotifierIndex);
    FThemeNotifierIndex := -1;
  end;

  FServer.Stop;
  FServer.Free;
  FSessions.Free;
  FTestDetails.Free;
  FGroupSummaries.Free;
  FGroupNodes.Free;

  if Assigned(FIdleTimer) then
    FIdleTimer.Free;
  if Assigned(FSaveTimer) then
    FSaveTimer.Free;
  if Assigned(FPendingSaveFiles) then
    FPendingSaveFiles.Free;
  if Assigned(FScanCache) then
    FScanCache.Free;

  if Assigned(ProjectsComboBox) then
  begin
    for I := 0 to ProjectsComboBox.Items.Count - 1 do
      ProjectsComboBox.Items.Objects[I].Free;
  end;

  if FormDextTestRunner = Self then
    FormDextTestRunner := nil;
  inherited Destroy;
end;

procedure TFormDextTestRunner.ApplyDpiScaling;
var
  LPPI: Integer;
  Idx: Integer;
  Session: TTestSession;
begin
  LPPI := Self.CurrentPPI;
  if LPPI = 0 then
    LPPI := 96;

  ButtonsPanel.Height := MulDiv(31, LPPI, 96);
  
  RefreshButton.Height := MulDiv(25, LPPI, 96);
  RefreshButton.Width := MulDiv(90, LPPI, 96);
  
  RunAllButton.Height := MulDiv(25, LPPI, 96);
  RunAllButton.Width := MulDiv(95, LPPI, 96);
  
  RunSelectedButton.Height := MulDiv(25, LPPI, 96);
  RunSelectedButton.Width := MulDiv(95, LPPI, 96);
  
  StopButton.Height := MulDiv(25, LPPI, 96);
  StopButton.Width := MulDiv(65, LPPI, 96);
  
  ActionsButton.Height := MulDiv(25, LPPI, 96);
  ActionsButton.Width := MulDiv(30, LPPI, 96);

  if Assigned(FSessions) then
  begin
    for Idx := 0 to FSessions.Count - 1 do
    begin
      Session := FSessions[Idx];
      if Assigned(Session.FilterEdit) and Assigned(Session.FilterEdit.Parent) then
        TPanel(Session.FilterEdit.Parent).Height := MulDiv(28, LPPI, 96);
      if Assigned(Session.ClearFilterButton) then
        Session.ClearFilterButton.Width := MulDiv(22, LPPI, 96);
    end;
  end;
end;

procedure TFormDextTestRunner.DoShow;
begin
  inherited DoShow;
  ApplyDpiScaling;
  ApplyIDETheme;
end;

function TFormDextTestRunner.GetProjectByFileName(const AFileName: string): IOTAProject;
var
  LModuleServices: IOTAModuleServices;
  LGroup: IOTAProjectGroup;
  I: Integer;
begin
  Result := nil;
  if not Supports(BorlandIDEServices, IOTAModuleServices, LModuleServices) then
    Exit;
  LGroup := LModuleServices.MainProjectGroup;
  if Assigned(LGroup) then
  begin
    for I := 0 to LGroup.ProjectCount - 1 do
    begin
      if Assigned(LGroup.Projects[I]) and SameText(LGroup.Projects[I].FileName, AFileName) then
      begin
        Result := LGroup.Projects[I];
        Exit;
      end;
    end;
  end;
end;

procedure TFormDextTestRunner.RefreshActiveProjectTestsList;
var
  CacheDict: TObjectDictionary<string, TFileScanCache>;
  FileName: string;
  Files: TArray<string>;
  FilesToScan: TList<string>;
  FilesToScanArray: TArray<string>;
  Generation: Integer;
  i: Integer;
  ModifiedTimes: TArray<TDateTime>;
  Project: IOTAProject;
  LStopwatch: TStopwatch;
  Cache: TFileScanCache;
  FileTime: TDateTime;
  Tests: TList<TTestLocation>;
begin
  if not FEnabled then Exit;
  LStopwatch := TStopwatch.StartNew;
  LogPerformance('RefreshActiveProjectTestsList: begin');
  Project := GetProjectByFileName(FActiveProjectFile);
  if not Assigned(Project) then
  begin
    TestsTreeView.Items.BeginUpdate;
    try
      TestsTreeView.Items.Clear;
      FTestLocations.Clear;
      ResetSummaryLabels;
    finally
      TestsTreeView.Items.EndUpdate;
    end;
    LogPerformance(Format('RefreshActiveProjectTestsList: no project %.2f ms', [LStopwatch.Elapsed.TotalMilliseconds]));
    Exit;
  end;

  SetLength(Files, Project.GetModuleCount);
  for i := 0 to Project.GetModuleCount - 1 do
    Files[i] := Project.GetModule(i).FileName;

  TestsTreeView.Items.BeginUpdate;
  try
    TestsTreeView.Items.Clear;
    FTestLocations.Clear;
    TestsTreeView.Items.AddChild(nil, 'Loading tests asynchronously...');
  finally
    TestsTreeView.Items.EndUpdate;
  end;

  Inc(FScanGeneration);
  Generation := FScanGeneration;

  // Query modified times and determine what needs to be scanned
  CacheDict := TObjectDictionary<string, TFileScanCache>(FScanCache);
  FilesToScan := TList<string>.Create;
  try
    for FileName in Files do
    begin
      if SameText(ExtractFileExt(FileName), '.pas') and FileExists(FileName) then
      begin
        Cache := nil;
        FileTime := TFile.GetLastWriteTime(FileName);
        if CacheDict.TryGetValue(FileName, Cache) then
        begin
          if Cache.Timestamp <> FileTime then
            FilesToScan.Add(FileName);
        end
        else
          FilesToScan.Add(FileName);
      end;
    end;
    FilesToScanArray := FilesToScan.ToArray;
  finally
    FilesToScan.Free;
  end;

  SetLength(ModifiedTimes, Length(FilesToScanArray));
  for i := 0 to Length(FilesToScanArray) - 1 do
    ModifiedTimes[i] := TFile.GetLastWriteTime(FilesToScanArray[i]);

  TTask.Run(TProc(procedure
    var
      LScannedLists: TArray<TList<TTestLocation>>;
      i: Integer;
    begin
      SetLength(LScannedLists, Length(FilesToScanArray));
      LogPerformance(Format('RefreshActiveProjectTestsList: scan start (%d files)', [Length(FilesToScanArray)]));

      for i := 0 to Length(FilesToScanArray) - 1 do
      begin
        Tests := nil;
        if TTestASTScanner.ScanFile(FilesToScanArray[i], Tests) then
          LScannedLists[i] := Tests
        else
          LScannedLists[i] := nil;
      end;
      LogPerformance('RefreshActiveProjectTestsList: scan end');

      TThread.Queue(nil, TThreadProcedure(procedure
        var
          FileName: string;
          i: Integer;
          TestLoc: TTestLocation;
          UiStopwatch: TStopwatch;
        begin
          UiStopwatch := TStopwatch.StartNew;
          if Generation <> FScanGeneration then
          begin
            for i := 0 to Length(LScannedLists) - 1 do
              if Assigned(LScannedLists[i]) then
                LScannedLists[i].Free;
            Exit;
          end;

          for i := 0 to Length(FilesToScanArray) - 1 do
          begin
            FileName := FilesToScanArray[i];
            Tests := LScannedLists[i];
            if Tests = nil then
              Tests := TList<TTestLocation>.Create;
            CacheDict.AddOrSetValue(FileName, TFileScanCache.Create(ModifiedTimes[i], Tests));
          end;

          TestsTreeView.Items.BeginUpdate;
          try
            TestsTreeView.Items.Clear;
            FTestLocations.Clear;

            for FileName in Files do
            begin
              Cache := nil;
              if CacheDict.TryGetValue(FileName, Cache) then
              begin
                for TestLoc in Cache.Tests do
                  FTestLocations.Add(TestLoc);
              end;
            end;

            RefreshTreeView;
          finally
            TestsTreeView.Items.EndUpdate;
          end;
          TThread.ForceQueue(nil, TThreadProcedure(procedure
            begin
              ExpandTestsTreeView;
            end));
          LogPerformance(Format('RefreshActiveProjectTestsList: ui rebuild %.2f ms, total %.2f ms', [UiStopwatch.Elapsed.TotalMilliseconds, LStopwatch.Elapsed.TotalMilliseconds]));
        end));
    end));
end;

procedure TFormDextTestRunner.ApplyIDETheme;
var
  ThemingServices: IOTAIDEThemingServices;
  BgColor, FgColor: TColor;
  Idx: Integer;
  Session: TTestSession;
begin
  if Supports(BorlandIDEServices, IOTAIDEThemingServices, ThemingServices) then
  begin
    if ThemingServices.IDEThemingEnabled then
    begin
      BgColor := ThemingServices.StyleServices.GetSystemColor(clWindow);
      FgColor := ThemingServices.StyleServices.GetSystemColor(clWindowText);

      // 1. Update the active TestsTreeView
      if Assigned(TestsTreeView) then
      begin
        TestsTreeView.Color := BgColor;
        TestsTreeView.Font.Color := FgColor;
        TestsTreeView.Font.Size := 9;
        TestsTreeView.Invalidate;
      end;

      // 2. Loop through all sessions to update all TreeViews
      if Assigned(FSessions) then
      begin
        for Idx := 0 to FSessions.Count - 1 do
        begin
          Session := FSessions[Idx];
          if Assigned(Session.TreeView) then
          begin
            Session.TreeView.Color := BgColor;
            Session.TreeView.Font.Color := FgColor;
            Session.TreeView.Font.Size := 9;
            Session.TreeView.Invalidate;
          end;
        end;
      end;

      // 3. Details Memo
      if Assigned(DetailsMemo) then
      begin
        DetailsMemo.Color := BgColor;
        DetailsMemo.Font.Color := FgColor;
      end;

      // 4. Test Inspector (Scrollbox & Labels)
      if Assigned(InspectorScroll) then
      begin
        InspectorScroll.ParentColor := False;
        InspectorScroll.Color := BgColor;
      end;

      if Assigned(TestNameLabel) then TestNameLabel.Font.Color := FgColor;
      if Assigned(StatusLabel) then
      begin
        if (not string(StatusLabel.Caption).Contains('Passed')) and (not string(StatusLabel.Caption).Contains('Failed')) then
          StatusLabel.Font.Color := FgColor;
      end;
      if Assigned(LocationLabel) then LocationLabel.Font.Color := FgColor;
      if Assigned(DurationLabel) then DurationLabel.Font.Color := FgColor;
      if Assigned(ErrorHeaderLabel) then ErrorHeaderLabel.Font.Color := FgColor;

      if Assigned(ErrorMemo) then
      begin
        ErrorMemo.Color := BgColor;
        ErrorMemo.Font.Color := FgColor;
      end;

      if Assigned(SummaryTotalLabel) then SummaryTotalLabel.Font.Color := FgColor;
      if Assigned(SummarySelectedLabel) then SummarySelectedLabel.Font.Color := FgColor;
      if Assigned(SummaryTimeLabel) then SummaryTimeLabel.Font.Color := FgColor;

      // 5. Form background color
      Self.Color := ThemingServices.StyleServices.GetSystemColor(clBtnFace);

      RebuildStatusImages;
    end;
  end;
end;

procedure TFormDextTestRunner.CMStyleChanged(var Message: TMessage);
begin
  inherited;
  TThread.ForceQueue(nil, TThreadProcedure(procedure
    begin
      ApplyIDETheme;
    end));
end;

procedure TFormDextTestRunner.Resize;
begin
  inherited;
  if Assigned(FDisabledContainer) and Assigned(FDisabledPanel) then
  begin
    FDisabledContainer.Left := (FDisabledPanel.ClientWidth - FDisabledContainer.Width) div 2;
    FDisabledContainer.Top := (FDisabledPanel.ClientHeight - FDisabledContainer.Height) div 2;
  end;
end;

procedure TFormDextTestRunner.SetEnabledState(AValue: Boolean);
var
  Handler: TNotifyEvent;
begin
  FEnabled := AValue;
  FDisabledPanel.Visible := not AValue;

  if Assigned(EnabledCheckBox) then
  begin
    Handler := EnabledCheckBox.OnClick;
    EnabledCheckBox.OnClick := nil;
    try
      EnabledCheckBox.Checked := AValue;
    finally
      EnabledCheckBox.OnClick := Handler;
    end;
  end;

  ProjectsComboBox.Enabled := AValue;
  ButtonsPanel.Enabled := AValue;
  SessionsPageControl.Enabled := AValue;
  DetailsPanel.Enabled := AValue;

  if AValue then
  begin
    if ProjectsComboBox.Items.Count = 0 then
      RefreshProjects
    else if FActiveProjectFile <> '' then
      RefreshActiveProjectTestsList;
  end
  else
  begin
    TestsTreeView.Items.Clear;
    FTestLocations.Clear;
  end;

  if Assigned(EnableDisableTestExplorerMenuItem) then
  begin
    if AValue then
      EnableDisableTestExplorerMenuItem.Caption := 'Disable Test Explorer'
    else
      EnableDisableTestExplorerMenuItem.Caption := 'Enable Test Explorer';
  end;
end;

procedure TFormDextTestRunner.ToggleEnabledClick(Sender: TObject);
var
  IniFile: TMemIniFile;
begin
  SetEnabledState(not FEnabled);
  IniFile := TMemIniFile.Create(TPath.Combine(TPath.GetHomePath, 'DextTestExplorer.ini'));
  try
    IniFile.WriteBool('General', 'Enabled', FEnabled);
    IniFile.UpdateFile;
  finally
    IniFile.Free;
  end;
end;

procedure TFormDextTestRunner.EnableBtnClick(Sender: TObject);
var
  IniFile : TMemIniFile;
begin
  SetEnabledState(True);
  IniFile := TMemIniFile.Create(TPath.Combine(TPath.GetHomePath, 'DextTestExplorer.ini'));
  try
    IniFile.WriteBool('General', 'Enabled', True);
    IniFile.UpdateFile;
  finally
    IniFile.Free;
  end;
end;

procedure TFormDextTestRunner.ClearLogsClick(Sender: TObject);
begin
  DetailsMemo.Clear;
  ClearTestStatus;
  ResetSummaryLabels;
end;

procedure TFormDextTestRunner.RunFailedTestsClick(Sender: TObject);
var
  FailedTests: TList<string>;
  Key: string;
  Info: TTestDetailInfo;
begin
  FailedTests := TList<string>.Create;
  try
    for Key in FTestDetails.Keys do
    begin
      Info := FTestDetails[Key];
      if SameText(Info.Status, 'Failed') or SameText(Info.Status, 'Error') then
      begin
        FailedTests.Add(Key);
      end;
    end;

    if FailedTests.Count > 0 then
    begin
      LogMsg(Format('Running %d failed tests...', [FailedTests.Count]));
      RunImpactedTests(FailedTests.ToArray);
    end
    else
    begin
      LogMsg('No failed tests to run.');
    end;
  finally
    FailedTests.Free;
  end;
end;

procedure TFormDextTestRunner.ExportMenuClick(Sender: TObject);
var
  DefaultExtension: string;
  ExportFormat: string;
  Filter: string;
  SaveDialog: TSaveDialog;
  Text: string;
begin
  if not (Sender is TMenuItem) then Exit;
  Text := TMenuItem(Sender).Caption;

  if Text = 'Export to JUnit XML' then
  begin
    ExportFormat := 'junit';
    DefaultExtension := 'xml';
    Filter := 'XML Files (*.xml)|*.xml';
  end
  else if Text = 'Export to XUnit XML' then
  begin
    ExportFormat := 'xunit';
    DefaultExtension := 'xml';
    Filter := 'XML Files (*.xml)|*.xml';
  end
  else if Text = 'Export to JSON' then
  begin
    ExportFormat := 'json';
    DefaultExtension := 'json';
    Filter := 'JSON Files (*.json)|*.json';
  end
  else if Text = 'Export to SonarQube XML' then
  begin
    ExportFormat := 'sonar';
    DefaultExtension := 'xml';
    Filter := 'XML Files (*.xml)|*.xml';
  end
  else if Text = 'Export to HTML Report' then
  begin
    ExportFormat := 'html';
    DefaultExtension := 'html';
    Filter := 'HTML Files (*.html)|*.html';
  end
  else
    Exit;

  SaveDialog := TSaveDialog.Create(Self);
  try
    SaveDialog.DefaultExt := DefaultExtension;
    SaveDialog.Filter := Filter;
    SaveDialog.Title := 'Export Test Report';
    if SaveDialog.Execute then
    begin
      ExportResults(ExportFormat, SaveDialog.FileName);
    end;
  finally
    SaveDialog.Free;
  end;
end;

procedure TFormDextTestRunner.ExportResults(const ExportFormat, FileName: string);
var
  HTMLReporter: THTMLReporter;
  JsonReporter: TJsonReporter;
  JUnitReporter: TJUnitReporter;
  SonarReporter: TSonarQubeReporter;
  SuiteName: string;
  TestDetailInfo: TTestDetailInfo;
  TestInfo: Dext.Testing.Integration.TTestInfo;
  XUnitReporter: TXUnitReporter;
  Key: string;
  Parts: TArray<string>;
begin
  SuiteName := ExtractFileName(ChangeFileExt(FActiveProjectFile, ''));
  if SuiteName = '' then SuiteName := 'DextTests';

  if SameText(ExportFormat, 'junit') then
  begin
    JUnitReporter := TJUnitReporter.Create;
    try
      JUnitReporter.BeginSuite(SuiteName);
      for Key in FTestDetails.Keys do
      begin
        TestDetailInfo := FTestDetails[Key];
        FillChar(TestInfo, SizeOf(TestInfo), 0);
        Parts := TestDetailInfo.TestName.Split(['.']);
        if Length(Parts) >= 2 then
        begin
          TestInfo.FixtureName := Parts[0];
          TestInfo.TestName := Parts[1];
        end
        else
        begin
          TestInfo.FixtureName := 'Default';
          TestInfo.TestName := TestDetailInfo.TestName;
        end;
        TestInfo.DisplayName := TestDetailInfo.TestName;
        if SameText(TestDetailInfo.Status, 'Passed') then TestInfo.Result := TTestResult.trPassed
        else if SameText(TestDetailInfo.Status, 'Failed') or SameText(TestDetailInfo.Status, 'Error') then TestInfo.Result := TTestResult.trFailed
        else if SameText(TestDetailInfo.Status, 'Skipped') then TestInfo.Result := TTestResult.trSkipped
        else TestInfo.Result := TTestResult.trNone;
        TestInfo.Duration := TTimeSpan.FromMilliseconds(TestDetailInfo.DurationMs);
        TestInfo.ErrorMessage := TestDetailInfo.ErrorMessage;
        TestInfo.StackTrace := TestDetailInfo.StackTrace;
        JUnitReporter.AddTestCase(TestInfo);
      end;
      JUnitReporter.EndSuite;
      JUnitReporter.SaveToFile(FileName);
      LogMsg('Results exported to JUnit format: ' + FileName);
    finally
      JUnitReporter.Free;
    end;
  end
  else if SameText(ExportFormat, 'xunit') then
  begin
    XUnitReporter := TXUnitReporter.Create;
    try
      XUnitReporter.BeginSuite(SuiteName);
      for Key in FTestDetails.Keys do
      begin
        TestDetailInfo := FTestDetails[Key];
        FillChar(TestInfo, SizeOf(TestInfo), 0);
        Parts := TestDetailInfo.TestName.Split(['.']);
        if Length(Parts) >= 2 then
        begin
          TestInfo.FixtureName := Parts[0];
          TestInfo.TestName := Parts[1];
        end
        else
        begin
          TestInfo.FixtureName := 'Default';
          TestInfo.TestName := TestDetailInfo.TestName;
        end;
        TestInfo.DisplayName := TestDetailInfo.TestName;
        if SameText(TestDetailInfo.Status, 'Passed') then TestInfo.Result := TTestResult.trPassed
        else if SameText(TestDetailInfo.Status, 'Failed') or SameText(TestDetailInfo.Status, 'Error') then TestInfo.Result := TTestResult.trFailed
        else if SameText(TestDetailInfo.Status, 'Skipped') then TestInfo.Result := TTestResult.trSkipped
        else TestInfo.Result := TTestResult.trNone;
        TestInfo.Duration := TTimeSpan.FromMilliseconds(TestDetailInfo.DurationMs);
        TestInfo.ErrorMessage := TestDetailInfo.ErrorMessage;
        TestInfo.StackTrace := TestDetailInfo.StackTrace;
        XUnitReporter.AddTestCase(TestInfo);
      end;
      XUnitReporter.EndSuite;
      XUnitReporter.SaveToFile(FileName);
      LogMsg('Results exported to XUnit format: ' + FileName);
    finally
      XUnitReporter.Free;
    end;
  end;
  if SameText(ExportFormat, 'json') then
  begin
    JsonReporter := TJsonReporter.Create;
    try
      JsonReporter.BeginSuite(SuiteName);
      for Key in FTestDetails.Keys do
      begin
        TestDetailInfo := FTestDetails[Key];
        FillChar(TestInfo, SizeOf(TestInfo), 0);
        Parts := TestDetailInfo.TestName.Split(['.']);
        if Length(Parts) >= 2 then
        begin
          TestInfo.FixtureName := Parts[0];
          TestInfo.TestName := Parts[1];
        end
        else
        begin
          TestInfo.FixtureName := 'Default';
          TestInfo.TestName := TestDetailInfo.TestName;
        end;
        TestInfo.DisplayName := TestDetailInfo.TestName;
        if SameText(TestDetailInfo.Status, 'Passed') then TestInfo.Result := TTestResult.trPassed
        else if SameText(TestDetailInfo.Status, 'Failed') or SameText(TestDetailInfo.Status, 'Error') then TestInfo.Result := TTestResult.trFailed
        else if SameText(TestDetailInfo.Status, 'Skipped') then TestInfo.Result := TTestResult.trSkipped
        else TestInfo.Result := TTestResult.trNone;
        TestInfo.Duration := TTimeSpan.FromMilliseconds(TestDetailInfo.DurationMs);
        TestInfo.ErrorMessage := TestDetailInfo.ErrorMessage;
        TestInfo.StackTrace := TestDetailInfo.StackTrace;
        JsonReporter.AddTestCase(TestInfo);
      end;
      JsonReporter.EndSuite;
      JsonReporter.SaveToFile(FileName);
      LogMsg('Results exported to JSON format: ' + FileName);
    finally
      JsonReporter.Free;
    end;
  end
  else if SameText(ExportFormat, 'sonar') then
  begin
    SonarReporter := TSonarQubeReporter.Create;
    try
      for Key in FTestDetails.Keys do
      begin
        TestDetailInfo := FTestDetails[Key];
        FillChar(TestInfo, SizeOf(TestInfo), 0);
        Parts := TestDetailInfo.TestName.Split(['.']);
        if Length(Parts) >= 2 then
        begin
          TestInfo.FixtureName := Parts[0];
          TestInfo.TestName := Parts[1];
        end
        else
        begin
          TestInfo.FixtureName := 'Default';
          TestInfo.TestName := TestDetailInfo.TestName;
        end;
        TestInfo.DisplayName := TestDetailInfo.TestName;
        if SameText(TestDetailInfo.Status, 'Passed') then TestInfo.Result := trPassed
        else if SameText(TestDetailInfo.Status, 'Failed') or SameText(TestDetailInfo.Status, 'Error') then TestInfo.Result := trFailed
        else if SameText(TestDetailInfo.Status, 'Skipped') then TestInfo.Result := trSkipped
        else TestInfo.Result := trNone;
        TestInfo.Duration := TTimeSpan.FromMilliseconds(TestDetailInfo.DurationMs);
        TestInfo.ErrorMessage := TestDetailInfo.ErrorMessage;
        TestInfo.StackTrace := TestDetailInfo.StackTrace;
        SonarReporter.AddTestCase(TestInfo);
      end;
      SonarReporter.SaveToFile(FileName);
      LogMsg('Results exported to SonarQube format: ' + FileName);
    finally
      SonarReporter.Free;
    end;
  end
  else if SameText(ExportFormat, 'html') then
  begin
    HTMLReporter := THTMLReporter.Create;
    try
      HTMLReporter.SetTitle(SuiteName);
      HTMLReporter.BeginSuite(SuiteName);
      for Key in FTestDetails.Keys do
      begin
        TestDetailInfo := FTestDetails[Key];
        FillChar(TestInfo, SizeOf(TestInfo), 0);
        Parts := TestDetailInfo.TestName.Split(['.']);
        if Length(Parts) >= 2 then
        begin
          TestInfo.FixtureName := Parts[0];
          TestInfo.TestName := Parts[1];
        end
        else
        begin
          TestInfo.FixtureName := 'Default';
          TestInfo.TestName := TestDetailInfo.TestName;
        end;
        TestInfo.DisplayName := TestDetailInfo.TestName;
        if SameText(TestDetailInfo.Status, 'Passed') then TestInfo.Result := TTestResult.trPassed
        else if SameText(TestDetailInfo.Status, 'Failed') or SameText(TestDetailInfo.Status, 'Error') then TestInfo.Result := TTestResult.trFailed
        else if SameText(TestDetailInfo.Status, 'Skipped') then TestInfo.Result := TTestResult.trSkipped
        else TestInfo.Result := TTestResult.trNone;
        TestInfo.Duration := TTimeSpan.FromMilliseconds(TestDetailInfo.DurationMs);
        TestInfo.ErrorMessage := TestDetailInfo.ErrorMessage;
        TestInfo.StackTrace := TestDetailInfo.StackTrace;
        HTMLReporter.AddTestCase(TestInfo);
      end;
      HTMLReporter.EndSuite;
      HTMLReporter.SaveToFile(FileName);
      LogMsg('Results exported to HTML format: ' + FileName);
    finally
      HTMLReporter.Free;
    end;
  end;
end;

procedure TFormDextTestRunner.IdleTimerTimer(Sender: TObject);
begin
  FIdleTimer.Enabled := False;
  if FEnabled and RunOnIdleCheckBox.Checked and (FActiveProjectFile <> '') then
  begin
    LogMsg('Idle auto-run triggered.');
    RunActiveProjectTests;
  end;
end;

procedure TFormDextTestRunner.ConfigChangeHandler(Sender: TObject);
var
  Ini: TMemIniFile;
begin
  Ini := TMemIniFile.Create(TPath.Combine(TPath.GetHomePath, 'DextTestExplorer.ini'));
  try
    Ini.WriteString('General', 'CustomParams', CustomParamsEdit.Text);
    Ini.WriteBool('General', 'RunOnSave', RunOnSaveCheckBox.Checked);
    Ini.WriteBool('General', 'RunOnIdle', RunOnIdleCheckBox.Checked);
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;

  if Assigned(FIdleTimer) then
    FIdleTimer.Enabled := RunOnIdleCheckBox.Checked;
end;

function GetProjectTargetInfo(const ADprojPath: string; out AIsPackage: Boolean; out AExeOutput: string; const APlatform: string = 'Win32'; const AConfig: string = 'Debug'): Boolean;
var
  LContent: string;
  LMainSourceStart, LMainSourceEnd: Integer;
  LMainSource: string;
  LExeOutStart, LExeOutEnd: Integer;
  LPlatformTag: string;
  LPlatformGroupStart, LPlatformGroupEnd: Integer;
  LPlatformGroup: string;
  LOutStart, LOutEnd: Integer;
  LBaseGroupStart, LBaseGroupEnd: Integer;
  LBaseGroup: string;
begin
  Result := False;
  AIsPackage := False;
  AExeOutput := '';
  if not FileExists(ADprojPath) then Exit;

  try
    LContent := TFile.ReadAllText(ADprojPath);

    // Check MainSource
    LMainSourceStart := LContent.IndexOf('<MainSource>');
    if LMainSourceStart >= 0 then
    begin
      Inc(LMainSourceStart, Length('<MainSource>'));
      LMainSourceEnd := LContent.IndexOf('</MainSource>', LMainSourceStart);
      if LMainSourceEnd > LMainSourceStart then
      begin
        LMainSource := LContent.Substring(LMainSourceStart, LMainSourceEnd - LMainSourceStart).Trim;
        if LMainSource.EndsWith('.dpk', True) then
          AIsPackage := True;
      end;
    end;

    // Check ProjectType
    if not AIsPackage then
    begin
      if LContent.Contains('<Borland.ProjectType>Package</Borland.ProjectType>') then
        AIsPackage := True;
    end;

    // 1. Try platform-specific base property group, e.g., Base_Win32
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
              AExeOutput := LPlatformGroup.Substring(LOutStart, LOutEnd - LOutStart).Trim;
          end;
        end;
      end;
    end;

    // 2. Try base configurations
    if AExeOutput = '' then
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
                AExeOutput := LBaseGroup.Substring(LOutStart, LOutEnd - LOutStart).Trim;
            end;
          end;
        end;
      end;
    end;

    // 3. Fallback to last occurrence
    if AExeOutput = '' then
    begin
      LExeOutStart := LContent.LastIndexOf('<DCC_ExeOutput>');
      if LExeOutStart >= 0 then
      begin
        Inc(LExeOutStart, Length('<DCC_ExeOutput>'));
        LExeOutEnd := LContent.IndexOf('</DCC_ExeOutput>', LExeOutStart);
        if LExeOutEnd > LExeOutStart then
          AExeOutput := LContent.Substring(LExeOutStart, LExeOutEnd - LExeOutStart).Trim;
      end;
    end;

    Result := True;
  except
    // ignore
  end;
end;

function ResolveExePath(const ADprojPath, AExeOutput: string; const APlatform: string = 'Win32'; const AConfig: string = 'Debug'): string;
var
  LProjectDir: string;
  LOutputDir: string;
  LProjectName: string;
begin
  LProjectDir := ExtractFilePath(ADprojPath);
  LProjectName := ChangeFileExt(ExtractFileName(ADprojPath), '');

  if AExeOutput <> '' then
  begin
    LOutputDir := AExeOutput.Replace('$(Platform)', APlatform).Replace('$(Config)', AConfig);
    if TPath.IsRelativePath(LOutputDir) then
      LOutputDir := TPath.GetFullPath(TPath.Combine(LProjectDir, LOutputDir))
    else
      LOutputDir := LOutputDir;
  end
  else
  begin
    LOutputDir := TPath.Combine(LProjectDir, TPath.Combine(APlatform, AConfig));
  end;

  Result := TPath.Combine(LOutputDir, LProjectName + '.exe');
end;

procedure TFormDextTestRunner.RefreshProjects;
var
  LModuleServices: IOTAModuleServices;
  LGroup: IOTAProjectGroup;
  I: Integer;
  LProj: IOTAProject;
  LProjFile: string;
  LIsPackage: Boolean;
  LOutput: string;
  LPrevSelectedFile: string;
  LFoundIndex: Integer;
  ProjInfo: TDextProjectInfo;
begin
  LPrevSelectedFile := FActiveProjectFile;

  // Clear existing items and free their TDextProjectInfo objects
  for I := 0 to ProjectsComboBox.Items.Count - 1 do
    ProjectsComboBox.Items.Objects[I].Free;
  ProjectsComboBox.Items.Clear;

  if not Supports(BorlandIDEServices, IOTAModuleServices, LModuleServices) then
    Exit;

  LGroup := LModuleServices.MainProjectGroup;
  if Assigned(LGroup) then
  begin
    for I := 0 to LGroup.ProjectCount - 1 do
    begin
      LProj := LGroup.Projects[I];
      if Assigned(LProj) then
      begin
        LProjFile := LProj.FileName;
        if (LProjFile.ToLower.Contains('test') or LProjFile.ToLower.Contains('tests')) and
           SameText(ExtractFileExt(LProjFile), '.dproj') then
        begin
          LIsPackage := False;
          LOutput := '';
          if GetProjectTargetInfo(LProjFile, LIsPackage, LOutput) and LIsPackage then
            Continue;

          ProjectsComboBox.Items.AddObject(ExtractFileName(LProjFile), TDextProjectInfo.Create(LProjFile));
        end;
      end;
    end;
  end;

  LFoundIndex := -1;
  if LPrevSelectedFile <> '' then
  begin
    for I := 0 to ProjectsComboBox.Items.Count - 1 do
    begin
      ProjInfo := TDextProjectInfo(ProjectsComboBox.Items.Objects[I]);
      if Assigned(ProjInfo) and SameText(ProjInfo.FileName, LPrevSelectedFile) then
      begin
        LFoundIndex := I;
        Break;
      end;
    end;
  end;

  if LFoundIndex <> -1 then
  begin
    ProjectsComboBox.ItemIndex := LFoundIndex;
    ProjectsComboBoxChange(ProjectsComboBox);
  end
  else if ProjectsComboBox.Items.Count > 0 then
  begin
    ProjectsComboBox.ItemIndex := 0;
    ProjectsComboBoxChange(ProjectsComboBox);
  end
  else
  begin
    ProjectsComboBox.ItemIndex := -1;
    FActiveProjectFile := '';
    if FActiveSession <> nil then
      FActiveSession.ActiveProjectFile := '';
    TestsTreeView.Items.Clear;
    FTestLocations.Clear;
    ResetSummaryLabels;
  end;
end;

procedure TFormDextTestRunner.ProjectsComboBoxChange(Sender: TObject);
var
  LProj: IOTAProject;
  LProjInfo: TDextProjectInfo;
begin
  UpdateSummaryCounts;
  if ProjectsComboBox.ItemIndex = -1 then Exit;

  LProjInfo := TDextProjectInfo(ProjectsComboBox.Items.Objects[ProjectsComboBox.ItemIndex]);
  if not Assigned(LProjInfo) then Exit;

  LProj := GetProjectByFileName(LProjInfo.FileName);
  if not Assigned(LProj) then Exit;

  FActiveProjectFile := LProj.FileName;
  if FActiveSession <> nil then
    FActiveSession.ActiveProjectFile := FActiveProjectFile;

  // Unregister old project notifier
  if (FActiveProjectNotifierIndex <> -1) and Assigned(FActiveProjectForNotifier) then
  begin
    try
      FActiveProjectForNotifier.RemoveNotifier(FActiveProjectNotifierIndex);
    except
      // ignore in case project was already destroyed
    end;
    FActiveProjectNotifierIndex := -1;
    FActiveProjectForNotifier := nil;
  end;

  // Register notifier on new project
  FActiveProjectForNotifier := LProj;
  try
    FActiveProjectNotifierIndex := LProj.AddNotifier(TDextProjectNotifier.Create(Self, LProj.FileName));
  except
    FActiveProjectNotifierIndex := -1;
    FActiveProjectForNotifier := nil;
  end;

  RefreshActiveProjectTestsList;
end;

function TFormDextTestRunner.FindNodeByPath(const APath: string): TTreeNode;
var
  i, J: Integer;
  Node: TTreeNode;
  Split: TArray<string>;

  function GetNodeClassName(const ANodeText: string): string;
  var
    Pos: Integer;
  begin
    Pos := ANodeText.IndexOf(' (');
    if Pos > 0 then
      Result := ANodeText.Substring(0, Pos)
    else
      Result := ANodeText;
  end;
begin
  Result := nil;

  if FGroupingMode = tgmStatus then
  begin
    // In status mode, child nodes are named exactly 'ClassName.MethodName'. Root nodes are 'Failed', 'Passed', 'Skipped', 'Idle'.
    for i := 0 to TestsTreeView.Items.Count - 1 do
    begin
      Node := TestsTreeView.Items[i];
      if (Node.Parent <> nil) and SameText(Node.Text, APath) then
      begin
        Result := Node;
        Exit;
      end;
    end;

    // If not found, check if searching for a status category node itself
    for i := 0 to TestsTreeView.Items.Count - 1 do
    begin
      Node := TestsTreeView.Items[i];
      if (Node.Parent = nil) and SameText(Node.Text, APath) then
      begin
        Result := Node;
        Exit;
      end;
    end;

    Exit;
  end;

  // If APath contains a dot, try to find the child node via ClassName.MethodName
  if APath.Contains('.') then
  begin
    Split := APath.Split(['.'], 2);
    if Length(Split) = 2 then
    begin
      for i := 0 to TestsTreeView.Items.Count - 1 do
      begin
        Node := TestsTreeView.Items[i];
        if (Node.Parent = nil) and SameText(GetNodeClassName(Node.Text), Split[0]) then
        begin
          for J := 0 to Node.Count - 1 do
          begin
            if SameText(Node.Item[J].Text, Split[1]) then
            begin
              Result := Node.Item[J];
              Exit;
            end;
          end;
        end;
      end;
    end;
  end;

  // Fallback: search all nodes by ClassName prefix
  for i := 0 to TestsTreeView.Items.Count - 1 do
  begin
    Node := TestsTreeView.Items[i];
    if (Node.Parent = nil) and SameText(GetNodeClassName(Node.Text), APath) then
    begin
      Result := Node;
      Exit;
    end;
  end;
end;

procedure TFormDextTestRunner.OnTestResultReceived(const AJSONData: string);
var
  Value: TJSONValue;
  JSONArray: TJSONArray;
  i: Integer;

  procedure ProcessSingleResult(ItemJson: TJSONObject);
  var
    DetailInfo: TTestDetailInfo;
    DurationMs: Double;
    ErrorObj: TJSONObject;
    Event: string;
    FullTestName: string;
    i: Integer;
    Node: TTreeNode;
    Passed, Failed, Ignored: Integer;
    TestLocation: TTestLocation;
    TestName, Status, Msg, StackTrace: string;
    Checked: TArray<string>;
    SelectedCount: Integer;
    Fixture: string;
    TempDur: Double;
  begin
    if ItemJson.TryGetValue<string>('event', Event) and SameText(Event, 'RunComplete') then
    begin
      Passed := ItemJson.GetValue<Integer>('passed');
      Failed := ItemJson.GetValue<Integer>('failed');
      Ignored := ItemJson.GetValue<Integer>('ignored');
      LogMsg('');
      LogMsg('========================================');
      LogMsg(Format('Testing Completed. Passed: %d, Failed: %d, Ignored: %d', [Passed, Failed, Ignored]));
      LogMsg('========================================');

      // Stop the stopwatch
      TStopwatch(FStopwatch).Stop;
      UpdateTimingLabels;

      // Mark any remaining 'Idle' tests as 'Skipped'
      for i := 0 to FTestLocations.Count - 1 do
      begin
        TestLocation := FTestLocations[i];
        FullTestName := TestLocation.ClassName + '.' + TestLocation.MethodName;
        if FTestDetails.TryGetValue(FullTestName, DetailInfo) then
        begin
          if SameText(DetailInfo.Status, 'Idle') or (DetailInfo.Status = '') then
          begin
            DetailInfo.Status := 'Skipped';
            FTestDetails.AddOrSetValue(FullTestName, DetailInfo);
            Inc(FSkippedCount);
          end;
        end
        else
        begin
          DetailInfo.TestName := FullTestName;
          DetailInfo.Status := 'Skipped';
          DetailInfo.DurationMs := 0;
          DetailInfo.ErrorMessage := 'Not executed';
          DetailInfo.StackTrace := '';
          DetailInfo.FileName := TestLocation.FileName;
          DetailInfo.Line := TestLocation.Line;
          FTestDetails.AddOrSetValue(FullTestName, DetailInfo);
          Inc(FSkippedCount);
        end;
      end;

      // Update final labels
      SummarySuccessLabel.Caption := 'Passed: ' + FPassedCount.ToString;
      SummaryFailedLabel.Caption := 'Failed: ' + FFailedCount.ToString;
      SummarySkippedLabel.Caption := 'Skipped: ' + FSkippedCount.ToString;

      // Complete and then hide the progress panel
      if Assigned(ProgressPanel) then
      begin
        ProgressBar.Position := ProgressBar.Max;
        ProgressLabel.Caption := Format('%d/%d', [FCompletedTests, Max(FCompletedTests, FTotalTests)]);
        // Hide after a short delay so user can see 100%
        TThread.ForceQueue(nil, TThreadProcedure(procedure
          begin
            if Assigned(ProgressPanel) then
              ProgressPanel.Visible := False;
          end));
      end;
      if FRunningProcessHandle <> 0 then
      begin
        CloseHandle(FRunningProcessHandle);
        FRunningProcessHandle := 0;
      end;
      FRunningTests := False;
      TTelemetryTracker.AnalyzeHistory(FActiveProjectFile, DetailsMemo);
      CollapseSuccessAndFocusFailures;
      TryLoadCoverage;
      Exit;
    end;

    if ItemJson.TryGetValue<string>('event', Event) and SameText(Event, 'RunStart') then
    begin
      FTotalTests := ItemJson.GetValue<Integer>('totalTests');
      FCompletedTests := 0;
      FPassedCount := 0;
      FFailedCount := 0;
      FSkippedCount := 0;
      FTestExecutionDurationMs := 0;
      InitializeGroupSummaries;

      // Ensure all test locations exist in FTestDetails as Idle
      for i := 0 to FTestLocations.Count - 1 do
      begin
        TestLocation := FTestLocations[i];
        FullTestName := TestLocation.ClassName + '.' + TestLocation.MethodName;
        DetailInfo.TestName := FullTestName;
        DetailInfo.Status := 'Idle';
        DetailInfo.DurationMs := 0;
        DetailInfo.ErrorMessage := '';
        DetailInfo.StackTrace := '';
        DetailInfo.FileName := TestLocation.FileName;
        DetailInfo.Line := TestLocation.Line;
        FTestDetails.AddOrSetValue(FullTestName, DetailInfo);
      end;

      if Assigned(ProgressPanel) then
      begin
        ProgressBar.Max := Max(1, FTotalTests);
        ProgressBar.Position := 0;
        ProgressLabel.Caption := Format('0/%d', [FTotalTests]);
        ProgressPanel.Visible := True;
      end;

      // Update summary counts
      Checked := GetCheckedTests;
      SelectedCount := Length(Checked);
      if SelectedCount = 0 then
        SelectedCount := FTestLocations.Count;
      SummarySelectedLabel.Caption := 'Selected: ' + SelectedCount.ToString;
      SummaryTotalLabel.Caption := 'Total: ' + FTestLocations.Count.ToString;
      SummarySuccessLabel.Caption := 'Passed: 0';
      SummaryFailedLabel.Caption := 'Failed: 0';
      SummarySkippedLabel.Caption := 'Skipped: 0';
      UpdateTotalTimeLabel;

      if FGroupingMode = tgmStatus then
        RefreshTreeView;
      Exit;
    end;

    // Detect if this is a standard result
    TestName := '';
    Status := '';
    Msg := '';
    StackTrace := '';
    DurationMs := 0;

    if ItemJson.TryGetValue<string>('testName', TestName) then
    begin
      // Standard Dext result format
      ItemJson.TryGetValue<string>('status', Status);
      ItemJson.TryGetValue<Double>('durationMs', DurationMs);
      if ItemJson.TryGetValue<TJSONObject>('error', ErrorObj) and Assigned(ErrorObj) then
      begin
        Msg := ErrorObj.GetValue<string>('message');
        StackTrace := ErrorObj.GetValue<TJSONObject>('stackTrace').ToJSON;
      end;
    end
    else if ItemJson.TryGetValue<string>('testname', TestName) then
    begin
      // External tests compatibility result format
      ItemJson.TryGetValue<string>('resulttype', Status);

      // Map external tests status to Dext status standard values ('Passed', 'Failed', 'Skipped', 'Error')
      if SameText(Status, 'Passed') then Status := 'Passed'
      else if SameText(Status, 'Failed') then Status := 'Failed'
      else if SameText(Status, 'Error') then Status := 'Error'
      else if SameText(Status, 'Skipped') then Status := 'Skipped';

      Fixture := '';
      if ItemJson.TryGetValue<string>('fixturename', Fixture) and (Fixture <> '') then
      begin
        TestName := Fixture + '.' + TestName;
      end;

      TempDur := 0;
      if ItemJson.TryGetValue<Double>('duration', TempDur) then
        DurationMs := TempDur;

      ItemJson.TryGetValue<string>('exceptionmessage', Msg);
      ItemJson.TryGetValue<string>('status', StackTrace);
    end;

    if TestName = '' then Exit;

    LogMsg('Result received: ' + TestName + ' - ' + Status);

    if not SameText(Status, 'Running') then
    begin
      // Update progress bar
      Inc(FCompletedTests);
      if Assigned(ProgressPanel) and ProgressPanel.Visible then
      begin
        if ProgressBar.Style = pbstMarquee then
          ProgressBar.Style := pbstNormal;
        ProgressBar.Max := Max(ProgressBar.Max, FTotalTests);
        ProgressBar.Position := Min(FCompletedTests, ProgressBar.Max);
        ProgressLabel.Caption := Format('%d/%d', [FCompletedTests, FTotalTests]);
      end;

      if SameText(Status, 'Passed') then
        Inc(FPassedCount)
      else if SameText(Status, 'Failed') or SameText(Status, 'Error') then
        Inc(FFailedCount)
      else if SameText(Status, 'Skipped') then
        Inc(FSkippedCount);

      SummarySuccessLabel.Caption := 'Passed: ' + FPassedCount.ToString;
      SummaryFailedLabel.Caption := 'Failed: ' + FFailedCount.ToString;
      SummarySkippedLabel.Caption := 'Skipped: ' + FSkippedCount.ToString;
      FTestExecutionDurationMs := FTestExecutionDurationMs + DurationMs;
      UpdateTotalTimeLabel;
    end;

    TTelemetryTracker.RecordTestResult(FActiveProjectFile, TestName, Status, Round(DurationMs));
    UpdateNodeResultCache(TestName, Status, DurationMs);

    UpdateTestNode(TestName, Status, Msg, StackTrace);

    // Cache test details
    DetailInfo.TestName := TestName;
    DetailInfo.Status := Status;
    DetailInfo.DurationMs := DurationMs;
    DetailInfo.ErrorMessage := Msg;
    DetailInfo.StackTrace := StackTrace;

    Node := FindNodeByPath(TestName);
    if Assigned(Node) and (Node.Data <> nil) then
    begin
      i := Integer(Node.Data) - 1;
      if (i >= 0) and (i < FTestLocations.Count) then
      begin
        DetailInfo.FileName := FTestLocations[i].FileName;
        DetailInfo.Line := FTestLocations[i].Line;
      end;
    end;

    FTestDetails.AddOrSetValue(TestName, DetailInfo);

    // If this test is selected, update inspector tab
    if (TestsTreeView.Selected <> nil) and
       (SameText(TestsTreeView.Selected.Text, TestName) or
        SameText(GetNodeFullTestName(TestsTreeView.Selected), TestName)) then
    begin
      UpdateTestInspector(TestName);
    end;
  end;

begin
{$IFDEF DEBUG}
  LogMsg('[Debug Payload] ' + AJSONData);
{$ENDIF}

  Value := TJSONObject.ParseJSONValue(AJSONData);
  if not Assigned(Value) then Exit;

  try
    if Value is TJSONArray then
    begin
      JSONArray := TJSONArray(Value);
      for i := 0 to JsonArray.Count - 1 do
      begin
        if JSONArray.Items[i] is TJSONObject then
          ProcessSingleResult(TJSONObject(JSONArray.Items[i]));
      end;
    end
    else if Value is TJSONObject then
    begin
      ProcessSingleResult(TJSONObject(Value));
    end;
  finally
    Value.Free;
  end;
end;

procedure TFormDextTestRunner.CollapseSuccessAndFocusFailures;
var
  Node: TTreeNode;
  Child: TTreeNode;
  HasFailures: Boolean;
  FirstFailedNode: TTreeNode;
begin
  if TestsTreeView = nil then Exit;

  if FGroupingMode = tgmStatus then
    RefreshTreeView;

  TestsTreeView.Items.BeginUpdate;
  try
    FirstFailedNode := nil;

    Node := TestsTreeView.Items.GetFirstNode;
    while Assigned(Node) do
    begin
      // We only care about root nodes that have children
      if (Node.Parent = nil) and (Node.Count > 0) then
      begin
        if FGroupingMode = tgmStatus then
        begin
          if SameText(Node.Text, 'Failed') then
          begin
            Node.Expanded := True;
            Child := Node.GetFirstChild;
            if Assigned(Child) and not Assigned(FirstFailedNode) then
              FirstFailedNode := Child;
          end
          else
          begin
            Node.Expanded := False;
          end;
        end
        else
        begin
          HasFailures := False;

          Child := Node.GetFirstChild;
          while Assigned(Child) do
          begin
            if Child.ImageIndex = 2 then
            begin
              HasFailures := True;
              if not Assigned(FirstFailedNode) then
                FirstFailedNode := Child;
            end;

            Child := Child.GetNextSibling;
          end;

          if HasFailures then
            Node.Expanded := True;
        end;
      end;
      Node := Node.GetNext;
    end;

    // Focus the first failure if found
    if Assigned(FirstFailedNode) then
    begin
      TestsTreeView.Selected := FirstFailedNode;
      FirstFailedNode.MakeVisible;
    end;
  finally
    TestsTreeView.Items.EndUpdate;
  end;
end;

procedure TFormDextTestRunner.NotifyProcessExited;
begin
  FRunningTests := False;
  if FRunningProcessHandle <> 0 then
  begin
    LogMsg('');
    LogMsg('========================================');
    LogMsg('Testing Completed (Process Exited)');
    LogMsg('========================================');

    if Assigned(ProgressPanel) then
    begin
      ProgressBar.Position := ProgressBar.Max;
      ProgressLabel.Caption := Format('%d/%d', [FCompletedTests, Max(FCompletedTests, FTotalTests)]);
      TThread.Queue(nil, TThreadProcedure(procedure
        begin
          if Assigned(ProgressPanel) then
            ProgressPanel.Visible := False;
        end));
    end;

    CloseHandle(FRunningProcessHandle);
    FRunningProcessHandle := 0;
    TStopwatch(FStopwatch).Stop;
    UpdateTimingLabels;

    TTelemetryTracker.AnalyzeHistory(FActiveProjectFile, DetailsMemo);
    CollapseSuccessAndFocusFailures;
    TryLoadCoverage;
  end;
end;

procedure TFormDextTestRunner.UpdateTestNode(const ATestName, AStatus, AMessage, AStackTrace: string);
var
  Node: TTreeNode;
  Text: string;
  NodeRect: TRect;
begin
  // ATestName is usually in the format: ClassName.MethodName or TClassName.MethodName
  Node := FindNodeByPath(ATestName);
  if not Assigned(Node) then
  begin
    // Fallback: search for method leaf node matching method portion
    Text := ATestName;
    if Text.Contains('.') then
      Text := Text.Split(['.'])[1];
    Node := FindNodeByPath(Text);
  end;

  if Assigned(Node) then
  begin
    if SameText(AStatus, 'Passed') then
    begin
      Node.ImageIndex := 1;
      Node.SelectedIndex := 1;
    end
    else if SameText(AStatus, 'Failed') or SameText(AStatus, 'Error') then
    begin
      Node.ImageIndex := 2;
      Node.SelectedIndex := 2;
      if AMessage <> '' then
      begin
        LogMsg('Test Failed: ' + ATestName);
        LogMsg('Error: ' + AMessage);
        if AStackTrace <> '' then
        begin
          LogMsg('Stack Trace:');
          LogMsg(AStackTrace);
        end;
        LogMsg('----------------------------------------');
      end;
    end
    else if SameText(AStatus, 'Skipped') then
    begin
      Node.ImageIndex := 0; // Gray
      Node.SelectedIndex := 0;
    end;
    NodeRect := Node.DisplayRect(False);
    InvalidateRect(TestsTreeView.Handle, @NodeRect, True);
  end;
end;

procedure TFormDextTestRunner.TestsTreeViewChange(Sender: TObject; Node: TTreeNode);
var
  LKey: string;
  LStopwatch: TStopwatch;
  LRect: TRect;
begin
  if not Assigned(Node) then Exit;
  LStopwatch := TStopwatch.StartNew;

  LKey := GetNodeFullTestName(Node);
  UpdateTestInspector(LKey);
  if (Node.Parent <> nil) and FTestDetails.ContainsKey(LKey) then
  begin
    if DetailsPageControl.Visible then
      DetailsPageControl.ActivePage := InspectorTab;
  end;
  LRect := Node.DisplayRect(True);
  LRect.Right := TestsTreeView.ClientWidth;
  InvalidateRect(TestsTreeView.Handle, @LRect, True);
  if LStopwatch.Elapsed.TotalMilliseconds > 5 then
    LogPerformance(Format('TestsTreeViewChange slow %.2f ms: %s', [LStopwatch.Elapsed.TotalMilliseconds, LKey]));
end;

procedure TFormDextTestRunner.UpdateTestInspector(const ATestName: string);
var
  DetailInfo: TTestDetailInfo;
  StatusText: string;
  Node: TTreeNode;
  i: Integer;
  TestLocation: TTestLocation;
  Stopwatch: TStopwatch;
  RealLine: Integer;
begin
  Stopwatch := TStopwatch.StartNew;
  if not Assigned(TestNameLabel) then Exit;
  TestNameLabel.Caption := 'Test Name: ' + ATestName;
  ErrorMemo.Clear;

  // Set default Location
  LocationLabel.Caption := 'Location: Unknown';
  Node := nil;
  if Assigned(TestsTreeView) and Assigned(TestsTreeView.Selected) and
    SameText(GetNodeFullTestName(TestsTreeView.Selected), ATestName) then
    Node := TestsTreeView.Selected;

  if not Assigned(Node) then
    Node := FindNodeByPath(ATestName);

  if Assigned(Node) and (Node.Data <> nil) then
  begin
    i := Integer(Node.Data) - 1;
    if (i >= 0) and (i < FTestLocations.Count) then
    begin
      TestLocation := FTestLocations[i];
      RealLine := FindMethodImplementationLine(TestLocation.FileName, TestLocation.ClassName, TestLocation.MethodName, TestLocation.Line);
      LocationLabel.Caption := Format('Location: %s (Line %d)', [ExtractFileName(TestLocation.FileName), RealLine]);
    end;
  end;

  if FTestDetails.TryGetValue(ATestName, DetailInfo) then
  begin
    StatusText := DetailInfo.Status;
    StatusLabel.Caption := 'Status: ' + StatusText;
    StatusLabel.ParentColor := False;
    if SameText(StatusText, 'Passed') then
      StatusLabel.Font.Color := TColor($5EC522) // Green BGR
    else if SameText(StatusText, 'Failed') or SameText(StatusText, 'Error') then
      StatusLabel.Font.Color := TColor($4444EF) // Red BGR
    else
    begin
      StatusLabel.Font.Color := clWindowText;
      StatusLabel.ParentColor := True;
    end;

    // Format duration intelligently: show sub-ms precision when needed
    if DetailInfo.DurationMs < 1.0 then
      DurationLabel.Caption := Format('Duration: %.3f ms', [DetailInfo.DurationMs])
    else if DetailInfo.DurationMs < 100.0 then
      DurationLabel.Caption := Format('Duration: %.2f ms', [DetailInfo.DurationMs])
    else
      DurationLabel.Caption := Format('Duration: %.0f ms', [DetailInfo.DurationMs]);

    if DetailInfo.ErrorMessage <> '' then
    begin
      ErrorMemo.Lines.Add('Error Message:');
      ErrorMemo.Lines.Add(DetailInfo.ErrorMessage);
      ErrorMemo.Lines.Add('');
    end;

    if DetailInfo.StackTrace <> '' then
    begin
      ErrorMemo.Lines.Add('Stack Trace:');
      ErrorMemo.Lines.Add(DetailInfo.StackTrace);
    end;
  end
  else
  begin
    StatusLabel.Caption := 'Status: Idle';
    StatusLabel.Font.Color := clWindowText;
    DurationLabel.Caption := 'Duration: N/A';
  end;

  ErrorHeaderLabel.Visible := (DetailInfo.ErrorMessage <> '') or (DetailInfo.StackTrace <> '');
  ErrorMemo.Visible := ErrorHeaderLabel.Visible;

  if Stopwatch.Elapsed.TotalMilliseconds > 5 then
    LogPerformance(Format('UpdateTestInspector slow %.2f ms: %s', [Stopwatch.Elapsed.TotalMilliseconds, ATestName]));
end;

procedure TFormDextTestRunner.ClearTestStatus;
var
  I: Integer;
  LNode: TTreeNode;
begin
  if Assigned(FTestDetails) then
    FTestDetails.Clear;
  if Assigned(FGroupSummaries) then
    FGroupSummaries.Clear;
  if Assigned(FGroupNodes) then
    FGroupNodes.Clear;
  if Assigned(TestNameLabel) then
  begin
    TestNameLabel.Caption := 'Test Name: Select a test...';
    StatusLabel.Caption := 'Status: Idle';
    StatusLabel.Font.Color := clWindowText;
    LocationLabel.Caption := 'Location: N/A';
    DurationLabel.Caption := 'Duration: N/A';
    ErrorMemo.Clear;
  end;

  TestsTreeView.Items.BeginUpdate;
  try
    for I := 0 to TestsTreeView.Items.Count - 1 do
    begin
      LNode := TestsTreeView.Items[I];
      if LNode.ImageIndex in [1, 2] then
      begin
        LNode.ImageIndex := 0;
        LNode.SelectedIndex := 0;
      end;
    end;
  finally
    TestsTreeView.Items.EndUpdate;
  end;
end;

procedure TFormDextTestRunner.RunActiveProjectTests(const TestFilter: string = ''; AutoSave: Boolean = True);
var
  Group: IOTAProjectGroup;
  ModuleServices: IOTAModuleServices;
  Project: IOTAProject;
  SaveServices: IOTAModuleServices;
begin
  if ProjectsComboBox.ItemIndex = -1 then Exit;
  Project := GetProjectByFileName(FActiveProjectFile);
  if not Assigned(Project) then Exit;

  FRunningTests := True;

  // Synchronize IDE Active Project
  if Supports(BorlandIDEServices, IOTAModuleServices, ModuleServices) and Assigned(ModuleServices) then
  begin
    Group := ModuleServices.MainProjectGroup;
    if Assigned(Group) and (Group.ActiveProject <> Project) then
      Group.ActiveProject := Project;
  end;

  ClearTestStatus;
  DetailsMemo.Clear;
  FTotalTests := 0;
  FCompletedTests := 0;
  FTestExecutionDurationMs := 0;
  LogPerformance(Format('RunActiveProjectTests: start filter="%s" autoSave=%s', [TestFilter, BoolToStr(AutoSave, True)]));

  // Start stopwatch
  TStopwatch(FStopwatch).Reset;
  TStopwatch(FStopwatch).Start;
  UpdateTotalTimeLabel;

  // Show progress immediately so the user knows something is happening
  if Assigned(ProgressPanel) then
  begin
    ProgressBar.Style := pbstMarquee;
    ProgressBar.Position := 0;
    ProgressBar.Max := 100;
    ProgressLabel.Caption := 'Saving files...';
    ProgressPanel.Visible := True;
    ProgressPanel.Update;
  end;

  if Assigned(DetailsPageControl) and Assigned(ConsoleTab) then
    DetailsPageControl.ActivePage := ConsoleTab;

  LogMsg('--- Dext Test Runner ---');
  LogMsg('Project: ' + ExtractFileName(FActiveProjectFile));

  // Step 1: Save all editor buffers so IDE's make sees up-to-date timestamps
  if AutoSave and Supports(BorlandIDEServices, IOTAModuleServices, SaveServices) then
  begin
    LogMsg('[1/3] Saving all modified files...');
    SaveServices.SaveAll;
  end;

  // Step 2: Trigger the IDE's incremental make (async).
  //   The IDE knows exactly which files changed in the editor.
  //   Test launch happens in NotifyCompileComplete → AfterCompile notifier.
  FPendingTestFilter  := TestFilter;
  FPendingProject     := Project;
  FWaitingForCompile  := True;

  if Assigned(ProgressPanel) then
  begin
    ProgressLabel.Caption := '[2/3] Compiling...';
    ProgressPanel.Update;
  end;
  LogMsg('[2/3] Starting incremental compile (IDE make)...');
  DetailsMemo.Update;
  LogPerformance('RunActiveProjectTests: before build');

  Project.ProjectBuilder.BuildProject(cmOTAMake, False, True);
  // Returns immediately — NotifyCompileComplete is called by Expert.AfterCompile
end;

procedure TFormDextTestRunner.LaunchTestExe(const ATestFilter: string);
var
  LIsPackage: Boolean;
  LOutput: string;
  LExeFile: string;
  LParams: string;
  LCmdLine: string;
  SI: TStartupInfo;
  PI: TProcessInformation;
  PlatformVal: string;
  Config: string;
  Proj: IOTAProject;
  Configs: IOTAProjectOptionsConfigurations;
  Checked: TArray<string>;
  JSON: string;
  Idx: Integer;
  CustomParams: string;
  ProcessHandle: THandle;
begin
  LIsPackage := False;
  LOutput := '';
  PlatformVal := 'Win32';
  Config := 'Debug';
  Proj := GetProjectByFileName(FActiveProjectFile);
  if Assigned(Proj) then
  begin
    LOutput := Proj.ProjectOptions.Values['OutputDir'];
    if Supports(Proj.ProjectOptions, IOTAProjectOptionsConfigurations, Configs) then
    begin
      PlatformVal := Configs.ActivePlatformName;
      if Assigned(Configs.ActiveConfiguration) then
        Config := Configs.ActiveConfiguration.Name;
    end;
  end;
  if LOutput = '' then
    GetProjectTargetInfo(FActiveProjectFile, LIsPackage, LOutput, PlatformVal, Config);
  LExeFile := ResolveExePath(FActiveProjectFile, LOutput, PlatformVal, Config);

  if not FileExists(LExeFile) then
  begin
    LogMsg('Error: Executable not found at ' + LExeFile);
    TStopwatch(FStopwatch).Stop;
    UpdateTimingLabels;
    if Assigned(ProgressPanel) then ProgressPanel.Visible := False;
    Exit;
  end;

  // Apply test filter to server selection JSON
  if ATestFilter <> '' then
    FServer.SelectedTestsJSON := '["' + ATestFilter + '"]'
  else
  begin
    Checked := GetCheckedTests;
    if Length(Checked) > 0 then
    begin
      JSON := '[';
      for Idx := 0 to Length(Checked) - 1 do
      begin
        if Idx > 0 then JSON := JSON + ',';
        JSON := JSON + '"' + Checked[Idx] + '"';
      end;
      JSON := JSON + ']';
      FServer.SelectedTestsJSON := JSON;
    end
    else
      FServer.SelectedTestsJSON := '[]';
  end;

  LogMsg('Selected tests filter: ' + FServer.SelectedTestsJSON);

  // Update progress to 'Executing'
  if Assigned(ProgressPanel) then
  begin
    ProgressLabel.Caption := '⏳ Executing tests...';
    ProgressBar.Style := pbstMarquee;
    ProgressPanel.Visible := True;
    ProgressPanel.Update;
  end;
  DetailsMemo.Update;

  LParams := Format('--port %d -no-wait', [FServer.Port]);
  CustomParams := CustomParamsEdit.Text;
  if CustomParams <> '' then
    LParams := LParams + ' ' + CustomParams;

  if ATestFilter <> '' then
  begin
    FServer.SelectedTestsJSON := '["' + ATestFilter + '"]';
  end;

  LCmdLine := Format('"%s" %s', [LExeFile, LParams]);
  LogMsg('Command Line: ' + LCmdLine);
  UniqueString(LCmdLine);

  ZeroMemory(@SI, SizeOf(SI));
  SI.cb := SizeOf(SI);
  ZeroMemory(@PI, SizeOf(PI));

  if FRunningProcessHandle <> 0 then
  begin
    TerminateProcess(FRunningProcessHandle, 0);
    CloseHandle(FRunningProcessHandle);
    FRunningProcessHandle := 0;
  end;

  if CreateProcess(nil, PChar(LCmdLine), nil, nil, False, CREATE_NO_WINDOW, nil, PChar(ExtractFilePath(LExeFile)), SI, PI) then
  begin
    FRunningProcessHandle := PI.hProcess;
    CloseHandle(PI.hThread);

    ProcessHandle := PI.hProcess;
    TThread.CreateAnonymousThread(procedure
      begin
        WaitForSingleObject(ProcessHandle, 120000); // 120s timeout max
        TThread.Queue(nil, TThreadProcedure(procedure
          begin
            if Assigned(FormDextTestRunner) then
              FormDextTestRunner.NotifyProcessExited;
          end));
      end).Start;
  end
  else
    LogMsg('Failed to launch runner: ' + LExeFile);
end;

var
  LLogLock: TObject = nil;

procedure LogToFile(const AMsg: string);
var
  LPath: string;
  LWriter: TStreamWriter;
begin
  if LLogLock = nil then Exit;
  System.TMonitor.Enter(LLogLock);
  try
    try
      LPath := TPath.Combine(TPath.GetTempPath, 'DextExpert.log');
      LWriter := TFile.AppendText(LPath);
      try
        LWriter.WriteLine(Format('[%s] %s', [FormatDateTime('yyyy-MM-dd hh:nn:ss.zzz', Now), AMsg]));
      finally
        LWriter.Free;
      end;
    except
    end;
  finally
    System.TMonitor.Exit(LLogLock);
  end;
end;

procedure TFormDextTestRunner.LogMsg(const AMsg: string);
begin
  LogToFile('[UI] ' + AMsg);
  Winapi.Windows.OutputDebugString(PChar('[Dext.UI] ' + AMsg));
  {$IFDEF DEBUG}
  DetailsMemo.Lines.Add(Format('[%s] %s', [FormatDateTime('hh:nn:ss.zzz', Now), AMsg]));
  {$ELSE}
  DetailsMemo.Lines.Add(AMsg);
  {$ENDIF}
  DetailsMemo.Update;
end;

procedure TFormDextTestRunner.LogPerformance(const AMessage: string);
{$IFDEF DEXT_TEST_EXPLORER_PERF_LOG}
var
  Line: string;
  LogFile: string;
{$ENDIF}
begin
{$IFDEF DEXT_TEST_EXPLORER_PERF_LOG}
  Line := Format('[%s] %s', [FormatDateTime('hh:nn:ss.zzz', Now), AMessage]);
  LogFile := TPath.Combine(TPath.GetTempPath, 'DextTestExplorer.perf.log');
  try
    System.TMonitor.Enter(PerfLogLock);
    try
      TFile.AppendAllText(LogFile, Line + sLineBreak, TEncoding.UTF8);
    finally
      System.TMonitor.Exit(PerfLogLock);
    end;
  except
    // ignore logging failures
  end;
{$ELSE}
  if AMessage = '' then;
{$ENDIF}
end;

procedure TFormDextTestRunner.InitializeGroupSummaries;
var
  LIdx: Integer;
  LTest: TTestLocation;
  LKey: string;
  LInfo: TGroupSummaryInfo;
begin
  if not Assigned(FGroupSummaries) then Exit;
  FGroupSummaries.Clear;
  for LIdx := 0 to FTestLocations.Count - 1 do
  begin
    LTest := FTestLocations[LIdx];
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

procedure TFormDextTestRunner.UpdateGroupSummary(const ATestName, AStatus: string; ADurationMs: Double);
var
  LClassName: string;
  LDotPos: Integer;
  LInfo: TGroupSummaryInfo;
  LIdx: Integer;
  LTest: TTestLocation;
begin
  if not Assigned(FGroupSummaries) then Exit;
  LDotPos := ATestName.IndexOf('.');
  if LDotPos <= 0 then Exit;
  LClassName := ATestName.Substring(0, LDotPos);
  if not FGroupSummaries.TryGetValue(LClassName, LInfo) then
  begin
    LInfo.TotalCount := 0;
    LInfo.PassedCount := 0;
    LInfo.FailedCount := 0;
    LInfo.DurationMs := 0;

    for LIdx := 0 to FTestLocations.Count - 1 do
    begin
      LTest := FTestLocations[LIdx];
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

procedure TFormDextTestRunner.InvalidateGroupNode(const ATestName: string);
var
  DotPos: Integer;
  Node: TTreeNode;
  NodeRect: TRect;
  TestClassName: string;
begin
  if not Assigned(TestsTreeView) then Exit;
  DotPos := ATestName.IndexOf('.');
  if DotPos <= 0 then Exit;
  TestClassName := ATestName.Substring(0, DotPos);
  Node := FindNodeByPath(TestClassName);
  if Assigned(Node) then
  begin
    NodeRect := Node.DisplayRect(True);
    NodeRect.Right := TestsTreeView.ClientWidth;
    InvalidateRect(TestsTreeView.Handle, @NodeRect, True);
  end;
end;

procedure TFormDextTestRunner.UpdateNodeResultCache(const ATestName, AStatus: string; ADurationMs: Double);
begin
  UpdateGroupSummary(ATestName, AStatus, ADurationMs);
  InvalidateGroupNode(ATestName);
end;

procedure TFormDextTestRunner.UpdateTotalTimeLabel;
begin
  SummaryTotalTimeLabel.Caption := Format('Total: %.2fs', [TStopwatch(FStopwatch).Elapsed.TotalSeconds]);
end;

procedure TFormDextTestRunner.UpdateSummaryCounts;
var
  CheckedTests: TArray<string>;
  SelectedCount: Integer;
begin
  ResetSummaryLabels;
  SummaryTotalLabel.Caption := 'Total: ' + FTestLocations.Count.ToString;
  CheckedTests := GetCheckedTests;
  SelectedCount := Length(CheckedTests);
  SummarySelectedLabel.Caption := 'Selected: ' + SelectedCount.ToString;
end;

procedure TFormDextTestRunner.UpdateTimingLabels;
begin
  SummaryTimeLabel.Caption := Format('Tests: %.2fs', [FTestExecutionDurationMs / 1000]);
  UpdateTotalTimeLabel;
end;

procedure TFormDextTestRunner.NotifyCompileComplete(ASucceeded: Boolean);
begin
  if not FWaitingForCompile then Exit;
  FWaitingForCompile := False;

  if not ASucceeded then
  begin
    FRunningTests := False;
    LogMsg('❌ Compile failed — tests not executed.');
    TStopwatch(FStopwatch).Stop;
    UpdateTimingLabels;
    if Assigned(ProgressPanel) then
    begin
      ProgressLabel.Caption := 'Compile failed';
      ProgressPanel.Visible := False;
    end;
    Exit;
  end;

  LogMsg('✔ Compile succeeded.');
  LaunchTestExe(FPendingTestFilter);
end;

procedure TFormDextTestRunner.RunAllButtonClick(Sender: TObject);
begin
  RunActiveProjectTests;
end;

procedure TFormDextTestRunner.RunAllProjectsClick(Sender: TObject);
begin
  RunAllProjectsTests;
end;

procedure TFormDextTestRunner.RunAllProjectsTests;
var
  I: Integer;
  LProj: IOTAProject;
  LProjFile: string;
  LIsPackage: Boolean;
  LOutput: string;
  LExeFile: string;
  LCmdLine: string;
  LParams: string;
  SI: TStartupInfo;
  PI: TProcessInformation;
  SaveServices: IOTAModuleServices;
  ProjInfo: TDextProjectInfo;
  PlatformVal: string;
  Config: string;
  Configs: IOTAProjectOptionsConfigurations;
begin
  FRunningTests := True;
  ClearTestStatus;
  DetailsMemo.Clear;
  FTotalTests := 0;
  FCompletedTests := 0;
  if Assigned(ProgressPanel) then
  begin
    ProgressBar.Style := pbstMarquee;
    ProgressBar.Position := 0;
    ProgressBar.Max := 100;
    ProgressLabel.Caption := '...';
    ProgressPanel.Visible := True;
  end;
  // Focus Console Log
  if Assigned(DetailsPageControl) and Assigned(ConsoleTab) then
    DetailsPageControl.ActivePage := ConsoleTab;
  LogMsg('=== Running All Test Projects ===');

  // Save all modified IDE files once before the loop.
  if Supports(BorlandIDEServices, IOTAModuleServices, SaveServices) then
  begin
    LogMsg('Saving all modified files...');
    SaveServices.SaveAll;
  end;

  for I := 0 to ProjectsComboBox.Items.Count - 1 do
  begin
    ProjInfo := TDextProjectInfo(ProjectsComboBox.Items.Objects[I]);
    if Assigned(ProjInfo) then
    begin
      LProj := GetProjectByFileName(ProjInfo.FileName);
      if Assigned(LProj) then
      begin
        LProjFile := LProj.FileName;
        LogMsg('');
        LogMsg('----------------------------------------');
        LogMsg('Compiling ' + ExtractFileName(LProjFile) + '...');
        if not CompileProjectDirect(LProjFile) then
        begin
          LogMsg('Direct DCC compile failed, building via IDE make...');
          LProj.ProjectBuilder.BuildProject(cmOTAMake, False, True);
        end;

        LIsPackage := False;
        LOutput := '';
        PlatformVal := 'Win32';
        Config := 'Debug';
        if Assigned(LProj) then
        begin
          LOutput := LProj.ProjectOptions.Values['OutputDir'];
          if Supports(LProj.ProjectOptions, IOTAProjectOptionsConfigurations, Configs) then
          begin
            PlatformVal := Configs.ActivePlatformName;
            if Assigned(Configs.ActiveConfiguration) then
              Config := Configs.ActiveConfiguration.Name;
          end;
        end;
        if LOutput = '' then
          GetProjectTargetInfo(LProjFile, LIsPackage, LOutput);
        LExeFile := ResolveExePath(LProjFile, LOutput, PlatformVal, Config);

        if FileExists(LExeFile) then
        begin
          LogMsg('Executing ' + ExtractFileName(LExeFile) + '...');
          FServer.SelectedTestsJSON := '[]';
          LParams := Format('--port %d -no-wait', [FServer.Port]);
          LCmdLine := Format('"%s" %s', [LExeFile, LParams]);
          UniqueString(LCmdLine);

          FillChar(SI, SizeOf(SI), 0);
          SI.cb := SizeOf(TStartupInfo);
          FillChar(PI, SizeOf(PI), 0);
          if CreateProcess(nil, PChar(LCmdLine), nil, nil, False, CREATE_NO_WINDOW, nil, PChar(ExtractFilePath(LExeFile)), SI, PI) then
          begin
            CloseHandle(PI.hProcess);
            CloseHandle(PI.hThread);
          end
          else
          begin
            LogMsg('Failed to launch runner: ' + LExeFile);
            TStopwatch(FStopwatch).Stop;
            UpdateTimingLabels;
          end;
        end;
      end;
    end;
  end;
  FRunningTests := False;
end;

procedure TFormDextTestRunner.RunSelectedButtonClick(Sender: TObject);
var
  LChecked: TArray<string>;
begin
  LChecked := GetCheckedTests;
  if (Sender = RunSelectedButton) and (Length(LChecked) > 0) then
  begin
    RunActiveProjectTests('');
  end
  else if Assigned(TestsTreeView.Selected) then
  begin
    RunActiveProjectTests(GetNodeFullTestName(TestsTreeView.Selected));
  end
  else
    RunActiveProjectTests;
end;

procedure TFormDextTestRunner.ExpandAllMenuItemClick(Sender: TObject);
begin
  ExpandTestsTreeView;
end;

procedure TFormDextTestRunner.CollapseAllMenuItemClick(Sender: TObject);
begin
  TestsTreeView.Items.BeginUpdate;
  TestsTreeView.FullCollapse;
  TestsTreeView.Items.EndUpdate;
end;

procedure TFormDextTestRunner.StopButtonClick(Sender: TObject);
begin
  FRunningTests := False;
  LogMsg('Stop clicked. Terminating running test runner process...');
  if FRunningProcessHandle <> 0 then
  begin
    TerminateProcess(FRunningProcessHandle, 0);
    CloseHandle(FRunningProcessHandle);
    FRunningProcessHandle := 0;
  end;

  FWaitingForCompile := False;

  if Assigned(ProgressPanel) then
  begin
    ProgressBar.Style := pbstNormal;
    ProgressBar.Position := 0;
    ProgressPanel.Visible := False;
  end;
  TStopwatch(FStopwatch).Stop;
  UpdateTimingLabels;

  LogMsg('Test execution stopped.');
end;

function TFormDextTestRunner.FindMethodImplementationLine(const AFileName, AClassName, AMethodName: string; ADefaultLine: Integer): Integer;
var
  LStrings: TStringList;
  I: Integer;
  LSearchStr1, LSearchStr2: string;
  LLine: string;
begin
  Result := ADefaultLine;
  if not FileExists(AFileName) then Exit;
  LStrings := TStringList.Create;
  try
    LStrings.LoadFromFile(AFileName);
    LSearchStr1 := ('procedure ' + AClassName + '.' + AMethodName).ToLower;
    LSearchStr2 := ('function ' + AClassName + '.' + AMethodName).ToLower;
    for I := 0 to LStrings.Count - 1 do
    begin
      LLine := LStrings[I].ToLower.Trim;
      if LLine.StartsWith(LSearchStr1) or LLine.StartsWith(LSearchStr2) then
      begin
        Result := I + 1;
        Break;
      end;
    end;
  finally
    LStrings.Free;
  end;
end;

procedure TFormDextTestRunner.TestsTreeViewDblClick(Sender: TObject);
var
  LNode: TTreeNode;
  LIdx: Integer;
  LLoc: TTestLocation;
  LModuleServices: IOTAModuleServices;
  LModule: IOTAModule;
  LSourceEditor: IOTASourceEditor;
  LView: IOTAEditView;
  LTargetLine: Integer;
begin
  LNode := TestsTreeView.Selected;
  if not Assigned(LNode) or (LNode.Data = nil) then Exit;

  LIdx := Integer(LNode.Data) - 1;
  if (LIdx < 0) or (LIdx >= FTestLocations.Count) then Exit;

  LLoc := FTestLocations[LIdx];
  if LLoc.FileName = '' then Exit;

  LTargetLine := FindMethodImplementationLine(LLoc.FileName, LLoc.ClassName, LLoc.MethodName, LLoc.Line);

  // Navigate directly using the exact unit file path
  if Supports(BorlandIDEServices, IOTAModuleServices, LModuleServices) then
  begin
    LModule := LModuleServices.OpenModule(LLoc.FileName);
    if Assigned(LModule) then
    begin
      LModule.Show;
      if Supports(LModule.CurrentEditor, IOTASourceEditor, LSourceEditor) then
      begin
        LView := LSourceEditor.GetEditView(0);
        if Assigned(LView) then
        begin
          LView.Position.Move(LTargetLine, 1);
        end;
      end;
    end;
  end;
end;

function TFormDextTestRunner.GetCheckedTests: TArray<string>;
var
  I: Integer;
  LNode: TTreeNode;
  LList: TList<string>;
begin
  LList := TList<string>.Create;
  try
    for I := 0 to TestsTreeView.Items.Count - 1 do
    begin
      LNode := TestsTreeView.Items[I];
      if (LNode.Parent <> nil) and LNode.Checked then
      begin
        LList.Add(GetNodeFullTestName(LNode));
      end;
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function TFormDextTestRunner.GetRunButtonRect(ANode: TTreeNode): TRect;
var
  LTextRect: TRect;
  LPPI: Integer;
  LBtnWidth, LBtnHeight, LOffset: Integer;
begin
  LPPI := Self.CurrentPPI;
  if LPPI = 0 then
    LPPI := 96;

  LBtnWidth := MulDiv(20, LPPI, 96);
  LBtnHeight := MulDiv(13, LPPI, 96);
  LOffset := MulDiv(8, LPPI, 96);

  LTextRect := ANode.DisplayRect(True);
  Result.Left := LTextRect.Right + LOffset;
  Result.Top := LTextRect.Top + (LTextRect.Height - LBtnHeight) div 2;
  Result.Right := Result.Left + LBtnWidth;
  Result.Bottom := Result.Top + LBtnHeight;
end;

procedure TFormDextTestRunner.TestsTreeViewMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  LTreeView: TTreeView;
  LNode: TTreeNode;
  LOldNode: TTreeNode;
  LBtnRect: TRect;
  LRect: TRect;
begin
  LTreeView := Sender as TTreeView;
  LNode := LTreeView.GetNodeAt(X, Y);

  if LNode <> FHoverNode then
  begin
    LOldNode := FHoverNode;
    FHoverNode := LNode;

    if Assigned(LOldNode) then
    begin
      LRect := LOldNode.DisplayRect(False);
      LRect.Right := LTreeView.ClientWidth;
      InvalidateRect(LTreeView.Handle, @LRect, True);
    end;

    if Assigned(FHoverNode) then
    begin
      LRect := FHoverNode.DisplayRect(False);
      LRect.Right := LTreeView.ClientWidth;
      InvalidateRect(LTreeView.Handle, @LRect, True);
    end;
  end;

  if Assigned(FHoverNode) and (FHoverNode.Parent <> nil) then
  begin
    LBtnRect := GetRunButtonRect(FHoverNode);
    if PtInRect(LBtnRect, Point(X, Y)) then
    begin
      LTreeView.Cursor := crHandPoint;
      Exit;
    end;
  end;

  LTreeView.Cursor := crDefault;
end;

procedure TFormDextTestRunner.TestsTreeViewMouseLeave(Sender: TObject);
var
  LTreeView: TTreeView;
  LOldNode: TTreeNode;
  LRect: TRect;
begin
  LTreeView := Sender as TTreeView;
  if Assigned(FHoverNode) then
  begin
    LOldNode := FHoverNode;
    FHoverNode := nil;
    LRect := LOldNode.DisplayRect(False);
    LRect.Right := LTreeView.ClientWidth;
    InvalidateRect(LTreeView.Handle, @LRect, True);
  end;
end;

procedure TFormDextTestRunner.TestsTreeViewMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  LNode: TTreeNode;
  LBtnRect: TRect;
  LHitInfo: THitTests;
  I: Integer;
begin
  if Button = mbLeft then
  begin
    LNode := TestsTreeView.GetNodeAt(X, Y);
    if Assigned(LNode) then
    begin
      LHitInfo := TestsTreeView.GetHitTestInfoAt(X, Y);
      if htOnStateIcon in LHitInfo then
      begin
        TThread.ForceQueue(nil, TThreadProcedure(procedure
          var
            I: Integer;
            LState: Boolean;
            ParentNode: TTreeNode;
            AnyChecked: Boolean;
          begin
            if not Assigned(LNode) or not Assigned(TestsTreeView) then Exit;
            LState := LNode.Checked;
            if LNode.Parent = nil then
            begin
              TestsTreeView.Items.BeginUpdate;
              try
                for I := 0 to LNode.Count - 1 do
                  LNode.Item[I].Checked := LState;
              finally
                TestsTreeView.Items.EndUpdate;
              end;
            end
            else
            begin
              ParentNode := LNode.Parent;
              AnyChecked := False;
              for I := 0 to ParentNode.Count - 1 do
              begin
                if ParentNode.Item[I].Checked then
                begin
                  AnyChecked := True;
                  Break;
                end;
              end;
              ParentNode.Checked := AnyChecked;
            end;
            UpdateSummaryCounts;
            TestsTreeView.Invalidate;
          end));
      end;

      if LNode.Parent <> nil then
      begin
        LBtnRect := GetRunButtonRect(LNode);
        if PtInRect(LBtnRect, Point(X, Y)) then
        begin
          TestsTreeView.Selected := LNode;
          
          TestsTreeView.Items.BeginUpdate;
          try
            for I := 0 to TestsTreeView.Items.Count - 1 do
              TestsTreeView.Items[I].Checked := False;
            LNode.Checked := True;
            if LNode.Parent <> nil then
              LNode.Parent.Checked := True;
          finally
            TestsTreeView.Items.EndUpdate;
          end;
          UpdateSummaryCounts;
          TestsTreeView.Invalidate;

          RunActiveProjectTests(GetNodeFullTestName(LNode));
        end;
      end;
    end;
  end;
end;

procedure TFormDextTestRunner.TestsTreeViewMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  LNode: TTreeNode;
  LHitInfo: THitTests;
begin
  if Button = mbLeft then
  begin
    LNode := TestsTreeView.GetNodeAt(X, Y);
    if Assigned(LNode) then
    begin
      LHitInfo := TestsTreeView.GetHitTestInfoAt(X, Y);
      if htOnStateIcon in LHitInfo then
      begin
        TThread.ForceQueue(nil, TThreadProcedure(procedure
          var
            I: Integer;
            LState: Boolean;
            ParentNode: TTreeNode;
            AnyChecked: Boolean;
          begin
            if not Assigned(LNode) or not Assigned(TestsTreeView) then Exit;
            LState := LNode.Checked;
            if LNode.Parent = nil then
            begin
              TestsTreeView.Items.BeginUpdate;
              try
                for I := 0 to LNode.Count - 1 do
                  LNode.Item[I].Checked := LState;
              finally
                TestsTreeView.Items.EndUpdate;
              end;
            end
            else
            begin
              ParentNode := LNode.Parent;
              AnyChecked := False;
              for I := 0 to ParentNode.Count - 1 do
              begin
                if ParentNode.Item[I].Checked then
                begin
                  AnyChecked := True;
                  Break;
                end;
              end;
              ParentNode.Checked := AnyChecked;
            end;
            UpdateSummaryCounts;
            TestsTreeView.Invalidate;
          end));
      end;
    end;
  end;
end;

function TFormDextTestRunner.GetNodeFullTestName(ANode: TTreeNode): string;
var
  LParentText: string;
  LSpaceIdx: Integer;
  LTestIndex: Integer;
  LTestLocation: TTestLocation;
begin
  Result := '';
  if not Assigned(ANode) then Exit;

  if (ANode.Data <> nil) and Assigned(FTestLocations) then
  begin
    LTestIndex := Integer(ANode.Data) - 1;
    if (LTestIndex >= 0) and (LTestIndex < FTestLocations.Count) then
    begin
      LTestLocation := FTestLocations[LTestIndex];
      Result := LTestLocation.ClassName + '.' + LTestLocation.MethodName;
      Exit;
    end;
  end;

  if FGroupingMode = tgmStatus then
  begin
    if ANode.Parent <> nil then
      Result := ANode.Text // Under status grouping, leaf nodes hold 'ClassName.MethodName'
    else
      Result := '';
    Exit;
  end;

  if ANode.Parent = nil then
  begin
    LParentText := ANode.Text;
    LSpaceIdx := LParentText.IndexOf(' (');
    if LSpaceIdx > 0 then
      Result := LParentText.Substring(0, LSpaceIdx)
    else
      Result := LParentText;
  end
  else
  begin
    LParentText := ANode.Parent.Text;
    LSpaceIdx := LParentText.IndexOf(' (');
    if LSpaceIdx > 0 then
      LParentText := LParentText.Substring(0, LSpaceIdx);
    Result := LParentText + '.' + ANode.Text;
  end;
end;

procedure TFormDextTestRunner.FilterEditChange(Sender: TObject);
begin
  if (FActiveSession <> nil) and (FActiveSession.ClearFilterButton <> nil) then
    FActiveSession.ClearFilterButton.Visible := Trim(ActiveFilterEdit.Text) <> '';
  RefreshTreeView;
end;

procedure TFormDextTestRunner.LayoutMenuClick(Sender: TObject);
begin
  if Sender is TMenuItem then
  begin
    TabbedLayoutMenuItem.Checked := Sender = TabbedLayoutMenuItem;
    SplitBottomLayoutMenuItem.Checked := Sender = SplitBottomLayoutMenuItem;
    SplitRightLayoutMenuItem.Checked := Sender = SplitRightLayoutMenuItem;
    ApplyLayout(TTestExplorerLayout(TMenuItem(Sender).Tag));
  end;
end;

procedure TFormDextTestRunner.GroupingMenuClick(Sender: TObject);
var
  IniFile: TMemIniFile;
begin
  if Sender is TMenuItem then
  begin
    GroupByClassMenuItem.Checked := Sender = GroupByClassMenuItem;
    GroupByTestStatusMenuItem.Checked := Sender = GroupByTestStatusMenuItem;

    FGroupingMode := TTestGroupingMode(TMenuItem(Sender).Tag - 100);

    // Save grouping mode to ini file
    try
      IniFile := TMemIniFile.Create(TPath.Combine(TPath.GetHomePath, 'DextTestExplorer.ini'));
      try
        IniFile.WriteInteger('Grouping', 'Mode', Ord(FGroupingMode));
      finally
        IniFile.Free;
      end;
    except
    end;

    RefreshTreeView;
  end;
end;

function TFormDextTestRunner.ActiveFilterEdit: TEdit;
begin
  if FActiveSession <> nil then
    Result := FActiveSession.FilterEdit
  else
    Result := nil;
end;

procedure TFormDextTestRunner.ClearFilterButtonClick(Sender: TObject);
var
  LActiveFilter: TEdit;
begin
  LActiveFilter := ActiveFilterEdit;
  if Assigned(LActiveFilter) then
  begin
    LActiveFilter.Text := '';
    LActiveFilter.SetFocus;
  end;
end;

procedure TFormDextTestRunner.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  ActiveFilter: TEdit;
begin
  if (Key = Ord('F')) and (ssCtrl in Shift) then
  begin
    ActiveFilter := ActiveFilterEdit;
    if Assigned(ActiveFilter) then
    begin
      ActiveFilter.SetFocus;
      Key := 0;
    end;
  end
  else if Key = VK_ESCAPE then
  begin
    ActiveFilter := ActiveFilterEdit;
    if Assigned(ActiveFilter) and (ActiveFilter.Text <> '') then
    begin
      ActiveFilter.Text := '';
      Key := 0;
    end;
  end;
end;

procedure TFormDextTestRunner.ApplyLayout(ALayout: TTestExplorerLayout);
var
  IniFile: TMemIniFile;
begin
  FCurrentLayout := ALayout;

  try
    IniFile := TMemIniFile.Create(TPath.Combine(TPath.GetHomePath, 'DextTestExplorer.ini'));
    try
      IniFile.WriteInteger('Layout', 'Mode', Ord(ALayout));
      IniFile.UpdateFile;
    finally
      IniFile.Free;
    end;
  except
    // ignore
  end;

  DetailsMemo.Align := alNone;
  InspectorScroll.Align := alNone;
  FInspectorSplitter.Visible := False;

  case ALayout of
    telCompact:
    begin
      NameSplitter.Align := alBottom;
      NameSplitter.Cursor := crVSplit;
      DetailsPanel.Align := alBottom;
      DetailsPanel.Height := 220;

      DetailsPageControl.Visible := True;
      DetailsMemo.Parent := ConsoleTab;
      DetailsMemo.Align := alClient;
      DetailsMemo.AlignWithMargins := False;
      InspectorScroll.Parent := InspectorTab;
      InspectorScroll.Align := alClient;
      InspectorScroll.AlignWithMargins := False;
      NameSplitter.Top := InspectorScroll.Top - NameSplitter.Height;
    end;

    telSplitBottom:
    begin
      NameSplitter.Align := alBottom;
      NameSplitter.Cursor := crVSplit;
      DetailsPanel.Align := alBottom;
      DetailsPanel.Height := 150;

      DetailsPageControl.Visible := False;

      DetailsMemo.Parent := DetailsPanel;
      DetailsMemo.Align := alLeft;
      DetailsMemo.Width := DetailsPanel.Width div 2;
      DetailsMemo.AlignWithMargins := True;
      DetailsMemo.Margins.Left := 6;
      DetailsMemo.Margins.Right := 0;
      DetailsMemo.Margins.Top := 6;
      DetailsMemo.Margins.Bottom := 6;

      FInspectorSplitter.Parent := DetailsPanel;
      FInspectorSplitter.Align := alLeft;
      FInspectorSplitter.Cursor := crHSplit;
      FInspectorSplitter.Width := 6;
      FInspectorSplitter.Visible := True;

      InspectorScroll.Parent := DetailsPanel;
      InspectorScroll.Align := alClient;
      InspectorScroll.AlignWithMargins := True;
      InspectorScroll.Margins.Left := 0;
      InspectorScroll.Margins.Right := 6;
      InspectorScroll.Margins.Top := 6;
      InspectorScroll.Margins.Bottom := 6;
      NameSplitter.Top := InspectorScroll.Top - NameSplitter.Height;
    end;

    telSplitRight:
    begin
      NameSplitter.Align := alRight;
      NameSplitter.Cursor := crHSplit;
      DetailsPanel.Align := alRight;
      DetailsPanel.Width := 320;

      DetailsPageControl.Visible := False;

      DetailsMemo.Parent := DetailsPanel;
      DetailsMemo.Align := alBottom;
      DetailsMemo.Height := DetailsPanel.Height div 2;
      DetailsMemo.AlignWithMargins := True;
      DetailsMemo.Margins.Left := 6;
      DetailsMemo.Margins.Right := 6;
      DetailsMemo.Margins.Top := 0;
      DetailsMemo.Margins.Bottom := 6;

      FInspectorSplitter.Parent := DetailsPanel;
      FInspectorSplitter.Align := alBottom;
      FInspectorSplitter.Cursor := crVSplit;
      FInspectorSplitter.Height := 6;
      FInspectorSplitter.Visible := True;

      InspectorScroll.Parent := DetailsPanel;
      InspectorScroll.Align := alClient;
      InspectorScroll.AlignWithMargins := True;
      InspectorScroll.Margins.Left := 0;
      InspectorScroll.Margins.Right := 0;
      InspectorScroll.Margins.Top := 6;
      InspectorScroll.Margins.Bottom := 0;
    end;
  end;

  // Ensure correct Z-order of aligned controls to make Splitter work correctly
  DetailsPanel.SendToBack;
  NameSplitter.SendToBack;
end;

procedure TFormDextTestRunner.RefreshTreeView;
var
  Filter: string;
  i: Integer;
  TestLocation: TTestLocation;
  FixtureNode, MethodNode: TTreeNode;
  ClassMatches: Boolean;
  MethodMatches: Boolean;
  FixtureTestsCount: TDictionary<string, Integer>;
  ActiveFilterEdit: TEdit;
  FailedNode, PassedNode, SkippedNode, IdleNode: TTreeNode;
  FullTestName: string;
  DetailInfo: TTestDetailInfo;
  Status: string;
  TargetRoot: TTreeNode;
  FixtureNodeCache: TDictionary<string, TTreeNode>;
begin
  TestsTreeView.Items.BeginUpdate;
  try
    TestsTreeView.Items.Clear;
    InitializeGroupSummaries;
    FixtureNodeCache := TDictionary<string, TTreeNode>.Create;
    try
    Filter := '';
    ActiveFilterEdit := Self.ActiveFilterEdit;
    if Assigned(ActiveFilterEdit) then
      Filter := Trim(ActiveFilterEdit.Text);

    if FGroupingMode = tgmStatus then
    begin
      FailedNode := nil;
      PassedNode := nil;
      SkippedNode := nil;
      IdleNode := nil;

      for i := 0 to FTestLocations.Count - 1 do
      begin
        TestLocation := FTestLocations[i];
        ClassMatches := (Filter = '') or TestLocation.ClassName.ToLower.Contains(Filter.ToLower);
        MethodMatches := (Filter = '') or TestLocation.MethodName.ToLower.Contains(Filter.ToLower);

        if ClassMatches or MethodMatches then
        begin
          FullTestName := TestLocation.ClassName + '.' + TestLocation.MethodName;
          Status := 'Idle';
          if FTestDetails.TryGetValue(FullTestName, DetailInfo) then
            Status := DetailInfo.Status;

          if SameText(Status, 'Failed') or SameText(Status, 'Error') then
          begin
            if not Assigned(FailedNode) then
            begin
              FailedNode := TestsTreeView.Items.AddChild(nil, 'Failed');
              FailedNode.ImageIndex := 2;
              FailedNode.SelectedIndex := 2;
              if Filter <> '' then FailedNode.Expanded := True;
            end;
            TargetRoot := FailedNode;
          end
          else if SameText(Status, 'Passed') or SameText(Status, 'Success') then
          begin
            if not Assigned(PassedNode) then
            begin
              PassedNode := TestsTreeView.Items.AddChild(nil, 'Passed');
              PassedNode.ImageIndex := 1;
              PassedNode.SelectedIndex := 1;
              if Filter <> '' then PassedNode.Expanded := True;
            end;
            TargetRoot := PassedNode;
          end
          else if SameText(Status, 'Skipped') then
          begin
            if not Assigned(SkippedNode) then
            begin
              SkippedNode := TestsTreeView.Items.AddChild(nil, 'Skipped');
              SkippedNode.ImageIndex := 0;
              SkippedNode.SelectedIndex := 0;
              if Filter <> '' then SkippedNode.Expanded := True;
            end;
            TargetRoot := SkippedNode;
          end
          else
          begin
            if not Assigned(IdleNode) then
            begin
              IdleNode := TestsTreeView.Items.AddChild(nil, 'Idle');
              IdleNode.ImageIndex := 0;
              IdleNode.SelectedIndex := 0;
              if Filter <> '' then IdleNode.Expanded := True;
            end;
            TargetRoot := IdleNode;
          end;

          MethodNode := TestsTreeView.Items.AddChild(TargetRoot, TestLocation.ClassName + '.' + TestLocation.MethodName);
          MethodNode.Data := Pointer(i + 1);

          if SameText(Status, 'Failed') or SameText(Status, 'Error') then
          begin
            MethodNode.ImageIndex := 2;
            MethodNode.SelectedIndex := 2;
          end
          else if SameText(Status, 'Passed') or SameText(Status, 'Success') then
          begin
            MethodNode.ImageIndex := 1;
            MethodNode.SelectedIndex := 1;
          end;
        end;
      end;
    end
    else
    begin
      FixtureTestsCount := TDictionary<string, Integer>.Create;
      try
        for i := 0 to FTestLocations.Count - 1 do
        begin
          TestLocation := FTestLocations[i];
          ClassMatches := (Filter = '') or TestLocation.ClassName.ToLower.Contains(Filter.ToLower);
          MethodMatches := (Filter = '') or TestLocation.MethodName.ToLower.Contains(Filter.ToLower);

          if ClassMatches or MethodMatches then
          begin
            if FixtureTestsCount.ContainsKey(TestLocation.ClassName) then
              FixtureTestsCount[TestLocation.ClassName] := FixtureTestsCount[TestLocation.ClassName] + 1
            else
              FixtureTestsCount.Add(TestLocation.ClassName, 1);
          end;
        end;

        for i := 0 to FTestLocations.Count - 1 do
        begin
          TestLocation := FTestLocations[i];
          ClassMatches := (Filter = '') or TestLocation.ClassName.ToLower.Contains(Filter.ToLower);
          MethodMatches := (Filter = '') or TestLocation.MethodName.ToLower.Contains(Filter.ToLower);

          if ClassMatches or MethodMatches then
          begin
            if not FixtureNodeCache.TryGetValue(TestLocation.ClassName, FixtureNode) then
            begin
              FixtureNode := TestsTreeView.Items.AddChild(nil, TestLocation.ClassName);
              FixtureNode.ImageIndex := 3;
              FixtureNode.SelectedIndex := 3;
              FixtureNodeCache.Add(TestLocation.ClassName, FixtureNode);
              if Filter <> '' then FixtureNode.Expanded := True;
            end;

            MethodNode := TestsTreeView.Items.AddChild(FixtureNode, TestLocation.MethodName);
            MethodNode.Data := Pointer(i + 1);

            FullTestName := TestLocation.ClassName + '.' + TestLocation.MethodName;
            Status := 'Idle';
            if FTestDetails.TryGetValue(FullTestName, DetailInfo) then
              Status := DetailInfo.Status;

            if SameText(Status, 'Failed') or SameText(Status, 'Error') then
            begin
              MethodNode.ImageIndex := 2;
              MethodNode.SelectedIndex := 2;
            end
            else if SameText(Status, 'Passed') or SameText(Status, 'Success') then
            begin
              MethodNode.ImageIndex := 1;
              MethodNode.SelectedIndex := 1;
            end
            else if SameText(Status, 'Skipped') then
            begin
              MethodNode.ImageIndex := 0;
              MethodNode.SelectedIndex := 0;
            end
            else
            begin
              MethodNode.ImageIndex := 0;
              MethodNode.SelectedIndex := 0;
            end;
          end;
        end;
      finally
        FixtureTestsCount.Free;
      end;
    end;

    finally
      FixtureNodeCache.Free;
    end;
  finally
    TestsTreeView.Items.EndUpdate;
  end;
end;

procedure TFormDextTestRunner.TestsTreeViewAdvancedCustomDrawItem(Sender: TCustomTreeView; Node: TTreeNode; State: TCustomDrawState; Stage: TCustomDrawStage; var PaintImages, DefaultDraw: Boolean);
var
  LBtnRect: TRect;
  LRect: TRect;
  LTextX, LTextY: Integer;
  LClassName: string;
  LCountText: string;
  LFailedCount: Integer;
  LPassedCount: Integer;
  LTotalDuration: Double;
  LHasDuration: Boolean;
  LFullTestName: string;
  LInfo: TTestDetailInfo;
  LDurText: string;
  LErrText: string;
  LSummary: TGroupSummaryInfo;
begin
  DefaultDraw := True;

  if (Stage = cdPrePaint) and (Node <> nil) then
  begin
    if not (cdsSelected in State) then
    begin
      Sender.Canvas.Brush.Color := TTreeView(Sender).Color;
      Sender.Canvas.Font.Color := TTreeView(Sender).Font.Color;
    end;

    if Node.Parent = nil then
      Sender.Canvas.Font.Style := [fsBold]
    else
      Sender.Canvas.Font.Style := [];
  end;

  if (Stage = cdPostPaint) and (Node <> nil) then
  begin
    Sender.Canvas.Brush.Style := bsClear;
    LRect := Node.DisplayRect(True);
    LTextX := LRect.Right + 6;
    LTextY := LRect.Top + (LRect.Height - Sender.Canvas.TextHeight('W')) div 2;

    if Node.Parent = nil then
    begin
      LClassName := Node.Text;
      LFailedCount := 0;
      LPassedCount := 0;
      LTotalDuration := 0;
      LHasDuration := False;
      if Assigned(FGroupSummaries) and FGroupSummaries.TryGetValue(LClassName, LSummary) then
      begin
        LFailedCount := LSummary.FailedCount;
        LPassedCount := LSummary.PassedCount;
        LTotalDuration := LSummary.DurationMs;
        LHasDuration := LSummary.DurationMs > 0;
      end;

      // Draw (N Tests in X ms) and execution status
      Sender.Canvas.Font.Color := clGrayText;
      Sender.Canvas.Font.Style := [];

      if LHasDuration then
        LCountText := ' (' + Node.Count.ToString + ' Tests in ' + Format('%.4f ms', [LTotalDuration]) + ')'
      else
        LCountText := ' (' + Node.Count.ToString + ' Tests)';
      Sender.Canvas.TextOut(LTextX, LTextY, LCountText);
      LTextX := LTextX + Sender.Canvas.TextWidth(LCountText) + 6;

      if LFailedCount > 0 then
      begin
        Sender.Canvas.Font.Color := TColor($4444EF); // Red BGR
        Sender.Canvas.TextOut(LTextX, LTextY, 'Failed: ' + LFailedCount.ToString + ' tests failed');
      end
      else if (LPassedCount > 0) and (LPassedCount = Node.Count) then
      begin
        Sender.Canvas.Font.Color := TColor($5EC522); // Green BGR
        Sender.Canvas.TextOut(LTextX, LTextY, 'Success');
      end;
    end
    else
    begin
      LFullTestName := GetNodeFullTestName(Node);
      if FTestDetails.TryGetValue(LFullTestName, LInfo) then
      begin
        if (LInfo.Status <> '') and not SameText(LInfo.Status, 'Idle') then
        begin
          if LInfo.DurationMs < 1.0 then
            LDurText := Format('[%.3f ms]', [LInfo.DurationMs])
          else
            LDurText := Format('[%.2f ms]', [LInfo.DurationMs]);

          Sender.Canvas.Font.Color := clGrayText;
          Sender.Canvas.Font.Style := [];
          Sender.Canvas.TextOut(LTextX, LTextY, LDurText);
          LTextX := LTextX + Sender.Canvas.TextWidth(LDurText) + 6;

          if SameText(LInfo.Status, 'Passed') then
          begin
            Sender.Canvas.Font.Color := TColor($5EC522); // Green BGR
            Sender.Canvas.TextOut(LTextX, LTextY, 'Success');
          end
          else if SameText(LInfo.Status, 'Failed') or SameText(LInfo.Status, 'Error') then
          begin
            Sender.Canvas.Font.Color := TColor($4444EF); // Red BGR
            LErrText := 'Failed';
            if LInfo.ErrorMessage <> '' then
              LErrText := 'Failed: ' + LInfo.ErrorMessage.Replace(#13, '').Replace(#10, ' ');
            if Length(LErrText) > 60 then
              LErrText := Copy(LErrText, 1, 57) + '...';
            Sender.Canvas.TextOut(LTextX, LTextY, LErrText);
          end;
        end;
      end;

      if Node = FHoverNode then
      begin
        LBtnRect := GetRunButtonRect(Node);
        Sender.Canvas.Brush.Color := TColor($E7FCDC); // Light Green BGR
        Sender.Canvas.Pen.Color := TColor($5EC522); // Green BGR
        Sender.Canvas.RoundRect(LBtnRect.Left, LBtnRect.Top, LBtnRect.Right, LBtnRect.Bottom, 4, 4);
        Sender.Canvas.Font.Color := TColor($3D8015); // Dark Green BGR
        Sender.Canvas.Font.Size := 7;
        Sender.Canvas.Font.Style := [fsBold];
        Sender.Canvas.Brush.Style := bsClear;
        DrawText(Sender.Canvas.Handle, #$25B6, -1, LBtnRect, DT_CENTER or DT_VCENTER or DT_SINGLELINE);
      end;
    end;
  end;
end;

procedure TFormDextTestRunner.DebugSelectedClick(Sender: TObject);
var
  LNode: TTreeNode;
  LProj: IOTAProject;
  LNTAServices: INTAServices;
  LFoundAction: TContainedAction;
  LParams: string;
  LIsPackage: Boolean;
  LOutput: string;
  LExeFile: string;
  LModuleServices: IOTAModuleServices;
  LGroup: IOTAProjectGroup;
  LProjInfo: TDextProjectInfo;
  SaveServices: IOTAModuleServices;
  I: Integer;
  Act: TContainedAction;
begin
  LNode := TestsTreeView.Selected;
  if not Assigned(LNode) then Exit;

  LProjInfo := TDextProjectInfo(ProjectsComboBox.Items.Objects[ProjectsComboBox.ItemIndex]);
  if not Assigned(LProjInfo) then Exit;
  LProj := GetProjectByFileName(LProjInfo.FileName);
  if not Assigned(LProj) then Exit;

  // Synchronize IDE Active Project
  if Supports(BorlandIDEServices, IOTAModuleServices, LModuleServices) and Assigned(LModuleServices) then
  begin
    LGroup := LModuleServices.MainProjectGroup;
    if Assigned(LGroup) and (LGroup.ActiveProject <> LProj) then
    begin
      LGroup.ActiveProject := LProj;
    end;
  end;

  ClearTestStatus;
  DetailsMemo.Clear;
  FTotalTests := 0;
  FCompletedTests := 0;
  if Assigned(ProgressPanel) then
  begin
    ProgressBar.Position := 0;
    ProgressBar.Max := 100;
    ProgressLabel.Caption := '...';
    ProgressPanel.Visible := True;
  end;
  // Focus Console Log
  if Assigned(DetailsPageControl) and Assigned(ConsoleTab) then
    DetailsPageControl.ActivePage := ConsoleTab;
  LogMsg('Compiling project (Debug): ' + ExtractFileName(FActiveProjectFile));

  // Save all modified IDE files before compiling.
  if Supports(BorlandIDEServices, IOTAModuleServices, SaveServices) then
  begin
    LogMsg('Saving all modified files...');
    SaveServices.SaveAll;
  end;

  LIsPackage := False;
  LOutput := '';
  GetProjectTargetInfo(FActiveProjectFile, LIsPackage, LOutput);
  LExeFile := ResolveExePath(FActiveProjectFile, LOutput);

  if not CompileProjectDirect(FActiveProjectFile) then
  begin
    LogMsg('Direct DCC compile failed or bypassed. Falling back to IDE make...');
    LProj.ProjectBuilder.BuildProject(cmOTAMake, False, True);
  end;

  if not FileExists(LExeFile) then
  begin
    LogMsg('Error: Executable not found at ' + LExeFile);
    Exit;
  end;

  LParams := Format('--port %d -no-wait', [FServer.Port]);
  FServer.SelectedTestsJSON := '["' + GetNodeFullTestName(LNode) + '"]';

  LogMsg('Starting debugger with parameters: ' + LParams);
  LProj.ProjectOptions.Values['RunParams'] := LParams;

  LFoundAction := nil;
  if Supports(BorlandIDEServices, INTAServices, LNTAServices) then
  begin
    if LNTAServices.ActionList <> nil then
    begin
      for I := 0 to LNTAServices.ActionList.ActionCount - 1 do
      begin
        Act := LNTAServices.ActionList.Actions[I];
        if SameText(Act.Name, 'actRun') or SameText(Act.Name, 'actRunRun') or
           SameText(Act.Name, 'actRunProgram') or (Act.ShortCut = ShortCut(VK_F9, [])) then
        begin
          LFoundAction := Act;
          Break;
        end;
      end;
    end;
  end;

  if LFoundAction <> nil then
  begin
    TThread.Queue(nil, TThreadProcedure(procedure
      begin
        LFoundAction.Execute;
      end));
  end
  else
  begin
    LogMsg('Warning: Could not trigger debugger automatically.');
    LogMsg('Please press F9 (Run) manually in the IDE to start debugging.');
  end;
end;

procedure TFormDextTestRunner.RefreshButtonClick(Sender: TObject);
begin
  RefreshProjects;
end;

procedure TFormDextTestRunner.SetActiveSession(ASession: TTestSession);
var
  LThemingServices: IOTAIDEThemingServices;
  ActiveIndex: Integer;
  I: Integer;
  ProjInfo: TDextProjectInfo;
begin
  if ASession = nil then Exit;
  FActiveSession := ASession;

  TestsTreeView := ASession.TreeView;
  FTestLocations := ASession.TestLocations;
  FActiveProjectFile := ASession.ActiveProjectFile;

  if ProjectsComboBox.Items.Count > 0 then
  begin
    ActiveIndex := -1;
    for I := 0 to ProjectsComboBox.Items.Count - 1 do
    begin
      ProjInfo := TDextProjectInfo(ProjectsComboBox.Items.Objects[I]);
      if Assigned(ProjInfo) and (ProjInfo.FileName = FActiveProjectFile) then
      begin
        ActiveIndex := I;
        Break;
      end;
    end;
    ProjectsComboBox.ItemIndex := ActiveIndex;
  end;

  if Supports(BorlandIDEServices, IOTAIDEThemingServices, LThemingServices) then
  begin
    if LThemingServices.IDEThemingEnabled then
    begin
      TestsTreeView.Color := LThemingServices.StyleServices.GetSystemColor(clWindow);
      TestsTreeView.Font.Color := LThemingServices.StyleServices.GetSystemColor(clWindowText);
    end;
  end;
end;

procedure TFormDextTestRunner.SessionsPageControlChange(Sender: TObject);
var
  I: Integer;
begin
  if SessionsPageControl.ActivePage = nil then Exit;

  for I := 0 to FSessions.Count - 1 do
  begin
    if FSessions[I].TabSheet = SessionsPageControl.ActivePage then
    begin
      SetActiveSession(FSessions[I]);
      Break;
    end;
  end;
end;

procedure TFormDextTestRunner.CreateNewSession(const AName: string);
var
  LSession: TTestSession;
begin
  LSession := TTestSession.Create(SessionsPageControl, AName);

  LSession.TreeView.Images := TestsTreeView.Images;
  LSession.TreeView.Checkboxes := True;
  LSession.TreeView.PopupMenu := TestsTreeView.PopupMenu;
  LSession.TreeView.OnMouseMove := TestsTreeViewMouseMove;
  LSession.TreeView.OnMouseLeave := TestsTreeViewMouseLeave;
  LSession.TreeView.OnMouseDown := TestsTreeViewMouseDown;
  LSession.TreeView.OnMouseUp := TestsTreeViewMouseUp;
  LSession.TreeView.OnAdvancedCustomDrawItem := TestsTreeViewAdvancedCustomDrawItem;
  LSession.TreeView.OnDblClick := TestsTreeViewDblClick;
  LSession.TreeView.OnChange := TestsTreeViewChange;

  FSessions.Add(LSession);

  SessionsPageControl.ActivePage := LSession.TabSheet;
  SetActiveSession(LSession);

  RefreshProjects;
  UpdateTabVisibility;
end;

procedure TFormDextTestRunner.CloseSession(ASession: TTestSession);
var
  ActiveIndex: Integer;
  NextIndex: Integer;
begin
  if FSessions.Count <= 1 then Exit;

  ActiveIndex := FSessions.IndexOf(ASession);

  if FActiveSession = ASession then
  begin
    NextIndex := ActiveIndex - 1;
    if NextIndex < 0 then NextIndex := 1;
    SetActiveSession(FSessions[NextIndex]);
    SessionsPageControl.ActivePage := FActiveSession.TabSheet;
  end;

  FSessions.Remove(ASession);
  UpdateTabVisibility;
end;

procedure TFormDextTestRunner.SessionTabContextPopup(Sender: TObject; MousePos: TPoint; var Handled: Boolean);
var
  LPageControl: TPageControl;
  LTabIndex: Integer;
  LPos: TPoint;
  Menu: TPopupMenu;
  Item: TMenuItem;
begin
  LPageControl := Sender as TPageControl;
  LPos := MousePos;

  LTabIndex := LPageControl.IndexOfTabAt(LPos.X, LPos.Y);
  if LTabIndex >= 0 then
  begin
    LPageControl.ActivePage := LPageControl.Pages[LTabIndex];
    SessionsPageControlChange(LPageControl);

    Menu := TPopupMenu.Create(Self);
    Item := TMenuItem.Create(Menu);
    Item.Caption := 'Close Session';
    Item.OnClick := CloseActiveSessionClick;
    Menu.Items.Add(Item);

    LPos := LPageControl.ClientToScreen(LPos);
    Menu.Popup(LPos.X, LPos.Y);
    Handled := True;
  end;
end;

procedure TFormDextTestRunner.CloseActiveSessionClick(Sender: TObject);
begin
  CloseSession(FActiveSession);
end;

function ExtractTagValue(const AContent, ATagName: string): string;
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

function GetDelphiProductVersion: string;
var
  LBinDir: string;
  LSplit: TArray<string>;
  I: Integer;
begin
  LBinDir := ExtractFilePath(ParamStr(0));
  LSplit := LBinDir.Split(['\']);
  for I := 0 to Length(LSplit) - 1 do
  begin
    if SameText(LSplit[I], 'Studio') and (I < Length(LSplit) - 1) then
      Exit(LSplit[I + 1]);
  end;
  Result := '23.0';
end;

function ExecuteAndCapture(const ACommandLine, AWorkDir: string; out AOutput: string): Boolean;
var
  LSa: TSecurityAttributes;
  LReadPipe, LWritePipe: THandle;
  LSi: TStartUpInfo;
  LPi: TProcessInformation;
  LBuffer: array[0..4095] of AnsiChar;
  LBytesRead: DWORD;
  LSuccess: Boolean;
  LCmdLine: string;
  LExitCode: DWORD;
begin
  Result := False;
  AOutput := '';

  LSa.nLength := SizeOf(TSecurityAttributes);
  LSa.bInheritHandle := True;
  LSa.lpSecurityDescriptor := nil;

  if not CreatePipe(LReadPipe, LWritePipe, @LSa, 0) then Exit;

  try
    SetHandleInformation(LReadPipe, HANDLE_FLAG_INHERIT, 0);

    ZeroMemory(@LSi, SizeOf(TStartUpInfo));
    LSi.cb := SizeOf(TStartUpInfo);
    LSi.hStdOutput := LWritePipe;
    LSi.hStdError := LWritePipe;
    LSi.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
    LSi.wShowWindow := SW_HIDE;

    LCmdLine := ACommandLine;
    UniqueString(LCmdLine);

    if CreateProcess(nil, PChar(LCmdLine), nil, nil, True, CREATE_NO_WINDOW, nil,
      Pointer(AWorkDir), LSi, LPi) then
    begin
      CloseHandle(LWritePipe);
      LWritePipe := 0;

      repeat
        LSuccess := ReadFile(LReadPipe, LBuffer[0], SizeOf(LBuffer) - 1, LBytesRead, nil);
        if LBytesRead > 0 then
        begin
          LBuffer[LBytesRead] := #0;
          AOutput := AOutput + string(AnsiString(LBuffer));
        end;
      until not LSuccess or (LBytesRead = 0);

      WaitForSingleObject(LPi.hProcess, INFINITE);

      LExitCode := 0;
      GetExitCodeProcess(LPi.hProcess, LExitCode);
      Result := (LExitCode = 0);

      CloseHandle(LPi.hProcess);
      CloseHandle(LPi.hThread);
    end;
  finally
    if LReadPipe <> 0 then CloseHandle(LReadPipe);
    if LWritePipe <> 0 then CloseHandle(LWritePipe);
  end;
end;

function TFormDextTestRunner.CompileProjectDirect(const AProjFile: string): Boolean;
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
    LogMsg('Error: DPR/DPK file not found: ' + DprFile);
    Exit;
  end;

  DccExe := ExtractFilePath(ParamStr(0)) + 'dcc32.exe';
  if not FileExists(DccExe) then
  begin
    LogMsg('Error: Compiler not found: ' + DccExe);
    Exit;
  end;

  try
    Content := TFile.ReadAllText(AProjFile);
  except
    on E: Exception do
    begin
      LogMsg('Error reading project file: ' + E.Message);
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

  LogMsg('DCC Command: ' + CmdLine);

  if ExecuteAndCapture(CmdLine, WorkDir, Output) then
  begin
    LogMsg(Output);
    LogMsg('Direct compilation successful.');
    Result := True;
  end
  else
  begin
    LogMsg(Output);
    LogMsg('Direct compilation failed.');
  end;
end;

procedure TFormDextTestRunner.TryLoadCoverage;
var
  LCovPath: string;
  LRoot: string;
  LTestsDir: string;
  LFiles: TArray<string>;
  LFile: string;
begin
  LCovPath := TPath.Combine(ExtractFilePath(FActiveProjectFile), 'dext_coverage.xml');
  if not FileExists(LCovPath) then
    LCovPath := TPath.Combine(TPath.GetDirectoryName(ExtractFilePath(FActiveProjectFile)), 'dext_coverage.xml');

  if not FileExists(LCovPath) then
  begin
    LRoot := TPath.GetDirectoryName(TPath.GetDirectoryName(ExtractFilePath(FActiveProjectFile)));
    LCovPath := TPath.Combine(TPath.Combine(LRoot, 'Tests'), 'test-results.xml');
  end;

  if not FileExists(LCovPath) then
  begin
    LTestsDir := 'c:\dev\Dext\DextRepository\Tests\Output';
    if TDirectory.Exists(LTestsDir) then
    begin
      LFiles := TDirectory.GetFiles(LTestsDir, '*.xml');
      for LFile in LFiles do
      begin
        try
          if TFile.ReadAllText(LFile).Contains('<coverage') then
          begin
            LCovPath := LFile;
            Break;
          end;
        except
          // ignore
        end;
      end;
    end;
  end;

  if FileExists(LCovPath) then
  begin
    LogMsg('Loading code coverage from: ' + LCovPath);
    TThread.Queue(nil, TThreadProcedure(procedure
      begin
        TCoverageManager.GetInstance.LoadCoverageFromXML(LCovPath);
      end));
  end
  else
  begin
    LogMsg('No code coverage report found.');
  end;
end;

procedure TFormDextTestRunner.RunImpactedTests(const ATests: TArray<string>);
var
  LJSON: string;
  I: Integer;
begin
  if Length(ATests) = 0 then Exit;

  LJSON := '[';
  for I := 0 to Length(ATests) - 1 do
  begin
    if I > 0 then LJSON := LJSON + ',';
    LJSON := LJSON + '"' + ATests[I] + '"';
  end;
  LJSON := LJSON + ']';

  FServer.SelectedTestsJSON := LJSON;
  RunActiveProjectTests('');
end;

procedure TFormDextTestRunner.HandleFileSaved(const AFileName: string);
begin
  if not SameText(ExtractFileExt(AFileName), '.pas') then Exit;
  if not Assigned(FPendingSaveFiles) then Exit;

  if FPendingSaveFiles.IndexOf(AFileName) < 0 then
    FPendingSaveFiles.Add(AFileName);

  if Assigned(FSaveTimer) then
  begin
    FSaveTimer.Enabled := False;
    FSaveTimer.Enabled := True;
  end;
end;

procedure TFormDextTestRunner.SaveTimerTimer(Sender: TObject);
var
  LTests: TList<TTestLocation>;
  LTest: TTestLocation;
  LIdx: Integer;
  LNode: TTreeNode;
  LFixtureNode: TTreeNode;
  LMethodNode: TTreeNode;
  LFile: string;
  I: Integer;
  ParentNode: TTreeNode;
begin
  if not Assigned(FSaveTimer) then Exit;
  FSaveTimer.Enabled := False;

  if not Assigned(FPendingSaveFiles) or (FPendingSaveFiles.Count = 0) then Exit;

  TestsTreeView.Items.BeginUpdate;
  try
    for I := 0 to FPendingSaveFiles.Count - 1 do
    begin
      LFile := FPendingSaveFiles[I];
      LTests := nil;
      if TTestASTScanner.ScanFile(LFile, LTests) then
      begin
        try
          // Remove existing tests in this file from our list and TreeView
          for LIdx := FTestLocations.Count - 1 downto 0 do
          begin
            if SameText(FTestLocations[LIdx].FileName, LFile) then
            begin
              LNode := FindNodeByPath(FTestLocations[LIdx].ClassName + '.' + FTestLocations[LIdx].MethodName);
              if not Assigned(LNode) then
                LNode := FindNodeByPath(FTestLocations[LIdx].MethodName);

              if Assigned(LNode) then
              begin
                ParentNode := LNode.Parent;
                LNode.Free;
                if Assigned(ParentNode) and (ParentNode.Count = 0) then
                  ParentNode.Free;
              end;
              FTestLocations.Delete(LIdx);
            end;
          end;

          // Add newly discovered tests
          for LTest in LTests do
          begin
            FTestLocations.Add(LTest);

            LFixtureNode := FindNodeByPath(LTest.ClassName);
            if not Assigned(LFixtureNode) then
            begin
              LFixtureNode := TestsTreeView.Items.AddChild(nil, LTest.ClassName);
              LFixtureNode.ImageIndex := 3;
              LFixtureNode.SelectedIndex := 3;
            end;

            LMethodNode := TestsTreeView.Items.AddChild(LFixtureNode, LTest.MethodName);
            LMethodNode.Data := Pointer(FTestLocations.Count);
            LMethodNode.ImageIndex := 0;
            LMethodNode.SelectedIndex := 0;
          end;
        finally
          LTests.Free;
        end;
      end;
    end;

    if FPendingSaveFiles.Count > 0 then
      ExpandTestsTreeView;
  finally
    TestsTreeView.Items.EndUpdate;
    FPendingSaveFiles.Clear;
  end;

  // Reset/Debounce the Idle timer upon saving a file
  if RunOnIdleCheckBox.Checked and Assigned(FIdleTimer) then
  begin
    FIdleTimer.Enabled := False;
    FIdleTimer.Enabled := True;
  end;

  if RunOnSaveCheckBox.Checked and not FRunningTests and not FWaitingForCompile and (FRunningProcessHandle = 0) then
  begin
    RunActiveProjectTests('', False);
  end;
end;

{ TTelemetryTracker }

class procedure TTelemetryTracker.RecordTestResult(const AProjectFile, ATestName, AStatus: string; ADurationMs: Integer); // ADurationMs remains Integer for storage
var
  LDir, LFile: string;
  LArray: TJSONArray;
  LObj: TJSONObject;
  LText: string;
begin
  if AProjectFile = '' then Exit;
  LDir := TPath.Combine(TPath.GetDirectoryName(AProjectFile), '.dext\testing');
  try
    ForceDirectories(LDir);
    LFile := TPath.Combine(LDir, 'history.json');

    LArray := nil;
    if FileExists(LFile) then
    begin
      try
        LText := TFile.ReadAllText(LFile, TEncoding.UTF8);
        LArray := TJSONObject.ParseJSONValue(LText) as TJSONArray;
      except
        // ignore parsing errors
      end;
    end;

    if LArray = nil then
      LArray := TJSONArray.Create;

    LObj := TJSONObject.Create;
    LObj.AddPair('testName', ATestName);
    LObj.AddPair('status', AStatus);
    LObj.AddPair('durationMs', TJSONNumber.Create(ADurationMs));
    LObj.AddPair('timestamp', DateTimeToStr(Now));
    LArray.AddElement(LObj);

    // Limit to last 1000 runs
    while LArray.Count > 1000 do
      LArray.Remove(0).Free;

    TFile.WriteAllText(LFile, LArray.ToJSON, TEncoding.UTF8);
    LArray.Free;
  except
    // ignore filesystem errors
  end;
end;

class procedure TTelemetryTracker.AnalyzeHistory(const AProjectFile: string; AMemo: TMemo);
var
  AvgDuration: Double;
  Directory, FileName: string;
  DurationMs: Integer;
  DurList: TList<Integer>;
  HasHeader: Boolean;
  i: Integer;
  IntPair: TPair<string, TList<Integer>>;
  IsFlaky: Boolean;
  IsRegression: Boolean;
  JsonArray: TJSONArray;
  JsonObj: TJSONObject;
  LastDuration: Integer;
  LastStatus: string;
  NameKey: string;
  Pair: TPair<string, TList<string>>;
  StatList: TList<string>;
  StatusesList: TList<string>;
  Sum: Integer;
  TestDurations: TDictionary<string, TList<Integer>>;
  TestName, LStatus: string;
  TestStatuses: TDictionary<string, TList<string>>;
  Text: string;
  Value: TJSONValue;
begin
  if (AProjectFile = '') or (AMemo = nil) then Exit;

  Directory := TPath.Combine(TPath.GetDirectoryName(AProjectFile), '.dext\testing');
  FileName := TPath.Combine(Directory, 'history.json');
  if not FileExists(FileName) then Exit;

  TestDurations := TDictionary<string, TList<Integer>>.Create;
  TestStatuses := TDictionary<string, TList<string>>.Create;
  try
    try
      Text := TFile.ReadAllText(FileName, TEncoding.UTF8);
      JsonArray := TJSONObject.ParseJSONValue(Text) as TJSONArray;
      if JsonArray = nil then Exit;

      try
        // 1. Group values by test name
        for i := 0 to JsonArray.Count - 1 do
        begin
          Value := JsonArray.Items[i];
          if Value is TJSONObject then
          begin
            JsonObj := TJSONObject(Value);
            if JsonObj.TryGetValue<string>('testName', TestName) then
            begin
              JsonObj.TryGetValue<string>('status', LStatus);
              JsonObj.TryGetValue<Integer>('durationMs', DurationMs);

              if not TestDurations.TryGetValue(TestName, DurList) then
              begin
                DurList := TList<Integer>.Create;
                TestDurations.Add(TestName, DurList);
              end;
              DurList.Add(DurationMs);

              StatList := nil;
              if not TestStatuses.TryGetValue(TestName, StatList) then
              begin
                StatList := TList<string>.Create;
                TestStatuses.Add(TestName, StatList);
              end;
              StatList.Add(LStatus);
            end;
          end;
        end;

        // 2. Perform regression and flakiness analysis
        HasHeader := False;
        for Pair in TestStatuses do
        begin
          NameKey := Pair.Key;
          StatusesList := Pair.Value;
          DurList := TestDurations[NameKey];

          IsFlaky := False;
          if StatusesList.Count >= 2 then
          begin
            LastStatus := StatusesList[0];
            for i := 1 to StatusesList.Count - 1 do
            begin
              if StatusesList[i] <> LastStatus then
              begin
                IsFlaky := True;
                Break;
              end;
            end;
          end;

          IsRegression := False;
          AvgDuration := 0.0;
          LastDuration := 0;
          if DurList.Count >= 3 then
          begin
            LastDuration := DurList[DurList.Count - 1];
            Sum := 0;
            for i := 0 to DurList.Count - 2 do
              Inc(Sum, DurList[i]);
            AvgDuration := Sum / (DurList.Count - 1);

            if (AvgDuration > 10) and (LastDuration > AvgDuration * 1.5) then
              IsRegression := True;
          end;

          if IsFlaky or IsRegression then
          begin
            if not HasHeader then
            begin
              AMemo.Lines.Add('');
              AMemo.Lines.Add('[ANALYTICS] --- TEST ANALYTICS ENGINE REPORT ---');
              HasHeader := True;
            end;

            if IsFlaky then
              AMemo.Lines.Add('   [FLAKY] TEST DETECTED: ' + NameKey + ' (status changes between Pass and Fail)');
            if IsRegression then
              AMemo.Lines.Add(Format('   [PERF REGRESSION] %s (Last: %dms, Avg: %.1fms)', [NameKey, LastDuration, AvgDuration]));
          end;
        end;

        if HasHeader then
          AMemo.Lines.Add('========================================');
      finally
        JsonArray.Free;
      end;
    except
      // ignore errors during analysis
    end;
  finally
    for IntPair in TestDurations do Pair.Value.Free;
    TestDurations.Free;
    for Pair in TestStatuses do Pair.Value.Free;
    TestStatuses.Free;
  end;
end;

procedure TFormDextTestRunner.ActionsButtonClick(Sender: TObject);
var
  ClickPoint: TPoint;
begin
  ClickPoint := ActionsButton.ClientToScreen(Point(0, ActionsButton.Height));
  ActionsPopupMenu.Popup(ClickPoint.X, ClickPoint.Y);
end;

procedure TFormDextTestRunner.UpdateTabVisibility;
begin
  SessionsPageControl.Pages[0].TabVisible := SessionsPageControl.PageCount > 1;
  if not SessionsPageControl.Pages[0].TabVisible then
    SessionsPageControl.ActivePageIndex := 0;
end;

procedure TFormDextTestRunner.AddSessionButtonClick(Sender: TObject);
begin
  CreateNewSession('Session ' + (FSessions.Count + 1).ToString);
end;

procedure TFormDextTestRunner.ExpandTestsTreeView;
begin
  if Assigned(TestsTreeView) then
  begin
    if TestsTreeView.Items.Count > 0 then
    begin
      TestsTreeView.Selected := TestsTreeView.Items[0];
      TestsTreeView.Items[0].MakeVisible;
      TestsTreeView.Invalidate;
    end;
    TestsTreeView.FullExpand;
    TestsTreeView.Invalidate;
  end;
end;

procedure TFormDextTestRunner.ResetSummaryLabels;
begin
  SummaryTotalLabel.Caption := 'Total: 0';
  SummarySelectedLabel.Caption := 'Selected: 0';
  SummarySuccessLabel.Caption := 'Passed: 0';
  SummaryFailedLabel.Caption := 'Failed: 0';
  SummarySkippedLabel.Caption := 'Skipped: 0';
  SummaryTimeLabel.Caption := 'Tests: 0.00 s';
  SummaryTotalTimeLabel.Caption := 'Total: 0.00 s';
  FTestExecutionDurationMs := 0;
end;

initialization
  LLogLock := TObject.Create;
{$IFDEF DEXT_TEST_EXPLORER_PERF_LOG}
  PerfLogLock := TObject.Create;
{$ENDIF}
  RegisterDockableForm;

finalization
  FreeAndNil(LLogLock);
{$IFDEF DEXT_TEST_EXPLORER_PERF_LOG}
  PerfLogLock.Free;
{$ENDIF}
  UnregisterDockableForm;

end.

