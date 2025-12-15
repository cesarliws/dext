unit Dext.Entity.Setup;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Dext.Entity.Drivers.Interfaces,
  Dext.Entity.Dialects;

type
  /// <summary>
  ///   Configuration options for a DbContext.
  /// </summary>
  TDbContextOptions = class
  private
    FDriverName: string;
    FConnectionString: string;
    FParams: TDictionary<string, string>;
    FPooling: Boolean;
    FPoolMax: Integer;
    FDialect: ISQLDialect;
    FCustomConnection: IDbConnection;
  public
    constructor Create;
    destructor Destroy; override;

    property DriverName: string read FDriverName write FDriverName;
    property ConnectionString: string read FConnectionString write FConnectionString;
    property Params: TDictionary<string, string> read FParams;
    property Pooling: Boolean read FPooling write FPooling;
    property PoolMax: Integer read FPoolMax write FPoolMax;
    property Dialect: ISQLDialect read FDialect write FDialect;
    property CustomConnection: IDbConnection read FCustomConnection write FCustomConnection;

    // Fluent Helpers
    function UseSQLite(const DatabaseFile: string): TDbContextOptions;
    function UseDriver(const ADriverName: string): TDbContextOptions;
    function WithPooling(Enable: Boolean = True; MaxSize: Integer = 50): TDbContextOptions;
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
  FParams := TDictionary<string, string>.Create;
  FPooling := False;
  FPoolMax := 50;
end;

destructor TDbContextOptions.Destroy;
begin
  FParams.Free;
  inherited;
end;

function TDbContextOptions.UseDriver(const ADriverName: string): TDbContextOptions;
begin
  FDriverName := ADriverName;
  Result := Self;
end;

function TDbContextOptions.UseSQLite(const DatabaseFile: string): TDbContextOptions;
begin
  FDriverName := 'SQLite';
  FParams.AddOrSetValue('Database', DatabaseFile);
  FParams.AddOrSetValue('LockingMode', 'Normal');
  // SQLite implies SQLiteDialect, but injection happens later or we set it here if we want defaults
  if FDialect = nil then
    FDialect := TSQLiteDialect.Create;
  Result := Self;
end;

function TDbContextOptions.WithPooling(Enable: Boolean; MaxSize: Integer): TDbContextOptions;
begin
  FPooling := Enable;
  FPoolMax := MaxSize;
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

end.
