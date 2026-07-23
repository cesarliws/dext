# Dialect-Aware Batch Operations (Spec S59)

`Dext.Entity` provides high-performance bulk operation execution (`UpdateRange` and `RemoveRange`) powered by dialect-aware execution strategies (`TDextBatchStrategyFactory`).

## Performance Motivation

In standard database drivers like FireDAC, default Array DML implementation emulates `UPDATE` and `DELETE` batch operations by performing $N$ sequential network roundtrips on engines lacking native protocol array binding (such as PostgreSQL and MySQL/MariaDB).

Spec S59 introduces single-statement query rewriting:
- **PostgreSQL**: Rewrites `UPDATE` into `UPDATE table AS t SET col = v.col FROM (VALUES (...), (...)) AS v(...) WHERE t.pk = v.pk`.
- **MySQL / MariaDB**: Rewrites `UPDATE` into `UPDATE table SET col = CASE WHEN pk = x THEN y END WHERE pk IN (...)`.
- **Batch DELETE**: Executes single-statement deletion via `WHERE (pk1, pk2) IN (...)`.
- **Oracle / Firebird**: Preserves native protocol Array DML binding.

This optimization reduces per-record execution latency from **~650 µs** down to **~118 µs**.

## Usage Example

```pascal
var
  Users: TArray<TUser>;
  i: Integer;
begin
  SetLength(Users, 500);
  for i := 0 to 499 do
  begin
    Users[i] := Ctx.Users.Find(i + 1);
    Users[i].Status := 'Active';
  end;

  // Single-statement dialect-aware batch UPDATE
  Ctx.Users.UpdateRange(Users);

  // Single-statement dialect-aware batch DELETE
  Ctx.Users.RemoveRange(Users);
end;
```
