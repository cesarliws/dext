---
name: dext-app-structure
description: Structure a Dext Web API project — Startup class, middleware pipeline, .dpr bootstrap, database seeding, and project organisation.
---

# Dext Application Structure

## Core Imports

```pascal
uses
  Dext;          // IConfiguration, TDextServices, IServiceProvider
  Dext.Web;      // IWebApplication, IStartup, TAppBuilder, WebApplication
  Dext.Entity;   // AddDbContext, TDbContextOptions 
  Dext.Utils;    // SetConsoleCharSet, ConsolePause
  Dext.MM;       // Optional: FastMM5 memory manager
```

## Standard Project Layout

```
MyProject/
├── MyProject.dpr                  # Entry point (minimal)
├── MyProject.Startup.pas          # Service registration + middleware pipeline
├── MyProject.Endpoints.pas        # Minimal API route definitions (optional)
├── Domain/
│   └── Entities.pas               # ORM entity classes
│   └── IUserService.pas           # Service interfaces
├── Data/
│   └── Context.pas                # TDbContext subclass
│   └── Seeder.pas                 # Database seeding
├── Services/
│   └── UserService.pas            # Service implementations
└── Tests/
    └── MyProject.Tests.dpr        # Separate console test project
```

## Startup Class Pattern

Create `MyProject.Startup.pas` implementing `IStartup`:

```pascal
unit MyProject.Startup;

interface

uses
  Dext.Entity.Core,  // TDbContextOptions
  Dext,              // IConfiguration, TDextServices
  Dext.Web;          // IWebApplication, IStartup

type
  TStartup = class(TInterfacedObject, IStartup)
  public
    procedure ConfigureServices(const Services: TDextServices; const Configuration: IConfiguration);
    procedure Configure(const App: IWebApplication);
  private
    procedure ConfigureDatabase(Options: TDbContextOptions);
  end;

implementation

uses
  MyProject.Data.Context,
  MyProject.Endpoints,
  MyProject.Services;

procedure TStartup.ConfigureServices(const Services: TDextServices; const Configuration: IConfiguration);
begin
  Services
    .AddDbContext<TAppDbContext>(ConfigureDatabase)
    .AddScoped<IUserService, TUserService>
    .AddControllers;  // Include only when using controller pattern
end;

procedure TStartup.Configure(const App: IWebApplication);
begin
  // Optional: configure JSON serialization defaults
  JsonDefaultSettings(JsonSettings.CamelCase.CaseInsensitive.ISODateFormat);

  App.Builder
    .UseExceptionHandler           // 1. Always first
    .UseHttpLogging                // 2. HTTP logging
    .UseCors(CorsOptions.AllowAnyOrigin.AllowAnyMethod.AllowAnyHeader)  // 3. CORS
    .UseAuthentication             // 4. If JWT is enabled (before routes)
    .MapEndpoints(TMyEndpoints.MapEndpoints)  // 5. Minimal APIs
    .MapControllers                // 6. Controllers (if used)
    .UseSwagger(Swagger.Title('My API').Version('v1'));  // 7. Swagger (after routes)
end;

procedure TStartup.ConfigureDatabase(Options: TDbContextOptions);
begin
  Options
    .UseSQLite('App.db')
    .WithPooling(True);  // REQUIRED for production Web APIs
end;
```

### Startup Key Rules

- `TDextServices` is a **Record** — never call `.Free` on it. It is automatically managed by the stack.
- **Builders (Middlewares/Options)**: Always use functional globals to instantiate builders: `CorsOptions`, `JwtOptions(key)`, `ResponseCacheOptions`, `SwaggerOptions`, `RateLimitPolicy`.
  - These are also records on the stack. **Never** free them.
  - E.g.: `App.Builder.UseCors(CorsOptions.AllowAnyOrigin.AllowAnyMethod)`
- `ConfigureServices` receives `(const Services: TDextServices; const Configuration: IConfiguration)`.
- **Feature flags (S68):** host registers JSON/YAML with `ReloadOnChange`; call `TFeatureConfiguration.Reload(Configuration)` to force an immediate refresh of `FeatureManagement:*` keys.
- **Options ValidateOnStart (S68):** `Configure<T>(..., Validator, True)` fails fast in `BuildServices` before the server listens.
- `Configure` receives `IWebApplication`, not `IApplicationBuilder`.
- Use `App.Builder` for the fluent middleware pipeline.
- Database configuration **must** be in a separate private method.
- Middleware order matters: exception handler first, swagger last.

### Lifecycle & Memory Management (Golden Rules)

- **IWebApplication**: ALWAYS declare the variable explicitly as `IWebApplication`.
  - ✅ `var App: IWebApplication := WebApplication;`
  - ❌ `var App := WebApplication;` (Insecure. The compiler infers the concrete class, causing ARC leaks on shutdown).
- **Records containing Interfaces**: Records like `TJsonSettings` and `Prop<T>` contain interfaces. They **MUST** be initialized to zero before use to avoid `Invalid pointer operation`. Dext does this via factories, but if you create one manually, make sure it is initialized properly.

## Main Program (`.dpr`)

```pascal
program Web.MyProject;

{$APPTYPE CONSOLE}

uses
  Dext.MM,         // Optional: FastMM5
  Dext.Utils,      // SetConsoleCharSet, ConsolePause
  System.SysUtils,
  Dext,            // IServiceProvider
  Dext.Web,        // IWebApplication, WebApplication
  MyProject.Startup in 'MyProject.Startup.pas';

var
  App: IWebApplication;
  Provider: IServiceProvider;
begin
  SetConsoleCharSet;  // REQUIRED: UTF-8 console output
  try
    App := WebApplication;
    App.UseStartup(TStartup.Create);
    Provider := App.BuildServices;

    // Seed database BEFORE App.Run
    TDbSeeder.Seed(Provider);

    App.Run(9000);  // Blocks until Ctrl+C
  except
    on E: Exception do
      WriteLn('Fatal: ' + E.Message);
  end;
  ConsolePause;  // REQUIRED: keeps console open in IDE
end.
```

### .dpr Common Mistakes

| Wrong | Correct |
|-------|---------|
| `var App := WebApplication;` | `App: IWebApplication; App := WebApplication;` |
| Missing `IServiceProvider` declare | Declare `Provider: IServiceProvider` |
| Missing `Dext` in uses | `IServiceProvider` requires `Dext` unit |
| Forgetting `SetConsoleCharSet` | Always include — broken UTF-8 output |
| Missing `ConsolePause` | App window closes instantly in IDE (does not affect Production/Docker) |

> `var App := WebApplication;` causes the compiler to infer the concrete class, not `IWebApplication`. This causes ARC/shutdown issues.

## Fluent Pipeline — Mandatory Pattern

**Always** use fluent chaining. Never break the chain with intermediate variables:

```pascal
// ✅ CORRECT: Fluent chain
Services
  .AddDbContext<TMyContext>(ConfigureDatabase)
  .AddScoped<IUserService, TUserService>
  .AddSingleton<ICache, TMemoryCache>;

App.Builder
  .UseExceptionHandler
  .UseHttpLogging
  .MapEndpoints(TMyEndpoints.MapEndpoints)
  .UseSwagger(Swagger.Title('My API').Version('v1'));

// ❌ WRONG: Intermediate variables
var Builder := App.Builder;
Builder.UseExceptionHandler;  // Breaks fluent pattern
Builder.UseHttpLogging;
```

## Run vs Start

| Method | Behaviour | Use Case |
|--------|-----------|----------|
| `App.Run(port)` | Blocks until Ctrl+C | Console apps, services, daemons |
| `App.Start` | Non-blocking | GUI apps (VCL/FMX), system tray tools |
| `App.Stop` | Graceful shutdown | Called on form/window close |

### GUI App Example (VCL)

```pascal
procedure TMainForm.FormCreate(Sender: TObject);
begin
  FApp := WebApplication;
  FApp.UseStartup(TStartup.Create);
  FProvider := FApp.BuildServices;
  FApp.Start;  // Non-blocking
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FApp.Stop;  // Graceful shutdown
end;
```

## Database Seeding

Seed BEFORE `App.Run`, using a scope to get services:

```pascal
class procedure TDbSeeder.Seed(const Provider: IServiceProvider);
begin
  var Scope := Provider.CreateScope;
  try
    var Db := Scope.ServiceProvider.GetService(TAppDbContext) as TAppDbContext;

    if Db.EnsureCreated then  // True only when schema is first created
    begin
      if not Db.Users.QueryAll.Any then  // Check before inserting
      begin
        var Admin := TUser.Create;
        Admin.Name := 'Admin';
        Admin.Email := 'admin@example.com';
        Db.Users.Add(Admin);
        Db.SaveChanges;
        // Admin.Id is auto-populated
      end;
    end;
  finally
    Scope := nil;  // Disposes all scoped services
  end;
end;
```

> **NEVER** call `BuildServiceProvider` inside a Seeder — this creates a new container with an empty DB.

## Endpoints Module

Organise routes in a dedicated unit:

```pascal
unit MyProject.Endpoints;

interface
uses
  Dext.Web; // TAppBuilder — NOT IApplicationBuilder

type
  TMyEndpoints = class
  public
    class procedure MapEndpoints(Builder: TAppBuilder); static;
  end;

implementation
uses
  MyProject.Services;

class procedure TMyEndpoints.MapEndpoints(Builder: TAppBuilder);
begin
  Builder.MapGet<IResult>('/health',
    function: IResult
    begin
      Result := Results.Ok('healthy');
    end);

  Builder.MapPost<TLoginRequest, IAuthService, IResult>('/api/auth/login',
    function(Req: TLoginRequest; Auth: IAuthService): IResult
    begin
      Result := Results.Ok(Auth.Login(Req));
    end);
end;
```

Wire up in Startup:

```pascal
App.Builder
  .MapEndpoints(TMyEndpoints.MapEndpoints)
  ...
```

## JSON Default Settings

Configure JSON serialization globally in `Configure`:

```pascal
// Most common production setting
JsonDefaultSettings(JsonSettings.CamelCase.CaseInsensitive.ISODateFormat);
```

Available fluent config options:

- `CamelCase`, `PascalCase`, `SnakeCase`
- `CaseInsensitive`
- `ISODateFormat`, `UnixTimestamp`, `CustomDateFormat(str)`
- `EnumAsString`, `EnumAsNumber`
- `IgnoreNullValues`
- `ServiceProvider(provider)`

## Standard Middleware Pipeline Order

```
1. UseExceptionHandler   — catch unhandled exceptions (always first)
2. UseHttpLogging        — request/response logging
3. UseCors              — cross-origin headers
4. UseAuthentication     — JWT token validation (before routes)
5. MapEndpoints(...)     — Minimal API routes
6. MapControllers        — Controller routes
7. UseSwagger(...)       — OpenAPI/Swagger UI (always last)
```

