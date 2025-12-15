# CORS (Cross-Origin Resource Sharing) - Dext Framework

Sistema completo de CORS para permitir requisições cross-origin de forma segura e configurável.

## 🌐 O que é CORS?

CORS (Cross-Origin Resource Sharing) é um mecanismo de segurança que permite que um servidor indique quais origens (domínios) têm permissão para acessar seus recursos. Por padrão, navegadores bloqueiam requisições cross-origin por segurança.

**Exemplo de problema sem CORS:**
```
Frontend em: http://localhost:3000
API em: http://localhost:8080

❌ Navegador bloqueia a requisição por política de mesma origem (Same-Origin Policy)
```

**Solução com CORS:**
```
API adiciona headers CORS permitindo http://localhost:3000
✅ Navegador permite a requisição
```

## 📦 Recursos

- ✅ **Builder Fluente** para configuração elegante
- ✅ **Preflight Requests** (OPTIONS) automáticos
- ✅ **Múltiplas Origens** ou wildcard (*)
- ✅ **Métodos HTTP** configuráveis
- ✅ **Headers** personalizados
- ✅ **Credentials** (cookies, auth headers)
- ✅ **Cache de Preflight** (Max-Age)
- ✅ **Debug Log** opcional

## 🚀 Uso Básico

### 1. CORS Permissivo (Desenvolvimento)

```pascal
uses
  Dext.Http.Cors;

var
  App: IWebApplication;
begin
  App := TDextApplication.Create;
  var Builder := App.GetApplicationBuilder;

  // ✅ Permitir qualquer origem (desenvolvimento)
  TApplicationBuilderCorsExtensions.UseCors(Builder,
    procedure(Cors: TCorsBuilder)
    begin
      Cors
        .AllowAnyOrigin
        .AllowAnyMethod
        .AllowAnyHeader;
    end);

  // ... configurar rotas ...

  App.Run(8080);
end;
```

### 2. CORS Restritivo (Produção)

```pascal
// ✅ Permitir apenas origens específicas
TApplicationBuilderCorsExtensions.UseCors(Builder,
  procedure(Cors: TCorsBuilder)
  begin
    Cors
      .WithOrigins(['https://myapp.com', 'https://www.myapp.com'])
      .WithMethods(['GET', 'POST', 'PUT', 'DELETE'])
      .WithHeaders(['Content-Type', 'Authorization'])
      .AllowCredentials
      .WithMaxAge(3600); // Cache preflight por 1 hora
  end);
```

### 3. CORS com Opções Explícitas

```pascal
var
  Options: TCorsOptions;
begin
  Options := TCorsBuilder.Create
    .WithOrigins(['http://localhost:3000'])
    .WithMethods(['GET', 'POST'])
    .WithHeaders(['Content-Type'])
    .Build;

  TApplicationBuilderCorsExtensions.UseCors(Builder, Options);
end;
```

## 🎯 Exemplos Práticos

### Exemplo 1: API Pública

```pascal
// API que pode ser acessada de qualquer lugar
TApplicationBuilderCorsExtensions.UseCors(Builder,
  procedure(Cors: TCorsBuilder)
  begin
    Cors.AllowAnyOrigin
        .AllowAnyMethod
        .AllowAnyHeader;
  end);
```

### Exemplo 2: SPA + API

```pascal
// Frontend React/Vue/Angular + Backend Dext
TApplicationBuilderCorsExtensions.UseCors(Builder,
  procedure(Cors: TCorsBuilder)
  begin
    Cors
      .WithOrigins(['http://localhost:3000', 'http://localhost:5173']) // Vite/React
      .WithMethods(['GET', 'POST', 'PUT', 'DELETE', 'PATCH'])
      .WithHeaders(['Content-Type', 'Authorization', 'X-Requested-With'])
      .AllowCredentials; // Para cookies/auth
  end);
```

### Exemplo 3: Múltiplos Ambientes

```pascal
var
  AllowedOrigins: TArray<string>;
begin
  // Configurar origens baseado no ambiente
  {$IFDEF DEBUG}
  AllowedOrigins := ['http://localhost:3000', 'http://localhost:5173'];
  {$ELSE}
  AllowedOrigins := ['https://myapp.com', 'https://www.myapp.com'];
  {$ENDIF}

  TApplicationBuilderCorsExtensions.UseCors(Builder,
    procedure(Cors: TCorsBuilder)
    begin
      Cors
        .WithOrigins(AllowedOrigins)
        .WithMethods(['GET', 'POST', 'PUT', 'DELETE'])
        .WithHeaders(['Content-Type', 'Authorization'])
        .AllowCredentials
        .WithMaxAge(7200); // 2 horas
    end);
end;
```

### Exemplo 4: Headers Expostos

```pascal
// Expor headers personalizados para o cliente
TApplicationBuilderCorsExtensions.UseCors(Builder,
  procedure(Cors: TCorsBuilder)
  begin
    Cors
      .WithOrigins(['https://myapp.com'])
      .AllowAnyMethod
      .AllowAnyHeader
      .WithExposedHeaders(['X-Total-Count', 'X-Page-Number', 'X-Custom-Header']);
  end);
```

### Exemplo 5: Debug Mode

```pascal
// Habilitar logs detalhados para debug
var
  Options: TCorsOptions;
  Middleware: TCorsMiddleware;
begin
  Options := TCorsBuilder.Create
    .AllowAnyOrigin
    .AllowAnyMethod
    .AllowAnyHeader
    .Build;

  // Criar middleware com debug habilitado
  Middleware := TCorsMiddleware.Create(Options, True); // True = debug log
  
  Builder.UseMiddleware(TCorsMiddleware, TValue.From(Options));
end;
```

## 📋 Métodos do Builder

| Método | Descrição | Exemplo |
|--------|-----------|---------|
| `WithOrigins(origins)` | Define origens permitidas | `.WithOrigins(['https://app.com'])` |
| `AllowAnyOrigin` | Permite qualquer origem (*) | `.AllowAnyOrigin` |
| `WithMethods(methods)` | Define métodos HTTP permitidos | `.WithMethods(['GET', 'POST'])` |
| `AllowAnyMethod` | Permite qualquer método | `.AllowAnyMethod` |
| `WithHeaders(headers)` | Define headers permitidos | `.WithHeaders(['Content-Type'])` |
| `AllowAnyHeader` | Permite qualquer header | `.AllowAnyHeader` |
| `WithExposedHeaders(headers)` | Headers expostos ao cliente | `.WithExposedHeaders(['X-Total'])` |
| `AllowCredentials` | Permite credentials (cookies) | `.AllowCredentials` |
| `WithMaxAge(seconds)` | Cache de preflight (segundos) | `.WithMaxAge(3600)` |
| `Build` | Retorna `TCorsOptions` | `.Build` |

## 🔒 Segurança

### ⚠️ Cuidados Importantes

1. **Não use `AllowAnyOrigin` em produção**
   ```pascal
   // ❌ INSEGURO em produção
   Cors.AllowAnyOrigin.AllowCredentials;
   
   // ✅ SEGURO - origens específicas
   Cors.WithOrigins(['https://myapp.com']).AllowCredentials;
   ```

2. **AllowAnyOrigin + AllowCredentials não funcionam juntos**
   ```pascal
   // ❌ Navegadores rejeitam esta combinação
   Cors.AllowAnyOrigin.AllowCredentials;
   
   // ✅ Use origens específicas com credentials
   Cors.WithOrigins(['https://app.com']).AllowCredentials;
   ```

3. **Liste apenas origens confiáveis**
   ```pascal
   // ❌ Muito permissivo
   Cors.WithOrigins(['*']);
   
   // ✅ Específico e seguro
   Cors.WithOrigins([
     'https://myapp.com',
     'https://www.myapp.com',
     'https://admin.myapp.com'
   ]);
   ```

4. **Use HTTPS em produção**
   ```pascal
   // ❌ HTTP em produção
   Cors.WithOrigins(['http://myapp.com']);
   
   // ✅ HTTPS em produção
   Cors.WithOrigins(['https://myapp.com']);
   ```

## 🧪 Testando CORS

### Teste com cURL

```bash
# Testar preflight (OPTIONS)
curl -X OPTIONS http://localhost:8080/api/users \
  -H "Origin: http://localhost:3000" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: Content-Type" \
  -v

# Testar requisição real
curl -X GET http://localhost:8080/api/users \
  -H "Origin: http://localhost:3000" \
  -v
```

### Teste com JavaScript

```javascript
// No frontend (http://localhost:3000)
fetch('http://localhost:8080/api/users', {
  method: 'GET',
  headers: {
    'Content-Type': 'application/json'
  }
})
.then(response => response.json())
.then(data => console.log('Success:', data))
.catch(error => console.error('CORS Error:', error));
```

### Verificar Headers na Resposta

Headers que devem aparecer:
```
Access-Control-Allow-Origin: http://localhost:3000
Access-Control-Allow-Methods: GET, POST, PUT, DELETE
Access-Control-Allow-Headers: Content-Type, Authorization
Access-Control-Allow-Credentials: true
Access-Control-Max-Age: 3600
```

## 🔍 Troubleshooting

### Problema: "CORS policy: No 'Access-Control-Allow-Origin' header"

**Causa:** CORS não está configurado ou a origem não está permitida.

**Solução:**
```pascal
// Adicionar middleware CORS
TApplicationBuilderCorsExtensions.UseCors(Builder,
  procedure(Cors: TCorsBuilder)
  begin
    Cors.WithOrigins(['http://localhost:3000']);
  end);
```

### Problema: "CORS policy: Credentials flag is 'true', but 'Access-Control-Allow-Origin' is '*'"

**Causa:** Não pode usar `AllowAnyOrigin` com `AllowCredentials`.

**Solução:**
```pascal
// Trocar AllowAnyOrigin por origens específicas
Cors
  .WithOrigins(['http://localhost:3000'])
  .AllowCredentials;
```

### Problema: Preflight OPTIONS retorna 404

**Causa:** Middleware CORS não está registrado ou está depois do routing.

**Solução:**
```pascal
// CORS deve vir ANTES do routing
Builder.Use(CorsMiddleware);  // ✅ Primeiro
Builder.MapGet('/api/users', ...);  // Depois
```

## 📚 Referências

- [MDN - CORS](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS)
- [W3C - CORS Specification](https://www.w3.org/TR/cors/)
- [CORS Best Practices](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS#security)

---

**Desenvolvido com 🌐 para o Dext Framework**
