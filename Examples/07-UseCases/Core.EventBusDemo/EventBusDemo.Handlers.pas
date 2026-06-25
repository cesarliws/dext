unit EventBusDemo.Handlers;

/// <summary>
///   IEventHandler&lt;T&gt; implementations for the EventBusDemo.
///   Each handler prints its action to the console so the demo output
///   makes clear which handlers were invoked and in what order.
/// </summary>

interface

uses
  System.SysUtils,
  System.Classes,
  Dext.Events,
  Dext.Events.Interfaces,
  EventBusDemo.Events;

type
  // --------------------------------------------------------------------------
  // TOrderPlacedEvent handlers (three handlers - all run in order)
  // --------------------------------------------------------------------------

  TEmailNotificationHandler = class(TInterfacedObject,
    IEventHandler<TOrderPlacedEvent>)
  public
    procedure Handle(const AEvent: TOrderPlacedEvent);
  end;

  TAuditLogHandler = class(TInterfacedObject,
    IEventHandler<TOrderPlacedEvent>)
  public
    procedure Handle(const AEvent: TOrderPlacedEvent);
  end;

  TInventoryDeductHandler = class(TInterfacedObject,
    IEventHandler<TOrderPlacedEvent>)
  public
    procedure Handle(const AEvent: TOrderPlacedEvent);
  end;

  // --------------------------------------------------------------------------
  // TPaymentProcessedEvent handler
  // --------------------------------------------------------------------------

  TPaymentReceiptHandler = class(TInterfacedObject,
    IEventHandler<TPaymentProcessedEvent>)
  public
    procedure Handle(const AEvent: TPaymentProcessedEvent);
  end;

  // --------------------------------------------------------------------------
  // TInventoryLowEvent handler
  // --------------------------------------------------------------------------

  TInventoryAlertHandler = class(TInterfacedObject,
    IEventHandler<TInventoryLowEvent>)
  public
    procedure Handle(const AEvent: TInventoryLowEvent);
  end;

  // --------------------------------------------------------------------------
  // Deliberately failing handler - used by the exception demo
  // --------------------------------------------------------------------------

  TAlwaysFailHandler = class(TInterfacedObject,
    IEventHandler<TOrderPlacedEvent>)
  public
    procedure Handle(const AEvent: TOrderPlacedEvent);
  end;

implementation

{ TEmailNotificationHandler }

procedure TEmailNotificationHandler.Handle(const AEvent: TOrderPlacedEvent);
begin
  WriteLn(Format('  [Email]    Order #%d -> customer %d confirmation sent  ($%.2f)',
    [AEvent.OrderId, AEvent.CustomerId, AEvent.TotalAmount]));
end;

{ TAuditLogHandler }

procedure TAuditLogHandler.Handle(const AEvent: TOrderPlacedEvent);
begin
  WriteLn(Format('  [Audit]    Order #%d recorded in audit log (%d item(s))',
    [AEvent.OrderId, AEvent.ItemCount]));
end;

{ TInventoryDeductHandler }

procedure TInventoryDeductHandler.Handle(const AEvent: TOrderPlacedEvent);
begin
  WriteLn(Format('  [Inventory] Order #%d -> %d item(s) deducted from stock',
    [AEvent.OrderId, AEvent.ItemCount]));
end;

{ TPaymentReceiptHandler }

procedure TPaymentReceiptHandler.Handle(const AEvent: TPaymentProcessedEvent);
begin
  WriteLn(Format('  [Receipt]  Order #%d payment of $%.2f via %s processed',
    [AEvent.OrderId, AEvent.Amount, AEvent.PaymentMethod]));
end;

{ TInventoryAlertHandler }

procedure TInventoryAlertHandler.Handle(const AEvent: TInventoryLowEvent);
begin
  WriteLn(Format('  [ALERT]    Product "%s" (ID %d): stock %d < minimum %d - reorder needed!',
    [AEvent.ProductName, AEvent.ProductId, AEvent.CurrentStock, AEvent.MinimumStock]));
end;

{ TAlwaysFailHandler }

procedure TAlwaysFailHandler.Handle(const AEvent: TOrderPlacedEvent);
begin
  raise EInvalidOperation.CreateFmt(
    'Simulated failure processing Order #%d', [AEvent.OrderId]);
end;

end.
