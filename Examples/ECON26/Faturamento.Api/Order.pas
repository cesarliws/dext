unit Order;

interface

uses
  Dext,
  Dext.Entity,
  Dext.Core.SmartTypes;

type
  TNovoPedido = class
  private
    FProductId: Integer;
    FQty: Integer;
  public
    [Required]
    property ProductId: Integer read FProductId write FProductId;
    [Required, Range(1, 999)]
    property Qty: Integer read FQty write FQty;
  end;

  TPlaceOrderDto = TNovoPedido;

  [Table('Orders')]
  TOrder = class
  private
    FId: IntType;
    FProductId: IntType;
    FQuantity: IntType;
  public
    [PK, AutoInc]
    property Id: IntType read FId write FId;
    property ProductId: IntType read FProductId write FProductId;
    property Quantity: IntType read FQuantity write FQuantity;
  end;

implementation

end.
