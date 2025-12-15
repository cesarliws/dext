# Nullable Support in Dext ORM

## Overview

Dext ORM provides **full support** for `Nullable<T>` types in entity properties, including Foreign Keys. This allows you to represent optional database columns that can contain `NULL` values.

## Supported Nullable Types

- ✅ `Nullable<Integer>`
- ✅ `Nullable<Int64>`
- ✅ `Nullable<String>`
- ✅ `Nullable<TGUID>`
- ✅ `Nullable<TDateTime>`
- ✅ `Nullable<Double>`
- ✅ `Nullable<Boolean>`
- ✅ Any `Nullable<T>` compatible with **Spring4D** or future **Delphi native** implementations

## Usage

### Basic Entity with Nullable Fields

```pascal
uses
  Dext.Types.Nullable;

type
  [Table('users')]
  TUser = class
  private
    FId: Integer;
    FName: string;
    FAge: Nullable<Integer>;
    FEmail: Nullable<string>;
    FAddressId: Nullable<Integer>;
  public
    [PK, AutoInc]
    property Id: Integer read FId write FId;
    
    property Name: string read FName write FName;
    
    // Optional age - can be NULL in database
    property Age: Nullable<Integer> read FAge write FAge;
    
    // Optional email - can be NULL in database
    property Email: Nullable<string> read FEmail write FEmail;
    
    // Optional Foreign Key - can be NULL in database
    [Column('address_id')]
    property AddressId: Nullable<Integer> read FAddressId write FAddressId;
  end;
```

### Working with Nullable Values

```pascal
var
  User: TUser;
begin
  User := TUser.Create;
  try
    User.Name := 'John Doe';
    
    // Setting a nullable value
    User.Age := 30;
    
    // Setting to NULL
    User.Email := nil;
    
    // Checking if has value
    if User.Age.HasValue then
      WriteLn('Age: ' + User.Age.Value.ToString);
    
    // Getting value with default
    WriteLn('Email: ' + User.Email.GetValueOrDefault('N/A'));
    
    // Save to database
    Context.Entities<TUser>.Add(User);
    Context.SaveChanges;
  finally
    User.Free;
  end;
end;
```

### Nullable Foreign Keys

Nullable Foreign Keys are fully supported for optional relationships:

```pascal
type
  [Table('users')]
  TUser = class
  private
    FAddressId: Nullable<Integer>;
    FAddress: Lazy<TAddress>;
  public
    // Optional Foreign Key
    [Column('address_id')]
    property AddressId: Nullable<Integer> read FAddressId write FAddressId;
    
    // Optional relationship
    [ForeignKey('AddressId'), NotMapped]
    property Address: TAddress read GetAddress write SetAddress;
  end;
```

**Behavior**:
- When `AddressId` is `NULL`, the `Address` property will **not** attempt to load
- When `AddressId` has a value, the `Address` will be loaded normally (lazy or eager)

## Implementation Details

### How It Works

#### 1. **Saving (Persist)**

When saving entities with `Nullable<T>` fields:

1. The ORM detects the field is a `Nullable<T>` by checking the type name
2. Accesses internal fields (`fHasValue`, `fValue`) via RTTI
3. If `HasValue = false`, saves `NULL` to the database
4. If `HasValue = true`, extracts the inner value and saves it

#### 2. **Loading (Hydrate)**

When loading entities from the database:

1. The `TValueConverter` detects the target property is `Nullable<T>`
2. Converts the database value to the inner type (e.g., `Integer`)
3. Creates a new `Nullable<T>` instance
4. Sets `fValue` with the converted value
5. Sets `fHasValue` to `true`

#### 3. **Foreign Key Loading**

When loading references with `Nullable<T>` foreign keys:

1. The `TryUnwrapAndValidateFK` helper function unwraps the nullable
2. Checks if `HasValue = true`
3. Validates the inner value (e.g., `Integer ≠ 0`)
4. If valid, loads the related entity
5. If `NULL` or invalid, skips loading

### Compatibility

The implementation supports **both**:

- **Spring4D Nullable**: Uses `fHasValue: string` (empty = null)

The ORM automatically detects which implementation you're using and handles it correctly.

## Database Support

Nullable types work with all supported databases:

- ✅ **SQLite**: `NULL` values
- ✅ **PostgreSQL**: `NULL` values
- ✅ **Firebird**: `NULL` values (coming soon)
- ✅ **MySQL**: `NULL` values (coming soon)
- ✅ **SQL Server**: `NULL` values (coming soon)

## Best Practices

### 1. Use Nullable for Optional Fields

```pascal
// ✅ Good - clearly indicates optional field
property Age: Nullable<Integer> read FAge write FAge;

// ❌ Avoid - using 0 or -1 as "null" is error-prone
property Age: Integer read FAge write FAge; // 0 = unknown?
```

### 2. Always Check HasValue

```pascal
// ✅ Good - safe access
if User.Age.HasValue then
  WriteLn('Age: ' + User.Age.Value.ToString);

// ❌ Avoid - will raise exception if NULL
WriteLn('Age: ' + User.Age.Value.ToString);
```

### 3. Use GetValueOrDefault

```pascal
// ✅ Good - provides fallback
var Age := User.Age.GetValueOrDefault(0);

// ✅ Also good - custom default
var Email := User.Email.GetValueOrDefault('no-email@example.com');
```

### 4. Nullable Foreign Keys for Optional Relationships

```pascal
// ✅ Good - optional relationship
[Column('address_id')]
property AddressId: Nullable<Integer> read FAddressId write FAddressId;

[ForeignKey('AddressId'), NotMapped]
property Address: TAddress read GetAddress write SetAddress;

// ✅ Good - required relationship
[Column('company_id')]
property CompanyId: Integer read FCompanyId write FCompanyId;

[ForeignKey('CompanyId'), NotMapped]
property Company: TCompany read GetCompany write SetCompany;
```

## Examples

### Example 1: Optional Email

```pascal
var
  User: TUser;
begin
  User := Context.Entities<TUser>.Find(1);
  try
    if User.Email.HasValue then
      SendEmail(User.Email.Value)
    else
      WriteLn('User has no email');
  finally
    User.Free;
  end;
end;
```

### Example 2: Updating Nullable Fields

```pascal
var
  User: TUser;
begin
  User := Context.Entities<TUser>.Find(1);
  try
    // Set to a value
    User.Age := 25;
    
    // Clear the value (set to NULL)
    User.Email := nil;
    
    Context.SaveChanges;
  finally
    User.Free;
  end;
end;
```

### Example 3: Querying with Nullable

```pascal
// Find users with no email
var UsersWithoutEmail := Context.Entities<TUser>
  .Where(function(U: TUser): Boolean
    begin
      Result := not U.Email.HasValue;
    end)
  .ToList;

// Find users with specific age
var Users30 := Context.Entities<TUser>
  .Where(function(U: TUser): Boolean
    begin
      Result := U.Age.HasValue and (U.Age.Value = 30);
    end)
  .ToList;
```

## Troubleshooting

### Issue: "Cannot convert X to Nullable<T>"

**Solution**: Ensure you're using `Dext.Types.Nullable` or Spring4D's `Nullable<T>` implementation.

### Issue: "Invalid class typecast" when loading

**Solution**: This was fixed in the latest version. Make sure you're using Dext ORM v1.0+ with full Nullable support.

### Issue: Foreign Key not loading

**Solution**: Check that:
1. The `AddressId` field has a valid value (not `NULL` or `0`)
2. The related entity exists in the database
3. The `[ForeignKey]` attribute is correctly configured

## See Also

- [ORM Roadmap](ORM_ROADMAP.md)
- [Fluent API Documentation](FLUENT_API.md)
- [Lazy Loading Guide](LAZY_LOADING.md)
