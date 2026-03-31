# PR 2 of 3 — Entity: FireDAC `TValue` hydration + hydration error diagnostics

**Compare:** https://github.com/cesarliws/dext/compare/main...usofm:pr/02-firedac-hydration-diagnostics?expand=1

**Merge order:** Independent of PR 1. **PR 3 should be merged after PR 2** (or PR 3 branch rebased onto `main` after PR 2 lands).

## Suggested title

`fix(entity): FireDAC field→TValue mapping and detailed hydration errors`

---

## Bug A — `EVariantTypeCastError` in `Hydrate` / `TFireDACReader.GetValue`

### Example error

```
EVariantTypeCastError: Invalid variant type conversion
TDbSet<TMyEntity>.HydrateTarget
TValue.FromVariant
TFireDACReader.GetValue
```

### Example context

- **PostgreSQL** (or others): `NUMERIC`, `BIGINT`, `BOOLEAN`, binary types, etc.
- Reader used `TValue.FromVariant(Field.Value)` for anything outside a small `case` — many FireDAC variant forms are not RTTI-convertible.

### Fix

- **`FireDACFieldToTValue`:** explicit handling for BCD/FMTBcd, `Int64`, booleans, bytes, fixed/wide char, currency, `ftTimeStampOffset` (when `DEXT_DELPHI102_UP`), null → `TValue.Empty`.
- **Fallback:** `EVariantTypeCastError` → `Field.AsString`.
- **`ExecuteScalar`:** uses the same helper as the reader.

**File:** `Sources/Data/Dext.Entity.Drivers.FireDAC.pas`

---

## Bug B — Hard-to-debug hydration failures

### Before

```
Error hydrating TMyEntity.SomeProp: ...
```

### After (example)

```
Hydration failed: entity=TMyEntity | column="tier" | property="Tier" | PropertyType=System.string | TypeKind=tkUString | incomingTValue=... | EVariantTypeCastError: ...
```

### Compiler constraints

- **`E2506`:** helpers used from `TDbSet<T>.HydrateTarget` are **forward-declared** in the unit interface.
- **`TValueKind` / `GetEnumName`:** use explicit `case AVal.Kind of` labels instead of `TypeInfo(TValueKind)`.

**File:** `Sources/Data/Dext.Entity.DbSet.pas`

---

## Files in this PR

- `Sources/Data/Dext.Entity.Drivers.FireDAC.pas`
- `Sources/Data/Dext.Entity.DbSet.pas`

---

## Verify

Load entities backed by PG types that previously failed in `GetValue`. Force a mapping error and confirm the new exception lists column, property, and types.
