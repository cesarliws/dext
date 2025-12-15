# Mixed Composite Keys

## Visão Geral

O Dext ORM suporta chaves primárias compostas com tipos de dados heterogêneos (mixed types), permitindo que entidades utilizem combinações de diferentes tipos como `Integer + String`, `GUID + Integer`, etc.

## Motivação

Muitos sistemas legados e bancos de dados existentes utilizam chaves compostas com tipos mistos:
- **Sistemas Multi-Tenant**: `TenantId (Integer) + EntityId (String)`
- **Dados Hierárquicos**: `CategoryId (Integer) + Code (String)`
- **Integrações**: `SystemId (GUID) + LocalId (Integer)`

Anteriormente, o Dext suportava apenas chaves compostas homogêneas (`array of Integer`). Esta feature adiciona suporte completo para tipos heterogêneos.

## API

### Definição de Entidade

```pascal
type
  TMixedKeyEntity = class
  private
    [PK] FKey1: Integer;
    [PK] FKey2: string;
    FValue: string;
  public
    property Key1: Integer read FKey1 write FKey1;
    property Key2: string read FKey2 write FKey2;
    property Value: string read FValue write FValue;
  end;
```

### Uso do Find

```pascal
// Buscar por chave composta mista
var Entity := Context.Entities<TMixedKeyEntity>.Find([10, 'ABC']);

// Também funciona com mais de 2 chaves
var Entity := Context.Entities<TMultiKeyEntity>.Find([100, 'TENANT-A', 'CODE-123']);
```

## Implementação Técnica

### Interface

```pascal
IDbSet<T> = interface
  // Overload para chaves compostas mistas
  function Find(const AId: array of Variant): T; overload;
  
  // Overloads existentes mantidos para compatibilidade
  function Find(const AId: Variant): T; overload;
  function Find(const AId: array of Integer): T; overload;
end;
```

### Funcionamento Interno

1. **Detecção de Tipo**: O método `Find(Variant)` detecta automaticamente se o parâmetro é um `VarArray` e delega para `Find(array of Variant)`

2. **Construção Dinâmica**: O método constrói dinamicamente uma `IExpression` baseada nos metadados da entidade:
   ```pascal
   // Para Find([10, 'ABC']) em TMixedKeyEntity
   // Gera: (Key1 = 10) AND (Key2 = 'ABC')
   ```

3. **Mapeamento de Colunas**: Utiliza `FPKColumns` e `FColumns` para mapear corretamente as propriedades para colunas do banco

4. **SQL Gerado**:
   ```sql
   SELECT * FROM mixed_keys 
   WHERE Key1 = 10 AND Key2 = 'ABC'
   LIMIT 1
   ```

## Exemplos de Uso

### Exemplo 1: Sistema Multi-Tenant

```pascal
type
  TTenantEntity = class
  private
    [PK] FTenantId: Integer;
    [PK] FEntityCode: string;
    FName: string;
  public
    property TenantId: Integer read FTenantId write FTenantId;
    property EntityCode: string read FEntityCode write FEntityCode;
    property Name: string read FName write FName;
  end;

// Uso
var Entity := Context.Entities<TTenantEntity>.Find([1, 'CUSTOMER-001']);
```

### Exemplo 2: Integração com Sistema Externo

```pascal
type
  TExternalReference = class
  private
    [PK] FSystemGuid: TGUID;
    [PK] FLocalId: Integer;
    FData: string;
  public
    property SystemGuid: TGUID read FSystemGuid write FSystemGuid;
    property LocalId: Integer read FLocalId write FLocalId;
    property Data: string read FData write FData;
  end;

// Uso
var Guid := StringToGUID('{12345678-1234-1234-1234-123456789012}');
var Entity := Context.Entities<TExternalReference>.Find([Guid, 42]);
```

### Exemplo 3: Hierarquia de Dados

```pascal
type
  TProductVariant = class
  private
    [PK] FProductId: Integer;
    [PK] FVariantCode: string;
    [PK] FSizeCode: string;
    FPrice: Currency;
  public
    property ProductId: Integer read FProductId write FProductId;
    property VariantCode: string read FVariantCode write FVariantCode;
    property SizeCode: string read FSizeCode write FSizeCode;
    property Price: Currency read FPrice write FPrice;
  end;

// Uso com 3 chaves
var Variant := Context.Entities<TProductVariant>.Find([100, 'COLOR-RED', 'SIZE-M']);
```

## Compatibilidade

### Backward Compatibility

A implementação é **100% backward compatible**:

```pascal
// Continua funcionando
var User := Context.Entities<TUser>.Find(1);

// Continua funcionando
var OrderItem := Context.Entities<TOrderItem>.Find([100, 50]);

// Nova funcionalidade
var Mixed := Context.Entities<TMixedKeyEntity>.Find([10, 'ABC']);
```

### Delegação Automática

O método `Find(Variant)` detecta automaticamente arrays:

```pascal
// Ambos funcionam
var Entity1 := Context.Find([10, 'ABC']);           // Variant array
var Entity2 := Context.Find(VarArrayOf([10, 'ABC'])); // Explicit VarArray
```

## Limitações e Considerações

### 1. Performance
- **Overhead Mínimo**: A construção dinâmica de expressões tem overhead negligível
- **Índices**: Certifique-se de criar índices compostos no banco para performance ideal

### 2. Tipos Suportados
Todos os tipos que podem ser convertidos para `Variant`:
- ✅ Integer, Int64, SmallInt
- ✅ String, WideString
- ✅ Boolean
- ✅ Float, Double, Currency
- ✅ TDateTime
- ✅ TGUID (via conversão)
- ❌ Records complexos
- ❌ Objects

### 3. Ordem das Chaves
A ordem dos valores no array **deve corresponder** à ordem das propriedades marcadas com `[PK]`:

```pascal
type
  TEntity = class
  private
    [PK] FKey1: Integer;  // Primeira chave
    [PK] FKey2: string;   // Segunda chave
  end;

// Correto
Find([10, 'ABC'])  // Key1=10, Key2='ABC'

// Incorreto
Find(['ABC', 10])  // Vai tentar Key1='ABC', Key2=10 (erro de tipo)
```

### 4. Gerenciamento de Memória
- Entidades retornadas por `Find` são gerenciadas pelo `IdentityMap`
- Use `AsNoTracking` se não precisar de tracking:
  ```pascal
  // Sintaxe com Fluent API
  var Entity := Context.Entities<TMixedKeyEntity>
    .AsNoTracking
    .Query(MixedKeyEntity.Key1.Eq(10).And(MixedKeyEntity.Key2.Eq('ABC')))
    .FirstOrDefault;
  
  // Ou com Operator Overloading (mais conciso)
  var Entity := Context.Entities<TMixedKeyEntity>
    .AsNoTracking
    .Query((MixedKeyEntity.Key1 = 10) and (MixedKeyEntity.Key2 = 'ABC'))
    .FirstOrDefault;
  ```

## Testes

A implementação inclui testes abrangentes em `EntityDemo.Tests.MixedCompositeKeys.pas`:

```pascal
procedure TMixedCompositeKeyTest.Run;
begin
  var Entity := TMixedKeyEntity.Create;
  try
    Entity.Key1 := 10;
    Entity.Key2 := 'ABC';
    Entity.Value := 'Test Value';

    FContext.Entities<TMixedKeyEntity>.Add(Entity);
    FContext.SaveChanges;
    
    var Found := FContext.Entities<TMixedKeyEntity>.Find([10, 'ABC']);
    
    Assert(Found <> nil);
    Assert(Found.Value = 'Test Value');
    Assert(Found.Key1 = 10);
    Assert(Found.Key2 = 'ABC');
  finally
    Entity.Free;
  end;
end;
```

### Validação
- ✅ Inserção com chaves mistas
- ✅ Busca com `Find([Integer, String])`
- ✅ Verificação de valores corretos
- ✅ Sem memory leaks (FastMM5)
- ✅ Compatibilidade com todas as outras features

## Comparação com Entity Framework Core

### Entity Framework Core (C#)
```csharp
// Definição
public class MixedKeyEntity
{
    public int Key1 { get; set; }
    public string Key2 { get; set; }
    public string Value { get; set; }
}

protected override void OnModelCreating(ModelBuilder modelBuilder)
{
    modelBuilder.Entity<MixedKeyEntity>()
        .HasKey(e => new { e.Key1, e.Key2 });
}

// Uso
var entity = context.MixedKeyEntities.Find(10, "ABC");
```

### Dext ORM (Delphi)
```pascal
// Definição
type
  TMixedKeyEntity = class
  private
    [PK] FKey1: Integer;
    [PK] FKey2: string;
    FValue: string;
  public
    property Key1: Integer read FKey1 write FKey1;
    property Key2: string read FKey2 write FKey2;
    property Value: string read FValue write FValue;
  end;

// Uso
var Entity := Context.Entities<TMixedKeyEntity>.Find([10, 'ABC']);
```

**Diferenças:**
- EF Core usa parâmetros variádicos (`Find(10, "ABC")`)
- Dext usa array de Variant (`Find([10, 'ABC'])`)
- Ambos suportam tipos heterogêneos
- Ambos geram SQL otimizado

## Roadmap

### Implementado ✅
- [x] `Find(array of Variant)` para chaves mistas
- [x] Detecção automática de `VarArray` em `Find(Variant)`
- [x] Construção dinâmica de expressões
- [x] Testes completos
- [x] Documentação

### Futuro 🔮
- [ ] Suporte a `FindAsync` para operações assíncronas
- [ ] Otimização de cache para metadados de chaves compostas
- [ ] Suporte a chaves compostas em relacionamentos (FK compostas)

## Conclusão

Mixed Composite Keys é uma feature essencial para trabalhar com bancos de dados legados e sistemas complexos. A implementação no Dext ORM é:

- ✅ **Type-Safe**: Usa metadados da entidade
- ✅ **Performática**: Overhead mínimo
- ✅ **Compatível**: Não quebra código existente
- ✅ **Testada**: Cobertura completa de testes
- ✅ **Documentada**: Exemplos práticos e detalhados

---

**Versão**: Alpha 0.7+  
**Status**: ✅ Implementado e Validado  
**Autor**: Dext ORM Team  
**Data**: Dezembro 2025
