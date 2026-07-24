unit UniDACDemo.Tests.Base;

interface

uses
  System.SysUtils,
  Dext,
  Dext.Entity.Core,
  Dext.Entity.Setup;

type
  TUniDACTestBase = class
  private
    FContext: TDbContext;
    function GetContext: TDbContext;
  public
    constructor Create; virtual;
    destructor Destroy; override;
    property Context: TDbContext read GetContext;
  end;

implementation

{ TUniDACTestBase }

constructor TUniDACTestBase.Create;
begin
  inherited Create;
  FContext := nil;
end;

destructor TUniDACTestBase.Destroy;
begin
  FContext.Free;
  inherited;
end;

function TUniDACTestBase.GetContext: TDbContext;
begin
  if FContext = nil then
    FContext := TDbContext.Create(UniDACDemo.DbConfig.CreateOptions);
  Result := FContext;
end;

end.