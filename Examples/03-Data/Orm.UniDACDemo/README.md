# UniDAC Demo

Console application demonstrating Dext ORM operations using **UniDAC** as the
database driver backend (instead of the default FireDAC).

## Requirements

- Delphi 10.4 Sydney or later
- [UniDAC](https://www.devart.com/unidac/) by DevArt (installed)
- Dext framework (Sources/ on the library/search path)

## How to Build

1. Add `DEXT_USE_UNIDAC` to **Project Options > Delphi Compiler > Conditional defines**
2. Add the Dext `Sources/` directory tree to the project search path
   (or use the `set_env.ps1` script to set `SEARCH_PATH` environment variable)
3. Add required UniDAC provider units to the search path
   (e.g. `SQLiteUniProvider` for the default SQLite demo)
4. Compile and run

## Switching Database Providers

Edit `UniDACDemo.DbConfig.pas` to change the connection:

| Provider   | UniDAC Unit           |
|------------|-----------------------|
| SQLite     | `SQLiteUniProvider`   |
| PostgreSQL | `PostgreSQLUniProvider` |
| MySQL      | `MySQLUniProvider`    |
| SQL Server | `SQLServerUniProvider` |
| Oracle     | `OracleUniProvider`   |
| Firebird   | `InterBaseUniProvider` |

## What It Tests

- **INSERT** - Create entities and persist them
- **SELECT ALL** - Retrieve all records as a list
- **UPDATE** - Modify an existing record
- **DELETE** - Remove a record
- **VERIFY** - Confirm final state matches expectations

## Architecture

```
Orm.UniDACDemo.dpr          -- Program entry point (defines DEXT_USE_UNIDAC)
UniDACDemo.DbConfig.pas     -- Database connection configuration
UniDACDemo.Entities.pas    -- Entity definitions (TCustomer, TOrder) with relationships
UniDACDemo.Tests.Base.pas  -- Base test class (creates/destroys TDbContext)
UniDACDemo.Tests.CRUD.pas  -- CRUD test procedures
```

## Entity Style

Uses **Smart Properties** (`IntType`, `StringType`, `DoubleType`) with
Dext attributes (`[PK, AutoInc]`, `[Required]`, `[MaxLength]`,
`[ForeignKey]`, `[BelongsTo]`, `[HasMany]`) — the recommended style
per the Dext ORM documentation.

## How It Works

When `DEXT_USE_UNIDAC` is defined:

- `Dext.Entity.Setup.pas` switches from FireDAC to UniDAC units at compile time
- `TDbContextOptions.BuildConnection` routes to `BuildUniDACConnection`
- UniDAC's `TUniConnection` replaces `TFDConnection` internally
- The ORM layer (DbSet, SQL generator, dialects, Smart Properties, etc.) remains unchanged