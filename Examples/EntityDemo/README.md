# EntityDemo - Quick Start Guide

## Overview

The EntityDemo project demonstrates the Dext ORM capabilities with comprehensive tests. It now supports **easy switching between database providers** using `TDbConfig`.

## Running the Tests

### 1. Default (PostgreSQL)

The project is configured to use PostgreSQL by default. Simply run:

```bash
EntityDemo.exe
```

**Requirements**:
- PostgreSQL server running on `localhost:5432`
- Database: `postgres`
- Username: `postgres`
- Password: `root`

### 2. Switch to SQLite

Edit `EntityDemo.dpr` and uncomment the SQLite configuration:

```pascal
// Option 1: SQLite (Default - File-based, good for development)
TDbConfig.SetProvider(dpSQLite);
TDbConfig.ConfigureSQLite('test.db');

// Option 2: PostgreSQL (Server-based, production-ready)
// TDbConfig.SetProvider(dpPostgreSQL);
// TDbConfig.ConfigurePostgreSQL('localhost', 5432, 'postgres', 'postgres', 'root');
```

**No server required!** SQLite creates a local file.

### 3. Switch to Firebird

```pascal
// Option 3: Firebird (Brazilian market favorite)
TDbConfig.SetProvider(dpFirebird);
TDbConfig.ConfigureFirebird('test.fdb', 'SYSDBA', 'masterkey');

// Option 4: SQL Server (Enterprise)
TDbConfig.SetProvider(dpSQLServer);
TDbConfig.ConfigureSQLServer('localhost', 'dext_test', 'sa', 'Password123!');
```

## Test Suite

The demo includes **10 comprehensive test suites**:

1. **CRUD Tests** - Basic Create, Read, Update, Delete operations
2. **Relationships Tests** - Foreign Keys and navigation properties
3. **Advanced Query Tests** - Complex queries with filters and projections
4. **Composite Keys Tests** - Multi-column primary keys
5. **Explicit Loading Tests** - Manual loading of related entities
6. **Lazy Loading Tests** - Automatic loading on access
7. **Fluent API Tests** - Query builder and LINQ-style operations
8. **Lazy Execution Tests** - Deferred query execution
9. **Bulk Operations Tests** - Batch insert/update/delete
10. **Concurrency Tests** - Optimistic concurrency control

## Expected Output

```
🚀 Dext Entity ORM Demo Suite
=============================

📊 Database Provider: PostgreSQL

🔧 Setting up test with: PostgreSQL
🗑️  Dropping existing tables...
📦 Registering entities...
🏗️  Creating schema...
✅ Setup complete!

Running Test: TCRUDTest
🔍 Running CRUD Tests...
========================
🔍 Testing Insert...
   ✅ User inserted with ID: 1
   ✅ Name matches: John Doe
   ✅ Age matches: 30
...

✨ All tests completed.
```

## Database Configuration

### PostgreSQL Setup

1. Install PostgreSQL
2. Create database (or use default `postgres`)
3. Update credentials in `EntityDemo.dpr` if needed

### SQLite Setup

No setup required! Just switch the provider.

### Firebird Setup

1. Install Firebird
2. Database file will be created automatically

### SQL Server Setup

1. Install SQL Server (Express or Developer)
2. Create database `dext_test`
3. Enable TCP/IP protocol if needed
4. Update credentials in `EntityDemo.dpr`

## Customizing Tests

### Run Specific Tests

Edit `EntityDemo.dpr` and comment out tests you don't want to run:

```pascal
procedure RunAllTests;
begin
  // 1. CRUD Tests
  RunTest(TCRUDTest);
  
  // 2. Relationships Tests
  // RunTest(TRelationshipTest);  // Commented out
  
  // ... etc
end;
```

### Add Your Own Tests

1. Create a new unit inheriting from `TBaseTest`
2. Implement the `Run` method
3. Add to `RunAllTests`

Example:

```pascal
type
  TMyCustomTest = class(TBaseTest)
  public
    procedure Run; override;
  end;

procedure TMyCustomTest.Run;
begin
  Log('🔍 Running My Custom Test...');
  
  // Your test code here
  var User := TUser.Create;
  try
    User.Name := 'Test User';
    FContext.Entities<TUser>.Add(User);
    FContext.SaveChanges;
    
    AssertTrue(User.Id > 0, 'User created', 'Failed to create user');
  finally
    User.Free;
  end;
end;
```

## Troubleshooting

### "Cannot connect to PostgreSQL"

**Solution**: Check that:
1. PostgreSQL is running
2. Credentials are correct
3. Database exists

### "Driver not found"

**Solution**: Ensure FireDAC drivers are linked:
- SQLite: `FireDAC.Phys.SQLite`
- PostgreSQL: `FireDAC.Phys.PG`
- Firebird: `FireDAC.Phys.FB`

### "Table already exists"

**Solution**: The tests automatically drop tables before running. If you see this error, manually drop the tables or delete the SQLite file.

## Next Steps

- Read the [Nullable Support Guide](../../Docs/NULLABLE_SUPPORT.md)
- Check the [Database Configuration Guide](../../Docs/DATABASE_CONFIG.md)
- Review the [ORM Roadmap](../../Docs/ORM_ROADMAP.md)

## Contributing

Found a bug or want to add a test? Contributions are welcome!

1. Fork the repository
2. Create your feature branch
3. Add tests
4. Submit a pull request

---

*Happy Testing! 🚀*
