# Dext Scoped Services

Implementação completa de **Scoped Lifetime** para Dependency Injection, inspirado no ASP.NET Core.

## 🎯 O que são Scoped Services?

Scoped services são criados **uma vez por requisição HTTP** e compartilhados entre todos os componentes que precisam deles durante essa requisição.

### Comparação de Lifetimes

| Lifetime | Quando é criado | Quando é destruído | Uso típico |
|----------|-----------------|-------------------|------------|
| **Singleton** | Uma vez (na inicialização) | No shutdown da aplicação | Configurações, Caches globais |
| **Scoped** | Uma vez por requisição | No fim da requisição | DbContext, Unit of Work, Request Context |
| **Transient** | Toda vez que é resolvido | Imediatamente após uso | Serviços stateless, Helpers |

## 📦 Como Usar

### 1. Registrar Serviços Scoped

```pascal
.ConfigureServices(procedure(Services: IServiceCollection)
begin
  // Registrar como SCOPED
  TServiceCollectionExtensions.AddScoped<IRequestContext, TRequestContext>(Services);
  TServiceCollectionExtensions.AddScoped<IDbContext, TDbContext>(Services);
end)
```

### 2. Adicionar Middleware de Scope

**IMPORTANTE**: Adicione o middleware `UseServiceScope` logo no início do pipeline:

```pascal
.Configure(procedure(App: IApplicationBuilder)
begin
  // PRIMEIRO: Exception Handler
  TApplicationBuilderMiddlewareExtensions.UseExceptionHandler(App);
  
  // SEGUNDO: Service Scope (cria scope por requisição)
  TApplicationBuilderScopeExtensions.UseServiceScope(App);
  
  // Resto dos middlewares...
  TApplicationBuilderRateLimitExtensions.UseRateLimiting(App, ...);
  // ...
end)
```

### 3. Usar Normalmente

O framework injeta automaticamente:

```pascal
App.MapGet<IRequestContext, IDbContext, IResult>(
  '/api/data',
  function(Ctx: IRequestContext; Db: IDbContext): IResult
  begin
    // Ctx e Db são a MESMA instância durante toda esta requisição
    // Se outro serviço injetado também pedir IRequestContext, 
    // receberá a MESMA instância
    
    Result := Results.Json('{"requestId":"' + Ctx.RequestId + '"}');
  end
);
```

## 💡 Exemplo Completo: Request Context

### Definir Interface e Implementação

```pascal
type
  IRequestContext = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    function GetRequestId: string;
    function GetTimestamp: TDateTime;
    property RequestId: string read GetRequestId;
    property Timestamp: TDateTime read GetTimestamp;
  end;

  TRequestContext = class(TInterfacedObject, IRequestContext)
  private
    FRequestId: string;
    FTimestamp: TDateTime;
  public
    constructor Create;
    function GetRequestId: string;
    function GetTimestamp: TDateTime;
  end;

constructor TRequestContext.Create;
begin
  inherited Create;
  FRequestId := TGUID.NewGuid.ToString;
  FTimestamp := Now;
  WriteLn('[RequestContext] Created: ' + FRequestId);
end;

function TRequestContext.GetRequestId: string;
begin
  Result := FRequestId;
end;

function TRequestContext.GetTimestamp: TDateTime;
begin
  Result := FTimestamp;
end;
```

### Registrar e Usar

```pascal
// Registrar
Services.AddScoped<IRequestContext, TRequestContext>;

// Usar em múltiplos lugares
App.MapGet<IRequestContext, IResult>(
  '/api/request-info',
  function(Ctx: IRequestContext): IResult
  begin
    Result := Results.Json(Format(
      '{"requestId":"%s","timestamp":"%s"}',
      [Ctx.RequestId, DateTimeToStr(Ctx.Timestamp)]
    ));
  end
);

// Outro endpoint - MESMA instância se na mesma requisição
App.MapGet<IRequestContext, IUserService, IResult>(
  '/api/user-with-context',
  function(Ctx: IRequestContext; UserSvc: IUserService): IResult
  begin
    // Ctx.RequestId será o MESMO que no endpoint acima
    // se for a mesma requisição HTTP
    Result := Results.Json('...');
  end
);
```

## 🔥 Casos de Uso Reais

### 1. DbContext (Entity Framework-like)

```pascal
type
  IDbContext = interface
    function GetUsers: TList<TUser>;
    procedure SaveChanges;
  end;

// Registrar como Scoped
Services.AddScoped<IDbContext, TDbContext>;

// Usar
App.MapPost<TCreateUserRequest, IDbContext, IResult>(
  '/api/users',
  function(Request: TCreateUserRequest; Db: IDbContext): IResult
  begin
    var User := TUser.Create;
    User.Name := Request.Name;
    Db.Users.Add(User);
    Db.SaveChanges; // Commit no fim da requisição
    Result := Results.Created('/api/users/' + User.Id.ToString, User);
  end
);
```

### 2. Unit of Work

```pascal
type
  IUnitOfWork = interface
    function GetUserRepository: IUserRepository;
    function GetOrderRepository: IOrderRepository;
    procedure Commit;
    procedure Rollback;
  end;

// Scoped: uma transação por requisição
Services.AddScoped<IUnitOfWork, TUnitOfWork>;

App.MapPost<TCreateOrderRequest, IUnitOfWork, IResult>(
  '/api/orders',
  function(Request: TCreateOrderRequest; UoW: IUnitOfWork): IResult
  begin
    try
      var User := UoW.GetUserRepository.FindById(Request.UserId);
      var Order := TOrder.Create(User, Request.Items);
      UoW.GetOrderRepository.Add(Order);
      UoW.Commit; // Commit da transação
      Result := Results.Created('/api/orders/' + Order.Id.ToString, Order);
    except
      UoW.Rollback;
      raise;
    end;
  end
);
```

### 3. Request Tracing

```pascal
type
  IRequestTracer = interface
    procedure LogEvent(const AMessage: string);
    function GetTraceId: string;
  end;

Services.AddScoped<IRequestTracer, TRequestTracer>;

// Todos os serviços podem logar no mesmo trace
App.MapGet<IRequestTracer, IUserService, IResult>(
  '/api/users/{id}',
  function(Tracer: IRequestTracer; UserSvc: IUserService): IResult
  begin
    Tracer.LogEvent('Fetching user');
    var User := UserSvc.GetUser(123);
    Tracer.LogEvent('User fetched successfully');
    // Tracer.GetTraceId retorna o mesmo ID para toda a requisição
    Result := Results.Json(User);
  end
);
```

## ⚠️ Importante

1. **Sempre adicione `UseServiceScope`** no início do pipeline
2. **Não injete Scoped em Singleton**: Um singleton não pode depender de um scoped (erro em runtime)
3. **Scoped é thread-safe**: Cada thread (requisição) tem seu próprio scope
4. **Cleanup automático**: Instâncias scoped são liberadas automaticamente no fim da requisição

## 🚀 Performance

- **Melhor que Transient**: Evita criar múltiplas instâncias do mesmo serviço
- **Melhor que Singleton para estado**: Não precisa de locks para estado por requisição
- **Ideal para DbContext**: Evita problemas de concorrência e memory leaks

## 📚 Arquitetura Interna

```
Request 1                    Request 2
    |                            |
    v                            v
[Scope 1]                    [Scope 2]
    |                            |
    ├─ IRequestContext (A)       ├─ IRequestContext (B)
    ├─ IDbContext (A)            ├─ IDbContext (B)
    └─ IUnitOfWork (A)           └─ IUnitOfWork (B)
         |                            |
         v                            v
    [Singleton Services]  <-- Compartilhados
         |
         └─ IConfiguration
         └─ ILogger
```

## 🔗 Referências

- ASP.NET Core Dependency Injection: https://learn.microsoft.com/en-us/aspnet/core/fundamentals/dependency-injection
- Service Lifetimes: https://learn.microsoft.com/en-us/dotnet/core/extensions/dependency-injection#service-lifetimes

---

**Dext Framework** - Modern Web Framework for Delphi
