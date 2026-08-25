# Controllers

Controllers provide a class-based, MVC-style approach to organizing endpoints.

> 📦 **Example**: [Web.TicketSales](../../../Examples/Web.TicketSales/)

## Basic Controller

Dext supports two styles for defining controllers. **Important**: Parameter routes **MUST start with a slash** (`/`).

### Option 1: Consolidated (Recommended)

```pascal
type
  [ApiController('/api/users')]       // Base route defined in ApiController
  TUsersController = class
  private
    FUserService: IUserService;
  public
    constructor Create(UserService: IUserService);

    [HttpGet]                          // GET /api/users
    function GetAll: IResult;

    [HttpGet('/{id}')]                 // GET /api/users/123 (leading slash MANDATORY)
    function GetById(Id: Integer): IResult;

    [HttpPost]                         // POST /api/users
    function CreateUser([Body] Dto: TCreateUserDto): IResult;

    [HttpPut('/{id}')]                 // PUT /api/users/123
    function UpdateUser(Id: Integer; [Body] Dto: TUpdateUserDto): IResult;

    [HttpDelete('/{id}')]              // DELETE /api/users/123
    function DeleteUser(Id: Integer): IResult;
  end;
```

### Option 2: Separated (.NET Style)

```pascal
type
  [ApiController]
  [Route('/api/users')]                // Base route via Route attribute
  TUsersController = class
  public
    [HttpGet]                          // GET /api/users
    function GetAll: IResult;

    [HttpGet, Route('/{id}')]          // GET /api/users/123
    function GetById(Id: Integer): IResult;
  end;
```

> [!WARNING]
> - ❌ `[HttpGet('{id}')]` → **Missing leading slash**. Can generate incorrect routes.
> - ❌ `[Route]` without `[ApiController]` → Controller won't be registered by the scanner.

## Implementation

Controller actions return `IResult` directly using the `Results` helper:

```pascal
function TUsersController.GetAll: IResult;
begin
  Result := Results.Ok(FUserService.GetAll);
end;

function TUsersController.GetById(Id: Integer): IResult;
begin
  var User := FUserService.FindById(Id);
  if User = nil then
    Result := Results.NotFound('User not found')
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
> **Method naming**: NEVER name a method just `Create` — it conflicts with Delphi constructors (E2254). Use explicit names like `CreateUser`, `CreateOrder`, etc.

## Register Controllers

Controllers are registered in `ConfigureServices` and mapped in the pipeline:

```pascal
procedure TStartup.ConfigureServices(const Services: TDextServices; const Configuration: IConfiguration);
begin
  Services
    .AddDbContext<TAppDbContext>(ConfigureDatabase)
    .AddScoped<IUserService, TUserService>
    .AddControllers;  // Register controllers for DI
end;

procedure TStartup.Configure(const App: IWebApplication);
begin
  App.Builder
    .UseExceptionHandler
    .UseHttpLogging
    .MapControllers      // Map all controller routes (BEFORE Swagger)
    .UseSwagger(Swagger.Title('My API').Version('v1'));
end;
```

## Constructor Injection

Services are automatically injected via constructor when registered:

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
// In ConfigureServices:
Services
  .AddScoped<IUserService, TUserService>
  .AddSingleton<ILogger, TConsoleLogger>
  .AddControllers;
```

## Action Results

```pascal
Result := Results.Ok(Data);                        // 200 + JSON
Result := Results.Ok<TMyDto>(Dto);                 // 200 + typed serialization
Result := Results.Created('/path', Data);          // 201 + Location header
Result := Results.Accepted('/jobs/1', Data);       // 202 + Location header
Result := Results.NoContent;                        // 204
Result := Results.BadRequest('Invalid data');       // 400
Result := Results.NotFound('Not found');            // 404
Result := Results.ValidationProblem(Validation);    // 400 problem+json
Result := Results.StatusCode(401);                  // Custom status
Result := Results.Json<TMyDto>(Dto);               // Explicit JSON
```

> [!NOTE]
> `Results.Unauthorized` **may not exist** — use `Results.StatusCode(401)` as a safe alternative.

## Parameter Binding

```pascal
// Route parameter (leading slash MANDATORY)
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

## Protecting Controllers

```pascal
type
  [ApiController('/api/secure')]
  [Authorize]                   // Require authentication for all methods
  TSecureController = class
  public
    [HttpGet]
    [AllowAnonymous]            // Exception: allow public access
    function PublicInfo: IResult;

    [HttpPost]
    [Authorize('Admin')]        // Require 'Admin' role
    function RestrictedAction: IResult;
  end;
```

## OpenAPI Metadata

Enrich Swagger documentation with tags:

```pascal
// Group endpoints via WithTags
[ApiController('/api/users')]
TUsersController = class
  // All endpoints appear under the "Users" tag in Swagger
end;
```

---

[← Minimal APIs](minimal-apis.md) | [Next: Model Binding →](model-binding.md)
