unit DextStore.Controllers;

interface

uses
  System.SysUtils,
  Dext,
  Dext.Web,
  Dext.Json,
  DextStore.Models,
  DextStore.Services;

type
  // ===========================================================================
  // Auth Controller
  // ===========================================================================
  [ApiController('/api/auth')]
  TAuthController = class
  private
    FTokenHandler: IJwtTokenHandler;
  public
    constructor Create(TokenHandler: IJwtTokenHandler);

    [HttpPost('/login')]
    [AllowAnonymous]
    procedure Login(Ctx: IHttpContext; const Request: TLoginRequest; [FromServices] const
      ClaimsBuilder: IClaimsBuilder);
  end;

  // ===========================================================================
  // 🛒 Products Controller
  // ===========================================================================
  [ApiController('/api/products')]
  TProductsController = class
  private
    FService: IProductService;
  public
    constructor Create(Service: IProductService);

    [HttpGet('')]
    procedure GetAll(Ctx: IHttpContext);

    [HttpGet('/{id}')]
    procedure GetById(Ctx: IHttpContext; [FromRoute] Id: Integer);

    [HttpPost('')]
    [Authorize('Bearer')]
    [ValidateModel] // Validates [Required], [StringLength] etc.
    procedure CreateProduct(Ctx: IHttpContext; const Request: TCreateProductRequest);
  end;

  // ===========================================================================
  // 🛍️ Cart Controller
  // ===========================================================================
  [ApiController('/api/cart')]
  [Authorize('Bearer')]
  TCartController = class
  private
    FService: ICartService;
  public
    constructor Create(Service: ICartService);

    [HttpGet('')]
    procedure GetCart(Ctx: IHttpContext);

    [HttpPost('/items')]
    procedure AddItem(Ctx: IHttpContext; const Request: TAddToCartRequest);

    [HttpDelete('')]
    procedure ClearCart(Ctx: IHttpContext);
  end;

  // ===========================================================================
  // 📦 Orders Controller
  // ===========================================================================
  [ApiController('/api/orders')]
  [Authorize('Bearer')]
  TOrdersController = class
  private
    FService: IOrderService;
  public
    constructor Create(Service: IOrderService);

    [HttpPost('/checkout')]
    procedure Checkout(Ctx: IHttpContext);

    [HttpGet('')]
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
var
  Token: string;
begin
  // Hardcoded user for demo
  if (Request.Username = 'user') and (Request.Password = 'password') then
  begin
    Token := FTokenHandler.GenerateToken(
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
var
  Products: TArray<TProduct>;
begin
  Products := FService.GetAll;
  Ctx.Response.Json(TDextJson.Serialize(Products));
end;

procedure TProductsController.GetById(Ctx: IHttpContext; Id: Integer);
var
  Product: TProduct;
begin
  Product := FService.GetById(Id);
  if Product <> nil then
    Ctx.Response.Json(TDextJson.Serialize(Product))
  else
    Ctx.Response.Status(404).Json('{"error": "Product not found"}');
end;

procedure TProductsController.CreateProduct(Ctx: IHttpContext; const Request: TCreateProductRequest);
var
  Product: TProduct;
begin
  Product := FService.CreateProduct(Request);
  Ctx.Response.Status(201).Json(TDextJson.Serialize(Product));
end;

{ TCartController }

constructor TCartController.Create(Service: ICartService);
begin
  FService := Service;
end;

procedure TCartController.GetCart(Ctx: IHttpContext);
var
  UserId: string;
  Items: TArray<TCartItem>;
  Total: Currency;
  Response: TCartResponse;
begin
  UserId := Ctx.User.Identity.Name;
  Items := FService.GetCart(UserId);
  Total := FService.CalculateTotal(UserId);

  Response.Items := Items;
  Response.TotalAmount := Total;
  Response.UserId := UserId;

  Ctx.Response.Json(TDextJson.Serialize(Response));
end;

procedure TCartController.AddItem(Ctx: IHttpContext; const Request: TAddToCartRequest);
var
  UserId: string;
begin
  try
    UserId := Ctx.User.Identity.Name;
    FService.AddItem(UserId, Request.ProductId, Request.Quantity);
    Ctx.Response.Json('{"message": "Item added to cart"}');
  except
    on E: Exception do
      Ctx.Response.Status(400).Json(Format('{"error": "%s"}', [E.Message]));
  end;
end;

procedure TCartController.ClearCart(Ctx: IHttpContext);
var
  UserId: string;
begin
  UserId := Ctx.User.Identity.Name;
  FService.ClearCart(UserId);
  Ctx.Response.Status(204);
end;

{ TOrdersController }

constructor TOrdersController.Create(Service: IOrderService);
begin
  FService := Service;
end;

procedure TOrdersController.Checkout(Ctx: IHttpContext);
var
  UserId: string;
  Order: TOrder;
  Response: TOrderResponse;
begin
  try
    UserId := Ctx.User.Identity.Name;
    Order := FService.Checkout(UserId);

    Response.OrderId := Order.Id;
    Response.Total := Order.TotalAmount;
    Response.Status := Order.Status;
    Response.Message := 'Order placed successfully';

    Ctx.Response.Status(201).Json(TDextJson.Serialize(Response));
  except
    on E: Exception do
      Ctx.Response.Status(400).Json(Format('{"error": "%s"}', [E.Message]));
  end;
end;

procedure TOrdersController.GetMyOrders(Ctx: IHttpContext);
var
  UserId: string;
  Orders: TArray<TOrder>;
begin
  UserId := Ctx.User.Identity.Name;
  Orders := FService.GetUserOrders(UserId);
  Ctx.Response.Json(TDextJson.Serialize(Orders));
end;

initialization
  TAuthController.ClassName;
  TProductsController.ClassName;
  TCartController.ClassName;
  TOrdersController.ClassName;

end.

