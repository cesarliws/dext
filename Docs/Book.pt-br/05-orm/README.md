# 5. ORM (Dext.Entity)

Dext.Entity é um ORM completo para Delphi com suporte a múltiplos bancos de dados.

## Capítulos

1. [Primeiros Passos](primeiros-passos.md)
2. [Entidades & Mapeamento](entidades.md)
3. [Consultas](consultas.md)
4. [Smart Properties](smart-properties.md)
5. [Consultas JSON](consultas-json.md)
6. [Specifications](specifications.md)
7. [Relacionamentos](relacionamentos.md)
8. [Migrations](migrations.md)
9. [Scaffolding](scaffolding.md)
10. [Multi-Tenancy](multi-tenancy.md)
11. [SQL Puro (FromSql)](sql-puro-from-sql.md)
12. [Procedimentos Armazenados](procedimentos-armazenados.md)
13. [Concorrência e Travamento](travamento-concorrencia.md)
14. [Transações](transacoes.md)
15. [Soft Delete](soft-delete.md)
16. [Mapeamento Aninhado](mapeamento-aninhado.md)
17. [Operações em Lote](operacoes-em-lote.md)

> 📦 **Exemplos**:
>
> - [Orm.EntityDemo](../../../Examples/Orm.EntityDemo/) (Padrão)
> - [Orm.EntityStyles](../../../Examples/Orm.EntityStyles/) (Comparativo: POCO vs Smart Properties)

## Início Rápido

```pascal
// 1. Definir Entidade
type
  [Table('users')]
  TUser = class
  private
    FId: Integer;
    FName: string;
  public
    [PK, AutoInc]
    property Id: Integer read FId write FId;
    
    [Column('name')]
    property Name: string read FName write FName;
  end;

// 2. Criar Contexto
type
  TAppContext = class(TDbContext)
  public
    function Users: IDbSet<TUser>;
  end;

// 3. Usar!
var
  Ctx: TAppContext;
  User: TUser;
begin
  Ctx := TAppContext.Create(Connection, Dialect);
  
  // Create
  User := TUser.Create;
  User.Name := 'João';
  Ctx.Users.Add(User);
  Ctx.SaveChanges;
  
  // Read
  User := Ctx.Users.Find(1);
  
  // Query
  var u := Prototype.Entity<TUser>;
  var UsuariosAtivos := Ctx.Users
    .Where(u.Name.Contains('João'))
    .ToList;
end;
```

## Bancos de Dados Suportados

| Banco de Dados | Status |
|----------------|--------|
| PostgreSQL | ✅ Estável |
| SQL Server | ✅ Estável |
| SQLite | ✅ Estável |
| Firebird | ✅ Estável |
| MySQL / MariaDB | ✅ Estável |
| Oracle | ✅ Stable |

---

[← Recursos da API](../04-recursos-api/README.md) | [Próximo: Primeiros Passos →](primeiros-passos.md)
