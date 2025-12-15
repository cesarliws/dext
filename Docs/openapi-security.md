# Suporte a Autenticação e Autorização no OpenAPI (Swagger)

Este documento descreve as novas funcionalidades de segurança implementadas no gerador OpenAPI do Dext Framework.

## Funcionalidades Implementadas

1.  **Definição de Security Schemes**: Suporte para definir esquemas de segurança como Bearer Auth (JWT) e API Key.
2.  **Atributos de Autorização**: Novo atributo `[SwaggerAuthorize]` para marcar endpoints protegidos.
3.  **Geração de JSON**: O gerador agora inclui as seções `security` (nas operações) e `components/securitySchemes` (no documento raiz).

## Como Usar

### 1. Configurar Security Schemes

Ao configurar o Swagger, você pode habilitar os esquemas de segurança desejados:

```pascal
var
  Options: TOpenAPIOptions;
begin
  Options := TOpenAPIOptions.Default;
  
  // Habilitar JWT Bearer Auth
  Options := Options.WithBearerAuth('JWT', 'Entre com o token JWT no formato: Bearer {token}');
  
  // Habilitar API Key Auth
  Options := Options.WithApiKeyAuth('X-API-Key', aklHeader, 'Chave de API para acesso');
  
  // ... passar Options para o gerador ou middleware
end;
```

### 2. Proteger Endpoints

#### Usando Controllers

Para marcar um endpoint como protegido, você pode usar o atributo `[SwaggerAuthorize]` no controller ou no método. O scanner de controllers detecta automaticamente esses atributos.

```pascal
type
  [SwaggerAuthorize('bearerAuth')] // Todos os métodos requerem autenticação Bearer
  TMyController = record
    [DextGet('/api/protected')]
    class procedure GetProtected(Ctx: IHttpContext); static;
    
    [DextGet('/api/admin')]
    [SwaggerAuthorize('apiKeyAuth')] // Requer AMBOS (bearerAuth E apiKeyAuth)
    class procedure GetAdmin(Ctx: IHttpContext); static;
  end;
```

#### Usando Minimal API

Para Minimal API, utilize o método de extensão `RequireAuthorization`:

```pascal
App.MapGet('/api/secure', 
  procedure(Ctx: IHttpContext)
  begin
    Ctx.Response.Write('Secure Data');
  end)
  .RequireAuthorization('bearerAuth');
```

### 3. JSON Gerado

O JSON gerado agora incluirá:

```json
{
  "openapi": "3.0.0",
  "paths": {
    "/api/protected": {
      "get": {
        "security": [
          {
            "bearerAuth": []
          }
        ],
        ...
      }
    }
  },
  "components": {
    "securitySchemes": {
      "bearerAuth": {
        "type": "http",
        "scheme": "bearer",
        "bearerFormat": "JWT",
        "description": "..."
      },
      "apiKeyAuth": {
        "type": "apiKey",
        "name": "X-API-Key",
        "in": "header"
      }
    }
  }
}
```

## Arquivos Modificados

*   `Dext.OpenAPI.Types.pas`: Adicionado suporte a `Security` em `TOpenAPIOperation` e tipos para Security Schemes.
*   `Dext.OpenAPI.Attributes.pas`: Adicionado `SwaggerAuthorizeAttribute`.
*   `Dext.OpenAPI.Generator.pas`: Implementada lógica de geração de Security Schemes e serialização JSON.
*   `Dext.Http.Interfaces.pas`: Adicionado campo `Security` em `TEndpointMetadata`.
