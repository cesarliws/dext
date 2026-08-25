# Health Checks

Monitore a saúde da aplicação com endpoints dedicados. Prefira o middleware nativo (`UseHealthChecks` / `THealthCheckMiddleware`): padrões **`/health`** (agregado), **`/health/live`** (liveness — processo no ar) e **`/health/ready`** (readiness — dependências).

## Health Check Básico

```pascal
App.MapGet('/health', procedure(Ctx: IHttpContext)
  begin
    Ctx.Response.StatusCode := 200;
    Ctx.Response.Json('{"status": "saudável"}');
  end);
```

## Health Check Detalhado

```pascal
App.MapGet('/health', procedure(Ctx: IHttpContext)
  var
    Status: string;
    DbOk, CacheOk: Boolean;
  begin
    // Verificar banco de dados
    try
      DbContext.Connection.Execute('SELECT 1');
      DbOk := True;
    except
      DbOk := False;
    end;
    
    // Verificar cache
    try
      CacheService.Ping;
      CacheOk := True;
    except
      CacheOk := False;
    end;
    
    // Determinar status geral
    if DbOk and CacheOk then
    begin
      Ctx.Response.StatusCode := 200;
      Status := 'saudável';
    end
    else
    begin
      Ctx.Response.StatusCode := 503;
      Status := 'não saudável';
    end;
    
    Ctx.Response.Json(Format(
      '{"status": "%s", "verificacoes": {"database": %s, "cache": %s}}',
      [Status, BoolToStr(DbOk, 'true', 'false'), BoolToStr(CacheOk, 'true', 'false')]
    ));
  end);
```

## Formato de Resposta

### Saudável (200 OK)

```json
{
  "status": "saudável",
  "verificacoes": {
    "database": true,
    "cache": true
  }
}
```

### Não Saudável (503 Service Unavailable)

```json
{
  "status": "não saudável",
  "verificacoes": {
    "database": true,
    "cache": false
  },
  "erros": [
    "Timeout de conexão com Redis"
  ]
}
```

## Docker / Kubernetes

```yaml
# docker-compose.yml
services:
  api:
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

---

[← CORS](cors.md) | [Próximo: ORM →](../05-orm/README.md)
