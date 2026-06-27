# ORM: Getting Started

Learn how to create your first entity and database context.

> 📦 **Example**: [Web.EventHub](../../../Examples/Web.EventHub/)

## 1. Create an Entity

```pascal
unit MyProject.Domain.Entities;

interface

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

implementation

end.
```

> [!IMPORTANT]
> Use `Dext.Entity` facade for attributes — **NOT** `Dext.Entity.Attributes` directly.  
> Avoid redundant `[Column]` attributes; Dext maps properties automatically via Naming Strategy.

## 2. Create a DbContext

```pascal
unit MyProject.Data.Context;

interface

uses
  Dext.Entity.Core,    // IDbSet<T>, TDbContext - REQUIRED for generics
  Dext.Entity;         // Facade

type
  TAppDbContext = class(TDbContext)
  private
    function GetUsers: IDbSet<TUser>;
  public
    property Users: IDbSet<TUser> read GetUsers;
  end;

implementation

uses
  MyProject.Domain.Entities;

function TAppDbContext.GetUsers: IDbSet<TUser>;
begin
  Result := Entities<TUser>;
end;

end.
```

> [!IMPORTANT]
> Since `IDbSet<T>` is generic, you **MUST** add `Dext.Entity.Core` to uses.  
> The facade `Dext.Entity` does **NOT** export generic types.  
> Use **Properties** to expose `IDbSet<T>` (recommended) — this avoids syntactic ambiguities.

## 3. Configure Connection (via DI)

The recommended approach is to register the DbContext via DI in your Startup:

```pascal
procedure TStartup.ConfigureServices(const Services: TDextServices; const Configuration: IConfiguration);
begin
  Services
    .AddDbContext<TAppDbContext>(ConfigureDatabase)
    .AddScoped<IUserService, TUserService>;
end;

procedure TStartup.ConfigureDatabase(Options: TDbContextOptions);
begin
  Options
    .UseSQLite('App.db')
    .WithPooling(True); // REQUIRED for production Web APIs
end;
```

Supported database drivers and connections:
- `.UseSQLite('filename.db')`
- `.UsePostgreSQL('connection-string')`
- `.UseMySQL('connection-string')`
- `.UseSQLServer('connection-string')`
- `.UseFirebird('connection-string')`
- `.UseOracle('connection-string')`
- `.UseConnectionDef('nome-def-firedac')` (Uses a global connection definition pre-registered in FireDAC)

### 3.1. Using UseConnectionDef and FireDAC Pooling

When using `.UseConnectionDef('NameDef')`, Dext automatically resolves the SQL dialect based on the driver configured inside FireDAC. Additionally, if the FireDAC connection definition has pooling enabled (`Pooled=True`), Dext natively detects it and inherits that setting:

```pascal
procedure TStartup.ConfigureDatabase(Options: TDbContextOptions);
begin
  Options
    .UseConnectionDef('MyConnectionFB')
    .WithPooling(True); // Enables reusing connections managed by FireDAC
end;
```

### 3.2. Dialect Configuration

Dext attempts to infer the SQL dialect automatically based on the FireDAC DriverID. If you are using a custom Connection String or if detection fails, you can force the dialect manually:

```pascal
procedure TStartup.ConfigureDatabase(Options: TDbContextOptions);
begin
  Options
    .UseSQLServer(Configuration.Get('ConnectionStrings:Default'))
    .UseDialect(ddSQLServer) // Optional if detection fails
    .WithPooling(True);
end;
```

> [!TIP]
> For **SQL Server**, Dext uses `TSQLServerDialect` by default, which is optimized for 2012+ versions. If you are using a legacy version (2008), paging behavior (Skip/Take) may require special attention.

> [!WARNING]
> **Connection Pooling**: Web APIs are multithreaded. **ALWAYS** enable pooling via `.WithPooling(True)` to avoid connection exhaustion.

### 3.3. Bulk Batch Size

By default, bulk operations (`PersistAddRange`, `PersistUpdateRange`, and `PersistRemoveRange`) are chunked in batches of 100 records at a time to avoid exceeding database driver parameter limits (e.g. FireDAC) or excessive network packet size. You can customize this size to suit your environment:

```pascal
procedure TStartup.ConfigureDatabase(Options: TDbContextOptions);
begin
  Options
    .UsePostgreSQL(Configuration.Get('ConnectionStrings:Default'))
    .WithBulkBatchSize(250) // Sets the bulk batch size to 250 records
    .WithPooling(True);
end;
```


## 4. Create Tables

```pascal
Db.EnsureCreated;   // Returns True if schema was created (function: Boolean)
```

## 5. CRUD Operations

### Create

```pascal
var User := TUser.Create;
User.Name := 'John Doe';
User.Email := 'john@example.com';

Db.Users.Add(User);
Db.SaveChanges;

// ✅ User.Id is auto-populated (AutoInc) — no need to query DB!
WriteLn('Created user with ID: ', User.Id);
```

### Read

```pascal
// Find by ID
var User := Db.Users.Find(1);

// Get all
var AllUsers := Db.Users.ToList;

// Query with Smart Properties (recommended)
var u := TUser.Props;
var JohnUsers := Db.Users
  .Where(u.Name.StartsWith('John'))
  .ToList;
```

### Update

```pascal
var User := Db.Users.Find(1);
User.Name := 'Jane Doe';
Db.Users.Update(User);  // ✅ Force State = Modified
Db.SaveChanges;
```

> [!WARNING]
> Always call `Db.Users.Update(Entity)` **before** `SaveChanges` for updates. Auto-tracking can fail silently for detached entities.

### Delete

```pascal
var User := Db.Users.Find(1);
Db.Users.Remove(User);
Db.SaveChanges;
```

## 6. Database Seeding

Seed data in the `.dpr` **before** `App.Run`:

```pascal
class procedure TDbSeeder.Seed(const Provider: IServiceProvider);
begin
  var Scope := Provider.CreateScope;
  try
    var Db := Scope.ServiceProvider.GetService(TAppDbContext) as TAppDbContext;

    if Db.EnsureCreated then
    begin
      // Use .Any to check existence (avoids loading all records)
      if not Db.Users.QueryAll.Any then
      begin
        var Admin := TUser.Create;
        Admin.Name := 'Admin';
        Admin.Email := 'admin@example.com';
        Db.Users.Add(Admin);
        Db.SaveChanges;
      end;
    end;
  finally
    Scope := nil;
  end;
end;
```

---

[← ORM Overview](README.md) | [Next: Entities & Mapping →](entities.md)
