# Claims Builder

Construa payloads JWT de forma rápida e segura.

## Atributos de Tokens (Claims)

Claims são declarações sobre uma entidade (geralmente o usuário). No Dext, você usa o `TClaimsBuilder` para criar esses conjuntos de dados.

## Exemplo de Uso

```pascal
uses
  Dext.Web.Security;

var
  Claims: TArray<TClaim>;
begin
  Claims := TClaimsBuilder.Create
    .AddSub('user_12345')             // Subject (ID do usuário)
    .AddName('João Silva')            // Nome real
    .AddEmail('joao@provedor.com')    // Email
    .AddRole('Admin')                 // Papel/Regra
    .AddRole('Financeiro')            // Múltiplos papéis
    .AddClaim('tenant_id', '789')     // Claim customizada
    .AddClaim('premium', 'true')
    .Build;
end;
```

## Claims Padrão (RFC 7519)

| Método | Claim | Descrição |
|--------|-------|-----------|
| `.AddSub()` | `sub` | Identificador único do usuário |
| `.AddIss()` | `iss` | Emissor do token |
| `.AddAud()` | `aud` | Público que pode usar o token |
| `.AddExp()` | `exp` | Data de expiração |
| `.AddIat()` | `iat` | Data de emissão |

## Verificação no Handler

Quando o usuário envia um token válido, você acessa as claims diretamente no contexto:

```pascal
App.MapGet('/me', procedure(Ctx: IHttpContext)
  begin
    var Nome := Ctx.User.FindFirst('name');
    var EhAdmin := Ctx.User.IsInRole('Admin');
    
    Ctx.Response.Json(Format('{"usuario": "%s", "admin": %s}', [Nome, BoolToStr(EhAdmin, 'sim', 'não')]));
  end)
  .RequireAuthorization;
```

## Autorização Baseada em Políticas

Para lógica além de uma única role, registre uma política nomeada e use `[AuthorizePolicy]` nos controllers (Delphi não tem named arguments como `Policy =` em `[Authorize]`):

```pascal
TAuthorizationPolicyRegistry.RegisterPolicy('MaiorDeIdade',
  function(const Principal: IClaimsPrincipal): Boolean
  var
    AgeClaim: TClaim;
  begin
    AgeClaim := Principal.FindClaim('age');
    Result := (AgeClaim.ClaimType <> '') and (StrToIntDef(AgeClaim.Value, 0) >= 18);
  end);

// Em uma action de controller:
// [AuthorizePolicy('MaiorDeIdade')]
```

Avalie manualmente quando necessário:

```pascal
if TAuthorizationPolicyRegistry.Evaluate('MaiorDeIdade', Ctx.User) then
  // permitido
```

---

[← Autenticação JWT](jwt-auth.md) | [Próximo: Recursos da API →](../04-recursos-api/README.md)
