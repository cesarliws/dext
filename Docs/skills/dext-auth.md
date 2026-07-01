---
name: dext-auth
description: Secure Dext Web APIs with JWT authentication — setup, login endpoints, protecting routes, and working with claims.
---

# Dext Authentication (JWT)

## Core Import

```pascal
uses
  Dext.Web;      // JwtOptions helper
  Dext.Auth.JWT; // IJwtTokenHandler, TClaim, TClaimsBuilder, TJwtTokenHandler
```

## JWT Flow

1. Client sends credentials to `/api/auth/login`
2. Server validates and returns a JWT token
3. Client includes `Authorization: Bearer <token>` header on protected requests
4. Middleware validates the token automatically

## 1. Configure Authentication in Startup

```pascal
procedure TStartup.ConfigureServices(
  const Services: TDextServices;
  const Configuration: IConfiguration);
begin
  // 1. MANDATORY Registration of the Handler (Dext.Auth.JWT)
  Services.AddSingleton<IJwtTokenHandler, TJwtTokenHandler>(
    function(Provider: IServiceProvider): TObject
    begin
      Result := TJwtTokenHandler.Create(JWT_SECRET, JWT_ISSUER, JWT_AUDIENCE, 60);
    end);

  // 2. Recommended: Claims Builder for your project
  Services.AddTransient<IClaimsBuilder, TClaimsBuilder>;
end;

procedure TStartup.Configure(const App: IWebApplication);
begin
  App.Builder
    .UseExceptionHandler
    // 3. Activate Auth Middleware (Fluent Builder)
    .UseJwtAuthentication(
      JwtOptions(JWT_SECRET)
        .Issuer(JWT_ISSUER)
        .Audience(JWT_AUDIENCE)
    )
    .MapControllers
    .UseSwagger(Swagger.Title('My API').Version('v1'));
end;
```

> `UseJwtAuthentication` middleware **must be added before** route mapping.

## 3. Login Endpoint

### With Minimal API

```pascal
type
  TLoginRequest = record
    Username: string;
    Password: string;
  end;

  TLoginResponse = record
    Token: string;
  end;

Builder.MapPost<TLoginRequest, IAuthService, IJwtTokenHandler, IClaimsBuilder, IResult>('/api/auth/login',
  function(Req: TLoginRequest; Auth: IAuthService; Jwt: IJwtTokenHandler; Claims: IClaimsBuilder): IResult
  begin
    if not Auth.ValidateCredentials(Req.Username, Req.Password) then
      Exit(Results.StatusCode(401));

    var UserClaims := Claims.BuildClaims(Req.Username, 'user');
    
    // GenerateToken accepts TArray<TClaim>. Do NOT pass strings directly.
    var Token := Jwt.GenerateToken(UserClaims);

    var Response: TLoginResponse;
    Response.Token := Token;
    Result := Results.Ok(Response);
  end);
```

### With Controller

```pascal
type
  [ApiController('/api/auth')]
  TAuthController = class
  private
    FAuthService: IAuthService;
    FJwt: IJwtTokenHandler;
    FClaims: IClaimsBuilder;
  public
    constructor Create(AuthService: IAuthService; Jwt: IJwtTokenHandler; Claims: IClaimsBuilder);

    [HttpPost('/login')]
    function Login([Body] Request: TLoginRequest): IResult;
  end;

function TAuthController.Login(Request: TLoginRequest): IResult;
begin
  if not FAuthService.ValidateCredentials(Request.Username, Request.Password) then
    Exit(Results.StatusCode(401));

  var UserClaims := FClaims.BuildClaims(Request.Username, 'user');
  var Token := FJwt.GenerateToken(UserClaims);
  
  Result := Results.Ok(TLoginResponse.Create(Token));
end;
```

## 4. Claims Builder

`TClaimsBuilder` provides a fluent API for building JWT claims:

```pascal
var Claims := TClaimsBuilder.Create
  .AddSub('user-id-123')         // Subject — user's unique ID
  .AddName('Alice Smith')         // Full name
  .AddEmail('alice@example.com')  // Email
  .AddRole('user')                // Single role
  .AddRoles(['admin', 'editor'])  // Multiple roles
  .AddClaim('department', 'IT')   // Custom claim
  .AddClaim('tenant', 'acme')     // Another custom claim
  .Build;                         // Returns TArray<TClaim>
```

## 5. Protect Endpoints

### Minimal API — `.RequireAuthorization`

```pascal
Builder.MapGet<IOrderService, IResult>('/api/orders',
  function(Svc: IOrderService): IResult
  begin
    Result := Results.Ok(Svc.GetAll);
  end)
  .RequireAuthorization;  // Requires any authenticated user

Builder.MapDelete<IOrderService, Integer, IResult>('/api/orders/{id}',
  function(Svc: IOrderService; Id: Integer): IResult
  begin
    Svc.Delete(Id);
    Result := Results.NoContent;
  end)
  .RequireAuthorization('Admin');  // Requires 'Admin' role
```

### Controller — `[Authorize]` / `[AllowAnonymous]`

```pascal
type
  [ApiController('/api/orders')]
  [Authorize]                        // All actions require auth
  TOrdersController = class
  public
    [HttpGet]
    [AllowAnonymous]                 // Public — override class-level [Authorize]
    function GetPublicOrders: IResult;

    [HttpGet('/{id}')]
    function GetById(Id: Integer): IResult;  // Requires auth

    [HttpDelete('/{id}')]
    [Authorize('Admin')]             // Requires 'Admin' role
    function DeleteOrder(Id: Integer): IResult;
  end;
```

## 6. Accessing Claims in Handlers

### Minimal API — via `IHttpContext`

Only use `IHttpContext` when you genuinely need it (e.g., to read claims):

```pascal
Builder.MapGet<IOrderService, IHttpContext, IResult>('/api/orders/my',
  function(Svc: IOrderService; Ctx: IHttpContext): IResult
  begin
    var UserId := Ctx.User.FindFirst('sub');
    Result := Results.Ok(Svc.GetByUserId(UserId));
  end)
  .RequireAuthorization;
```

### Controller — via `HttpContext`

```pascal
function TOrdersController.GetMyOrders: IResult;
begin
  var UserId := HttpContext.User.FindFirst('sub');
  var UserName := HttpContext.User.FindFirst('name');
  Result := Results.Ok(FOrderService.GetByUserId(UserId));
end;
```

### Claims API

```pascal
// Get single claim value
var UserId := Ctx.User.FindFirst('sub');
var Email := Ctx.User.FindFirst('email');
var Name := Ctx.User.FindFirst('name');

// Get all values for a claim type (e.g., multiple roles)
var Roles := Ctx.User.FindAll('role');

// Check role membership
if Ctx.User.IsInRole('admin') then
  // Admin logic...
```

## 6. Token Validation

`UseJwtAuthentication` middleware validates automatically:

- Signature (HMAC-SHA256 by default)
- Expiration (`exp` claim)
- Issuer (`iss`) — if `Options.Issuer` is set
- Audience (`aud`) — if `Options.Audience` is set

## Standard JWT Claim Names

| Custom Builder Method | Claim key |
|--------|-----------|
| `.AddSub('id')` | `sub` |
| `.AddName('name')` | `name` |
| `.AddEmail('email')` | `email` |
| `.AddRole('role')` | `role` |
| `.AddClaim('key', 'val')` | `key` (custom) |

## Common Mistakes

| Wrong | Correct |
|-------|---------|
| `Results.Unauthorized` | `Results.StatusCode(401)` |
| `UseJwtAuthentication` after routes | `UseJwtAuthentication` before routes |
| Secret key shorter than 32 chars | Must be at least 32 characters |
| Creating your own `IJwtTokenHandler` interface | Always use `Dext.Auth.JWT.IJwtTokenHandler` |
| `Jwt.GenerateToken(User, Role)` | Use `Jwt.GenerateToken(TArray<TClaim>)` |
| Not adding `.RequireAuthorization` | Endpoints are public by default |
| Calling `inherited Create(AName)` | Call `inherited Create;` or `inherited;` |

## 7. Policy-Based Authorization & Asymmetric Validation (RS256)

### Custom Policies
Register named authorization policies globally in `TAuthorizationPolicyRegistry`:

```pascal
TAuthorizationPolicyRegistry.RegisterPolicy('Over18',
  function(const Principal: IClaimsPrincipal): Boolean
  begin
    var AgeClaim := Principal.FindClaim('age');
    Result := (AgeClaim.Value <> '') and (StrToIntDef(AgeClaim.Value, 0) >= 18);
  end);
```

Then require it on endpoints:

* Minimal APIs: `.RequirePolicy('Over18')`
* Controllers: `[Authorize(Policy := 'Over18')]`

### Asymmetric Cryptography (RS256)
When integrating with identity providers (Google, Azure AD, Keycloak), use RS256 signature validation. Load options with the public JWK key:

```pascal
Services.AddAuthentication(procedure(Options: TAuthenticationOptions)
  begin
    Options.Algorithm := 'RS256';
    Options.PublicKeyJson := '{"kty":"RSA", "n":"...", "e":"..."}'; // Modulus & Exponent
  end);
```

### External Identity Providers (OIDC / OAuth2)
Use plug-and-play middleware helpers:

```pascal
App.Builder
  .UseGoogleAuthentication('CLIENT_ID')
  // OR
  .UseEntraIdAuthentication('TENANT_ID', 'CLIENT_ID')
  // OR
  .UseKeycloakAuthentication('REALM_URL', 'CLIENT_ID')
```


