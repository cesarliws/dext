---
name: dext-api-features
description: Configure cross-cutting API features in Dext — CORS, rate limiting, response caching, health checks, OpenAPI/Swagger, and custom middleware. Use when setting up the HTTP pipeline, protecting endpoints, or documenting APIs.
---

# Dext API Features

## Middleware Pipeline Order

```pascal
App.Builder
  .UseExceptionHandler    // 1. Always first
  .UseHttpLogging         // 2. Logging
  .UseCors(...)           // 3. CORS (before routes)
  .UseAuthentication      // 4. Auth
  .UseRateLimiting(...)   // 5. Rate limiting
  .UseCompression         // 6. Compression
  .MapEndpoints(...)      // 7. Routes
  .UseSwagger(...)        // 8. Swagger (always last)
```

## Custom Middleware

### Inline

```pascal
App.Builder.Use(procedure(Ctx: IHttpContext; Next: TRequestDelegate)
  begin
    // Before endpoint
    WriteLn('Request: ', Ctx.Request.Path);
    Next(Ctx);
    // After endpoint
    WriteLn('Response: ', Ctx.Response.StatusCode.ToString);
  end);
```

### Class-Based

```pascal
type
  TMyMiddleware = class(TInterfacedObject, IMiddleware)
  private
    FLogger: ILogger;
  public
    constructor Create(Logger: ILogger);
    procedure Invoke(Ctx: IHttpContext; Next: TRequestDelegate);
  end;

// Register
App.Builder.UseMiddleware<TMyMiddleware>;
```

### Short-Circuit (Stop Pipeline)

```pascal
App.Builder.Use(procedure(Ctx: IHttpContext; Next: TRequestDelegate)
  begin
    if Ctx.Request.Header('X-API-Key') = '' then
    begin
      Ctx.Response.StatusCode := 401;
      Ctx.Response.Json('{"error":"API key required"}');
      Exit;  // Do NOT call Next
    end;
    Next(Ctx);
  end);
```

## CORS

`CorsOptions` is a function factory that replaces `TCorsOptions.Create`. The function factory makes the code cleaner and more fluent.

```pascal
// Development (open)
App.Builder.UseCors(
  CorsOptions.AllowAnyOrigin.AllowAnyMethod.AllowAnyHeader);

// Production (restrictive)
App.Builder.UseCors(
  CorsOptions
    .AllowOrigins(['https://myapp.com'])
    .AllowMethods(['GET', 'POST', 'PUT', 'DELETE'])
    .AllowHeaders(['Content-Type', 'Authorization'])
    .AllowCredentials
    .MaxAge(3600));
```

> `AllowAnyOrigin` + `AllowCredentials` is invalid — use specific origins when credentials are needed.
> CORS must be registered **before** route mapping.

## Rate Limiting

```pascal
// Fixed window (e.g., 100 permits per 60 seconds)
App.Builder.UseRateLimiting(
  RateLimitPolicy.FixedWindow(100, 60));

// Token bucket (e.g., limit 100, refill 10)
App.Builder.UseRateLimiting(
  RateLimitPolicy.TokenBucket(100, 10));

// Partition strategies
App.Builder.UseRateLimiting(
  RateLimitPolicy.FixedWindow(100, 60).PartitionByIp);

App.Builder.UseRateLimiting(
  RateLimitPolicy.FixedWindow(1000, 3600).PartitionByHeader('X-API-Key'));

App.Builder.UseRateLimiting(
  RateLimitPolicy.FixedWindow(100, 60)
    .PartitionKey(
      function(Ctx: IHttpContext): string
      begin
        Result := Ctx.Request.QueryParam('tenant');
      end));
```

Exceeded requests return `429 Too Many Requests` with headers:
`X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`.

## Response Caching

### Middleware Configuration (Memory Cache)

```pascal
App.Builder.UseResponseCache(
  ResponseCacheOptions
    .DefaultDuration(30)
    .MaxSize(100)
    .VaryByQueryString);
```

### Middleware Configuration (Redis Cache)

```pascal
uses Dext.Caching.Redis;

// 1. Explicitly specifying the TRedisCacheStore:
App.Builder.UseResponseCache(
  ResponseCacheOptions
    .DefaultDuration(60)
    .Store(TRedisCacheStore.Create('127.0.0.1', 6379))
);

// 2. Or using the UseRedisCache helper shortcut:
App.Builder.UseRedisCache('127.0.0.1', 6379, 'password_if_any', 0 { database }, 60 { duration });
```

## Built-In Filters & Attributes

Dext provides various routing and filter attributes out-of-the-box that can be applied to controllers or individual actions.

```pascal
[ApiController('/api/examples')]|// or [ApiController, Route('/api/examples')]
[LogAction] // Controller-level filter: applies to ALL endpoints in this class
TExamplesController = class
public
  // 1. Core routing verbs
  [HttpGet('/get')]
  [HttpPost('/post')]
  [HttpPut('/put')]
  [HttpDelete('/delete')]
  [HttpPatch('/patch')]
  
  // 2. Custom route overriding
  [Route('/custom-path')] 
  procedure CoreVerbsEndpoint(Ctx: IHttpContext);

  // 3. Header validations
  [HttpGet('/secured')]
  [RequireHeader('X-Tenant-ID', 'Tenant ID is required')]
  procedure SecuredEndpoint(Ctx: IHttpContext);

  // 4. Response modifications & Caching
  [HttpGet('/cached')]
  [ResponseCache(60, 'public')] // Adds Cache-Control: public, max-age=60
  [AddHeader('X-Custom-Header', 'Dext-Rocks')]
  procedure CachedEndpoint(Ctx: IHttpContext);

  // 5. Model state validation
  [HttpPost('/validate')]
  [ValidateModel]
  procedure ValidateEndpoint(Ctx: IHttpContext);
end;
```

## Health Checks

Dext provides a built-in DI-based health check pipeline that exposes a `/health` endpoint automatically.

### 1. Define a Health Check

Implement the `IHealthCheck` interface.

```pascal
type
  TDatabaseHealthCheck = class(TInterfacedObject, IHealthCheck)
  public
    function CheckHealth: THealthCheckResult;
  end;

function TDatabaseHealthCheck.CheckHealth: THealthCheckResult;
begin
  try
    // In a real app, query the database here
    Result := THealthCheckResult.Healthy('Ready');
  except
    on E: Exception do
      Result := THealthCheckResult.Unhealthy('Database is unreachable', E);
  end;
end;
```

### 2. Register Checks

```pascal
App.Services
  .AddHealthChecks
    .AddCheck<TDatabaseHealthCheck>
    .AddCheck<TRedisHealthCheck>
    .Build;
```

### 3. Add Middleware

```pascal
App.UseMiddleware(THealthCheckMiddleware);
```

The middleware automatically intercepts requests to `/health` and returns a JSON payload with the status of all registered checks. Standard HTTP codes apply: `200 OK` = healthy/degraded, `503 Service Unavailable` = unhealthy.

## OpenAPI / Swagger

### 1. Global Setup & Security

Use the `SwaggerOptions` factory to define global info and security definitions like Bearer/API keys.

> **API Design Note**: Dext avoids the `With` prefix in fluent syntaxes to keep the code cleaner. Use `BearerAuth` instead of `WithBearerAuth`.

```pascal
App.Builder
  .MapControllers // Map your routes first
  .UseSwagger(
    SwaggerOptions
      .Title('My Dext API')
      .Description('API documentation')
      .Version('v1')
      .BearerAuth('JWT', 'Enter token: Bearer {token}')
  ); // Always register Swagger last!
```

### 2. Schema Models (DTOs)

Document your records and classes using schema attributes.

```pascal
[SwaggerSchema('User', 'Represents a user in the system')]
TUser = record
  [SwaggerProperty('Unique identifier')]
  [SwaggerExample('1')]
  Id: Integer;

  [SwaggerRequired]
  [SwaggerProperty('Email address')]
  [SwaggerFormat('email')]
  Email: string;
  
  [SwaggerIgnoreProperty] // Hide from Swagger
  InternalSecret: string;
end;
```

### 3. Minimal API Metadata

Use the fluent `SwaggerEndpoint.From` wrapper to document Minimal APIs.

```pascal
var GetUsersEndpoint := App.Builder.MapGet('/api/users', 
  procedure (Ctx: IHttpContext) begin end);

SwaggerEndpoint.From(GetUsersEndpoint)
  .Summary('Get all users')
  .Description('Retrieves a list of users')
  .Tag('Users')
  .Response(200, TypeInfo(TArray<TUser>), 'Success')
  .Response(404, TypeInfo(TErrorResponse), 'Not found')
  .RequireAuthorization('JWT');
```

### 4. Controller Attributes

Use OpenAPI attributes to document endpoint methods and classes.

```pascal
type
  [ApiController('/api/users')]
  [SwaggerTag('Users')] // Groups under "Users" in Swagger UI
  TUsersController = class
  public
    [HttpGet]
    [SwaggerOperation('List all users', 'Retrieves registered users')]
    [SwaggerResponse(200, TUserArray, 'Success')] 
    function GetAll: IResult;

    [HttpGet('/{id}')]
    [SwaggerOperation('Get user by ID')]
    [SwaggerParam('id', 'User internal ID', TSwaggerParamLocation.Path)]
    [SwaggerResponse(200, TUser, 'User found')]
    [SwaggerResponse(404, 'User not found')] // Without schema type
    [SwaggerIgnore] // Optional: Completely hide this endpoint
    function GetById(Id: Integer): IResult;

    [HttpPost]
    [SwaggerOperation('Create User')]
    [SwaggerAuthorize] // Show lock icon, requires auth
    function CreateUser([Body] Req: TUser): IResult;
  end;
```

### Supported OpenAPI Attributes

| Attribute | Applies To | Description |
| --------- | ---------- | ----------- |
| `[SwaggerSchema(Title, Desc)]` | Record / Class | Defines an object schema |
| `[SwaggerProperty(Desc)]` | Field / Prop | Documents a field |
| `[SwaggerRequired]` | Field / Prop | Marks a field as required |
| `[SwaggerExample(Value)]` | Field / Prop | Provides an example value |
| `[SwaggerFormat(Format)]` | Field / Prop | Data format (e.g. 'email', 'date-time') |
| `[SwaggerIgnoreProperty]` | Field / Prop | Hides internal fields |
| `[SwaggerTag(Name)]` | Controller | Groups endpoints |
| `[SwaggerOperation(Summary, Desc, Id)]` | Method | Endpoint info |
| `[SwaggerParam(Name, Desc, Location)]` | Method | Documents a parameter |
| `[SwaggerResponse(Code, Class, Desc)]` | Method | Response schema & code |
| `[SwaggerIgnore]` | Method / Class | Excludes from Swagger docs |
| `[SwaggerAuthorize]` | Method | Implies authorization is needed |

## Static Files

You can serve static files using either a simple root path or detailed options.

```pascal
// 1. Simple overload (serves from the specified path)
App.Builder.UseStaticFiles('./wwwroot');

// 2. Detailed options
var Options := TStaticFileOptions.Create;
Options.RootPath := './public';
Options.DefaultFile := 'index.html';
Options.ServeUnknownFileTypes := False;

App.Builder.UseStaticFiles(Options);
```

## Compression

```pascal
// Response Compression (gzip/deflate)
App.Builder.UseMiddleware(TCompressionMiddleware);
```

