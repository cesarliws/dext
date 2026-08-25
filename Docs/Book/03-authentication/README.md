# 3. Authentication & Security

Protect your APIs with JWT authentication and authorization.

## Chapters

1. [Basic Authentication](basic-auth.md) - Simple HTTP authentication
2. [JWT Authentication](jwt-auth.md) - Token-based authentication
3. [Claims Builder](claims-builder.md) - User claims, roles, and named authorization policies (`[AuthorizePolicy]`)

> 📦 **Example**: [Web.JwtAuthDemo](../../../Examples/Web.JwtAuthDemo/)

## Quick Start

```pascal
// 1. Configure Services
Services.AddAuthentication(procedure(Options: TAuthenticationOptions)
  begin
    Options.SecretKey := 'your-secret-key-at-least-32-chars';
    Options.ExpirationMinutes := 60;
  end);

// 2. Generate Token
App.MapPost('/login', procedure(Ctx: IHttpContext)
  var
    Token: string;
  begin
    // Validate credentials...
    
    Token := TJwtHelper.GenerateToken('your-secret-key', 
      TClaimsBuilder.Create
        .AddSub('user-id-123')
        .AddName('John Doe')
        .AddRole('admin')
        .Build,
      60 // minutes
    );
    
    Ctx.Response.Json('{"token": "' + Token + '"}');
  end);

// 3. Protect Endpoint
App.MapGet('/protected', procedure(Ctx: IHttpContext)
  begin
    var UserId := Ctx.User.FindFirst('sub');
    Ctx.Response.Json('{"message": "Hello, ' + UserId + '!"}');
  end)
  .RequireAuthorization;
```

---

[← Web Framework](../02-web-framework/README.md) | [Next: JWT Authentication →](jwt-auth.md)
