# Dext Entity ORM - Migrations Guide

The Dext Entity ORM includes a powerful Code-First Migrations system that allows you to evolve your database schema over time by modifying your Delphi entity classes.

## Overview

Migrations provide a way to:
1.  **Generate** schema changes automatically by comparing your current Entity Model with a previous snapshot.
2.  **Apply** these changes to the database in a controlled, versioned manner.
3.  **Track** which migrations have been applied to each database environment.

## Getting Started

### 1. Define Your Entities

Start by defining your entities as usual:

```pascal
[Table('Users')]
TUser = class
private
  FId: Integer;
  FName: string;
  FEmail: string;
public
  [Column('Id'), PrimaryKey, AutoInc]
  property Id: Integer read FId write FId;
  
  [Column('Name'), Required, MaxLength(100)]
  property Name: string read FName write FName;
  
  [Column('Email'), MaxLength(150)]
  property Email: string read FEmail write FEmail;
end;
```

### 2. Register Migrations

Migrations are Pascal units that implement the `IMigration` interface. They are typically generated automatically, but you can also create them manually.

Example of a Migration Unit:

```pascal
unit Migrations.InitialCreate;

interface

uses
  Dext.Entity.Migrations;

type
  TMigration_20231001_Initial = class(TInterfacedObject, IMigration)
  public
    function GetId: string;
    procedure Up(Builder: TSchemaBuilder);
    procedure Down(Builder: TSchemaBuilder);
  end;

implementation

function TMigration_20231001_Initial.GetId: string;
begin
  Result := '20231001_Initial'; // Unique ID (Timestamp + Name)
end;

procedure TMigration_20231001_Initial.Up(Builder: TSchemaBuilder);
begin
  Builder.CreateTable('Users', procedure(T: TTableBuilder)
  begin
    T.Column('Id', 'INTEGER').PrimaryKey.Identity;
    T.Column('Name', 'VARCHAR', 100).NotNull;
    T.Column('Email', 'VARCHAR', 150);
  end);
  
  Builder.CreateIndex('Users', 'IX_Users_Email', ['Email'], True);
end;

procedure TMigration_20231001_Initial.Down(Builder: TSchemaBuilder);
begin
  Builder.DropTable('Users');
end;

initialization
  RegisterMigration(TMigration_20231001_Initial.Create);

end.
```

### 3. Running Migrations

To apply pending migrations to your database, use the `TMigrator` class. This is usually done at application startup or via a dedicated administration tool.

```pascal
uses
  Dext.Entity.Migrations.Runner;

procedure ApplyMigrations(Context: IDbContext);
var
  Migrator: TMigrator;
begin
  Migrator := TMigrator.Create(Context);
  try
    Migrator.Migrate;
  finally
    Migrator.Free;
  end;
end;
```

The `Migrate` method will:
1.  Check if the `__DextMigrations` history table exists (and create it if not).
2.  Query the history table to see which migrations have already been applied.
3.  Execute the `Up` method of any pending migrations in chronological order.
4.  Record the applied migrations in the history table.

## Schema Builder API

The `TSchemaBuilder` provides a fluent API to define database operations in a dialect-agnostic way.

### Creating Tables

```pascal
Builder.CreateTable('Products', procedure(T: TTableBuilder)
begin
  T.Column('Id', 'INTEGER').PrimaryKey.Identity;
  T.Column('Name', 'VARCHAR', 200).NotNull;
  T.Column('Price', 'DECIMAL').Precision(18, 2);
  T.Column('IsActive', 'BOOLEAN').Default('1');
end);
```

### Modifying Tables

```pascal
// Add a new column
Builder.AddColumn('Products', 'Stock', 'INTEGER', 0, False); // Name, Type, Length, Nullable

// Drop a column
Builder.DropColumn('Products', 'OldColumn');

// Create an Index
Builder.CreateIndex('Products', 'IX_Products_Name', ['Name']);
```

### Raw SQL

If you need to execute specific SQL that isn't covered by the builder:

```pascal
Builder.Sql('UPDATE Products SET Stock = 0 WHERE Stock IS NULL');
```

## Architecture

*   **`Dext.Entity.Migrations`**: Core interfaces and Registry.
*   **`Dext.Entity.Migrations.Builder`**: Fluent API (`TSchemaBuilder`) for defining operations.
*   **`Dext.Entity.Migrations.Operations`**: Internal representation of schema changes (`TCreateTableOperation`, etc.).
*   **`Dext.Entity.Migrations.Runner`**: Logic to apply migrations to the database (`TMigrator`).
*   **`Dext.Entity.Migrations.Generator`**: (Internal) Generates Pascal code from operations.
*   **`Dext.Entity.Migrations.Differ`**: (Internal) Compares models to detect changes.

## Future Plans

*   **CLI Tool**: A command-line tool to automatically generate migration units by comparing your code with the database state.
*   **Down Migration Generation**: Automatic generation of `Down` logic where possible.
