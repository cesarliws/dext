# Dext Framework vs .NET / EF Core — Feature Comparison Matrix

> **Purpose**: This document provides a comprehensive, objective comparison between the Dext Framework for Delphi and the equivalent ecosystem of ASP.NET Core + Entity Framework Core for .NET. It is intended to help developers understand what Dext offers, where it has parity, where it goes beyond, and where differences exist due to platform context.
>
> *Last Updated: May 2026*

---

## How to Read This Document

This comparison is structured into four logical blocks:

| Block | Meaning |
|---|---|
| **A — Full Parity** | Dext implements the functional equivalent of the .NET feature |
| **B — Dext Exclusive** | Features Dext has that .NET does not (or requires expensive 3rd party packages) |
| **C — Partial / Roadmap** | .NET has this; Dext has it partially or it is planned |
| **D — Context Difference** | Features of .NET that do not apply to Delphi by design |

---

## Block A — Full Feature Parity

> [!NOTE]
> All features listed here are fully implemented in Dext. The naming convention and API surface are intentionally kept close to the .NET counterparts to lower the learning curve for developers migrating from the .NET ecosystem.

### A.1 ORM / Data Access

| Feature | EF Core | Dext Equivalent | Notes |
|:---|:---|:---|:---|
| **DbContext (Unit of Work)** | `DbContext` | `TDbContext` | Full Unit of Work pattern |
| **Change Tracking** | Automatic (Added / Modified / Deleted / Unchanged) | Automatic — same 4 states | Identity Map for instance uniqueness by PK |
| **SaveChanges** | `SaveChanges()` / `SaveChangesAsync()` | `SaveChanges()` | Persists all tracked changes in a transaction |
| **Generic Repository** | `DbSet<T>` | `DbSet<T>` | Operations: `Add`, `Update`, `Remove`, `Find`, `Where`, `Include`, `ToList` |
| **Code-First Migrations** | `dotnet ef migrations add` | Automated Migrations System | Also via CLI. Chronological snapshots with table/column rename detection. **IDE Expert with wizard planned.** |
| **Lazy Loading** | Proxy-based (`UseLazyLoadingProxies`) | Proxy Objects (transparent interception) | Same architecture |
| **Eager Loading** | `Include()` / `ThenInclude()` | `Include()` / `ThenInclude()` | Same API surface |
| **Soft Delete** | Global Query Filters (manual) | `[SoftDelete]` / `[DeletedAt]` attributes | Fully declarative. HardDelete, Restore, OnlyDeleted, IgnoreQueryFilters. `[DeletedAt]` automatically stamps the deletion datetime. |
| **Multi-tenancy** | Manual / EF Query Filters | `Dext.MultiTenancy` | 3 strategies: Shared DB (TenantId), Schema Isolation, DB per Tenant |
| **Pessimistic Locking** | Not built-in (raw SQL) | `FOR UPDATE` native | Built-in in the query engine |
| **Inheritance: TPH** | Table-Per-Hierarchy | TPH with discriminator attributes | Polymorphic hydration automatic |
| **Inheritance: TPT** | Table-Per-Type | Partial support | |
| **Value Converters** | `HasConversion<T>()` | `TValueConverterRegistry` | 20+ built-in converters (Enum, GUID, TUUID, JSONB, TBytes...) |
| **JSON Column Queries** | `OwnsOne().ToJson()` / `JSON_VALUE` | `[JsonColumn]` + `.Json('path')` | Cross-DB: PostgreSQL JSONB, MySQL JSON_EXTRACT, SQLite json_extract, SQL Server JSON_VALUE |
| **Stored Procedures** | `FromSqlRaw()` / `ExecuteSqlRaw()` | `[StoredProcedure]` + `[DbParam]` | Fully declarative via attributes |
| **Specification Pattern** | 3rd party (Ardalis.Specification) | `Dext.Specifications` — **built-in** | `Where`, `OrderBy`, `Include`, `Take`, `Skip` fluent builder |
| **LINQ-like Query Extensions** | Native LINQ | `Dext.Collections.Extensions` | Unified expression engine, managed records, and implicit operators. Performance optimized via a thread-safe RTTI metadata cache. |
| **Multi-Database Support** | Separate NuGet packages per provider | **7 drivers unified** | Built directly on FireDAC Phys Driver layer (no database components like TQuery). PostgreSQL, SQL Server, MySQL, SQLite, Oracle, Firebird, InterBase (and easily extensible to all FireDAC physical drivers). |
| **Multi-Mapping (Dapper-style)** | Not built-in | `[Nested]` attribute | Recursive hydration. Fully supports mapping directly to Views and Stored Procedures, not just tables. |
| **Connection Pooling** | ADO.NET pooling | Fluent Connection Setup + Pooling Auto-Detection | `UsePostgreSQL`, `UseFirebird`, etc. with auto pooling |
| **Paging** | `Skip()` / `Take()` | `Skip()` / `Take()` | Same API |
| **Aggregates** | `Count()`, `Sum()`, `Max()`, `Min()`, `Avg()` | `Count()`, `Sum()`, `Max()`, `Min()`, `Average()` | Same API |
| **SQL Cache** | EF compiled queries | SQL command reuse cache | Repeated queries reuse generated SQL |
| **Bulk Operations** | `ExecuteUpdate()` / `ExecuteDelete()` (EF7+) | `AddRange` / `UpdateRange` / `RemoveRange` | Native support for high-performance batch insert, update, and delete in a single batch call. |
| **Object Mapping (AutoMapper)** | AutoMapper (3rd party) | `TMapper` — **built-in** | `CreateMap<TSource, TDest>`, `ForMember`, `Map<TSource, TDest>`, collection mapping |

### A.2 Web Framework / ASP.NET Core Equivalent

| Feature | ASP.NET Core | Dext Equivalent | Notes |
|:---|:---|:---|:---|
| **Minimal APIs** | `app.MapGet(...)` / `app.MapPost(...)` | `app.MapGet(...)` / `app.MapPost(...)` | Same fluent API |
| **Controller-based APIs** | `[ApiController]` + `ControllerBase` | `[ApiController]` + attribute routing | Same pattern |
| **Middleware Pipeline** | `app.Use(...)` — Chain of Responsibility | `app.Use(...)` — same architecture | Functional (delegates) and class-based with DI injection |
| **Model Binding** | `[FromBody]`, `[FromQuery]`, `[FromRoute]`, `[FromHeader]`, `[FromServices]` | Same attributes | Zero-allocation via `TByteSpan` (direct UTF-8 deserialization) |
| **API Versioning** | `Asp.Versioning` (NuGet) | **Built-in** — 4 readers | `THeaderApiVersionReader`, `TQueryStringApiVersionReader`, `TPathApiVersionReader`, `TCompositeApiVersionReader` |
| **Rate Limiting** | `Microsoft.AspNetCore.RateLimiting` | **Built-in** — 4 algorithms | Fixed Window, Sliding Window, Token Bucket, Concurrency Limiter |
| **CORS** | `UseCors()` | CORS middleware — built-in | |
| **Output Caching** | `IOutputCache` | In-Memory (Redis Client planned) | Redis client is 80% complete and built natively in Dext for maximum performance |
| **Health Checks** | `IHealthCheck` | Health Checks — built-in | Basic built-in implementation; database and external service integrations on the roadmap |
| **ProblemDetails (RFC 9457)** | Built-in .NET 8+ | Built-in | Exception handling middleware produces RFC 9457 compliant responses |
| **OpenAPI / Swagger** | `Microsoft.AspNetCore.OpenApi` | **Built-in** — automatic generation | Registered endpoints auto-appear in Swagger |
| **SSE (Server-Sent Events)** | `IServerSentEvents` | SSE native | |
| **SignalR Equivalent (Hubs)** | SignalR | SSE-based Messaging (SignalR planned) | Currently basic SSE broadcast. Full bi-directional Hub interfaces are ready; implementation is planned post-native IOCP/EPOLL engine (avoiding LGPL-3.0 dependencies like Delphi-Cross-Socket). |
| **Background Services** | `IHostedService` / `BackgroundService` | `IHostedService` + `TBackgroundService` | `Execute(ICancellationToken)` |
| **Application Lifetime** | `IHostApplicationLifetime` | `IHostApplicationLifetime` | `ApplicationStarted`, `ApplicationStopping`, `ApplicationStopped` |
| **Template Engine** | Razor | Dext Template Engine | AST-based, zero-dependency, layout inheritance, macros, filters |
| **Template Engine Alt** | Razor Pages | Web Stencils (Delphi 12.2+) | Native Delphi alternative |
| **Multipart / File Upload** | `IFormFile` | `IFormFile` | Same abstraction |
| **GZip Compression** | `UseResponseCompression` | Built-in middleware | High-performance GZip middleware |
| **Developer Exception Page** | `UseDeveloperExceptionPage()` | `DeveloperExceptionPage` middleware | |

### A.3 Core Framework

| Feature | .NET | Dext Equivalent | Notes |
|:---|:---|:---|:---|
| **Dependency Injection** | `Microsoft.Extensions.DI` | `TDextServices` | `AddSingleton`, `AddTransient`, `AddScoped`, `AddSingletonFactory` |
| **DI Lifecycles** | Singleton / Transient / Scoped | Singleton / Transient / Scoped | `CreateScope` for isolated child provider |
| **Auto-Collections (DI)** | `IEnumerable<T>` injection | `IList<T>`, `IEnumerable<T>`, `IDictionary<K,V>` | Resolved automatically |
| **DI Attributes** | `[FromServices]` | `[Inject]`, `[ServiceConstructor]` | Field/property/constructor injection |
| **Configuration System** | `IConfiguration` / `appsettings.json` | `TDextConfiguration` | JSON, YAML, ENV, CLI args, InMemory — same multi-provider design |
| **Options Pattern** | `IOptions<T>`, `IOptionsSnapshot<T>`, `IOptionsMonitor<T>` | `IOptions<T>`, `IOptionsSnapshot<T>`, `IOptionsMonitor<T>` | Same interfaces |
| **Hot-Reload Configuration** | `IChangeToken` | `IChangeToken` + `OnReload` callback | |
| **Logging** | `ILogger<T>` / `ILoggerFactory` | `ILoggerFactory` / `ILogger` | Trace, Debug, Information, Warning, Error, Critical |
| **Async / Await** | `Task<T>` / `async/await` | `TAsyncTask` + Work-Stealing Scheduler | |
| **Cancellation Token** | `CancellationToken` | `ICancellationToken` | `WaitForCancellation`, `IsCancellationRequested` |
| **Nullable<T>** | `Nullable<T>` / `T?` | `Nullable<T>` | `HasValue`, `Value`, `GetValueOrDefault`, implicit operators |
| **Lazy<T>** | `Lazy<T>` | `Lazy<T>` | Thread-safe double-checked locking; factory-based and pre-computed |
| **Span<T> / ReadOnlySpan<T>** | `Span<T>` / `ReadOnlySpan<T>` | `TSpan<T>` / `TReadOnlySpan<T>` | Zero-allocation; bounds-checked |
| **Object Mapping** | AutoMapper (3rd party) | `TMapper` built-in | |
| **JSON Serialization** | `System.Text.Json` / Newtonsoft | `TDextJson` + Low-level UTF-8 streaming | Pluggable drivers. Includes zero-allocation binary JSON reader/writer using `TSpan` directly on raw bytes without heap allocations. |
| **Frozen Collections** | `FrozenDictionary<K,V>` (.NET 8+) | `TFrozenDictionary<K,V>` / `TFrozenSet<T>` | Lock-Free reads; immutable after construction |
| **Channels (Go-inspired)** | `System.Threading.Channels` | `TChannel<T>` | Bounded (backpressure) + Unbounded; ChannelReader/ChannelWriter |
| **Event Bus / MediatR** | MediatR (3rd party) | `Dext.Events` — **built-in** | Behaviors pipeline (logging, timing, exception); scoped/singleton bus |
| **Defer Pattern** | `using` / `IDisposable` | `IDeferred` / `TDeferredAction` | Go-inspired; action executed on scope exit |

### A.4 Testing

| Feature | .NET | Dext Equivalent | Notes |
|:---|:---|:---|:---|
| **Test Framework** | xUnit / NUnit / MSTest (3rd party) | `Dext.Testing` — **built-in** | |
| **Attribute-Based Tests** | `[Fact]`, `[Theory]`, `[Test]` | `[Fact]`, `[Test]`, `[Fixture]`, `[TestClass]` | |
| **Data-Driven Tests** | `[InlineData]`, `[MemberData]` | `[TestCase]`, `[TestCaseSource]`, `[Values]`, `[Range]`, `[Random]` | |
| **Combinatorial Tests** | Parameterized (manual) | `[Combinatorial]` | All parameter combinations auto-generated |
| **Lifecycle Hooks** | `[SetUp]`, `[TearDown]`, `[OneTimeSetUp]` | `[Setup]`, `[TearDown]`, `[BeforeAll]`, `[AfterAll]`, `[AssemblyInitialize]` | |
| **Fluent Assertions** | FluentAssertions (3rd party) | `Dext.Assertions` — **built-in** | `Should(Value)` pattern; structural comparison |
| **Soft Asserts** | FluentAssertions (3rd party) | `Assert.Multiple(...)` — built-in | Collect multiple failures before failing |
| **Snapshot Testing** | Verify (3rd party) | Built-in | Disk-based baseline, structural JSON compare, update mode |
| **Mocking** | Moq / NSubstitute (3rd party) | `Dext.Mocks` — **built-in** | `Mock<T>.Setup.Returns(Val)`, matchers, verification |
| **Auto-Mocking** | AutoFixture + Moq (3rd party) | `TAutoMocker` — **built-in** | Automated mock injection into DI container |
| **CI/CD Reports** | 3rd party libraries | Built-in | JUnit XML, xUnit XML, TRX (Azure DevOps), HTML (Dark Theme), JSON, SonarQube |

---

## Block B — Dext Exclusive Features

> [!IMPORTANT]
> The features in this block exist in Dext but have **no direct equivalent in the .NET ecosystem** (or require expensive 3rd-party solutions that are not officially supported). These are the primary technical differentiators.

| Feature | Dext | .NET / EF Core Status | Impact |
|:---|:---|:---|:---|
| **Database as API** | `[DataApi]` attribute + `app.MapDataApis` — generates full CRUD REST API at runtime in **1 line** | No equivalent. Requires Scaffold + Controllers + Repository + Service layer manually | 🔴 Major — eliminates days of boilerplate for standard CRUD operations |
| **Smart Properties / `Prop<T>`** | Generic record with dual mode: stores value OR generates AST via operator overloading. Type-safe queries **without magic strings**. Same AST used by ORM and URL filter engine | LINQ is native to C#; but AST is not portable between ORM and other subsystems | 🔴 Major — eliminates `nameof()` and expression tree boilerplate |
| **EntityDataSet (ORM ↔ VCL/FMX Bridge)** | Connects `TList<T>` (both Smart Properties and POCO collections) to DBGrid/FastReport. **Live data preview in the IDE in design-time** without compiling | No equivalent. Windows Forms DataAdapter is not POCO-based; no IDE preview from ORM | 🔴 Major (Delphi-specific advantage) |
| **SIMD-Accelerated Collections** | `TRawDictionary` with Open Addressing + Linear Probing. AVX2/SSE2 vectorized lookups. **6.6x faster** than standard RTL dictionary | BCL collections use similar techniques, but developers cannot control or tune at this level | 🟡 High — critical path performance |
| **In-Process `TExpressionEvaluator`** | Evaluates the **same ORM AST** against in-memory objects and dictionaries. Used by `EntityDataSet.Filter` and standalone | EF Core does not expose an in-memory evaluator for the same expression tree used by SQL | 🟡 High — enables truly unified query logic |
| **`TStringExpressionParser`** | Converts URL QueryString (`?age_gt=18`) directly into `IExpression` AST nodes with automatic type inference | No equivalent. DRF (Python) does this; ASP.NET requires custom filter parsing | 🟡 High — powers `Database as API` URL filter system |
| **MCP Server Native** | Zero-dependency MCP 2025-03-26 implementation. `[MCPTool]`, `[MCPParam]`, `[MCPResource]`, `[MCPPrompt]` RTTI attributes. HTTP Streamable, SSE, Stdio transports | No official .NET MCP server implementation (ecosystem still nascent in 2026) | 🟡 High — AI-native framework capability |
| **Flyweight / Streaming SSR** | `TStreamingViewIterator<T>` — renders 10,000+ records with **O(1) memory** during template `@foreach` | `IAsyncEnumerable<T>` + streaming via `yield return` exists but requires manual plumbing | 🟡 High — critical for large-volume SSR without `ToList` |
| **HTMX Auto-Detection** | Framework automatically detects `HX-Request` headers and suppresses global layout on compatible endpoints | ASP.NET does not have native HTMX integration; requires manual header inspection | 🟢 Medium |
| **Binary Code Folding** | `TRawList<T>` — typed generics are thin wrappers over a raw memory core. **Up to 60% reduction in compile times** | Not needed in C# (no Generic Bloom problem in the CLR) | 🟢 Medium (Delphi-specific) |
| **Live IDE Scaffolding Expert** | Dext Design-Time Expert parses `.pas` units and creates `TFields` dynamically **without compiling**. Live table selection with real-time SQL preview | EF Core Scaffold requires compilation and migration; no comparable IDE integration | 🟢 Medium (Delphi-specific advantage) |
| **AI Skills (Native)** | Modular `.md` skill files teaching AI assistants (Cursor, Antigravity, Copilot, Claude) to generate idiomatic Dext code | Elevates developer efficiency directly inside modern AI editors | 🟢 Medium — DX multiplier |
| **Visual Telemetry Dashboard (Built-in)** | Embedded Dashboard (WIP) with Gantt span tree, RED metrics graphs (RPS, QPS, latency, errors), SQL profiler, HTTP profiler | Requires Grafana + Prometheus + Jaeger + OpenTelemetry collector as separate infrastructure | 🔴 Major for teams without DevOps infrastructure (significant updates coming soon) |
| **UUID v7 Native** | `TUUID.NewV7` — time-ordered, RFC 9562 compliant. Automatic endianness swap for PostgreSQL `uuid` | `Guid.NewGuid()` generates v4; v7 requires NuGet package (UUIDNext, etc.) | 🟢 Medium |
| **FireDAC `ConnectionDef` Support** | `UseConnectionDef('MyConn')` resolves dialect, driver, and pooling from FDManager automatically | Allows zero-config deployment by directly reading global IDE/Server FD connection profiles. | 🟢 Medium (Delphi-specific advantage) |
| **`.http` File Runner (Built-in)** | Native parser for standard `.http` files. Same file documents the API, is tested in Dashboard, and executed by RestClient | VS Code/.http files are a tooling convention; ASP.NET does not have a built-in runner | 🟢 Medium — DX advantage |

---

## Block C — Partial in Dext / Roadmap Items

> [!NOTE]
> These are features where .NET has a more complete or different implementation. Dext either has a partial equivalent or the feature is planned.

| Feature | .NET Status | Dext Status | Notes |
|:---|:---|:---|:---|
| **OpenTelemetry ActivitySource** | Fully integrated (ActivitySource, Meter, W3C Trace Context) | Partial — `TDiagnosticSource` + CorrelationId tracking | Roadmap: full OTel exporters (OTLP, Console) |
| **HybridCache (L1 + L2 unified)** | .NET 9+ — unified L1 (in-memory) + L2 (Redis/SQL), stampede protection, tag-based invalidation | Partial — In-Memory and Redis available separately | Roadmap: unified `HybridCache` API |
| **DbContext Pooling** | `AddDbContextPool<T>` — high-traffic context reuse pool | Not yet implemented | Roadmap: `TPooledDbContextFactory` |
| **Named Query Filters (multiple)** | EF Core 10 — multiple named filters per entity, selectively enabled/disabled | Partial — single global filter per entity | Roadmap: named filter support |
| **`ISaveChangesInterceptor` (formal)** | EF Core Interceptors — decoupled pipeline | Partial — auditing is done inside `DbContext` override | Roadmap: formal interceptor interfaces |
| **`IDbCommandInterceptor` (formal)** | SQL command interception for logging, correlation IDs | Partial — `TDiagnosticSource` captures SQL | Roadmap: formal command interceptor |
| **Vector Search / Hybrid Search** | EF Core 10 + SQL Server 2025 | Not implemented | Niche requirement — will track adoption |

---

## Block D — Context Differences (Not Applicable to Delphi)

> [!NOTE]
> These are features of the .NET ecosystem that do not apply to the Dext Framework by design. The difference is architectural and platform-specific, not a gap.

| Feature (.NET) | Why It Doesn't Apply to Dext |
|:---|:---|
| **Blazor / WebAssembly** | Delphi compiles to native binaries. UI for desktop apps uses FMX (multi-platform) or VCL (Windows). No browser runtime needed |
| **JavaScript Interop** | Delphi has no JS runtime. Browser integration, when needed, is via standard REST APIs |
| **Native AOT compilation** | Delphi has always compiled ahead-of-time to native machine code. This is the default, not a new feature. No warm-up time, no JIT, no runtime |
| **Passkey / Biometric Identity UI** | Browser-level WebAuthn API — handled at the reverse proxy or front-end layer |
| **ANCM / IIS Module** | Dext uses the `WebBroker Adapter` for native IIS/ISAPI/CGI integration — already a first-class citizen |
| **gRPC (proto-buf generated code)** | Delphi has no native gRPC compiler; but **gRPC & Protobuf are on Wave 3 of Dext's Roadmap ([S02](../../DextRepository/Docs/ROADMAP.md#L36))** as a high-performance native IOCP/EPOLL engine with Code-First gRPC mapping for Delphi Interfaces ([S14](../../DextRepository/Docs/ROADMAP.md#L42)). |
| **Compiled Models (EF Core)** | Delphi compiles the entire model ahead-of-time. There is no warm-up cost for ORM metadata at runtime |
| **Source Generator Validation** | Delphi does not have Source Generators as a language feature. Dext uses RTTI-based validation (`[Required]`, `[Range]`, etc.) which achieves the same result |
| **HSTS Middleware** | Typically managed by the reverse proxy (Nginx, Caddy, Traefik). Dext focuses on app-layer concerns |
| **Static Assets Pipeline (`MapStaticAssets`)** | Relevant for web apps serving front-end bundles. Delphi apps typically serve through a CDN or reverse proxy |

---

## Summary Statistics

| Category | Count |
|:---|:---|
| Full Parity Features (Block A) | 60+ |
| Dext-Exclusive Features (Block B) | 17 |
| Roadmap Items (Block C) | 7 |
| Context Differences — Not Applicable (Block D) | 10 |

## Engineering & High-Performance Foundations

To understand how these functional parity points and exclusive features are implemented at a lower level, refer to our comprehensive architectural guide. It covers compiler-level optimizations, memory footprints, and low-level performance benchmarks:

* 👉 **[Dext Framework Ecosystem Overview](https://github.com/dotpas/dext/blob/main/Docs/Dext_Ecosystem_Overview.md)**: Deep dive into the *Zero-Allocation Web Pipeline*, *Binary Code Folding (Generic Bloom Cure)*, and *SIMD-Accelerated Collections*.

---

## Navigation

This document is a **reference table** — use it to look up specific features or run precise comparisons.

| I want to… | Go to… |
|:---|:---|
| Understand *why* Dext was built and get the big picture | [Dext vs .NET — Architecture Narrative](./Dext_vs_DotNet_Narrative.md) |
| Deep-dive into the ORM with code examples (Delphi vs C#) | [Dext ORM — Complete Capabilities Reference](./Dext_ORM_Capabilities.md) |
| Understand Apache 2.0 licensing and enterprise compliance | [Open Source Licensing for Enterprise](./Open_Source_Licensing_Enterprise.md) |
| Read the full Dext ecosystem architecture | [Dext Ecosystem Overview](https://github.com/dotpas/dext/blob/main/Docs/Dext_Ecosystem_Overview.md) |

---

*Dext Framework — Feature Comparison Reference | May 2026*
