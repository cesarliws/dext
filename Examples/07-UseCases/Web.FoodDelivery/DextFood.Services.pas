unit DextFood.Services;

interface

type
  /// <summary>
  /// Interface para o serviço de pedidos do DextFood.
  /// </summary>
  IOrderService = interface
    ['{F1D7E4B2-9A8C-4BDE-AD6F-7C9E1D2D3E4F}']
    procedure CreateOrder(const Total: Currency);
  end;

  /// <summary>
  /// Implementação do serviço de pedidos.
  /// </summary>
  TOrderService = class(TInterfacedObject, IOrderService)
  public
    procedure CreateOrder(const Total: Currency);
  end;

implementation

uses
  System.SysUtils;

{ TOrderService }

procedure TOrderService.CreateOrder(const Total: Currency);
begin
  // Lógica de negócio de pedidos...
  Writeln(Format('🛒 Processando novo pedido: %m', [Total]));
end;

end.
