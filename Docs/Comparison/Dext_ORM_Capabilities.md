# Dext ORM — Complete Capabilities Reference

> **Dext is engineered with a vision of "Inspiration, Not Limitation."**
> While Entity Framework Core serves as a brilliant architectural reference for modern enterprise persistence, Dext is not a rigid, stock port. It adapts proven, high-performance patterns from .NET, Java/Spring Boot, Go, and Flutter/Dart, combining them with exclusive native innovations designed specifically for the Delphi compiler and visual VCL/FMX RAD legacies.
> 
> *Last Updated: May 2026*

---

## At a Glance
 
| Metric | Value |
|:---|:---|
| **Supported Databases** | 7 natively (PostgreSQL, SQL Server, MySQL, SQLite, Oracle, Firebird, InterBase) built on the **FireDAC Phys Driver layer** — easily expandable to all database engines supported by FireDAC (DB2, MongoDB, Teradata, etc.). |
| **ORM Architecture** | DbContext / Unit of Work / Change Tracking / Identity Map |
| **Query Language** | Type-safe ergonomic DSL via `Prop<T>` AST |
| **Exclusive Features** | Database as API, EntityDataSet & Active Architecture, Smart Properties AST, JSON Column Queries, native MCP Server |
| **Testing** | 5-database CI matrix (PostgreSQL, SQL Server, MySQL, SQLite, Firebird — structurally covering InterBase as well) |
| **Production Evidence** | AWS/Azure — ~800,000 requests/day in fiscal management systems |

---

## 1. Core Architecture

### DbContext — Unit of Work

The Dext ORM follows the same Unit of Work + Repository pattern as Entity Framework Core.

**EF Core:**
```csharp
public class AppDbContext : DbContext
{
    public DbSet<Product> Products { get; set; }
    public DbSet<Order> Orders { get; set; }

    protected override void OnConfiguring(DbContextOptionsBuilder options)
        => options.UseNpgsql(connectionString);
}

using var db = new AppDbContext();
db.Products.Add(new Product { Name = "Widget", Price = 9.99m });
await db.SaveChangesAsync();
```

**Dext (Current syntax with manual getters):**
```pascal
type
  TAppDbContext = class(TDbContext)
  private
    function GetProducts: IDbSet<TProduct>;
    function GetOrders: IDbSet<TOrder>;
  public
    property Products: IDbSet<TProduct> read GetProducts;
    property Orders: IDbSet<TOrder> read GetOrders;
  end;

function TAppDbContext.GetProducts: IDbSet<TProduct>;
begin
  Result := Entity<TProduct>; // Herdado da classe base TDbContext
end;

function TAppDbContext.GetOrders: IDbSet<TOrder>;
begin
  Result := Entity<TOrder>;
end;

var Db := TAppDbContext.Create(
  DbOptions.UsePostgreSQL(ConnectionString)
);
Db.Products.Add(TProduct.Create('Widget', 9.99));
Db.SaveChanges;
```

> [!NOTE]
> **Roadmap Evolution ([S30](../../DextRepository/Docs/Specs/S30-DbContext-AutoHydration.md))**: In the upcoming Wave 3 stability release, Dext will introduce **Automatic DbContext Hydration** to eliminate even these single-line getters. Properties will map directly to private fields (e.g., `property Products: IDbSet<TProduct> read FProducts;`), and the framework will automatically inject the corresponding repositories during context initialization using the optimized RTTI cache.

Both follow the same pattern. The API surface is intentionally close.

---

## 2. Change Tracking

Dext's Change Tracking uses the same 4-state model as EF Core:

| State | Description |
|:---|:---|
| `Added` | Entity was added via `Add()`, not yet saved |
| `Modified` | Tracked entity had its properties changed |
| `Deleted` | Entity marked for deletion via `Remove()` |
| `Unchanged` | Entity loaded from DB, no changes detected |

**Identity Map**: Like EF Core, Dext maintains an in-memory map ensuring that two queries for the same PK return the same object instance — preventing ghost writes and inconsistent state.

---

## 3. Query Engine — Type-Safe, No Magic Strings

### EF Core approach (Strongly-Typed LINQ):

```csharp
// Fully compile-time type-safe via C# Native LINQ
var products = await db.Products
    .Where(p => p.Price > 100 && p.Name.Contains("Widget"))
    .OrderByDescending(p => p.Price)
    .Skip(20)
    .Take(10)
    .ToListAsync();
```

### Dext approach (Type-Safe AST via Smart Properties ou TEntityType<T> metadata):

```pascal
// Achieves the exact same level of compile-time type safety in Delphi.
// Overloaded operators generate a secure AST without legacy "FieldByName" magic strings.
var P := Prototype.Entity<TProduct>;
var Products := Db.Products
  .Where((P.Price > 100) and P.Name.Contains('Widget'))
  .OrderBy(P.Price.Desc)
  .Skip(20)
  .Take(10)
  .ToList;
```

#### Dual-Mode Architecture & Metadata Cache

The `Prop<T>` record is an engineering marvel designed to work seamlessly in **dual mode**:
- **Runtime Mode**: Operates as a standard field value, storing the type `T` value in memory.
- **Query/DSL Mode**: Overloaded operators (`>`, `<`, `=`, `and`, `or`, `Contains`, `Like`, `In`, `IsNull`...) automatically generate `IExpression` AST nodes. 

Dext gives the developer two elegant patterns to resolve entity companion metadata:
1. **Smart Properties (Unified Domain Entity)**: By embedding `Prop<T>` (or built-in aliases IntType, StringType, BooleanType, etc.) directly inside the entity (e.g. `TProduct`), the class becomes the single source of truth for both data and metadata, keeping the domain highly cohesive.
2. **Separated Companion Type (`TEntityType<T>`)**: If the developer prefers to work with raw primitive Pascal types (e.g. standard `Integer`, `String`, `Boolean`), Dext allows creating a companion class (e.g. `TProductType`) carrying the AST.

To make usage elegant, developers can define a simple class function on the entity returning the metadata:
```pascal
// Option A: Smart Properties (Cohesive Domain)
class function TProduct.Prototype: TProduct;
begin
  Result := Prototype.Entity<TProduct>;
end;

// Option B: Pure Primitive Domain + Companion Type
class function TProduct.Prototype: TEntityType<TProduct>;
begin
  Result := TProductType;
end;
```

**Under the hood**: The metadata extraction footprint is exactly identical. Both approaches leverage Dext's highly optimized, thread-safe RTTI metadata cache. RTTI scanning is executed only once per type, populating the cache and resolving the AST mapping without runtime execution or memory overhead.

**This same AST is used by:**
1. The ORM SQL Compiler (generates database queries).
2. The in-memory `TExpressionEvaluator` (filters standard `TList<T>` collections locally).
3. The `Database as API` engine (translates URL filters like `?price_gt=100` to AST nodes automatically).

---

## 4. Relationships & Loading Strategies

### Eager Loading

**EF Core:**
```csharp
var orders = await db.Orders
    .Include(o => o.Customer)
    .ThenInclude(c => c.Address)
    .ToListAsync();
```

**Dext:**
```pascal
var Orders := Db.Orders
  .Include(O.Customer)
  .ThenInclude(C.Address)
  .ToList;
```

### Lazy Loading

EF Core achieves lazy loading either via transparent virtual proxies (requiring virtual navigation properties) or via `ILazyLoader` injection. 

Dext offers both worlds. It supports transparent proxy interception (same as EF Core's virtual proxies) **and** a highly elegant, explicit generic **`Lazy<T>` wrapper** pattern. The `Lazy<T>` wrapper keeps entities as 100% pure POCOs without needing virtual methods or complex class overrides:

```pascal
type
  [Table('Comments')]
  TComment = class
  private
    FId: Integer;
    FText: string;
    FAuthorId: Integer;
    FAuthor: Lazy<TAuthor>;
  public
    [PK, AutoInc]
    property Id: Integer read FId write FId;
    property Text: string read FText write FText;
    
    [Column('author_id')]
    property AuthorId: Integer read FAuthorId write FAuthorId;
    
    [BelongsTo]
    [ForeignKey('author_id')]
    property Author: Lazy<TAuthor> read FAuthor write FAuthor;
  end;
```

When you access `Comment.Author.Value`, the Dext framework dynamically resolves and executes the database query on demand, using thread-safe double-checked locking. This offers a highly structured, self-documenting architectural contract directly inside the entity definition.

### Multi-Mapping (Dapper-style) & Recursive Hydration

While basic ORMs struggle with flat query results representing joined tables, Dext features a **zero-boilerplate, high-performance recursive hydrator** similar to Dapper's multi-mapping (`splitOn`), but with significantly more automation.

By declaring a relationship field with the `[Nested]` attribute (or mapping it fluently), you activate Dext's **recursive path mapper**.

```pascal
type
  TOrderLine = class
  private
    FProductId: Integer;
    FQuantity: Integer;
    FProduct: TProduct;
  public
    property ProductId: Integer read FProductId write FProductId;
    property Quantity: Integer read FQuantity write FQuantity;

    [Nested]
    property Product: TProduct read FProduct write FProduct;
  end;
```

#### How It Works Under the Hood (No Manual `splitOn` Required)

In Dapper (.NET), mapping a joined row requires specifying a manual `splitOn` string (e.g. `'Id'`) so the framework knows where to segment the flat column list. 

Dext eliminates this configuration step by utilizing **convention-based path routing** at the compiler/RTTI level:

1. **Path-Name Recognition**: The hydrator scans the returned database column list. If it encounters a column with a separator like `_` or `.` (e.g. `Product_Id`, `Product_Name`, `Product_Price` or `Product.Name`), it extracts the prefix (`Product`).
2. **Auto-Instantiation (Lazy Allocation)**: If the target property (`Product`) is class-typed and currently `nil`, the hydrator **automatically instantiates it** on-the-fly using the optimized `TActivator` metadata cache.
3. **Recursive Value Binding**: It then routes the remaining path segments recursively (e.g., binding `Name` and `Price` directly to `FProduct.FName` and `FProduct.FPrice`).
4. **Infinite Depth Mapping**: Because Dext's `TReflection.SetValueByPath` is recursive, it can automatically map multi-level hierarchies (e.g. `Order_Customer_Address_City`) to any depth with zero manual configuration.

#### Performance & Safety
* **Zero GC Pressure**: Path parsing uses light stack-allocated buffers and in-place string indexing.
* **Property Interception**: Bypasses slow property setters by writing directly to the backing fields (resolved via RTTI cache) during hydration, preventing side-effects or dirty-tracking overhead.

---

## 5. Migrations System

Dext uses code-first migrations with chronological snapshots — same conceptual model as EF Core:

```
dotnet ef migrations add InitialCreate    →  dext migrations add InitialCreate
dotnet ef database update                 →  dext database update
```

**Additional capability**: Dext detects table and column renames via attributes, generating `RENAME TABLE` / `RENAME COLUMN` SQL instead of `DROP + CREATE`.

---

## 6. Soft Delete — `[SoftDelete]` Attribute

EF Core requires manual Global Query Filter setup for soft delete. Dext makes it declarative:

**EF Core (manual setup):**
```csharp
// Model configuration
modelBuilder.Entity<Task>().HasQueryFilter(t => !t.IsDeleted);

// Override SaveChanges
public override Task<int> SaveChangesAsync(...)
{
    foreach (var entry in ChangeTracker.Entries<Task>())
        if (entry.State == EntityState.Deleted)
        {
            entry.State = EntityState.Modified;
            entry.Entity.IsDeleted = true;
        }
    return base.SaveChangesAsync(...);
}
```

**Dext (fully declarative with optional timestamp tracking):**
```pascal
type
  [SoftDelete('IsDeleted')]
  TTask = class
  private
    FName: StringType;
    FIsDeleted: BoolType;
    FDeletedAt: DateTimeType;
  public
    property Name: StringType read FName write FName;
    property IsDeleted: BoolType read FIsDeleted write FIsDeleted;

    [DeletedAt]
    property DeletedAt: DateTimeType read FDeletedAt write FDeletedAt;
  end;
```

That's it. Dext automatically:
- Transforms `Remove()` into `UPDATE SET IsDeleted = TRUE` (and automatically stamps the current date/time on the `DeletedAt` property if decorated with the `[DeletedAt]` attribute).
- Filters deleted records out of all queries by default.
- Exposes `IgnoreQueryFilters`, `OnlyDeleted`, `HardDelete`, and `Restore`.
- Cleans the Identity Map after soft-deletion.

Supports custom values: `[SoftDelete('Status', 99, 0)]` — uses integer/enum status codes.

---

## 7. JSON Column Queries — `[JsonColumn]`

**EF Core (PostgreSQL):**
```csharp
// EF Core 7+ with PostgreSQL JSON support
var admins = db.Users
    .Where(u => EF.Functions.JsonExists(u.Settings, "role"))
    .ToList();
```

**Dext (cross-database):**
```pascal
var U: TUserType;
var Admins := Db.Users
  .Where(U.Settings.Json('role') = 'admin')
  .ToList;
```

Cross-database implementation:
- **PostgreSQL**: `settings #>> '{role}'` (JSONB indexed)
- **MySQL**: `JSON_UNQUOTE(JSON_EXTRACT(settings, '$.role'))`
- **SQLite**: `json_extract(settings, '$.role')`
- **SQL Server**: `JSON_VALUE(settings, '$.role')`

Nested paths work too: `U.Settings.Json('profile.details.level') = 5`

---

## 8. Multi-Tenancy — Built-in

Dext has a dedicated `Dext.MultiTenancy` module with **three isolation strategies**:

| Strategy | How It Works | Best For |
|:---|:---|:---|
| **Shared Database** | `TenantId` column discriminator — automatic filter | Small tenants, cost efficiency |
| **Schema Isolation** | PostgreSQL `search_path` switching per request | Medium tenants, logical isolation |
| **Database per Tenant** | Dynamic connection string per tenant | Enterprise, strict data isolation |

```pascal
Services.AddMultiTenancy
  .UseSharedDatabase  // or .UseSchemaIsolation or .UseDatabasePerTenant
  .WithTenantFromHeader('X-Tenant-Id');
```

---

## 9. Inheritance Mapping

**Table-Per-Hierarchy (TPH)** — full support with polymorphic hydration:

```pascal
type
  [Discriminator('Type')]
  TVehicle = class
    Name: StringType;
    [DiscriminatorValue('car')]
    // ...
  end;

  TCar = class(TVehicle)
    Doors: IntType;
  end;

  TTruck = class(TVehicle)
    Payload: FloatType;
  end;
```

---

## 10. Stored Procedures — Declarative Command Pattern

Executing Stored Procedures in modern enterprise systems is a common hot path, but it is notoriously painful in traditional ORMs.

### The Contrast

#### EF Core (Manual Parameter Binding & Rigid Mapping)
C# does not support dynamic object inference or dynamic query result mapping out-of-the-box in EF Core.
* If the procedure returns custom aggregates, you **must declare a DTO** and explicitly register it as a keyless entity in the `DbContext` (`modelBuilder.Entity<T>().HasNoKey()`).
* If the procedure has `OUT` or `INOUT` parameters, or returns multiple result sets, EF Core **forces you to drop down to pure ADO.NET boilerplate** (`DbCommand`, `DbDataReader`), instantiating manual `SqlParameter` objects and reading data row-by-row.

```csharp
// EF Core: Prone to magic string errors and requires manual parameter setup
var minPriceParam = new SqlParameter("@MinPrice", 100);
var result = await db.Database.ExecuteSqlRawAsync(
    "EXEC GetTopProducts @MinPrice", minPriceParam);
```

#### Dext (Declarative Command Pattern)
Dext wraps Stored Procedures using a cohesive **Command/CQRS Pattern**. While it requires defining a class, this class serves as a **compile-time checked architectural contract** that encapsulates all inputs, outputs, and projections.

```pascal
type
  [StoredProcedure('GetTopProducts')]
  TGetTopProducts = class
  private
    FMinPrice: Currency;
    FResults: IList<TProduct>;
  public
    [DbParam('MinPrice')]
    property MinPrice: Currency read FMinPrice write FMinPrice;

    // The query projection is auto-hydrated from the procedure's result set
    property Results: IList<TProduct> read FResults write FResults;
  end;

// Execution: Zero database boilerplate, zero loose parameter arrays
var Command := TGetTopProducts.Create;
Command.MinPrice := 100;
Db.Execute(Command); 
```

### Key Architectural Advantages of the Dext Approach

1. **Zero ADO.NET/FireDAC Leaks**: You never write low-level code to bind parameters, set database types, or open/close connection streams. Dext handles connection lifetime, parameter direction, and memory cleanup automatically.
2. **Cohesive Strongly-Typed Contract**: Inputs (`[DbParam]`), outputs (`out` parameters), and return datasets are structurally bound to the command object. This eliminates unsafe runtime arrays and type casting.
3. **CQRS Ready**: Perfectly aligns with *Command Query Responsibility Segregation* patterns. Each complex database operation is treated as an isolated, testable, and self-documenting command unit.
4. **Rich Projection Hydration**: The returned rows are automatically parsed and mapped to rich entity graphs or lightweight DTO lists using the optimized, RTTI-cached hydrator.

---

## 11. Exclusive Capabilities (Not in EF Core)

### 11.1 Database as API

**The most powerful feature of the Dext ORM.** Generate a full CRUD REST API from a single attribute — no controllers, no services, no repositories:

```pascal
type
  [Table, DataApi('/api/products')]
  TProduct = class
    Id: IntType;
    Name: StringType;
    Price: CurrencyType;
  end;

// In startup:
App.MapDataApis; // Done.
```

This generates **5 endpoints automatically**:

| Method | Route | Description |
|:---|:---|:---|
| `GET` | `/api/products` | List with pagination, sorting, and 11 filter operators |
| `GET` | `/api/products/{id}` | PK lookup (simple or composite) |
| `POST` | `/api/products` | Create — returns 201 |
| `PUT` | `/api/products/{id}` | Full update |
| `DELETE` | `/api/products/{id}` | Delete |

**URL Filter System (11 operators):**
```
GET /api/products?price_gt=100&name_cont=widget&_orderby=price+desc&_limit=20&_offset=0
```

Operators: `_eq`, `_neq`, `_gt`, `_gte`, `_lt`, `_lte`, `_cont` (LIKE %x%), `_sw`, `_ew`, `_in`, `_null`

**Granular Security:**
```pascal
App.MapDataApis.Configure<TProduct>(
  DataApiOptions
    .RequireAuth
    .RequireWriteRole(['admin'])
    .Allow([amGet, amGetList]) // Read-only for non-admins
    .UseSnakeCase
    .UseSwagger
);
```

---

### 11.2 EntityDataSet — ORM ↔ VCL/FMX Bridge

Connect legacy Delphi components (DBGrid, FastReport, TDBEdit) to rich Smart Property domains or standard POCO entity collections — with zero architecture compromise:

```pascal
EntityDataSet1.Collection := Db.Products.ToList; // Direct list (supports both POCO & Smart Properties)
```

**Live IDE Preview**: In design-time, provide a `TFDConnection` and `DataProvider`, and Dext generates dynamic SQL and displays real data in the DBGrid *without compiling the project*.

This has **no equivalent in the .NET ecosystem** — Windows Forms DataAdapter requires manual mapping, and there is no Visual Studio designer that previews ORM data live.

---

### 11.3 In-Memory Expression Evaluator

The same AST generated by `Prop<T>` can be evaluated against in-memory collections — without touching the database:

```pascal
var Filter := TExpressionEvaluator.Create;

// Same expression used for SQL query...
var SqlResult := Db.Products.Where(P.Price > 100).ToList;

// ...also filters an in-memory list:
var InMemoryResult := Filter.Evaluate(LocalCache, P.Price > 100);
```

EF Core does not expose an in-memory evaluator for the same expression tree used for SQL generation.

---

## 12. Performance Characteristics

| Benchmark | Dext | Notes |
|:---|:---|:---|
| **Route matching** | 10,000 routes in 47ms, zero heap allocations | Span<T>-based routing |
| **Dictionary lookup** | 6.6x faster than RTL | AVX2/SSE2 SIMD + Open Addressing |
| **Compile time** | 60% reduction vs standard generics | Binary Code Folding |
| **SSR memory** | O(1) for any record count | Flyweight streaming iterator |
| **JSON parsing** | Zero-allocation UTF-8 via TByteSpan | Direct field offset injection |

---

## 13. Multi-Database Test Matrix

The Dext ORM persistence engine is validated against a **real 5-database CI matrix** on every release:

| Database | Version Tested | Notes |
|:---|:---|:---|
| **PostgreSQL** | 14, 15, 16 | JSONB, UUID, `search_path` for schemas |
| **SQL Server** | 2019, 2022 | Window functions, TRY_CAST |
| **MySQL** | 8.0 | JSON_EXTRACT, LIMIT/OFFSET |
| **SQLite** | 3.x | In-process; json_extract |
| **Firebird** | 3.0, 4.0 | Legacy paging (ROWS/TO), SEQUENCE |

Oracle is supported in production but not included in the automated CI matrix.

## 14. High-Performance Engineering & Architecture Deep Dive

While functional capabilities are crucial, Dext's ultimate differentiator is **how these features are implemented** to achieve industrial-grade efficiency:
* **Binary Code Folding**: Prevents "Generic Bloom" in Delphi, reducing compile times by up to 60% and shrinking binary sizes.
* **SIMD-Accelerated Collections**: Vectorized AVX2/SSE2 lookups making `TRawDictionary` up to 6.6x faster than standard RTL dictionaries.
* **In-Memory Expression Evaluator**: Direct reuse of the ORM's `Prop<T>` AST to evaluate complex queries against standard in-memory lists with zero database trips.

For a comprehensive technical deep-dive into Dext's zero-allocation design, compiler optimizations, and low-level performance benchmarks, refer to the [Dext Framework Ecosystem Overview](https://github.com/dotpas/dext/blob/main/Docs/Dext_Ecosystem_Overview.md).

---

## 15. ORM Quick-Reference Summary

The table below covers the core ORM capabilities at a glance. For the full framework-wide comparison including web, DI, testing, and exclusive features, see the **[Feature Comparison Reference](./Feature_Comparison_Dext_vs_DotNet.md)**.

| ORM Capability | EF Core | Dext ORM | Dext Highlight |
|:---|:---:|:---:|:---|
| **DbContext / Unit of Work** | Yes | Yes | `TDbContext` - same UoW + Identity Map pattern |
| **Change Tracking (4 states)** | Yes | Yes | `Added / Modified / Deleted / Unchanged` |
| **Code-First Migrations** | Yes | Yes | Snapshot-based, chronological, with rename detection |
| **Lazy / Eager Loading** | Yes | Yes | `Include()` / `ThenInclude()` - same API |
| **Soft Delete** | Partial (manual filter) | Yes | `[SoftDelete]` + `[DeletedAt]` out of the box |
| **Multi-Tenancy** | Partial (query filter) | Yes | 3 strategies: Shared DB, Schema, DB-per-Tenant |
| **Pessimistic Locking** | No (raw SQL only) | Yes | `FOR UPDATE` integrated in the query engine |
| **JSON Column Queries** | Yes | Yes | `[JsonColumn]` + `.Json('path')` - cross-DB |
| **Inheritance TPH** | Yes | Yes | Polymorphic hydration via discriminator |
| **Inheritance TPT / TPC** | Yes | Partial | Roadmap |
| **Value Converters** | Yes | Yes | `TValueConverterRegistry` - 20+ built-in |
| **Stored Procedures** | Yes | Yes | `[StoredProcedure]` + `[DbParam]` - fully declarative |
| **Multi-Mapping (Dapper-style)** | No | Yes | `[Nested]` - recursive hydration via `_` / `.` separators |
| **Multi-Database Support** | Yes (NuGet) | Yes (7 native) | PostgreSQL, SQL Server, MySQL, SQLite, Oracle, Firebird, InterBase |
| **Type-Safe Query DSL** | Yes (LINQ) | Yes (`Prop<T>` AST) | Same AST reused for SQL, in-memory filter, and URL parsing |
| **Database as API** | No | Yes | `[DataApi]` - full CRUD REST API in 1 attribute |
| **EntityDataSet (VCL/FMX)** | No | Yes | POCO to DBGrid/FastReport bridge with design-time preview |
| **In-Memory Expression Evaluator** | No | Yes | Same `Prop<T>` AST filters in-memory `TList<T>` |
| **URL to Expression Parser** | No | Yes | `?price_gt=100` automatically converted to AST node |


## 16. Global Inspiration, Community Evolution: Beyond the Stock Paradigm

A central tenet of the Dext design philosophy is **"Inspired by the best, optimized for Delphi, driven by the community."** We do not view .NET or EF Core as rigid templates to copy line-for-line, nor do we limit our horizon to replication. Instead, we use them as baseline benchmarks while integrating the best paradigms from the entire global software engineering landscape.

### 1. Unified Out-of-the-Box Capabilities (The Third-Party Advantage)
When developers evaluate .NET, they often look at what is available in the entire NuGet ecosystem, not just the stock BCL (Base Class Library). Dext has taken a highly proactive approach by **natively implementing the most popular, standard, and critical third-party C# patterns** directly inside our core framework. This eliminates the dependency hell of managing external packages:
* **Object Mapping**: Natively built-in as `Dext.Mapper` (`TMapper`), inspired by the widely-used **AutoMapper** NuGet package.
* **Specification Pattern**: Natively built-in as `Dext.Specifications`, inspired by **Ardalis.Specification**.
* **Enterprise Event Bus & Pipeline Behaviors**: Natively built-in as `Dext.Events`, inspired by the industry-standard **MediatR** package.
* **Testing & Mocks**: Natively built-in assertion engines, TestCase combinations, and `TAutoMocker`, inspired by **FluentAssertions**, **NUnit**, and **Moq**.

### 2. A Polyglot Architecture: Borrowing from the Best
Dext actively incorporates architectural breakthroughs and developer-friendly patterns from multiple major ecosystems:
* **Go (Golang)**: We adapted the ultra-lightweight, high-throughput **Channel pattern** (`TChannel<T>`) and the deterministic **Defer pattern** (`IDeferred`/`TDeferredAction`) to bring clean, zero-leak resource management and powerful backpressure-aware concurrency to Delphi.
* **Flutter & Dart**: We drew inspiration from Dart's compile-time safety paradigms, asynchronous ergonomics, and modern UI-reactive bindings to optimize how our visual VCL/FMX `EntityDataSet` behaves under active design-time changes.
* **Java & Spring Boot**: We studied Spring Boot's clean IoC/DI container ergonomics and declarative attribute bindings to craft Dext's highly intuitive dependency injection and annotation-based routing mechanisms.
* **Python & JavaScript/TypeScript**: We looked at the extreme developer ergonomics and simple setups of fast web frameworks like FastAPI and Hono to implement our native **HTMX auto-detection** and zero-boilerplate **Database as API** (`[DataApi]`) configurations.

### 3. Open to Continuous, Community-Driven Growth
Software frameworks are living systems. If a developer notices that a specific, highly-specialized feature "N" is missing from Dext's stock offering, we do not view this as a permanent constraint:
* **Adaptive Feature Roadmap**: Our design architecture is intentionally modular and decoupled. Adding new capabilities, database dialects, custom converters, or middleware handlers is simple and clean.
* **Open to Contributions**: We are committed to evolving Dext in close collaboration with the enterprise Delphi community. If your production environment requires a specialized architectural pattern or a specific data-access driver, the Dext team and community are fully equipped to build, review, and integrate it.
* **Modernizing Delphi Together**: Dext is engineered to prove that Delphi developers do not have to compromise. You can have compiled, zero-dependency, ultra-fast native binaries while enjoying the most modern, elegant, and powerful software architecture patterns on the planet.

---

*Dext Framework — ORM Capabilities Reference | May 2026*

