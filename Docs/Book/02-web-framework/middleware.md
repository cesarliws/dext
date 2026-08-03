# Middleware

Intercept and process HTTP requests in the pipeline.

## How Middleware Works

```
Request → Middleware 1 → Middleware 2 → ... → Endpoint
                ↓               ↓
Response ← Middleware 1 ← Middleware 2 ← ... ← Endpoint
```

## Built-in Middleware

```pascal
App.Configure(procedure(App: IApplicationBuilder)
  begin
    // Exception handling (should be first)
    App.UseExceptionHandler;
    
    // Logging
    App.UseHttpLogging;
    
    // Authentication
    App.UseAuthentication;
    
    // CORS
    App.UseCors(CorsOptions);
    
    // Rate limiting
    App.UseRateLimiting(RateLimitOptions);
    
    // Static files
    App.UseStaticFiles('/public', './wwwroot');
    
    // Compression
    App.UseCompression;
    
    // Base Path
    App.UsePathBase('/myapp');

    // Endpoints go last
    App.MapGet('/api', Handler);
  end);
```

## Base Path Hosting (`UsePathBase`)

Serve applications under a path prefix (e.g. `https://example.com/myapp/`):

```pascal
App := WebApplication;
App.UsePathBase('/myapp');
App.MapGet('/ping', procedure(Ctx: IHttpContext)
  begin
    // Ctx.Request.PathBase -> '/myapp'
    // Ctx.Request.Path -> '/ping'
    // Ctx.Request.ToAppUrl('/ping') -> '/myapp/ping'
    Ctx.Response.Write('OK');
  end);
App.Run(8080);
```

## Custom Middleware

### Inline Middleware

```pascal
App.Use(procedure(Ctx: IHttpContext; Next: TRequestDelegate)
  var
    StartTime: TDateTime;
  begin
    StartTime := Now;
    
    // Before endpoint
    WriteLn('Request started: ', Ctx.Request.Path);
    
    Next(Ctx);  // Call next middleware/endpoint
    
    // After endpoint
    WriteLn('Request completed in ', MilliSecondsBetween(Now, StartTime), 'ms');
  end);
```

### Middleware Class

```pascal
type
  TLoggingMiddleware = class(TInterfacedObject, IMiddleware)
  private
    FLogger: ILogger;
  public
    constructor Create(Logger: ILogger);
    procedure Invoke(Ctx: IHttpContext; Next: TRequestDelegate);
  end;

procedure TLoggingMiddleware.Invoke(Ctx: IHttpContext; Next: TRequestDelegate);
begin
  FLogger.Info('Request: ' + Ctx.Request.Method + ' ' + Ctx.Request.Path);
  
  try
    Next(Ctx);
    FLogger.Info('Response: ' + Ctx.Response.StatusCode.ToString);
  except
    on E: Exception do
    begin
      FLogger.Error('Error: ' + E.Message);
      raise;
    end;
  end;
end;

// Register
App.UseMiddleware<TLoggingMiddleware>;
```

## Short-Circuit Middleware

Stop the pipeline early:

```pascal
App.Use(procedure(Ctx: IHttpContext; Next: TRequestDelegate)
  begin
    if Ctx.Request.Header('X-API-Key') = '' then
    begin
      Ctx.Response.StatusCode := 401;
      Ctx.Response.Json('{"error": "API key required"}');
      Exit;  // Don't call Next()
    end;
    
    Next(Ctx);  // Continue pipeline
  end);
```

## Conditional Middleware

Apply middleware based on conditions:

```pascal
// Only for /api/* paths
App.UseWhen(
  function(Ctx: IHttpContext): Boolean
  begin
    Result := Ctx.Request.Path.StartsWith('/api');
  end,
  procedure(App: IApplicationBuilder)
  begin
    App.UseRateLimiting(ApiLimitOptions);
  end);
```

## Middleware Order

Order matters! Recommended order:

1. `UseExceptionHandler` - Catch all errors
2. `UseHttpLogging` - Log requests
3. `UseCors` - Handle CORS preflight
4. `UseAuthentication` - Validate tokens
5. `UseRateLimiting` - Throttle requests
6. `UseCompression` - Compress responses
7. **Endpoints** - Your API logic

---

[← Routing](routing.md) | [Next: Authentication →](../03-authentication/README.md)
