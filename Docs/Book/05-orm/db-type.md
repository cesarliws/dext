# Database Type Control (DbType)

Dext.Entity allows you to explicitly control the database data type used for parameters and column mapping. This is particularly useful when you need to distinguish between different types that map to the same Delphi type (e.g., `TDateTime` mapping to `Date` vs `DateTime` in the database).

## The [DbType] Attribute

By using the `[DbType]` attribute, you tell the ORM exactly which `TFieldType` should be used when creating parameters for SQL commands.

### Example: Date vs DateTime

By default, a `TDateTime` property might be mapped to a `DateTime` or `TimeStamp` in the database. If you want to ensure it's treated as a pure `Date`:

```pascal
type
  [Table('Events')]
  TEvent = class
  public
    [PK, AutoInc]
    property Id: Integer read FId write FId;
    
    [DbType(ftDate)]
    property RegistrationDate: TDateTime read FDate write FDate;
  end;
```

### Supported Types

Most standard `TFieldType` values are supported, including:

- `ftDate`, `ftTime`, `ftDateTime`, `ftTimeStamp`
- `ftString`, `ftWideString`, `ftMemo`, `ftWideMemo`
- `ftInteger`, `ftSmallint`, `ftLargeint`, `ftBCD`, `ftFMTBcd`
- `ftBoolean`
- `ftBlob`, `ftGuid`

## High-Precision Decimals (`TBcd` & `ftFMTBcd`)

For financial and tax applications requiring high numeric precision beyond the 4 decimal places of `Currency` and avoiding `Double` floating-point precision loss, Dext provides first-class support for `TBcd` and `ftFMTBcd`:

```pascal
type
  [Table('Products')]
  TProduct = class
  private
    FPrice: TBcd;
  public
    [PK, AutoInc]
    property Id: Int64 read FId write FId;

    // Native TBcd support with custom precision (e.g. 28 digits, 10 decimals)
    [DbType(ftFMTBcd), Precision(28, 10)]
    property Price: TBcd read FPrice write FPrice;
  end;
```

> [!NOTE]
> The most efficient path for `TBcd` is FireDAC direct binary binding
> (`Param.AsFMTBCD := Bcd`). Conversions through `String`, `Currency`,
> `Double`, or `Variant` remain available for compatibility, but may perform
> intermediate formatting, parsing, or numeric conversion.

## Fluent Mapping

If you prefer using Fluent Mapping instead of attributes, you can use `HasDbType` and `HasPrecision`:

```pascal
modelBuilder.Entity<TProduct>()
  .Prop('Price')
    .HasDbType(ftFMTBcd)
    .HasPrecision(28, 10);
```

## Legacy Pagination

Dext.Entity automatically handles pagination for different database engines. For newer databases, it uses the standard `OFFSET ... FETCH NEXT` syntax. 

### Modern Syntax (PostgreSQL, SQL Server 2012+, Oracle 12c+, Firebird 3.0+)

```sql
SELECT * FROM Users 
ORDER BY Id 
OFFSET 10 ROWS FETCH NEXT 10 ROWS ONLY
```

### Legacy Support (Oracle 11g, SQL Server 2008)

For older versions of Oracle, Dext automatically wraps your query using a `ROWNUM` strategy:

```sql
SELECT * FROM (
  SELECT a.*, ROWNUM rnum 
  FROM (SELECT * FROM Users ORDER BY Id) a 
  WHERE ROWNUM <= 20
) WHERE rnum > 10
```

This is handled transparently by the `TOracleDialect`. You don't need to change your application code; just use `.Skip(x).Take(y)` and Dext will generate the correct SQL for your dialect.

### Manual Dialect Configuration

If automatic detection fails (common when using complex connection strings), you can force the dialect in your `Startup`:

```pascal
procedure TStartup.ConfigureDatabase(Options: TDbContextOptions);
begin
  Options
    .UseSQLServer(Configuration.Get('ConnectionStrings:Default'))
    .UseDialect(ddSQLServer); // Force the SQL Server dialect
end;
```
