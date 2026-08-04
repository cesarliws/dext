# Minimal APIs

Minimal APIs provide a lightweight, lambda-based approach to building HTTP endpoints with automatic DI and Model Binding.

> 📦 **Examples**: 
> - [Web.EventHub](../../../Examples/Web.EventHub/) - Modern patterns (2026)
> - [Web.SalesSystem](../../../Examples/Web.SalesSystem/) - Clean Architecture + CQRS

## Basic Endpoints

```pascal
// Simple GET (no parameters)
Builder.MapGet<IResult>('/health',
  function: IResult
  begin
    Result := Results.Ok('healthy');
  end);
```

> [!IMPORTANT]
> The last generic type parameter is always `IResult` (the return type).

## DI + Model Binding (Recommended Pattern)

Dext has integrated **Dependency Injection** and **Model Binding**. Services, DTOs, and route parameters are injected **automatically** via generic type parameters.

```pascal
// GET with injected service
Builder.MapGet<IUserService, IResult>('/api/users',
  function(Svc: IUserService): IResult
  begin
    Result := Results.Ok(Svc.GetAll);
  end);

// GET with service + route param (Integer auto-bound from {id})
Builder.MapGet<IUserService, Integer, IResult>('/api/users/{id}',
  function(Svc: IUserService; Id: Integer): IResult
  begin
    Result := Results.Ok(Svc.GetById(Id));
  end);

// POST with DTO (body) + service
Builder.MapPost<TLoginRequest, IAuthService, IResult>('/api/auth/login',
  function(Req: TLoginRequest; Auth: IAuthService): IResult
  begin
    Result := Results.Ok(Auth.Login(Req));
  end);

// QUERY with DTO (body) + service (RFC 10008)
Builder.MapQuery<TUserSearchQuery, IUserService, IResult>('/api/users/search',
  function(Query: TUserSearchQuery; Svc: IUserService): IResult
  begin
    Result := Results.Ok(Svc.Search(Query));
  end);
```

> [!WARNING]
> ⛔ **NEVER** resolve services manually: `Ctx.RequestServices.GetService<T>`  
> ⛔ **NEVER** parse body manually: `Ctx.Request.BodyAsJson<T>`  
> Use the generic type parameters instead — the framework handles everything.

### How the Framework Resolves Parameters

| Type | Resolution |
|------|-----------|
| Interfaces/Classes registered in DI | Injected automatically |
| Records with `[FromRoute]`/`[FromHeader]`/`[FromQuery]` | Mixed binding |
| Records without attributes | Model Binding from request body |
| `Integer`, `string` matching route template | Route param directly |
| `IHttpContext` | Injected automatically (use only if really needed) |

## Route Parameters

> [!IMPORTANT]
> Dext uses **`{param}`** syntax for route parameters (like ASP.NET Core), not `:param` (Express style).

### Direct Binding (Simple Types)

```pascal
Builder.MapGet<IUserService, Integer, IResult>('/api/users/{id}',
  function(Svc: IUserService; Id: Integer): IResult
  begin
    Result := Results.Ok(Svc.GetById(Id));
  end);
```

### Using Record-Based Model Binding

```pascal
type
  TUserIdRequest = record
    [FromRoute('id')]
    Id: Integer;
  end;

Builder.MapGet<IUserService, TUserIdRequest, IResult>('/api/users/{id}',
  function(Svc: IUserService; Req: TUserIdRequest): IResult
  begin
    Result := Results.Ok(Svc.GetById(Req.Id));
  end);
```

## Mixed Binding (Multiple Sources)

The most powerful feature: combine data from route, header, query and body in one record.

```pascal
type
  TUpdateStatusRequest = record
    [FromRoute('id')]
    TicketId: Integer;           // Captured from URL /api/tickets/{id}

    [FromHeader('X-User-Id')]
    UserId: Integer;             // Captured from HTTP header

    // Fields without attributes → Model Binding from JSON body
    NewStatus: TTicketStatus;
    Reason: string;
  end;

Builder.MapPost<TUpdateStatusRequest, ITicketService, IResult>('/api/tickets/{id}/status',
  function(Req: TUpdateStatusRequest; Svc: ITicketService): IResult
  begin
    Result := Results.Ok(Svc.UpdateStatus(Req.TicketId, Req.NewStatus, Req.Reason, Req.UserId));
  end);
```

### Available Binding Attributes

| Attribute | Source |
|-----------|--------|
| `[FromRoute('paramName')]` | Captured from `{paramName}` in URL |
| `[FromHeader('Header-Name')]` | Captured from HTTP header |
| `[FromQuery('queryParam')]` | Captured from `?queryParam=value` |
| No attribute | Captured from JSON body (default) |

> [!WARNING]
> ⛔ **NEVER** use `Ctx.Request.Route['id']` → use `[FromRoute('id')]` in the DTO  
> ⛔ **NEVER** use `Ctx.Request.Headers['X-User-Id']` → use `[FromHeader('X-User-Id')]` in the DTO

> 📚 **See Also**: [Model Binding](model-binding.md) for full details.

## Results Pattern

Use the `Results` helper for consistent responses:

```pascal
Results.Ok(Data)             // 200 with JSON body
Results.Ok<T>(Data)          // 200 with typed serialization
Results.Created('/path', E)  // 201 with Location header
Results.NoContent            // 204
Results.BadRequest('msg')    // 400
Results.NotFound('msg')      // 404
Results.StatusCode(401)      // Unauthorized (safe alternative)
Results.StatusCode(418, '..') // Custom status
Results.Ok                   // 200 without body (parameterless overload)
```

Return directly from typed handlers:
```pascal
function(...): IResult
begin
  Result := Results.Ok(User);
end;
```

## Endpoint Metadata (OpenAPI)

Enrich Swagger documentation with fluent metadata:

```pascal
Builder.MapGet<IResult>('/api/health',
  function: IResult
  begin
    Result := Results.Ok('API is healthy');
  end)
  .WithTags('Health')
  .WithSummary('Check API status')
  .WithDescription('Returns a simple message confirming the service is running.');
```

### Available Methods

- `.WithTags(...)` — Group endpoints in Swagger
- `.WithSummary(...)` — Short title for the endpoint
- `.WithDescription(...)` — Detailed description
- `.WithMetadata(Summary, Description, Tags)` — Set multiple metadata at once
- `.RequireAuthorization` — Require authentication (optionally accepts Schemes or Roles)

## Model Binding Cleanup

The framework automatically frees class objects created by Model Binding after handler execution:

```pascal
// ✅ CORRECT: Framework frees Dto automatically
Builder.MapPost<TCreateOrderDto, IResult>('/api/orders',
  function(Dto: TCreateOrderDto): IResult
  begin
    // Use Dto normally
    // DO NOT call Dto.Free - the framework handles it!
    Result := Results.Ok(Dto.Items.Count);
  end);
```

## FastPath & Data API (`MapFast` & `UseSql`)

For **performance-critical** endpoints (ping/pong, high-frequency webhooks, or massive Data APIs), Dext provides the **`MapFast`** route handler:

```pascal
// Ultra-fast route (bypasses DI Scope and RTTI activation)
App.MapFast('GET', '/fastping', procedure(const Req: IHttpRequest; const Res: IHttpResponse)
begin
  Res.SendJsonUtf8('{"message":"pong"}');
end);

// FastPath Data API with UseSql (Direct UTF-8 Streaming to Socket)
App.MapFast('GET', '/api/cities/fast', procedure(const Req: IHttpRequest; const Res: IHttpResponse)
begin
  Db.UseSql('SELECT Id, Name, State FROM Cities')
    .ExecuteToUtf8Stream(Res.GetOutputStream);
end);
```

> [!TIP]
> The `Db.UseSql` method combined with `Res.GetOutputStream` streams response data directly to the HTTP socket in UTF-8 without intermediate `TJsonObject` allocations, achieving **up to +123% throughput** under extreme load.

## Endpoints Module Pattern

Move all route definitions to a dedicated unit:

```pascal
unit MyProject.Endpoints;

interface

uses
  Dext.Web; // TAppBuilder, IResult, Results

type
  TMyEndpoints = class
  public
    class procedure MapEndpoints(const Builder: TAppBuilder); static;
  end;

implementation

class procedure TMyEndpoints.MapEndpoints(const Builder: TAppBuilder);
begin
  Builder.MapGet<IResult>('/health', ...);
  Builder.MapPost<TLoginRequest, IAuthService, IResult>('/api/auth/login', ...);
end;
```

> [!IMPORTANT]
> The parameter type for `MapEndpoints` is `TAppBuilder` (from `Dext.Web`), **not** `IApplicationBuilder`.

Wire it in the Startup:
```pascal
App.Builder
  .MapEndpoints(TMyEndpoints.MapEndpoints)  // Receives method pointer
  .UseSwagger(...);
```

---

[← Web Framework](README.md) | [Next: Controllers →](controllers.md)
