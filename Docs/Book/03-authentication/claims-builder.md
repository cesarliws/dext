# Claims Builder

Build JWT payloads quickly and securely.

## Token Attributes (Claims)

Claims are statements about an entity (typically, the user). In Dext, you use the `TClaimsBuilder` to create these data sets.

## Usage Example

```pascal
uses
  Dext.Web.Security;

var
  Claims: TArray<TClaim>;
begin
  Claims := TClaimsBuilder.Create
    .AddSub('user_12345')             // Subject (User ID)
    .AddName('John Doe')              // Real name
    .AddEmail('john@provider.com')    // Email
    .AddRole('Admin')                 // Role
    .AddRole('Finance')               // Multiple roles
    .AddClaim('tenant_id', '789')     // Custom claim
    .AddClaim('premium', 'true')
    .Build;
end;
```

## Standard Claims (RFC 7519)

| Method | Claim | Description |
|--------|-------|-------------|
| `.AddSub()` | `sub` | Unique user identifier |
| `.AddIss()` | `iss` | Token issuer |
| `.AddAud()` | `aud` | Intended audience |
| `.AddExp()` | `exp` | Expiration time |
| `.AddIat()` | `iat` | Issued at time |

## Verification in Handler

When the user sends a valid token, you access claims directly in the context:

```pascal
App.MapGet('/me', procedure(Ctx: IHttpContext)
  begin
    var Name := Ctx.User.FindFirst('name');
    var IsAdmin := Ctx.User.IsInRole('Admin');
    
    Ctx.Response.Json(Format('{"user": "%s", "admin": %s}', [Name, BoolToStr(IsAdmin, 'yes', 'no')]));
  end)
  .RequireAuthorization;
```

## Policy-Based Authorization

For logic beyond a single role, register a named policy and apply `[AuthorizePolicy]` on controllers (Delphi has no `Policy =` named arguments on `[Authorize]`):

```pascal
TAuthorizationPolicyRegistry.RegisterPolicy('Over18',
  function(const Principal: IClaimsPrincipal): Boolean
  var
    AgeClaim: TClaim;
  begin
    AgeClaim := Principal.FindClaim('age');
    Result := (AgeClaim.ClaimType <> '') and (StrToIntDef(AgeClaim.Value, 0) >= 18);
  end);

// On a controller action:
// [AuthorizePolicy('Over18')]
```

Evaluate manually when needed:

```pascal
if TAuthorizationPolicyRegistry.Evaluate('Over18', Ctx.User) then
  // allowed
```

---

[← JWT Authentication](jwt-auth.md) | [Next: API Features →](../04-api-features/README.md)
