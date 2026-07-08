# Rotas

Defina padrões de URL e extraia parâmetros.

## Padrões de Rota

### Rotas Estáticas

```pascal
App.MapGet('/users', Handler);           // GET /users
App.MapPost('/users', Handler);          // POST /users
App.MapGet('/api/health', Handler);      // GET /api/health
```

### Parâmetros de Rota

```pascal
App.MapGet('/users/{id}', procedure(Ctx: IHttpContext)
  begin
    var Id := Ctx.Request.RouteParams['id'];
    // Id = "123" para /users/123
  end);

App.MapGet('/orders/{orderId}/items/{itemId}', procedure(Ctx: IHttpContext)
  begin
    var OrderId := Ctx.Request.RouteParams['orderId'];
    var ItemId := Ctx.Request.RouteParams['itemId'];
  end);
```

## Rotas em Controllers

### Rota a Nível de Classe

```pascal
[Route('/api/v1/users')]
TUsersController = class(TController)
public
  [HttpGet]             // GET /api/v1/users
  function GetAll: IActionResult;
  
  [HttpGet('/{id}')]     // GET /api/v1/users/123
  function GetById(Id: Integer): IActionResult;
  
  [HttpPost]            // POST /api/v1/users
  function Create([FromBody] User: TUser): IActionResult;
end;
```

### APIs Versionadas

```pascal
[Route('/api/v1/orders')]
TOrdersV1Controller = class(TController)
end;

[Route('/api/v2/orders')]
TOrdersV2Controller = class(TController)
end;
```

## Parâmetros de Query

```pascal
// URL: /search?q=delphi&page=1&limit=20
App.MapGet('/search', procedure(Ctx: IHttpContext)
  begin
    var Query := Ctx.Request.GetQueryParam('q');
    var Page := Ctx.Request.GetQueryParam('page');
    var Limit := Ctx.Request.GetQueryParam('limit');
  end);
```

## Métodos HTTP

```pascal
App.MapGet('/resource', Handler);     // GET
App.MapPost('/resource', Handler);    // POST
App.MapPut('/resource/{id}', Handler); // PUT
App.MapPatch('/resource/{id}', Handler); // PATCH
App.MapDelete('/resource/{id}', Handler); // DELETE
App.MapQuery('/resource', Handler);   // QUERY (RFC 10008)
```

## Método HTTP QUERY (RFC 10008)

O método HTTP `QUERY` é projetado para operações de consulta seguras, idempotentes e orientadas ao corpo da requisição.

```pascal
App.MapQuery('/users/query', procedure(Ctx: IHttpContext)
  begin
    // Processa o corpo da requisição com a query estruturada
  end);
```

Você pode definir os tipos de mídia (media types) suportados usando o método `.AcceptsQuery`:

```pascal
App.MapQuery('/users/query', Handler);
TEndpointMetadataExtensions.AcceptsQuery(App, ['application/jsonpath', 'application/sql']);
```

Quando uma requisição OPTIONS é enviada para o endpoint, o Dext retorna automaticamente:
- `Allow: QUERY, OPTIONS` (e outros métodos suportados)
- `Accept-Query: application/jsonpath, application/sql`

## Agrupando Rotas

```pascal
App.MapGroup('/api/v1', procedure(Group: IRouteGroup)
  begin
    Group.MapGet('/users', UsersHandler);
    Group.MapGet('/orders', OrdersHandler);
    // Resulta em: /api/v1/users, /api/v1/orders
  end);
```

## Performance do Motor de Roteamento (Radix Tree)

O Dext utiliza um algoritmo otimizado de **Árvore Radix (Trie)** para o roteamento.
Em vez de realizar uma busca linear (`O(N)`) por todas as rotas registradas a cada
requisição, as rotas são compiladas em uma árvore de segmentos de caminho.

Principais características:
- **Complexidade de Busca O(L)**: O tempo de resolução de rotas depende estritamente
  da profundidade/segmentos do caminho da URL (`L`), e não do número de rotas (`N`).
- **Backtracking de Segmentos**: Suporte para segmentos literais, parâmetros (`{id}`)
  e curingas com backtracking para garantir que rotas exatas tenham prioridade.
- **Mapeamento de Metadados Zero-Allocation**: O motor evita o empacotamento pesado
  de RTTI/TValue ao resolver metadados de endpoint, atribuindo os valores
  diretamente por meio da propriedade `IHttpContext.EndpointMetadata`.

---

[← Model Binding](model-binding.md) | [Próximo: Middleware →](middleware.md)

