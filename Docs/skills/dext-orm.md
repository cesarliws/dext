---
name: dext-orm
description: Use the Dext ORM — define entities, create DbContext, query data with Smart Properties, and handle CRUD operations.
---

# Dext ORM

## Uses Clause Order (CRITICAL)

Delphi only supports one class helper for a given type at a time. To ensure all framework features (Minimal APIs, Routing, Web Helpers) are available, the `uses` order **MUST** be:

1. `Dext`
2. `Dext.Entity` (if using ORM)
3. `Dext.Web` (**LAST**)

```pascal
uses
  System.SysUtils,
  Dext,              // Base
  Dext.Entity,       // ORM Attributes & Facade
  Dext.Web;          // Web Helpers (Last)
```

## Core Imports

```pascal
uses
  Dext.Entity,          // Attributes Facade
  Dext.Entity.Core,     // IDbSet<T>, TDbContext
  Dext.Core.SmartTypes, // IntType, StringType (Mandatory)
  Dext.Collections;     // IList<T>
```

> [!IMPORTANT]
> Use `Dext.Entity` facade for attributes — **NOT** `Dext.Entity.Attributes` directly.

## 1. Define an Entity

Use **Properties**, not public fields. Dext relies on Delphi RTTI properties for metadata discovery. Always map entities using the appropriate Dext attributes.

### 1.1. Core Imports & Uses Clause
For any unit containing Dext ORM entities, the following `uses` clause is required:
```pascal
uses
  System.SysUtils,
  System.Classes,
  Dext.Entity,              // Attributes facade (Table, Column, PK, FK, etc.)
  Dext.Entity.Collections,  // For collections like IEntityCollection<T>
  Dext.Types.Nullable,      // For Nullable<T> and Prop<Nullable<T>>
  Dext.Types.Lazy,          // For lazy loading ILazy<T> and TValueLazy<T>
  Dext.Core.SmartTypes;     // For Smart Properties (IntType, StringType, etc.)
```

### 1.2. Complete Mapping Example
Here is a complete example of an entity showing primary keys, columns, nullable fields, smart properties, and relationships:

```pascal
type
  TOrder = class; // Forward declaration

  [Table('users')]
  TUser = class
  private
    FId: IntType;
    FName: StringType;
    FEmail: StringType;
    FOrders: ILazy<TList<TOrder>>;
    function GetOrders: TList<TOrder>;
  public
    [PK, AutoInc]
    property Id: IntType read FId write FId;

    [Required, MaxLength(100)]
    property Name: StringType read FName write FName;

    [Required, MaxLength(200), Column('user_email')]
    property Email: StringType read FEmail write FEmail;

    // One-to-Many Relationship (HasMany)
    [InverseProperty('User'), HasMany]
    property Orders: TList<TOrder> read GetOrders;
  end;

  [Table('orders')]
  TOrder = class
  private
    FId: IntType;
    FUserId: IntType;
    FUser: ILazy<TUser>;
    FTotal: DoubleType;
    function GetUser: TUser;
    procedure SetUser(const Value: TUser);
  public
    [PK, AutoInc]
    property Id: IntType read FId write FId;

    [Required]
    property UserId: IntType read FUserId write FUserId;

    [Required]
    property Total: DoubleType read FTotal write FTotal;

    // Many-to-One Navigation Property (BelongsTo)
    [ForeignKey('user_id'), BelongsTo]
    property User: TUser read GetUser write SetUser;
  end;

implementation

{ TUser }
function TUser.GetOrders: TList<TOrder>;
begin
  if FOrders = nil then FOrders := TLazy<TList<TOrder>>.Create;
  Result := FOrders.Value;
end;

{ TOrder }
function TOrder.GetUser: TUser;
begin
  if FUser <> nil then
    Result := FUser.Value
  else
    Result := nil;
end;

procedure TOrder.SetUser(const Value: TUser);
begin
  FUser := TValueLazy<TUser>.Create(Value);
  if Value <> nil then
    FUserId := Value.Id;
end;
```

### 1.3. Smart Properties
Always use native Smart Property aliases (**IntType**, **StringType**, **DoubleType**, **BoolType** from `Dext.Core.SmartTypes`) for class properties to enable automatic model binding and type-safe filtering.

### 1.4. Available Mapping Attributes

| Category | Attribute | Target | Description |
| :--- | :--- | :--- | :--- |
| **Class Mapping** | `[Table('name')]` | Class | Map class to specific table |
| | `[Schema('name')]` | Class | Specify database schema |
| | `[Inheritance(TInheritanceStrategy)]` | Class | Set inheritance strategy (`TablePerHierarchy`, `TablePerType`) |
| | `[DiscriminatorColumn('name')]` | Class | Column name for TPH discriminator |
| | `[DiscriminatorValue(Value)]` | Class | Value representing this class in TPH |
| **Field/Prop Mapping** | `[Column('name')]` | Property | Map property to specific column |
| | `[PK]` or `[PrimaryKey]` | Property | Primary Key (supports composite PKs) |
| | `[AutoInc]` | Property | Auto-incrementing integer PK |
| | `[Sequence('name', alloc)]` | Property | Primary Key pre-allocation via Database Sequence generator (HiLo) |
| | `[Required]` | Property | NOT NULL constraint |
| | `[MaxLength(N)]` | Property | Max string/array length |
| | `[MinLength(N)]` | Property | Min string/array length |
| | `[Precision(P, S)]` | Property | Numeric precision and scale |
| | `[DefaultValue(Val)]` | Property | Default value when DB returns NULL |
| | `[NotMapped]` | Property | Exclude from mapping and JSON serialization |
| | `[JsonColumn]` | Property | Marks field as JSON/JSONB column |
| | `[TypeConverter(Class)]`| Property | Map custom type converter class |
| **Audit & Concurrency** | `[CreatedAt]` | Property | Timestamp set automatically on INSERT |
| | `[UpdatedAt]` | Property | Timestamp set automatically on INSERT/UPDATE |
| | `[Version]` | Property | Optimistic concurrency version column (Integer) |
| | `[SoftDelete('Col')]` | Class | Enable soft delete mapping |
| | `[DeletedAt]` | Property | Soft delete timestamp |
| **Relationships** | `[ForeignKey('col')]` | Property | Define foreign key column name |
| | `[BelongsTo]` | Property | Many-to-One relationship |
| | `[HasMany]` | Property | One-to-Many relationship (Collection) |
| | `[HasOne]` | Property | One-to-One relationship |
| | `[ManyToMany('tbl', 'c1', 'c2')]` | Property | Many-to-Many relationship with join table |
| | `[InverseProperty('prop')]` | Property | Specify navigation property on the other side |

---

## 2. Nullable Columns

Database columns can be `NULL`. Dext provides two options to represent nullable values depending on whether you are using standard fields or Smart Properties:

### 2.1. Standard Nullable Fields (`Nullable<T>`)
Use `Nullable<T>` (from `Dext.Types.Nullable`) for standard columns where query-mode expression trees are not needed:

```pascal
type
  TTicket = class
  private
    FAssigneeId: Nullable<Integer>;
  public
    [ForeignKey('Assignee')]
    property AssigneeId: Nullable<Integer> read FAssigneeId write FAssigneeId;
  end;

// Usage
Ticket.AssigneeId := 10;                     // Implicit assign
Ticket.AssigneeId := Nullable<Integer>.Null; // Set to NULL
```

### 2.2. Nullable Smart Properties (`Prop<Nullable<T>>`)
If you need **Smart Properties** for a nullable column (to query with `.Where` or `.OrderBy`), you **MUST** use composition: `Prop<Nullable<T>>`:

```pascal
type
  TUser = class
  private
    FMiddleName: Prop<Nullable<string>>;
  public
    property MiddleName: Prop<Nullable<string>> read FMiddleName write FMiddleName;
  end;

// Usage & Querying
var u := Prototype.Entity<TUser>;
var Results := Db.Users
  .Where(u.MiddleName.IsNull)
  .ToList;
```

> [!WARNING]
> **NEVER** declare properties as `Nullable<Prop<T>>` (e.g., `Nullable<StringType>`). This legacy pattern is deprecated, triggers runtime warning logs, and causes query ordering (`OrderBy`) issues due to Delphi's limitations on nesting implicit operators. Always use `Prop<Nullable<T>>`.

## 3. Create a DbContext

```pascal
type
  TAppDbContext = class(TDbContext)
  private
    function GetUsers: IDbSet<TUser>;
  public
    property Users: IDbSet<TUser> read GetUsers;
  end;

implementation

function TAppDbContext.GetUsers: IDbSet<TUser>;
begin
  Result := Entities<TUser>;
end;
```

## 4. Configure Database (via DI)

```pascal
procedure TStartup.ConfigureDatabase(Options: TDbContextOptions);
begin
  Options
    .UsePostgreSQL('host=localhost;db=my')
    .WithPooling(True); // REQUIRED for production
end;
```

### Supported Dialects

- **PostgreSQL**: `.UsePostgreSQL()`
- **SQL Server**: `.UseSQLServer()`
- **SQLite**: `.UseSQLite()`
- **MySQL / MariaDB**: `.UseMySQL()`
- **Firebird**: `.UseFirebird()`
- **Oracle**: `.UseOracle()`
- **FireDAC Connection Definition**: `.UseConnectionDef('DefName')` (with automatic dialect detection and pooling support)

## 5. CRUD Operations

### Create & Read

```pascal
// Create
var User := TUser.Create;
User.Name := 'John';
Db.Users.Add(User);
Db.SaveChanges; // User.Id is auto-populated here

// Read
var User := Db.Users.Find(1);
var All := Db.Users.ToList;
```

### Update & Delete

```pascal
// Update
User.Name := 'Bob';
Db.Users.Update(User); // REQUIRED: marks as Modified
Db.SaveChanges;

// Delete
Db.Users.Remove(User);
Db.SaveChanges;
```

## 6. Smart Properties (`Prop<T>`)

Smart Properties provide type-safe queries without strings.

### Entity Definition

```pascal
type
  TUser = class
  public
    // Smart Properties are the class fields with Prop<T> aliases
    Name: StringType;
    Age: IntType;
    // ... normal mapped properties ...
  end;
```

### Type-Safe Filtering

Use `Prototype.Entity<T>` to obtain a query-mode instance. Its properties generate expression tree nodes — they do **not** hold real data.

```pascal
var u := Prototype.Entity<TUser>; // Query-mode prototype
var Users := Db.Users
  .Where((u.Name.Contains('Cezar')) and (u.Age >= 18))
  .OrderBy(u.Name.Asc)
  .ToList;
```

### 6.1. Strongly-Typed Fluent Joins

Dext Entity provides strongly-typed fluent join methods executing directly inside database queries.

#### Explicit Join Condition
```pascal
var u := TUser.Props;
var a := TAddress.Props;

var Results := Db.Users
  .JoinLeft<TAddress>('u', 'a', u.AddressId = a.Id)
  .Where(u.Age >= 18)
  .ToList;
```

#### Implicit Auto-Join (ON resolved from ModelBuilder metadata)
```pascal
var u := TUser.Props;

// ON u.AddressId = a.Id resolved automatically
var Results := Db.Users
  .JoinInner<TAddress>
  .Where(u.Age >= 18)
  .ToList;
```

#### Cross Join (Cartesian Product, no ON condition)
```pascal
var Results := Db.Users
  .JoinCross<TDepartment>
  .ToList;
```

Available join methods:
- `JoinInner<TInner>` / `JoinInner<TInner>(AliasOuter, AliasInner, Condition)`
- `JoinLeft<TInner>` / `JoinLeft<TInner>(AliasOuter, AliasInner, Condition)`
- `JoinRight<TInner>` / `JoinRight<TInner>(AliasOuter, AliasInner, Condition)`
- `JoinFull<TInner>` / `JoinFull<TInner>(AliasOuter, AliasInner, Condition)`
- `JoinCross<TInner>` / `JoinCross<TInner>(AliasOuter, AliasInner)`

## 7. `IList<T>` Collections

ORM always returns `IList<T>`.

```pascal
var Users: IList<TUser> := Db.Users.ToList;

for var User in Users do
  WriteLn(User.Name);
// Memory is managed by the interface (no Free needed)
```

### Relationships (Owned Collections)

When a List is managed by DbContext, **NEVER** set `OwnsObjects = True`.

```pascal
constructor TOrder.Create;
begin
  // False = DbContext handles entity disposal
  FItems := TCollections.CreateList<TOrderItem>(False);
end;
```

## 8. Database Seeding

```pascal
class procedure TDbSeeder.Seed(const Provider: IServiceProvider);
begin
  var Scope := Provider.CreateScope;
  try
    var Db := Scope.ServiceProvider.GetService<TAppDbContext>;
    if Db.EnsureCreated then
    begin
       // Initialize data
    end;
  finally
    Scope := nil;
  end;
end;
```

## 9. Fluent API (POO Mapping)

Override `OnModelCreating` to configure entities without using attributes.

```pascal
procedure TAppDbContext.OnModelCreating(Builder: TModelBuilder);
begin
  Builder.UseNamingStrategy(TSnakeCaseNamingStrategy);

  Builder.Entity<TProduct>()
    .ToTable('my_products')
    .HasKey('Id')
    .Prop('Price').HasColumn('unit_price').IsRequired;
end;
```

## 10. Memory Management

- **Context Scope**: Entities returned by `Find` or `ToList` are tracked by the context. They are freed when the context is destroyed.
- **Detach**: `Db.Detach(Entity)` stops tracking but does **NOT** free the object. You must call `Entity.Free` manually.
- **Unit Tests**: Without a DbContext, lists created with `OwnsObjects=False` will leak unless you manually free items.
