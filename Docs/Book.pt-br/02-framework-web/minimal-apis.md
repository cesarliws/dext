# Minimal APIs

Minimal APIs fornecem uma abordagem leve, baseada em lambdas, para criar endpoints HTTP com DI e Model Binding automáticos.

> 📦 **Exemplos**: 
> - [Web.EventHub](../../../Examples/Web.EventHub/) - Padrões modernos (2026)
> - [Web.SalesSystem](../../../Examples/Web.SalesSystem/) - Arquitetura Limpa + CQRS

## Endpoints Básicos

```pascal
// GET simples (sem parâmetros)
Builder.MapGet<IResult>('/health',
  function: IResult
  begin
    Result := Results.Ok('healthy');
  end);
```

> [!IMPORTANT]
> O último parâmetro genérico é sempre `IResult` (o tipo de retorno).

## DI + Model Binding (Padrão Recomendado)

O Dext possui **Injeção de Dependência** e **Model Binding** integrados. Serviços, DTOs e parâmetros de rota são injetados **automaticamente** via parâmetros genéricos.

```pascal
// GET com serviço injetado
Builder.MapGet<IUserService, IResult>('/api/users',
  function(Svc: IUserService): IResult
  begin
    Result := Results.Ok(Svc.GetAll);
  end);

// GET com serviço + parâmetro de rota (Integer auto-bound de {id})
Builder.MapGet<IUserService, Integer, IResult>('/api/users/{id}',
  function(Svc: IUserService; Id: Integer): IResult
  begin
    Result := Results.Ok(Svc.GetById(Id));
  end);

// POST com DTO (body) + serviço
Builder.MapPost<TLoginRequest, IAuthService, IResult>('/api/auth/login',
  function(Req: TLoginRequest; Auth: IAuthService): IResult
  begin
    Result := Results.Ok(Auth.Login(Req));
  end);

// QUERY com DTO (body) + serviço (RFC 10008)
Builder.MapQuery<TUserSearchQuery, IUserService, IResult>('/api/users/search',
  function(Query: TUserSearchQuery; Svc: IUserService): IResult
  begin
    Result := Results.Ok(Svc.Search(Query));
  end);
```

> [!WARNING]
> ⛔ **NUNCA** resolva serviços manualmente: `Ctx.RequestServices.GetService<T>`  
> ⛔ **NUNCA** parse o body manualmente: `Ctx.Request.BodyAsJson<T>`  
> Use os parâmetros genéricos — o framework gerencia tudo.

### Como o Framework Resolve Parâmetros

| Tipo | Resolução |
|------|-----------|
| Interfaces/Classes registradas no DI | Injetadas automaticamente |
| Records com `[FromRoute]`/`[FromHeader]`/`[FromQuery]` | Binding misto (Mixed) |
| Records sem atributos | Model Binding do body da requisição |
| `Integer`, `string` correspondendo ao template | Parâmetro de rota direto |
| `IHttpContext` | Injetado automaticamente (use apenas se realmente necessário) |

## Parâmetros de Rota

> [!IMPORTANT]
> Dext usa a sintaxe **`{param}`** para parâmetros de rota (como ASP.NET Core), não `:param` (estilo Express).

### Binding Direto (Tipos Simples)

```pascal
Builder.MapGet<IUserService, Integer, IResult>('/api/users/{id}',
  function(Svc: IUserService; Id: Integer): IResult
  begin
    Result := Results.Ok(Svc.GetById(Id));
  end);
```

### Usando Model Binding Baseado em Record

```pascal
type
  TUserIdRequest = record
    [FromRoute('id')]
    Id: Integer;
  end;

Builder.MapGet<IUserService, TUserIdRequest, IResult>('/api/users/{id}',
  function(Svc: IUserService; Req: TUserIdRequest): IResult
  begin
    Result := Results.Ok(Svc.GetById(Req.Id));
  end);
```

## Binding Misto (Múltiplas Fontes)

O recurso mais poderoso: combine dados de rota, cabeçalho, query e body em um único record.

```pascal
type
  TUpdateStatusRequest = record
    [FromRoute('id')]
    TicketId: Integer;           // Capturado da URL /api/tickets/{id}

    [FromHeader('X-User-Id')]
    UserId: Integer;             // Capturado do Header HTTP

    // Campos sem atributos → Model Binding do body JSON
    NewStatus: TTicketStatus;
    Reason: string;
  end;

Builder.MapPost<TUpdateStatusRequest, ITicketService, IResult>('/api/tickets/{id}/status',
  function(Req: TUpdateStatusRequest; Svc: ITicketService): IResult
  begin
    Result := Results.Ok(Svc.UpdateStatus(Req.TicketId, Req.NewStatus, Req.Reason, Req.UserId));
  end);
```

### Atributos de Binding Disponíveis

| Atributo | Fonte |
|----------|-------|
| `[FromRoute('paramName')]` | Capturado de `{paramName}` na URL |
| `[FromHeader('Header-Name')]` | Capturado do Header HTTP |
| `[FromQuery('queryParam')]` | Capturado de `?queryParam=value` |
| Sem atributo | Capturado do body JSON (padrão) |

> [!WARNING]
> ⛔ **NUNCA** use `Ctx.Request.Route['id']` → use `[FromRoute('id')]` no DTO  
> ⛔ **NUNCA** use `Ctx.Request.Headers['X-User-Id']` → use `[FromHeader('X-User-Id')]` no DTO

> 📚 **Veja Também**: [Model Binding](model-binding.md) para detalhes completos.

## Padrão Results

Use o helper `Results` para respostas consistentes:

```pascal
Results.Ok(Data)             // 200 com corpo JSON
Results.Ok<T>(Data)          // 200 com serialização tipada
Results.Created('/path', E)  // 201 com Header Location
Results.NoContent            // 204
Results.BadRequest('msg')    // 400
Results.NotFound('msg')      // 404
Results.StatusCode(401)      // Unauthorized (alternativa segura)
Results.StatusCode(418, '..') // Status Customizado
Results.Ok                   // 200 sem corpo (overload parameterless)
```

Retorne diretamente dos handlers tipados:
```pascal
function(...): IResult
begin
  Result := Results.Ok(User);
end;
```

## Metadados de Endpoint (OpenAPI)

Enriqueça a documentação Swagger com metadados fluentes:

```pascal
Builder.MapGet<IResult>('/api/health',
  function: IResult
  begin
    Result := Results.Ok('API saudável');
  end)
  .WithTags('Health')
  .WithSummary('Verificar status da API')
  .WithDescription('Retorna uma mensagem simples confirmando que o serviço está rodando.');
```

### Métodos Disponíveis

- `.WithTags(...)` — Agrupa endpoints no Swagger
- `.WithSummary(...)` — Título curto para o endpoint
- `.WithDescription(...)` — Descrição detalhada
- `.WithMetadata(Summary, Description, Tags)` — Define múltiplos metadados de uma vez
- `.RequireAuthorization` — Exige autenticação (opcionalmente aceita Schemes ou Roles)

## Cleanup de Model Binding

O framework libera automaticamente objetos de classe criados pelo Model Binding após a execução do handler:

```pascal
// ✅ CORRETO: Framework libera o Dto automaticamente
Builder.MapPost<TCreateOrderDto, IResult>('/api/orders',
  function(Dto: TCreateOrderDto): IResult
  begin
    // Use o Dto normalmente
    // NÃO chame Dto.Free - o framework cuida disso!
    Result := Results.Ok(Dto.Items.Count);
  end);
```

## FastPath & Data API (`MapFast` & `UseSql`)

Para endpoints de **desempenho crítico** (ping/pong, webhooks de altíssima frequência ou APIs de dados massivas), o Dext oferece a rota **`MapFast`**:

```pascal
// Rota ultra-rápida (bypassa DI Scope e alocações de RTTI)
App.MapFast('GET', '/fastping', procedure(const Req: IHttpRequest; const Res: IHttpResponse)
begin
  Res.SendJsonUtf8('{"message":"pong"}');
end);

// FastPath Data API com UseSql (Streaming direto em UTF-8 para o socket)
App.MapFast('GET', '/api/cities/fast', procedure(const Req: IHttpRequest; const Res: IHttpResponse)
begin
  Db.UseSql('SELECT Id, Name, State FROM Cities')
    .ExecuteToUtf8Stream(Res.GetOutputStream);
end);
```

> [!TIP]
> O método `Db.UseSql` aliado a `Res.GetOutputStream` escreve a resposta diretamente no stream do socket HTTP em UTF-8 sem criar objetos `TJsonObject` intermediários, garantindo **até +123% de vazão** sob carga extrema.

## Padrão de Módulo de Endpoints

Mova todas as definições de rota para uma unit dedicada:

```pascal
unit MeuProjeto.Endpoints;

interface

uses
  Dext.Web; // TAppBuilder, IResult, Results

type
  TMeusEndpoints = class
  public
    class procedure MapEndpoints(const Builder: TAppBuilder); static;
  end;

implementation

class procedure TMeusEndpoints.MapEndpoints(const Builder: TAppBuilder);
begin
  Builder.MapGet<IResult>('/health', ...);
  Builder.MapPost<TLoginRequest, IAuthService, IResult>('/api/auth/login', ...);
end;
```

> [!IMPORTANT]
> O tipo do parâmetro para `MapEndpoints` é `TAppBuilder` (de `Dext.Web`), **não** `IApplicationBuilder`.

Conecte no Startup:
```pascal
App.Builder
  .MapEndpoints(TMeusEndpoints.MapEndpoints)  // Recebe method pointer
  .UseSwagger(...);
```

---

[← Framework Web](README.md) | [Próximo: Controllers →](controllers.md)
