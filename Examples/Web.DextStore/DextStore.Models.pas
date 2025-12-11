unit DextStore.Models;

interface

uses
  Dext;

type
  // ===========================================================================
  // 📦 Entities
  // ===========================================================================
  
  TProduct = class
  private
    FId: Integer;
    FName: string;
    FPrice: Currency;
    FStock: Integer;
    FCategory: string;
  public
    property Id: Integer read FId write FId;
    property Name: string read FName write FName;
    property Price: Currency read FPrice write FPrice;
    property Stock: Integer read FStock write FStock;
    property Category: string read FCategory write FCategory;
  end;

  TCartItem = class
  private
    FProductId: Integer;
    FQuantity: Integer;
    FProductName: string;
    FUnitPrice: Currency;
  public
    property ProductId: Integer read FProductId write FProductId;
    property ProductName: string read FProductName write FProductName;
    property Quantity: Integer read FQuantity write FQuantity;
    property UnitPrice: Currency read FUnitPrice write FUnitPrice;
    
    function Total: Currency;
  end;

  TOrder = class
  private
    FId: Integer;
    FUserId: string;
    FItems: TArray<TCartItem>;
    FTotalAmount: Currency;
    FCreatedAt: TDateTime;
    FStatus: string;
  public
    property Id: Integer read FId write FId;
    property UserId: string read FUserId write FUserId;
    property Items: TArray<TCartItem> read FItems write FItems;
    property TotalAmount: Currency read FTotalAmount write FTotalAmount;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property Status: string read FStatus write FStatus;

    destructor Destroy; override;
  end;

  // ===========================================================================
  // 📝 DTOs (Data Transfer Objects)
  // ===========================================================================

  TLoginRequest = record
    [Required]
    Username: string;
    [Required]
    Password: string;
  end;

  TCreateProductRequest = record
    [Required]
    [StringLength(3, 100)]
    Name: string;
    
    [Required]
    Price: Currency;
    
    [Required]
    Stock: Integer;
    
    Category: string;
  end;

  TAddToCartRequest = record
    [Required]
    ProductId: Integer;
    
    [Required]
    Quantity: Integer;
  end;

  TOrderResponse = record
    OrderId: Integer;
    Total: Currency;
    Status: string;
    Message: string;
  end;

implementation

{ TCartItem }

function TCartItem.Total: Currency;
begin
  Result := FQuantity * FUnitPrice;
end;

{ TOrder }

destructor TOrder.Destroy;
begin
  for var Item in FItems do
    if Assigned(Item) then
      Item.Free;
  inherited;
end;

end.
