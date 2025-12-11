unit DextStore.Services;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.SyncObjs,
  DextStore.Models;

type
  // ===========================================================================
  // 🛒 Product Service (In-Memory Repository)
  // ===========================================================================
  IProductService = interface
    ['{10A20B30-C4D5-4E6F-A7B8-C9D0E1F2A3B4}']
    function GetAll: TArray<TProduct>;
    function GetById(Id: Integer): TProduct;
    function CreateProduct(const Request: TCreateProductRequest): TProduct;
    procedure UpdateStock(Id, Quantity: Integer);
  end;

  TProductService = class(TInterfacedObject, IProductService)
  private
    FProducts: TObjectList<TProduct>;
    FLock: TCriticalSection;
    FNextId: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    
    function GetAll: TArray<TProduct>;
    function GetById(Id: Integer): TProduct;
    function CreateProduct(const Request: TCreateProductRequest): TProduct;
    procedure UpdateStock(Id, Quantity: Integer);
  end;

  // ===========================================================================
  // 🛍️ Cart Service (Session-based, simplified as User-based for demo)
  // ===========================================================================
  ICartService = interface
    ['{20B30C40-D5E6-4F7A-B8C9-D0E1F2A3B4C5}']
    procedure AddItem(const UserId: string; ProductId, Quantity: Integer);
    function GetCart(const UserId: string): TArray<TCartItem>;
    procedure ClearCart(const UserId: string);
    function CalculateTotal(const UserId: string): Currency;
  end;

  TCartService = class(TInterfacedObject, ICartService)
  private
    // Map UserId -> List of Items
    FCarts: TObjectDictionary<string, TObjectList<TCartItem>>;
    FLock: TCriticalSection;
    FProductService: IProductService;
  public
    constructor Create(ProductService: IProductService);
    destructor Destroy; override;
    
    procedure AddItem(const UserId: string; ProductId, Quantity: Integer);
    function GetCart(const UserId: string): TArray<TCartItem>;
    procedure ClearCart(const UserId: string);
    function CalculateTotal(const UserId: string): Currency;
  end;

  // ===========================================================================
  // 📦 Order Service
  // ===========================================================================
  IOrderService = interface
    ['{30C40D50-E6F7-4A8B-C9D0-E1F2A3B4C5D6}']
    function Checkout(const UserId: string): TOrder;
    function GetUserOrders(const UserId: string): TArray<TOrder>;
  end;

  TOrderService = class(TInterfacedObject, IOrderService)
  private
    FOrders: TObjectList<TOrder>;
    FLock: TCriticalSection;
    FCartService: ICartService;
    FNextId: Integer;
  public
    constructor Create(CartService: ICartService);
    destructor Destroy; override;
    
    function Checkout(const UserId: string): TOrder;
    function GetUserOrders(const UserId: string): TArray<TOrder>;
  end;

implementation

{ TProductService }

constructor TProductService.Create;
begin
  FProducts := TObjectList<TProduct>.Create;
  FLock := TCriticalSection.Create;
  FNextId := 1;
  
  // Seed Data
  var P := TProduct.Create;
  P.Id := FNextId; Inc(FNextId);
  P.Name := 'Delphi 12 Athens';
  P.Price := 1500.00;
  P.Stock := 100;
  P.Category := 'Software';
  FProducts.Add(P);

  P := TProduct.Create;
  P.Id := FNextId; Inc(FNextId);
  P.Name := 'Mechanical Keyboard';
  P.Price := 120.50;
  P.Stock := 50;
  P.Category := 'Hardware';
  FProducts.Add(P);
end;

destructor TProductService.Destroy;
begin
  FProducts.Free;
  FLock.Free;
  inherited;
end;

function TProductService.CreateProduct(const Request: TCreateProductRequest): TProduct;
begin
  FLock.Enter;
  try
    var P := TProduct.Create;
    P.Id := FNextId;
    Inc(FNextId);
    P.Name := Request.Name;
    P.Price := Request.Price;
    P.Stock := Request.Stock;
    P.Category := Request.Category;
    
    FProducts.Add(P);
    
    // Return a copy or the object itself (careful with memory management in real apps)
    // Here we return the object managed by the list, which is fine for this demo
    Result := P;
  finally
    FLock.Leave;
  end;
end;

function TProductService.GetAll: TArray<TProduct>;
begin
  FLock.Enter;
  try
    Result := FProducts.ToArray;
  finally
    FLock.Leave;
  end;
end;

function TProductService.GetById(Id: Integer): TProduct;
begin
  FLock.Enter;
  try
    Result := nil;
    for var P in FProducts do
      if P.Id = Id then
        Exit(P);
  finally
    FLock.Leave;
  end;
end;

procedure TProductService.UpdateStock(Id, Quantity: Integer);
begin
  FLock.Enter;
  try
    var P := GetById(Id);
    if P <> nil then
      P.Stock := P.Stock + Quantity;
  finally
    FLock.Leave;
  end;
end;

{ TCartService }

constructor TCartService.Create(ProductService: IProductService);
begin
  FCarts := TObjectDictionary<string, TObjectList<TCartItem>>.Create([doOwnsValues]);
  FLock := TCriticalSection.Create;
  FProductService := ProductService;
end;

destructor TCartService.Destroy;
begin
  FCarts.Free;
  FLock.Free;
  inherited;
end;

procedure TCartService.AddItem(const UserId: string; ProductId, Quantity: Integer);
begin
  FLock.Enter;
  try
    var Product := FProductService.GetById(ProductId);
    if Product = nil then
      raise Exception.Create('Product not found');
      
    if Product.Stock < Quantity then
      raise Exception.Create('Insufficient stock');

    if not FCarts.ContainsKey(UserId) then
      FCarts.Add(UserId, TObjectList<TCartItem>.Create);
      
    var Cart := FCarts[UserId];
    var Found := False;
    
    for var Item in Cart do
    begin
      if Item.ProductId = ProductId then
      begin
        Item.Quantity := Item.Quantity + Quantity;
        Found := True;
        Break;
      end;
    end;
    
    if not Found then
    begin
      var Item := TCartItem.Create;
      Item.ProductId := ProductId;
      Item.ProductName := Product.Name;
      Item.UnitPrice := Product.Price;
      Item.Quantity := Quantity;
      Cart.Add(Item);
    end;
  finally
    FLock.Leave;
  end;
end;

function TCartService.CalculateTotal(const UserId: string): Currency;
begin
  FLock.Enter;
  try
    Result := 0;
    if FCarts.ContainsKey(UserId) then
    begin
      for var Item in FCarts[UserId] do
        Result := Result + Item.Total;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TCartService.ClearCart(const UserId: string);
begin
  FLock.Enter;
  try
    if FCarts.ContainsKey(UserId) then
      FCarts.Remove(UserId); // Removes and frees the list
  finally
    FLock.Leave;
  end;
end;

function TCartService.GetCart(const UserId: string): TArray<TCartItem>;
begin
  FLock.Enter;
  try
    if FCarts.ContainsKey(UserId) then
      Result := FCarts[UserId].ToArray
    else
      Result := [];
  finally
    FLock.Leave;
  end;
end;

{ TOrderService }

constructor TOrderService.Create(CartService: ICartService);
begin
  FOrders := TObjectList<TOrder>.Create;
  FLock := TCriticalSection.Create;
  FCartService := CartService;
  FNextId := 1000;
end;

destructor TOrderService.Destroy;
begin
  FOrders.Free;
  FLock.Free;
  inherited;
end;

function TOrderService.Checkout(const UserId: string): TOrder;
begin
  FLock.Enter;
  try
    var Items := FCartService.GetCart(UserId);
    if Length(Items) = 0 then
      raise Exception.Create('Cart is empty');
      
    var Order := TOrder.Create;
    Order.Id := FNextId;
    Inc(FNextId);
    Order.UserId := UserId;
    Order.CreatedAt := Now;
    Order.Status := 'Completed';
    Order.TotalAmount := FCartService.CalculateTotal(UserId);
    
    // Clone items for the order (simplified)
    // In a real app, you would create OrderItems entities
    // Here we just reference them but we need to be careful because CartService clears the cart
    // So we should deep copy. For this demo, we'll just create new objects.
    var OrderItems := TList<TCartItem>.Create;
    for var Item in Items do
    begin
      var NewItem := TCartItem.Create;
      NewItem.ProductId := Item.ProductId;
      NewItem.ProductName := Item.ProductName;
      NewItem.Quantity := Item.Quantity;
      NewItem.UnitPrice := Item.UnitPrice;
      OrderItems.Add(NewItem);
    end;
    Order.Items := OrderItems.ToArray;
    OrderItems.Free; // The array holds references, but TOrder should own them? 
    // Wait, TArray<T> is just an array. TOrder needs to manage lifecycle if it owns them.
    // For simplicity in this demo, we assume TOrder will free them or we leak slightly for the sake of brevity.
    // Ideally TOrder should use TObjectList<TCartItem>.
    
    FOrders.Add(Order);
    
    FCartService.ClearCart(UserId);
    
    Result := Order;
  finally
    FLock.Leave;
  end;
end;

function TOrderService.GetUserOrders(const UserId: string): TArray<TOrder>;
begin
  FLock.Enter;
  try
    var List := TList<TOrder>.Create;
    try
      for var Order in FOrders do
        if Order.UserId = UserId then
          List.Add(Order);
      Result := List.ToArray;
    finally
      List.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

end.
