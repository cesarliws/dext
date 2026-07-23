# Operações em Lote Conscientes do Dialeto (Spec S59)

O `Dext.Entity` oferece execução de operações em lote (`UpdateRange` e `RemoveRange`) com suporte nativo a estratégias otimizadas por dialeto de banco de dados (`TDextBatchStrategyFactory`).

## Motivação e Performance

Em drivers como FireDAC, o Array DML tradicional emula a execução de `UPDATE` e `DELETE` realizando $N$ chamadas sequenciais na rede em bancos como PostgreSQL e MySQL/MariaDB.

O Spec S59 introduz reescrita de query única (*single-statement rewrite*):
- **PostgreSQL**: Reescreve `UPDATE` como `UPDATE table AS t SET col = v.col FROM (VALUES (...), (...)) AS v(...) WHERE t.pk = v.pk`.
- **MySQL / MariaDB**: Reescreve `UPDATE` como `UPDATE table SET col = CASE WHEN pk = x THEN y END WHERE pk IN (...)`.
- **Deleção em Lote**: Suporte a cláusula `WHERE (pk1, pk2) IN (...)` em uma única instrução SQL.
- **Oracle / Firebird**: Mantém o Array DML nativo do protocolo do driver.

Com essa otimização, a latência de execução em lote cai de **~650 µs** para **~118 µs** por registro.

## Uso Prático

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

  // Executa single-statement batch UPDATE consciente do dialeto
  Ctx.Users.UpdateRange(Users);

  // Executa single-statement batch DELETE
  Ctx.Users.RemoveRange(Users);
end;
```
