unit UniDACDemo.Tests.Base;

interface

uses
  System.SysUtils,
  Dext,
  Dext.Entity,
  Dext.Entity.Context,
  Dext.Entity.Core,
  Dext.Entity.Drivers.Interfaces,
  Dext.Entity.Dialects,
  Dext.Entity.Setup;

type
  TUniDACTestBase = class
  private
    FConn: IDbConnection;
    FDialect: ISQLDialect;
    FContext: TDbContext;
    function GetContext: TDbContext;
  public
    constructor Create; virtual;
    destructor Destroy; override;
    property Context: TDbContext read GetContext;
  end;

implementation

uses UniDACDemo.DbConfig;

{ TUniDACTestBase }

constructor TUniDACTestBase.Create;
var
  Options: TDbContextOptions;
begin
  inherited Create;
  Options := CreateOptions;
  FConn := Options.BuildConnection;
  FDialect := TSQLiteDialect.Create;
  FConn.Connect;
  FContext := TDbContext.Create(FConn, FDialect);
end;

destructor TUniDACTestBase.Destroy;
begin
  FContext.Free;
  inherited;
end;

function TUniDACTestBase.GetContext: TDbContext;
begin
  Result := FContext;
end;

end.
