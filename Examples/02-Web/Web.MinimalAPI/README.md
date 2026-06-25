# Minimal API Example

The simplest way to create HTTP endpoints with Dext - no Controllers needed!

## 🚀 Features

*   **Simple Route Mapping**: Define routes directly with `App.MapGet()`, `App.MapPost()`, etc.
*   **Type-Safe Handlers**: Use `MapGetR<T>()` for strongly-typed return values
*   **Dependency Injection**: Access services from the request context
*   **Query Parameters**: Read query string values with `Context.Request.Query`
*   **JSON Responses**: Send JSON using `Context.Response.Json()` or `Results.Ok()`

## 🛠️ Getting Started

1.  **Compile** `Web.MinimalAPIExample.dproj`
2.  **Run** `Web.MinimalAPIExample.exe`
    *   Server starts on **http://localhost:5000**
3.  **Test**:
    ```powershell
    .\Test.Web.MinimalAPI.ps1
    ```

## 📍 Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /hello?name=World` | Greeting with DI service |
| `GET /echo?text=foo` | Echoes "Echo: foo" |
| `GET /time` | Current server time |
| `GET /json` | JSON object response |
| `GET /health` | Health check endpoint |

## 📖 Code Examples

### Basic Route Mapping

```pascal
// Simple GET endpoint
App.MapGet('/echo',
  procedure(Context: IHttpContext)
  begin
    var Text := Context.Request.Query.Values['text'];
    Context.Response.Write('Echo: ' + Text);
  end);
```

### Type-Safe Handlers with IResult

```pascal
// Recommended for APIs - returns IResult
TApplicationBuilderExtensions.MapGetR<IResult>(App, '/time',
  function: IResult
  begin
    Result := Results.Ok(Format('Server time: %s', [DateTimeToStr(Now)]));
  end);
```

### Dependency Injection

```pascal
// Register service
Builder.ConfigureServices(
  procedure(Services: IServiceCollection)
  begin
    TServiceCollectionExtensions.AddSingleton<IGreetingService, TGreetingService>(Services);
  end);

// Resolve in handler
App.MapGet('/hello',
  procedure(Context: IHttpContext)
  var
    Svc: IGreetingService;
  begin
    if Supports(Context.Services.Resolve<IGreetingService>, IGreetingService, Svc) then
      Context.Response.Write(Svc.GetGreeting('World'));
  end);
```

### JSON Response

```pascal
App.MapGet('/json',
  procedure(Context: IHttpContext)
  begin
    Context.Response.Json('{"message": "Hello JSON!"}');
  end);
```

## 📚 See Also

- [Web.SwaggerExample](../Web.SwaggerExample) - Minimal API with OpenAPI documentation
- [Web.ControllerExample](../Web.ControllerExample) - Using Controllers for complex APIs
- [Web.JwtAuthDemo](../Web.JwtAuthDemo) - Adding JWT authentication
