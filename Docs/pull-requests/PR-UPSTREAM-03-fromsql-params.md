# PR 3 of 3 — Entity: `FromSql` positional parameters (PostgreSQL / FireDAC)

**Compare:** https://github.com/cesarliws/dext/compare/main...usofm:pr/03-fromsql-sequential-params?expand=1

**Base recommendation:** Open this PR **after PR 2 is merged**, or set GitHub base to `pr/02-firedac-hydration-diagnostics` until then. The branch `pr/03-fromsql-sequential-params` is stacked on top of PR 2 so `main + PR2 + PR3` is consistent.

## Suggested title

`fix(entity): FromSql binds array to FireDAC :placeholders by order (BindSequentialParams)`

---

## Bug — `Parameter 'p0' not found` with raw SQL

### Example code

```pascal
FDb.UserRoles
  .FromSql(
    'SELECT ur.*, r.name AS role_name ' +
    'FROM core_user_roles ur ' +
    'JOIN core_roles r ON r.id = ur.role_id ' +
    'WHERE ur.user_id = :UserId',
    [AUserId])
  .ToList;
```

### Example error

```
EDatabaseError: Parameter 'p0' not found
```

### Root cause

FireDAC builds parameters from SQL names (`UserId` for `:UserId`).  
`TSqlQueryIterator` called `AddParam('p0', Value)` → `ParamByName('p0')` → not found.

---

## Fix

1. **`IDbCommand.BindSequentialParams(const AValues: TArray<TValue>)`** — bind `AValues[i]` to `Params[i]` in SQL order.
2. **`TSqlQueryIterator`** — `Cmd.BindSequentialParams(FParams)` instead of `p0`/`p1`.
3. **`TFireDACCommand`:** if `Params.Count = 0` but SQL contains `:` and values were passed, call **`Prepare`** then bind.
4. **`FireDACResolveParamsCollection`:** `AddParam('pK', …)` maps to `Params[K]` when the literal name is absent (stale binaries / legacy callers).
5. **`TFireDACPhysCommand`:** same sequential binding + resolver; **no silent ignore** when a named param is missing.

**Files:**  
`Dext.Entity.Drivers.Interfaces.pas`, `Dext.Entity.Drivers.FireDAC.pas`, `Dext.Entity.Drivers.FireDAC.Phys.pas`, `Dext.Entity.DbSet.pas`, `Dext.Entity.Core.pas` (XML on `FromSql`).

---

## Breaking note

Any custom `IDbCommand` implementation must add **`BindSequentialParams`**.

---

## Verify

Run `FromSql` with `:UserId` and `[id]`; confirm no `p0` error and correct rows. Optionally assert parameter count matches value count and read the improved mismatch error message.
