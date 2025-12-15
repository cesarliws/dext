# Health Checks no Dext

O Dext fornece um middleware de Health Checks para monitorar a saúde da sua aplicação e de suas dependências (banco de dados, serviços externos, etc.).

## Configuração Básica

Para adicionar Health Checks, registre o serviço e o middleware no `TDextApplication` (ou no seu `Startup`):

```pascal
uses
  Dext.HealthChecks,
  Dext.Core.Extensions;

// ...

// 1. Registrar os serviços de Health Check
TDextServiceCollectionExtensions.AddHealthChecks(App.Services)
  .AddCheck<TDatabaseHealthCheck> // Seu check customizado
  .AddCheck<TRedisHealthCheck>
  .Build;

// 2. Adicionar o Middleware
App.UseMiddleware(THealthCheckMiddleware);
```

Por padrão, o endpoint será `/health`.

## Criando um Health Check Customizado

Implemente a interface `IHealthCheck`:

```pascal
uses
  Dext.HealthChecks;

type
  TDatabaseHealthCheck = class(TInterfacedObject, IHealthCheck)
  public
    function CheckHealth: THealthCheckResult;
  end;

implementation

function TDatabaseHealthCheck.CheckHealth: THealthCheckResult;
begin
  try
    // Lógica para verificar o banco de dados
    // ...
    Result := THealthCheckResult.Healthy('Database is reachable');
  except
    on E: Exception do
      Result := THealthCheckResult.Unhealthy('Database connection failed', E);
  end;
end;
```

## Resposta JSON

O endpoint `/health` retorna um JSON estruturado:

```json
{
  "status": "Healthy",
  "checks": {
    "TDatabaseHealthCheck": {
      "status": "Healthy",
      "description": "Database is reachable"
    },
    "TRedisHealthCheck": {
      "status": "Unhealthy",
      "description": "Connection refused"
    }
  }
}
```

Se algum check falhar, o status geral será `Unhealthy` e o código HTTP será `503 Service Unavailable`. Caso contrário, será `200 OK`.
