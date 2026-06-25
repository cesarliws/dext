unit EventBusDemo.Services;

/// <summary>
///   Application services for the EventBusDemo.
///
///   TOrderService uses the narrow IEventPublisher&lt;TOrderPlacedEvent&gt;
///   instead of the full IEventBus - it declares exactly which event it emits.
///
///   TPaymentService uses IEventBus directly, since it publishes two different
///   event types (TPaymentProcessedEvent and TInventoryLowEvent).
/// </summary>

interface

uses
  System.SysUtils,
  Dext.Events,
  Dext.Events.Interfaces,
  EventBusDemo.Events;

type
  IOrderService = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    procedure PlaceOrder(AOrderId, ACustomerId, AItems: Integer;
      ATotal: Currency);
  end;

  IPaymentService = interface
    ['{B2C3D4E5-F6A7-8901-BCDE-F12345678901}']
    procedure ProcessPayment(AOrderId: Integer; AAmount: Currency;
      const AMethod: string);
  end;

  /// <summary>
  ///   Uses IEventPublisher&lt;TOrderPlacedEvent&gt; - narrow, ISP-compliant.
  ///   In tests: swap the publisher for a TEventBusTracker and assert on events.
  /// </summary>
  TOrderService = class(TInterfacedObject, IOrderService)
  private
    FPublisher: IEventPublisher<TOrderPlacedEvent>;
  public
    constructor Create(const APublisher: IEventPublisher<TOrderPlacedEvent>);
    procedure PlaceOrder(AOrderId, ACustomerId, AItems: Integer;
      ATotal: Currency);
  end;

  /// <summary>
  ///   Uses IEventBus directly - publishes two different event types.
  ///   Simulates low-inventory detection after every payment.
  /// </summary>
  TPaymentService = class(TInterfacedObject, IPaymentService)
  private
    FBus: IEventBus;
  public
    constructor Create(const ABus: IEventBus);
    procedure ProcessPayment(AOrderId: Integer; AAmount: Currency;
      const AMethod: string);
  end;

implementation

{ TOrderService }

constructor TOrderService.Create(
  const APublisher: IEventPublisher<TOrderPlacedEvent>);
begin
  inherited Create;
  FPublisher := APublisher;
end;

procedure TOrderService.PlaceOrder(AOrderId, ACustomerId, AItems: Integer;
  ATotal: Currency);
var
  Event: TOrderPlacedEvent;
begin
  Event.OrderId      := AOrderId;
  Event.CustomerId   := ACustomerId;
  Event.ItemCount    := AItems;
  Event.TotalAmount  := ATotal;
  FPublisher.Publish(Event);
end;

{ TPaymentService }

constructor TPaymentService.Create(const ABus: IEventBus);
begin
  inherited Create;
  FBus := ABus;
end;

procedure TPaymentService.ProcessPayment(AOrderId: Integer; AAmount: Currency;
  const AMethod: string);
var
  PayEvt: TPaymentProcessedEvent;
  InvEvt: TInventoryLowEvent;
begin
  PayEvt.OrderId       := AOrderId;
  PayEvt.Amount        := AAmount;
  PayEvt.PaymentMethod := AMethod;
  TEventBusExtensions.Publish<TPaymentProcessedEvent>(FBus, PayEvt);

  // Simulate: after deducting stock from payment, inventory drops low.
  InvEvt.ProductId    := 42;
  InvEvt.ProductName  := 'Widget Pro';
  InvEvt.CurrentStock := 3;
  InvEvt.MinimumStock := 10;
  TEventBusExtensions.Publish<TInventoryLowEvent>(FBus, InvEvt);
end;

end.
