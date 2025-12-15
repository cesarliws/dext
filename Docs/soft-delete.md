# Dext ORM - Soft Delete Support

Dext ORM supports **Soft Deletes**, a feature that marks entities as deleted in the database without physically removing the record. This allows for data recovery, audit trails, and safer deletion operations.

## Enabling Soft Delete

To enable Soft Delete for an entity, apply the `[SoftDelete]` attribute to the class.

### 1. Basic Usage (Boolean Flag)

By default, `[SoftDelete]` assumes a boolean column where `1` (True) means deleted and `0` (False) means active.

You must specify the name of the **property** (or column) that holds the deletion status.

```pascal
type
  [Table('tasks')]
  [SoftDelete('IsDeleted')] // Maps to IsDeleted property
  TTask = class
  private
    FId: Integer;
    FTitle: string;
    FIsDeleted: Boolean;
  public
    [PK, AutoInc]
    property Id: Integer read FId write FId;
    property Title: string read FTitle write FTitle;

    [Column('is_deleted')]
    property IsDeleted: Boolean read FIsDeleted write FIsDeleted;
  end;
```

### 2. Custom Values (Status Enum / Integer)

You can specify custom values for the deleted and not-deleted states. This is useful if you use an integer status column (e.g., `0` = Active, `99` = Deleted).

```pascal
[SoftDelete('Status', 99, 0)] // Deleted = 99, Not Deleted = 0
TUser = class
  // ...
  property Status: Integer read FStatus write FStatus;
end;
```

## Working with Soft Deleted Entities

### Deleting (Soft)

Use the standard `Remove` method. The ORM detects the attribute and performs an `UPDATE` instead of specific `DELETE`.

```pascal
Context.Entities<TTask>.Remove(MyTask);
Context.SaveChanges;
// Executes: UPDATE tasks SET is_deleted = 1 WHERE id = :p0
```

> **Important**: After `SaveChanges`, the entity is removed from the `IdentityMap` and destroyed (freed) from memory to prevent memory leaks, ensuring the application state remains consistent with the "deleted" logical state.

### Hard Delete (Physical Removal)

If you need to permanently remove a record (bypassing Soft Delete rules), use `HardDelete`.

```pascal
Context.Entities<TTask>.HardDelete(MyTask);
// Executes: DELETE FROM tasks WHERE id = :p0
```

### Querying

By default, **Soft Deleted entities are excluded** from all queries (`Find`, `List`, `Query`, `Count`, `Any`).

```pascal
// Returns only active tasks (IsDeleted = 0)
var Tasks := Context.Entities<TTask>.List;
```

To include deleted entities (e.g., for an admin generic view), use `IgnoreQueryFilters`:

```pascal
// Returns ALL tasks (Active + Deleted)
var AllTasks := Context.Entities<TTask>.IgnoreQueryFilters.List;
```

To fetch **only** deleted entities (e.g., Recyle Bin):

```pascal
var DeletedTasks := Context.Entities<TTask>.OnlyDeleted.List;
```

### Restoring

You can restore a soft-deleted entity using `Restore`.

```pascal
// 1. Find the deleted entity
var Task := Context.Entities<TTask>
  .IgnoreQueryFilters
  .Find(DeletedId);

// 2. Restore it
if Task <> nil then
  Context.Entities<TTask>.Restore(Task);
  // Executes immediately: UPDATE tasks SET is_deleted = 0 WHERE id = ...
```

## Implementation Details

- **Global Filters**: The exclusion of deleted records is implemented via Global Query Filters in the `TSqlGenerator`.
- **IdentityMap**: Soft deleted entities are removed from the internal cache to ensure they don't consume memory or appear in subsequent lookups unless explicitly requested via new queries.
- **Cascading**: Soft Delete currently does **not** automatically cascade to child entities. Keep this in mind for aggregate roots.

## Common Issues & Fixes

### Type Casting Errors
The ORM handles conversion between the Attribute definition (Variant) and the Property Type (Boolean/Integer) automatically. Ensure your property type matches the logical intent of the Soft Delete values.
