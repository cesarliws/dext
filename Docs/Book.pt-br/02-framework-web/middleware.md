# Middleware

Intercepte e processe requisições HTTP no pipeline.

## Como Middleware Funciona

```
Requisição → Middleware 1 → Middleware 2 → ... → Endpoint
                ↓               ↓
Resposta ← Middleware 1 ← Middleware 2 ← ... ← Endpoint
```

## Middleware Integrados

```pascal
App.Configure(procedure(App: IApplicationBuilder)
  begin
    // Tratamento de exceções (deve ser primeiro)
    App.UseExceptionHandler;
    
    // Logging
    App.UseHttpLogging;
    
    // Autenticação
    App.UseAuthentication;
    
    // CORS
    App.UseCors(CorsOptions);
    
    // Rate limiting
    App.UseRateLimiting(RateLimitOptions);
    
    // Arquivos estáticos
    App.UseStaticFiles('/public', './wwwroot');
    
    // Base Path
    App.UsePathBase('/myapp');

    // Endpoints vêm por último
    App.MapGet('/api', Handler);
  end);
```

## Base Path Hosting (`UsePathBase`)

Sirva aplicações sob um prefixo de caminho (ex: `https://example.com/myapp/`):

```pascal
App := WebApplication;
App.UsePathBase('/myapp');
App.MapGet('/ping', procedure(Ctx: IHttpContext)
  begin
    // Ctx.Request.PathBase -> '/myapp'
    // Ctx.Request.Path -> '/ping'
    // Ctx.Request.ToAppUrl('/ping') -> '/myapp/ping'
    Ctx.Response.Write('OK');
  end);
App.Run(8080);
```

## Middleware Customizado

### Middleware Inline

```pascal
App.Use(procedure(Ctx: IHttpContext; Next: TRequestDelegate)
  var
    StartTime: TDateTime;
  begin
    StartTime := Now;
    
    // Antes do endpoint
    WriteLn('Requisição iniciada: ', Ctx.Request.Path);
    
    Next(Ctx);  // Chama próximo middleware/endpoint
    
    // Depois do endpoint
    WriteLn('Requisição completada em ', MilliSecondsBetween(Now, StartTime), 'ms');
  end);
```

## Middleware de Curto-Circuito

Pare o pipeline antecipadamente:

```pascal
App.Use(procedure(Ctx: IHttpContext; Next: TRequestDelegate)
  begin
    if Ctx.Request.Header('X-API-Key') = '' then
    begin
      Ctx.Response.StatusCode := 401;
      Ctx.Response.Json('{"error": "API key obrigatória"}');
      Exit;  // Não chama Next()
    end;
    
    Next(Ctx);  // Continua pipeline
  end);
```

## Ordem do Middleware

A ordem importa! Ordem recomendada:

1. `UseExceptionHandler` - Captura todos os erros
2. `UseHttpLogging` - Loga requisições
3. `UseCors` - Trata preflight CORS
4. `UseAuthentication` - Valida tokens
5. `UseRateLimiting` - Limita requisições
6. **Endpoints** - Sua lógica de API

## Forwarded Headers (Reverse Proxies)

Processe cabeçalhos `X-Forwarded-*` provenientes de proxies reversos (NGINX, Caddy, Cloudflare, Traefik) com arquitetura **Zero-Trust**:

```pascal
var
  Opts: TForwardedHeadersOptions;
begin
  Opts := TForwardedHeadersOptions.Create;
  // Registre apenas proxies explicitamente confiáveis
  Opts.KnownProxies.Add('127.0.0.1');
  Opts.KnownNetworks.Add('10.0.0.0/8');

  App.UseForwardedHeaders(Opts);
end;
```

## Antiforgery (Proteção CSRF)

Proteção contra Cross-Site Request Forgery usando tokens HMAC-SHA256 e verificação de Origin/Host:

```pascal
var
  Antiforgery: IAntiforgery;
begin
  Antiforgery := TAntiforgery.Create('chave-secreta-hmac-2026', True);
  
  App.Use(procedure(Ctx: IHttpContext; Next: TRequestDelegate)
    begin
      // Valida automaticamente requisições mutativas (POST, PUT, DELETE, PATCH)
      Antiforgery.ValidateRequest(Ctx);
      Next(Ctx);
    end);
end;
```

---

[← Rotas](rotas.md) | [Próximo: Autenticação →](../03-autenticacao/README.md)
