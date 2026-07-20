# Querying

Fluent query API for retrieving data.

## Return Types: IList\<T\>

> [!IMPORTANT]
> Dext uses `IList<T>` from `Dext.Collections`, not `TObjectList<T>` from `System.Generics.Collections`.

```pascal
uses
  Dext.Collections;

var Users: IList<TUser>;
begin
  Users := Context.Users.ToList;  // Returns IList<TUser>
  
  for var User in Users do
    WriteLn(User.Name);
end;
```

### Creating New Lists

Use the `TCollections.CreateList<T>` factory:

```pascal
// Create a new list
var MyList := TCollections.CreateList<TUser>;
MyList.Add(User1);
MyList.Add(User2);

// Create with ownership (auto-free objects)
var OwnedList := TCollections.CreateList<TUser>(True);
```

> [!TIP]
> `IList<T>` is an interface, so no `try/finally Free` is needed!

## Basic Queries

### Get All

```pascal
var Users := Context.Users.ToList;
```

### Find by ID

```pascal
var User := Context.Users.Find(1);
if User <> nil then
  WriteLn('Found: ', User.Name);
```

### First / FirstOrDefault

```pascal
// Throws if not found
var User := Context.Users.First;

// Returns nil if not found
var User := Context.Users.FirstOrDefault;
```

## Filtering (Where)

### Smart Properties (Recommended)

Use `var` inline for Props (simulating C# lambda variables):

```pascal
// ✅ CORRECT: var inline camelCase, close to usage scope
var u := TUser.Props;
var ActiveUsers := Context.Users
  .Where(u.IsActive = True)
  .ToList;

// Multiple conditions
var Results := Context.Users
  .Where((u.Age >= 18) and (u.Status = 'active'))
  .ToList;
```

> [!IMPORTANT]
> **Why camelCase?** To differentiate from PascalCase method variables.  
> In multi-table queries with Include/Join, each table has its own inline var (`var u`, `var o`, `var p`).

```pascal
// ❌ WRONG: Verbose, repeats TUser.Props for every field
ExistingUser := Context.Users
  .Where((TUser.Props.Email = Email) and
         (TUser.Props.Status <> usDeleted))
  .FirstOrDefault;

// ✅ CORRECT: var inline, concise
var u := TUser.Props;
ExistingUser := Context.Users
  .Where((u.Email = Email) and (u.Status <> usDeleted))
  .FirstOrDefault;
```

### Lambda Expression (Prototype)

```pascal
var u := Prototype.Entity<TUser>;
var ActiveUsers := Context.Users
  .Where(u.IsActive)
  .ToList;
```

## Ordering

> [!WARNING]
> `OrderBy` requires `.Asc` or `.Desc` — passing a Prop directly causes `E2010 Incompatible types`.

```pascal
var u := TUser.Props;

// Ascending
var Users := Context.Users
  .QueryAll
  .OrderBy(u.Name.Asc)
  .ToList;

// Descending
var Users := Context.Users
  .QueryAll
  .OrderBy(u.CreatedAt.Desc)
  .ToList;

// Multiple columns
var Users := Context.Users
  .QueryAll
  .OrderBy(u.LastName.Asc)
  .OrderBy(u.FirstName.Asc)
  .ToList;
```

```pascal
// ❌ WRONG: Causes E2010
.OrderBy(TUser.Props.CreatedAt)

// ✅ CORRECT: Use .Asc or .Desc
var u := TUser.Props;
.OrderBy(u.CreatedAt.Asc)
.OrderBy(u.CreatedAt.Desc)
```

## Pagination

```pascal
var u := TUser.Props;
var Page := Context.Users
  .QueryAll
  .OrderBy(u.Id.Asc)
  .Skip(20)   // Skip first 20
  .Take(10)   // Take next 10
  .ToList;
```

## No Tracking Queries (Performance)

Use `.AsNoTracking` for **Read-Only** scenarios. This returns objects without adding them to the `IdentityMap` or `ChangeTracker`, resulting in ~30-50% better performance and lower memory usage.

> [!IMPORTANT]
> **Memory Management & Lifetime**: In Tracked mode (default), the `DbContext` `IdentityMap` owns the entity instances. When the `DbContext` is disposed (`Db.Free`), tracked entities are destroyed. To return entities that must survive past `DbContext` disposal (e.g. from domain services to controllers/views), use `.AsNoTracking.ToList`. In No Tracking mode, the returned `IList<T>` **owns** the objects and keeps them alive until the list goes out of scope.

```pascal
// Ideal for APIs and Reports passing entities beyond DbContext scope
var Users := Context.Users
  .AsNoTracking
  .Where(u.IsActive = True)
  .ToList; // Objects will be freed when Users is released
```


## Projection (Select)

```pascal
type
  TUserDto = record
    Name: string;
    Email: string;
  end;

var u := Prototype.Entity<TUser>;
var Dtos := Context.Users
  .Select<TUserDto>([u.Name, u.Email])
  .ToList;
```

## Aggregates

```pascal
var u := TUser.Props;

// Count
var Total := Context.Users.Count;
var ActiveCount := Context.Users
  .Where(u.IsActive = True)
  .Count;

// Any / Exists (preferred for seeder checks)
var HasAdmin := Context.Users
  .Where(u.Role = 'admin')
  .Any;
```

## Custom Types (Enums)

If a specific type (like an Enum) doesn't have a pre-defined alias, create one using `Prop<T>`:

```pascal
type
  StatusType = Prop<TOrderStatus>;  // Custom smart type
```

Use in queries:

```pascal
var o := TOrder.Props;
var PaidOrders := Context.Orders
  .Where(o.Status = osPaid)
  .OrderBy(o.Total.Desc)
  .ToList;
```

## Ghost Entities (Prototype)

Use `Prototype.Entity<T>` from `Dext.Entity.Prototype` for type-safe metadata in queries:

```pascal
var p := Prototype.Entity<TProduct>;
var Expensive := Context.Products
  .Where(p.Price > 100)
  .ToList;
```

## Query Execution

Queries are lazy — executed only when you:

| Method | Effect |
|--------|--------|
| `.ToList` | Execute and return list |
| `.First` / `.FirstOrDefault` | Execute and return one |
| `.Count` | Execute and return count |
| `.Any` | Execute and return boolean |
| `.Find(id)` | Execute and return by PK |

```pascal
// Query executed HERE
var Users := Query.ToList;
```

## Advanced Querying (Joins & Grouping)

For complex scenarios, use specification typing and explicit joins.

### SQL Join (`Join(table, alias, joinType, condition)`)

Use the SQL-oriented join overload when you want the join translated to SQL by the provider.

```pascal
var u := TUser.Props;
var Users := Context.Users
  .AsNoTracking
  // Qualified predicate in ON clause:
  // users.address_id = a.id
  .Join('addresses', 'a', jtInner, Prop('users.address_id') = Prop('a.id'))
  .Where(u.Age >= 18)
  .OrderBy(u.Id.Asc)
  .ToList;
```

> [!IMPORTANT]
> You can provide the join condition as:
> - `IExpression` (strict/typed path), or
> - simple string `"left = right"` (helper parser).
>
> For both forms, use qualified column/property names in the ON predicate
> (for example: `users.address_id`, `a.id`).

### Strongly-Typed Fluent Joins

Dext Entity supports advanced, strongly-typed fluent joins that run entirely at the database provider level. These operations compile directly into optimized SQL joins (INNER, LEFT, RIGHT, FULL, CROSS).

There are three main ways to write fluent joins:

#### 1. Explicit Condition Joins
Specify the tables, aliases, and explicit ON condition using Smart Properties:
```pascal
var u := TUser.Props;
var a := TAddress.Props;

var Results := Context.Users
  .JoinLeft<TAddress>('u', 'a', u.AddressId = a.Id)
  .Where(u.Age >= 18)
  .ToList;
```

#### 2. Implicit Relationship Auto-Joins
If the relationship is defined in your `TModelBuilder` configuration (e.g. HasOne/HasMany), Dext resolves the ON condition automatically from entity metadata:
```pascal
var u := TUser.Props;

// Automatically resolves to: ON u.AddressId = a.Id
var Results := Context.Users
  .JoinInner<TAddress>
  .Where(u.Age >= 18)
  .ToList;
```

#### 3. Cross Joins (No ON condition)
Generate a Cartesian product between two tables without an ON clause:
```pascal
var Results := Context.Users
  .JoinCross<TDepartment>
  .ToList;
```

Available strongly-typed fluent join methods:
- `JoinInner<TInner>` (auto-resolved ON) or `JoinInner<TInner>(AliasOuter, AliasInner, Condition)`
- `JoinLeft<TInner>` (auto-resolved ON) or `JoinLeft<TInner>(AliasOuter, AliasInner, Condition)`
- `JoinRight<TInner>` (auto-resolved ON) or `JoinRight<TInner>(AliasOuter, AliasInner, Condition)`
- `JoinFull<TInner>` (auto-resolved ON) or `JoinFull<TInner>(AliasOuter, AliasInner, Condition)`
- `JoinCross<TInner>` (no ON condition) or `JoinCross<TInner>(AliasOuter, AliasInner)`

### Generic Join (`Join<TInner, TKey, TResult>`)

Use this overload for projection/correlation scenarios where in-memory composition is acceptable:

```pascal
var Joined := Context.Users
  .AsNoTracking
  .Join<TAddress, Integer, string>(
    Context.Addresses.AsNoTracking,
    'AddressId',
    'Id',
    function(U: TUser; A: TAddress): string
    begin
      Result := U.Name + ' @ ' + A.City;
    end
  )
  .ToList;
```

> [!WARNING]
> `Join<TInner, TKey, TResult>` materializes outer and inner sequences and correlates them in memory.  
> It is **not** a drop-in replacement for SQL joins at scale.

> [!TIP]
> See runnable examples in:
> `Examples/03-Data/Orm.EntityDemo/EntityDemo.Tests.Join.pas`

### Group By & Having

Aggregate data and filter grouped results.

```pascal
var Stats := Context.Orders
  .GroupBy('CustomerId')
  .Having(TOrder.Props.Total.Sum > 1000)
  .Select(['CustomerId', 'Total.Sum'])
  .ToList;
```


## Performance & Caching

### SQL Generation Cache

Dext includes a singleton `TSQLCache` that caches the generated SQL for queries based on their structure (AST Signature). This significantly improves performance for repetitive queries by skipping the SQL generation phase.

The cache is **enabled by default** and is thread-safe.

#### Disabling the Cache

If you need to disable caching (e.g., for debugging or specific dynamic scenarios), you can toggle it globally:

```pascal
uses
  Dext.Entity.Cache;

// Disable globally
TSQLCache.Instance.Enabled := False;
```

---

[← Entities](entities.md) | [Next: Smart Properties →](smart-properties.md)
