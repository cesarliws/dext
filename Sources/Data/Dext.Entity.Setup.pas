unit Dext.Entity.Setup;

interface

{$I Dext.inc}

uses
  System.SysUtils,
  System.Classes,
  Dext.Collections.Base,
  Dext.Collections.Dict,
  Dext.Collections,
  Dext.Entity.Drivers.Interfaces,
  Dext.Entity.Dialects,
  Dext.Entity.Naming,
  {$IFDEF DEXT_USE_UNIDAC}
  Dext.Entity.Drivers.UniDAC,
  Dext.Entity.Drivers.UniDAC.Manager,
  Uni,                               // TUniConnection
  {$ELSE}
  Dext.Entity.Drivers.FireDAC,
  Dext.Entity.Drivers.FireDAC.Manager,
  FireDAC.Comp.Client,               // TFDConnection
  {$ENDIF}

type
  /// <summary>
  ///   Configuration options for a DbContext.
  ///   Supports both FireDAC (default) and UniDAC (when DEXT_USE_UNIDAC is defined).
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
    {$IFNDEF DEXT_USE_UNIDAC}
    FOptimizations: TFireDACOptimizations; // FireDAC-specific optimizations
    {$ENDIF}
    FDialect: ISQLDialect;
    FCustomConnection: IDbConnection;
    FNamingStrategy: INamingStrategy;
    FNaming: string;
    FOnLog: TProc<string>;
    FBulkBatchSize: Integer;
    procedure SetConnectionString(const AValue: string);
    {$IFDEF DEXT_USE_UNIDAC}
    function BuildUniDACConnection: IDbConnection;
    {$ELSE}
    function BuildFireDACConnection: IDbConnection;
    {$ENDIF}
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
    {$IFNDEF DEXT_USE_UNIDAC}
    property Optimizations: TFireDACOptimizations read FOptimizations write FOptimizations;
    {$ENDIF}
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
    {$IFNDEF DEXT_USE_UNIDAC}
    function ConfigureOptimizations(AOpts: TFireDACOptimizations): TDbContextOptions;
    {$ENDIF}
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
  {$IFNDEF DEXT_USE_UNIDAC}
  // Default legacy optimization behavior (Matches original hardcoded logic)
  FOptimizations := [optDisableMacros, optDisableEscapes, optDirectExecute];
  {$ENDIF}
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

{$IFNDEF DEXT_USE_UNIDAC}
function TDbContextOptions.ConfigureOptimizations(AOpts: TFireDACOptimizations): TDbContextOptions;
begin
  FOptimizations := AOpts;
  Result := Self;
end;
{$ENDIF}

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
begin
  if FCustomConnection <> nil then
    Exit(FCustomConnection);

  {$IFDEF DEXT_USE_UNIDAC}
  Result := BuildUniDACConnection;
  {$ELSE}
  Result := BuildFireDACConnection;
  {$ENDIF}
end;

{$IFDEF DEXT_USE_UNIDAC}
function TDbContextOptions.BuildUniDACConnection: IDbConnection;
var
  UniConn: TUniConnection;
  SL: TStringList;
  Pair: TPair<string, string>;
  Conn: TUniDACConnection;
  ProviderName: string;
begin
  ProviderName := TDextUniDACManager.MapDriverToProvider(FDriverName);

  if FPooling then
  begin
    SL := TStringList.Create;
    try
      for Pair in FParams do
        SL.Values[Pair.Key] := Pair.Value;
      UniConn := TDextUniDACManager.Instance.CreatePooledConnection(
        ProviderName, TStrings(SL), FPoolMax);
    finally
      SL.Free;
    end;
  end
  else
  begin
    UniConn := TUniConnection.Create(nil);
    try
      UniConn.ProviderName := ProviderName;

      // Apply connection string if provided
      if FConnectionString <> '' then
        UniConn.ConnectionString := FConnectionString
      else
      begin
        // Apply individual params
        for Pair in FParams do
          UniConn.SpecificOptions.Values[Pair.Key] := Pair.Value;
      end;
    except
      UniConn.Free;
      raise;
    end;
  end;

  // Apply Unicode and other sensible defaults
  TDextUniDACManager.Instance.ApplyOptions(UniConn, []);

  Conn := TUniDACConnection.Create(UniConn, True);
  Conn.OnLog := FOnLog;
  Result := Conn;
end;
{$ELSE}
function TDbContextOptions.BuildFireDACConnection: IDbConnection;
var
  FDConn: TFDConnection;
  DefName: string;
  SL: TStringList;
  Pair: TPair<string, string>;
  Conn: TFireDACConnection;
begin
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
{$ENDIF}

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
