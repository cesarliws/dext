---
name: dext-web
description: Build HTTP endpoints with Dext Web Framework — Minimal APIs and Controllers, routing, model binding, and results.
---

# Dext Web Framework

## Uses Clause Order (CRITICAL)

Delphi only supports one class helper for a given type at a time. To ensure all framework features (Minimal APIs, Routing, Web Helpers) are available, the `uses` order **MUST** be:

1. `Dext`
2. `Dext.Entity` (if using ORM)
3. `Dext.Web` (**LAST**)

```pascal
uses
  Dext,
  Dext.Entity, // Optional
  Dext.Web;    // Always last
```

## Application Bootstrap

```pascal
program MyApi;
{$APPTYPE CONSOLE}
uses
  System.SysUtils,
  Dext.Web;
begin
  var App := WebApplication;
  var Builder := App.Builder;

  Builder.MapGet<IResult>('/health',
    function: IResult
    begin
      Result := Results.Ok('healthy');
    end);

  App.Run(8080);
end.
```

## Minimal API — Endpoint Patterns

The **last** generic type parameter is always `IResult` (return type). All preceding parameters are auto-resolved: interfaces/classes from DI, records from model binding, and simple types (`Integer`, `string`) from route.

```pascal
// No parameters
Builder.MapGet<IResult>('/health',
  function: IResult
  begin
    Result := Results.Ok('healthy');
  end);

// Service injected from DI
Builder.MapGet<IUserService, IResult>('/api/users',
  function(Svc: IUserService): IResult
  begin
    Result := Results.Ok(Svc.GetAll);
  end);

// Service + route param (bound from {id})
Builder.MapGet<IUserService, Integer, IResult>('/api/users/{id}',
  function(Svc: IUserService; Id: Integer): IResult
  begin
    Result := Results.Ok(Svc.GetById(Id));
  end);

// POST: DTO from body + service
Builder.MapPost<TCreateUserDto, IUserService, IResult>('/api/users',
  function(Dto: TCreateUserDto; Svc: IUserService): IResult
  begin
    var User := Svc.Add(Dto);
    Result := Results.Created('/api/users/' + IntToStr(User.Id), User);
  end);

// QUERY: DTO from body + service (RFC 10008)
Builder.MapQuery<TUserSearchQuery, IUserService, IResult>('/api/users/search',
  function(Query: TUserSearchQuery; Svc: IUserService): IResult
  begin
    Result := Results.Ok(Svc.Search(Query));
  end);
```

> **NEVER** do `Ctx.RequestServices.GetService<T>` or `Ctx.Request.BodyAsJson<T>`.
> Use generic type parameters — the framework handles everything.

## Route Parameters

Use `{param}` syntax (ASP.NET Core style, **not** `:param`):

```pascal
// Direct binding: Integer from {id}
Builder.MapGet<IOrderService, Integer, IResult>('/api/orders/{id}',
  function(Svc: IOrderService; Id: Integer): IResult
  begin
    Result := Results.Ok(Svc.Find(Id));
  end);
```

## Model Binding — Record DTOs

Records are bound from the request body by default. Use attributes to override the source:

| Attribute | Source |
|-----------|--------|
| `[FromRoute('param')]` | URL route segment `{param}` |
| `[FromHeader('Header-Name')]` | HTTP header |
| `[FromQuery('name')]` | Query string `?name=value` |
| *(none)* | JSON request body |

```pascal
type
  TUpdateTicketRequest = record
    [FromRoute('id')]
    TicketId: Integer;          // from /api/tickets/{id}

    [FromHeader('X-User-Id')]
    UserId: Integer;            // from HTTP header

    NewStatus: TTicketStatus;   // from JSON body
    Reason: string;             // from JSON body
  end;

Builder.MapPost<TUpdateTicketRequest, ITicketService, IResult>(
  '/api/tickets/{id}/status',
  function(Req: TUpdateTicketRequest; Svc: ITicketService): IResult
  begin
    Result := Results.Ok(Svc.UpdateStatus(Req));
  end);
```

> **NEVER** use `Ctx.Request.Route['id']` or `Ctx.Request.Headers['X-User-Id']`.
> **NEVER** free class DTOs — the framework frees them automatically after the handler.

## Results Helper

```pascal
Results.Ok(Data)             // 200 + JSON body
Results.Ok<T>(Data)          // 200 + typed serialization
Results.Created('/path', E)  // 201 + Location header
Results.NoContent            // 204
Results.BadRequest('msg')    // 400
Results.NotFound('msg')      // 404
Results.StatusCode(401)      // Use instead of Results.Unauthorized
Results.StatusCode(418, 'msg') // Custom status
Results.Ok                   // 200 without body
```

## Endpoints Module Pattern

Organise routes in a dedicated unit:

```pascal
unit MyProject.Endpoints;

interface
uses
  Dext.Web; // TAppBuilder

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

Wire in Startup:

```pascal
App.Builder
  .MapEndpoints(TMyEndpoints.MapEndpoints)
  .UseSwagger(Swagger.Title('My API').Version('v1'));
```

> The parameter type for `MapEndpoints` is `TAppBuilder` (not `IApplicationBuilder`).

## Controllers

Two supported styles (route params **must start with `/`**):

### Style 1: Consolidated (Recommended)

```pascal
type
  [ApiController('/api/users')]
  TUsersController = class
  private
    FUserService: IUserService;
  public
    constructor Create(UserService: IUserService);

    [HttpGet]                      // GET /api/users
    function GetAll: IResult;

    [HttpGet('/{id}')]             // GET /api/users/123
    function GetById(Id: Integer): IResult;

    [HttpPost]                     // POST /api/users
    function CreateUser([Body] Dto: TCreateUserDto): IResult;

    [HttpPut('/{id}')]             // PUT /api/users/123
    function UpdateUser(Id: Integer; [Body] Dto: TUpdateUserDto): IResult;

    [HttpDelete('/{id}')]          // DELETE /api/users/123
    function DeleteUser(Id: Integer): IResult;
  end;
```

### Style 2: Separated (.NET style)

```pascal
type
  [ApiController]
  [Route('/api/users')]
  TUsersController = class
  public
    [HttpGet]
    function GetAll: IResult;

    [HttpGet, Route('/{id}')]
    function GetById(Id: Integer): IResult;
  end;
```

### Controller Rules

- Route params **must start with `/`**: `[HttpGet('/{id}')]` ✅, `[HttpGet('{id}')]` ❌
- **NEVER** name a method just `Create` — conflicts with Delphi constructors (E2254). Use `CreateUser`, `CreateOrder`, etc.
- `[Route]` requires `[ApiController]` to be registered by the scanner.

### Smart Linking Prevention (Controllers)

Delphi's linker removes unreferenced classes. Since Controllers are called via RTTI, you **must** force the inclusion of the class in the unit's initialization block, otherwise the route will return 404.

```pascal
initialization
  TUsersController.ClassName;
```

### Controller Actions

```pascal
function TUsersController.GetAll: IResult;
begin
  Result := Results.Ok(FUserService.GetAll);
end;

function TUsersController.GetById(Id: Integer): IResult;
begin
  var User := FUserService.FindById(Id);
  if User = nil then
    Result := Results.NotFound('User not found')
  else
    Result := Results.Ok(User);
end;
```

### Controller Parameter Binding

```pascal
[HttpGet('/search')]
function Search([FromQuery] Q: string; [FromQuery] Page: Integer): IResult;

[HttpPost]
function CreateUser([FromBody] Request: TCreateUserDto): IResult;

[HttpGet]
function Auth([FromHeader('Authorization')] Token: string): IResult;
```

### Controller Authorization

```pascal
type
  [ApiController('/api/secure')]
  [Authorize]                     // All methods require auth
  TSecureController = class
  public
    [HttpGet]
    [AllowAnonymous]              // Exception: public
    function PublicInfo: IResult;

    [HttpPost]
    [Authorize('Admin')]          // Requires 'Admin' role
    function AdminAction: IResult;
  end;
```

### Register Controllers in Startup

```pascal
procedure TStartup.ConfigureServices(const Services: TDextServices; ...);
begin
  Services
    .AddScoped<IUserService, TUserService>
    .AddControllers;  // Register controllers for DI
end;

procedure TStartup.Configure(const App: IWebApplication);
begin
  App.Builder
    .UseExceptionHandler
    .UseHttpLogging
    .UsePathBase('/myapp')     // Serve application under /myapp prefix
    .MapControllers            // Map routes BEFORE Swagger
    .UseSwagger(Swagger.Title('My API').Version('v1'));
end;
```

## Routing & Performance Rules

Dext uses an optimized Radix Tree router:
- Always use the `IHttpContext.EndpointMetadata` property directly to get or set metadata details instead of invoking slow RTTI dictionary packaging or `TValue`.
- Route matching complexity is O(L), depending strictly on the number of path segments instead of the total number of registered routes.

## HTTP Methods Reference

| Dext Method | HTTP Verb |
|-------------|-----------|
| `MapGet<...>` | GET |
| `MapPost<...>` | POST |
| `MapPut<...>` | PUT |
| `MapDelete<...>` | DELETE |
| `MapPatch<...>` | PATCH |
| `[HttpGet]` / `[HttpPost]` / etc. | Controller attributes |

## Common Mistakes

| Wrong | Correct |
|-------|---------|
| `Ctx.RequestServices.GetService<T>` | Use generic type parameters |
| `Ctx.Request.BodyAsJson<T>` | Use record DTO as parameter |
| `Ctx.Request.Route['id']` | Use `[FromRoute('id')]` in DTO |
| `Ctx.Request.Headers['X-Foo']` | Use `[FromHeader('X-Foo')]` in DTO |
| `Dto.Free` inside handler | Framework frees DTOs automatically |
| `[HttpGet('{id}')]` (no slash) | `[HttpGet('/{id}')]` |
| Method named `Create` | Use `CreateUser`, `CreateOrder`, etc. |
| `Results.Unauthorized` | `Results.StatusCode(401)` |
