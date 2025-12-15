# Action Filters

Action Filters no Dext permitem executar código antes e depois da execução de uma action de controller, de forma declarativa usando atributos. Inspirado no ASP.NET Core.

## 📋 Índice

- [Conceito](#conceito)
- [Filtros Built-in](#filtros-built-in)
- [Criando Filtros Customizados](#criando-filtros-customizados)
- [Ordem de Execução](#ordem-de-execução)
- [Casos de Uso](#casos-de-uso)
- [API Reference](#api-reference)

---

## Conceito

Action Filters são interceptadores que executam lógica em pontos específicos do pipeline de execução de uma action:

1. **OnActionExecuting**: Antes da action executar
2. **OnActionExecuted**: Depois da action executar (ou se houver exceção)

```pascal
[LogAction]  // ← Filter executado automaticamente
[DextGet('/users')]
function GetUsers: IResult;
```

### Benefícios

- ✅ **Reutilização**: Lógica comum em um só lugar
- ✅ **Declarativo**: Código limpo e legível
- ✅ **Composição**: Combine múltiplos filtros
- ✅ **Testável**: Filtros podem ser testados isoladamente

---

## Filtros Built-in

O Dext já vem com 5 filtros prontos para uso:

### 1. `[LogAction]` - Logging Automático

Loga automaticamente o tempo de execução e resultado da action.

```pascal
[LogAction]
[DextGet('/api/users')]
function GetUsers: IResult;
```

**Output no console:**
```
[ActionFilter] Executing: TUserController.GetUsers (GET /api/users)
[ActionFilter] Executed: TUserController.GetUsers - SUCCESS (took 45 ms)
```

### 2. `[RequireHeader]` - Validação de Headers

Valida que um header específico está presente na requisição.

```pascal
[RequireHeader('X-API-Key', 'API Key is required')]
[DextPost('/api/data')]
function PostData: IResult;
```

**Comportamento:**
- Se o header estiver presente: continua normalmente
- Se o header estiver ausente: retorna `400 Bad Request` com mensagem de erro

### 3. `[ResponseCache]` - Headers de Cache

Adiciona headers de cache HTTP à resposta.

```pascal
[ResponseCache(60, 'public')]  // Cache por 60 segundos
[DextGet('/api/products')]
function GetProducts: IResult;
```

**Headers adicionados:**
```
Cache-Control: public, max-age=60
```

**Parâmetros:**
- `Duration`: Tempo em segundos
- `Location`: `'public'`, `'private'`, ou `'no-cache'` (padrão: `'public'`)

### 4. `[AddHeader]` - Headers Customizados

Adiciona headers customizados à resposta.

```pascal
[AddHeader('X-Custom-Header', 'MyValue')]
[DextGet('/api/info')]
function GetInfo: IResult;
```

### 5. `[ValidateModel]` - Validação Customizada

Placeholder para validação customizada (pode ser estendido).

```pascal
[ValidateModel]
[DextPost('/api/users')]
function CreateUser([FromBody] User: TUserRequest): IResult;
```

---

## Criando Filtros Customizados

### Passo 1: Criar a Classe do Filtro

```pascal
uses
  Dext.Filters;

type
  // Filtro que verifica se o usuário é admin
  RequireAdminAttribute = class(ActionFilterAttribute)
  public
    procedure OnActionExecuting(AContext: IActionExecutingContext); override;
  end;

implementation

procedure RequireAdminAttribute.OnActionExecuting(AContext: IActionExecutingContext);
begin
  // Verificar se o usuário é admin
  if (AContext.HttpContext.User = nil) or 
     (not AContext.HttpContext.User.IsInRole('Admin')) then
  begin
    // Short-circuit: retornar 403 Forbidden
    AContext.Result := Results.StatusCode(403, '{"error":"Admin access required"}');
  end;
end;
```

### Passo 2: Usar o Filtro

```pascal
[RequireAdmin]
[DextDelete('/api/users/{id}')]
function DeleteUser(Id: Integer): IResult;
```

### Exemplo: Filtro de Auditoria

```pascal
type
  AuditAttribute = class(ActionFilterAttribute)
  private
    FAction: string;
  public
    constructor Create(const AAction: string);
    procedure OnActionExecuted(AContext: IActionExecutedContext); override;
  end;

constructor AuditAttribute.Create(const AAction: string);
begin
  inherited Create;
  FAction := AAction;
end;

procedure AuditAttribute.OnActionExecuted(AContext: IActionExecutedContext);
begin
  if not Assigned(AContext.Exception) then
  begin
    // Logar ação bem-sucedida
    var UserId := AContext.HttpContext.User.Identity.Name;
    WriteLn(Format('[Audit] User %s performed %s at %s', 
      [UserId, FAction, DateTimeToStr(Now)]));
  end;
end;

// Uso:
[Audit('DELETE_USER')]
[DextDelete('/api/users/{id}')]
function DeleteUser(Id: Integer): IResult;
```

---

## Ordem de Execução

### Múltiplos Filtros

Quando você aplica múltiplos filtros, eles executam em ordem específica:

```pascal
[FilterA]
[FilterB]
[FilterC]
[DextGet('/test')]
function Test: IResult;
```

**Ordem de execução:**

1. `FilterA.OnActionExecuting`
2. `FilterB.OnActionExecuting`
3. `FilterC.OnActionExecuting`
4. **Action executa**
5. `FilterC.OnActionExecuted` (ordem reversa!)
6. `FilterB.OnActionExecuted`
7. `FilterA.OnActionExecuted`

### Filtros em Controller e Method

Filtros podem ser aplicados tanto no controller quanto no método:

```pascal
[LogAction]  // ← Aplica a TODOS os métodos
[DextController('/api')]
TUserController = class
public
  [ResponseCache(60)]  // ← Aplica APENAS a este método
  [DextGet('/users')]
  function GetUsers: IResult;
end;
```

**Ordem:**
1. Filtros do Controller (OnActionExecuting)
2. Filtros do Método (OnActionExecuting)
3. **Action**
4. Filtros do Método (OnActionExecuted - reverso)
5. Filtros do Controller (OnActionExecuted - reverso)

### Short-Circuit

Um filtro pode interromper a execução definindo um `Result`:

```pascal
procedure OnActionExecuting(AContext: IActionExecutingContext);
begin
  if not IsValid then
  begin
    AContext.Result := Results.BadRequest('{"error":"Invalid"}');
    // Action NÃO será executada
    // Filtros subsequentes NÃO serão executados
  end;
end;
```

---

## Casos de Uso

### 1. Rate Limiting por Usuário

```pascal
type
  UserRateLimitAttribute = class(ActionFilterAttribute)
  private
    FMaxRequests: Integer;
    FWindowSeconds: Integer;
  public
    constructor Create(AMaxRequests, AWindowSeconds: Integer);
    procedure OnActionExecuting(AContext: IActionExecutingContext); override;
  end;

// Uso:
[UserRateLimit(10, 60)]  // 10 req/min por usuário
[DextPost('/api/expensive-operation')]
function ExpensiveOperation: IResult;
```

### 2. Transformação de Resposta

```pascal
type
  WrapResponseAttribute = class(ActionFilterAttribute)
  public
    procedure OnActionExecuted(AContext: IActionExecutedContext); override;
  end;

procedure WrapResponseAttribute.OnActionExecuted(AContext: IActionExecutedContext);
begin
  // Envolver resposta em um envelope padrão
  // { "success": true, "data": {...} }
end;
```

### 3. Logging de Exceções

```pascal
type
  LogExceptionsAttribute = class(ActionFilterAttribute)
  public
    procedure OnActionExecuted(AContext: IActionExecutedContext); override;
  end;

procedure LogExceptionsAttribute.OnActionExecuted(AContext: IActionExecutedContext);
begin
  if Assigned(AContext.Exception) then
  begin
    // Logar exceção em sistema externo
    LogToSentry(AContext.Exception);
    
    // Marcar como handled para não propagar
    AContext.ExceptionHandled := True;
    
    // Retornar resposta customizada
    AContext.Result := Results.StatusCode(500, '{"error":"Internal error"}');
  end;
end;
```

### 4. Validação de Permissões

```pascal
type
  RequirePermissionAttribute = class(ActionFilterAttribute)
  private
    FPermission: string;
  public
    constructor Create(const APermission: string);
    procedure OnActionExecuting(AContext: IActionExecutingContext); override;
  end;

// Uso:
[RequirePermission('users.delete')]
[DextDelete('/api/users/{id}')]
function DeleteUser(Id: Integer): IResult;
```

---

## API Reference

### IActionExecutingContext

Contexto disponível ANTES da action executar.

```pascal
property HttpContext: IHttpContext;
property ActionDescriptor: TActionDescriptor;
property Result: IResult;  // Set para short-circuit
```

### IActionExecutedContext

Contexto disponível DEPOIS da action executar.

```pascal
property HttpContext: IHttpContext;
property ActionDescriptor: TActionDescriptor;
property Result: IResult;  // Pode modificar o resultado
property Exception: Exception;  // Se houver exceção
property ExceptionHandled: Boolean;  // Set para marcar como handled
```

### TActionDescriptor

Informações sobre a action.

```pascal
ControllerName: string;
ActionName: string;
HttpMethod: string;
Route: string;
```

### ActionFilterAttribute

Classe base para criar filtros.

```pascal
procedure OnActionExecuting(AContext: IActionExecutingContext); virtual;
procedure OnActionExecuted(AContext: IActionExecutedContext); virtual;
```

---

## Comparação com ASP.NET Core

| Feature | Dext | ASP.NET Core |
|---------|------|--------------|
| Action Filters | ✅ | ✅ |
| OnActionExecuting | ✅ | ✅ |
| OnActionExecuted | ✅ | ✅ |
| Short-circuit | ✅ | ✅ |
| Exception Handling | ✅ | ✅ |
| Controller-level Filters | ✅ | ✅ |
| Global Filters | ❌ (futuro) | ✅ |
| Async Filters | ❌ (limitação Delphi) | ✅ |

---

## Melhores Práticas

1. **Mantenha filtros simples**: Um filtro deve fazer uma coisa bem feita
2. **Use short-circuit com cuidado**: Apenas quando realmente necessário
3. **Evite lógica de negócio**: Filtros são para cross-cutting concerns
4. **Teste isoladamente**: Filtros devem ser testáveis sem controller
5. **Documente comportamento**: Especialmente se modificar Result ou Exception

---

## Próximos Passos

- [ ] Global Filters (aplicar a todos os controllers)
- [ ] Result Filters (executam após IResult.Execute)
- [ ] Exception Filters (especializados em tratar exceções)
- [ ] Resource Filters (executam antes do model binding)

---

**Dext Framework** - Modern Web Framework for Delphi
