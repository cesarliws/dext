# Health Checks

Monitor application health with dedicated endpoints. Prefer the built-in middleware (`UseHealthChecks` / `THealthCheckMiddleware`): defaults are **`/health`** (aggregate), **`/health/live`** (liveness — process up), and **`/health/ready`** (readiness — dependency checks).

## Basic Health Check

```pascal
App.MapGet('/health', procedure(Ctx: IHttpContext)
  begin
    Ctx.Response.StatusCode := 200;
    Ctx.Response.Json('{"status": "healthy"}');
  end);
```

## Detailed Health Check

```pascal
App.MapGet('/health', procedure(Ctx: IHttpContext)
  var
    Status: string;
    DbOk, CacheOk: Boolean;
  begin
    // Check database
    try
      DbContext.Connection.Execute('SELECT 1');
      DbOk := True;
    except
      DbOk := False;
    end;
    
    // Check cache
    try
      CacheService.Ping;
      CacheOk := True;
    except
      CacheOk := False;
    end;
    
    // Determine overall status
    if DbOk and CacheOk then
    begin
      Ctx.Response.StatusCode := 200;
      Status := 'healthy';
    end
    else
    begin
      Ctx.Response.StatusCode := 503;
      Status := 'unhealthy';
    end;
    
    Ctx.Response.Json(Format(
      '{"status": "%s", "checks": {"database": %s, "cache": %s}}',
      [Status, BoolToStr(DbOk, 'true', 'false'), BoolToStr(CacheOk, 'true', 'false')]
    ));
  end);
```

## Response Format

### Healthy (200 OK)

```json
{
  "status": "healthy",
  "checks": {
    "database": true,
    "cache": true,
    "externalApi": true
  },
  "uptime": "3d 14h 22m"
}
```

### Unhealthy (503 Service Unavailable)

```json
{
  "status": "unhealthy",
  "checks": {
    "database": true,
    "cache": false,
    "externalApi": true
  },
  "errors": [
    "Redis connection timeout"
  ]
}
```

## Liveness vs Readiness

### Liveness Probe

"Is the app running?" - Restart if fails.

```pascal
App.MapGet('/health/live', procedure(Ctx: IHttpContext)
  begin
    Ctx.Response.StatusCode := 200;
    Ctx.Response.Write('OK');
  end);
```

### Readiness Probe

"Is the app ready to serve traffic?" - Remove from load balancer if fails.

```pascal
App.MapGet('/health/ready', procedure(Ctx: IHttpContext)
  begin
    if AppIsReady then
      Ctx.Response.StatusCode := 200
    else
      Ctx.Response.StatusCode := 503;
  end);
```

## Kubernetes / Docker

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

```yaml
# kubernetes deployment
livenessProbe:
  httpGet:
    path: /health/live
    port: 5000
  initialDelaySeconds: 10
  periodSeconds: 30

readinessProbe:
  httpGet:
    path: /health/ready
    port: 5000
  initialDelaySeconds: 5
  periodSeconds: 10
```

---

[← Caching](caching.md) | [Next: ORM →](../05-orm/README.md)
