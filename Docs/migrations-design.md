## Overview
Migrations allow the database schema to evolve over time alongside the application's data model. Instead of manually running SQL scripts, the ORM generates and manages these changes.

We support two architectural approaches for migrations:
1.  **Embedded (Pascal)**: Migrations are compiled into the application. Simple for small apps.
2.  **External (JSON)**: Migrations are stored as JSON files and executed by an external runner (`dext console`). Ideal for CI/CD and enterprise environments where the application should not have DDL permissions.

## Core Components

### 1. Migration Metadata (`IMigration`)
An interface representing a single migration step.

```pascal
type
  IMigration = interface
    ['{...}']
    function GetId: string; // Timestamp_Name (e.g., '20231027100000_InitialCreate')
    procedure Up(Builder: TSchemaBuilder);
    procedure Down(Builder: TSchemaBuilder);
  end;
```

### 2. Schema Builder (`TSchemaBuilder`)
A fluent API to define schema changes abstractly, which the Dialect translates to SQL.
```pascal
Builder.CreateTable('Users')
  .Column('Id', TColumnType.Integer).NotNull.PrimaryKey.Identity
  .Column('Name', TColumnType.String, 100).NotNull
  .ForeignKey('GroupId', 'Groups', 'Id');
```

### 3. Model Snapshot (`TModelSnapshot`)
To detect changes, we need to compare the *current* code model against the *last applied* model.
- **Approach**: **Snapshot**. When adding a migration, we compare the `DbContext` model with the `LastKnownSnapshot`. The difference generates the `Up`/`Down` methods (or JSON operations).

### 4. Migration History Table
A table in the database (e.g., `__DextMigrations`) tracking applied migrations.
- `MigrationId` (PK, String)
- `AppliedOn` (DateTime)
- `ProductVersion` (String)

---

## Migration Formats

We support two formats for storing migrations. This is configurable via `Dext.config.json` or `TDbContext` options.

### Format A: Pascal Units (Embedded)
The traditional Delphi approach. Each migration is a unit compiled into the executable.
*   **Pros**: Strong typing, full language power, no external dependencies.
*   **Cons**: Requires recompilation, application needs DDL permissions.

```pascal
unit Migrations.M20231027100000_InitialCreate;

procedure Up(Builder: TSchemaBuilder);
begin
  Builder.CreateTable('Users')...
end;
```

### Format B: JSON Files (External)
Migrations are stored as language-agnostic JSON files.
*   **Pros**: No recompilation, safe for CI/CD, readable by other tools.
*   **Cons**: Less flexible than code (no custom logic).

**Example (`20251205060000_CreateUsers.json`):**
```json
{
  "id": "20251205060000",
  "description": "Create Users Table",
  "author": "Cezar",
  "operations": [
    {
      "op": "create_table",
      "name": "Users",
      "columns": [
        { "name": "Id", "type": "GUID", "pk": true },
        { "name": "Email", "type": "VARCHAR", "length": 255, "nullable": false },
        { "name": "CreatedAt", "type": "TIMESTAMP", "default": "CURRENT_TIMESTAMP" }
      ]
    },
    {
      "op": "create_index",
      "table": "Users",
      "name": "IX_Users_Email",
      "columns": ["Email"],
      "unique": true
    }
  ]
}
```

**Supported Operations (`op`):**
*   `create_table`: Creates a new table. Requires `name` and `columns`.
*   `drop_table`: Drops a table. Requires `name`.
*   `add_column`: Adds a column to an existing table. Requires `table` and `column` definition.
*   `drop_column`: Drops a column. Requires `table` and `name`.
*   `alter_column`: Modifies a column. Requires `table` and `column` definition.
*   `add_fk`: Adds a foreign key. Requires `table`, `name`, `columns`, `ref_table`, `ref_columns`.
*   `drop_fk`: Drops a foreign key. Requires `table` and `name`.
*   `create_index`: Creates an index. Requires `table`, `name`, `columns`. Optional `unique`.
*   `drop_index`: Drops an index. Requires `table` and `name`.
*   `sql`: Executes raw SQL. Requires `sql`.

---

## Runtime Safety (The "Handshake")

To ensure the application runs against a compatible database schema without needing to run migrations itself:

1.  **Build Time**: The compiler/build tool injects the `ExpectedSchemaHash` or `LastMigrationId` into the executable resource.
2.  **Startup**: The application checks the `__DextMigrations` table.
    - If `LastAppliedMigration < ExpectedMigration`: Error (Database outdated).
    - If `LastAppliedMigration > ExpectedMigration`: Warning/Error (Application outdated).
    - If `LastAppliedMigration == ExpectedMigration`: Success.

```pascal
procedure TMyAppContext.OnStart;
begin
  // Validates schema compatibility without altering the database
  if not Migrator.ValidateSchemaCompatibility('20251205060000_LastKnownMigration') then
    raise Exception.Create('Database schema is incompatible with this application version.');
end;
```

---

## Workflow (CLI / Tooling)

### 1. `dext migrations add <Name>`
- Compiles/Loads the project.
- Builds current `TModel`.
- Loads `LastSnapshot`.
- Calculates Diff.
- **Config Check**:
    - If `Format=Pascal`: Generates `Migrations\YYYYMMDDHHMMSS_Name.pas`.
    - If `Format=JSON`: Generates `Migrations\YYYYMMDDHHMMSS_Name.json`.
- Updates `LastSnapshot`.

### 2. `dext migrate:up` (External Runner)
- Reads migration source (Folder of JSONs or DLL/BPL).
- Connects to DB (Admin credentials).
- Applies pending migrations.
- Updates `__DextMigrations`.

**Usage:**
```bash
# Run migrations from a specific directory containing JSON files
dext migrate:up --source "C:\Path\To\Migrations"
```

### 3. Application Startup
- Connects to DB (App credentials - DML only).
- Performs "Handshake" using `Migrator.ValidateSchemaCompatibility`.
- Starts if compatible.

---

## Implementation Status

### Phase 1: JSON Support
- [x] Define JSON Schema for all `TMigrationOperation` types.
- [x] Implement `TMigrationJsonSerializer` and `TMigrationJsonDeserializer`.
- [x] Update `TMigrator` to accept a `IMigrationSource` (Abstract provider for Pascal/JSON).

### Phase 2: External Runner
- [x] Create `dext console` command `migrate:run` (implemented as `migrate:up`).
- [x] Implement logic to read JSON files and execute against a connection string (`TJsonMigrationLoader`).

### Phase 3: Safety & Tooling
- [x] Implement `ValidateSchemaCompatibility`.
- [ ] Add configuration options to toggle between formats.
