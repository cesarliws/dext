[ 🇧🇷 Português ](README.pt-br.md)

# Dext Framework - Modern Full-Stack Development for Delphi

> ⚠️ **Status: Active Development**
> The project is currently implementing version 1.0. The public API, fluent syntax, and method names are subject to breaking changes without prior notice until the first stable release.

**Dext** is a complete ecosystem for modern Delphi development, combining a high-performance web framework (inspired by ASP.NET Core) with a robust ORM and advanced infrastructure tooling.

The goal of Dext is to bring modern development paradigms—such as Dependency Injection, Asynchronous Programming, Fluent APIs, and Code-First—to the Delphi environment while maintaining native performance.

## 🎯 Philosophy and Goals

*   **Parity with .NET Core**: The primary goal is to reach feature parity with equivalent frameworks in the .NET ecosystem (ASP.NET Core, EF Core), staying up-to-date with platform innovations.
*   **Native Performance**: After functional stabilization of v1, the focus will shift entirely to **performance optimization**, aiming to compete with high-speed frameworks.
*   **Innovation**: While inspired by .NET, Dext is not limited to it, seeking to implement solutions that specifically make sense for the Delphi language.

---

## 📄 License

This project is licensed under the **Apache License 2.0** (the same used by .NET Core). This allows free use in commercial and open-source projects, with the security of a permissive and modern license.

---

## 🚀 Main Modules

### 🌐 Dext.Web (Web Framework)
A lightweight and powerful HTTP framework for building REST APIs and microservices.
- **Minimal APIs**: Concise fluent syntax for route definition.
- **Controllers**: Traditional class-based support for complex APIs.
- **Smart Binding**: Automatic JSON serialization and validation for Records/Classes.
- **Middlewares**: Modular and extensible request pipeline.
- **Smart JSON**: Native support for TGUID/UUID, Enums, and advanced types in JSON serialization.
- **OpenAPI**: Native Swagger integration with auto-generated documentation.

### 🗄️ Dext.Entity (ORM)
A modern ORM focused on productivity and performance.
- **Code-First**: Define your database using Delphi classes.
- **Scaffolding**: Database-First support to generate entities from existing schemas.
- **Migrations**: Database schema version control via CLI.
- **Fluent Query API**: Strongly typed and expressive queries.
- **Change Tracking**: Automatic change tracking and optimized persistence.
- **Advanced Types**: Native support for UUID/GUID, Enums (as string or int), JSON/JSONB, and Arrays.
- **Multi-Database**: Support for SQL Server, PostgreSQL, Firebird, MySQL, Oracle, and SQLite.

### ⚙️ Dext.Core (Infrastructure)
The foundation of the framework, usable in any type of application.
- **Dependency Injection**: Full and fast IOC container.
- **Configuration**: Flexible configuration system (JSON, Environment Variables).
- **Logging**: Structured logging abstraction.
- **Async/Await**: Primitives for real asynchronous programming.
- **Collections**: Advanced generic collections with functional extensions.
- **Specifications**: Business rule encapsulation and composition (DDD).
- **Expressions**: Expression tree primitives for dynamic logic evaluation.

---

## 📚 Documentation Index

### 🚀 Getting Started


### 🌐 Web API
- **Routing & Endpoints**
  - [Minimal API](Docs/minimal-api.md)
  - [Validation](Docs/model-binding.md) # (Includes validation)
- **Security & Middleware**
  - [JWT Authentication](Docs/jwt-authentication.md)
  - [CORS](Docs/cors.md)
  - [Rate Limiting](Docs/rate-limiting.md)
- **Advanced**
  - [Background Services](Docs/background-services.md)
  - [Action Filters](Docs/action-filters.md)
  - [Swagger / OpenAPI](Docs/swagger.md)

### 🗄️ Data Access (ORM)
- [Database Configuration](Docs/database-config.md)
- [Fluent Query API](Docs/fluent-query-api.md)
- [Migrations](Docs/migrations-guide.md)
- [Lazy Loading](Docs/lazy-loading-advanced.md)
- [Bulk Operations](Docs/bulk-operations.md)
- [Soft Delete](Docs/soft-delete.md)

### ⚙️ Core & Infrastructure
- [Dependency Injection & Scopes](Docs/scoped-services.md)
- [Configuration & Options Pattern](Docs/options-pattern.md)
- [Async Programming](Docs/async-api.md)
- [Caching](Docs/caching.md)

---

## 💻 Requirements

- **Delphi**: Recommended Delphi 10.4 Sydney or higher (due to extensive use of modern language features).
- **Indy**: Uses Indy components (already included in Delphi) for the HTTP transport layer (subject to future replacement/optimization).

## 📦 Installation and Configuration

1. **Clone the repository:**
   ```bash
   git clone https://github.com/dext-framework/dext.git
   ```

   > 📦 **Package Note**: The project is organized into modular packages located in the `Sources` directory (e.g., `Dext.Core.dpk`, `Dext.Web.Core.dpk`, `Dext.Data.dpk`). You can open `Sources/DextFramework.groupproj` to load all packages at once.

2. **Configure Paths in Delphi:**
   Add the following paths to your **Library Path** (for compilation) and **Browsing Path** (for code navigation):
   - `\Sources\Core`
   - `\Sources\Data`
   - `\Sources\Expressions`
   - `\Sources\Hosting`
   - `\Sources\Http`
   - `\Sources\Testing`

   > 📝 **Note**: Compiled files (`.dcu`, binaries) will be generated in the `.\Output` directory.


3. **Dependencies:**
   - The framework uses `FastMM5` (recommended for memory debugging).
   - Native database drivers (FireDAC, etc.) are supported.

---

## ⚡ Quick Example (Minimal API)

```pascal
program MyAPI;

uses
  Dext.Web;

begin
  var App := TDextApplication.Create;
  var Builder := App.Builder;

  // Simple Route
  Builder.MapGet<IResult>('/hello', 
    function: IResult
    begin
      Result := Results.Ok('{"message": "Hello Dext!"}');
    end);

  // Route with parameter and binding
  Builder.MapGet<Integer, IResult>('/users/{id}',
    function(Id: Integer): IResult
    begin
      Result := Results.Json(Format('{"userId": %d}', [Id]));
    end);

  App.Run(8080);
end.
```

## 🧩 Model Binding & Dependency Injection

Dext automatically resolves dependencies and deserializes JSON bodies into Records/Classes:

```pascal
// 1. Register Services
App.Services.AddSingleton<IEmailService, TEmailService>;

// 2. Define Endpoint with Dependencies
// - 'Dto': Automatically bound from JSON Body (Smart Binding)
// - 'EmailService': Automatically injected from DI Container
App.Builder.MapPost<TUserDto, IEmailService, IResult>('/register',
  function(Dto: TUserDto; EmailService: IEmailService): IResult
  begin
    EmailService.SendWelcome(Dto.Email);
    Result := Results.Created('/login', 'User registered');
  end);
```

## 💎 ORM Example (Fluent Query)

Dext ORM allows expressive and strongly typed queries, eliminating magical SQL strings:

```pascal
// Complex Query with Joins and Filters
// O: TOrder (Alias/Proxy)
var Orders := DbContext.Orders
  .Where((O.Status = TOrderStatus.Paid) and (O.Total > 1000))
  .Include('Customer') // Eager Loading
  .Include('Items')
  .OrderBy(O.Date.Desc)
  .Take(50)
  .ToList;

// High-Performance Bulk Update
DbContext.Products
  .Where(P.Category = 'Outdated') // P: TProduct
  .Update                         // Starts bulk update
  .Execute;
```

## ⚡ Async Example (Fluent Tasks)

Forget `TThread` complexity. Use a modern API based on Promises/Tasks:

```pascal
// Asynchronous Task Chaining
var Task := TAsyncTask.Run<TUserProfile>(
  function: TUserProfile
  begin
    // Runs on background
    Result := ExternalApi.GetUserProfile(UserId);
  end)
  .ThenBy<Boolean>(
    function(Profile: TUserProfile): Boolean
    begin
      Result := Profile.IsVerified and Profile.HasCredit;
    end)
  .OnComplete( // Returns to UI Thread automatically
    procedure(IsVerified: Boolean)
    begin
      if IsVerified then
        ShowSuccess('User Verified!')
      else
        ShowError('Verification Failed');
    end)
  .Start; // Starts execution

// Timeout & Cancellation Handling
var CTS := TCancellationTokenSource.Create;

TAsyncTask.Run<TReport>(
  function: TReport
  begin
    // Pass token to long-running operation
    Result := ReportService.GenerateHeavyReport(CTS.Token);
  end)
  .WithCancellation(CTS.Token) // Links token to Task pipeline
  .OnComplete(
    procedure(Report: TReport)
    begin
      ShowReport(Report);
    end)
  .OnException(
    procedure(Ex: Exception)
    begin
      if Ex is EOperationCancelled then
        ShowMessage('Operation timed out!')
      else
        ShowError(Ex.Message);
    end)
  .Start;
```

## 🧪 Examples and Tests

The repository contains practical example projects:

- **`Examples/Orm.EntityDemo`**: Comprehensive demo focused on ORM features (CRUD, Migrations, Querying).
- **`Examples/Web.ControllerExample`**: Demonstrates Controller-based API implementation (includes a minimal **Vite** frontend client).
- **`Examples/Web.SwaggerExample`**: Shows how to integrate and customize OpenAPI/Swagger documentation.
- **`Examples/Web.TaskFlowAPI`**: A complete "Real World" REST API demonstrating layered architecture, ORM, Auth, and DI.
- **`Examples/Dext.Starter.Admin`**: **(Recommended)** A Modern Admin Panel with HTMX, Service Layer, and Minimal APIs. [Read the Guide](Examples/Dext.Starter.Admin/README.md).


---

## 🔮 Coming Soon

- **Advanced Testing Framework**: Pure Delphi testing framework focused on modern patterns (TDD/BDD).
- **Documentation**: Complete revision and bilingual support (English/Portuguese) for all modules.

---

## 🗺️ Roadmaps

Follow the project development:
- [V1.0 Release Plan](Docs/Roadmap/v1-release-plan.md) 🚀
- [ORM Roadmap](Docs/Roadmap/orm-roadmap.md)
- [Web Framework Roadmap](Docs/Roadmap/web-roadmap.md)
- [Infra & IDE Roadmap](Docs/Roadmap/infra-roadmap.md)
- [Architecture & Performance](Docs/architecture-performance.md)

---

**Dext Framework** - *Native performance, modern productivity.*
Developed with ❤️ by the Delphi community.
