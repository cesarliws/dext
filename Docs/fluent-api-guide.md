# 🔍 Dext Fluent API - Guia Completo

## Visão Geral

A **Fluent API** do Dext permite criar queries tipadas e expressivas usando metadados de entidades, eliminando strings mágicas e fornecendo validação em tempo de compilação.

## Operadores Implementados

### 🔢 Operadores de Comparação

```pascal
// Igualdade
UserEntity.Age = 25
UserEntity.Age <> 25

// Maior/Menor
UserEntity.Age > 20
UserEntity.Age >= 18
UserEntity.Age < 30
UserEntity.Age <= 30
```

### 🔤 Operadores de String

```pascal
// Busca por início, fim ou conteúdo
UserEntity.Name.StartsWith('John')   // LIKE 'John%'
UserEntity.Name.EndsWith('son')      // LIKE '%son'
UserEntity.Name.Contains('Smith')    // LIKE '%Smith%'

// LIKE direto
UserEntity.Name.Like('%Doe%')
UserEntity.Name.NotLike('%Test%')
```

### 📏 Operadores de Intervalo

```pascal
// Between (Age >= 18 AND Age <= 65)
UserEntity.Age.Between(18, 65)
```

### ❓ Operadores de Nulidade

```pascal
UserEntity.Name.IsNull
UserEntity.Name.IsNotNull
```

### 🔗 Operadores Lógicos

```pascal
// AND
(UserEntity.Age >= 18) and (UserEntity.Age <= 65)

// OR
(UserEntity.Age < 18) or (UserEntity.Age > 65)

// NOT
not (UserEntity.Age = 25)
```

## Como Usar

### 1. Definir Metadados da Entidade

```pascal
// Em EntityDemo.Entities.pas
UserEntity = class
public
  class var Id: TProperty;
  class var Name: TProperty;
  class var Age: TProperty;
  
  class constructor Create;
end;

class constructor UserEntity.Create;
begin
  Id := TProperty.Create('Id');
  Name := TProperty.Create('Name');
  Age := TProperty.Create('Age');
end;
```

### 2. Criar Specifications Reutilizáveis

```pascal
TAdultUsersSpec = class(TSpecification<TUser>)
public
  constructor Create; override;
end;

constructor TAdultUsersSpec.Create;
begin
  inherited Create;
  Where(UserEntity.Age >= 18);
end;
```

### 3. Usar nas Queries

```pascal
var Spec := TAdultUsersSpec.Create;
try
  var Adults := Context.Entities<TUser>.List(Spec);
  // Processar resultados
finally
  Spec.Free;
end;
```

## Próximas Funcionalidades a Explorar

### 🎯 1. OrderBy Tipado

```pascal
// Proposta
UserEntity.Age.Asc
UserEntity.Name.Desc

// Uso
var Spec := TSpecification<TUser>.Create;
Spec.Where(UserEntity.Age >= 18);
Spec.OrderBy(UserEntity.Name.Asc);
```

### 📦 2. Select/Projection

```pascal
// Proposta: Selecionar apenas campos específicos
var Spec := TSpecification<TUser>.Create;
Spec.Select([UserEntity.Name, UserEntity.Age]);
```

### 🔄 3. Paginação Fluente

```pascal
// Proposta
var Spec := TSpecification<TUser>.Create;
Spec.Where(UserEntity.Age >= 18);
Spec.Skip(10).Take(20); // Página 2, 20 itens por página
```

### 🔗 4. Include para Eager Loading

```pascal
// Proposta: Carregar relacionamentos
var Spec := TSpecification<TUser>.Create;
Spec.Include('Address');
Spec.Include('Orders');
```

### 📊 5. Agregações

```pascal
// Proposta
Context.Entities<TUser>.Count(UserEntity.Age >= 18);
Context.Entities<TProduct>.Sum(ProductEntity.Price);
Context.Entities<TProduct>.Average(ProductEntity.Price);
Context.Entities<TUser>.Max(UserEntity.Age);
Context.Entities<TUser>.Min(UserEntity.Age);
```

### 🎨 6. GroupBy e Having

```pascal
// Proposta
var Spec := TSpecification<TOrder>.Create;
Spec.GroupBy(OrderEntity.CustomerId);
Spec.Having(Count(OrderEntity.Id) > 5);
```

### 🔍 7. Distinct

```pascal
// Proposta
var Spec := TSpecification<TUser>.Create;
Spec.Select([UserEntity.City]);
Spec.Distinct;
```

### ⚡ 8. No-Tracking Queries

```pascal
// Proposta: Queries somente leitura sem Identity Map
Context.Entities<TUser>.AsNoTracking.List(Spec);
```

## Vantagens da Fluent API

✅ **Type-Safe**: Erros detectados em tempo de compilação  
✅ **IntelliSense**: Autocomplete para propriedades  
✅ **Refactoring**: Renomear propriedades atualiza queries automaticamente  
✅ **Legibilidade**: Código mais expressivo e fácil de entender  
✅ **Reutilização**: Specifications podem ser compostas e reutilizadas  

## Comparação com Strings Mágicas

### ❌ Antes (String Mágica)
```pascal
var SQL := 'SELECT * FROM users WHERE age >= 18 AND name LIKE ''%John%''';
// Sem validação, propenso a erros de digitação
```

### ✅ Agora (Fluent API)
```pascal
var Spec := TSpecification<TUser>.Create;
Spec.Where((UserEntity.Age >= 18) and UserEntity.Name.Contains('John'));
// Tipado, validado, refatorável
```

## Roadmap de Prioridades

1. **OrderBy Tipado** - Alta prioridade, uso comum
2. **Paginação Fluente** - Alta prioridade, essencial para listas
3. **Include (Eager Loading)** - Média prioridade, melhora performance
4. **Agregações** - Média prioridade, funcionalidade comum
5. **Select/Projection** - Baixa prioridade, otimização
6. **GroupBy/Having** - Baixa prioridade, casos específicos
7. **Distinct** - Baixa prioridade, casos específicos
8. **No-Tracking** - Baixa prioridade, otimização avançada
