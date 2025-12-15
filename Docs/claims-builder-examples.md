# Claims Builder - Comparação Antes/Depois

## ❌ Antes (Manual e Verboso)

```pascal
var
  Claims: TArray<TClaim>;
begin
  // Criar array manualmente
  SetLength(Claims, 5);
  Claims[0] := TClaim.Create(TClaimTypes.NameIdentifier, '123');
  Claims[1] := TClaim.Create(TClaimTypes.Name, 'john.doe');
  Claims[2] := TClaim.Create(TClaimTypes.Email, 'john@example.com');
  Claims[3] := TClaim.Create(TClaimTypes.Role, 'Admin');
  Claims[4] := TClaim.Create(TClaimTypes.Role, 'User');
  
  // Se precisar adicionar mais um claim, tem que:
  // 1. Mudar o SetLength
  // 2. Adicionar nova linha
  // 3. Ajustar todos os índices se inserir no meio
  
  Token := JwtHandler.GenerateToken(Claims);
end;
```

**Problemas:**
- ❌ Precisa saber quantos claims terá antecipadamente
- ❌ Gerenciamento manual de índices
- ❌ Difícil adicionar/remover claims
- ❌ Código verboso e repetitivo
- ❌ Propenso a erros de índice

## ✅ Depois (Fluent e Elegante)

```pascal
var
  Claims: TArray<TClaim>;
begin
  // Criar com fluent interface
  Claims := TClaimsBuilder.Create
    .WithNameIdentifier('123')
    .WithName('john.doe')
    .WithEmail('john@example.com')
    .WithRole('Admin')
    .WithRole('User')
    .Build;
  
  // Adicionar mais claims? Só adicionar mais uma linha!
  // .WithGivenName('John')
  
  Token := JwtHandler.GenerateToken(Claims);
end;
```

**Vantagens:**
- ✅ Não precisa saber o tamanho antecipadamente
- ✅ Sem gerenciamento de índices
- ✅ Fácil adicionar/remover claims
- ✅ Código limpo e autodocumentado
- ✅ IntelliSense mostra métodos disponíveis
- ✅ Impossível errar índices

## 🎯 Exemplos Práticos

### Exemplo 1: Claims Básicos

```pascal
// Usuário simples
var Claims := TClaimsBuilder.Create
  .WithNameIdentifier('user-123')
  .WithName('john.doe')
  .Build;
```

### Exemplo 2: Usuário Completo

```pascal
// Usuário com todos os dados
var Claims := TClaimsBuilder.Create
  .WithNameIdentifier('user-456')
  .WithName('jane.smith')
  .WithEmail('jane@example.com')
  .WithGivenName('Jane')
  .WithFamilyName('Smith')
  .WithRole('Admin')
  .Build;
```

### Exemplo 3: Múltiplas Roles

```pascal
// Usuário com várias roles
var Claims := TClaimsBuilder.Create
  .WithNameIdentifier('user-789')
  .WithName('admin')
  .WithRole('Admin')
  .WithRole('Moderator')
  .WithRole('Editor')
  .Build;
```

### Exemplo 4: Claims Personalizados

```pascal
// Misturando claims padrão e personalizados
var Claims := TClaimsBuilder.Create
  .WithNameIdentifier('user-999')
  .WithName('developer')
  .WithEmail('dev@example.com')
  .AddClaim('department', 'Engineering')
  .AddClaim('level', 'Senior')
  .AddClaim('team', 'Backend')
  .Build;
```

### Exemplo 5: Construção Condicional

```pascal
// Adicionar claims condicionalmente
var Builder := TClaimsBuilder.Create
  .WithNameIdentifier(User.Id)
  .WithName(User.Username);

if User.Email <> '' then
  Builder.WithEmail(User.Email);

if User.IsAdmin then
  Builder.WithRole('Admin');

if User.IsModerator then
  Builder.WithRole('Moderator');

var Claims := Builder.Build;
```

## 📊 Comparação de Linhas de Código

| Cenário | Antes | Depois | Redução |
|---------|-------|--------|---------|
| 3 claims | 5 linhas | 4 linhas | 20% |
| 5 claims | 7 linhas | 6 linhas | 14% |
| 10 claims | 12 linhas | 11 linhas | 8% |
| + Condicional | +3 linhas cada | +1 linha cada | 67% |

## 🚀 Performance

O builder usa `TList<TClaim>` internamente e só cria o array final no `Build()`, então:

- ✅ Eficiente para qualquer número de claims
- ✅ Sem realocações desnecessárias
- ✅ Overhead mínimo (apenas uma alocação de lista)
- ✅ `Build()` é O(n) onde n = número de claims

## 💡 Dicas de Uso

### 1. Reutilizar Builder

```pascal
// ❌ Não faça isso - cria novo builder a cada vez
for User in Users do
begin
  var Claims := TClaimsBuilder.Create
    .WithNameIdentifier(User.Id)
    .WithName(User.Name)
    .Build;
  // ...
end;

// ✅ Melhor - reutilize o builder
var Builder := TClaimsBuilder.Create;
for User in Users do
begin
  Builder.Clear;  // TODO: Adicionar método Clear
  var Claims := Builder
    .WithNameIdentifier(User.Id)
    .WithName(User.Name)
    .Build;
  // ...
end;
Builder.Free;
```

### 2. Validação

```pascal
var Builder := TClaimsBuilder.Create;
try
  Builder
    .WithNameIdentifier(UserId)
    .WithName(Username);
  
  // Verificar se tem claims suficientes
  if Builder.Count < 2 then
    raise Exception.Create('Insufficient claims');
  
  var Claims := Builder.Build;
finally
  Builder.Free;
end;
```

### 3. Factory Method

```pascal
// Criar helper para casos comuns
function CreateUserClaims(const UserId, Username: string): TArray<TClaim>;
begin
  Result := TClaimsBuilder.Create
    .WithNameIdentifier(UserId)
    .WithName(Username)
    .Build;
end;

// Uso
var Claims := CreateUserClaims('123', 'john.doe');
```

---

**O Claims Builder torna o código mais limpo, seguro e fácil de manter!** ✨
