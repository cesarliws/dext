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
    function LogTo(AProc: TProc<string>): TDbContextOptions;
    function WithBulkBatchSize(ASize: Integer): TDbContextOptions;
  end;

  /// <summary>
  ///   Builder for configuring DbContext options.
  /// </summary>
  TDbContextOptionsBuilder = class
  private
    FOptions: TDbContextOptions;
  public
    constructor Create(Options: TDbContextOptions);
    function UseSQLite(const DatabaseFile: string): TDbContextOptionsBuilder;
    function UseDriver(const ADriverName: string): TDbContextOptionsBuilder;
  end;

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
  ConnectionString := AConnectionString;
  Result := Self;
end;

function TDbContextOptions.UsePostgreSQL(const AConnectionString: string): TDbContextOptions;
begin
  FDriverName := 'PG';
  ConnectionString := AConnectionString;
  Result := Self;
end;

function TDbContextOptions.UseMySQL(const AConnectionString: string): TDbContextOptions;
begin
  FDriverName := 'MySQL';
  ConnectionString := AConnectionString;
  Result := Self;
end;

function TDbContextOptions.UseFirebird(const AConnectionString: string): TDbContextOptions;
begin
  FDriverName := 'FB';
  ConnectionString := AConnectionString;
  Result := Self;
end;

function TDbContextOptions.UseOracle(const AConnectionString: string): TDbContextOptions;
begin
  FDriverName := 'Ora';
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

function TDbContextOptions.UseNamingStrategy(const AStrategy: INamingStrategy): TDbContextOptions;
begin
  FNamingStrategy := AStrategy;
  Result := Self;
end;

function TDbContextOptions.UseSnakeCaseNamingConvention: TDbContextOptions;
begin
  FNamingStrategy := TSnakeCaseNamingStrategy.Create;
  Result := Self;
end;

{ TDbContextOptionsBuilder }

constructor TDbContextOptionsBuilder.Create(Options: TDbContextOptions);
begin
  FOptions := Options;
end;

function TDbContextOptionsBuilder.UseDriver(const ADriverName: string): TDbContextOptionsBuilder;
begin
  FOptions.UseDriver(ADriverName);
  Result := Self;
end;

function TDbContextOptionsBuilder.UseSQLite(const DatabaseFile: string): TDbContextOptionsBuilder;
begin
  FOptions.UseSQLite(DatabaseFile);
  Result := Self;
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
