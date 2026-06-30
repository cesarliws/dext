unit EventBusDemo.Tests;

/// <summary>
///   Demonstrates testing with TEventBusTracker.
///   TEventBusTracker is a fake IEventBus that records every published event
///   without running any real handlers - perfect for unit tests.
///
///   TEventBusTracker.Register registers the tracker as the IEventBus
///   singleton, so any service that injects IEventBus or
///   IEventPublisher&lt;T&gt; will use it.
/// </summary>

interface

procedure RunTests;

implementation

uses
  System.SysUtils,
  Dext, Dext.DI.Interfaces,                    // TDextServices, IServiceProvider, TServiceProviderExtensions
  Dext.DI.Core,            // TServiceType
  Dext.Events,             // facade
  Dext.Events.Extensions,  // AddEventBus, AddEventPublisher, etc. (DI helpers)
  Dext.Events.Interfaces,  // IEventBus, TEventBusExtensions.Publish<T>
  Dext.Events.Testing,     // TEventBusTracker
  EventBusDemo.Events,
  EventBusDemo.Services;

procedure PrintResult(const ATest: string; const APassed: Boolean);
begin
  if APassed then
    WriteLn('  [PASS] ' + ATest)
  else
    WriteLn('  [FAIL] ' + ATest);
end;

procedure Test_OrderService_PublishesOrderPlacedEvent;
var
  Services: TDextServices;
  Provider: IServiceProvider;
  Tracker: TEventBusTracker;
  OrderSvc: IOrderService;
  Last: TOrderPlacedEvent;
begin
  // Arrange
  Services := TDextServices.New;
  TEventBusTracker.Register(Services, Tracker)
    .AddEventPublisher<TOrderPlacedEvent>
    .AddTransient<IOrderService, TOrderService>;

  Provider := Services.BuildServiceProvider;
  OrderSvc := TDextServices.GetRequiredService<IOrderService>(Provider);

  // Act
  OrderSvc.PlaceOrder(101, 55, 3, 149.90);

  // Assert
  PrintResult('PlaceOrder publishes TOrderPlacedEvent',
    Tracker.HasPublished<TOrderPlacedEvent>);
  PrintResult('PublishedCount = 1',
    Tracker.PublishedCount<TOrderPlacedEvent> = 1);

  Last := Tracker.LastPublished<TOrderPlacedEvent>;
  PrintResult('OrderId = 101',    Last.OrderId = 101);
  PrintResult('CustomerId = 55',  Last.CustomerId = 55);
  PrintResult('ItemCount = 3',    Last.ItemCount = 3);
  PrintResult('TotalAmount correct', Abs(Last.TotalAmount - 149.90) < 0.01);
end;

procedure Test_PlaceOrder_MultipleOrders_CountsCorrectly;
var
  Services: TDextServices;
  Provider: IServiceProvider;
  Tracker: TEventBusTracker;
  OrderSvc: IOrderService;
  All: TArray<TOrderPlacedEvent>;
begin
  Services := TDextServices.New;
  TEventBusTracker.Register(Services, Tracker)
    .AddEventPublisher<TOrderPlacedEvent>
    .AddTransient<IOrderService, TOrderService>;

  Provider := Services.BuildServiceProvider;
  OrderSvc := TDextServices.GetRequiredService<IOrderService>(Provider);

  OrderSvc.PlaceOrder(201, 10, 1, 29.90);
  OrderSvc.PlaceOrder(202, 11, 2, 59.80);
  OrderSvc.PlaceOrder(203, 12, 5, 199.50);

  PrintResult('Three orders -> count = 3',
    Tracker.PublishedCount<TOrderPlacedEvent> = 3);

  All := Tracker.GetPublished<TOrderPlacedEvent>;
  PrintResult('GetPublished returns 3 items', Length(All) = 3);
  PrintResult('First order ID = 201', All[0].OrderId = 201);
  PrintResult('Last order ID = 203',  All[2].OrderId = 203);

  // LastPublished returns the most recent
  PrintResult('LastPublished = order 203',
    Tracker.LastPublished<TOrderPlacedEvent>.OrderId = 203);
end;

procedure Test_Clear_ResetsTrackerState;
var
  Services: TDextServices;
  Provider: IServiceProvider;
  Tracker: TEventBusTracker;
  Bus: IEventBus;
  Evt: TOrderPlacedEvent;
begin
  Services := TDextServices.New;
  TEventBusTracker.Register(Services, Tracker);

  Provider := Services.BuildServiceProvider;
  Bus := TDextServices.GetRequiredService<IEventBus>(Provider);

  Evt.OrderId := 1; Evt.CustomerId := 1; Evt.ItemCount := 1; Evt.TotalAmount := 10;
  TEventBusExtensions.Publish<TOrderPlacedEvent>(Bus, Evt);

  PrintResult('Before Clear: HasPublished = True',
    Tracker.HasPublished<TOrderPlacedEvent>);

  Tracker.Clear;

  PrintResult('After Clear: HasPublished = False',
    not Tracker.HasPublished<TOrderPlacedEvent>);
  PrintResult('After Clear: Count = 0',
    Tracker.PublishedCount<TOrderPlacedEvent> = 0);
end;

procedure Test_NoHandlersPublished_NothingInTracker;
var
  Services: TDextServices;
  Provider: IServiceProvider;
  Tracker: TEventBusTracker;
  Bus: IEventBus;
  Evt: TPaymentProcessedEvent;
begin
  Services := TDextServices.New;
  TEventBusTracker.Register(Services, Tracker);

  Provider := Services.BuildServiceProvider;
  Bus := TDextServices.GetRequiredService<IEventBus>(Provider);

  // Publish a DIFFERENT event type (TPaymentProcessedEvent)
  Evt.OrderId := 99; Evt.Amount := 50; Evt.PaymentMethod := 'Pix';
  TEventBusExtensions.Publish<TPaymentProcessedEvent>(Bus, Evt);

  // Tracker records ALL published events, not just those with handlers
  PrintResult('TPaymentProcessedEvent recorded',
    Tracker.HasPublished<TPaymentProcessedEvent>);

  // But TOrderPlacedEvent was never published
  PrintResult('TOrderPlacedEvent NOT in tracker',
    not Tracker.HasPublished<TOrderPlacedEvent>);
end;

procedure RunTests;
begin
  WriteLn('  --- Test: PlaceOrder publishes correct event ---');
  Test_OrderService_PublishesOrderPlacedEvent;
  WriteLn;

  WriteLn('  --- Test: Multiple orders counted correctly ---');
  Test_PlaceOrder_MultipleOrders_CountsCorrectly;
  WriteLn;

  WriteLn('  --- Test: Clear resets tracker state ---');
  Test_Clear_ResetsTrackerState;
  WriteLn;

  WriteLn('  --- Test: Different event types are isolated ---');
  Test_NoHandlersPublished_NothingInTracker;
end;

end.
