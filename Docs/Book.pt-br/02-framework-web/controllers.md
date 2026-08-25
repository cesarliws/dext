# Controllers

Controllers fornecem uma abordagem baseada em classes (estilo MVC) para organizar endpoints.

> 📦 **Exemplo**: [Web.TicketSales](../../../Examples/Web.TicketSales/)

## Controller Básico

O Dext suporta dois estilos para definir controllers. **Importante**: Rotas com parâmetros **DEVEM iniciar com barra** (`/`).

### Opção 1: Consolidado (Recomendado)

```pascal
type
  [ApiController('/api/users')]       // Rota base definida no ApiController
  TUsersController = class
  private
    FUserService: IUserService;
  public
    constructor Create(UserService: IUserService);
    
    [HttpGet]                          // GET /api/users
    function GetAll: IResult;

    [HttpGet('/{id}')]                 // GET /api/users/123 (barra inicial OBRIGATÓRIA)
    function GetById(Id: Integer): IResult;
    
    [HttpPost]                         // POST /api/users
    function CreateUser([Body] Dto: TCreateUserDto): IResult;
    
    [HttpPut('/{id}')]                 // PUT /api/users/123
    function UpdateUser(Id: Integer; [Body] Dto: TUpdateUserDto): IResult;
    
    [HttpDelete('/{id}')]              // DELETE /api/users/123
    function DeleteUser(Id: Integer): IResult;
  end;
```

### Opção 2: Separado (Estilo .NET)

```pascal
type
  [ApiController]
  [Route('/api/users')]                // Rota base via atributo Route
  TUsersController = class
  public
    [HttpGet]                          // GET /api/users
    function GetAll: IResult;

    [HttpGet, Route('/{id}')]          // GET /api/users/123
    function GetById(Id: Integer): IResult;
  end;
```

> [!WARNING]
> - ❌ `[HttpGet('{id}')]` → **Falta a barra inicial**. Pode gerar rotas incorretas.
> - ❌ `[Route]` sem `[ApiController]` → O Controller não será registrado pelo scanner.

## Implementação

Actions de Controller retornam `IResult` diretamente usando o helper `Results`:

```pascal
function TUsersController.GetAll: IResult;
begin
  Result := Results.Ok(FUserService.GetAll);
end;

function TUsersController.GetById(Id: Integer): IResult;
begin
  var User := FUserService.FindById(Id);
  if User = nil then
    Result := Results.NotFound('Usuário não encontrado')
  else
    Result := Results.Ok(User);
end;

function TUsersController.CreateUser(Dto: TCreateUserDto): IResult;
begin
  var User := FUserService.Add(Dto);
  Result := Results.Created('/api/users/' + IntToStr(User.Id), User);
end;
```

> [!IMPORTANT]
> **Nomeação de Métodos**: NUNCA nomeie um método apenas como `Create` — ele conflita com construtores Delphi (E2254). Use nomes explícitos como `CreateUser`, `CreateOrder`, etc.

## Registrar Controllers

Controllers são registrados em `ConfigureServices` e mapeados no pipeline:

```pascal
procedure TStartup.ConfigureServices(const Services: TDextServices; const Configuration: IConfiguration);
begin
  Services
    .AddDbContext<TAppDbContext>(ConfigureDatabase)
    .AddScoped<IUserService, TUserService>
    .AddControllers;  // Registra controllers para DI
end;

procedure TStartup.Configure(const App: IWebApplication);
begin
  App.Builder
    .UseExceptionHandler
    .UseHttpLogging
    .MapControllers      // Mapeia rotas de controllers (ANTES do Swagger)
    .UseSwagger(Swagger.Title('Minha API').Version('v1'));
end;
```

## Injeção via Construtor

Serviços são injetados automaticamente via construtor quando registrados:

```pascal
type
  [ApiController('/api/users')]
  TUsersController = class
  private
    FUserService: IUserService;
    FLogger: ILogger;
  public
    constructor Create(UserService: IUserService; Logger: ILogger);
  end;

constructor TUsersController.Create(UserService: IUserService; Logger: ILogger);
begin
  FUserService := UserService;
  FLogger := Logger;
end;
```

```pascal
// Em ConfigureServices:
Services
  .AddScoped<IUserService, TUserService>
  .AddSingleton<ILogger, TConsoleLogger>
  .AddControllers;
```

## Action Results

```pascal
Result := Results.Ok(Data);                        // 200 + JSON
Result := Results.Ok<TMyDto>(Dto);                 // 200 + serialização tipada
Result := Results.Created('/path', Data);          // 201 + Header Location
Result := Results.Accepted('/jobs/1', Data);       // 202 + Header Location
Result := Results.NoContent;                        // 204
Result := Results.BadRequest('Dados inválidos');    // 400
Result := Results.NotFound('Não encontrado');       // 404
Result := Results.ValidationProblem(Validation);    // 400 problem+json
Result := Results.StatusCode(401);                  // Status customizado
Result := Results.Json<TMyDto>(Dto);               // JSON explícito
```

> [!NOTE]
> `Results.Unauthorized` **pode não existir** — use `Results.StatusCode(401)` como alternativa segura.

## Model Binding de Parâmetros

```pascal
// Rota paramétrica (barra inicial OBRIGATÓRIA)
[HttpGet('/{id}')]
function GetById(Id: Integer): IResult;

// Query parameter
[HttpGet('/search')]
function Search([FromQuery] Q: string; [FromQuery] Page: Integer): IResult;

// Body
[HttpPost]
function CreateUser([FromBody] Request: TCreateUserDto): IResult;

// Header
[HttpGet]
function Auth([FromHeader('Authorization')] Token: string): IResult;
```

## Protegendo Controllers

```pascal
type
  [ApiController('/api/secure')]
  [Authorize]                   // Exige autenticação para todos os métodos
  TSecureController = class
  public
    [HttpGet]
    [AllowAnonymous]            // Exceção: permite acesso público
    function PublicInfo: IResult;

    [HttpPost]
    [Authorize('Admin')]        // Exige role 'Admin'
    function RestrictedAction: IResult;
  end;
```

## Metadados OpenAPI

Enriqueça a documentação Swagger com tags:

```pascal
// Agrupa endpoints via WithTags
[ApiController('/api/users')]
TUsersController = class
  // Todos os endpoints aparecem sob a tag "Users" no Swagger
end;
```

---

[← Minimal APIs](minimal-apis.md) | [Próximo: Model Binding →](model-binding.md)
