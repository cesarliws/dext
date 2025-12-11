# Descoberta do Problema de Lazy Loading

## 🔍 O Que Descobrimos

Dos logs de debug:
```
DEBUG: Creating TLazyLoader for TUser
DEBUG: Calling Proxify...
DEBUG: Proxify completed
DEBUG: OnBefore called for method: GetHashCode  ← APENAS GetHashCode!
DEBUG: Checking if GetHashCode is a navigation property...
DEBUG: Not a navigation property
FAILED: Address should not be nil (Lazy Loading failed)
```

### Problema Identificado

1. ✅ `Proxify` está funcionando
2. ✅ `OnBefore` **está sendo chamado**
3. ❌ Mas apenas para `GetHashCode`, **NÃO** para `GetAddress`!

## 🎯 Por Que GetAddress Não Foi Chamado?

Quando fazemos:
```pascal
if LoadedUser.Address = nil then
```

O Delphi **deveria** chamar `GetAddress`, mas não está chamando!

### Possíveis Causas

#### 1. Otimização do Compilador
O compilador pode estar acessando `FAddress` diretamente ao invés de chamar o getter.

**Solução Tentada:**
- Mudamos `write FAddress` para `write SetAddress` (setter virtual)
- Adicionamos log em `GetAddress` para confirmar

#### 2. TVirtualMethodInterceptor Não Intercepta Getters de Propriedades
O `TVirtualMethodInterceptor` pode não interceptar getters de propriedades, apenas métodos normais.

**Para Testar:**
- Adicionar log diretamente em `GetAddress`
- Se o log aparecer, o getter está sendo chamado mas o interceptor não está interceptando
- Se o log NÃO aparecer, o getter não está sendo chamado

## 📝 Próximo Teste

Execute novamente e procure por:
```
DEBUG: TUser.GetAddress called
```

### Se Aparecer:
→ O getter é chamado, mas o interceptor não intercepta getters de propriedades
→ **Solução:** Precisamos de uma abordagem diferente (Lazy<T> ou proxy manual)

### Se NÃO Aparecer:
→ O compilador está otimizando e acessando `FAddress` diretamente
→ **Solução:** Forçar o uso do getter (talvez com `strict private` no campo)

## 🔧 Soluções Alternativas

Se o TVirtualMethodInterceptor não funcionar para getters de propriedades:

### Opção 1: Lazy<T> (Recomendado)
```pascal
TUser = class
private
  FAddress: Lazy<TAddress>;
public
  property Address: Lazy<TAddress> read FAddress;
end;

// Uso:
if LoadedUser.Address.IsValueCreated then
  WriteLn(LoadedUser.Address.Value.City);
```

### Opção 2: Método Explícito
```pascal
TUser = class
public
  function GetAddress: TAddress;  // Método público, não getter
end;

// Uso:
var Addr := LoadedUser.GetAddress;  // Lazy load aqui
if Addr <> nil then
  WriteLn(Addr.City);
```

### Opção 3: Proxy Manual
Criar uma classe proxy que intercepta manualmente:
```pascal
TUserProxy = class(TUser)
  function GetAddress: TAddress; override;
end;
```

## 🎯 Aguardando Resultado do Teste

Execute e compartilhe a saída completa do console!
