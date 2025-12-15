# 🚀 Fluent Query API - Guia Completo

A **Fluent Query API** do Dext Entity fornece uma maneira poderosa, expressiva e tipada para consultar dados. Ela suporta filtragem, projeção, agregação, junção e paginação usando uma sintaxe de encadeamento de métodos.

## 🏁 Uso Básico

Para iniciar uma consulta, utilize o método `Query` em um conjunto de entidades (`DbSet`):

```delphi
var
  Users: TFluentQuery<TUser>;
begin
  Users := Context.Entities<TUser>.Query;
  // ... use Users ...
  Users.Free;
end;
```

## 🔍 Filtragem (Where)

Você pode filtrar usando um predicado (`TFunc<T, Boolean>`) ou um `IExpression` (Specification).

### Usando Predicado (Lambda/Anonymous Method)
```delphi
Users.Where(function(U: TUser): Boolean
  begin
    Result := U.Age > 18;
  end);
```

### Usando Specification (IExpression)
A forma mais limpa e recomendada, usando metadados gerados (Helpers):
```delphi
// Assumindo que UserEntity é um helper gerado para as propriedades de TUser
Users.Where(UserEntity.Age > 18);
```

## 📦 Projeções (Select)

Você pode projetar para um novo tipo, uma única propriedade ou uma entidade parcial.

### Selecionar Propriedade Única
Projeta para uma lista de valores do tipo da propriedade.
```delphi
var
  Names: TFluentQuery<string>;
begin
  // Seleciona apenas os nomes
  Names := Users.Select<string>('Name');
  // Ou usando o helper
  Names := Users.Select<string>(UserEntity.Name);
end;
```

### Selecionar Múltiplas Propriedades (Carregamento Parcial)
Cria novas instâncias da entidade com apenas as propriedades especificadas preenchidas. Útil para performance.
```delphi
var
  PartialUsers: TFluentQuery<TUser>;
begin
  // Carrega apenas Name e City, Age será 0/Default
  PartialUsers := Users.Select(['Name', 'City']);
  // Ou usando helpers
  PartialUsers := Users.Select([UserEntity.Name, UserEntity.City]);
end;
```

### Selecionar com Seletor Customizado
Projeta para qualquer tipo usando uma função customizada.
```delphi
Users.Select<TUserDTO>(function(U: TUser): TUserDTO
  begin
    Result := TUserDTO.Create(U.Name, U.Age);
  end);
```

## 📊 Agregações

Agregações suportadas: `Count`, `Sum`, `Average`, `Min`, `Max`, `Any`.

### Count (Contagem)
```delphi
var Total: Integer := Users.Count;
var Adults: Integer := Users.Count(function(U: TUser): Boolean begin Result := U.Age >= 18; end);
```

### Sum, Average, Min, Max
Podem ser chamados com o nome da propriedade (string) ou uma função seletora.

```delphi
// Usando Nome da Propriedade (Mais limpo)
var TotalAge: Double := Users.Sum('Age');
var MaxAge: Double := Users.Max(UserEntity.Age.Name);

// Usando Seletor
var MinAge: Double := Users.Min(function(U: TUser): Double begin Result := U.Age; end);
```

### Any (Existência)
Verifica se existe algum elemento (opcionalmente satisfazendo um predicado).
```delphi
if Users.Any then ...
if Users.Any(function(U: TUser): Boolean begin Result := U.Age > 100; end) then ...
```

## 🔗 Junções (Join)

Junte duas consultas baseadas em propriedades chave.

### Join Simplificado (Nomes de Propriedades)
```delphi
var
  Joined: TFluentQuery<string>;
begin
  Joined := Users.Join<TAddress, Integer, string>(
    Addresses,            // Query Interna (TAddress)
    UserEntity.AddressId, // Propriedade Chave Externa (em User)
    UserEntity.Id,        // Propriedade Chave Interna (em Address)
    function(U: TUser; A: TAddress): string
    begin
      Result := U.Name + ' mora em ' + A.Street;
    end
  );
end;
```

## 📄 Paginação

Paginação eficiente com metadados.

```delphi
var
  Page: IPagedResult<TUser>;
begin
  Page := Users.Paginate(1, 10); // Página 1, Tamanho 10
  
  // Propriedades disponíveis:
  // Page.Items (TList<T>)
  // Page.TotalCount
  // Page.PageCount
  // Page.HasNextPage
end;
```

## ⚡ Execução (Lazy Loading)

A query é preguiçosa (lazy). A execução real acontece apenas quando você chama:
- `ToList`
- Um método de agregação (`Count`, `Sum`, etc.)
- `GetEnumerator` (ex: em um loop `for..in`)

```delphi
var
  UserList: TList<TUser>;
begin
  // A query é construída aqui, mas não executada
  var Query := Users.Where(UserEntity.Age > 18);
  
  // A execução acontece aqui
  UserList := Query.ToList;
  try
    // usar lista
  finally
    UserList.Free;
  end;
end;
```
