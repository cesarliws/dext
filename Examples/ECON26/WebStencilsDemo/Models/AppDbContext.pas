unit AppDbContext;

interface

uses
  Dext.Entity,
  Dext.Entity.Core,
  Dext.Entity.Setup,
  Customer;

type
  TAppDbContext = class(TDbContext)
  private
    function GetCustomers: IDbSet<TCustomer>;
  public
    constructor Create; overload;
    constructor Create(const AOptions: TDbContextOptions); overload;
    property Customers: IDbSet<TCustomer> read GetCustomers;
  end;

implementation

{ TAppDbContext }

constructor TAppDbContext.Create;
var
  Opts: TDbContextOptions;
begin
  Opts := TDbContextOptions.Create;
  try
    Opts.UseSQLite(':memory:');
    inherited Create(Opts);
  finally
    Opts.Free;
  end;
end;

constructor TAppDbContext.Create(const AOptions: TDbContextOptions);
begin
  inherited Create(AOptions);
end;

function TAppDbContext.GetCustomers: IDbSet<TCustomer>;
begin
  Result := Entities<TCustomer>;
end;

end.
