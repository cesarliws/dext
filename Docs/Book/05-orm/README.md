# 5. ORM (Dext.Entity)

Dext.Entity is a full-featured ORM for Delphi with support for multiple databases.

## Chapters

1. [Getting Started](getting-started.md)
2. [Entities & Mapping](entities.md)
3. [Querying](querying.md)
4. [Smart Properties](smart-properties.md)
5. [JSON Queries](json-queries.md)
6. [Specifications](specifications.md)
7. [Relationships](relationships.md)
8. [Inheritance](inheritance.md)
9. [Migrations](migrations.md)
10. [Scaffolding](scaffolding.md)
11. [Multi-Tenancy](multi-tenancy.md)
12. [Raw SQL (FromSql)](raw-sql-from-sql.md)
13. [Stored Procedures](stored-procedures.md)
14. [Concurrency & Locking](locking.md)
15. [Transactions](transactions.md)
16. [Soft Delete](soft-delete.md)
17. [Multi-Mapping](nested-mapping.md)
18. [Batch Operations](batch-operations.md)

> 📦 **Examples**:
>
> - [Orm.EntityDemo](../../../Examples/Orm.EntityDemo/) (Standard)
> - [Orm.EntityStyles](../../../Examples/Orm.EntityStyles/) (Comparison: POCO vs Smart Properties)

## Quick Start

```pascal
// 1. Define Entity
type
  [Table('users')]
  TUser = class
  private
    FId: Integer;
    FName: string;
  public
    [PK, AutoInc]
    property Id: Integer read FId write FId;
    
    [Column('name')]
    property Name: string read FName write FName;
  end;

// 2. Create Context
type
  TAppContext = class(TDbContext)
  public
    function Users: IDbSet<TUser>;
  end;

// 3. Use It!
var
  Ctx: TAppContext;
  User: TUser;
begin
  Ctx := TAppContext.Create(Connection, Dialect);
  
  // Create
  User := TUser.Create;
  User.Name := 'John';
  Ctx.Users.Add(User);
  Ctx.SaveChanges;
  
  // Read
  User := Ctx.Users.Find(1);
  
  // Query
  var u := Prototype.Entity<TUser>;
  var ActiveUsers := Ctx.Users
    .Where(u.Name.Contains('John'))
    .ToList;
end;
```

## Supported Databases

| Database | Status |
|----------|--------|
| PostgreSQL | ✅ Stable |
| SQL Server | ✅ Stable |
| SQLite | ✅ Stable |
| Firebird | ✅ Stable |
| MySQL / MariaDB | ✅ Stable |
| Oracle | 🟡 Beta |

---

[← API Features](../04-api-features/README.md) | [Next: Getting Started →](getting-started.md)
