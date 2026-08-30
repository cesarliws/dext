unit AppDbContext;

interface

uses
  Dext.Entity,
  Dext.Entity.Core,
  Dext.Entity.Setup,
  Product,
  Order;

type
  TAppDbContext = class(TDbContext)
  private
    function GetProducts: IDbSet<TProduct>;
    function GetOrders: IDbSet<TOrder>;
  protected
    procedure OnModelCreating(Builder: TModelBuilder); override;
  public
    constructor Create; overload;
    constructor Create(const AOptions: TDbContextOptions); overload;
    property Products: IDbSet<TProduct> read GetProducts;
    property Orders: IDbSet<TOrder> read GetOrders;
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

procedure TAppDbContext.OnModelCreating(Builder: TModelBuilder);
begin
  inherited;
  Builder.Entity<TProduct>;
  Builder.Entity<TOrder>;
end;

function TAppDbContext.GetProducts: IDbSet<TProduct>;
begin
  Result := Entities<TProduct>;
end;

function TAppDbContext.GetOrders: IDbSet<TOrder>;
begin
  Result := Entities<TOrder>;
end;

end.
