# Dext ORM Scaffolding

The Dext ORM Scaffolding tool allows you to automatically generate Delphi Entity classes from an existing database schema. It supports both **Attribute-based Mapping** and **Fluent Mapping**.

## Features

- **Database First**: Connects to your existing database (via FireDAC) and extracts schema information.
- **Table & Column Mapping**: Generates classes for tables and properties for columns.
- **Type Mapping**: Automatically maps SQL types (INT, VARCHAR, DATE, etc.) to Delphi types (Integer, string, TDateTime, etc.).
- **Nullable Support**: Uses `Nullable<T>` for nullable database columns.
- **Relationships**: Detects Foreign Keys and generates `ILazy<T>` navigation properties for lazy loading.
- **Naming Conventions**: Converts `snake_case` database names to `PascalCase` Delphi names (e.g., `user_id` -> `UserId`, `order_items` -> `TOrderItems`).
- **Mapping Styles**: Supports generating standard Attributes (`[Table]`, `[Column]`) or Fluent Mapping (`RegisterMappings`).

## Usage

The scaffolding logic is encapsulated in the `Dext.Entity.Scaffolding` unit.

### 1. Basic Usage (Attribute Mapping)

```pascal
uses
  Dext.Entity.Scaffolding,
  Dext.Entity.Drivers.FireDAC;

procedure GenerateEntities;
var
  Connection: IDbConnection;
  Provider: ISchemaProvider;
  Generator: IEntityGenerator;
  Tables: TArray<string>;
  MetaList: TArray<TMetaTable>;
  Code: string;
begin
  // 1. Setup Connection
  Connection := TFireDACConnection.Create(FDConnection1);
  
  // 2. Create Schema Provider
  Provider := TFireDACSchemaProvider.Create(Connection);
  
  // 3. Extract Metadata
  Tables := Provider.GetTables;
  SetLength(MetaList, Length(Tables));
  for var i := 0 to High(Tables) do
    MetaList[i] := Provider.GetTableMetadata(Tables[i]);
    
  // 4. Generate Code (Default: Attributes)
  Generator := TDelphiEntityGenerator.Create;
  Code := Generator.GenerateUnit('MyEntities', MetaList);
  
  // 5. Save to File
  TFile.WriteAllText('MyEntities.pas', Code);
end;
```

### 2. Fluent Mapping Generation

To generate entities without attributes (POCOs) and a separate `RegisterMappings` procedure, pass `msFluent` to `GenerateUnit`:

```pascal
  // ... (setup as above)

  // Generate with Fluent Mapping
  Code := Generator.GenerateUnit('MyFluentEntities', MetaList, msFluent);
  
  TFile.WriteAllText('MyFluentEntities.pas', Code);
```

## Generated Code Structure

### Attribute Mapping Example

```pascal
unit MyEntities;

interface

uses
  Dext.Entity, Dext.Types.Nullable, Dext.Types.Lazy;

type
  [Table('users')]
  TUser = class
  private
    FId: Integer;
    FFullName: string;
    FAddressId: Nullable<Integer>;
    FAddress: ILazy<TAddress>;
    // ... getters/setters ...
  public
    [PK] [AutoInc] 
    property Id: Integer read FId write FId;
    
    [Column('full_name')] 
    property FullName: string read FFullName write FFullName;
    
    [ForeignKey('address_id')]
    property Address: TAddress read GetAddress write SetAddress;
  end;
```

### Fluent Mapping Example

```pascal
unit MyFluentEntities;

interface

uses
  Dext.Entity, Dext.Entity.Mapping, Dext.Types.Nullable, Dext.Types.Lazy, Dext.Persistence;

type
  TUser = class
  private
    FId: Integer;
    FFullName: string;
    // ...
  public
    property Id: Integer read FId write FId;
    property FullName: string read FFullName write FFullName;
    // ...
  end;

procedure RegisterMappings(ModelBuilder: TModelBuilder);

implementation

procedure RegisterMappings(ModelBuilder: TModelBuilder);
begin
  ModelBuilder.Entity<TUser>
    .Table('users')
    .HasKey('Id')
    .Prop('FullName').Column('full_name')
    .Prop('Address').HasForeignKey('address_id');
end;

end.
```

### Metadata Classes (TPropExpression)

The generator also creates metadata classes (suffixed with `Entity`) to support type-safe queries:

```pascal
  UserEntity = class
  public
    class var Id: TPropExpression;
    class var FullName: TPropExpression;
    class var AddressId: TPropExpression;
    class var Address: TPropExpression;

    class constructor Create;
  end;
```

These allow you to write queries like:

```pascal
  // Select * From Users Where FullName = 'John'
  Query.Where(UserEntity.FullName.Eq('John'));
  // or
  Query.Where(UserEntity.FullName = 'John');
```

## Supported Databases

Currently, the Scaffolding tool relies on FireDAC's metadata capabilities (`TFDMetaInfoQuery`). It has been tested with:
- SQLite
- PostgreSQL
- Firebird
- SQL Server
- (Planned) MySQL, Oracle

## Troubleshooting

- **"Meta data argument value must be specified"**: This usually happens with SQLite. The scaffolding engine includes retry logic to handle different FireDAC driver requirements for `ObjectName` vs `BaseObjectName`.
- **Memory Leaks**: Ensure you are not creating multiple `TFDConnection` wrappers or contexts without freeing them. The generated code uses interfaces (`ILazy<T>`) and records (`Nullable<T>`) to minimize memory management issues.
