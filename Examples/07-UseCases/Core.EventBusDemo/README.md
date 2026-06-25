# Core.EventBusDemo - Dext Event Bus Showcase

A focused console application that walks through all eight event bus features
in isolated, self-contained demos. No web server or database required - just
build and run.

## What This Example Teaches

| Demo | Feature | Key API |
|------|---------|---------|
| 1 | Basic publish/subscribe | `AddEventBus`, `AddEventHandler`, `Publish<T>` |
| 2 | Multiple handlers per event | `AddEventHandler` × 3 |
| 3 | Global pipeline behavior | `AddEventBehavior<TBehavior>` |
| 4 | Per-event behavior + short-circuit | `AddEventBehaviorFor<TEvent, TBehavior>` |
| 5 | Typed publisher (ISP) | `AddEventPublisher<T>`, `IEventPublisher<T>` |
| 6 | Fire-and-forget | `PublishBackground<T>` |
| 7 | Exception aggregation | `EEventDispatchAggregate` |
| 8 | Unit testing | `TEventBusTracker`, `TEventBusTracker.Register` |

## Project Structure

```
EventsBus.Demo/
├── EventBusDemo.dpr       # Entry point - runs all 8 demos sequentially
├── EventBusDemo.dproj     # Delphi project file
├── EventBusDemo.Events.pas     # Plain record event definitions
├── EventBusDemo.Handlers.pas   # IEventHandler<T> implementations
├── EventBusDemo.Behaviors.pas  # Custom pipeline behaviors
├── EventBusDemo.Services.pas   # Application services (typed publisher usage)
└── EventBusDemo.Tests.pas      # TEventBusTracker unit tests
```

## Expected Output

```
╔══════════════════════════════════════════════════════════════╗
║         Dext Framework - Event Bus Demo                     ║
╚══════════════════════════════════════════════════════════════╝

================================================================
  Demo 1: Basic - One event, one handler
================================================================
  [Email]    Order #1 -> customer 100 confirmation sent  ($99.90)
  Result: 1 handler(s) invoked, 1 succeeded

================================================================
  Demo 2: Multiple handlers - all three run in order
================================================================
  [Email]    Order #2 -> customer 101 confirmation sent  ($249.00)
  [Audit]    Order #2 recorded in audit log (5 item(s))
  [Inventory] Order #2 -> 5 item(s) deducted from stock
  Result: 3 handler(s) invoked, 3 succeeded

================================================================
  Demo 3: Global behavior (TConsolePipelineBehavior wraps each handler)
================================================================
  [Pipeline] >> entering handler for TOrderPlacedEvent
  [Email]    Order #3 -> customer 102 confirmation sent  ($75.50)
  [Pipeline] << leaving handler for TOrderPlacedEvent
  [Pipeline] >> entering handler for TOrderPlacedEvent
  [Audit]    Order #3 recorded in audit log (1 item(s))
  [Pipeline] << leaving handler for TOrderPlacedEvent

  ... (Demo 4–8 output) ...

================================================================
  All demos completed.
================================================================
```

## Key Patterns Shown

### Multiple handlers

```pascal
Services
  .AddEventBus
  .AddEventHandler<TOrderPlacedEvent, TEmailNotificationHandler>
  .AddEventHandler<TOrderPlacedEvent, TAuditLogHandler>
  .AddEventHandler<TOrderPlacedEvent, TInventoryDeductHandler>;
```

### Pipeline behaviors

```pascal
// Custom behavior - implement IEventBehavior.Intercept, call ANext() to continue
type
  TConsolePipelineBehavior = class(TInterfacedObject, IEventBehavior)
    procedure Intercept(AEventType: PTypeInfo; const AEvent: TValue;
      const ANext: TEventNextDelegate);
  end;

procedure TConsolePipelineBehavior.Intercept(...);
begin
  WriteLn('>> entering ' + string(AEventType.Name));
  ANext();   // MUST call to continue
  WriteLn('<< leaving ' + string(AEventType.Name));
end;
```

### ISP-compliant typed publisher

```pascal
// TOrderService declares exactly what it can publish:
constructor TOrderService.Create(
  const APublisher: IEventPublisher<TOrderPlacedEvent>);

// vs the full bus - used when publishing multiple event types:
constructor TPaymentService.Create(const ABus: IEventBus);
```

### Unit tests with TEventBusTracker

```pascal
TEventBusTracker.Register(Services, Tracker)  // fake IEventBus - no real handlers
  .AddEventPublisher<TOrderPlacedEvent>
  .AddTransient<IOrderService, TOrderService>;

OrderSvc.PlaceOrder(101, 55, 3, 149.90);

Assert(Tracker.HasPublished<TOrderPlacedEvent>);
Assert(Tracker.LastPublished<TOrderPlacedEvent>.OrderId = 101);
```

## See Also

- [Event Bus documentation](../../Docs/Book/10-advanced/event-bus.md)
- `Sources/Events/Dext.Events.Interfaces.pas` - public interfaces
- `Sources/Events/Dext.Events.Bus.pas` - implementation details
- `Sources/Events/Dext.Events.Testing.pas` - TEventBusTracker
