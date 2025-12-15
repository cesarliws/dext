# 🗄️ Dext Entity ORM - Database Dialects

Dext Entity ORM supports multiple database engines through **Dialects**. A Dialect abstracts the differences in SQL syntax, data types, and specific features of each database.

## ✅ Supported Dialects

The following dialects are built-in and ready to use:

| Database | Class Name | Status | Features |
| :--- | :--- | :--- | :--- |
| **SQLite** | `TSQLiteDialect` | ✅ Validated | AutoInc, Paging, Boolean (0/1) |
| **PostgreSQL** | `TPostgreSQLDialect` | ✅ Validated | Serial, Paging, Boolean (TRUE/FALSE), UUID |
| **Firebird 3.0+** | `TFirebirdDialect` | ✅ Validated | Identity, Paging (OFFSET/FETCH), Boolean (TRUE/FALSE) |
| **SQL Server** | `TSQLServerDialect` | ✅ Validated | Identity, Paging (OFFSET/FETCH), UUID |
| **Oracle 12c+** | `TOracleDialect` | ⚠️ Unit Tested | Identity, Paging, UUID (VARCHAR2) |
| **MySQL / MariaDB** | `TMySQLDialect` | ⚠️ Unit Tested | AutoIncrement, Paging (LIMIT), UUID (CHAR) |

---

## 🛠️ Customizing a Dialect

If the built-in dialects do not meet your specific needs (e.g., you need to support a legacy version of Firebird or a specific company convention), you can easily extend an existing dialect or create a new one.

### Example: Customizing Firebird Dialect

Suppose you want to use **Firebird 2.5**, which does not support the `BOOLEAN` type (native in 3.0+) and uses a different paging syntax (`ROWS x TO y`). You can inherit from `TFirebirdDialect` (or `TBaseDialect`) and override the necessary methods.

```pascal
unit MyProject.Dialects;

interface

uses
  Dext.Entity.Dialects;

type
  TFirebird25Dialect = class(TFirebirdDialect)
  public
    // Override Boolean mapping to use CHAR(1) 'T'/'F' instead of TRUE/FALSE
    function BooleanToSQL(AValue: Boolean): string; override;
    
    // Override Paging to use ROWS syntax
    function GeneratePaging(ASkip, ATake: Integer): string; override;
  end;

implementation

uses
  System.SysUtils;

{ TFirebird25Dialect }

function TFirebird25Dialect.BooleanToSQL(AValue: Boolean): string;
begin
  if AValue then Result := '''T''' else Result := '''F''';
end;

function TFirebird25Dialect.GeneratePaging(ASkip, ATake: Integer): string;
begin
  // Firebird 2.5: ROWS <start> TO <end>
  // Note: 1-based index usually
  Result := Format('ROWS %d TO %d', [ASkip + 1, ASkip + ATake]);
end;

end.
```

### Using Your Custom Dialect

To use your custom dialect, simply instantiate it when creating the `TDbContext`.

```pascal
uses
  MyProject.Dialects,
  Dext.Entity;

var
  Context: IDbContext;
begin
  // Inject your custom dialect
  Context := TDbContext.Create(
    MyConnection, 
    TFirebird25Dialect.Create // <--- Here
  );
  
  // Now the ORM will generate SQL compatible with Firebird 2.5
end;
```

This flexibility allows you to adapt the ORM to any database version or specific requirement without waiting for official framework updates.
