unit Dext.Entity.Setup;

interface

uses
  System.SysUtils,
  System.Classes,
  Dext.Collections.Base,
  Dext.Collections.Dict,
  Dext.Collections,
  Dext.Entity.Drivers.Interfaces,
  Dext.Entity.Dialects,
  Dext.Entity.Naming,
  Dext.Entity.Drivers.FireDAC,
  Dext.Entity.Drivers.FireDAC.Manager,
  FireDAC.Comp.Client;

type
  /// <summary>
  ///   Configuration options for a DbContext.
  /// </summary>
  TDbContextOptions = class
  private
    FDriverName: string;
    FConnectionString: string;
    FConnectionDefName: string;
    FConnectionDefString: string;
    FParams: IDictionary<string, string>;
    FPooling: Boolean;
    FPoolMax: Integer;
    FOptimizations: TFireDACOptimizations; // Connect Optimizations
    FDialect: ISQLDialect;
    FCustomConnection: IDbConnection;
    FNamingStrategy: INamingStrategy;
    FNaming: string;
    FOnLog: TProc<string>;
    FBulkBatchSize: Integer;
    procedure SetConnectionString(const AValue: string);
  public
    constructor Create;
    destructor Destroy; override;

    property DriverName: string read FDriverName write FDriverName;
    property ConnectionString: string read FConnectionString write SetConnectionString;
    property ConnectionDefName: string read FConnectionDefName write FConnectionDefName;
    property ConnectionDefString: string read FConnectionDefString write FConnectionDefString;
    property Params: IDictionary<string, string> read FParams;
    property Pooling: Boolean read FPooling write FPooling;
    property PoolMax: Integer read FPoolMax write FPoolMax;
    property Optimizations: TFireDACOptimizations read FOptimizations write FOptimizations;
    property Dialect: ISQLDialect read FDialect write FDialect;
    property CustomConnection: IDbConnection read FCustomConnection write FCustomConnection;
    property NamingStrategy: INamingStrategy read FNamingStrategy write FNamingStrategy;
    property Naming: string read FNaming write FNaming;
    property OnLog: TProc<string> read FOnLog write FOnLog;
    property BulkBatchSize: Integer read FBulkBatchSize write FBulkBatchSize;

    function BuildConnection: IDbConnection;
    function BuildDialect: ISQLDialect;
    function BuildNamingStrategy: INamingStrategy;

    // Fluent Helpers
    function UseSQLite(const DatabaseFile: string): TDbContextOptions;
    function UseSQLServer(const AConnectionString: string): TDbContextOptions;
    function UsePostgreSQL(const AConnectionString: string): TDbContextOptions;
    function UseMySQL(const AConnectionString: string): TDbContextOptions;
    function UseFirebird(const AConnectionString: string): TDbContextOptions;
    function UseOracle(const AConnectionString: string): TDbContextOptions;
    function UseDriver(const ADriverName: string): TDbContextOptions;
    function UseConnectionDef(const ADefName: string): TDbContextOptions;
    function WithPooling(Enable: Boolean = True; MaxSize: Integer = 50): TDbContextOptions;
    function ConfigureOptimizations(AOpts: TFireDACOptimizations): TDbContextOptions;
    function UseCustomDialect(const ADialect: ISQLDialect): TDbContextOptions;
    function UseDialect(ADialect: TDatabaseDialect): TDbContextOptions;
    function UseNamingStrategy(const AStrategy: INamingStrategy): TDbContextOptions;
    function UseSnakeCaseNamingConvention: TDbContextOptions;
    function SnakeCase: TDbContextOptions;
    function LogTo(AProc: TProc<string>): TDbContextOptions;
    function WithBulkBatchSize(ASize: Integer): TDbContextOptions;
  end;

  /// <summary>
  ///   Fluent builder for configuring DbContext options.
  /// </summary>
  TDbContextOptionsBuilder = record
  private
    FDriverName: string;
    FConnectionString: string;
    FConnectionDefName: string;
    FConnectionDefString: string;
    FParams: TArray<TPair<string, string>>;
    FPooling: Boolean;
    FPoolMax: Integer;
    FOptimizations: TFireDACOptimizations;
    FDialect: ISQLDialect;
    FCustomConnection: IDbConnection;
    FNamingStrategy: INamingStrategy;
    FNaming: string;
    FOnLog: TProc<string>;
    FBulkBatchSize: Integer;
  public
    class function Create: TDbContextOptionsBuilder; static;

    function UseDriver(const ADriverName: string): TDbContextOptionsBuilder;
    function UseConnectionDef(const ADefName: string): TDbContextOptionsBuilder;
    function UseSQLite(const DatabaseFile: string): TDbContextOptionsBuilder;
    function UseSQLServer(const AConnectionString: string): TDbContextOptionsBuilder;
    function UsePostgreSQL(const AConnectionString: string): TDbContextOptionsBuilder;
    function UseMySQL(const AConnectionString: string): TDbContextOptionsBuilder;
    function UseFirebird(const AConnectionString: string): TDbContextOptionsBuilder;
    function UseOracle(const AConnectionString: string): TDbContextOptionsBuilder;
    function Pooling(Enable: Boolean = True; MaxSize: Integer = 50): TDbContextOptionsBuilder;
    function WithPooling(Enable: Boolean = True; MaxSize: Integer = 50): TDbContextOptionsBuilder;
    function Optimizations(AOpts: TFireDACOptimizations): TDbContextOptionsBuilder;
    function ConfigureOptimizations(AOpts: TFireDACOptimizations): TDbContextOptionsBuilder;
    function UseCustomDialect(const ADialect: ISQLDialect): TDbContextOptionsBuilder;
    function UseDialect(ADialect: TDatabaseDialect): TDbContextOptionsBuilder;
    function UseNamingStrategy(const AStrategy: INamingStrategy): TDbContextOptionsBuilder;
    function UseSnakeCaseNamingConvention: TDbContextOptionsBuilder;
    function SnakeCase: TDbContextOptionsBuilder;
    function LogTo(AProc: TProc<string>): TDbContextOptionsBuilder;
    function BulkBatchSize(ASize: Integer): TDbContextOptionsBuilder;
    function WithBulkBatchSize(ASize: Integer): TDbContextOptionsBuilder;
    function AddParam(const AKey, AValue: string): TDbContextOptionsBuilder;

    function Build: TDbContextOptions;
    class operator Implicit(const ABuilder: TDbContextOptionsBuilder): TDbContextOptions;
  end;

/// <summary>
///   Factory function returning a fluent TDbContextOptionsBuilder.
/// </summary>
function DbContextOptions: TDbContextOptionsBuilder;

implementation

{ TDbContextOptions }

constructor TDbContextOptions.Create;
begin
  FParams := TCollections.CreateDictionary<string, string>;
  FPooling := False;
  FPoolMax := 50;
  FBulkBatchSize := 100;
  // Default legacy optimization behavior (Matches original hardcoded logic)
  FOptimizations := [optDisableMacros, optDisableEscapes, optDirectExecute];
end;

destructor TDbContextOptions.Destroy;
begin
  FParams := nil;
  inherited;
end;

function TDbContextOptions.UseDriver(const ADriverName: string): TDbContextOptions;
begin
  FDriverName := ADriverName;
  FConnectionDefName := '';
  Result := Self;
end;

function TDbContextOptions.UseConnectionDef(const ADefName: string): TDbContextOptions;
begin
  FConnectionDefName := ADefName;
  FDriverName := '';
  FConnectionString := '';
  Result := Self;
end;

function TDbContextOptions.UseSQLite(const DatabaseFile: string): TDbContextOptions;
begin
  FDriverName := 'SQLite';
  FConnectionDefName := '';
  FParams.AddOrSetValue('Database', DatabaseFile);
  FParams.AddOrSetValue('LockingMode', 'Normal');
  // Dialect is auto-detected by TDbContext from the connection driver
  Result := Self;
end;

function TDbContextOptions.UseSQLServer(const AConnectionString: string): TDbContextOptions;
begin
  FDriverName := 'MSSQL';
  if not SameText(Copy(AConnectionString, 1, 9), 'DriverID=') and not AConnectionString.Contains('DriverID=') then
    ConnectionString := 'DriverID=MSSQL;' + AConnectionString
  else
    ConnectionString := AConnectionString;
  Result := Self;
end;

function TDbContextOptions.UsePostgreSQL(const AConnectionString: string): TDbContextOptions;
begin
  FDriverName := 'PG';
  if not SameText(Copy(AConnectionString, 1, 9), 'DriverID=') and not AConnectionString.Contains('DriverID=') then
    ConnectionString := 'DriverID=PG;' + AConnectionString
  else
    ConnectionString := AConnectionString;
  Result := Self;
end;

function TDbContextOptions.UseMySQL(const AConnectionString: string): TDbContextOptions;
begin
  FDriverName := 'MySQL';
  if not SameText(Copy(AConnectionString, 1, 9), 'DriverID=') and not AConnectionString.Contains('DriverID=') then
    ConnectionString := 'DriverID=MySQL;' + AConnectionString
  else
    ConnectionString := AConnectionString;
  Result := Self;
end;

function TDbContextOptions.UseFirebird(const AConnectionString: string): TDbContextOptions;
begin
  FDriverName := 'FB';
  if not SameText(Copy(AConnectionString, 1, 9), 'DriverID=') and not AConnectionString.Contains('DriverID=') then
    ConnectionString := 'DriverID=FB;' + AConnectionString
  else
    ConnectionString := AConnectionString;
  Result := Self;
end;

function TDbContextOptions.UseOracle(const AConnectionString: string): TDbContextOptions;
begin
  FDriverName := 'Ora';
  if not SameText(Copy(AConnectionString, 1, 9), 'DriverID=') and not AConnectionString.Contains('DriverID=') then
    ConnectionString := 'DriverID=Ora;' + AConnectionString
  else
    ConnectionString := AConnectionString;
  Result := Self;
end;

function TDbContextOptions.WithPooling(Enable: Boolean; MaxSize: Integer): TDbContextOptions;
begin
  FPooling := Enable;
  FPoolMax := MaxSize;
  Result := Self;
end;

function TDbContextOptions.ConfigureOptimizations(AOpts: TFireDACOptimizations): TDbContextOptions;
begin
  FOptimizations := AOpts;
  Result := Self;
end;

function TDbContextOptions.UseCustomDialect(const ADialect: ISQLDialect): TDbContextOptions;
begin
  FDialect := ADialect;
  Result := Self;
end;

function TDbContextOptions.UseDialect(ADialect: TDatabaseDialect): TDbContextOptions;
begin
  FDialect := TDialectFactory.CreateDialect(ADialect);
  Result := Self;
end;

function TDbContextOptions.LogTo(AProc: TProc<string>): TDbContextOptions;
begin
  FOnLog := AProc;
  Result := Self;
end;

function TDbContextOptions.WithBulkBatchSize(ASize: Integer): TDbContextOptions;
begin
  FBulkBatchSize := ASize;
  Result := Self;
end;

function TDbContextOptions.SnakeCase: TDbContextOptions;
begin
  Result := UseSnakeCaseNamingConvention;
end;

function TDbContextOptions.UseSnakeCaseNamingConvention: TDbContextOptions;
begin
  FNaming := 'snake_case';
  FNamingStrategy := TSnakeCaseNamingStrategy.Create;
  Result := Self;
end;

function TDbContextOptions.UseNamingStrategy(const AStrategy: INamingStrategy): TDbContextOptions;
begin
  FNamingStrategy := AStrategy;
  Result := Self;
end;

function TDbContextOptions.BuildConnection: IDbConnection;
var
  FDConn: TFDConnection;
  DefName: string;
  SL: TStringList;
  Pair: TPair<string, string>;
  Conn: TFireDACConnection;
begin
  if FCustomConnection <> nil then
    Exit(FCustomConnection);

  FDConn := TFDConnection.Create(nil);
  try
    if FConnectionString <> '' then
    begin
      FDConn.ConnectionString := FConnectionString;
    end;

    if FConnectionDefName <> '' then
    begin
      FDConn.ConnectionDefName := FConnectionDefName;
    end
    else if FDriverName <> '' then
    begin
      if FPooling then
      begin
        SL := TStringList.Create;
        try
          for Pair in FParams do
            SL.Values[Pair.Key] := Pair.Value;
          
          DefName := TDextFireDACManager.Instance.RegisterConnectionDef(FDriverName, TStrings(SL), FPoolMax);
          FDConn.ConnectionDefName := DefName;
        finally
          SL.Free;
        end;
      end
      else
      begin
        FDConn.DriverName := FDriverName;
        for Pair in FParams do
          FDConn.Params.Values[Pair.Key] := Pair.Value;
      end;
    end;
    
    // Resource options (Applying configured optimizations)
    TDextFireDACManager.Instance.ApplyResourceOptions(FDConn, FOptimizations);

    Conn := TFireDACConnection.Create(FDConn, True);
    Conn.OnLog := FOnLog;
    Result := Conn;
  except
    FDConn.Free;
    raise;
  end;
end;

function TDbContextOptions.BuildDialect: ISQLDialect;
begin
  Result := FDialect;
end;

function TDbContextOptions.BuildNamingStrategy: INamingStrategy;
begin
  if FNamingStrategy <> nil then
    Exit(FNamingStrategy);

  if SameText(FNaming, 'snake_case') then
    FNamingStrategy := TSnakeCaseNamingStrategy.Create
  else
    FNamingStrategy := TDefaultNamingStrategy.Create;
    
  Result := FNamingStrategy;
end;

{ TDbContextOptionsBuilder }

class function TDbContextOptionsBuilder.Create: TDbContextOptionsBuilder;
begin
  Result := Default(TDbContextOptionsBuilder);
  Result.FPoolMax := 50;
  Result.FBulkBatchSize := 100;
  Result.FOptimizations := [optDisableMacros, optDisableEscapes, optDirectExecute];
end;

function TDbContextOptionsBuilder.AddParam(const AKey, AValue: string): TDbContextOptionsBuilder;
var
  i: Integer;
begin
  Result := Self;
  for i := 0 to High(Result.FParams) do
  begin
    if SameText(Result.FParams[i].Key, AKey) then
    begin
      Result.FParams[i] := TPair<string, string>.Create(AKey, AValue);
      Exit;
    end;
  end;
  SetLength(Result.FParams, Length(Result.FParams) + 1);
  Result.FParams[High(Result.FParams)] := TPair<string, string>.Create(AKey, AValue);
end;

function TDbContextOptionsBuilder.UseDriver(const ADriverName: string): TDbContextOptionsBuilder;
begin
  Result := Self;
  Result.FDriverName := ADriverName;
  Result.FConnectionDefName := '';
end;

function TDbContextOptionsBuilder.UseConnectionDef(const ADefName: string): TDbContextOptionsBuilder;
begin
  Result := Self;
  Result.FConnectionDefName := ADefName;
  Result.FDriverName := '';
  Result.FConnectionString := '';
end;

function TDbContextOptionsBuilder.UseSQLite(const DatabaseFile: string): TDbContextOptionsBuilder;
begin
  Result := Self;
  Result.FDriverName := 'SQLite';
  Result.FConnectionDefName := '';
  Result := Result.AddParam('Database', DatabaseFile);
  Result := Result.AddParam('LockingMode', 'Normal');
end;

function TDbContextOptionsBuilder.UseSQLServer(const AConnectionString: string): TDbContextOptionsBuilder;
begin
  Result := Self;
  Result.FDriverName := 'MSSQL';
  if not SameText(Copy(AConnectionString, 1, 9), 'DriverID=') and not AConnectionString.Contains('DriverID=') then
    Result.FConnectionString := 'DriverID=MSSQL;' + AConnectionString
  else
    Result.FConnectionString := AConnectionString;
end;

function TDbContextOptionsBuilder.UsePostgreSQL(const AConnectionString: string): TDbContextOptionsBuilder;
begin
  Result := Self;
  Result.FDriverName := 'PG';
  if not SameText(Copy(AConnectionString, 1, 9), 'DriverID=') and not AConnectionString.Contains('DriverID=') then
    Result.FConnectionString := 'DriverID=PG;' + AConnectionString
  else
    Result.FConnectionString := AConnectionString;
end;

function TDbContextOptionsBuilder.UseMySQL(const AConnectionString: string): TDbContextOptionsBuilder;
begin
  Result := Self;
  Result.FDriverName := 'MySQL';
  if not SameText(Copy(AConnectionString, 1, 9), 'DriverID=') and not AConnectionString.Contains('DriverID=') then
    Result.FConnectionString := 'DriverID=MySQL;' + AConnectionString
  else
    Result.FConnectionString := AConnectionString;
end;

function TDbContextOptionsBuilder.UseFirebird(const AConnectionString: string): TDbContextOptionsBuilder;
begin
  Result := Self;
  Result.FDriverName := 'FB';
  if not SameText(Copy(AConnectionString, 1, 9), 'DriverID=') and not AConnectionString.Contains('DriverID=') then
    Result.FConnectionString := 'DriverID=FB;' + AConnectionString
  else
    Result.FConnectionString := AConnectionString;
end;

function TDbContextOptionsBuilder.UseOracle(const AConnectionString: string): TDbContextOptionsBuilder;
begin
  Result := Self;
  Result.FDriverName := 'Ora';
  if not SameText(Copy(AConnectionString, 1, 9), 'DriverID=') and not AConnectionString.Contains('DriverID=') then
    Result.FConnectionString := 'DriverID=Ora;' + AConnectionString
  else
    Result.FConnectionString := AConnectionString;
end;

function TDbContextOptionsBuilder.Pooling(Enable: Boolean; MaxSize: Integer): TDbContextOptionsBuilder;
begin
  Result := Self;
  Result.FPooling := Enable;
  Result.FPoolMax := MaxSize;
end;

function TDbContextOptionsBuilder.WithPooling(Enable: Boolean; MaxSize: Integer): TDbContextOptionsBuilder;
begin
  Result := Pooling(Enable, MaxSize);
end;

function TDbContextOptionsBuilder.Optimizations(AOpts: TFireDACOptimizations): TDbContextOptionsBuilder;
begin
  Result := Self;
  Result.FOptimizations := AOpts;
end;

function TDbContextOptionsBuilder.ConfigureOptimizations(AOpts: TFireDACOptimizations): TDbContextOptionsBuilder;
begin
  Result := Optimizations(AOpts);
end;

function TDbContextOptionsBuilder.UseCustomDialect(const ADialect: ISQLDialect): TDbContextOptionsBuilder;
begin
  Result := Self;
  Result.FDialect := ADialect;
end;

function TDbContextOptionsBuilder.UseDialect(ADialect: TDatabaseDialect): TDbContextOptionsBuilder;
begin
  Result := Self;
  Result.FDialect := TDialectFactory.CreateDialect(ADialect);
end;

function TDbContextOptionsBuilder.UseNamingStrategy(const AStrategy: INamingStrategy): TDbContextOptionsBuilder;
begin
  Result := Self;
  Result.FNamingStrategy := AStrategy;
end;

function TDbContextOptionsBuilder.UseSnakeCaseNamingConvention: TDbContextOptionsBuilder;
begin
  Result := Self;
  Result.FNaming := 'snake_case';
  Result.FNamingStrategy := TSnakeCaseNamingStrategy.Create;
end;

function TDbContextOptionsBuilder.SnakeCase: TDbContextOptionsBuilder;
begin
  Result := UseSnakeCaseNamingConvention;
end;

function TDbContextOptionsBuilder.LogTo(AProc: TProc<string>): TDbContextOptionsBuilder;
begin
  Result := Self;
  Result.FOnLog := AProc;
end;

function TDbContextOptionsBuilder.BulkBatchSize(ASize: Integer): TDbContextOptionsBuilder;
begin
  Result := Self;
  Result.FBulkBatchSize := ASize;
end;

function TDbContextOptionsBuilder.WithBulkBatchSize(ASize: Integer): TDbContextOptionsBuilder;
begin
  Result := BulkBatchSize(ASize);
end;

function TDbContextOptionsBuilder.Build: TDbContextOptions;
var
  Pair: TPair<string, string>;
begin
  Result := TDbContextOptions.Create;
  Result.DriverName := FDriverName;
  Result.ConnectionString := FConnectionString;
  Result.ConnectionDefName := FConnectionDefName;
  Result.ConnectionDefString := FConnectionDefString;
  for Pair in FParams do
    Result.Params.AddOrSetValue(Pair.Key, Pair.Value);
  Result.Pooling := FPooling;
  Result.PoolMax := FPoolMax;
  Result.Optimizations := FOptimizations;
  Result.Dialect := FDialect;
  Result.CustomConnection := FCustomConnection;
  Result.NamingStrategy := FNamingStrategy;
  Result.Naming := FNaming;
  Result.OnLog := FOnLog;
  Result.BulkBatchSize := FBulkBatchSize;
end;

class operator TDbContextOptionsBuilder.Implicit(const ABuilder: TDbContextOptionsBuilder): TDbContextOptions;
begin
  Result := ABuilder.Build;
end;

function DbContextOptions: TDbContextOptionsBuilder;
begin
  Result := TDbContextOptionsBuilder.Create;
end;

procedure TDbContextOptions.SetConnectionString(const AValue: string);
var
  SL: TStringList;
  i: Integer;
  Line, Key, Val: string;
  PosEq: Integer;
begin
  FConnectionString := AValue;
  FParams.Clear;
  
  // Basic parsing to populate Params for other uses (like Dialect detection)
  if AValue <> '' then
  begin
    SL := TStringList.Create;
    try
      SL.Delimiter := ';';
      SL.StrictDelimiter := True;
      SL.DelimitedText := AValue;
      
      for i := 0 to SL.Count - 1 do
      begin
        Line := SL[i];
        PosEq := Pos('=', Line);
        if PosEq > 0 then
        begin
          Key := Copy(Line, 1, PosEq - 1).Trim;
          Val := Copy(Line, PosEq + 1, MaxInt).Trim;
          FParams.AddOrSetValue(Key, Val);
          
          if SameText(Key, 'DriverID') then
            FDriverName := Val;
        end;
      end;
    finally
      SL.Free;
    end;
  end;
end;

end.
