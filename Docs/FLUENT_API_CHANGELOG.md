# ✨ Nova Feature: Fluent API Builders para CORS e JWT

## 🎯 Resumo

Implementamos **builders fluentes** para configuração de CORS e JWT Authentication, seguindo o mesmo padrão de frameworks modernos como ASP.NET Core.

## 📦 O que foi adicionado?

### 1. **JWT Options Builder** (`Dext.Auth.JWT.pas`)

#### Novos tipos:
- `TJwtOptions` - Record com configurações JWT
- `TJwtOptionsBuilder` - Builder fluente para JWT
- `TJwtOptionsHelper` - Helper para conversão implícita

#### API:
```pascal
var Builder := TJwtOptionsBuilder.Create('secret-key');
var Options := Builder
  .WithIssuer('my-issuer')
  .WithAudience('my-audience')
  .WithExpirationMinutes(120)
  .Build;
```

### 2. **Extension Methods** (`Dext.Auth.Middleware.pas`)

#### Nova classe:
- `TApplicationBuilderJwtExtensions` - Extension methods para `IApplicationBuilder`

#### API:
```pascal
// Opção 1: Com options
AppBuilder.UseJwtAuthentication(jwtOptions);

// Opção 2: Com builder fluente
AppBuilder.UseJwtAuthentication('secret-key', procedure(Auth: TJwtOptionsBuilder)
begin
  Auth.WithIssuer('dext-store')
      .WithAudience('dext-users')
      .WithExpirationMinutes(60);
end);
```

### 3. **CORS Builder** (já existia, documentado)

O CORS já tinha um builder fluente completo em `Dext.Http.Cors.pas`:

```pascal
AppBuilder.UseCors(procedure(Cors: TCorsBuilder)
begin
  Cors.AllowAnyOrigin
      .WithMethods(['GET', 'POST', 'PUT', 'DELETE'])
      .AllowAnyHeader
      .WithMaxAge(3600);
end);
```

## 🔄 Mudanças de Breaking Changes

### ⚠️ `Dext.Auth.Middleware.pas`

**Removido:**
- `TJwtAuthenticationOptions` (substituído por `TJwtOptions`)
- `TJwtAuthenticationOptions.Default()` (substituído por `TJwtOptions.Create()`)

**Atualizado:**
- `TJwtAuthenticationMiddleware.Create()` agora aceita `TJwtOptions` ao invés de `TJwtAuthenticationOptions`
- Removido `destructor Destroy` (agora usa interface `IJwtTokenHandler`)

**Migração:**
```pascal
// ❌ Antes
var Options := TJwtAuthenticationOptions.Default('secret-key');
Options.Issuer := 'my-issuer';

// ✅ Depois
var Options := TJwtOptions.Create('secret-key');
Options.Issuer := 'my-issuer';
```

## 📝 Exemplos de Uso

### Exemplo Completo - DextStore API

```pascal
program DextStoreAPI;

uses
  System.SysUtils,
  Dext;

begin
  var App := TDextApplication.Create;
  
  // Services
  App.Services
    .AddSingleton<IProductService, TProductService>
    .AddControllers;
  
  var Builder := App.Builder;
  
  // ✨ CORS com API Fluente
  Builder.UseCors(procedure(Cors: TCorsBuilder)
  begin
    Cors.WithOrigins(['http://localhost:5173'])
        .WithMethods(['GET', 'POST', 'PUT', 'DELETE'])
        .AllowCredentials;
  end);
  
  // ✨ JWT com API Fluente
  Builder.UseJwtAuthentication('secret-key', procedure(Auth: TJwtOptionsBuilder)
  begin
    Auth.WithIssuer('dext-store')
        .WithAudience('dext-users')
        .WithExpirationMinutes(60);
  end);
  
  App.MapControllers;
  App.Run(8080);
end.
```

## 🎨 Comparação Visual

### Antes (Verboso)
```pascal
var AuthOptions := TJwtAuthenticationOptions.Default('secret-key');
AuthOptions.Issuer := 'dext-store';
AuthOptions.Audience := 'dext-users';
AuthOptions.TokenPrefix := 'Bearer ';
// Como usar? Não havia extension method!
```

### Depois (Fluente e Elegante)
```pascal
AppBuilder.UseJwtAuthentication('secret-key', procedure(Auth: TJwtOptionsBuilder)
begin
  Auth.WithIssuer('dext-store')
      .WithAudience('dext-users')
      .WithExpirationMinutes(60);
end);
```

## 📚 Documentação

- **Guia Completo**: `docs/FLUENT_API_EXAMPLES.md`
- **Demo Executável**: `Examples/FluentAPIDemo.dpr`

## ✅ Status

- [x] `TJwtOptions` record criado
- [x] `TJwtOptionsBuilder` implementado
- [x] Extension methods para `IApplicationBuilder`
- [x] Documentação completa
- [x] Exemplo de demonstração
- [x] Compatibilidade com código existente

## 🚀 Próximos Passos

1. Atualizar exemplos existentes para usar a nova API
2. Adicionar testes unitários para os builders
3. Considerar adicionar builders para outros middlewares (Rate Limiting, Caching, etc.)

---

**Dext Framework** - Modern Web Development for Delphi 🚀
