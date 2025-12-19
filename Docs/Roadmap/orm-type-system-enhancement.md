# 🎯 ORM Type System Enhancement - Design Document

## Executive Summary

This document outlines the plan to enhance Dext's ORM type system to support database-specific types (UUID, ENUM, JSON, etc.) across different providers (PostgreSQL, MySQL, SQL Server, SQLite).

---

## Problem Statement

### Current Limitations

1. **UUID/GUID Support**
   - PostgreSQL requires explicit casting: `'value'::uuid`
   - No native `TGUID` mapping
   - String-based workaround is inefficient

2. **Enum Support**
   - Currently saved as integers only
   - No option to save as string (enum name)
   - PostgreSQL native ENUM types not supported

3. **Type Mapping**
   - Generic `TValue.AsVariant` fallback
   - No dialect-specific type handling
   - Missing support for: JSON, JSONB, ARRAY, HSTORE, etc.

### Real-World Impact

**User Report (MVP Testing PostgreSQL):**
```sql
-- Current (doesn't work):
SELECT * FROM person WHERE id = '830c3664-027d-4b87-8c98-76fb0aac08ec'

-- Required:
SELECT * FROM person WHERE id = '830c3664-027d-4b87-8c98-76fb0aac08ec'::uuid
```

---

## Solution Architecture

### 1. Type Converter System

Create a pluggable type converter architecture:

```pascal
type
  ITypeConverter = interface
    function CanConvert(ATypeInfo: PTypeInfo): Boolean;
    function ToDatabase(const AValue: TValue; ADialect: TDatabaseDialect): TValue;
    function FromDatabase(const AValue: TValue; ATypeInfo: PTypeInfo): TValue;
    function GetSQLCast(const AValue: string; ADialect: TDatabaseDialect): string;
  end;
```

### 2. Built-In Converters

#### A. GUID Converter

```pascal
TGuidConverter = class(TInterfacedObject, ITypeConverter)
  function CanConvert(ATypeInfo: PTypeInfo): Boolean;
  begin
    Result := ATypeInfo = TypeInfo(TGUID);
  end;

  function ToDatabase(const AValue: TValue; ADialect: TDatabaseDialect): TValue;
  begin
    case ADialect of
      ddPostgreSQL: 
        Result := GUIDToString(AValue.AsType<TGUID>); // Will be cast in SQL
      ddSQLServer, ddMySQL, ddSQLite:
        Result := GUIDToString(AValue.AsType<TGUID>);
    end;
  end;

  function GetSQLCast(const AValue: string; ADialect: TDatabaseDialect): string;
  begin
    case ADialect of
      ddPostgreSQL: Result := Format('%s::uuid', [AValue]);
      ddSQLServer: Result := Format('CAST(%s AS UNIQUEIDENTIFIER)', [AValue]);
      else Result := AValue; // MySQL/SQLite use strings
    end;
  end;
end;
```

#### B. Enum Converter

```pascal
TEnumConverterMode = (ecInteger, ecString);

TEnumConverter = class(TInterfacedObject, ITypeConverter)
private
  FMode: TEnumConverterMode;
public
  constructor Create(AMode: TEnumConverterMode = ecInteger);
  
  function ToDatabase(const AValue: TValue; ADialect: TDatabaseDialect): TValue;
  begin
    if FMode = ecInteger then
      Result := AValue.AsOrdinal
    else
      Result := GetEnumName(AValue.TypeInfo, AValue.AsOrdinal);
  end;

  function FromDatabase(const AValue: TValue; ATypeInfo: PTypeInfo): TValue;
  begin
    if FMode = ecInteger then
      TValue.Make(AValue.AsInteger, ATypeInfo, Result)
    else
    begin
      var OrdValue := GetEnumValue(ATypeInfo, AValue.AsString);
      TValue.Make(OrdValue, ATypeInfo, Result);
    end;
  end;
end;
```

#### C. JSON Converter (PostgreSQL JSONB)

```pascal
TJsonConverter = class(TInterfacedObject, ITypeConverter)
  function CanConvert(ATypeInfo: PTypeInfo): Boolean;
  begin
    // Detect custom attribute [JsonColumn]
    Result := HasAttribute<JsonColumnAttribute>(ATypeInfo);
  end;

  function ToDatabase(const AValue: TValue; ADialect: TDatabaseDialect): TValue;
  begin
    // Serialize object to JSON string
    Result := TDextJson.Serialize(AValue.AsObject);
  end;

  function GetSQLCast(const AValue: string; ADialect: TDatabaseDialect): string;
  begin
    case ADialect of
      ddPostgreSQL: Result := Format('%s::jsonb', [AValue]);
      else Result := AValue;
    end;
  end;
end;
```

---

## Implementation Plan

### Phase 1: Core Infrastructure (Week 1)

**Files to Create:**
- `Dext.Entity.TypeConverters.pas` - Base interfaces and registry
- `Dext.Entity.TypeConverters.Guid.pas` - GUID converter
- `Dext.Entity.TypeConverters.Enum.pas` - Enum converter

**Files to Modify:**
- `Dext.Entity.Drivers.FireDAC.pas` - Integrate type converters
- `Dext.Entity.Dialects.pas` - Add dialect-specific SQL generation

**Tasks:**
1. Create `ITypeConverter` interface
2. Create `TTypeConverterRegistry` singleton
3. Register built-in converters
4. Modify `SetParamValue` to use converters

### Phase 2: GUID Support (Week 1)

**Entity Example:**
```pascal
type
  [Table('users')]
  TUser = class
  private
    FId: TGUID;
    FName: string;
  public
    [PK]
    [Column('id')]
    property Id: TGUID read FId write FId;
    
    property Name: string read FName write FName;
  end;
```

**Generated SQL (PostgreSQL):**
```sql
-- Insert
INSERT INTO users (id, name) VALUES (:id::uuid, :name)

-- Query
SELECT * FROM users WHERE id = :id::uuid
```

**Implementation:**
1. Detect `TGUID` type in `SetParamValue`
2. Apply `TGuidConverter`
3. Generate SQL with `::uuid` cast for PostgreSQL

### Phase 3: Enum Support (Week 2)

**Attribute-Based Configuration:**
```pascal
type
  TUserRole = (urGuest, urUser, urAdmin);

  [Table('users')]
  TUser = class
  private
    FRole: TUserRole;
  public
    [Column('role')]
    [EnumAsString] // NEW attribute
    property Role: TUserRole read FRole write FRole;
  end;
```

**Behavior:**
- **Without `[EnumAsString]`**: Saves as `0, 1, 2` (default)
- **With `[EnumAsString]`**: Saves as `'urGuest', 'urUser', 'urAdmin'`

**PostgreSQL Native ENUM (Future):**
```sql
CREATE TYPE user_role AS ENUM ('Guest', 'User', 'Admin');
```

### Phase 4: Advanced Types (Week 3)

#### A. JSON/JSONB (PostgreSQL)

```pascal
type
  [Table('products')]
  TProduct = class
  private
    FMetadata: TJSONObject;
  public
    [Column('metadata')]
    [JsonColumn] // NEW attribute
    property Metadata: TJSONObject read FMetadata write FMetadata;
  end;
```

#### B. Array Types (PostgreSQL)

```pascal
type
  [Table('posts')]
  TPost = class
  private
    FTags: TArray<string>;
  public
    [Column('tags')]
    [ArrayColumn] // NEW attribute
    property Tags: TArray<string> read FTags write FTags;
  end;
```

**Generated SQL:**
```sql
INSERT INTO posts (tags) VALUES (ARRAY['delphi', 'orm', 'framework']::text[])
```

---

## Attribute System

### New Attributes

```pascal
type
  /// <summary>
  ///   Marks an enum property to be saved as string instead of integer.
  /// </summary>
  EnumAsStringAttribute = class(TCustomAttribute)
  end;

  /// <summary>
  ///   Marks a property as JSON/JSONB column (PostgreSQL).
  /// </summary>
  JsonColumnAttribute = class(TCustomAttribute)
  private
    FUseJsonB: Boolean; // PostgreSQL: JSON vs JSONB
  public
    constructor Create(AUseJsonB: Boolean = True);
    property UseJsonB: Boolean read FUseJsonB;
  end;

  /// <summary>
  ///   Marks a TArray<T> property as database array column.
  /// </summary>
  ArrayColumnAttribute = class(TCustomAttribute)
  end;

  /// <summary>
  ///   Specifies custom database type for a column.
  /// </summary>
  ColumnTypeAttribute = class(TCustomAttribute)
  private
    FTypeName: string;
  public
    constructor Create(const ATypeName: string);
    property TypeName: string read FTypeName;
  end;
```

---

## FireDAC Integration

### Current `SetParamValue` Enhancement

```pascal
procedure TFireDACCommand.SetParamValue(Param: TFDParam; const AValue: TValue);
var
  Converter: ITypeConverter;
  ConvertedValue: TValue;
  Dialect: TDatabaseDialect;
begin
  if AValue.IsEmpty then
  begin
    Param.Clear;
    Exit;
  end;

  // Get current dialect
  Dialect := GetDialect(FConnection);

  // Try to find a converter
  Converter := TTypeConverterRegistry.Instance.GetConverter(AValue.TypeInfo);
  if Converter <> nil then
  begin
    ConvertedValue := Converter.ToDatabase(AValue, Dialect);
    
    // Set param value
    case ConvertedValue.Kind of
      tkString, tkUString: 
      begin
        Param.DataType := ftString;
        Param.AsString := ConvertedValue.AsString;
      end;
      // ... other types
    end;
  end
  else
  begin
    // Fallback to current logic
    case AValue.Kind of
      // ... existing code
    end;
  end;
end;
```

### SQL Generation Enhancement

```pascal
function TFireDACCommand.BuildParameterSQL(const AParamName: string; 
  ATypeInfo: PTypeInfo): string;
var
  Converter: ITypeConverter;
  Dialect: TDatabaseDialect;
begin
  Result := ':' + AParamName;
  
  Converter := TTypeConverterRegistry.Instance.GetConverter(ATypeInfo);
  if Converter <> nil then
  begin
    Dialect := GetDialect(FConnection);
    Result := Converter.GetSQLCast(Result, Dialect);
  end;
end;
```

---

## Testing Strategy

### Unit Tests

```pascal
procedure TestGuidInsertion;
var
  User: TUser;
  Guid: TGUID;
begin
  CreateGUID(Guid);
  User := TUser.Create;
  User.Id := Guid;
  User.Name := 'John Doe';
  
  Context.Users.Add(User);
  Context.SaveChanges;
  
  var Loaded := Context.Users.Find(Guid);
  Assert.AreEqual(Guid, Loaded.Id);
end;

procedure TestEnumAsString;
var
  User: TUser;
begin
  User := TUser.Create;
  User.Role := urAdmin;
  
  Context.Users.Add(User);
  Context.SaveChanges;
  
  // Verify in database
  var SQL := 'SELECT role FROM users WHERE id = :id';
  var RoleStr := Context.ExecuteScalar<string>(SQL, [User.Id]);
  Assert.AreEqual('urAdmin', RoleStr);
end;
```

### Integration Tests (PostgreSQL)

- [ ] GUID primary key
- [ ] GUID foreign key
- [ ] Enum as integer (default)
- [ ] Enum as string
- [ ] JSONB column
- [ ] Array column
- [ ] UUID in WHERE clause
- [ ] UUID in JOIN

---

## Migration Support

### Auto-Detection

```pascal
// In TEntityTypeBuilder
function Prop<T>(const APropertyName: string): TPropertyBuilder<T>;
begin
  Result := inherited Prop<T>(APropertyName);
  
  // Auto-detect GUID
  if TypeInfo(T) = TypeInfo(TGUID) then
    Result.HasColumnType('uuid'); // PostgreSQL
    
  // Auto-detect enum
  if GetTypeKind(TypeInfo(T)) = tkEnumeration then
  begin
    if HasAttribute<EnumAsStringAttribute>(TypeInfo(T)) then
      Result.HasColumnType('varchar(50)')
    else
      Result.HasColumnType('integer');
  end;
end;
```

### Manual Override

```pascal
// In DbContext.OnModelCreating
Entity<TUser>.Prop(u => u.Id).HasColumnType('uuid');
Entity<TUser>.Prop(u => u.Role).HasColumnType('varchar(20)');
```

---

## Compatibility Matrix

| Type | PostgreSQL | MySQL | SQL Server | SQLite |
|------|------------|-------|------------|--------|
| **GUID** | `uuid` | `char(36)` | `uniqueidentifier` | `text` |
| **Enum (int)** | `integer` | `int` | `int` | `integer` |
| **Enum (string)** | `varchar` | `varchar` | `nvarchar` | `text` |
| **JSON** | `jsonb` | `json` | `nvarchar(max)` | `text` |
| **Array** | `type[]` | `json` | `nvarchar(max)` | `text` |

---

## Performance Considerations

### 1. Converter Caching

```pascal
TTypeConverterRegistry = class
private
  FConverters: TDictionary<PTypeInfo, ITypeConverter>;
  FLock: TMultiReadExclusiveWriteSynchronizer;
public
  function GetConverter(ATypeInfo: PTypeInfo): ITypeConverter;
  // Cached lookup, thread-safe
end;
```

### 2. SQL Generation Caching

- Cache generated SQL with type casts
- Invalidate on dialect change
- Use prepared statements

### 3. Bulk Operations

- Batch GUID conversions
- Array parameter binding for PostgreSQL

---

## Roadmap

### Immediate (This Week)

1. ✅ Create design document
2. ✅ Implement `ITypeConverter` interface
3. ✅ Implement `TGuidConverter`
4. ✅ Fix PostgreSQL UUID issue

### Short Term (In Progress)

1. ⏳ Implement `TEnumConverter`
2. ⏳ Add `[EnumAsString]` attribute
3. ⏳ Add comprehensive tests (Partial: GUID tested)
4. ⏳ Update documentation (Partial: README updated)

### Medium Term (Next Month)

1. JSON/JSONB support
2. Array type support
3. PostgreSQL native ENUM
4. Custom type converters (user-defined)

---

## Breaking Changes

**None** - All changes are additive and backward compatible.

- Existing integer enums continue to work
- GUID support is opt-in
- Default behavior unchanged

---

## Documentation Updates

1. **README.md**: Add type support matrix
2. **ORM Guide**: Add section on special types
3. **Migration Guide**: Document GUID and Enum usage
4. **API Reference**: Document new attributes

---

**Status**: 📋 Design Phase  
**Priority**: 🔥 High (Blocking MVP user)  
**Estimated Effort**: 2-3 weeks  
**Author**: Cesar Romero  
**Date**: 2025-12-18
