---
description: Implementar sistema de logging e melhorar middlewares de exception handling e HTTP logging
---

# 🎯 Objetivo
Implementar um sistema de logging robusto e melhorar os middlewares existentes (TLoggingMiddleware e TExceptionHandlingMiddleware) para tornar o framework Dext production-ready.

# 📋 Contexto
- **Localização atual**: `c:\dev\Dext\Sources\Core\Dext.Http.Middleware.pas`
- **Status**: Implementação básica existe, mas falta:
  - Sistema de logging abstrato (ILogger)
  - Níveis de log (Trace, Debug, Info, Warning, Error, Critical)
  - Exception handling com Problem Details (RFC 7807)
  - HTTP logging com métricas (elapsed time, status code)
  - Configuração Development vs Production

# 🔄 Plano de Implementação

## Fase 1: Logging System (1-2 dias)
**Arquivos a criar:**
1. `Dext.Logging.pas` - Interfaces e abstrações
   - Interface `ILogger` com métodos Log, LogInformation, LogWarning, LogError
   - Interface `ILoggerProvider` para criar loggers
   - Enum `TLogLevel` (Trace, Debug, Information, Warning, Error, Critical)
   - Interface `ILoggerFactory` para gerenciar providers

2. `Dext.Logging.Console.pas` - Provider de console
   - Classe `TConsoleLogger` implementando `ILogger`
   - Classe `TConsoleLoggerProvider` implementando `ILoggerProvider`
   - Formatação colorida por nível de log (opcional)

3. `Dext.Logging.Extensions.pas` - Extension methods para DI
   - `AddLogging()` - Registra logging no DI
   - `AddConsoleLogger()` - Adiciona console provider

**Exemplo de uso desejado:**
```pascal
// No WebHost
.ConfigureServices(procedure(Services: IServiceCollection)
begin
  Services.AddLogging(procedure(Builder: ILoggingBuilder)
  begin
    Builder.AddConsole();
    Builder.SetMinimumLevel(TLogLevel.Information);
  end);
end)

// No middleware
constructor THttpLoggingMiddleware.Create(ALogger: ILogger);
begin
  FLogger := ALogger;
end;

procedure THttpLoggingMiddleware.Invoke(...);
begin
  FLogger.LogInformation('HTTP {Method} {Path}', [Method, Path]);
end;
```

## Fase 2: Melhorar Exception Handler (0.5 dia)
**Arquivo a modificar:** `Dext.Http.Middleware.pas`

**Mudanças:**
1. Renomear `TExceptionHandlingMiddleware` → `TExceptionHandlerMiddleware`
2. Adicionar record `TExceptionHandlerOptions`:
   ```pascal
   TExceptionHandlerOptions = record
     IsDevelopment: Boolean;
     IncludeStackTrace: Boolean;
     LogExceptions: Boolean;
     class function Development: TExceptionHandlerOptions; static;
     class function Production: TExceptionHandlerOptions; static;
   end;
   ```

3. Implementar Problem Details (RFC 7807):
   ```pascal
   TProblemDetails = record
     &Type: string;
     Title: string;
     Status: Integer;
     Detail: string;
     Instance: string;
     TraceId: string;
     function ToJson: string;
   end;
   ```

4. Mapear exceções para status codes:
   - `EValidationException` → 400
   - `ENotFoundException` → 404
   - `EUnauthorizedException` → 401
   - `EForbiddenException` → 403
   - Outras → 500

5. Integrar com ILogger para logar exceções

## Fase 3: Melhorar HTTP Logging (0.5 dia)
**Arquivo a modificar:** `Dext.Http.Middleware.pas`

**Mudanças:**
1. Renomear `TLoggingMiddleware` → `THttpLoggingMiddleware`
2. Adicionar record `THttpLoggingOptions`:
   ```pascal
   THttpLoggingOptions = record
     LogRequestHeaders: Boolean;
     LogRequestBody: Boolean;
     LogResponseBody: Boolean;
     MaxBodySize: Integer;
     class function Default: THttpLoggingOptions; static;
   end;
   ```

3. Adicionar métricas:
   - Tempo de execução (elapsed time em ms)
   - Status code da resposta
   - Request ID (correlation)

4. Injetar `ILogger` via construtor

## Fase 4: Extension Methods (0.5 dia)
**Arquivo a criar:** `Dext.Http.Middleware.Extensions.pas`

```pascal
type
  TApplicationBuilderMiddlewareExtensions = class
  public
    class function UseHttpLogging(const ABuilder: IApplicationBuilder): IApplicationBuilder; overload;
    class function UseHttpLogging(const ABuilder: IApplicationBuilder; const AOptions: THttpLoggingOptions): IApplicationBuilder; overload;
    
    class function UseExceptionHandler(const ABuilder: IApplicationBuilder): IApplicationBuilder; overload;
    class function UseExceptionHandler(const ABuilder: IApplicationBuilder; const AOptions: TExceptionHandlerOptions): IApplicationBuilder; overload;
  end;
```

**Exemplo de uso:**
```pascal
App.UseExceptionHandler(TExceptionHandlerOptions.Production)
   .UseHttpLogging();
```

# ✅ Checklist de Conclusão
- [ ] `Dext.Logging.pas` criado com ILogger, ILoggerProvider, ILoggerFactory
- [ ] `Dext.Logging.Console.pas` criado com TConsoleLogger
- [ ] `Dext.Logging.Extensions.pas` criado com AddLogging()
- [ ] `TExceptionHandlerMiddleware` refatorado com Problem Details
- [ ] `THttpLoggingMiddleware` refatorado com métricas
- [ ] `Dext.Http.Middleware.Extensions.pas` criado com UseHttpLogging(), UseExceptionHandler()
- [ ] Testes manuais com `Dext.MinimalAPITest.dpr`
- [ ] Validar logging em console
- [ ] Validar exception handling (Development vs Production)
- [ ] Validar HTTP logging com elapsed time

# 🎯 Resultado Esperado
Após implementação:
- ✅ Sistema de logging abstrato e extensível
- ✅ Console logger funcionando
- ✅ Exception handler com Problem Details (RFC 7807)
- ✅ HTTP logging com métricas de performance
- ✅ Extension methods para fácil configuração
- ✅ Framework production-ready para próxima fase (Swagger/OpenAPI)

# 📝 Notas
- Seguir padrão do ASP.NET Core para interfaces e naming
- Usar structured logging (parâmetros em vez de string interpolation)
- Manter thread-safety onde necessário
- Documentar com XML comments
