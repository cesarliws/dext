# 🚫 No Tracking Queries - Design Document

## 📋 Visão Geral

**No Tracking Queries** permitem que o ORM retorne objetos **sem** adicioná-los ao `IdentityMap` e sem rastreá-los no `ChangeTracker`. Isso é essencial para:

- ✅ **APIs Read-Only**: Endpoints que apenas leem dados e retornam JSON
- ✅ **Performance**: Elimina overhead de tracking (~30-50% mais rápido)
- ✅ **Memória**: Objetos não ficam no IdentityMap (liberados quando lista sai de escopo)
- ✅ **Bulk Reads**: Grandes volumes de dados (relatórios, exports)

## 🎯 Casos de Uso

### ❌ **Tracking (Padrão) - Quando usar:**
```pascal
// Cenário: Vou modificar os dados
var Users := Context.Entities<TUser>.List;
for var User in Users do
begin
  User.Age := User.Age + 1;  // Modificação
  Context.Entities<TUser>.Update(User);
end;
Context.SaveChanges;
```

### ✅ **No Tracking - Quando usar:**
```pascal
// Cenário 1: API Read-Only
function TUserController.GetAll: TJSONArray;
var
  Users := FContext.Entities<TUser>.AsNoTracking.List;
begin
  Result := UsersToJSON(Users);  // Apenas leitura
  // Users liberado automaticamente ao sair de escopo
end;

// Cenário 2: Relatório
function GenerateReport: string;
var
  Sales := FContext.Entities<TSale>
    .AsNoTracking
    .Query(SaleEntity.Date >= StartDate)
    .ToList;
begin
  Result := BuildReport(Sales);  // Apenas leitura
end;
```

## 🏗️ Arquitetura

### **1. Ownership Strategy**

| Modo | IdentityMap | Lista | Quem libera objetos? |
|------|-------------|-------|---------------------|
| **Tracking** | ✅ Adiciona | `OwnsObjects=False` | IdentityMap (quando Context destruído) |
| **No Tracking** | ❌ Não adiciona | `OwnsObjects=True` | Lista (quando sai de escopo) |

### **2. Fluxo de Dados**

#### **Tracking (atual):**
```
DB → Hydrate → IdentityMap.Add → Lista (referência)
                     ↓
              ChangeTracker (se modificado)
                     ↓
              SaveChanges → DB
```

#### **No Tracking (novo):**
```
DB → Hydrate → Lista (ownership)
                 ↓
           (sai de escopo)
                 ↓
           Objetos liberados
```

## 💻 Implementação

### **1. Interface IDbSet<T>**

```pascal
type
  IDbSet<T> = interface
    // ... métodos existentes ...
    
    function AsNoTracking: IDbSet<T>;  // Retorna view sem tracking
  end;
```

### **2. TDbSet<T> - Campos**

```pascal
type
  TDbSet<T> = class(TInterfacedObject, IDbSet<T>)
  private
    FNoTracking: Boolean;  // Flag para controlar tracking
    // ... campos existentes ...
```

### **3. Modificar Hydrate**

```pascal
function TDbSet<T>.Hydrate(const Reader: IDbReader): T;
begin
  // ... código de criação do objeto ...
  
  // NOVO: Só adiciona ao IdentityMap se tracking estiver habilitado
  if not FNoTracking then
  begin
    if PKVal <> '' then
      FIdentityMap.Add(PKVal, Result);
    TLazyInjector.Inject(FContext, Result);
  end;
  
  // ... resto do código ...
end;
```

### **4. Modificar List**

```pascal
function TDbSet<T>.List(const ASpec: ISpecification<T>): IList<T>;
begin
  if PTypeInfo(TypeInfo(T)).Kind = tkClass then
  begin
    // NOVO: Ownership depende do modo de tracking
    if FNoTracking then
      Result := TCollections.CreateObjectList<T>  // OwnsObjects = True
    else
      Result := TCollections.CreateList<T>(False)  // OwnsObjects = False
  end
  else
    Result := TCollections.CreateList<T>;
    
  // ... resto do código ...
end;
```

### **5. Implementar AsNoTracking**

```pascal
function TDbSet<T>.AsNoTracking: IDbSet<T>;
begin
  FNoTracking := True;
  Result := Self;  // Retorna self para fluent API
end;
```

## 🧪 Testes

### **Teste 1: No Tracking não adiciona ao IdentityMap**
```pascal
procedure TestNoTrackingDoesNotAddToIdentityMap;
var
  User: TUser;
begin
  User := TUser.Create;
  User.Name := 'Test';
  Context.Entities<TUser>.Add(User);
  Context.SaveChanges;
  
  Context.Clear;  // Limpa IdentityMap
  
  var Users := Context.Entities<TUser>.AsNoTracking.List;
  AssertTrue(Users.Count = 1);
  
  // Buscar novamente COM tracking
  var TrackedUser := Context.Entities<TUser>.Find(User.Id);
  
  // Devem ser instâncias DIFERENTES (no tracking não foi para IdentityMap)
  AssertTrue(Users[0] <> TrackedUser);
end;
```

### **Teste 2: No Tracking libera objetos**
```pascal
procedure TestNoTrackingFreesObjects;
var
  InitialMemory: Int64;
begin
  InitialMemory := GetMemoryUsed;
  
  // Criar muitos objetos no tracking
  for i := 1 to 10000 do
  begin
    var Users := Context.Entities<TUser>.AsNoTracking.List;
    // Users sai de escopo e libera objetos
  end;
  
  var FinalMemory := GetMemoryUsed;
  
  // Memória deve estar próxima da inicial
  AssertTrue(Abs(FinalMemory - InitialMemory) < 1_000_000);
end;
```

### **Teste 3: Performance Benchmark**
```pascal
procedure BenchmarkNoTracking;
var
  StartTime: TDateTime;
begin
  // Tracking
  StartTime := Now;
  for i := 1 to 1000 do
    var Users := Context.Entities<TUser>.List;
  var TrackingTime := MillisecondsBetween(Now, StartTime);
  
  // No Tracking
  StartTime := Now;
  for i := 1 to 1000 do
    var Users := Context.Entities<TUser>.AsNoTracking.List;
  var NoTrackingTime := MillisecondsBetween(Now, StartTime);
  
  WriteLn(Format('Tracking: %dms, No Tracking: %dms (%.1f%% faster)', 
    [TrackingTime, NoTrackingTime, 
     ((TrackingTime - NoTrackingTime) / TrackingTime) * 100]));
end;
```

## 📊 Comparação com Entity Framework

### **Entity Framework Core:**
```csharp
// Tracking (padrão)
var users = context.Users.ToList();

// No Tracking
var users = context.Users.AsNoTracking().ToList();
```

### **Dext ORM (proposto):**
```pascal
// Tracking (padrão)
var Users := Context.Entities<TUser>.List;

// No Tracking
var Users := Context.Entities<TUser>.AsNoTracking.List;
```

## ⚠️ Considerações

### **1. Lazy Loading**
No tracking **desabilita** lazy loading, pois não há contexto para carregar relacionamentos.

```pascal
var Users := Context.Entities<TUser>.AsNoTracking.List;
// Users[0].Address será NIL mesmo se houver FK
```

**Solução**: Usar `Include` explicitamente:
```pascal
var Users := Context.Entities<TUser>
  .AsNoTracking
  .List(Specification.All<TUser>.Include('Address'));
```

### **2. Detach vs No Tracking**

**Detach** (atual):
```pascal
var User := Context.Entities<TUser>.Find(1);
Context.Entities<TUser>.Detach(User);
// User agora está "órfão" - quem libera?
```

**No Tracking** (melhor):
```pascal
var User := Context.Entities<TUser>.AsNoTracking.Find(1);
// User será liberado quando sair de escopo
```

### **3. Thread Safety**
No tracking é **thread-safe** por design, pois não compartilha estado (IdentityMap).

## 🎯 Prioridade

**ALTA** - Essencial para:
- APIs REST (maioria dos endpoints são read-only)
- Microservices
- Relatórios
- Background jobs

## 📅 Estimativa

- **Implementação**: 4-6 horas
- **Testes**: 2-3 horas
- **Documentação**: 1 hora
- **Total**: ~8-10 horas

## ✅ Checklist de Implementação

- [ ] Adicionar `FNoTracking: Boolean` em `TDbSet<T>`
- [ ] Implementar `AsNoTracking: IDbSet<T>`
- [ ] Modificar `Hydrate` para respeitar flag
- [ ] Modificar `List` para ownership condicional
- [ ] Modificar `Find` para ownership condicional
- [ ] Adicionar testes unitários
- [ ] Adicionar benchmark de performance
- [ ] Atualizar documentação
- [ ] Adicionar exemplos no README
