# Model Binding

Automatically convert HTTP requests to Delphi objects from multiple sources: JSON body, headers, query parameters, and route parameters.

> 📦 **Examples**: 
> - [Web.MinimalAPI](../../../Examples/Web.MinimalAPI/)
> - [Multi-Tenancy](../../../Examples/Dext.Examples.MultiTenancy/)

## Overview

Model Binding in Dext supports binding data from:

| Source | Attribute | Example |
|--------|-----------|---------|
| JSON Body | `[FromBody]` (default for POST/PUT) | Request payload |
| Headers | `[FromHeader('X-Header')]` | API keys, tenant IDs |
| Query String | `[FromQuery('param')]` | `?search=...&page=1` |
| Route Parameters | `[FromRoute('id')]` | `/users/{id}` |
| Services (DI) | `[FromServices]` | Injected services |

## Basic JSON Body Binding

### Records (Recommended)

```pascal
type
  TCreateUserRequest = record
    Name: string;
    Email: string;
    Age: Integer;
  end;

// Minimal API - automatic binding
App.MapPost<TCreateUserRequest, IResult>('/users',
  function(Request: TCreateUserRequest): IResult
  begin
    // Request is automatically populated from JSON body
    Result := Results.Created('/users/1', Request);
  end);
```

### Controller Style

```pascal
App.MapPost('/users', procedure(Ctx: IHttpContext)
  var
    Request: TCreateUserRequest;
  begin
    Request := Ctx.Request.BindBody<TCreateUserRequest>;
    // Use Request.Name, Request.Email, Request.Age
  end);
```

## Header Binding

Use `[FromHeader]` for API keys, tenant IDs, or any custom header:

```pascal
type
  TTenantRequest = record
    [FromHeader('X-Tenant-Id')]
    TenantId: string;
    [FromHeader('Authorization')]
    Token: string;
  end;

App.MapGet<TTenantRequest, IResult>('/api/data',
  function(Request: TTenantRequest): IResult
  begin
    if Request.TenantId = '' then
      Exit(Results.BadRequest('X-Tenant-Id header is required'));
      
    Result := Results.Ok(Format('Tenant: %s', [Request.TenantId]));
  end);
```

**Request:**
```bash
curl -H "X-Tenant-Id: acme-corp" \
     -H "Authorization: Bearer token123" \
     http://localhost:8080/api/data
```

## Query Parameter Binding

Use `[FromQuery]` for URL query parameters:

```pascal
type
  TSearchRequest = record
    [FromQuery('q')]
    Query: string;
    [FromQuery('page')]
    Page: Integer;
    [FromQuery('limit')]
    Limit: Integer;
  end;

App.MapGet<TSearchRequest, IResult>('/search',
  function(Request: TSearchRequest): IResult
  begin
    Result := Results.Ok(Format('Search: %s, Page: %d', 
      [Request.Query, Request.Page]));
  end);
```

**Request:**
```bash
curl "http://localhost:8080/search?q=delphi&page=1&limit=20"
```

## Route Parameter Binding

Use `[FromRoute]` for URL path parameters:

```pascal
type
  TRouteRequest = record
    [FromRoute('id')]
    Id: Integer;
    [FromRoute('category')]
    Category: string;
  end;

App.MapGet<TRouteRequest, IResult>('/products/{id}/category/{category}',
  function(Request: TRouteRequest): IResult
  begin
    Result := Results.Ok(Format('Product %d in %s', 
      [Request.Id, Request.Category]));
  end);
```

**Request:**
```bash
curl http://localhost:8080/products/42/category/electronics
```

## Mixed Binding (Multiple Sources)

The most powerful feature: combine data from different sources in a single record.

### Header + Body (Multi-Tenancy Pattern)

```pascal
type
  TProductCreateRequest = record
    // From HTTP header
    [FromHeader('X-Tenant-Id')]
    TenantId: string;
    
    // From JSON body (no attribute = default to body)
    Name: string;
    Description: string;
    Price: Currency;
    Stock: Integer;
  end;

App.MapPost<IProductService, TProductCreateRequest, IResult>('/api/products',
  function(Service: IProductService; Request: TProductCreateRequest): IResult
  begin
    // TenantId comes from header
    // Name, Description, Price, Stock come from JSON body
    
    if Request.TenantId = '' then
      Exit(Results.BadRequest('X-Tenant-Id header is required'));
      
    var Product := Service.Create(Request);
    Result := Results.Created('/api/products/' + IntToStr(Product.Id), Product);
  end);
```

**Request:**
```bash
curl -X POST http://localhost:8080/api/products \
     -H "X-Tenant-Id: acme-corp" \
     -H "Content-Type: application/json" \
     -d '{"name": "Widget Pro", "description": "A great widget", "price": 99.99, "stock": 100}'
```

### Route + Body (Update Pattern)

```pascal
type
  TProductUpdateRequest = record
    [FromRoute('id')]
    Id: Integer;
    
    // From JSON body
    Name: string;
    Price: Currency;
  end;

App.MapPut<TProductUpdateRequest, IResult>('/api/products/{id}',
  function(Request: TProductUpdateRequest): IResult
  begin
    // Id comes from URL path
    // Name and Price come from JSON body
    Result := Results.Ok(Format('Updated product %d', [Request.Id]));
  end);
```

### Route + Query (Filter Pattern)

```pascal
type
  TProductFilterRequest = record
    [FromRoute('category')]
    Category: string;
    [FromQuery('sort')]
    Sort: string;
    [FromQuery('page')]
    Page: Integer;
  end;

App.MapGet<TProductFilterRequest, IResult>('/api/products/{category}',
  function(Request: TProductFilterRequest): IResult
  begin
    Result := Results.Ok(Format('Category: %s, Sort: %s, Page: %d',
      [Request.Category, Request.Sort, Request.Page]));
  end);
```

### All Sources Combined

```pascal
type
  TFullRequest = record
    [FromHeader('X-Api-Key')]
    ApiKey: string;
    [FromRoute('id')]
    ResourceId: Integer;
    [FromQuery('include')]
    Include: string;
    // Body fields (default)
    Data: string;
    Count: Integer;
  end;

App.MapPut<TFullRequest, IResult>('/api/resources/{id}',
  function(Request: TFullRequest): IResult
  begin
    // ApiKey from header
    // ResourceId from route /api/resources/123
    // Include from query ?include=details
    // Data and Count from JSON body
    Result := Results.Ok('All binding sources used!');
  end);
```

## Binding Priority (Without Explicit Attributes)

When a field has no explicit binding attribute, Dext uses smart fallback:

1. **JSON Body** - First tries to find the field in the request body
2. **Route Parameters** - If not in body, checks route params (for IDs)
3. **Query Parameters** - Finally checks query string

This allows fields like `Id` to be automatically bound from the URL without explicit `[FromRoute]`.

## Case Sensitivity

JSON field matching is case-insensitive. All these JSON formats work:

```json
{"name": "John", "email": "john@example.com"}
{"Name": "John", "Email": "john@example.com"}
{"NAME": "John", "EMAIL": "john@example.com"}
```

## Type Conversion

Automatic conversion for common types:

| Type | Example Values |
|------|---------------|
| `string` | Any text |
| `Integer` | `123`, `-456` |
| `Int64` | Large numbers |
| `Double` | `99.99`, `-0.5` |
| `Currency` | `1234.56` |
| `Boolean` | `true`, `false`, `1`, `0` |
| `TDateTime` | ISO 8601 format |
| `TGUID` | `{UUID-FORMAT}` |
| `TUUID` | UUID string |

## Controller Parameter Binding

In controllers, use attributes directly on method parameters:

```pascal
[HttpGet('/users/{id}')]
function GetById(
  [FromRoute] Id: Integer;
  [FromHeader('Authorization')] Token: string
): IActionResult;

[HttpPost('/users')]
function Create([FromBody] Request: TCreateUserRequest): IActionResult;

[HttpGet('/search')]
function Search(
  [FromQuery] Q: string;
  [FromQuery] Page: Integer;
  [FromQuery] Limit: Integer
): IActionResult;
```

## Nested Objects

```pascal
type
  TAddress = record
    Street: string;
    City: string;
    ZipCode: string;
  end;
  
  TCreateUserRequest = record
    Name: string;
    Address: TAddress;  // Nested!
  end;
```

JSON:
```json
{
  "name": "John",
  "address": {
    "street": "123 Main St",
    "city": "New York",
    "zipCode": "10001"
  }
}
```

## Arrays

```pascal
type
  TBulkCreateRequest = record
    Users: TArray<TCreateUserRequest>;
  end;
```

JSON:
```json
{
  "users": [
    {"name": "John", "email": "john@example.com"},
    {"name": "Jane", "email": "jane@example.com"}
  ]
}
```

## Handling Malformed Payloads

If a JSON payload bound to a dynamic array (`TArray<T>`) or a primitive parameter is structurally malformed (e.g., missing brackets or other JSON syntax errors), Dext's Model Binder raises an `EBindingException` instead of swallowing the error. 

This results in an automatic HTTP `400 Bad Request` response detailing the parser error, improving diagnostics for API clients sending invalid payloads.

## Best Practices

1. **Use Records** for request DTOs (value types, no memory management)
2. **Be Explicit** with attributes when mixing sources
3. **Validate Required Headers** in your handler code
4. **Use `[FromHeader]`** for tenant IDs, API keys, correlation IDs
5. **Use `[FromQuery]`** for filters, pagination, sorting
6. **Use `[FromRoute]`** for resource identifiers

## Automatic Memory Management for Classes

When using **class-based DTOs** instead of records, the framework automatically frees the object after handler execution:

```pascal
type
  TCreateOrderDto = class
  public
    Items: IList<TOrderItemDto>;
  end;

// The framework automatically frees Dto after the handler returns
Builder.MapPost<TCreateOrderDto, IResult>('/api/orders',
  function(Dto: TCreateOrderDto): IResult
  begin
    // Use Dto normally
    // DO NOT call Dto.Free - the framework handles it!
    Result := Results.Created('/api/orders/1', Dto);
  end);
```

> [!NOTE]
> This follows the "creator destroys" principle: Model Binding creates the object, so it's responsible for cleaning it up.

---

[← Controllers](controllers.md) | [Next: Routing →](routing.md)
