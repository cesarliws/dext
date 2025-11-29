unit Dext.Entity.Drivers.FireDAC;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Variants,
  System.Rtti,
  System.Generics.Collections,
  Data.DB,
  FireDAC.Comp.Client,
  FireDAC.Stan.Param,
  FireDAC.Stan.Option,
  FireDAC.Stan.Error,
  FireDAC.DatS,
  FireDAC.Phys.Intf,
  FireDAC.DApt.Intf,
  FireDAC.Comp.DataSet,
  Dext.Entity.Drivers.Interfaces;

type
  TFireDACConnection = class;

  TFireDACTransaction = class(TInterfacedObject, IDbTransaction)
  private
    FTransaction: TFDTransaction;
    FOwnsTransaction: Boolean;
  public
    constructor Create(AConnection: TFDConnection);
    destructor Destroy; override;
    procedure Commit;
    procedure Rollback;
  end;

  TFireDACReader = class(TInterfacedObject, IDbReader)
  private
    FQuery: TFDQuery;
    FOwnsQuery: Boolean;
    FIsFirstMove: Boolean;
  public
    constructor Create(AQuery: TFDQuery; AOwnsQuery: Boolean);
    destructor Destroy; override;
    
    function Next: Boolean;
    function GetValue(const AColumnName: string): TValue; overload;
    function GetValue(AColumnIndex: Integer): TValue; overload;
    function GetColumnCount: Integer;
    function GetColumnName(AIndex: Integer): string;
    procedure Close;
  end;

  TFireDACCommand = class(TInterfacedObject, IDbCommand)
  private
    FQuery: TFDQuery;
    FConnection: TFDConnection;
  public
    constructor Create(AConnection: TFDConnection);
    destructor Destroy; override;
    
    procedure SetSQL(const ASQL: string);
    procedure AddParam(const AName: string; const AValue: TValue);
    procedure ClearParams;
    
    procedure Execute;
    function ExecuteQuery: IDbReader;
    function ExecuteNonQuery: Integer;
    function ExecuteScalar: TValue;
  end;

  TFireDACConnection = class(TInterfacedObject, IDbConnection)
  private
    FConnection: TFDConnection;
    FOwnsConnection: Boolean;
  public
    constructor Create(AConnection: TFDConnection; AOwnsConnection: Boolean = True);
    destructor Destroy; override;
    
    procedure Connect;
    procedure Disconnect;
    function IsConnected: Boolean;
    
    function BeginTransaction: IDbTransaction;
    function CreateCommand(const ASQL: string): IInterface; // Returns IDbCommand
    function GetLastInsertId: Variant;
    
    property Connection: TFDConnection read FConnection;
  end;

implementation

{ TFireDACTransaction }

constructor TFireDACTransaction.Create(AConnection: TFDConnection);
begin
  inherited Create;
  FTransaction := TFDTransaction.Create(nil);
  FTransaction.Connection := AConnection;
  FTransaction.StartTransaction;
  FOwnsTransaction := True;
end;

destructor TFireDACTransaction.Destroy;
begin
  if FOwnsTransaction and (FTransaction <> nil) then
  begin
    if FTransaction.Active then
      FTransaction.Rollback;
    FTransaction.Free;
  end;
  inherited;
end;

procedure TFireDACTransaction.Commit;
begin
  FTransaction.Commit;
end;

procedure TFireDACTransaction.Rollback;
begin
  FTransaction.Rollback;
end;

{ TFireDACReader }

constructor TFireDACReader.Create(AQuery: TFDQuery; AOwnsQuery: Boolean);
begin
  inherited Create;
  FQuery := AQuery;
  FOwnsQuery := AOwnsQuery;
  FIsFirstMove := True;
end;

destructor TFireDACReader.Destroy;
begin
  if FOwnsQuery then
    FQuery.Free;
  inherited;
end;

procedure TFireDACReader.Close;
begin
  FQuery.Close;
end;

function TFireDACReader.GetColumnCount: Integer;
begin
  Result := FQuery.FieldCount;
end;

function TFireDACReader.GetColumnName(AIndex: Integer): string;
begin
  Result := FQuery.Fields[AIndex].FieldName;
end;

function TFireDACReader.GetValue(AColumnIndex: Integer): TValue;
begin
  Result := TValue.FromVariant(FQuery.Fields[AColumnIndex].Value);
end;

function TFireDACReader.GetValue(const AColumnName: string): TValue;
begin
  Result := TValue.FromVariant(FQuery.FieldByName(AColumnName).Value);
end;

function TFireDACReader.Next: Boolean;
begin
  if not FQuery.Active then
    Exit(False);
    
  if FIsFirstMove then
  begin
    FIsFirstMove := False;
    // TDataSet is already at First after Open.
    // If it's empty, Eof is true.
    Result := not FQuery.Eof;
  end
  else
  begin
    FQuery.Next;
    Result := not FQuery.Eof;
  end;
end;

{ TFireDACCommand }

constructor TFireDACCommand.Create(AConnection: TFDConnection);
begin
  inherited Create;
  FConnection := AConnection;
  FQuery := TFDQuery.Create(nil);
  FQuery.Connection := FConnection;
end;

destructor TFireDACCommand.Destroy;
begin
  FQuery.Free;
  inherited;
end;

procedure TFireDACCommand.AddParam(const AName: string; const AValue: TValue);
var
  Param: TFDParam;
begin
  try
    Param := FQuery.ParamByName(AName);
    if AValue.IsEmpty then
    begin
      Param.Clear;
      if Param.DataType = ftUnknown then
        Param.DataType := ftString; 
    end
    else
      Param.Value := AValue.AsVariant;
  except
    on E: Exception do
    begin
      Writeln(ErrOutput, Format('CRITICAL ERROR in AddParam(%s): %s', [AName, E.Message]));
      raise;
    end;
  end;
end;

procedure TFireDACCommand.ClearParams;
begin
  FQuery.Params.Clear;
end;

procedure TFireDACCommand.Execute;
begin
  ExecuteNonQuery;
end;

function TFireDACCommand.ExecuteNonQuery: Integer;
begin
  FQuery.ExecSQL;
  Result := FQuery.RowsAffected;
end;

function TFireDACCommand.ExecuteQuery: IDbReader;
begin
  // Create a new Query for the Reader to allow independent iteration
  var Q := TFDQuery.Create(nil);
  Q.Connection := FConnection;
  Q.SQL.Text := FQuery.SQL.Text;
  
  // Copy params
  for var i := 0 to FQuery.Params.Count - 1 do
  begin
    var Src := FQuery.Params[i];
    var Dest := Q.Params.FindParam(Src.Name);
    if Dest <> nil then
    begin
      Dest.DataType := Src.DataType;
      Dest.Value := Src.Value;
    end;
  end;
  
  Q.Open;
  
  Result := TFireDACReader.Create(Q, True); // Reader owns this new query
end;

function TFireDACCommand.ExecuteScalar: TValue;
begin
  FQuery.Open;
  try
    if not FQuery.Eof then
      Result := TValue.FromVariant(FQuery.Fields[0].Value)
    else
      Result := TValue.Empty;
  finally
    FQuery.Close;
  end;
end;

procedure TFireDACCommand.SetSQL(const ASQL: string);
begin
  FQuery.SQL.Text := ASQL;
end;

{ TFireDACConnection }

constructor TFireDACConnection.Create(AConnection: TFDConnection; AOwnsConnection: Boolean);
begin
  inherited Create;
  FConnection := AConnection;
  FOwnsConnection := AOwnsConnection;
end;

destructor TFireDACConnection.Destroy;
begin
  if FOwnsConnection then
    FConnection.Free;
  inherited;
end;

function TFireDACConnection.BeginTransaction: IDbTransaction;
begin
  Result := TFireDACTransaction.Create(FConnection);
end;

procedure TFireDACConnection.Connect;
begin
  FConnection.Connected := True;
end;

function TFireDACConnection.CreateCommand(const ASQL: string): IInterface;
var
  Cmd: IDbCommand;
begin
  Cmd := TFireDACCommand.Create(FConnection);
  Cmd.SetSQL(ASQL);
  Result := Cmd;
end;

function TFireDACConnection.GetLastInsertId: Variant;
begin
  Result := FConnection.GetLastAutoGenValue('');
end;

procedure TFireDACConnection.Disconnect;
begin
  FConnection.Connected := False;
end;

function TFireDACConnection.IsConnected: Boolean;
begin
  Result := FConnection.Connected;
end;

end.
