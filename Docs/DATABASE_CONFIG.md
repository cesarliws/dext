# Database Configuration Guide

## Overview

The `TDbConfig` class provides an easy way to switch between different database providers for testing and development.

## Quick Start

### 1. Basic Usage

```pascal
uses
  EntityDemo.DbConfig;

begin
  // Set the database provider
  TDbConfig.SetProvider(dpPostgreSQL);
  
  // Create connection and dialect
  var Conn := TDbConfig.CreateConnection;
  var Dialect := TDbConfig.CreateDialect;
  
  // Use with DbContext
  var Context := TMyDbContext.Create(Conn, Dialect);
  try
    Context.EnsureCreated;
    // ... your code
  finally
    Context.Free;
  end;
end;
```

### 2. Switching Databases

```pascal
// Use SQLite (default)
TDbConfig.SetProvider(dpSQLite);

// Use PostgreSQL
TDbConfig.SetProvider(dpPostgreSQL);

// Use Firebird
TDbConfig.SetProvider(dpFirebird);

// Use SQL Server
TDbConfig.SetProvider(dpSQLServer);
```

## Configuration

### SQLite

```pascal
// Default configuration
TDbConfig.ConfigureSQLite('test.db');

// Custom file
TDbConfig.ConfigureSQLite('C:\Data\myapp.db');
```

### PostgreSQL

```pascal
// Default configuration (localhost:5432/dext_test)
TDbConfig.ConfigurePostgreSQL;

// Custom configuration
TDbConfig.ConfigurePostgreSQL(
  'myserver.com',  // Host
  5432,            // Port
  'production_db', // Database
  'admin',         // Username
  'secret123'      // Password
);
```

### Firebird

```pascal
// Default configuration
TDbConfig.ConfigureFirebird('test.fdb');

// Custom configuration
TDbConfig.ConfigureFirebird(
  'C:\Data\myapp.fdb',  // Database file
  'SYSDBA',             // Username
  'masterkey'           // Password
);
```

## Testing Multiple Databases

### Example: Run Tests on All Databases

```pascal
program RunAllTests;

uses
  EntityDemo.DbConfig,
  EntityDemo.Tests.CRUD;

procedure RunTestsForProvider(AProvider: TDatabaseProvider);
begin
  WriteLn('');
  WriteLn('========================================');
  WriteLn('Testing with: ' + TDbConfig.GetProviderName);
  WriteLn('========================================');
  
  TDbConfig.SetProvider(AProvider);
  TDbConfig.ResetDatabase;
  
  // Run your tests
  var Test := TCRUDTest.Create;
  try
    Test.Run;
  finally
    Test.Free;
  end;
end;

begin
  try
    // Test SQLite
    RunTestsForProvider(dpSQLite);
    
    // Test PostgreSQL
    RunTestsForProvider(dpPostgreSQL);
    
    // Test Firebird
    RunTestsForProvider(dpFirebird);
    
    WriteLn('');
    WriteLn('✅ All database tests completed!');
  except
    on E: Exception do
      WriteLn('❌ Error: ' + E.Message);
  end;
  
  ReadLn;
end.
```

### Example: Environment-Based Configuration

```pascal
var
  DbProvider: string;
begin
  // Read from environment variable
  DbProvider := GetEnvironmentVariable('DB_PROVIDER');
  
  if DbProvider = 'postgresql' then
    TDbConfig.SetProvider(dpPostgreSQL)
  else if DbProvider = 'firebird' then
    TDbConfig.SetProvider(dpFirebird)
  else
    TDbConfig.SetProvider(dpSQLite); // Default
    
  // Configure from environment
  if TDbConfig.GetProvider = dpPostgreSQL then
  begin
    TDbConfig.ConfigurePostgreSQL(
      GetEnvironmentVariable('PG_HOST'),
      StrToIntDef(GetEnvironmentVariable('PG_PORT'), 5432),
      GetEnvironmentVariable('PG_DATABASE'),
      GetEnvironmentVariable('PG_USER'),
      GetEnvironmentVariable('PG_PASSWORD')
    );
  end;
end;
```

## Database-Specific Notes

### SQLite

- **File-based**: Database is stored in a single file
- **Best for**: Development, testing, mobile apps
- **Reset**: Deletes the database file

```pascal
TDbConfig.ConfigureSQLite('test.db');
TDbConfig.ResetDatabase; // Deletes test.db
```

### PostgreSQL

- **Server-based**: Requires PostgreSQL server running
- **Best for**: Production, cloud, microservices
- **Reset**: Drops all tables (via EnsureCreated)

```pascal
TDbConfig.ConfigurePostgreSQL('localhost', 5432, 'dext_test', 'postgres', 'postgres');
```

**Connection String Example**:
```
Server=localhost;Port=5432;Database=dext_test;User_Name=postgres;Password=postgres
```

### Firebird

- **File-based**: Database is stored in a .fdb file
- **Best for**: Enterprise, Brazilian market
- **Reset**: Deletes the database file

```pascal
TDbConfig.ConfigureFirebird('test.fdb', 'SYSDBA', 'masterkey');
```

#### Firebird Specifics & Limitations

1.  **Case Sensitivity**: Dext ORM uses quoted identifiers by default. In Firebird, quoted identifiers are **case-sensitive**.
    - `CREATE TABLE "Users"` -> Table `Users` (not `USERS`).
    - **Raw SQL**: You must use quotes in raw SQL: `SELECT * FROM "Users"`, not `SELECT * FROM Users` (which looks for `USERS`).
    - **Drop Table**: `DROP TABLE "Users"` works, `DROP TABLE Users` fails if created with quotes.

2.  **Table Existence**: Firebird does not support `CREATE TABLE IF NOT EXISTS` natively in all versions.
    - Dext ORM implements a `TableExists` check in `EnsureCreated` to handle this transparently.
    - When using `TDbConfig.ResetDatabase`, the `.fdb` file is deleted to ensure a clean state.

3.  **Database Creation**:
    - Dext ORM uses `OpenMode=OpenOrCreate` to automatically create the `.fdb` file if it doesn't exist.
    - Recommended Page Size: 16384 (set automatically by `TDbConfig`).

### SQL Server

```pascal
// Default configuration
TDbConfig.ConfigureSQLServer;

// Custom configuration
TDbConfig.ConfigureSQLServer(
  'localhost',     // Host
  'dext_test',     // Database
  'sa',            // Username
  'Password123!'   // Password
);
```

#### SQL Server Specifics

1.  **Identity Columns**: Dext maps `AutoInc` to `INT IDENTITY(1,1)`.
2.  **Paging**: Requires SQL Server 2012+ (`OFFSET ... FETCH`).
3.  **Drop Table**: Uses `DROP TABLE IF EXISTS` (SQL Server 2016+).

## API Reference

### TDatabaseProvider

```pascal
type
  TDatabaseProvider = (
    dpSQLite,
    dpPostgreSQL,
    dpFirebird,
    dpMySQL,      // Coming soon
    dpSQLServer,  // Coming soon
    dpOracle      // Coming soon
  );
```

### TDbConfig Methods

| Method | Description |
|--------|-------------|
| `GetProvider` | Get current database provider |
| `SetProvider(AProvider)` | Set current database provider |
| `CreateConnection` | Create connection for current provider |
| `CreateDialect` | Create SQL dialect for current provider |
| `GetProviderName` | Get provider name as string |
| `ConfigureSQLite(...)` | Configure SQLite connection |
| `ConfigurePostgreSQL(...)` | Configure PostgreSQL connection |
| `ConfigureFirebird(...)` | Configure Firebird connection |
| `ResetDatabase` | Drop and recreate database |

## Best Practices

### 1. Use in Test Setup

```pascal
procedure TMyTest.SetUp;
begin
  inherited;
  TDbConfig.ResetDatabase;
  FContext := TMyDbContext.Create(
    TDbConfig.CreateConnection,
    TDbConfig.CreateDialect
  );
  FContext.EnsureCreated;
end;
```

### 2. Parameterize Tests

```pascal
procedure RunTest(AProvider: TDatabaseProvider);
begin
  TDbConfig.SetProvider(AProvider);
  // ... test code
end;

// Run for all providers
RunTest(dpSQLite);
RunTest(dpPostgreSQL);
RunTest(dpFirebird);
```

### 3. CI/CD Integration

```yaml
# GitHub Actions example
- name: Test SQLite
  run: |
    set DB_PROVIDER=sqlite
    EntityDemo.exe

- name: Test PostgreSQL
  run: |
    set DB_PROVIDER=postgresql
    set PG_HOST=localhost
    set PG_DATABASE=test_db
    EntityDemo.exe
```

## Troubleshooting

### "Driver not found"

**Solution**: Ensure FireDAC driver is linked in your project:

```pascal
uses
  FireDAC.Phys.SQLite,  // For SQLite
  FireDAC.Phys.PG,      // For PostgreSQL
  FireDAC.Phys.FB;      // For Firebird
```

### "Cannot connect to PostgreSQL"

**Solution**: Check that:
1. PostgreSQL server is running
2. Connection parameters are correct
3. Database exists (create it first if needed)

```sql
-- Create database
CREATE DATABASE dext_test;
```

### "Firebird database locked"

**Solution**: Ensure no other processes are using the database file.

## See Also

- [ORM Roadmap](../Docs/ORM_ROADMAP.md)
- [Database Support](../Docs/DATABASE_SUPPORT.md)
- [Testing Guide](../Docs/TESTING.md)
