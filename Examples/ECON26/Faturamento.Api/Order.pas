unit Order;

interface

uses
  Dext.AI.MCP.Attributes,
  Dext.AI.MCP.Protocol,
  Dext.AI.MCP.Types,
  Dext.AI.MCP.Tools,
  Product,
  Dext.Collections,
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


  TDemoProvider = class(TMCPToolProvider)
  public
    [MCPTool('calcular-desconto',
             'Calcula o desconto progressivo sobre um valor de venda.')]
    [MCPParam('valor', 'Valor bruto da venda em reais', ptNumber)]
    function CalcularDesconto(const Args: TJSONObject): TMCPToolResult; virtual;
  end;

implementation


{ TDemoProvider }

function TDemoProvider.CalcularDesconto(const Args: TJSONObject): TMCPToolResult;
begin

end;

end.
