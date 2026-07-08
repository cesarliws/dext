# TEntityDataSet & Remote Synchronization

The `TEntityDataSet` is a high-performance Delphi dataset designed to bridge Object Pascal lists and ORM entities directly to standard VCL/FMX data-aware controls (such as `TDBGrid`).

---

## 1. Local Rollback (RejectChanges)

When performing local CRUD operations, `TEntityDataSet` tracks modifications using change log records (`TEntityChange`). 

You can discard uncommitted changes and revert to the original state:

```pascal
// Discard all insertions, deletions, and modifications in memory
FDataSet.RejectChanges;
```

### Rollback Behavior
- **ersInserted**: Inserted objects are removed from the dataset and freed.
- **ersDeleted**: Deleted objects are restored to their original index.
- **ersModified**: Modified properties are restored to their original values via RTTI.

---

## 2. Syncing Changes (AcceptChanges)

Once local changes are successfully committed to the database or remote server via a sync provider, clear the change log:

```pascal
FDataSet.AcceptChanges;
```
