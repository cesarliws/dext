# 3. Autenticação & Segurança

Proteja suas APIs com autenticação JWT e autorização.

## Capítulos

1. [Autenticação Basic](basic-auth.md) - Autenticação HTTP simples
2. [Autenticação JWT](jwt-auth.md) - Autenticação baseada em tokens
3. [Claims Builder](claims-builder.md) - Claims, roles e políticas de autorização nomeadas (`[AuthorizePolicy]`)

> 📦 **Exemplo**: [Web.JwtAuthDemo](../../../Examples/Web.JwtAuthDemo/)

## Início Rápido

```pascal
// 1. Configurar Serviços
Services.AddAuthentication(procedure(Options: TAuthenticationOptions)
  begin
    Options.SecretKey := 'sua-chave-secreta-com-pelo-menos-32-caracteres';
    Options.ExpirationMinutes := 60;
  end);

// 2. Gerar Token
App.MapPost('/login', procedure(Ctx: IHttpContext)
  var
    Token: string;
  begin
    // Validar credenciais...
    
    Token := TJwtHelper.GenerateToken('sua-chave-secreta', 
      TClaimsBuilder.Create
        .AddSub('user-id-123')
        .AddName('João Silva')
        .AddRole('admin')
        .Build,
      60 // minutos
    );
    
    Ctx.Response.Json('{"token": "' + Token + '"}');
  end);

// 3. Proteger Endpoint
App.MapGet('/protegido', procedure(Ctx: IHttpContext)
  begin
    var UserId := Ctx.User.FindFirst('sub');
    Ctx.Response.Json('{"mensagem": "Olá, ' + UserId + '!"}');
  end)
  .RequireAuthorization;
```

---

[← Framework Web](../02-framework-web/README.md) | [Próximo: Autenticação JWT →](jwt-auth.md)
