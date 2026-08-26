# Dext Framework — Ecosystem Overview

> *"Not a collection of libraries. A cohesive integrated platform."*

This document presents the **Dext Framework** as a unified ecosystem, highlighting how each subsystem interconnects to form a complete enterprise development platform — something that **did not exist in Delphi** until now.

There are excellent projects in the Delphi ecosystem that solve isolated problems (ORM, DI, testing, REST). Dext's core differentiator is that **every single piece was designed to work together**, from the HTTP request down to database persistence, passing through DI, logging, validation, serialization, and telemetry — all within a unified and cohesive pipeline.

---

## 🧬 The Philosophy: Simplicity Requires Sophisticated Engineering

> *"Simplicity is Complicated."* — Rob Pike

The developer writes `App.MapGet('/users', ...)` and gains routing, model binding, JSON serialization, DI, logging, and error handling. But under the hood, the framework resolves:

1. The **Reflection Engine** discovers parameter types via thread-safe RTTI cache.
2. The **Activator** resolves dependencies with **greedy constructor selection**.
3. The **DI Container** injects services with hybrid lifecycles (ARC for interfaces, manual for classes).
4. The **Model Binder** deserializes the JSON body using the high-performance driver (zero-allocation UTF-8).
5. The **Validation Engine** applies validation attributes automatically.
6. The handler executes the business logic.
7. The result is serialized via `TUtf8JsonWriter` directly to the socket — **without intermediate string allocation**.

All of this happens invisibly to the developer. That is the promise.

> *"Make what is right easy and what is wrong difficult."* — Steve "Ardalis" Smith

---

## 🌐 Web Server Agnostic: Hosting Flexibility

The Dext Web Framework is completely isolated from the underlying HTTP server implementation. You write your application and routing logic once and choose how to serve the traffic depending on the environment and licensing, supporting:

1. **Indy (Built-in)**: The default choice. It comes natively with Delphi, with zero external dependencies. Perfect for internal APIs, standalone microservices, testing, and rapid development.
2. **WebBroker (Delphi Professional/Enterprise)**: The choice for legacy infrastructure or consolidated web servers. It allows running the same Dext application as an **Apache Module**, **ISAPI** (IIS), or **FastCGI** (to be served via NGINX).
3. **Delphi Cross Sockets - DCS (High Performance)**: The choice for extreme scalability and Real-Time applications. It uses asynchronous operating system APIs (**IOCP** on Windows, **EPOLL** on Linux, and **KQUEUE** on macOS) and offers native support for **WebSockets** for bidirectional communications.
   * *Licensing Note:* DCS is a third-party dependency licensed under **LGPL**. If you choose to use it in production, it is necessary to evaluate compatibility with the distribution terms of your commercial project.
4. **Windows HTTP Server API - http.sys (Zero-Allocation Native)**: The choice for maximum performance on Windows. It registers directly with the Windows HTTP kernel-mode driver (`http.sys`), bypassing user-mode socket overhead. Offers **zero heap allocations** on the request/response hot-paths through advanced request/response pooling and raw UTF-8 known headers table mapping.

---

## 🔥 Zero-Allocation Web Pipeline: The Performance Engine

Dext's HTTP pipeline was refactored from the ground up to **eliminate heap allocations** in request-processing hot-paths. This is not a local optimization — it is an architectural philosophy that spans the entire stack:

### From Request to Response — Without Allocating

```
[Socket] → TByteSpan (raw bytes, stack-allocated)
         → TUtf8JsonReader (zero-copy parsing directly from the buffer)
         → TUtf8JsonSerializer (record fields via PTypeInfo cache — no TValue boxing)
         → Prop<T> / Smart Types (query mode or runtime mode, no intermediates)
         → Handler executes logic
         → TUtf8JsonWriter (direct streaming to the socket — no intermediate string)
         → [Socket]
```

**Components involved in the zero-allocation pipeline:**

| Layer | Component | Impact |
|---|---|---|
| **Input Parsing** | `TByteSpan` + `TUtf8JsonReader` | Avoids UTF-8 → UTF-16 → UTF-8 conversion |
| **Deserialization** | `TUtf8JsonSerializer` | `TJsonRecordInfo` cache per `PTypeInfo` — eliminates repeated RTTI scans |
| **RTTI / Reflection** | `TReflection` | Lock-free fast path with singleton metadata cache |
| **Value Conversion** | `TValueConverterRegistry` | 3-level lookup without intermediate TValue allocation |
| **Comparisons** | `TDextSimd.EqualsBytes` | AVX2 (32 bytes/cycle) or SSE2 (16 bytes/cycle) |
| **Output Serialization** | `TUtf8JsonWriter` | Direct streaming to output buffer — zero temporary strings |
| **View Engine** | Flyweight Iterators | O(1) memory in template loops |

**The result**: Request processing time dropped **drastically** compared to traditional pipelines that convert strings multiple times. Each request touches the heap **as little as possible**.

---

## 🧠 Smart Types: The DSL That Shouldn't Exist in Delphi

The `Prop<T>` system is Dext's most significant innovation — a **LINQ-like fluent DSL with strong typing** implemented entirely via **operator overloading** and **expression trees**. This did not exist in Delphi.

### What the Developer Writes

```pascal
TUser = class
  property Age: IntType ...;      // Alias for Prop<Integer>
  property Name: StringType ...;  // Alias for Prop<string>
end;

var U := Prototype.Entity<TUser>;
// Static compilation query with IntelliSense
var Users := DbContext.Users
  .Where((U.Age > 18) and (U.Name.StartsWith('Ce')))
  .OrderBy(U.Age.Desc)
  .Take(50)
  .ToList;
```

### What Happens Under the Hood

1. `TPrototype` creates a "phantom" instance of `TUser` with `IPropInfo` injected into each `Prop<T>`.
2. When `U.Age > 18` executes, the `Prop<Integer>` is in **Query Mode** — instead of comparing values, it generates a `TBinaryExpression(TPropertyExpression('Age'), TLiteralExpression(18), boGreaterThan)` node.
3. The `and` operator combines expressions into `TLogicalExpression(left, right, loAnd)`.
4. The final `BooleanExpression` carries the entire AST.
5. The **SQL Dialect Compiler** traverses the tree and generates: `WHERE "Age" > 18 AND "Name" LIKE 'Ce%'`.

**The magic**: The same `Prop<T>` works in two modes. In query context, it generates SQL. In runtime context, it operates as a standard value type. The developer **never changes the API** — it is the same entity in both scenarios.

### Type System Depth

```
Prop<T>  ───────────►  BooleanExpression  ────►  IExpression (AST)
  │                           │                    │
  ├─ Implicit(T)              └─ and/or/not        ├─ TPropertyExpression
  ├─ Implicit(Nullable<T>)                         ├─ TBinaryExpression
  ├─ Implicit(Variant)                             ├─ TLogicalExpression
  ├─ Like/StartsWith/Contains                      ├─ TFunctionExpression
  ├─ In/NotIn/Between/IsNull                       ├─ TLiteralExpression
  ├─ Asc/Desc → IOrderBy                           └─ TConstantExpression
  └─ Arithmetic: +, -, *, /
```

---

## 📦 Dext.ORM Innovations: Multi-Mapping and Command Pattern

Dext.ORM does not limit itself to emulating Entity Framework; it solves historical data access pain points with high-performance solutions inspired by micro-mappers (like Dapper) and advanced architectural patterns.

### 1. Multi-Mapping Without Boilerplate (Split-free)
Unlike Dapper (.NET), which requires declaring magic splitting strings (`splitOn: 'Id'`) to map flat join results to complex object graphs, Dext performs **convention-driven path routing**:
* **Column Scanning**: When encountering columns with separators like `_` or `.` (e.g. `Product_Name` or `Product.Price`), the hydrator recognizes the nesting intent.
* **Recursive Auto-Instantiation**: If the nested object (`Product: TProduct`) is marked with `[Nested]` and is currently `nil`, the framework dynamically allocates it on-the-fly via the optimized, thread-safe `TActivator` cache.
* **Infinite Depth**: Dext's hydrator traverses column paths of any depth (e.g. `Order_Customer_Address_City`) recursively and automatically.
* **O(1) Performance**: Hydration bypasses slow property setters and injects values directly into physical memory offsets of backing fields (`FFields`), eliminating intermediate heap allocations.

### 2. Stored Procedures as Command/CQRS Pattern
Executing stored procedures with multiple input/output parameters or multiple datasets in traditional ORMs is a constant source of connection leaks and low-level code. Dext transforms procedures into **strongly-typed Command classes**:
* **Contract Class**: The developer declares a class representing the procedure (e.g. `TGetTopProducts`), annotating input and output parameters with `[DbParam]`.
* **Auto-Hydration of Projections**: Returned datasets are automatically hydrated into collections (e.g. `Results: IList<TProduct>`) exposed on the class itself.
* **Database Isolation**: All complexity regarding creating ADO.NET/FireDAC parameter objects, binding physical datatypes, and opening/closing cursors is abstracted by Dext. The developer simply instantiates the command, sets the input properties, and executes `Db.Execute(Command)`.

---

## 🖼️ TEntityDataSet: The Magic Bridge Between ORM and Design-Time UI

> *"What if a company with a massive legacy ERP wants to adopt Dext? How would they handle hundreds of forms packed with DB-aware components (DBGrids, DevExpress cxGrid) and dozens of FastReport reports visually designed in the IDE?"*

It was exactly this question that guided the creation of this feature. Building modern APIs with POCOs and Clean Architecture is excellent, but Delphi remains unmatched in rapid visual UI construction. `TEntityDataSet` was engineered to be the perfect bridge between the new domain architecture and the rich ecosystem of legacy visual components, **without compromising performance or developer experience (DX)**.

1. **Absurd Performance via Zero-Allocation**: Unlike traditional dataset adapters that use RTTI scans on every read operation, `TEntityDataSet` connects natively to a `TList<T>` (or `TObjectList<T>`). It extracts memory *offsets* during initialization via `TEntityMap`. During data binding with the grid, reading a value is virtually accessing a memory pointer directly, with zero reflection overhead.
2. **Automatic Setup (Entity Parsing)**: Forget manual column configurations. At design-time, Dext parses your units, locates entities marked with attributes, and **creates all `TFields` automatically** in the DataSet.
3. **Real Design-Time Data Preview**: Designing reports (FastReport) "in the dark" is frustrating. Dext solves this brilliantly: if you provide a `TFDConnection` and a `DataProvider`, the framework **generates dynamic SQL at design-time** and populates `TEntityDataSet` with real database records. You see the actual data live inside the IDE!
   * *Note:* At runtime, this design-time SQL is never executed. The component directly consumes your real in-memory object list, fully respecting your application logic.

---

## 🏎️ Collections & Concurrency: Performance Oasis

Dext rebuilds Delphi's data foundations to solve the two biggest bottlenecks of modern backends: **Generic Code Bloat** (binary size inflation/slow build times) and **Thread Contention** (locks under multi-core load).

### 1. Binary Code Folding: Curing Generic Bloat
The Delphi compiler duplicates binary machine code for every specialization of a generic class. Dext implements the **Code Folding** pattern, where hundreds of typed `IList<T>` instances share a single core engine `TRawList` operating over raw memory.
* **Real Impact**: Up to **60% reduction in compile times** in large projects (e.g., a 9-minute build reduced to 3.5 minutes).

### 2. Sniper Architecture (Zero-Alloc & SIMD)
* **Dictionaries with Open Addressing**: Unlike the standard RTL (which uses linked lists and causes cache misses), `TRawDictionary` uses *Linear Probing* in contiguous memory. **Result: 6.6x faster than RTL.**
* **SIMD Acceleration**: Memory scans using hardware-level vector instructions (AVX2/SSE2) process up to 32 bytes per clock cycle. **Result: Sorts are 6.8x faster.**
* **Vector + Span**: Manipulating massive buffers and files without intermediate memory allocations.

### 3. Modern Concurrency (Inspired by Go and .NET 8)
* **IChannel\<T\>**: Lock-Free transmission channels with native support for **Backpressure** (Bounded Channels) — essential to prevent fast producers from crashing the server.
* **Frozen Collections**: Immutable collections ("Write once, freeze") allowing infinite simultaneous read operations without using any locks (`TCriticalSection`), eliminating scalability bottlenecks in multi-threaded backends.

---

## 🧪 The Complete Quality Lifecycle

Dext doesn't just let you build applications — it guarantees they are **testable from end to end**:

```
[Code] → [Unit Tests + Mocking]
       → [Auto-Mocking Container (TAutoMocker)]
       → [Snapshot Testing (JSON baselines)]
       → [Code Coverage (dext test --coverage)]
       → [Quality Gates (CI/CD thresholds)]
       → [Reports: JUnit XML, TRX, SonarQube, HTML]
       → [Live Dashboard (dext ui)]
```

**Fully Integrated with DI**: `TTestServiceProvider` replaces production services with mocks without changing application code.

### The Quality Arsenal

1. **Auto-Mocking Container (`TAutoMocker`)**: No more instantiating dozens of mocks manually. `TAutoMocker` resolves the dependency graph and automatically injects mock objects into all interfaces required by the system under test.
2. **Snapshot Testing (`MatchSnapshot`)**: For validating complex JSON payloads or massive DTO outputs. Dext serializes the result, compares it with an approved baseline snapshot, and reports any regression.
3. **Integrated Code Coverage**: Run `dext test --coverage` via the CLI, and the framework uses its own instrumentation to generate detailed coverage reports (lines/branches) ready for SonarQube.
4. **Native CI/CD Integration**: Out-of-the-box support for generating standard industry reports: JUnit XML, TRX (Azure DevOps), and HTML. Quality Gates fail the pipeline automatically if coverage falls below your thresholds.
5. **Live Test Dashboard**: Execute `dext ui` and gain a local, modern dark-themed dashboard running in your browser to visualize the execution of your entire test suite in real-time.

---

## 🗄️ Database as API: One Line of Code, the Entire Ecosystem Working

**Database as API** is the ultimate demonstration of how Dext's integrated ecosystem eliminates architectural friction. It is entirely possible to build similar APIs by stitching together isolated libraries, but the engineering cost is brutal: mountains of boilerplate code, performance bottlenecks, exhausting DTO mappings, excessive heap allocations, and a fragile, high-maintenance codebase. 

Dext resolves this at the root: with **a single line of code**, the developer gains a complete REST API with security, filters, pagination, documentation, and telemetry — all operating in harmony over a zero-allocation pipeline with enterprise quality.

### What the Developer Writes

```pascal
[Table, DataApi]  // ← This is all.
TProduct = class
  [PK, AutoInc] property Id: Integer;
  property Name: string;
  property Price: Double;
end;

// In startup:
App.Builder.MapDataApis;  // Scans RTTI, registers all [DataApi] classes automatically
```

### What the Framework Delivers

```
One line → 5 REST endpoints (GET list, GET by id, POST, PUT, DELETE)
          → 11 URL QueryString filter operators (_gt, _lt, _cont, _in, ...)
          → Automatic pagination (_limit, _offset)
          → Dynamic sorting (_orderby=price desc)
          → Operation-level security (RequireAuth, RequireRole, ReadRole vs WriteRole)
          → Automatic Swagger/OpenAPI documentation
          → Telemetry (TDiagnosticSource)
          → Structured Logging
          → Multi-tenancy (RequireTenant)
          → Full support for UUID, GUID, and Composite Keys
```

### How Many Subsystems Are Activated with One Line?

| Subsystem | What It Does in DataApi |
|---|---|
| **RTTI / Reflection** | `TDataApi.MapAll` scans `[DataApi]` attributes via `TReflection`. `ResolvePropertyName` converts snake_case→PascalCase via `GetHandlerBySnakeCase` |
| **DI Container** | `GetDbContext` resolves the scoped `TDbContext` instance for the current HTTP request |
| **ORM (TDbContext)** | `DataSet(ClassInfo)` returns dynamic `IDbSet`. Handles `Add`, `Update`, `Remove`, `FindObject`, `ListObjects` |
| **Specifications (AST)** | QueryString filters generate `IExpression` via `TStringExpressionParser.Parse` — the **same AST** used by `Prop<T>` |
| **JSON Engine** | `TDextJson.Deserialize` (input) + `TDextSerializer` (output) with configurable `NamingStrategy` and `EnumStyle` |
| **Model Binding** | `TEntityIdResolver` delegates to `IModelBinder` to convert `{id}` from the URL to Integer/TUUID/TGUID automatically |
| **Security** | `CheckAuthorization` validates JWT token via `IClaimsPrincipal` with clean read/write role separation |
| **Swagger / OpenAPI** | Endpoints are automatically exposed in the OpenAPI spec with proper tags and descriptions |
| **Telemetry** | `TDiagnosticSource.Write` publishes tracing events at start/complete phases of model binding and execution |
| **Naming Conventions** | `TDataApiNaming` removes `T` prefix, pluralizes path names, and generates `/api/products` |

This is what integration means: None of these subsystems were built *exclusively* for the DataApi. Each was built as an independent, decoupled piece of the ecosystem. The DataApi simply **orchestrates** them — resulting in a single line of code activating 10 subsystems working in perfect harmony.

---

## 🏗️ The Integrated Ecosystem: How Everything Connects

What separates Dext from isolated third-party libraries is **end-to-end integration**. Every subsystem was engineered with deep awareness of the others:

### The Integration Graph

```
                        ┌──────────────────┐
                        │     Dext CLI     │
                        │  (dext new/add)  │
                        └────────┬─────────┘
                                 │ generates projects using
                                 ▼
┌────────────────┐      ┌──────────────────┐      ┌────────────────┐
│ Template Engine│◄─────│   Web Pipeline   │─────►│  View Engine   │
│ (AST-based)    │      │  (Zero-Alloc)    │      │ (SSR/Stencils) │
└────────────────┘      └────────┬─────────┘      └────────────────┘
                                 │
                    ┌────────────┼──────────────┐
                    ▼            ▼              ▼
        ┌──────────────┐  ┌────────────────┐  ┌──────────────┐
        │ DI Container │  │  JSON Engine   │  │  Validation  │
        │ (Hybrid ARC) │  │ (UTF-8 0-alloc)│  │ (Attribute)  │
        └──────┬───────┘  └──────┬─────────┘  └──────────────┘
               │                 │
               ▼                 ▼
        ┌──────────────┐ ┌────────────┐  ┌──────────────────┐
        │  Reflection  │ │Smart Types │  │   Collections    │
        │  (Cache)     │ │ (Prop<T>)  │  │ (SIMD/Channels)  │
        └──────┬───────┘ └──────┬─────┘  └────────┬─────────┘
               │                │                 │
               ▼                ▼                 ▼
        ┌──────────────────────────────────────────────────┐
        │        Memory & Performance Foundation           │
        │   (TSpan<T>, TByteSpan, SIMD, Code Folding)      │
        └───────────────┬────────────────┬─────────────────┘
                        │                │
                        ▼                ▼
                ┌──────────────┐   ┌──────────────┐
                │     ORM      │◄──│Specifications│
                │  (Multi-DB)  │   │ (IExpression)│
                └──────┬───────┘   └──────────────┘
                       │
              ┌────────┼──────────┐
              ▼        ▼          ▼
          ┌────────┐  ┌────────┐  ┌────────┐
          │ PgSQL  │  │ MSSQL  │  │ MySQL  │ ... + Firebird, SQLite, Oracle
          └────────┘  └────────┘  └────────┘
```

---

## 📊 What Dext Brought to Delphi

| Capability | How Dext Resolves It |
|---|---|
| **Type-safe LINQ-like DSL** | `Prop<T>` + Expression Trees + operator overloading |
| **Separated Companion Metadata** | `TEntityType<T>` separates domain data (POCO) from query metadata |
| **Zero-allocation HTTP pipeline** | `TByteSpan` → `TUtf8JsonReader` → handler → `TUtf8JsonWriter` → socket |
| **Generic Code Folding** | `TRawList` shares binary core — **up to 60% faster compilation** |
| **Frozen Collections** | `TFrozenDictionary<K,V>`, `TFrozenSet<T>` — lock-free concurrent reads |
| **Go-style Channels** | `IChannel<T>` with bounded/unbounded options and native back-pressure |
| **SIMD-accelerated collections** | kontiguous memory + AVX2/SSE2 — **6.6x faster lookups, 6.8x faster sorts** |
| **Lock Striping** | `TConcurrentDictionary<K,V>` with a striped array of `TSpinLock` |
| **Minimal API routing** | `App.MapGet`, `App.MapPost` with fast, zero-allocation model binding |
| **Auto-Mocking Container** | `TAutoMocker` automatically resolves and injects mock interfaces |
| **Snapshot Testing** | `MatchSnapshot` against JSON baseline files |
| **Database as API (1 line)** | `[DataApi]` maps complete CRUD REST routes, activating 10 subsystems in 1 line |
| **Dual-mode Expression Evaluator** | Same `IExpression` AST generates SQL in the DB and filters lists in-memory |
| **Declarative Soft Delete** | `[SoftDelete]` turns DELETE to UPDATE, with `Restore` and `OnlyDeleted` features |
| **JSON/JSONB Queries** | `.Json('path')` translates to PG `#>>`, MySQL `JSON_EXTRACT`, etc. |
| **Flutter-style Desktop Navigator** | Push/Pop/PopUntil + 3 UI Adapters + Middleware Pipeline + Auth Guards |
| **Magic Binding (Desktop MVVM)** | Two-way attribute binding: `[BindEdit]`, `[BindText]`, `[OnClickMsg]` |
| **Zero-alloc EntityDataSet** | Direct binding to `TList<T>` via memory offsets, plus design-time data sync |
| **Flyweight SSR Iterators** | Streams queries directly to templates with O(1) memory — no `ToList` |
| **HTMX Auto-Detection** | Automatically suppresses layout wrappers for `HX-Request` headers |
| **REST Client with Connection Pool** | Lightweight record facade with async chaining, custom auth, and cancellation |
| **Fluent TAsyncTask** | Chained async operations: `Run<T>.ThenBy<U>.OnComplete.OnException.Start` |
| **Typed IOptions<T>** | Binds JSON/YAML/ENV sections directly to typed configuration classes |
| **Native AI Skills** | Integrated Claude/Antigravity skills for direct generation of Dext-idiomatic code |
| **Multi-Tenancy (3 Strategies)** | Column, Schema, and Database isolation fully integrated in the ORM |
| **SignalR-compatible Hubs** | Real-time bi-directional messaging with groups and broadcasting |
| **AST Template Engine** | Tokenizer → AST → execution pipeline with WebStencils integration (Delphi 12.2+) |
| **Hybrid DI Lifecycle** | Automatic ARC for interfaces, manual lifecycle management for concrete classes |
| **precise Stack Trace Extraction** | Detailed stack frame extraction in `Dext.Core.Debug` to locate exact errors |

---

## 📐 Engineering Decisions: Why It Works

### 1. Record Types as Foundation
Modern Delphi (10.3+) supports **operator overloading in records**, **implicit/explicit operators**, and **class operators**. Dext exploits this to the limit: `Prop<T>`, `Nullable<T>`, `TUUID`, `TByteSpan`, `TSpan<T>`, `BooleanExpression` are all records with value semantics, completely eliminating heap allocation overhead.

### 2. Hybrid Memory Model
Instead of forcing a single strategy (ARC or manual), the DI Container automatically adapts: interfaces use native Delphi ARC (reference counting), while classes use framework-managed lifecycles (Singleton is destroyed at host shutdown, Scoped at request completion, and Transient is managed by the caller).

### 3. Driver Pattern for Extensibility
JSON serialization, the HTTP Server, and Database connections share the same decoupled driver design. You can swap `JsonDataObjects` for `System.JSON`, or `Indy` for `DCS`/`WebBroker`, without touching a single line of application code.

### 4. Reflection Cache as Backbone
The thread-safe RTTI cache with lock-free fast paths is the backbone of the entire framework. JSON, ORM, Validation, Model Binding, and Smart Types all query the same singleton metadata cache. A single RTTI scan at startup serves the entire process lifecycle.

### 5. Binary Code Folding
To prevent Delphi's classic generic binary bloat, Dext's typed generic lists are thin, compiler-friendly wrappers over core `TRaw` implementations managing raw memory block structures. This preserves absolute type safety for the developer while saving megabytes in the final executable and minutes in build time.

### 6. Direct Memory Inject (JSON Parsing)
Instead of invoking slow property setters and heavy reflection during JSON deserialization, Dext maps physical field offsets in memory beforehand (`PByte(Obj) + Offset`). During parsing, values are injected directly into their physical memory addresses, achieving speeds close to C++ struct parsing.

### 7. Implicit CQRS (Read vs. Write Pipeline)
The Dext DataApi enforces an implicit read/write segregation strategy:
* **Read (GET)**: An ultra-fast *Direct-to-JSON Streaming* pipeline that sends records from the database driver straight to the network socket, keeping memory consumption at O(1).
* **Write (POST/PUT)**: A domain-centric pipeline focusing on data integrity, hydrating the full entity, and executing all validations and business rules before saving.

### 8. Apache 2.0 Licensing (Enterprise Compliance & Snyk-Approved)
Legal security and governance are absolute prerequisites for corporate adoption. Dext's licensing model is a core pillar of its enterprise compliance:
* **CI/CD Pipeline Compliant**: Dext is completely free of copyleft (GPL/AGPL) dependencies. It effortlessly passes automated license scanners (like **Snyk** or **Black Duck**) integrated into post-commit pipelines.
* **Irrevocable Patent Grant (Patent Peace)**: The Apache 2.0 license guarantees that every contributor explicitly grants users a worldwide, perpetual, royalty-free patent license, shielding your proprietary apps from patent claims.
* **Patent Litigation Retaliation**: A legal shield. If a user sues anyone over patent infringement regarding Dext, their license is terminated immediately, preventing patent trolling.
* **LGPL Isolation**: The *Delphi Cross Sockets (DCS)* dependency — which uses **LGPL** — is completely optional and isolated. Dext runs natively over Indy or WebBroker, ensuring your commercial executables remain strictly proprietary and immune to licensing contamination.

---

## 5. Infrastructure Flywheel — Exponential Feature Composition

The maturity of the core infrastructure creates a **flywheel effect**: every new feature composes existing engines, drastically accelerating framework evolution.

**A Case Study — The Specification Pattern (inspired by Steve "Ardalis" Smith)**:
The Specification engine was originally designed for type-safe ORM queries (`Prop<T>` → `IExpression` → SQL). When the need for dynamic URL filtering arose in the DataApi, the Specification engine **already knew how to resolve it** — `TStringExpressionParser` translates URL filters to the exact same `IExpression` nodes. The complex filtering feature was practically "free."

```
Original Core Engine             →  Emergent Composition
─────────────────────────────────────────────────────────────────────────────
Specification (ORM queries)      →  DataApi (URL filtering — free)
                                 →  In-Memory Evaluator (zero extra code)
Reflection Cache (JSON)          →  ORM + Validation + Model Binding + EntityDataSet
TByteSpan (zero-allocation)      →  JSON Reader + EntityDataSet + [Roadmap] Redis RESP3
TConnectionPool (REST Client)    →  [Roadmap] Redis Client (same pattern)
TAsyncTask (async/await)         →  REST Client + [Roadmap] Redis + Background Services
```

**Practical Result**: During the feasibility study of the high-performance Redis Client, ~80% of the required infrastructure was already fully implemented: `TByteSpan`, `TAsyncTask`, `TConnectionPool`, and `ICancellationToken`. The only new code required was the raw RESP3 protocol driver itself.

### 6. The Integration Trade-off
Decoupled integration brings a **multiplication of responsibility**: a change in `IExpression` must be validated against **every consumer**. This makes automated testing not a luxury, but a necessity for existence. 

The ecosystem is sustained by hundreds of test suites and thousands of assertions, ranging from atomic unit tests to integration tests verified across a 5-database CI matrix. The framework's architectural maturity is proven by real-world deployments in **AWS and Azure** and mission-critical production pilots handling **over 800,000 requests per day**. In total, the framework and its tests encompass **over 200,000 lines of pure Pascal code**, proving its industrial-grade rigor.

---

## 🛤️ Roadmap: Where the Ecosystem Is Going

### Current Wave (In Progress)
* **S14 — SOA via Interfaces**: Transparent Code-First RPC/gRPC — define standard Delphi interfaces and the framework generates all network transport layers automatically.
* **S02 — gRPC & Protobuf**: High-performance, native IOCP/EPOLL engine for binary communication.
* **S06 — OAuth2 & OIDC**: Native OAuth2 login with Google, Microsoft, and custom JWT providers.
* **S13 — Redis Client**: High-performance asynchronous client supporting RESP3 and RedisJSON.

### Future
* Native HTTP Server (pure IOCP/EPOLL/Kqueue — removing DCS dependency).
* OData and GraphQL native support.
* Microservices Service Mesh (Service discovery, load balancing, health checking).
* Native UI rendering using Skia.

---

## 📊 Industrial Authority
* **Codebase**: 200,000+ lines of pure, high-performance Pascal code.
* **Field Tested**: Powering production systems in AWS/Azure processing **~800,000 requests per day** in fiscal management.
* **Test Coverage**: Hundreds of test suites across a 5-database CI matrix (PostgreSQL, SQL Server, MySQL, SQLite, Firebird).
* **Stress Tested**: High concurrency, race conditions, and memory leak scenarios fully validated under heavy load.
* **Compatibility**: Engineered for Delphi 10.3 (Rio) through 12.x (Athens). Limited support for 10.1–10.2 via inline variable refactoring. Web Stencils requires 12.2+.

---

## 🎯 Conclusion

Dext is the definitive answer to the fragmentation of the Delphi ecosystem. It provides the **Industrial Foundation** required to build mission-critical, high-scale applications with the rapid productivity of 2026.

For a detailed feature comparison with .NET/EF Core, see: [`Docs/Marketing/Feature_Comparison_Dext_vs_DotNet.md`](https://github.com/dotpas/dext/blob/main/Docs/Marketing/Feature_Comparison_Dext_vs_DotNet.md)

---

*Dext Framework — Native performance, modern productivity, complete ecosystem.*
