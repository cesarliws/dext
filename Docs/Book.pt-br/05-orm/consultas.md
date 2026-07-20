# Consultas (Querying)

API fluente para recuperação de dados.

## Tipos de Retorno: IList\<T\>

> [!IMPORTANT]
> O Dext usa `IList<T>` de `Dext.Collections`, não `TObjectList<T>` de `System.Generics.Collections`.

```pascal
uses
  Dext.Collections;

var Users: IList<TUser>;
begin
  Users := Context.Users.ToList;  // Retorna IList<TUser>
  
  for var User in Users do
    WriteLn(User.Name);
end;
```

### Criando Novas Listas

Use a factory `TCollections.CreateList<T>`:

```pascal
// Criar nova lista
var MinhaLista := TCollections.CreateList<TUser>;
MinhaLista.Add(User1);
MinhaLista.Add(User2);

// Criar com ownership (libera objetos automaticamente)
var ListaComOwner := TCollections.CreateList<TUser>(True);
```

> [!TIP]
> `IList<T>` é uma interface, então não precisa de `try/finally Free`!

## Consultas Básicas

### Obter Todos

```pascal
var Users := Context.Users.ToList;
```

### Buscar por ID

```pascal
var User := Context.Users.Find(1);
if User <> nil then
  WriteLn('Encontrado: ', User.Name);
```

### First / FirstOrDefault

```pascal
// Lança exceção se não encontrar
var User := Context.Users.First;

// Retorna nil se não encontrar
var User := Context.Users.FirstOrDefault;
```

## Filtragem (Where)

### Smart Properties (Recomendado)

Use `var` inline para Props (simulando variáveis lambda do C#):

```pascal
// ✅ CORRETO: var inline camelCase, próximo ao uso
var u := TUser.Props;
var UsuariosAtivos := Context.Users
  .Where(u.IsActive = True)
  .ToList;

// Múltiplas condições
var Resultados := Context.Users
  .Where((u.Age >= 18) and (u.Status = 'active'))
  .ToList;
```

> [!IMPORTANT]
> **Por que camelCase?** Para diferenciar de variáveis de método PascalCase.  
> Em queries multi-tabela com Include/Join, cada tabela tem sua própria var inline (`var u`, `var o`, `var p`).

### Expressão Lambda (Prototype)

```pascal
var u := Prototype.Entity<TUser>;
var UsuariosAtivos := Context.Users
  .Where(u.IsActive)
  .ToList;
```

## Ordenação (OrderBy)

> [!WARNING]
> `OrderBy` exige `.Asc` ou `.Desc` — passar uma Prop diretamente causa o erro `E2010 Incompatible types`.

```pascal
var u := TUser.Props;

// Ascendente
var Users := Context.Users
  .QueryAll
  .OrderBy(u.Name.Asc)
  .ToList;

// Descendente
var Users := Context.Users
  .QueryAll
  .OrderBy(u.CreatedAt.Desc)
  .ToList;

// Múltiplas colunas
var Users := Context.Users
  .QueryAll
  .OrderBy(u.LastName.Asc)
  .OrderBy(u.FirstName.Asc)
  .ToList;
```

## Paginação

```pascal
var u := TUser.Props;
var Pagina := Context.Users
  .QueryAll
  .OrderBy(u.Id.Asc)
  .Skip(20)   // Pula os primeiros 20
  .Take(10)   // Pega os próximos 10
  .ToList;
```

## No Tracking Queries (Performance)

Use `.AsNoTracking` para cenários de **Apenas Leitura**. Isso retorna objetos sem adicioná-los ao `IdentityMap` ou `ChangeTracker`, resultando em uma performance ~30-50% superior e menor uso de memória.

> [!IMPORTANT]
> **Gerenciamento de Memória & Ciclo de Vida**: No modo Tracked (padrão), o `IdentityMap` do `DbContext` é dono dos objetos. Quando o `DbContext` é liberado (`Db.Free`), as entidades rastreadas são destruídas. Para retornar entidades que devem sobreviver ao descarte do `DbContext` (ex: de serviços para controllers/views), utilize `.AsNoTracking.ToList`. No modo No Tracking, a `IList<T>` retornada **é dona** dos objetos e os mantêm vivos até a lista sair de escopo.

```pascal
// Ideal para APIs e Relatórios que trafegam fora do escopo do DbContext
var Users := Context.Users
  .AsNoTracking
  .Where(u.IsActive = True)
  .ToList; // Os objetos serão liberados quando Users for limpo
```


## Projeção (Select)

```pascal
type
  TUserDto = record
    Nome: string;
    Email: string;
  end;

var u := Prototype.Entity<TUser>;
var Dtos := Context.Users
  .Select<TUserDto>([u.Name, u.Email])
  .ToList;
```

## Agregações

```pascal
var u := TUser.Props;

// Count
var Total := Context.Users.Count;
var AtivosCount := Context.Users
  .Where(u.IsActive = True)
  .Count;

// Any / Exists (preferido para verificação em Seeders)
var TemAdmin := Context.Users
  .Where(u.Role = 'admin')
  .Any;
```

## Tipos Personalizados (Enums)

Se um tipo específico (como um Enum) não tiver um alias predefinido, crie um usando `Prop<T>`:

```pascal
type
  StatusType = Prop<TOrderStatus>;  // Tipo smart customizado
```

Use na query:

```pascal
var o := TOrder.Props;
var Pagos := Context.Orders
  .Where(o.Status = osPaid)
  .OrderBy(o.Total.Desc)
  .ToList;
```

## Entidades Fantasma (Prototype)

Use `Prototype.Entity<T>` de `Dext.Entity.Prototype` para metadados typesafe em queries complexas:

```pascal
var p := Prototype.Entity<TProduto>;
var Caros := Context.Products
  .Where(p.Preco > 100)
  .ToList;
```

## Execução da Query

Queries são lazy (preguiçosas) — executadas apenas quando você chama um método terminal:

| Método | Efeito |
|--------|--------|
| `.ToList` | Executa e retorna lista |
| `.First` / `.FirstOrDefault` | Executa e retorna um |
| `.Count` | Executa e retorna contagem |
| `.Any` | Executa e retorna boolean |
| `.Find(id)` | Executa e retorna por PK |

## Consultas Avançadas (Joins & Agrupamento)

Para cenários complexos, use a tipagem de Specification e joins explícitos.

### SQL Join (`Join(table, alias, joinType, condition)`)

Use o overload orientado a SQL quando você quer que o join seja traduzido para SQL pelo provider.

```pascal
var u := TUser.Props;
var Usuarios := Context.Users
  .AsNoTracking
  // Predicado qualificado no ON:
  // users.address_id = a.id
  .Join('addresses', 'a', jtInner, Prop('users.address_id') = Prop('a.id'))
  .Where(u.Age >= 18)
  .OrderBy(u.Id.Asc)
  .ToList;
```

> [!IMPORTANT]
> Você pode fornecer a condição do join como:
> - `IExpression` (caminho estrito/tipado), ou
> - string simples `"left = right"` (parser auxiliar).
>
> Em ambos os casos, use nomes de coluna/propriedade qualificados no predicado ON
> (ex.: `users.address_id`, `a.id`).

### Joins Fluentes Fortemente Tipados (Strongly-Typed)

O Dext Entity suporta joins fluentes avançados e fortemente tipados que rodam inteiramente no banco de dados. Essas operações compilam diretamente em joins SQL otimizados (INNER, LEFT, RIGHT, FULL, CROSS).

Existem três formas principais de declarar joins fluentes:

#### 1. Joins com Condição Explícita
Especifique as tabelas, aliases e a condição ON explícita usando Smart Properties:
```pascal
var u := TUser.Props;
var a := TAddress.Props;

var Resultados := Context.Users
  .JoinLeft<TAddress>('u', 'a', u.AddressId = a.Id)
  .Where(u.Age >= 18)
  .ToList;
```

#### 2. Auto-Joins por Relacionamento Implícito
Se o relacionamento estiver configurado em seu `TModelBuilder` (ex. HasOne/HasMany), o Dext resolve a condição ON automaticamente a partir dos metadados da entidade:
```pascal
var u := TUser.Props;

// Resolve automaticamente para: ON u.AddressId = a.Id
var Resultados := Context.Users
  .JoinInner<TAddress>
  .Where(u.Age >= 18)
  .ToList;
```

#### 3. Cross Joins (Sem condição ON)
Gera o produto cartesiano entre duas tabelas sem cláusula ON:
```pascal
var Resultados := Context.Users
  .JoinCross<TDepartment>
  .ToList;
```

Métodos de join fluente disponíveis:
- `JoinInner<TInner>` (ON auto-resolvido) ou `JoinInner<TInner>(AliasOuter, AliasInner, Condition)`
- `JoinLeft<TInner>` (ON auto-resolvido) ou `JoinLeft<TInner>(AliasOuter, AliasInner, Condition)`
- `JoinRight<TInner>` (ON auto-resolvido) ou `JoinRight<TInner>(AliasOuter, AliasInner, Condition)`
- `JoinFull<TInner>` (ON auto-resolvido) ou `JoinFull<TInner>(AliasOuter, AliasInner, Condition)`
- `JoinCross<TInner>` (sem condição ON) ou `JoinCross<TInner>(AliasOuter, AliasInner)`

### Join Genérico (`Join<TInner, TKey, TResult>`)

Use este overload para cenários de projeção/correlação onde composição em memória é aceitável:

```pascal
var Juncao := Context.Users
  .AsNoTracking
  .Join<TAddress, Integer, string>(
    Context.Addresses.AsNoTracking,
    'AddressId',
    'Id',
    function(U: TUser; A: TAddress): string
    begin
      Result := U.Name + ' @ ' + A.City;
    end
  )
  .ToList;
```

> [!WARNING]
> `Join<TInner, TKey, TResult>` materializa as sequências externa e interna e correlaciona em memória.  
> **Não** é substituto direto de SQL join em cenários de escala.

> [!TIP]
> Veja exemplos executáveis em:
> `Examples/03-Data/Orm.EntityDemo/EntityDemo.Tests.Join.pas`

### Group By & Having

Agregue dados e filtre resultados agrupados.

```pascal
var Stats := Context.Orders
  .GroupBy('CustomerId')
  .Having(TOrder.Props.Total.Sum > 1000)
  .Select(['CustomerId', 'Total.Sum'])
  .ToList;
```

## Performance & Cache

### Cache de Geração SQL

O Dext inclui um singleton `TSQLCache` que armazena o SQL gerado para consultas com base em sua estrutura (Assinatura AST). Isso melhora significativamente a performance de queries repetitivas.

O cache é **ativado por padrão** e é thread-safe.

#### Desativando o Cache

Se precisar desativar (ex: para depuração):

```pascal
uses
  Dext.Entity.Cache;

// Desativar globalmente
TSQLCache.Instance.Enabled := False;
```

---

[← Entidades](entidades.md) | [Próximo: Smart Properties →](smart-properties.md)
