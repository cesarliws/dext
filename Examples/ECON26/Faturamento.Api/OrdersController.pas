unit OrdersController;

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

    [HttpPost]
    function PlaceOrder(Dto: TPlaceOrderDto): IResult;
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
  Id := FOrders.Place(Dto.ProductId, Dto.Qty);
  Result := Results.Created<Integer>('/api/orders/' + IntToStr(Id), Id);
end;

end.
