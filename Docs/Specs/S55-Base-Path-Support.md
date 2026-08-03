# Spec S55: Base Path Support (#182)

- **Status**: Implemented
- **Issue**: #182
- **Author**: Stemonik & Cesar Romero

## 1. Overview
This specification details base path hosting support for Dext applications (`app.UsePathBase('/myapp')`). It enables applications to run cleanly behind path prefixes, reverse proxies, and shared port HTTP.sys bindings.

## 2. Key Components
1. `IHttpRequest`: Added `PathBase`, `GetPathBase`, `SetPathBase`, `SetPath`, `ToAppUrl`.
2. `TDextPathBaseMiddleware`: Engine-agnostic middleware stripping path base on segment boundaries and setting `Request.PathBase`.
3. `IWebApplication` / `AppBuilder`: Fluent API `.UsePathBase('/myapp')`.
4. `HTTP.sys Engine`: Native kernel registration incorporating path prefix into `UrlPrefix` (e.g., `http://+:8080/myapp/` or fallback `http://127.0.0.1:8080/myapp/`).

## 3. Usage Example
```pascal
App := WebApplication;
App.UsePathBase('/myapp');
App.MapGet('/hello', procedure(Ctx: IHttpContext)
  begin
    Ctx.Response.Write('Hello from ' + Ctx.Request.ToAppUrl('/hello'));
  end);
App.Run(8080);
```
