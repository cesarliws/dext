unit DextStore.Controllers;

interface

uses
  System.SysUtils,
  System.JSON,
  REST.Json,
  Dext,
  Dext.Http,
  DextStore.Models,
  DextStore.Services;

type
  // ===========================================================================
  // 🔐 Auth Controller
  // ===========================================================================
  [DextController('/api/auth')]
  TAuthController = class
  private
    FTokenHandler: IJwtTokenHandler;
  public
    constructor Create(TokenHandler: IJwtTokenHandler);
    
    [DextPost('/login')]
    [AllowAnonymous]
    procedure Login(Ctx: IHttpContext; const Request: TLoginRequest; [FromServices] const
      ClaimsBuilder: IClaimsBuilder);
  end;

  // ===========================================================================
  // 🛒 Products Controller
  // ===========================================================================
  [DextController('/api/products')]
  TProductsController = class
  private
    FService: IProductService;
  public
    constructor Create(Service: IProductService);
    
    [DextGet('/')]
    procedure GetAll(Ctx: IHttpContext);
    
    [DextGet('/{id}')]
    procedure GetById(Ctx: IHttpContext; [FromRoute] Id: Integer);
    
    [DextPost('/')]
    [SwaggerAuthorize('Bearer')]
    [ValidateModel] // Validates [Required], [StringLength] etc.
    procedure CreateProduct(Ctx: IHttpContext; const Request: TCreateProductRequest);
  end;

  // ===========================================================================
  // 🛍️ Cart Controller
  // ===========================================================================
  [DextController('/api/cart')]
  [SwaggerAuthorize('Bearer')]
  TCartController = class
  private
    FService: ICartService;
  public
    constructor Create(Service: ICartService);
    
    [DextGet('/')]
    procedure GetCart(Ctx: IHttpContext);
    
    [DextPost('/items')]
    procedure AddItem(Ctx: IHttpContext; const Request: TAddToCartRequest);
    
    [DextDelete('/')]
    procedure ClearCart(Ctx: IHttpContext);
  end;

  // ===========================================================================
  // 📦 Orders Controller
  // ===========================================================================
  [DextController('/api/orders')]
  [SwaggerAuthorize('Bearer')]
  TOrdersController = class
  private
    FService: IOrderService;
  public
    constructor Create(Service: IOrderService);
    
    [DextPost('/checkout')]
    procedure Checkout(Ctx: IHttpContext);
    
    [DextGet('/')]
    procedure GetMyOrders(Ctx: IHttpContext);
  end;

implementation


{ TAuthController }

constructor TAuthController.Create(TokenHandler: IJwtTokenHandler);
begin
  FTokenHandler := TokenHandler;
end;

procedure TAuthController.Login(Ctx: IHttpContext; const Request:
  TLoginRequest; const ClaimsBuilder: IClaimsBuilder);
begin
  // Hardcoded user for demo
  if (Request.Username = 'user') and (Request.Password = 'password') then
  begin
    var Token := FTokenHandler.GenerateToken(
      ClaimsBuilder
        .WithNameIdentifier(Request.Username)
        .WithRole('customer')
        .Build
    );
    
    Ctx.Response.Json(Format('{"token": "%s", "expires_in": 7200}', [Token]));
  end
  else
    Ctx.Response.Status(401).Json('{"error": "Invalid credentials"}');
end;

{ TProductsController }

constructor TProductsController.Create(Service: IProductService);
begin
  FService := Service;
end;

procedure TProductsController.GetAll(Ctx: IHttpContext);
begin
  var Products := FService.GetAll;
  var Arr := TJSONArray.Create;
  try
    for var P in Products do
      Arr.Add(TJson.ObjectToJsonObject(P) as TJSONObject);
    Ctx.Response.Json(Arr.ToString);
  finally
    Arr.Free;
  end;
end;

procedure TProductsController.GetById(Ctx: IHttpContext; Id: Integer);
begin
  var Product := FService.GetById(Id);
  if Product <> nil then
    Ctx.Response.Json(TJson.ObjectToJsonString(Product))
  else
    Ctx.Response.Status(404).Json('{"error": "Product not found"}');
end;

procedure TProductsController.CreateProduct(Ctx: IHttpContext; const Request: TCreateProductRequest);
begin
  var Product := FService.CreateProduct(Request);
  Ctx.Response.Status(201).Json(TJson.ObjectToJsonString(Product));
end;

{ TCartController }

constructor TCartController.Create(Service: ICartService);
begin
  FService := Service;
end;

procedure TCartController.GetCart(Ctx: IHttpContext);
begin
  var UserId := Ctx.User.Identity.Name;
  var Items := FService.GetCart(UserId);
  var Total := FService.CalculateTotal(UserId);
  
  // Custom JSON response structure
  // In a real app, define a TCartResponse DTO
  var Json := '{"items": [';
  for var I := 0 to High(Items) do
  begin
    if I > 0 then Json := Json + ',';
    Json := Json + Format('{"productId": %d, "name": "%s", "quantity": %d, "unitPrice": %f, "total": %f}',
      [Items[I].ProductId, Items[I].ProductName, Items[I].Quantity, Items[I].UnitPrice, Items[I].Total]);
  end;
  Json := Json + Format('], "totalAmount": %f, "userId": "%s"}', [Total, UserId]);
  
  Ctx.Response.Json(Json);
end;

procedure TCartController.AddItem(Ctx: IHttpContext; const Request: TAddToCartRequest);
begin
  try
    var UserId := Ctx.User.Identity.Name;
    FService.AddItem(UserId, Request.ProductId, Request.Quantity);
    Ctx.Response.Json('{"message": "Item added to cart"}');
  except
    on E: Exception do
      Ctx.Response.Status(400).Json(Format('{"error": "%s"}', [E.Message]));
  end;
end;

procedure TCartController.ClearCart(Ctx: IHttpContext);
begin
  var UserId := Ctx.User.Identity.Name;
  FService.ClearCart(UserId);
  Ctx.Response.Status(204);
end;

{ TOrdersController }

constructor TOrdersController.Create(Service: IOrderService);
begin
  FService := Service;
end;

procedure TOrdersController.Checkout(Ctx: IHttpContext);
begin
  try
    var UserId := Ctx.User.Identity.Name;
    var Order := FService.Checkout(UserId);
    
    var Response: TOrderResponse;
    Response.OrderId := Order.Id;
    Response.Total := Order.TotalAmount;
    Response.Status := Order.Status;
    Response.Message := 'Order placed successfully';
    
    Ctx.Response.Status(201).Json(Format(
      '{"orderId": %d, "total": %f, "status": "%s", "message": "%s"}',
      [Response.OrderId, Response.Total, Response.Status, Response.Message]));
  except
    on E: Exception do
      Ctx.Response.Status(400).Json(Format('{"error": "%s"}', [E.Message]));
  end;
end;

procedure TOrdersController.GetMyOrders(Ctx: IHttpContext);
begin
  var UserId := Ctx.User.Identity.Name;
  var Orders := FService.GetUserOrders(UserId);
  var Arr := TJSONArray.Create;
  try
    for var O in Orders do
      Arr.Add(TJson.ObjectToJsonObject(O) as TJSONObject);
    Ctx.Response.Json(Arr.ToString);
  finally
    Arr.Free;
  end;
end;

initialization
  TAuthController.ClassName;
  TProductsController.ClassName;
  TCartController.ClassName;
  TOrdersController.ClassName;

end.
