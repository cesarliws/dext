unit Grpc.EntityDataSet.Demo.Main.Form;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.Grids, Vcl.DBGrids, Vcl.StdCtrls, Vcl.ExtCtrls, Data.DB,
  Dext.Collections, Dext.Entity.DataSet, Dext.Entity.GrpcProvider,
  Dext.Serialization.Protobuf, Dext.Grpc.Codec, Dext.Grpc.Attributes,
  Dext.Web.Grpc.Server, Dext.Collections.Dict, Dext.Entity.Attributes;

type
  [GrpcMessage]
  TCompany = class
  private
    FId: Integer;
    FName: string;
    FCountry: string;
    FActive: Boolean;
  public
    constructor Create; overload;
    constructor Create(AId: Integer; const AName, ACountry: string; AActive: Boolean); overload;

    [PrimaryKey]
    [ProtoMember(1)]
    property Id: Integer read FId write FId;
    [ProtoMember(2)]
    property Name: string read FName write FName;
    [ProtoMember(3)]
    property Country: string read FCountry write FCountry;
    [ProtoMember(4)]
    property Active: Boolean read FActive write FActive;
  end;

  [GrpcMessage]
  TCompanyQueryRequest = class
  private
    FQuery: string;
  public
    [ProtoMember(1)]
    property Query: string read FQuery write FQuery;
  end;

  [GrpcMessage]
  TCompanyListResponse = class
  private
    FItems: IList<TCompany>;
  public
    constructor Create;
    [ProtoMember(1)]
    property Items: IList<TCompany> read FItems write FItems;
  end;

  [GrpcMessage]
  TCompanyChangeItem = class
  private
    FState: string; // 'Inserted', 'Modified', 'Deleted'
    FCompany: TCompany;
  public
    constructor Create; overload;
    constructor Create(const AState: string; ACompany: TCompany); overload;
    destructor Destroy; override;

    [ProtoMember(1)]
    property State: string read FState write FState;
    [ProtoMember(2)]
    property Company: TCompany read FCompany write FCompany;
  end;

  [GrpcMessage]
  TCompanyChangesRequest = class
  private
    FChanges: IList<TCompanyChangeItem>;
  public
    constructor Create;
    destructor Destroy; override;
    [ProtoMember(1)]
    property Changes: IList<TCompanyChangeItem> read FChanges write FChanges;
  end;

  [GrpcMessage]
  TCompanySaveResponse = class
  private
    FSuccess: Boolean;
    FMessage: string;
  public
    [ProtoMember(1)]
    property Success: Boolean read FSuccess write FSuccess;
    [ProtoMember(2)]
    property Message: string read FMessage write FMessage;
  end;

  [GrpcService('dext.services.CompanyService')]
  ICompanyService = interface(IInvokable)
    ['{B4A3C2D1-E0F6-7B8A-9C0D-1E2F3A4B5C6E}']
    [GrpcMethod('FetchAll')]
    function FetchAll(const ARequest: TCompanyQueryRequest): TCompanyListResponse;
    [GrpcMethod('ApplyChanges')]
    function ApplyChanges(const ARequest: TCompanyChangesRequest): TCompanySaveResponse;
  end;

  // Servidor Mock gRPC (Simula nosso banco de dados em memória)
  TCompanyService = class(TInterfacedObject, ICompanyService)
  private
    class var FDB: TList<TCompany>;
    class constructor Create;
    class destructor Destroy;
  public
    function FetchAll(const ARequest: TCompanyQueryRequest): TCompanyListResponse;
    function ApplyChanges(const ARequest: TCompanyChangesRequest): TCompanySaveResponse;
  end;

  // Custom data provider for TEntityDataSet
  TDemoGrpcProvider = class(TInterfacedObject,
    IEntityDataProvider<TCompany>)
  private
    FClient: TGrpcClient;
  public
    constructor Create(AClient: TGrpcClient);
    function FetchAll(const AQuery: string): TList<TCompany>;
    procedure ApplyChanges(const AList: TList<TCompany>);
  end;

  TFormMain = class(TForm)
    TopPanel: TPanel;
    LoadButton: TButton;
    AddButton: TButton;
    DeleteButton: TButton;
    SaveButton: TButton;
    CodeOnlyButton: TButton;
    LogsMemo: TMemo;
    CompanyDBGrid: TDBGrid;
    CompanyDataSource: TDataSource;
    ContentSplitter: TSplitter;
    procedure FormCreate(Sender: TObject);
    procedure LoadButtonClick(Sender: TObject);
    procedure AddButtonClick(Sender: TObject);
    procedure DeleteButtonClick(Sender: TObject);
    procedure SaveButtonClick(Sender: TObject);
    procedure CodeOnlyButtonClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    FDataSet: TEntityDataSet;
    FDispatcher: TDextGrpcDispatcher;
    FClient: TGrpcClient;
    FProvider: IEntityDataProvider<TCompany>;
    procedure Log(const AMsg: string);
  end;

var
  FormMain: TFormMain;

implementation

{$R *.dfm}

{ TCompany }

constructor TCompany.Create;
begin
  inherited Create;
end;

constructor TCompany.Create(AId: Integer; const AName, ACountry: string;
  AActive: Boolean);
begin
  FId := AId;
  FName := AName;
  FCountry := ACountry;
  FActive := AActive;
end;

{ TCompanyListResponse }

constructor TCompanyListResponse.Create;
begin
  inherited Create;
  FItems := TCollections.CreateList<TCompany>(True);
end;

{ TCompanyChangeItem }

constructor TCompanyChangeItem.Create;
begin
  inherited Create;
end;

constructor TCompanyChangeItem.Create(const AState: string;
  ACompany: TCompany);
begin
  FState := AState;
  FCompany := ACompany;
end;

destructor TCompanyChangeItem.Destroy;
begin
  FCompany.Free;
  inherited;
end;

{ TCompanyChangesRequest }

constructor TCompanyChangesRequest.Create;
begin
  inherited Create;
  FChanges := TCollections.CreateList<TCompanyChangeItem>(True);
end;

destructor TCompanyChangesRequest.Destroy;
begin
  inherited;
end;

{ TCompanyService }

class constructor TCompanyService.Create;
begin
  FDB := TList<TCompany>.Create;
  // Populate initial mock data
  FDB.Add(TCompany.Create(1, 'Google', 'USA', True));
  FDB.Add(TCompany.Create(2, 'Embarcadero', 'USA', True));
  FDB.Add(TCompany.Create(3, 'Dext Corp', 'Brazil', True));
end;

class destructor TCompanyService.Destroy;
var
  Item: TCompany;
begin
  for Item in FDB do
    Item.Free;
  FDB.Free;
end;

function TCompanyService.FetchAll(const ARequest: TCompanyQueryRequest):
  TCompanyListResponse;
var
  Item: TCompany;
begin
  Result := TCompanyListResponse.Create;
  for Item in FDB do
  begin
    Result.Items.Add(TCompany.Create(Item.Id, Item.Name, Item.Country,
      Item.Active));
  end;
end;

function TCompanyService.ApplyChanges(const ARequest: TCompanyChangesRequest): TCompanySaveResponse;
var
  Change: TCompanyChangeItem;
  DBItem: TCompany;
  Found: Boolean;
  i: Integer;
begin
  Result := TCompanySaveResponse.Create;
  try
    for Change in ARequest.Changes do
    begin
      if Change.State = 'Inserted' then
      begin
        FDB.Add(TCompany.Create(Change.Company.Id, Change.Company.Name,
          Change.Company.Country, Change.Company.Active));
      end
      else if Change.State = 'Modified' then
      begin
        Found := False;
        for DBItem in FDB do
        begin
          if DBItem.Id = Change.Company.Id then
          begin
            DBItem.Name := Change.Company.Name;
            DBItem.Country := Change.Company.Country;
            DBItem.Active := Change.Company.Active;
            Found := True;
            Break;
          end;
        end;
        if not Found then
          raise Exception.CreateFmt('Company ID %d not found for update',
            [Change.Company.Id]);
      end
      else if Change.State = 'Deleted' then
      begin
        for i := FDB.Count - 1 downto 0 do
        begin
          if FDB[i].Id = Change.Company.Id then
          begin
            FDB[i].Free;
            FDB.Delete(i);
            Break;
          end;
        end;
      end;
    end;
    Result.Success := True;
    Result.Message := 'Changes applied successfully to gRPC Mock Server!';
  except
    on E: Exception do
    begin
      Result.Success := False;
      Result.Message := 'Error: ' + E.Message;
    end;
  end;
end;

{ TDemoGrpcProvider }

constructor TDemoGrpcProvider.Create(AClient: TGrpcClient);
begin
  inherited Create;
  FClient := AClient;
end;

function TDemoGrpcProvider.FetchAll(const AQuery: string): TList<TCompany>;
var
  Req: TCompanyQueryRequest;
  Res: TCompanyListResponse;
  Item: TCompany;
begin
  Req := TCompanyQueryRequest.Create;
  Req.Query := AQuery;
  Res := TCompanyListResponse.Create;
  try
    FClient.CallMethod('dext.services.CompanyService', 'FetchAll', Req, Res);
    Result := TList<TCompany>.Create;
    for Item in Res.Items do
    begin
      Result.Add(TCompany.Create(Item.Id, Item.Name, Item.Country,
        Item.Active));
    end;
  finally
    Req.Free;
    Res.Free;
  end;
end;

procedure TDemoGrpcProvider.ApplyChanges(const AList: TList<TCompany>);
begin
  // Real implementation handled directly in the Save changes button for demo
end;

{ TFormMain }

procedure TFormMain.FormCreate(Sender: TObject);
begin
  // 1. Initialize In-process gRPC Server Dispatcher
  FDispatcher := TDextGrpcDispatcher.Create;
  FDispatcher.RegisterService(ICompanyService, TCompanyService);

  // 2. Initialize Client linked to dispatcher
  FClient := TGrpcClient.Create(FDispatcher);

  // 3. Initialize Custom Provider
  FProvider := TDemoGrpcProvider.Create(FClient);

  // 4. Setup TEntityDataSet
  FDataSet := TEntityDataSet.Create(Self);
  CompanyDataSource.DataSet := FDataSet;
  CompanyDBGrid.DataSource := CompanyDataSource;

  Log('gRPC server and client dispatcher loaded in memory.');
  Log('Ready to load data.');

  if FindCmdLineSwitch('auto') then
  begin
    Log('--- STARTING AUTOMATED TEST ---');
    LoadButtonClick(nil);
    AddButtonClick(nil);
    AddButtonClick(nil);
    AddButtonClick(nil);
    AddButtonClick(nil);
    if FDataSet.Locate('Id', 3, []) then
      DeleteButtonClick(nil);
    SaveButtonClick(nil);
    Log('--- AUTOMATED TEST FINISHED ---');
    Application.Terminate;
  end;
end;

procedure TFormMain.FormDestroy(Sender: TObject);
begin
  FClient.Free;
  FDispatcher.Free;
end;

procedure TFormMain.Log(const AMsg: string);
var
  Formatted: string;
begin
  Formatted := FormatDateTime('hh:nn:ss.zzz', Now) + ' - ' + AMsg;
  LogsMemo.Lines.Add(Formatted);
end;

procedure TFormMain.LoadButtonClick(Sender: TObject);
var
  Items: TList<TCompany>;
begin
  Log('Calling gRPC FetchAll...');
  Items := FProvider.FetchAll('');
  try
    FDataSet.Close;
    FDataSet.Load<TCompany>(Items, True); // DataSet takes ownership
    FDataSet.Open;
    Log(Format('Loaded %d companies into TEntityDataSet.', [Items.Count]));
  finally
    Items.Free;
  end;
end;

procedure TFormMain.AddButtonClick(Sender: TObject);
var
  NewId: Integer;
begin
  if not FDataSet.Active then
  begin
    ShowMessage('Dataset is not open. Please load data first.');
    Exit;
  end;

  // Basic auto-increment for demo
  NewId := 1;
  FDataSet.DisableControls;
  try
    FDataSet.First;
    while not FDataSet.Eof do
    begin
      if FDataSet.FieldByName('Id').AsInteger >= NewId then
        NewId := FDataSet.FieldByName('Id').AsInteger + 1;
      FDataSet.Next;
    end;
  finally
    FDataSet.EnableControls;
  end;

  FDataSet.Append;
  FDataSet.FieldByName('Id').AsInteger := NewId;
  FDataSet.FieldByName('Name').AsString := 'New Company ' + IntToStr(NewId);
  FDataSet.FieldByName('Country').AsString := 'Brazil';
  FDataSet.FieldByName('Active').AsBoolean := True;
  FDataSet.Post;
  Log(Format('Inserted row in DataSet with temporary ID %d', [NewId]));
end;

procedure TFormMain.DeleteButtonClick(Sender: TObject);
begin
  if FDataSet.Active and not FDataSet.IsEmpty then
  begin
    Log(Format('Deleting row with ID %d from DataSet',
      [FDataSet.FieldByName('Id').AsInteger]));
    FDataSet.Delete;
  end;
end;

procedure TFormMain.SaveButtonClick(Sender: TObject);
var
  Req: TCompanyChangesRequest;
  Res: TCompanySaveResponse;
  ChangesList: IList<TEntityChange>;
  Change: TEntityChange;
  StateStr: string;
  Comp: TCompany;
  DeletedId: Integer;
  Pair: Dext.Collections.Dict.TPair<string, Variant>;
begin
  if not FDataSet.Active then Exit;

  ChangesList := FDataSet.Changes;
  if ChangesList.Count = 0 then
  begin
    Log('No changes found in TEntityDataSet to save.');
    Exit;
  end;

  Req := TCompanyChangesRequest.Create;
  try
    for Change in ChangesList do
    begin
      case Change.State of
        ersInserted: StateStr := 'Inserted';
        ersModified: StateStr := 'Modified';
        ersDeleted:  StateStr := 'Deleted';
      else
        Continue;
      end;

      Comp := TCompany(Change.Entity);
      if Change.State = ersDeleted then
      begin
        DeletedId := 0;
        for Pair in Change.Key do
        begin
          if SameText(Pair.Key, 'Id') then
          begin
            DeletedId := Pair.Value;
            Break;
          end;
        end;
        Log(Format('  -> Serialization prep: State=%s, Id=%d (from Key), ' +
          'Name=, Country=, Active=False', [StateStr, DeletedId]));
        Req.Changes.Add(TCompanyChangeItem.Create(StateStr,
          TCompany.Create(DeletedId, '', '', False)));
      end
      else
      begin
        if Assigned(Comp) then
        begin
          Log(Format('  -> Serialization prep: State=%s, Id=%d, Name=%s, ' +
            'Country=%s, Active=%s',
            [StateStr, Comp.Id, Comp.Name, Comp.Country,
             BoolToStr(Comp.Active, True)]));
        end
        else
          Log('  -> Serialization prep: Entity is NIL!');

        // Create copy of company to send
        Req.Changes.Add(TCompanyChangeItem.Create(StateStr,
          TCompany.Create(Comp.Id, Comp.Name, Comp.Country, Comp.Active)));
      end;
    end;

    Log(Format('Sending %d changes over gRPC to server...',
      [Req.Changes.Count]));



    Res := TCompanySaveResponse.Create;
    try
      FClient.CallMethod('dext.services.CompanyService', 'ApplyChanges',
        Req, Res);
      if Res.Success then
      begin
        Log(Res.Message);
        FDataSet.AcceptChanges;
        // Refresh dataset
        LoadButtonClick(Self);
      end
      else
        Log('Save Failed: ' + Res.Message);
    finally
      Res.Free;
    end;
  finally
    Req.Free;
  end;
end;

procedure TFormMain.CodeOnlyButtonClick(Sender: TObject);
var
  Req: TCompanyQueryRequest;
  Res: TCompanyListResponse;
  Item: TCompany;
begin
  Log('[CODE-ONLY] Starting raw gRPC client call test...');
  Req := TCompanyQueryRequest.Create;
  Req.Query := 'all';
  Res := TCompanyListResponse.Create;
  try
    // Invoke gRPC method directly via client
    FClient.CallMethod('dext.services.CompanyService', 'FetchAll', Req, Res);
    Log(Format('[CODE-ONLY] Received %d items:', [Res.Items.Count]));
    for Item in Res.Items do
    begin
      Log(Format('  - ID: %d | Name: %s | Country: %s | Active: %s',
        [Item.Id, Item.Name, Item.Country, BoolToStr(Item.Active, True)]));
    end;
  finally
    Req.Free;
    Res.Free;
  end;
  Log('[CODE-ONLY] End of raw gRPC test.');
end;

end.
