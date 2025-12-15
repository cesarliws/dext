# 📦 Dext.Collections

O `Dext.Collections` é uma biblioteca moderna de coleções para Delphi, projetada para ser leve, segura quanto à memória e rica em funcionalidades funcionais (inspiradas no LINQ/Spring4D).

Ela faz parte do núcleo do **Dext Framework** e é utilizada intensivamente pelo **Dext Entity** ORM.

## 🚀 Principais Features

*   **Interface-based (`IList<T>`)**: Gerenciamento automático de ciclo de vida (ARC para interfaces).
*   **Memory Safety**: `OwnsObjects` gerenciado automaticamente para listas de objetos.
*   **API Fluente (LINQ-like)**: `Where`, `First`, `Any`, `All`, `ForEach`.
*   **Expression Support**: Integração profunda com `Dext.Specifications` para filtros complexos e tipados.
*   **Factory Pattern**: Criação simples via `TCollections`.

---

## 🛠️ Como Usar

### 1. Criando Listas

Utilize a factory `TCollections` para criar instâncias. Não é necessário destruir a lista manualmente se você usar a interface `IList<T>`, pois ela é gerenciada por contagem de referências.

```delphi
uses
  Dext.Collections;

var
  Users: IList<TUser>;
  Numbers: IList<Integer>;
begin
  // Lista de Objetos (OwnsObjects = True por padrão)
  // Os objetos serão destruídos automaticamente quando removidos ou quando a lista for destruída.
  Users := TCollections.CreateObjectList<TUser>; 
  
  // Lista de Tipos Primitivos/Records
  Numbers := TCollections.CreateList<Integer>;
end;
```

### 2. Operações Básicas

A interface `IList<T>` suporta todas as operações padrão de lista.

```delphi
Users.Add(User1);
Users.AddRange([User2, User3]);

if Users.Contains(User1) then
  Users.Remove(User1);

Users.RemoveAt(0);
Users.Clear; // Destrói todos os objetos se OwnsObjects=True

WriteLn(Users.Count);
WriteLn(Users[0].Name);
```

### 3. Métodos Funcionais (LINQ-like)

Realize operações de consulta e transformação de forma declarativa e concisa.

#### Filtragem com Predicados (Anonymous Methods)

```delphi
var
  Adults: IList<TUser>;
begin
  // Retorna uma NOVA lista contendo apenas os elementos que satisfazem a condição
  Adults := Users.Where(function(U: TUser): Boolean
    begin
      Result := U.Age >= 18;
    end);
    
  // Verifica existência
  if Users.Any(function(U: TUser): Boolean begin Result := U.IsActive end) then
    WriteLn('Temos usuários ativos!');
end;
```

### 4. Expression Support (Novo! ✨)

A grande vantagem do `Dext.Collections` é o suporte nativo a `IExpression` do módulo `Dext.Specifications`. Isso permite escrever queries tipadas e reutilizáveis que são avaliadas em memória usando RTTI otimizado.

> **Nota:** Requer `Dext.Specifications.Expression` no uses.

```delphi
uses
  Dext.Collections,
  Dext.Specifications.Expression; // para func helper Prop()

var
  LondonUsers: IList<TUser>;
  FirstAdmin: TUser;
begin
  // Filtrar usando Operators Overloading
  LondonUsers := Users.Where(Prop('City') = 'London');
  
  // Queries complexas com Lógica
  var Target := (Prop('Age') > 25) and (Prop('Role') = 'Admin');
  
  if Users.All(Prop('IsActive') = True) then
    WriteLn('Todos estão ativos');
    
  // Encontrar o primeiro match
  FirstAdmin := Users.First(Target);
             // ou Users.FirstOrDefault(Target);
end;
```

### 5. Iteração

Suporte total ao loop `for..in` do Delphi.

```delphi
for var User in Users do
begin
  WriteLn(User.Name);
end;
```

Ou usando `ForEach` funcional:

```delphi
Users.ForEach(procedure(U: TUser)
  begin
    U.LastAccess := Now;
  end);
```

---

## 🏗️ Arquitetura e Decisões de Design

### Por que não usar `System.Generics.Collections.TObjectList<T>`?

1.  **Memory Leaks**: `TObjectList<T>` padrão do Delphi requer `MyList.Free` manual. Isso é propenso a erros, especialmente quando listas são geradas e retornadas por métodos (quem é o dono?).
2.  **Verbosismo**: Criar predicados para `Find` ou filtrar listas requer muito código boilerplate no Delphi padrão.
3.  **ORM Integration**: O Dext ORM precisa aplicar filtros em memória (pós-loading ou cache) usando as mesmas Expressões que usa para gerar SQL. `TObjectList` não sabe o que é uma `IExpression`.

### Implementação

*   **`IList<T>`**: Interface limpa que herda de `IEnumerable<T>`.
*   **`TSmartList<T>`**: Implementação interna que encapsula uma `TList<T>` do Delphi, mas adiciona contagem de referência (`TInterfacedObject`) e lógica de `OwnsObjects` segura.
*   **`TExpressionEvaluator`**: Usado internamente para avaliar expressões RTTI contra objetos da lista em tempo de execução.

---

## 📊 Comparativo

| Feature | `TObjectList<T>` (Delphi) | `IList<T>` (Spring4D) | `IList<T>` (Dext) |
| :--- | :---: | :---: | :---: |
| **GC / ARC** | ❌ (Manual Free) | ✅ | ✅ |
| **Predicados / LINQ** | ❌ | ✅ (Completo / Otimizado) | ✅ (Essencial) |
| **Expression Trees** | ❌ | ❌ (Usa Predicados) | ✅ (Nativo / RTTI) |
| **Dependências** | Nenhuma | Spring.Base | Dext.Core |
| **Perfil** | Nativo | Completo / Alta Performance | Leve / Focado no ORM |

---

## 📝 Melhores Práticas

1.  Sempre declare variáveis como `IList<T>`, nunca como `TSmartList<T>`.
2.  Prefira usar `CreateObjectList` para objetos de domínio.
3.  Use `Where(IExpression)` para filtros dinâmicos ou que vieram de especificações de negócio.
4.  Use `Where(TFunc...)` para lógica ad-hoc rápida que não precisa de inspeção.
