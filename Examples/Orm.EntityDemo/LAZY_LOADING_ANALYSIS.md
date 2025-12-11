# Análise do Problema de Lazy Loading

## 🔍 Problema Identificado

O Lazy Loading não está funcionando porque o `TVirtualMethodInterceptor` tem uma limitação fundamental:

### Como TVirtualMethodInterceptor Funciona

1. `TVirtualMethodInterceptor.Proxify(Entity)` modifica a **VMT (Virtual Method Table)** da instância
2. Isso só funciona para métodos **VIRTUAL**
3. O `Proxify` precisa ser chamado **ANTES** de qualquer acesso ao objeto

### Nosso Problema Atual

```pascal
// Em TDbSet<T>.Hydrate:
Result := TActivator.CreateInstance<T>;  // 1. Cria instância
// ... popula propriedades ...
FLazyLoaders.Add(Result, TLazyLoader.Create(FContext, Result));  // 2. Cria Lazy Loader

// Mas quando o usuário acessa:
LoadedUser.Address  // Chama GetAddress
```

O problema é que:
1. ✅ `GetAddress` é **virtual** (bom!)
2. ❌ Mas `Proxify` é chamado **DEPOIS** do objeto já estar criado
3. ❌ O `OnBefore` **NÃO** está sendo chamado (verificar com logs)

## 🎯 Soluções Possíveis

### Opção 1: Usar Lazy<T> (Como Spring4D)

Mudar a definição das entidades para usar um tipo `Lazy<T>`:

```pascal
TUser = class
private
  FAddress: Lazy<TAddress>;
public
  property Address: Lazy<TAddress> read FAddress;
end;

// Uso:
if LoadedUser.Address.Value <> nil then
  WriteLn(LoadedUser.Address.Value.City);
```

**Prós:**
- ✅ Funciona de forma confiável
- ✅ Explícito (desenvolvedor sabe que é lazy)
- ✅ Usado pelo Spring4D

**Contras:**
- ❌ Muda a API das entidades
- ❌ Mais verboso (`.Value`)

### Opção 2: Proxify no Momento Certo

Modificar o `TActivator` para criar um proxy ao invés de uma instância normal:

```pascal
// Em TDbSet<T>.Hydrate:
Result := CreateProxiedInstance<T>;  // Cria com interceptor já aplicado
```

**Prós:**
- ✅ API limpa (sem `.Value`)
- ✅ Transparente para o desenvolvedor

**Contras:**
- ❌ Complexo de implementar
- ❌ Pode ter problemas com serialização
- ❌ Performance overhead

### Opção 3: Verificar OnBefore e Corrigir

Primeiro, vamos verificar se o `OnBefore` está sendo chamado com os logs que adicionamos.

## 📝 Próximos Passos

1. **Compilar e executar** com os logs de debug
2. **Verificar** se `OnBefore` está sendo chamado
3. **Decidir** qual abordagem seguir baseado nos resultados

## 🔧 Comandos para Teste

```powershell
# Compile no RAD Studio
# Execute EntityDemo.dpr
# Verifique a saída do console para os logs DEBUG
```

## 📊 Logs Esperados

Se funcionar:
```
DEBUG: Creating TLazyLoader for TUser
DEBUG: Calling Proxify...
DEBUG: Proxify completed
DEBUG: OnBefore called for method: GetAddress
DEBUG: Checking if GetAddress is a navigation property...
DEBUG: Found navigation property: Address, IsCollection: False
DEBUG: Loading property: Address
DEBUG: Loading Reference Address FK=1
DEBUG: ChildObj found: True
DEBUG: Setting Value type: TAddress
DEBUG: Value Set
DEBUG: Property loaded successfully
```

Se NÃO funcionar:
```
DEBUG: Creating TLazyLoader for TUser
DEBUG: Calling Proxify...
DEBUG: Proxify completed
(sem mais logs - OnBefore não foi chamado!)
```
