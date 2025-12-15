# Model Binding - Guia Detalhado

## 📚 Índice

- [Visão Geral](#visão-geral)
- [Fontes de Binding](#fontes-de-binding)
- [Inferência Automática](#inferência-automática)
- [Atributos de Binding](#atributos-de-binding)
- [Conversão de Tipos](#conversão-de-tipos)
- [Exemplos Avançados](#exemplos-avançados)
- [Tratamento de Erros](#tratamento-de-erros)

---

## 🎯 Visão Geral

O **Model Binding** é o processo automático de mapear dados de uma requisição HTTP para parâmetros tipados em handlers. O Dext suporta binding de múltiplas fontes simultaneamente.

### Fluxo de Binding

```
HTTP Request
    ↓
┌─────────────────────────────────┐
│   THandlerInvoker               │
│   - Analisa parâmetros do       │
│     handler via RTTI            │
│   - Determina fonte de binding  │
└─────────────────────────────────┘
    ↓
┌─────────────────────────────────┐
│   TModelBinder                  │
│   - BindBody                    │
│   - BindQuery                   │
│   - BindRoute                   │
│   - BindHeader                  │
│   - BindServices                │
└─────────────────────────────────┘
    ↓
Handler Parameters (Typed)
```

---

## 📦 Fontes de Binding

### 1. Body (JSON)

Deserializa o corpo JSON da requisição para um record.

**Quando usar**: POST, PUT com dados complexos

```pascal
type
  TCreateUserRequest = record
    Name: string;
    Email: string;
    Age: Integer;
    Active: Boolean;
  end;

// POST /api/users
// Body: {"name":"John","email":"john@example.com","age":30,"active":true}
App.Builder.MapPost<TCreateUserRequest, IHttpContext>('/api/users',
  procedure(Request: TCreateUserRequest; Ctx: IHttpContext)
  begin
    // Request.Name = "John"
    // Request.Email = "john@example.com"
    // Request.Age = 30
    // Request.Active = True
  end
);
```

**Atributo explícito**:
```pascal
procedure([FromBody] Request: TCreateUserRequest)
```

### 2. Route Parameters

Extrai valores de parâmetros na URL.

**Quando usar**: Identificadores de recursos (IDs, slugs, GUIDs)

#### Primitivos (Single Parameter)

```pascal
// GET /api/users/123
App.Builder.MapGet<Integer, IHttpContext>('/api/users/{id}',
  procedure(UserId: Integer; Ctx: IHttpContext)
  begin
    // UserId = 123
  end
);

// GET /api/posts/hello-world
App.Builder.MapGet<string, IHttpContext>('/api/posts/{slug}',
  procedure(Slug: string; Ctx: IHttpContext)
  begin
    // Slug = "hello-world"
  end
);
```

#### Records (Multiple Parameters)

```pascal
type
  TPostRoute = record
    Year: Integer;
    Month: Integer;
    Day: Integer;
  end;

// GET /api/posts/2025/11/19
App.Builder.MapGet<TPostRoute, IHttpContext>('/api/posts/{year}/{month}/{day}',
  procedure(Route: TPostRoute; Ctx: IHttpContext)
  begin
    // Route.Year = 2025
    // Route.Month = 11
    // Route.Day = 19
  end
);
```

**Atributo explícito**:
```pascal
type
  TUserRoute = record
    [FromRoute('userId')]
    Id: Integer;
  end;
```

### 3. Query String

Extrai valores da query string.

**Quando usar**: Filtros, paginação, ordenação

```pascal
type
  TUserFilter = record
    Page: Integer;
    PageSize: Integer;
    Active: Boolean;
    SearchTerm: string;
  end;

// GET /api/users?page=1&pageSize=10&active=true&searchTerm=john
App.Builder.MapGet<TUserFilter, IHttpContext>('/api/users',
  procedure(Filter: TUserFilter; Ctx: IHttpContext)
  begin
    // Filter.Page = 1
    // Filter.PageSize = 10
    // Filter.Active = True
    // Filter.SearchTerm = "john"
  end
);
```

**Atributo explícito**:
```pascal
type
  TUserFilter = record
    [FromQuery('p')]
    Page: Integer;
    
    [FromQuery('size')]
    PageSize: Integer;
  end;
```

### 4. Headers

Extrai valores de HTTP headers.

**Quando usar**: Autenticação, metadata, configurações

```pascal
type
  TAuthHeaders = record
    Authorization: string;
    [FromHeader('X-API-Key')]
    ApiKey: string;
    [FromHeader('Accept-Language')]
    Language: string;
  end;

App.Builder.MapGet<TAuthHeaders, IHttpContext>('/api/protected',
  procedure(Headers: TAuthHeaders; Ctx: IHttpContext)
  begin
    // Headers.Authorization = "Bearer token123"
    // Headers.ApiKey = "abc123"
    // Headers.Language = "pt-BR"
  end
);
```

### 5. Services (Dependency Injection)

Injeta serviços do container DI.

**Quando usar**: Acesso a serviços, repositórios, contextos

```pascal
IUserService = interface
  ['{...}']
  function GetUser(Id: Integer): TUser;
end;

App.Builder.MapGet<Integer, IUserService, IHttpContext>(
  '/api/users/{id}',
  procedure(UserId: Integer; UserService: IUserService; Ctx: IHttpContext)
  begin
    var User := UserService.GetUser(UserId);
    // ...
  end
);
```

---

## 🤖 Inferência Automática

Quando não há atributos explícitos, o framework infere a fonte baseado em:

### 1. Tipo do Parâmetro

```pascal
// Record → Body
procedure(User: TCreateUserRequest)

// Interface → Services  
procedure(Service: IUserService)

// IHttpContext → Context
procedure(Ctx: IHttpContext)
```

### 2. Presença de Route Parameters

```pascal
// Primitivo + RouteParams existem → Route
// GET /users/{id}
procedure(Id: Integer)  // Bind de Route

// Primitivo + RouteParams NÃO existem → Query
// GET /users
procedure(Page: Integer)  // Bind de Query
```

### 3. Ordem de Precedência

1. **Atributo explícito** (`[FromBody]`, `[FromRoute]`, etc.)
2. **IHttpContext** → Context
3. **Record** → Body
4. **Interface** → Services
5. **Primitivo com RouteParams** → Route
6. **Primitivo sem RouteParams** → Query

---

## 🏷️ Atributos de Binding

### FromBody

```pascal
procedure([FromBody] Request: TCreateUserRequest)
```

Força binding do corpo JSON, mesmo que o tipo não seja record.

### FromRoute

```pascal
procedure([FromRoute] Id: Integer)
procedure([FromRoute('userId')] Id: Integer)  // Nome customizado
```

Força binding de route parameter.

### FromQuery

```pascal
procedure([FromQuery] Page: Integer)
procedure([FromQuery('p')] Page: Integer)  // Nome customizado
```

Força binding de query string.

### FromHeader

```pascal
procedure([FromHeader] Authorization: string)
procedure([FromHeader('X-API-Key')] ApiKey: string)  // Nome customizado
```

Força binding de header.

### FromServices

```pascal
procedure([FromServices] UserService: IUserService)
```

Força binding do container DI.

---

## 🔄 Conversão de Tipos

### Tipos Primitivos Suportados

| Tipo Delphi | Exemplo | Conversão |
|-------------|---------|-----------|
| `Integer` | `"123"` → `123` | `StrToIntDef` |
| `Int64` | `"9999999999"` → `9999999999` | `StrToInt64Def` |
| `String` | `"hello"` → `"hello"` | Direto |
| `Boolean` | `"true"` → `True` | `SameText` |
| `Double` | `"3.14"` → `3.14` | `TryStrToFloat` |
| `TDateTime` | `"2025-11-19"` → `TDateTime` | `StrToDateTimeDef` |
| `TGUID` | `"{...}"` → `TGUID` | `StringToGUID` |

### Conversão de Boolean

Valores aceitos como `True`:
- `"true"` (case-insensitive)
- `"1"`
- `"yes"`
- `"on"`

Qualquer outro valor = `False`

### Conversão de GUID

Formatos aceitos:
```pascal
// Com chaves
"{12345678-1234-1234-1234-123456789012}"

// Sem chaves
"12345678-1234-1234-1234-123456789012"
```

### Tratamento de Erros

Em caso de erro de conversão:
- **Route/Query/Header**: Usa valor padrão (0, '', False, etc.)
- **Body**: Lança `EBindingException`
- **Services**: Lança `EBindingException` se serviço não encontrado

---

## 💡 Exemplos Avançados

### Combinando Múltiplas Fontes

```pascal
type
  TUpdateUserRequest = record
    Name: string;
    Email: string;
  end;

// PUT /api/users/123?notify=true
// Body: {"name":"John","email":"john@example.com"}
App.Builder.MapPut<Integer, TUpdateUserRequest, Boolean, IUserService, IHttpContext>(
  '/api/users/{id}',
  procedure(UserId: Integer;           // Route
            Request: TUpdateUserRequest; // Body
            Notify: Boolean;             // Query
            UserService: IUserService;   // Services
            Ctx: IHttpContext)           // Context
  begin
    UserService.UpdateUser(UserId, Request.Name, Request.Email);
    
    if Notify then
      UserService.SendNotification(UserId);
      
    Ctx.Response.Json('{"success":true}');
  end
);
```

### Smart Binding (Futuro)

Em desenvolvimento: Um único record recebendo dados de múltiplas fontes.

```pascal
type
  TUpdateUserCommand = record
    [FromRoute]
    UserId: Integer;
    
    [FromBody]
    Name: string;
    
    [FromBody]
    Email: string;
    
    [FromQuery]
    Notify: Boolean;
  end;

// PUT /api/users/123?notify=true
// Body: {"name":"John","email":"john@example.com"}
App.Builder.MapPut<TUpdateUserCommand, IHttpContext>('/api/users/{userId}',
  procedure(Command: TUpdateUserCommand; Ctx: IHttpContext)
  begin
    // Command.UserId = 123 (route)
    // Command.Name = "John" (body)
    // Command.Email = "john@example.com" (body)
    // Command.Notify = True (query)
  end
);
```

### Validação Customizada

```pascal
type
  TCreateUserRequest = record
    Name: string;
    Email: string;
    Age: Integer;
    
    function IsValid: Boolean;
    function ValidationErrors: TArray<string>;
  end;

function TCreateUserRequest.IsValid: Boolean;
begin
  Result := (Name <> '') and 
            (Email.Contains('@')) and 
            (Age >= 18);
end;

function TCreateUserRequest.ValidationErrors: TArray<string>;
begin
  SetLength(Result, 0);
  
  if Name = '' then
    Result := Result + ['Name is required'];
    
  if not Email.Contains('@') then
    Result := Result + ['Invalid email'];
    
  if Age < 18 then
    Result := Result + ['Must be 18 or older'];
end;

// Uso
App.Builder.MapPost<TCreateUserRequest, IHttpContext>('/api/users',
  procedure(Request: TCreateUserRequest; Ctx: IHttpContext)
  begin
    if not Request.IsValid then
    begin
      Ctx.Response.StatusCode := 400;
      Ctx.Response.Json(Format('{"errors":%s}', 
        [TDextJson.Serialize(Request.ValidationErrors)]));
      Exit;
    end;
    
    // Processar request válido
  end
);
```

---

## ⚠️ Tratamento de Erros

### EBindingException

Lançada quando há erro no binding:

```pascal
try
  // Binding automático
except
  on E: EBindingException do
  begin
    Ctx.Response.StatusCode := 400;
    Ctx.Response.Json(Format('{"error":"%s"}', [E.Message]));
  end;
end;
```

### Erros Comuns

| Erro | Causa | Solução |
|------|-------|---------|
| `BindRoute currently only supports records or single primitive inference` | Múltiplos route params com tipo primitivo | Use um record |
| `Service not found for interface` | Serviço não registrado | Registre em `ConfigureServices` |
| `Request body is empty` | Body vazio em POST/PUT | Envie JSON válido |
| `Error binding body` | JSON inválido | Verifique formato JSON |
| `Ambiguous binding` | Múltiplos route params para primitivo | Use record ou especifique atributo |

---

## 🔍 Debugging

### Logs de Binding

O framework imprime logs detalhados durante o binding:

```
🔍 Binding parameter: UserId (Type: Integer)
🛣️  FromRoute: id
  → Received value: 123
  → Converted to Integer: 123
```

### RTTI Inspection

Para debug avançado, você pode inspecionar o processo de binding:

```pascal
var
  Binder := TModelBinder.Create;
  Value := Binder.BindRoute(TypeInfo(Integer), Context);
  
WriteLn('Bound value: ', Value.AsInteger);
```

---

## 📚 Referências

- [Minimal API Guide](minimal-api.md)
- [JSON Features](dext-json-features.md)
- [Dependency Injection](scoped-services.md)

---

**Última atualização**: 2025-11-19
