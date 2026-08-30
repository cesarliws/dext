unit PlaceOrderTests;

interface

uses
  Dext.Testing,
  Dext.Testing.Attributes,
  OrderService,
  AppDbContext;

type
  [Fixture]
  TPlaceOrderTests = class
  private
    FDb: TAppDbContext;
    FOrders: IOrderService;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Recusa_produto_inativo;

    [Test]
    procedure Recusa_quantidade_zero;
  end;

implementation

uses
  System.SysUtils,
  Product;

{ TPlaceOrderTests }

procedure TPlaceOrderTests.Setup;
begin
  FDb := TAppDbContext.Create;
  FDb.EnsureCreated;
  FOrders := TOrderService.Create(FDb);
end;

procedure TPlaceOrderTests.TearDown;
begin
  FOrders := nil;
  FreeAndNil(FDb);
end;

procedure TPlaceOrderTests.Recusa_produto_inativo;
var
  P: TProduct;
begin
  P := TProduct.Create;
  P.Name := 'X';
  P.Active := False;
  FDb.Products.Add(P);
  FDb.SaveChanges;

  Should(
    procedure
    begin
      FOrders.Place(P.Id, 1);
    end).Throw<EInactiveProduct>;
end;

procedure TPlaceOrderTests.Recusa_quantidade_zero;
var
  P: TProduct;
begin
  P := TProduct.Create;
  P.Name := 'Ativo';
  P.Active := True;
  FDb.Products.Add(P);
  FDb.SaveChanges;

  Should(
    procedure
    begin
      FOrders.Place(P.Id, 0);
    end).Throw<EInvalidQuantity>;
end;

end.
