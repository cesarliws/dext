# Dext Minimal API - Guia Completo

## 📚 Índice

- [Introdução](#introdução)
- [Instalação](#instalação)
- [Conceitos Fundamentais](#conceitos-fundamentais)
- [Model Binding](#model-binding)
- [Route Parameters](#route-parameters)
- [Dependency Injection](#dependency-injection)
- [HTTP Methods](#http-methods)
- [Exemplos Práticos](#exemplos-práticos)
- [API Reference](#api-reference)

---

## 🚀 Introdução

O **Dext Minimal API** é um framework moderno e minimalista para criação de APIs RESTful em Delphi, inspirado no ASP.NET Core Minimal APIs. Ele oferece:

- ✅ **Model Binding automático** de múltiplas fontes (Body, Query, Route, Headers)
- ✅ **Dependency Injection** nativa
- ✅ **Route Parameters** com tipos primitivos e records
- ✅ **Extensões genéricas** para endpoints tipados
- ✅ **Suporte completo a HTTP** (GET, POST, PUT, DELETE)
- ✅ **JSON serialization/deserialization** integrado

---

## 📦 Instalação

### Requisitos

- Delphi 11 Alexandria ou superior
- Bibliotecas incluídas:
  - `Dext.Core` - Core framework
  - `Dext.Json` - JSON serialization
  - `Dext.DI` - Dependency Injection

### Configuração

1. Adicione os paths ao seu projeto:
   ```
   ..\Core
   ..\Core\Drivers
   ```

2. Adicione as units necessárias:
   ```pascal
   uses
     Dext.Web;
   ```
   ```

---

## 🎯 Conceitos Fundamentais

### WebHost Builder Pattern

O Dext utiliza o padrão Builder para configuração do servidor:

```pascal
var Host := TDextWebHost.CreateDefaultBuilder
  .ConfigureServices(procedure(Services: IServiceCollection)
  begin
    // Registrar serviços
  end)
  .Configure(procedure(App: IApplicationBuilder)
  begin
    // Configurar rotas
  end)
  .Build;

Host.Run;
```

### Handlers Tipados

Os handlers podem receber parâmetros tipados que são automaticamente resolvidos:

```pascal
// Handler com 1 parâmetro
procedure(UserId: Integer)

// Handler com 2 parâmetros
procedure(UserId: Integer; UserService: IUserService)

// Handler com 3 parâmetros
procedure(UserId: Integer; Request: TUpdateRequest; Ctx: IHttpContext)
```

---

## 🔗 Model Binding

O Model Binding é o processo de mapear dados da requisição HTTP para parâmetros do handler.

### Fontes de Binding

| Fonte | Descrição | Atributo | Exemplo |
|-------|-----------|----------|---------|
| **Body** | JSON no corpo da requisição | `[FromBody]` | `procedure(User: TUser)` |
| **Route** | Parâmetros na URL | `[FromRoute]` | `procedure(Id: Integer)` |
| **Query** | Query string | `[FromQuery]` | `procedure(Filter: TFilter)` |
| **Header** | HTTP Headers | `[FromHeader]` | `procedure(Token: string)` |
| **Services** | DI Container | `[FromServices]` | `procedure(Service: IService)` |

### Inferência Automática

Quando não há atributos explícitos, o framework infere a fonte baseado no tipo:

```pascal
// Record → Body
procedure(User: TCreateUserRequest)

// Interface → Services
procedure(UserService: IUserService)

// Primitivo com RouteParams → Route
procedure(Id: Integer)  // Se há {id} na rota

// Primitivo sem RouteParams → Query
procedure(Page: Integer)  // Se não há route params

// IHttpContext → Context
procedure(Ctx: IHttpContext)
```

### Exemplo Completo

```pascal
type
  TCreateUserRequest = record
    Name: string;
    Email: string;
    Age: Integer;
  end;

// POST /api/users
App.Builder.MapPost<TCreateUserRequest, IHttpContext>('/api/users',
  procedure(Request: TCreateUserRequest; Ctx: IHttpContext)
  begin
    // Request é automaticamente deserializado do JSON body
    Ctx.Response.Json(Format('{"message":"User %s created"}', [Request.Name]));
  end
);
```

---

## 🛣️ Route Parameters

### Primitivos

Suporte nativo a tipos primitivos em route parameters:

```pascal
// Integer
App.Builder.MapGet<Integer, IHttpContext>('/users/{id}',
  procedure(UserId: Integer; Ctx: IHttpContext)
  begin
    Ctx.Response.Json(Format('{"userId":%d}', [UserId]));
  end
);

// String
App.Builder.MapGet<string, IHttpContext>('/posts/{slug}',
  procedure(Slug: string; Ctx: IHttpContext)
  begin
    Ctx.Response.Json(Format('{"slug":"%s"}', [Slug]));
  end
);

// GUID
App.Builder.MapGet<TGUID, IHttpContext>('/items/{guid}',
  procedure(ItemGuid: TGUID; Ctx: IHttpContext)
  begin
    Ctx.Response.Json(Format('{"guid":"%s"}', [GUIDToString(ItemGuid)]));
  end
);
```

### Múltiplos Parâmetros

Para múltiplos route parameters, use um record:

```pascal
type
  TPostRoute = record
    Year: Integer;
    Month: Integer;
  end;

// GET /posts/{year}/{month}
App.Builder.MapGet<TPostRoute, IHttpContext>('/posts/{year}/{month}',
  procedure(Route: TPostRoute; Ctx: IHttpContext)
  begin
    Ctx.Response.Json(Format('{"year":%d,"month":%d}', 
      [Route.Year, Route.Month]));
  end
);
```

### Tipos Suportados

- ✅ `Integer`, `Int64`
- ✅ `String`, `UnicodeString`
- ✅ `Boolean`
- ✅ `TGUID`
- ✅ `Double`, `Single`
- ✅ `TDateTime`
- ✅ Records customizados

---

## 💉 Dependency Injection

### Registrando Serviços

```pascal
.ConfigureServices(procedure(Services: IServiceCollection)
begin
  // Singleton - uma instância para toda a aplicação
  Services.AddSingleton<IUserService, TUserService>;
  
  // Scoped - uma instância por requisição (futuro)
  // Services.AddScoped<IDbContext, TDbContext>;
  
  // Transient - nova instância sempre (futuro)
  // Services.AddTransient<IEmailService, TEmailService>;
end)
```

### Injetando em Handlers

```pascal
// Injeção automática de serviço
App.Builder.MapGet<Integer, IUserService, IHttpContext>('/users/{id}',
  procedure(UserId: Integer; UserService: IUserService; Ctx: IHttpContext)
  begin
    var UserName := UserService.GetUserName(UserId);
    Ctx.Response.Json(Format('{"name":"%s"}', [UserName]));
  end
);
```

---

## 🌐 HTTP Methods

### GET

```pascal
// Simples
App.Builder.MapGet<IHttpContext>('/api/health',
  procedure(Ctx: IHttpContext)
  begin
    Ctx.Response.Json('{"status":"healthy"}');
  end
);

// Com route parameter
App.Builder.MapGet<Integer, IHttpContext>('/api/users/{id}',
  procedure(UserId: Integer; Ctx: IHttpContext)
  begin
    Ctx.Response.Json(Format('{"userId":%d}', [UserId]));
  end
);
```

### POST

```pascal
type
  TCreateUserRequest = record
    Name: string;
    Email: string;
  end;

App.Builder.MapPost<TCreateUserRequest, IHttpContext>('/api/users',
  procedure(Request: TCreateUserRequest; Ctx: IHttpContext)
  begin
    Ctx.Response.StatusCode := 201;
    Ctx.Response.Json(Format('{"name":"%s","email":"%s"}', 
      [Request.Name, Request.Email]));
  end
);
```

### PUT

```pascal
type
  TUpdateUserRequest = record
    Name: string;
    Email: string;
  end;

App.Builder.MapPut<Integer, TUpdateUserRequest, IHttpContext>('/api/users/{id}',
  procedure(UserId: Integer; Request: TUpdateUserRequest; Ctx: IHttpContext)
  begin
    Ctx.Response.Json(Format('{"userId":%d,"updated":true}', [UserId]));
  end
);
```

### DELETE

```pascal
App.Builder.MapDelete<Integer, IHttpContext>('/api/users/{id}',
  procedure(UserId: Integer; Ctx: IHttpContext)
  begin
    Ctx.Response.Json(Format('{"userId":%d,"deleted":true}', [UserId]));
  end
);
```

---

## 💡 Exemplos Práticos

### CRUD Completo

```pascal
program UserAPI;

uses
  System.SysUtils,
  Dext.Web;

type
  TCreateUserRequest = record
    Name: string;
    Email: string;
  end;

  TUpdateUserRequest = record
    Name: string;
    Email: string;
  end;

  IUserService = interface
    ['{BFD0C440-E062-4D78-9842-8308E413B6B9}']
    function GetUser(Id: Integer): string;
    function CreateUser(const Name, Email: string): Integer;
    function UpdateUser(Id: Integer; const Name, Email: string): Boolean;
    function DeleteUser(Id: Integer): Boolean;
  end;

  TUserService = class(TInterfacedObject, IUserService)
  public
    function GetUser(Id: Integer): string;
    function CreateUser(const Name, Email: string): Integer;
    function UpdateUser(Id: Integer; const Name, Email: string): Boolean;
    function DeleteUser(Id: Integer): Boolean;
  end;

{ TUserService }

function TUserService.GetUser(Id: Integer): string;
begin
  Result := Format('User_%d', [Id]);
end;

function TUserService.CreateUser(const Name, Email: string): Integer;
begin
  Result := Random(1000);
end;

function TUserService.UpdateUser(Id: Integer; const Name, Email: string): Boolean;
begin
  Result := True;
end;

function TUserService.DeleteUser(Id: Integer): Boolean;
begin
  Result := True;
end;

begin
  var App := TDextApplication.Create;

  // Register Services
  App.Services.AddSingleton<IUserService, TUserService>;

  var Builder := App.Builder;

  // GET /api/users/{id}
  Builder.MapGet<Integer, IUserService, IHttpContext>(
    '/api/users/{id}',
    procedure(UserId: Integer; UserService: IUserService; Ctx: IHttpContext)
    begin
      var UserName := UserService.GetUser(UserId);
      Ctx.Response.Json(Format('{"id":%d,"name":"%s"}', [UserId, UserName]));
    end
  );

  // POST /api/users
  Builder.MapPost<TCreateUserRequest, IUserService, IHttpContext>(
    '/api/users',
    procedure(Request: TCreateUserRequest; UserService: IUserService; Ctx: IHttpContext)
    begin
      var NewId := UserService.CreateUser(Request.Name, Request.Email);
      Ctx.Response.StatusCode := 201;
      Ctx.Response.Json(Format('{"id":%d,"name":"%s","email":"%s"}', 
        [NewId, Request.Name, Request.Email]));
    end
  );

  // PUT /api/users/{id}
  Builder.MapPut<Integer, TUpdateUserRequest, IUserService, IHttpContext>(
    '/api/users/{id}',
    procedure(UserId: Integer; Request: TUpdateUserRequest; 
              UserService: IUserService; Ctx: IHttpContext)
    begin
      UserService.UpdateUser(UserId, Request.Name, Request.Email);
      Ctx.Response.Json(Format('{"id":%d,"updated":true}', [UserId]));
    end
  );

  // DELETE /api/users/{id}
  Builder.MapDelete<Integer, IUserService, IHttpContext>(
    '/api/users/{id}',
    procedure(UserId: Integer; UserService: IUserService; Ctx: IHttpContext)
    begin
      UserService.DeleteUser(UserId);
      Ctx.Response.Json(Format('{"id":%d,"deleted":true}', [UserId]));
    end
  );

  WriteLn('Server running on http://localhost:8080');
  App.Run(8080);
end.
```

---

## 📖 API Reference

### TApplicationBuilderExtensions

Classe com métodos de extensão para configuração de rotas.

#### MapGet

```pascal
class function MapGet<T>(App: IApplicationBuilder; const Path: string; 
  Handler: THandlerProc<T>): IApplicationBuilder;

class function MapGet<T1, T2>(App: IApplicationBuilder; const Path: string; 
  Handler: THandlerProc<T1, T2>): IApplicationBuilder;

class function MapGet<T1, T2, T3>(App: IApplicationBuilder; const Path: string; 
  Handler: THandlerProc<T1, T2, T3>): IApplicationBuilder;
```

#### MapPost

```pascal
class function MapPost<T>(App: IApplicationBuilder; const Path: string; 
  Handler: THandlerProc<T>): IApplicationBuilder;

class function MapPost<T1, T2>(App: IApplicationBuilder; const Path: string; 
  Handler: THandlerProc<T1, T2>): IApplicationBuilder;

class function MapPost<T1, T2, T3>(App: IApplicationBuilder; const Path: string; 
  Handler: THandlerProc<T1, T2, T3>): IApplicationBuilder;
```

#### MapPut

```pascal
class function MapPut<T>(App: IApplicationBuilder; const Path: string; 
  Handler: THandlerProc<T>): IApplicationBuilder;

class function MapPut<T1, T2>(App: IApplicationBuilder; const Path: string; 
  Handler: THandlerProc<T1, T2>): IApplicationBuilder;

class function MapPut<T1, T2, T3>(App: IApplicationBuilder; const Path: string; 
  Handler: THandlerProc<T1, T2, T3>): IApplicationBuilder;
```

#### MapDelete

```pascal
class function MapDelete<T>(App: IApplicationBuilder; const Path: string; 
  Handler: THandlerProc<T>): IApplicationBuilder;

class function MapDelete<T1, T2>(App: IApplicationBuilder; const Path: string; 
  Handler: THandlerProc<T1, T2>): IApplicationBuilder;

class function MapDelete<T1, T2, T3>(App: IApplicationBuilder; const Path: string; 
  Handler: THandlerProc<T1, T2, T3>): IApplicationBuilder;
```

### IModelBinder

Interface para binding de parâmetros.

```pascal
IModelBinder = interface
  function BindBody(AType: PTypeInfo; Context: IHttpContext): TValue;
  function BindQuery(AType: PTypeInfo; Context: IHttpContext): TValue;
  function BindRoute(AType: PTypeInfo; Context: IHttpContext): TValue;
  function BindHeader(AType: PTypeInfo; Context: IHttpContext): TValue;
  function BindServices(AType: PTypeInfo; Context: IHttpContext): TValue;
end;
```

### Atributos de Binding

```pascal
FromBodyAttribute = class(BindingAttribute)
FromQueryAttribute = class(BindingAttribute)
FromRouteAttribute = class(BindingAttribute)
FromHeaderAttribute = class(BindingAttribute)
FromServicesAttribute = class(BindingAttribute)
```

---

## 🔧 Troubleshooting

### Erro: "BindRoute currently only supports records or single primitive inference"

**Causa**: Tentativa de bind de múltiplos route parameters para um tipo primitivo.

**Solução**: Use um record para múltiplos parâmetros:

```pascal
type
  TUserRoute = record
    UserId: Integer;
    PostId: Integer;
  end;

MapGet<TUserRoute, IHttpContext>(App, '/users/{userId}/posts/{postId}', ...);
```

### Erro: "Service not found for interface"

**Causa**: Serviço não foi registrado no container DI.

**Solução**: Registre o serviço em `ConfigureServices`:

```pascal
.ConfigureServices(procedure(Services: IServiceCollection)
begin
  TServiceCollectionExtensions.AddSingleton<IMyService, TMyService>(Services);
end)
```

---

## 📝 Notas de Versão

### v1.0.0 (2025-11-19)

- ✅ Route parameters com tipos primitivos
- ✅ MapPut e MapDelete implementados
- ✅ Extensões genéricas para 1, 2 e 3 parâmetros
- ✅ Model binding de múltiplas fontes
- ✅ Dependency injection integrado
- ✅ JSON serialization/deserialization

---

## 📄 Licença

[Sua licença aqui]

## 🤝 Contribuindo

[Instruções de contribuição]

---

**Desenvolvido com ❤️ usando Delphi**
