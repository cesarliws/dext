unit OrderService;

interface

uses
  System.SysUtils,
  Dext.Web,
  Product,
  Order,
  AppDbContext;

type
  IOrderService = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    function Place(const ProductId: Integer; const Qty: Integer): Integer;
  end;

  EInactiveProduct = class(EDomainException);
  EInvalidQuantity = class(EDomainException);

  TOrderService = class(TInterfacedObject, IOrderService)
  private
    FDb: TAppDbContext;
  public
    constructor Create(Db: TAppDbContext);
    function Place(const ProductId: Integer; const Qty: Integer): Integer;
  end;

implementation

{ TOrderService }

constructor TOrderService.Create(Db: TAppDbContext);
begin
  inherited Create;
  FDb := Db;
end;

function TOrderService.Place(const ProductId: Integer; const Qty: Integer): Integer;
var
  Product: TProduct;
  NewOrder: TOrder;
begin
  if Qty <= 0 then
    raise EInvalidQuantity.Create('Quantidade inválida');

  Product := FDb.Products.Find(ProductId);
  if (Product = nil) or (not Boolean(Product.Active)) then
    raise EInactiveProduct.Create('Produto inativo');

  NewOrder := TOrder.Create;
  NewOrder.ProductId := ProductId;
  NewOrder.Quantity := Qty;
  FDb.Orders.Add(NewOrder);
  FDb.SaveChanges;
  Result := NewOrder.Id;
end;

end.
