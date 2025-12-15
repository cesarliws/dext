# 🚀 Bulk Operations (True Bulk SQL)

O **Dext Entity** suporta operações de inserção em massa de alta performance ("True Bulk SQL") utilizando o recurso **Array DML** do FireDAC. Isso permite inserir milhares de registros em milissegundos, aproveitando as otimizações nativas dos drivers de banco de dados (como OCI para Oracle, libpq para PostgreSQL, etc.).

---

## 📦 Inserção em Massa (`AddRange`)

Para inserir múltiplos registros de uma vez, utilize o método `AddRange` do `IDbSet<T>`.

### Exemplo de Uso

```pascal
var
  Users: TObjectList<TUser>;
begin
  Users := TObjectList<TUser>.Create;
  try
    // 1. Criar lista de entidades
    for var i := 1 to 1000 do
    begin
      var User := TUser.Create;
      User.Name := 'User ' + i.ToString;
      User.Email := 'user' + i.ToString + '@example.com';
      Users.Add(User);
    end;

    // 2. Adicionar ao Contexto (State = Added)
    Context.Entities<TUser>.AddRange(Users);

    // 3. Persistir (Executa Array DML)
    Context.SaveChanges; 
  finally
    Users.Free;
  end;
end;
```

---

## ⚙️ Como Funciona (Under the Hood)

Diferente de outros ORMs que geram múltiplos comandos `INSERT` ou concatenam strings SQL gigantes (`INSERT INTO ... VALUES (...), (...)`), o Dext Entity utiliza **Array DML**:

1.  **Template SQL**: O ORM gera um único comando SQL parametrizado:
    ```sql
    INSERT INTO users (name, email) VALUES (:name, :email)
    ```
2.  **Parameter Arrays**: Os valores de todas as entidades são convertidos em arrays nativos e vinculados aos parâmetros `:name` e `:email`.
3.  **Batch Execution**: O comando é enviado ao banco de dados uma única vez, junto com os arrays de dados. O driver do banco processa o lote internamente.

### Benefícios
*   **Performance Extrema**: Reduz drasticamente o "round-trip" de rede e o overhead de parsing do banco de dados.
*   **Segurança**: Totalmente parametrizado, imune a SQL Injection.
*   **Memória**: Uso eficiente de memória ao evitar alocação de strings SQL gigantescas.

---

## ⚠️ Limitações Importantes

### AutoInc IDs (Identity)
Devido à natureza do Array DML, **os IDs gerados pelo banco de dados (Auto Increment / Serial / Identity) NÃO são populados de volta nas entidades inseridas**.

*   **Comportamento**: Após o `SaveChanges`, as entidades inseridas via `AddRange` continuarão com o ID zerado (ou o valor que tinham antes).
*   **Motivo**: A maioria dos drivers de banco de dados não suporta retornar múltiplos IDs gerados durante uma execução em lote de forma eficiente ou padronizada.
*   **Solução**: Se você precisa dos IDs logo após a inserção, utilize o método `Add` (um por um) ou consulte os registros novamente usando um campo único (ex: UUID ou Código Natural).

### Validações
As validações de banco (Constraints, Foreign Keys) são aplicadas em lote. Se um registro falhar, dependendo do banco de dados, todo o lote pode ser rejeitado ou apenas o registro problemático (o Dext trata como uma transação atômica por padrão se envolto em uma).

---

## 🔄 Outras Operações em Massa

*   **UpdateRange**: Atualmente itera sobre as entidades e executa `UPDATE` individualmente (será otimizado para Array DML em versões futuras).
*   **RemoveRange**: Atualmente itera sobre as entidades e executa `DELETE` individualmente (será otimizado para Array DML em versões futuras).
