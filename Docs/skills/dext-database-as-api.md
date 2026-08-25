---
name: dext-database-as-api
description: Expose full REST CRUD endpoints automatically from Dext ORM entities with zero boilerplate using MapDataApi. Use when you need instant GET/POST/PUT/DELETE for an entity without writing controllers or services.
---

# Dext Database as API (Zero-Code CRUD)

Generate a complete REST API for an entity with a single line. No controller, no service, no repository needed.

## Core Import

```pascal
uses
  Dext.Web, Dext.Web.DataApi;
```

> 📦 Example: `Web.DatabaseAsApi`

## Quick Start

```pascal
// Entity
type
  [Table('products')]
  TProduct = class
  public
    [PK, AutoInc]
    property Id: Integer;
    [Required, MaxLength(100)]
    property Name: string;
    property Price: Double;
    property Stock: Integer;
  end;

// In Startup Configure — maps all 5 CRUD endpoints
App.Builder.MapDataApi<TProduct>('/api/products', 
  DataApiOptions
    .DbContext<TAppDbContext>
    .UseSwagger
    .Tag('Products')
);
```

## Generated Endpoints

| HTTP | URL | Description |
|------|-----|-------------|
| `GET` | `/api/products` | List all (pagination + filters) |
| `GET` | `/api/products/{id}` | Find by ID |
| `POST` | `/api/products` | Create new record |
| `PUT` | `/api/products/{id}` | Update existing record |
| `DELETE` | `/api/products/{id}` | Delete record |

## Query Parameters (Auto-Supported)

### Pagination & Ordering

```
GET /api/products?_limit=20&_offset=40
GET /api/products?_orderby=Price desc,Name asc
```

`_limit` is capped by **MaxPageSize** (default **100**). Configure with `.MaxPageSize(N)` on `DataApiOptions`; `0` disables the cap.

### Filtering (Dynamic Specification)

Filters are applied using property names suffixed with operators:

| Suffix | SQL Operator | Example | Description |
| ------ | ------------ | ------- | ----------- |
| `_eq` | `=` | `?Status_eq=1` | Equal to (default) |
| `_neq` | `<>` | `?Type_neq=2` | Not equal to |
| `_gt` | `>` | `?Price_gt=50` | Greater than |
| `_gte` | `>=` | `?Age_gte=18` | Greater or equal |
| `_lt` | `<` | `?Stock_lt=5` | Less than |
| `_lte` | `<=` | `?Date_lte=2025-01-01` | Less or equal |
| `_cont` | `LIKE %x%` | `?Name_cont=Dext` | Contains |
| `_sw` | `LIKE x%` | `?Code_sw=ABC` | Starts with |
| `_ew` | `LIKE %x` | `?Mail_ew=gmail.com` | Ends with |
| `_in` | `IN (...)` | `?Category_in=1,2,5` | List of values |

## Performance: Zero-Allocation Streaming

A key differentiator of Dext's Data API is its **high-performance JSON engine**. Unlike traditional approaches that load all data into memory and then serialize it to strings, Dext uses a **streaming approach**:

1. **Direct Streaming**: Uses `TUtf8JsonWriter` to write data directly into the response stream.
2. **Binary Integration**: Reads values straight from the database driver and writes them to the wire without intermediate string allocations for large datasets.
3. **Low Memory Footprint**: This architecture allows serving large datasets with minimal memory impact, crucial for high-traffic environments.

## Restricting Operations

```pascal
App.Builder.MapDataApi<TProduct>('/api/products',
  DataApiOptions
    .DbContext<TAppDbContext>
    .ConfigureEndpoints(procedure(Endpoints: IDataApiEndpointConfig)
    begin
      Endpoints.GET.Authorize('Admin');
      Endpoints.DELETE.Disable;
    end)
);
```

## Direct SQL UTF-8 Streaming (`UseSql`)

For maximum performance Data APIs (bypassing entity hydration and JSON AST creation):

```pascal
App.MapFast('GET', '/api/cities/fast', procedure(const Req: IHttpRequest; const Res: IHttpResponse)
begin
  Db.UseSql('SELECT Id, Name, State FROM Cities')
    .ExecuteToUtf8Stream(Res.GetOutputStream);
end);
```

Available operations (`TApiMethod`): `amGet`, `amGetList`, `amPost`, `amPut`, `amDelete`.

## Multiple Entities

```pascal
App.Builder
  .UseExceptionHandler
  .UseAuthentication
  .MapDataApi<TProduct>('/api/products', DataApiOptions.DbContext<TAppDbContext>)
  .MapDataApi<TCategory>('/api/categories', DataApiOptions.DbContext<TAppDbContext>)
  .MapDataApi<TOrder>('/api/orders',
    DataApiOptions
      .DbContext<TAppDbContext>
      .Allow([amGet, amGetList]) // Read-only
      .RequireAuth
  )
  .UseSwagger(...);
```

## When to Use vs When to Write a Controller

| Use `MapDataApi` | Write a Controller/Service |
| ---------------- | -------------------------- |
| Simple CRUD for internal/admin tools | Complex business logic on save/delete |
| Rapid prototyping | Validation beyond ORM attributes |
| Read-only data exposure | Custom response shapes |
| Admin dashboards | Multi-entity transactions |

