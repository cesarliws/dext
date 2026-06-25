program EventBusDemo;

{***************************************************************************}
{                                                                           }
{  Core.EventBusDemo - Dext Framework Event Bus Showcase                   }
{                                                                           }
{  Demonstrates all event bus features:                                     }
{    1. Basic publish/subscribe (single handler)                            }
{    2. Multiple handlers for the same event type                           }
{    3. Global pipeline behavior                                            }
{    4. Per-event pipeline behavior                                         }
{    5. IEventPublisher<T> typed publisher (ISP)                            }
{    6. Background (fire-and-forget) publishing                             }
{    7. Exception aggregation (EEventDispatchAggregate)                     }
{    8. Testing with TEventBusTracker                                       }
{                                                                           }
{***************************************************************************}

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Threading,
  Dext,                    // TDextServices, IServiceProvider
  Dext.Utils,
  Dext.Events,             // facade
  Dext.Events.Extensions,  // AddEventBus, AddEventHandler, etc.
  Dext.Events.Interfaces,  // IEventBus, TEventBusExtensions
  Dext.Events.Behaviors,   // TEventExceptionBehavior (must be direct for generic resolution)
  Dext.Events.Testing,     // TEventBusTracker
  EventBusDemo.Events     in 'EventBusDemo.Events.pas',
  EventBusDemo.Handlers   in 'EventBusDemo.Handlers.pas',
  EventBusDemo.Behaviors  in 'EventBusDemo.Behaviors.pas',
  EventBusDemo.Services   in 'EventBusDemo.Services.pas',
  EventBusDemo.Tests      in 'EventBusDemo.Tests.pas';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

procedure Separator(const ATitle: string);
begin
  WriteLn;
  WriteLn('================================================================');
  WriteLn('  ' + ATitle);
  WriteLn('================================================================');
end;

function BuildProvider(const ASetup: TProc<TDextServices>): IServiceProvider;
var
  Services: TDextServices;
begin
  Services := TDextServices.New;
  ASetup(Services);
  Result := Services.BuildServiceProvider;
end;

function GetBus(const AProvider: IServiceProvider): IEventBus;
begin
  Result := TDextServices.GetRequiredService<IEventBus>(AProvider);
end;

// ---------------------------------------------------------------------------
// Demo 1 - Basic: one event, one handler
// ---------------------------------------------------------------------------

procedure Demo1_Basic;
var
  Provider: IServiceProvider;
  Bus: IEventBus;
  Evt: TOrderPlacedEvent;
  Res: TPublishResult;
begin
  Separator('Demo 1: Basic - One event, one handler');

  Provider := BuildProvider(
    procedure(S: TDextServices)
    begin
      S.AddEventBus
       .AddEventHandler<TOrderPlacedEvent, TEmailNotificationHandler>;
    end);

  Bus := GetBus(Provider);
  Evt.OrderId := 1;
  Evt.CustomerId := 100;
  Evt.TotalAmount := 99.90;
  Evt.ItemCount := 2;
  Res := TEventBusExtensions.Publish<TOrderPlacedEvent>(Bus, Evt);

  WriteLn(Format('  Result: %d handler(s) invoked, %d succeeded',
    [Res.HandlersInvoked, Res.HandlersSucceeded]));
end;

// ---------------------------------------------------------------------------
// Demo 2 - Multiple handlers for the same event
// ---------------------------------------------------------------------------

procedure Demo2_MultipleHandlers;
var
  Provider: IServiceProvider;
  Bus: IEventBus;
  Evt: TOrderPlacedEvent;
  Res: TPublishResult;
begin
  Separator('Demo 2: Multiple handlers - all three run in order');

  Provider := BuildProvider(
    procedure(S: TDextServices)
    begin
      S.AddEventBus
       .AddEventHandler<TOrderPlacedEvent, TEmailNotificationHandler>
       .AddEventHandler<TOrderPlacedEvent, TAuditLogHandler>
       .AddEventHandler<TOrderPlacedEvent, TInventoryDeductHandler>;
    end);

  Bus := GetBus(Provider);
  Evt.OrderId := 2; 
  Evt.CustomerId := 101; 
  Evt.TotalAmount := 249.00; 
  Evt.ItemCount := 5;
  Res := TEventBusExtensions.Publish<TOrderPlacedEvent>(Bus, Evt);

  WriteLn(Format('  Result: %d handler(s) invoked, %d succeeded',
    [Res.HandlersInvoked, Res.HandlersSucceeded]));
end;

// ---------------------------------------------------------------------------
// Demo 3 - Global behavior
// ---------------------------------------------------------------------------

procedure Demo3_GlobalBehavior;
var
  Provider: IServiceProvider;
  Bus: IEventBus;
  Evt: TOrderPlacedEvent;
begin
  Separator('Demo 3: Global behavior (TConsolePipelineBehavior wraps each handler)');

  Provider := BuildProvider(
    procedure(S: TDextServices)
    begin
      S.AddEventBus
       .AddEventHandler<TOrderPlacedEvent, TEmailNotificationHandler>
       .AddEventHandler<TOrderPlacedEvent, TAuditLogHandler>
       .AddEventBehavior<TConsolePipelineBehavior>;  // global - wraps ALL handlers
    end);

  Bus := GetBus(Provider);
  Evt.OrderId := 3; 
  Evt.CustomerId := 102; 
  Evt.TotalAmount := 75.50; 
  Evt.ItemCount := 1;
  TEventBusExtensions.Publish<TOrderPlacedEvent>(Bus, Evt);
end;

// ---------------------------------------------------------------------------
// Demo 4 - Per-event behavior
// ---------------------------------------------------------------------------

procedure Demo4_PerEventBehavior;
var
  Provider: IServiceProvider;
  Bus: IEventBus;
  ValidEvt, InvalidEvt: TOrderPlacedEvent;
  PayEvt: TPaymentProcessedEvent;
begin
  Separator('Demo 4: Per-event behavior (TOrderValidationBehavior for TOrderPlacedEvent only)');

  Provider := BuildProvider(
    procedure(S: TDextServices)
    begin
      S.AddEventBus
       .AddEventHandler<TOrderPlacedEvent, TEmailNotificationHandler>
       .AddEventHandler<TPaymentProcessedEvent, TPaymentReceiptHandler>
       // Global behavior runs outermost for ALL events
       .AddEventBehavior<TConsolePipelineBehavior>
       // Per-event behavior: only applied to TOrderPlacedEvent, runs INSIDE global
       .AddEventBehaviorFor<TOrderPlacedEvent, TOrderValidationBehavior>;
    end);

  Bus := GetBus(Provider);

  WriteLn('  >> Valid order ($120.00):');
  ValidEvt.OrderId := 4; 
  ValidEvt.CustomerId := 103;
  ValidEvt.TotalAmount := 120.00; 
  ValidEvt.ItemCount := 3;
  TEventBusExtensions.Publish<TOrderPlacedEvent>(Bus, ValidEvt);

  WriteLn;
  WriteLn('  >> Invalid order ($0.00 - validation will short-circuit):');
  InvalidEvt.OrderId := 5; 
  InvalidEvt.CustomerId := 104;
  InvalidEvt.TotalAmount := 0; 
  InvalidEvt.ItemCount := 0;
  TEventBusExtensions.Publish<TOrderPlacedEvent>(Bus, InvalidEvt);

  WriteLn;
  WriteLn('  >> Payment event (no validation behavior applies here):');
  PayEvt.OrderId := 4; 
  PayEvt.Amount := 120.00; 
  PayEvt.PaymentMethod := 'CreditCard';
  TEventBusExtensions.Publish<TPaymentProcessedEvent>(Bus, PayEvt);
end;

// ---------------------------------------------------------------------------
// Demo 5 - IEventPublisher<T> typed publisher
// ---------------------------------------------------------------------------

procedure Demo5_TypedPublisher;
var
  Provider: IServiceProvider;
  OrderSvc: IOrderService;
  PaySvc: IPaymentService;
begin
  Separator('Demo 5: IEventPublisher<T> - typed publisher injected into services');

  Provider := BuildProvider(
    procedure(S: TDextServices)
    begin
      S.AddEventBus
       .AddEventHandler<TOrderPlacedEvent,    TEmailNotificationHandler>
       .AddEventHandler<TOrderPlacedEvent,    TAuditLogHandler>
       .AddEventHandler<TPaymentProcessedEvent, TPaymentReceiptHandler>
       .AddEventHandler<TInventoryLowEvent,   TInventoryAlertHandler>
       // Register typed publishers
       .AddEventPublisher<TOrderPlacedEvent>
       // Application services
       .AddTransient<IOrderService,   TOrderService>
       .AddTransient<IPaymentService, TPaymentService>;
    end);

  // TOrderService only knows about IEventPublisher<TOrderPlacedEvent>
  OrderSvc := TDextServices.GetRequiredService<IOrderService>(Provider);
  OrderSvc.PlaceOrder(6, 200, 4, 350.00);

  WriteLn;

  // TPaymentService uses IEventBus and publishes two event types
  PaySvc := TDextServices.GetRequiredService<IPaymentService>(Provider);
  PaySvc.ProcessPayment(6, 350.00, 'Pix');
end;

// ---------------------------------------------------------------------------
// Demo 6 - Background (fire-and-forget) publishing
// ---------------------------------------------------------------------------

procedure Demo6_BackgroundPublish;
var
  Provider: IServiceProvider;
  Bus: IEventBus;
  Evt: TOrderPlacedEvent;
begin
  Separator('Demo 6: PublishBackground - fire-and-forget on a thread pool thread');

  Provider := BuildProvider(
    procedure(S: TDextServices)
    begin
      S.AddEventBus
       .AddEventHandler<TOrderPlacedEvent, TEmailNotificationHandler>
       .AddEventHandler<TOrderPlacedEvent, TAuditLogHandler>
       .AddEventBehavior<TEventExceptionBehavior>; // recommended for background
    end);

  Bus := GetBus(Provider);
  Evt.OrderId := 7; 
  Evt.CustomerId := 300; 
  Evt.TotalAmount := 55.00; 
  Evt.ItemCount := 1;

  WriteLn('  Calling PublishBackground - returns immediately...');
  TEventBusExtensions.PublishBackground<TOrderPlacedEvent>(Bus, Evt);
  WriteLn('  ...returned. Handlers run asynchronously:');

  // Give the background task time to complete before the demo moves on.
  Sleep(200);
end;

// ---------------------------------------------------------------------------
// Demo 7 - Exception aggregation
// ---------------------------------------------------------------------------

procedure Demo7_ExceptionAggregation;
var
  Provider: IServiceProvider;
  Bus: IEventBus;
  Evt: TOrderPlacedEvent;
  Err: string;
begin
  Separator('Demo 7: Exception aggregation - all handlers run even when one fails');

  Provider := BuildProvider(
    procedure(S: TDextServices)
    begin
      S.AddEventBus
       .AddEventHandler<TOrderPlacedEvent, TEmailNotificationHandler> // succeeds
       .AddEventHandler<TOrderPlacedEvent, TAlwaysFailHandler>        // raises
       .AddEventHandler<TOrderPlacedEvent, TAuditLogHandler>;         // still runs
    end);

  Bus := GetBus(Provider);
  Evt.OrderId := 8; 
  Evt.CustomerId := 400; 
  Evt.TotalAmount := 77.00; 
  Evt.ItemCount := 2;

  try
    TEventBusExtensions.Publish<TOrderPlacedEvent>(Bus, Evt);
  except
    on E: EEventDispatchAggregate do
    begin
      WriteLn(Format('  EEventDispatchAggregate: %s', [E.Message]));
      WriteLn('  Individual errors:');
      for Err in E.Errors do
        WriteLn('    - ' + Err);
    end;
  end;
end;

// ---------------------------------------------------------------------------
// Demo 8 - Testing with TEventBusTracker
// ---------------------------------------------------------------------------

procedure Demo8_Testing;
begin
  Separator('Demo 8: TEventBusTracker - unit testing without real handlers');
  RunTests;
end;

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

begin
  try
    SetConsoleCharSet(65001);
    WriteLn('');
    WriteLn('╔══════════════════════════════════════════════════════════════╗');
    WriteLn('║         Dext Framework - Event Bus Demo                      ║');
    WriteLn('╚══════════════════════════════════════════════════════════════╝');

    Demo1_Basic;
    Demo2_MultipleHandlers;
    Demo3_GlobalBehavior;
    Demo4_PerEventBehavior;
    Demo5_TypedPublisher;
    Demo6_BackgroundPublish;
    Demo7_ExceptionAggregation;
    Demo8_Testing;

    WriteLn;
    WriteLn('================================================================');
    WriteLn('  All demos completed.');
    WriteLn('================================================================');

  except
    on E: Exception do
      WriteLn('Unhandled: ' + E.ClassName + ': ' + E.Message);
  end;

  ConsolePause;
end.
