# TEntityDataSet & Sincronização Remota

O `TEntityDataSet` é um dataset Delphi de alta performance projetado para expor coleções de objetos e entidades do ORM diretamente a controles visuais orientados a dados (data-aware) da VCL/FMX (como o `TDBGrid`).

---

## 1. Rollback Local (RejectChanges)

Durante operações locais de CRUD, o `TEntityDataSet` mantém o histórico das alterações pendentes em memória utilizando o log de modificações (`TEntityChange`).

Para descartar as alterações não enviadas e restaurar o estado original dos dados:

```pascal
// Descarta todas as inserções, exclusões e modificações locais
FDataSet.RejectChanges;
```

### Comportamento do Rollback:
- **ersInserted**: Objetos novos inseridos são removidos do dataset e liberados.
- **ersDeleted**: Registros excluídos retornam ao dataset em seu índice original.
- **ersModified**: Propriedades alteradas recuperam seus valores originais via RTTI.

---

## 2. Consolidando Alterações (AcceptChanges)

Após enviar e gravar com sucesso as alterações no servidor remoto ou no banco de dados local, limpe o log chamando `AcceptChanges`:

```pascal
FDataSet.AcceptChanges;
```
