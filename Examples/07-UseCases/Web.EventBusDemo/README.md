# Web.EventBus.Demo

Demonstrates **`AddScopedEventBus`** - the Dext Event Bus integrated into a web API controller.

## Key Concepts

| Concept | Description |
|---------|-------------|
| `AddScopedEventBus` | `IEventBus` is created **once per HTTP request**. Handlers share the caller's DI scope. |
| `AddEventBus` | Singleton bus - each `Publish` creates a fresh child scope (for background services). |
| `TEventExceptionBehavior` | Wraps handler failures as `EEventDispatchException` with event context. |
| `TEventBusExtensions.Publish<T>` | Static helper to publish typed events through the bus. |

## Why Scoped?

When a controller action publishes an event, the handler resolves in the **same HTTP request scope**. This means:

- Same `DbContext` → handler can write audit records in the same unit-of-work.
- Same identity / claims → no need to pass user context through the event.
- Same scoped services → consistent state across publisher and handler.

With `AddEventBus` (singleton), each `Publish` creates a *new child scope*, isolating handlers from the controller. Use that for background services where there is no ambient request scope.

## Structure

```
Web.EventBus.Demo/
├── Web.EventBusDemo.dpr                 # Entry point - listens on port 8080
├── Web.EventBusDemo.dproj               # Delphi project file
├── EventBusWebDemo.Startup.pas          # IStartup - delegates event bus config, adds controllers
├── EventBusWebDemo.EventBusConfig.pas   # Isolated event bus registration (record helper scope)
├── EventBusWebDemo.Controller.pas       # TTaskController - publishes events on each action
├── EventBusWebDemo.Events.pas           # Event records + handlers (WriteLn output)
└── Test.Web.EventBusDemo.ps1            # PowerShell integration test script
```

> **Why a separate `EventBusConfig` unit?** Delphi allows only one record helper per
> type in a compilation scope. `TEventBusDIExtensions` (from `Dext.Events.Extensions`)
> and `TWebServicesHelper` (from `Dext.Web`) both extend `TDextServices`. Isolating
> the event bus registration in its own unit prevents the helpers from shadowing
> each other.

## Running

Open `Web.EventBusDemo.dproj` in RAD Studio and press **Run**, or build with MSBuild:

```
msbuild Web.EventBusDemo.dproj /p:Config=Debug /p:Platform=Win32
```

Server starts on `http://localhost:8080`.

## Endpoints

| Method | Path | Action |
|--------|------|--------|
| `POST` | `/api/tasks` | Create task → publishes `TTaskCreatedEvent` |
| `PUT` | `/api/tasks/{id}/complete` | Complete task → publishes `TTaskCompletedEvent` |
| `DELETE` | `/api/tasks/{id}` | Cancel task → publishes `TTaskCancelledEvent` |
| `GET` | `/swagger` | Swagger UI |

## Example Requests

**Create a task:**
```bash
curl -X POST http://localhost:8080/api/tasks \
     -H "Content-Type: application/json" \
     -d '{"title":"Fix login bug","assignedTo":"Alice"}'
```

**Complete a task:**
```bash
curl -X PUT http://localhost:8080/api/tasks/1/complete \
     -H "Content-Type: application/json" \
     -d '{"completedBy":"Alice"}'
```

**Cancel a task:**
```bash
curl -X DELETE http://localhost:8080/api/tasks/1 \
     -H "Content-Type: application/json" \
     -d '{"reason":"No longer needed"}'
```

## Expected Server Console Output

Each request triggers a handler that writes to the server console:

```
  [Handler] Task #1 created: "Fix login bug" assigned to Alice
  [Handler] Task #1 completed by Alice at 14:32:07
  [Handler] Task #1 cancelled. Reason: No longer needed
```

If a handler raises an exception, `TEventExceptionBehavior` wraps it as `EEventDispatchException` with the event type name for structured error context.

## Registration Pattern

Event bus registration is isolated in `EventBusWebDemo.EventBusConfig.pas`:

```pascal
procedure ConfigureEventBus(const Services: TDextServices);
begin
  Services
    .AddScopedEventBus

    .AddEventHandler<TTaskCreatedEvent, TTaskCreatedHandler>
    .AddEventHandler<TTaskCompletedEvent, TTaskCompletedHandler>
    .AddEventHandler<TTaskCancelledEvent, TTaskCancelledHandler>

    .AddEventBehavior<TEventExceptionBehavior>;
end;
```

Called from `TStartup.ConfigureServices`:

```pascal
procedure TStartup.ConfigureServices(const Services: TDextServices;
  const Configuration: IConfiguration);
begin
  ConfigureEventBus(Services);
  Services.AddControllers;
end;
```

## Controller Pattern

The controller injects `IEventBus` and publishes events using the `TEventBusExtensions` static helper:

```pascal
[ApiController('/api/tasks')]
TTaskController = class
private
  FEventBus: IEventBus;
public
  constructor Create(const AEventBus: IEventBus);

  [HttpPost]
  function CreateTask(const Request: TCreateTaskRequest): IResult;
end;

function TTaskController.CreateTask(const Request: TCreateTaskRequest): IResult;
var
  Event: TTaskCreatedEvent;
begin
  Event.TaskId     := FNextId;
  Event.Title      := Request.Title;
  Event.AssignedTo := Request.AssignedTo;
  Event.CreatedAt  := Now;
  TEventBusExtensions.Publish<TTaskCreatedEvent>(FEventBus, Event);

  Result := Results.Created<TTaskResponse>('/api/tasks/' + IntToStr(FNextId), Response);
end;
```

## Handler Pattern

Handlers are resolved from the request scope. In this demo they use `WriteLn` for
server-console output. In production you would inject scoped services:

```pascal
TTaskCreatedHandler = class(TInterfacedObject, IEventHandler<TTaskCreatedEvent>)
public
  procedure Handle(const AEvent: TTaskCreatedEvent);
end;

procedure TTaskCreatedHandler.Handle(const AEvent: TTaskCreatedEvent);
begin
  WriteLn(Format('  [Handler] Task #%d created: "%s" assigned to %s',
    [AEvent.TaskId, AEvent.Title, AEvent.AssignedTo]));
end;
```

To share a `DbContext` or inject other scoped services:

```pascal
constructor TTaskCreatedHandler.Create(
  const ADbContext: TMyDbContext;    // same instance as the controller's
  const ALogger: ILoggerFactory);   // same request context
begin
  // ...
end;
```

## Integration Test

Run the PowerShell test script against a running server:

```powershell
powershell -ExecutionPolicy Bypass -File Test.Web.EventBusDemo.ps1
```

The script exercises all three endpoints and validates HTTP status codes and JSON
response fields.

## See Also

- [`EventsBus.Demo`](../EventsBus.Demo/) - console-only demo: behaviors, lifecycle, testing
- [Event Bus documentation](../../Docs/Book/10-advanced/event-bus.md)
- [Event Bus comparison](../../Docs/Book/10-advanced/event-bus-comparison.md)
