# Entities & Mapping

Configure how classes map to database tables.

## Mapping Styles

Dext supports two mapping models:

1. **Explicit Mapping** (strings in attributes) — Use when the database already exists or names don't follow a pattern.
2. **Naming Strategies** (automatic mapping) — Recommended for new projects.
3. **Automatic Inference** — Dext guesses names and relationships based on Delphi naming conventions.

## Attribute Mapping

### Basic Entity

```pascal
uses
  Dext.Entity; // Facade: Table, Column, PK, AutoInc, Required, MaxLength

type
  [Table('users')]
  TUser = class
  private
    FId: Integer;
    FName: string;
    FEmail: string;
    FCreatedAt: TDateTime;
  public
    [PK, AutoInc]
    property Id: Integer read FId write FId;

    [Required, MaxLength(100)]
    property Name: string read FName write FName;

    [Required, MaxLength(200)]
    property Email: string read FEmail write FEmail;

    [CreatedAt]
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
  end;
```

> [!IMPORTANT]
> **Attribute declaration style**: Place attributes on the same line, separated by commas.  
> - ✅ `[Required, MaxLength(50), JSONName('code')]`  
> - ❌ `[Required]` on one line, `[MaxLength(50)]` on the next.

## Available Attributes

### Table Mapping

| Attribute | Description |
|-----------|-------------|
| `[Table('name')]` | Map class to table |
| `[Table]` | Map using Naming Strategy |
| `[Schema('schema')]` | Specify schema |

### Column Mapping

| Attribute | Description |
|-----------|-------------|
| `[Column('name')]` | Map to specific column |
| `[Column]` | Map using Naming Strategy |
| `[PK]` | Primary key |
| `[AutoInc]` | Auto-increment |
| `[NotMapped]` | Exclude from mapping AND JSON |
| `[Version]` | Optimistic concurrency versioning |
| `[SoftDelete('deleted_col', 1, 0)]` | Logical deletion |
| `[CreatedAt]` | Automatic timestamp on insertion |
| `[UpdatedAt]` | Automatic timestamp on update |
| `[Field('FBackingField')]` | Use direct field mapping (bypasses setters) |


### Validation Attributes

| Attribute | Description |
|-----------|-------------|
| `[Required]` | NOT NULL constraint (validated on SaveChanges) |
| `[MaxLength(N)]` | Maximum string length |
| `[MinLength(N)]` | Minimum string length |

> [!WARNING]
> **`[StringLength]` does NOT exist in Dext!** Use `[MaxLength(N)]` instead.

These attributes require `Dext.Entity` in uses. Validation runs automatically on `SaveChanges`.

### Relationships

| Attribute | Description |
|-----------|-------------|
| `[ForeignKey('col')]` | Foreign key column |
| `[InverseProperty('prop')]` | Navigation link |

### Entity Collections & Ownership

When defining `IList<T>` properties that are also managed by the `DbContext`:

1. Use `FItems: IList<TChild>` as a private field.
2. Initialize in constructor with `TCollections.CreateList<TChild>(False)`.
3. **Crucial**: Pass `False` for `OwnsObjects`.
   - **Reason**: The DbContext already manages entity lifecycle. If the list also owns them (`True`), you get **Invalid Pointer Operation** (Double Free) during shutdown.
4. **Unit Tests**: Since no DbContext exists, you **must manually free** child items in your test's `finally` block.

### Type Hints

| Attribute | Description |
|-----------|-------------|
| `[MaxLength(100)]` | Max string length |
| `[Precision(18, 2)]` | Precision and Scale for numeric/decimal |
| `[Default('value')]` | Default value in database |
| `[JsonColumn]` | Treat column as JSON |
| `[DbType(ftGuid)]` | Force a specific TFieldType |

### Type Conversion

| Attribute | Description |
|-----------|-------------|
| `[TypeConverter(TMyConverter)]` | Custom converter for this property |

```pascal
type
  TUnixTimestampConverter = class(TTypeConverterBase)
  public
    function CanConvert(ATypeInfo: PTypeInfo): Boolean; override;
    function ToDatabase(const AValue: TValue; ADialect: TDatabaseDialect): TValue; override;
    function FromDatabase(const AValue: TValue; ATypeInfo: PTypeInfo): TValue; override;
  end;

  [Table('events')]
  TEvent = class
  private
    FCreatedAt: TDateTime;
    FScheduledAt: TDateTime;
  public
    // Custom converter - stored as Unix timestamp
    [TypeConverter(TUnixTimestampConverter)]
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;

    // Default TDateTime converter (ISO format)
    property ScheduledAt: TDateTime read FScheduledAt write FScheduledAt;
  end;
```

## Field Mapping (Optimization)

The **Field Mapping** feature allows Dext ORM to populate entities directly via their **backing fields**, bypassing property setters. This is critical for performance and for ensuring that logic placed in property setters (such as change tracking or validation) is not executed during object hydration (loading from the database).

### Usage

1.  **Convention-based**: If you use the `[Field]` attribute without arguments, Dext assumes the field is `F` + `PropertyName`.
2.  **Explicit Mapping**:
```pascal
type
  TUser = class
  private
    FInternalName: string;
  public
    [Field('FInternalName')] // Maps explicitly to 'FInternalName' field
    property Name: string read GetName write SetName;
  end;
```

3.  **Fluent API**:
```pascal
Builder.Prop('Name').UseField; // Uses convention
Builder.Prop('Email').HasFieldName('FInternalEmail');
```

## Soft Delete

Soft Delete marks entities as deleted in the database without physically removing the record.

### Configuration

Apply the `[SoftDelete]` attribute to the class. By default, it uses a boolean flag (`1` = Deleted, `0` = Active).

```pascal
[Table('tasks')]
[SoftDelete('IsDeleted')] 
TTask = class
  // ...
  property IsDeleted: Boolean read FIsDeleted write FIsDeleted;
end;
```

### Operations

- **Remove**: Automatically performs an `UPDATE` instead of `DELETE`.
- **HardDelete**: Permanently removes the record.
- **IgnoreQueryFilters**: Includes soft-deleted records in queries.
- **OnlyDeleted**: Queries only records marked as deleted.
- **Restore**: Reverts a soft deletion.

```pascal
Context.Tasks.Remove(Task); // Soft delete
Context.Tasks.HardDelete(Task); // Physical delete
var All := Context.Tasks.IgnoreQueryFilters.ToList; // Active + Deleted
```
```

## Nullable Columns

### Plain nullable values — `Nullable<T>`

Use `Nullable<T>` when the column is nullable but you **do not need** type-safe query expressions on it:

```pascal
uses
  Dext.Types.Nullable;  // Required for Nullable<T>

type
  [Table('tickets')]
  TTicket = class
  private
    FId: Integer;
    FAssigneeId: Nullable<Integer>;
  public
    [PK, AutoInc]
    property Id: Integer read FId write FId;

    [ForeignKey('Assignee')]
    property AssigneeId: Nullable<Integer> read FAssigneeId write FAssigneeId;
  end;
```

**Implicit conversion** works automatically:
```pascal
// Integer → Nullable<Integer>
Ticket.AssigneeId := AgentId;   // Works without casts

// Check if has value
if Ticket.AssigneeId.HasValue then
  WriteLn('Assigned to: ', Ticket.AssigneeId.Value);

// Get value with default
var AssignId := Ticket.AssigneeId.GetValueOrDefault(0);

// Set to null
Ticket.AssigneeId := Nullable<Integer>.Null;
```

### Nullable Smart Properties — `Prop<Nullable<T>>`

When you need both nullability **and** type-safe query expressions (`.Where`, `.OrderBy`), use the `Prop<Nullable<T>>` composition:

```pascal
type
  [Table('work_orders')]
  TWorkOrder = class
  private
    FClientName:  StringType;                   // non-nullable smart property
    FScheduledAt: Prop<Nullable<TDateTime>>;    // nullable smart property
    FAssigneeId:  Prop<Nullable<Integer>>;      // nullable smart property
  public
    property ClientName:  StringType                   read FClientName  write FClientName;
    property ScheduledAt: Prop<Nullable<TDateTime>>    read FScheduledAt write FScheduledAt;
    property AssigneeId:  Prop<Nullable<Integer>>      read FAssigneeId  write FAssigneeId;
  end;
```

This enables filtering and ordering on nullable columns:

```pascal
var o := TWorkOrder.Props;

// Filter
var Unscheduled := Context.WorkOrders.Where(o.ScheduledAt.IsNull).ToList;

// Order
var ByDate := Context.WorkOrders.QueryAll.OrderBy(o.ScheduledAt.Asc).ToList;
```

> [!IMPORTANT]
> **Do not** use `Nullable<Prop<T>>` (reversed nesting). This is a deprecated pattern that breaks `OrderBy` silently. The framework warns you at startup if it detects it.  
> See the full guide → [Smart Properties: Nullable Smart Properties](smart-properties.md#nullable-smart-properties)

> [!WARNING]
> **`NavType<T>` does NOT exist in Dext!** Always use `Nullable<T>` or `Prop<Nullable<T>>`.

## Change Tracking

The `ChangeTracker` may not automatically detect changes if the entity is detached. **Always** call `Update` explicitly before `SaveChanges`:

```pascal
// ❌ WRONG: Trusting auto-tracking can fail silently
Event.Status := esPublished;
FDb.SaveChanges;

// ✅ CORRECT: Force explicit update
Event.Status := esPublished;
FDb.Events.Update(Event);  // Ensures State = Modified
FDb.SaveChanges;
```

## Auto-Generated IDs

`SaveChanges` automatically populates IDs for inserted entities. Dext supports two primary key generation styles:

### 1. Database-Side Auto-Increment (`[AutoInc]`)
The database generates the ID during insertion (e.g. `IDENTITY` or serial columns).

```pascal
[PK, AutoInc]
property Id: Integer read FId write FId;
```

> [!WARNING]
> Because the IDs are generated on the database server during the execution of the insert statements, entities configured with `[AutoInc]` **cannot be inserted in high-performance batch/bulk mode (`PersistAddRange`)**. The ORM falls back to row-by-row insertion to retrieve the IDs.

### 2. Client-Side Pre-Allocation via Sequences (`[Sequence]`)
Introduces database sequence generators combined with a thread-safe **HiLo Optimizer** (Pooled-lo algorithm). The ORM pre-allocates a range of IDs in memory by querying the database sequence once, then assigns the keys on the client-side. This **fully unlocks high-performance bulk inserts**.

```pascal
[PK, Sequence('SEQ_USER_ID', 50)]
property Id: Integer read FId write FId;
```

* **Parameters:**
  * `SequenceName`: The name of the sequence generator in the database.
  * `AllocationSize` (default `50`): The block size of IDs to pre-allocate in memory per roundtrip.

Or configure via the Fluent API in `OnModelCreating`:
```pascal
modelBuilder.Entity<TUser>
  .Property('Id')
  .UseSequence('SEQ_USER_ID', 50);
```

---

## Change Tracking

`FDb.Detach(Entity)` only removes the entity from the IdentityMap. It does **NOT** free memory.

```pascal
// ❌ WRONG: Memory Leak (detached entity becomes orphan)
FDb.Detach(Entity);
Entity := FDb.Find(ID);

// ✅ CORRECT: Free memory explicitly
FDb.Detach(Entity);
Entity.Free;
Entity := FDb.Find(ID);
```

## Naming Conventions

By default, Dext uses the property name as column name. For new projects, configure a Naming Strategy:

```pascal
// In DbContext
procedure TAppDbContext.OnModelCreating(Builder: TModelBuilder);
begin
  Builder.UseNamingStrategy(TSnakeCaseNamingStrategy);
end;
```

With `TSnakeCaseNamingStrategy`:
- Table `TUser` → `user`
- Column `CreatedAt` → `created_at`

Override with `[Table('name')]` and `[Column('name')]` when needed.

> 💡 **Reference**: See the [Orm.EntityStyles](../../../Examples/Orm.EntityStyles/) example for a side-by-side comparison.

---

[← Getting Started](getting-started.md) | [Next: Querying →](querying.md)
