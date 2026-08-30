unit OrdersController;

{$M+}

interface

uses
  System.SysUtils,
  Dext.Web,
  Dext.Web.Results,
  Order,
  OrderService;

type
  [ApiController('/api/orders')]
  TOrdersController = class
  private
    FOrders: IOrderService;
  public
    constructor Create(Orders: IOrderService);

    [HttpPost('')]
    function PlaceOrder(Dto: TPlaceOrderDto): IResult; virtual;
  end;

implementation

{ TOrdersController }

constructor TOrdersController.Create(Orders: IOrderService);
begin
  inherited Create;
  FOrders := Orders;
end;

function TOrdersController.PlaceOrder(Dto: TPlaceOrderDto): IResult;
var
  Id: Integer;
begin
  try
    Id := FOrders.Place(Dto.ProductId, Dto.Qty);
    Result := Results.Created<Integer>('/api/orders/' + IntToStr(Id), Id);
  except
    on E: EDomainException do
      Result := Results.Problem(E.Message, E.StatusCode);
  end;
end;

initialization
  TOrdersController.ClassName;

end.
