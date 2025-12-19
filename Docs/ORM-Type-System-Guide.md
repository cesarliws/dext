# 🔧 ORM Type System - User Guide

## Overview

Dext's ORM Type System provides powerful type converters that handle database-specific types (GUID, Enum, JSON, Array) across different database providers (PostgreSQL, MySQL, SQL Server, SQLite).

---

## Quick Start

### GUID Support

**Problem**: PostgreSQL requires explicit UUID casting.

**Before:**
```sql
-- Doesn't work in PostgreSQL
SELECT * FROM users WHERE id = '830c3664-027d-4b87-8c98-76fb0aac08ec'
```

**After (with Dext):**
```pascal
type
  [Table('users')]
  TUser = class
  private
    FId: TGUID;
  public
    [PK]
    property Id: TGUID read FId write FId;
  end;

// Dext automatically generates:
// SELECT * FROM users WHERE id = :id::uuid
```

**Generated SQL (PostgreSQL):**
```sql
INSERT INTO users (id, name) VALUES (:id::uuid, :name)
SELECT * FROM users WHERE id = :id::uuid
```

---

## Supported Types

### 1. GUID / UUID

**Delphi Type**: `TGUID`

**Database Types**:
- PostgreSQL: `uuid`
- SQL Server: `uniqueidentifier`
- MySQL: `char(36)`
- SQLite: `text`

**Usage**:
```pascal
type
  [Table('products')]
  TProduct = class
  private
    FId: TGUID;
    FName: string;
  public
    [PK]
    property Id: TGUID read FId write FId;
    property Name: string read FName write FName;
  end;

// Create and save
var
  Product: TProduct;
begin
  Product := TProduct.Create;
  CreateGUID(Product.Id);
  Product.Name := 'Widget';
  
  Context.Products.Add(Product);
  Context.SaveChanges;
end;

// Query by GUID
var
  Id: TGUID;
  Product: TProduct;
begin
  Id := StringToGUID('{830C3664-027D-4B87-8C98-76FB0AAC08EC}');
  Product := Context.Products.Find(Id);
end;
```

**JSON Core Support**:
`TGUID` is natively supported by `TDextJson`. When serializing a GUID property to JSON, it is automatically converted to a correctly formatted string (ex: `"{5F0B...}"`), avoiding RTTI errors common in other Delphi serializers.

---

### 2. Enums

**Delphi Type**: `TEnumType`

**Storage Modes**:
1. **Integer** (default): Stores ordinal value
2. **String**: Stores enum name

**Usage (Integer Mode - Default)**:
```pascal
type
  TUserRole = (urGuest, urUser, urAdmin, urSuperAdmin);

  [Table('users')]
  TUser = class
  private
    FRole: TUserRole;
  public
    property Role: TUserRole read FRole write FRole;
  end;

// Stored in database as: 0, 1, 2, 3
```

**Usage (String Mode)**:
```pascal
type
  TUserRole = (urGuest, urUser, urAdmin, urSuperAdmin);

  [Table('users')]
  TUser = class
  private
    FRole: TUserRole;
  public
    [EnumAsString]  // ← Add this attribute
    property Role: TUserRole read FRole write FRole;
  end;

// Stored in database as: 'urGuest', 'urUser', 'urAdmin', 'urSuperAdmin'
```

**Benefits of String Mode**:
- ✅ Human-readable in database
- ✅ Easier debugging
- ✅ Better for data migration
- ❌ Slightly larger storage

**Query Example**:
```pascal
// Works with both modes
var Users := Context.Users
  .Where(UserEntity.Role = urAdmin)
  .ToList;
```

---

### 3. JSON / JSONB (PostgreSQL)

**Delphi Type**: Any class/record

**Database Types**:
- PostgreSQL: `json` or `jsonb` (recommended)
- MySQL: `json`
- SQL Server: `nvarchar(max)`
- SQLite: `text`

**Usage**:
```pascal
type
  TUserSettings = class
    Theme: string;
    Language: string;
    NotificationsEnabled: Boolean;
  end;

  [Table('users')]
  TUser = class
  private
    FId: TGUID;
    FSettings: TUserSettings;
  public
    [PK]
    property Id: TGUID read FId write FId;
    
    [JsonColumn(True)]  // True = JSONB (PostgreSQL), False = JSON
    property Settings: TUserSettings read FSettings write FSettings;
  end;

// Save
var
  User: TUser;
begin
  User := TUser.Create;
  CreateGUID(User.Id);
  
  User.Settings := TUserSettings.Create;
  User.Settings.Theme := 'dark';
  User.Settings.Language := 'en';
  User.Settings.NotificationsEnabled := True;
  
  Context.Users.Add(User);
  Context.SaveChanges;
end;

// Load
var
  User: TUser;
begin
  User := Context.Users.Find(SomeGuid);
  WriteLn('Theme: ', User.Settings.Theme);
  WriteLn('Language: ', User.Settings.Language);
end;
```

**Generated SQL (PostgreSQL)**:
```sql
INSERT INTO users (id, settings) 
VALUES (:id::uuid, :settings::jsonb)
```

**JSONB vs JSON**:
- **JSONB** (recommended): Binary format, faster queries, supports indexing
- **JSON**: Text format, preserves formatting

---

### 4. Arrays (PostgreSQL)

**Delphi Type**: `TArray<T>`

**Database Types**:
- PostgreSQL: `type[]` (native arrays)
- MySQL: `json`
- SQL Server: `nvarchar(max)` (JSON)
- SQLite: `text` (JSON)

**Usage**:
```pascal
type
  [Table('posts')]
  TPost = class
  private
    FId: TGUID;
    FTitle: string;
    FTags: TArray<string>;
  public
    [PK]
    property Id: TGUID read FId write FId;
    property Title: string read FTitle write FTitle;
    
    [ArrayColumn]
    property Tags: TArray<string> read FTags write FTags;
  end;

// Save
var
  Post: TPost;
begin
  Post := TPost.Create;
  CreateGUID(Post.Id);
  Post.Title := 'Getting Started with Dext';
  
  SetLength(Post.Tags, 3);
  Post.Tags[0] := 'delphi';
  Post.Tags[1] := 'orm';
  Post.Tags[2] := 'tutorial';
  
  Context.Posts.Add(Post);
  Context.SaveChanges;
end;

// Query (PostgreSQL)
var Posts := Context.Posts
  .Where('tags @> ARRAY[''delphi'']::text[]')  // Contains 'delphi'
  .ToList;
```

**Generated SQL (PostgreSQL)**:
```sql
INSERT INTO posts (id, title, tags) 
VALUES (:id::uuid, :title, ARRAY['delphi', 'orm', 'tutorial']::text[])
```

---

## Custom Type Converters

You can create custom converters for your own types.

### Step 1: Create Converter

```pascal
type
  TMoneyConverter = class(TTypeConverterBase)
  public
    function CanConvert(ATypeInfo: PTypeInfo): Boolean; override;
    function ToDatabase(const AValue: TValue; ADialect: TDatabaseDialect): TValue; override;
    function FromDatabase(const AValue: TValue; ATypeInfo: PTypeInfo): TValue; override;
    function GetSQLCast(const AParamName: string; ADialect: TDatabaseDialect): string; override;
  end;

function TMoneyConverter.CanConvert(ATypeInfo: PTypeInfo): Boolean;
begin
  Result := ATypeInfo = TypeInfo(TMoney);
end;

function TMoneyConverter.ToDatabase(const AValue: TValue; ADialect: TDatabaseDialect): TValue;
var
  Money: TMoney;
begin
  Money := AValue.AsType<TMoney>;
  Result := Money.Amount; // Store as decimal
end;

function TMoneyConverter.FromDatabase(const AValue: TValue; ATypeInfo: PTypeInfo): TValue;
var
  Money: TMoney;
begin
  Money.Amount := AValue.AsExtended;
  Money.Currency := 'USD'; // Default
  TValue.Make(@Money, TypeInfo(TMoney), Result);
end;

function TMoneyConverter.GetSQLCast(const AParamName: string; ADialect: TDatabaseDialect): string;
begin
  case ADialect of
    ddPostgreSQL: Result := Format('%s::numeric(18,2)', [AParamName]);
    else Result := AParamName;
  end;
end;
```

### Step 2: Register Converter

```pascal
// Global registration (affects all properties of this type)
TTypeConverterRegistry.Instance.RegisterConverter(TMoneyConverter.Create);

// Or per-type registration
TTypeConverterRegistry.Instance.RegisterConverterForType(
  TypeInfo(TMoney),
  TMoneyConverter.Create
);
```

### Step 3: Use It

```pascal
type
  [Table('invoices')]
  TInvoice = class
  private
    FTotal: TMoney;
  public
    property Total: TMoney read FTotal write FTotal;
  end;
```

---

## Database-Specific Features

### PostgreSQL

**Native Types Supported**:
- `uuid` - GUID
- `jsonb` / `json` - JSON objects
- `type[]` - Arrays
- `enum` - Native enums (future)

**Example**:
```pascal
type
  [Table('products')]
  TProduct = class
  private
    FId: TGUID;
    FMetadata: TProductMetadata;
    FTags: TArray<string>;
  public
    [PK]
    property Id: TGUID read FId write FId;
    
    [JsonColumn(True)] // JSONB
    property Metadata: TProductMetadata read FMetadata write FMetadata;
    
    [ArrayColumn]
    property Tags: TArray<string> read FTags write FTags;
  end;
```

**Generated Schema**:
```sql
CREATE TABLE products (
  id uuid PRIMARY KEY,
  metadata jsonb,
  tags text[]
);
```

### SQL Server

**Type Mappings**:
- `TGUID` → `uniqueidentifier`
- `TArray<T>` → `nvarchar(max)` (JSON)
- JSON → `nvarchar(max)`

### MySQL

**Type Mappings**:
- `TGUID` → `char(36)`
- `TArray<T>` → `json`
- JSON → `json`

### SQLite

**Type Mappings**:
- `TGUID` → `text`
- `TArray<T>` → `text` (JSON)
- JSON → `text`

---

## Migration Support

### Auto-Detection

Dext automatically detects types and generates appropriate DDL:

```pascal
// In DbContext.OnModelCreating
Entity<TUser>
  .Prop(u => u.Id).HasColumnType('uuid')
  .Prop(u => u.Role).HasColumnType('varchar(20)');
```

### Manual Override

```pascal
Entity<TProduct>
  .Prop(p => p.Metadata).HasColumnType('jsonb')
  .Prop(p => p.Tags).HasColumnType('text[]');
```

---

## Performance Tips

### 1. Use JSONB for PostgreSQL

```pascal
[JsonColumn(True)]  // JSONB - faster, indexable
property Settings: TUserSettings read FSettings write FSettings;
```

### 2. Index GUID Columns

```sql
CREATE INDEX idx_users_id ON users USING btree (id);
```

### 3. Index JSONB Fields

```sql
CREATE INDEX idx_users_settings ON users USING gin (settings);
```

### 4. Use Enum Integers for Performance

```pascal
// Faster (integer comparison)
property Role: TUserRole read FRole write FRole;

// Slower but more readable (string comparison)
[EnumAsString]
property Role: TUserRole read FRole write FRole;
```

---

## Troubleshooting

### Issue: "Invalid UUID format"

**Cause**: PostgreSQL requires valid UUID format.

**Solution**: Use `CreateGUID()` or validate input:
```pascal
var Guid: TGUID;
begin
  if not TryStringToGUID('{...}', Guid) then
    raise Exception.Create('Invalid GUID');
end;
```

### Issue: "Cannot cast to uuid"

**Cause**: Missing type converter or wrong dialect.

**Solution**: Ensure `Dext.Entity.TypeConverters` is in uses clause and FireDAC driver is correctly configured.

### Issue: "Enum value not found"

**Cause**: Database has string value that doesn't match enum name.

**Solution**: Ensure enum names match exactly (case-sensitive):
```pascal
// Database: 'urAdmin' ✓
// Database: 'admin' ✗ (won't match)
```

---

## Examples

### Complete Example: User Management

```pascal
type
  TUserRole = (urGuest, urUser, urAdmin);
  
  TUserSettings = class
    Theme: string;
    Language: string;
  end;

  [Table('users')]
  TUser = class
  private
    FId: TGUID;
    FName: string;
    FRole: TUserRole;
    FSettings: TUserSettings;
    FTags: TArray<string>;
  public
    [PK]
    property Id: TGUID read FId write FId;
    property Name: string read FName write FName;
    
    [EnumAsString]
    property Role: TUserRole read FRole write FRole;
    
    [JsonColumn(True)]
    property Settings: TUserSettings read FSettings write FSettings;
    
    [ArrayColumn]
    property Tags: TArray<string> read FTags write FTags;
  end;

// Usage
var
  User: TUser;
begin
  User := TUser.Create;
  CreateGUID(User.Id);
  User.Name := 'John Doe';
  User.Role := urAdmin;
  
  User.Settings := TUserSettings.Create;
  User.Settings.Theme := 'dark';
  User.Settings.Language := 'en';
  
  SetLength(User.Tags, 2);
  User.Tags[0] := 'developer';
  User.Tags[1] := 'admin';
  
  Context.Users.Add(User);
  Context.SaveChanges;
  
  // Query
  var Admins := Context.Users
    .Where(UserEntity.Role = urAdmin)
    .ToList;
end;
```

---

## API Reference

### Attributes

| Attribute | Purpose | Example |
|-----------|---------|---------|
| `[EnumAsString]` | Store enum as string | `[EnumAsString] property Role: TUserRole` |
| `[JsonColumn(UseJsonB)]` | Store object as JSON/JSONB | `[JsonColumn(True)] property Settings: TSettings` |
| `[ArrayColumn]` | Store array | `[ArrayColumn] property Tags: TArray<string>` |
| `[ColumnType('type')]` | Custom DB type | `[ColumnType('uuid')] property Id: TGUID` |

### Type Converters

| Converter | Delphi Type | PostgreSQL | SQL Server | MySQL | SQLite |
|-----------|-------------|------------|------------|-------|--------|
| `TGuidConverter` | `TGUID` | `uuid` | `uniqueidentifier` | `char(36)` | `text` |
| `TEnumConverter` | `TEnumType` | `integer`/`varchar` | `int`/`nvarchar` | `int`/`varchar` | `integer`/`text` |
| `TJsonConverter` | `TObject` | `jsonb`/`json` | `nvarchar(max)` | `json` | `text` |
| `TArrayConverter` | `TArray<T>` | `type[]` | `nvarchar(max)` | `json` | `text` |

---

## See Also

- [ORM Type System Enhancement Design](orm-type-system-enhancement.md)
- [Entity Framework Guide](../README.md)
- [Migration Guide](migrations-guide.md)

---

**Version**: Dext v1.0  
**Last Updated**: 2025-12-19  
**Author**: Cesar Romero
