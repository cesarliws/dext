# Dext Framework - Fluent API Examples

## 🎯 CORS Configuration

### Opção 1: API Fluente com Builder (Recomendado)

```pascal
// Usando o builder fluente
AppBuilder.UseCors(procedure(Cors: TCorsBuilder)
begin
  Cors.AllowAnyOrigin
      .WithMethods(['GET', 'POST', 'PUT', 'DELETE'])
      .AllowAnyHeader
      .WithMaxAge(3600);
end);
```

### Opção 2: Configuração Manual com Record

```pascal
// Criando options manualmente
var CorsOptions := TCorsOptions.Create;
CorsOptions.AllowedOrigins := ['http://localhost:5173'];
CorsOptions.AllowedMethods := ['GET', 'POST', 'PUT', 'DELETE'];
CorsOptions.AllowCredentials := True;
AppBuilder.UseCors(CorsOptions);
```

### Opção 3: Configuração Padrão

```pascal
// Usando configuração padrão
AppBuilder.UseCors;
```

---

## 🔐 JWT Authentication Configuration

### Opção 1: API Fluente com Builder (Recomendado) ✨ NOVO!

```pascal
// Usando o builder fluente
AppBuilder.UseJwtAuthentication('my-super-secret-key-at-least-32-chars-long', 
  procedure(Auth: TJwtOptionsBuilder)
  begin
    Auth.WithIssuer('dext-store')
        .WithAudience('dext-users')
        .WithExpirationMinutes(120); // 2 hours
  end
);
```

### Opção 2: Configuração Manual com Record

```pascal
// Criando options manualmente
var AuthOptions := TJwtOptions.Create('my-super-secret-key-at-least-32-chars-long');
AuthOptions.Issuer := 'dext-store';
AuthOptions.Audience := 'dext-users';
AuthOptions.ExpirationMinutes := 120;
AppBuilder.UseJwtAuthentication(AuthOptions);
```

---

## 📦 Exemplo Completo - DextStore API

```pascal
program DextStoreAPI;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Dext;

begin
  try
    var App := TDextApplication.Create;
    
    // Configure Services
    App.Services
      .AddSingleton<IProductService, TProductService>
      .AddSingleton<ICartService, TCartService>
      .AddControllers;
    
    var Builder := App.Builder;
    
    // ✨ CORS with Fluent API
    Builder.UseCors(procedure(Cors: TCorsBuilder)
    begin
      Cors.WithOrigins(['http://localhost:5173', 'https://myapp.com'])
          .WithMethods(['GET', 'POST', 'PUT', 'DELETE'])
          .WithHeaders(['Content-Type', 'Authorization'])
          .AllowCredentials
          .WithMaxAge(3600);
    end);
    
    // ✨ JWT Authentication with Fluent API
    Builder.UseJwtAuthentication('dext-store-secret-key-must-be-very-long-and-secure',
      procedure(Auth: TJwtOptionsBuilder)
      begin
        Auth.WithIssuer('dext-store')
            .WithAudience('dext-users')
            .WithExpirationMinutes(60);
      end
    );
    
    // Map Controllers
    App.MapControllers;
    
    // Run!
    WriteLn('🚀 DextStore API running on http://localhost:8080');
    App.Run(8080);
  except
    on E: Exception do
      WriteLn('❌ Error: ', E.Message);
  end;
end.
```

---

## 🎨 Comparação: Antes vs Depois

### ❌ Antes (Verboso)

```pascal
var CorsOptions := TCorsOptions.Create;
CorsOptions.AllowedOrigins := ['*'];
CorsOptions.AllowedMethods := ['GET', 'POST', 'PUT', 'DELETE'];
CorsOptions.AllowedHeaders := ['Content-Type', 'Authorization'];
CorsOptions.AllowCredentials := False;
CorsOptions.MaxAge := 3600;
AppBuilder.UseCors(CorsOptions);

var AuthOptions := TJwtOptions.Create('secret-key');
AuthOptions.Issuer := 'dext-store';
AuthOptions.Audience := 'dext-users';
AuthOptions.ExpirationMinutes := 60;
AppBuilder.UseJwtAuthentication(AuthOptions);
```

### ✅ Depois (Fluente e Elegante)

```pascal
AppBuilder.UseCors(procedure(Cors: TCorsBuilder)
begin
  Cors.AllowAnyOrigin
      .WithMethods(['GET', 'POST', 'PUT', 'DELETE'])
      .AllowAnyHeader
      .WithMaxAge(3600);
end);

AppBuilder.UseJwtAuthentication('secret-key', procedure(Auth: TJwtOptionsBuilder)
begin
  Auth.WithIssuer('dext-store')
      .WithAudience('dext-users')
      .WithExpirationMinutes(60);
end);
```

---

## 🚀 Benefícios da API Fluente

1. **Mais Legível**: O código se lê como uma frase natural
2. **Menos Verboso**: Menos linhas de código para a mesma funcionalidade
3. **IntelliSense Amigável**: O IDE sugere os próximos métodos disponíveis
4. **Imutabilidade Implícita**: O builder encapsula a configuração
5. **Consistência**: Mesmo padrão usado em ASP.NET Core e outros frameworks modernos

---

## 📚 Métodos Disponíveis

### TCorsBuilder

- `WithOrigins(const AOrigins: array of string): TCorsBuilder`
- `AllowAnyOrigin: TCorsBuilder`
- `WithMethods(const AMethods: array of string): TCorsBuilder`
- `AllowAnyMethod: TCorsBuilder`
- `WithHeaders(const AHeaders: array of string): TCorsBuilder`
- `AllowAnyHeader: TCorsBuilder`
- `WithExposedHeaders(const AHeaders: array of string): TCorsBuilder`
- `AllowCredentials: TCorsBuilder`
- `WithMaxAge(ASeconds: Integer): TCorsBuilder`
- `Build: TCorsOptions`

### TJwtOptionsBuilder

- `WithIssuer(const AIssuer: string): TJwtOptionsBuilder`
- `WithAudience(const AAudience: string): TJwtOptionsBuilder`
- `WithExpirationMinutes(AMinutes: Integer): TJwtOptionsBuilder`
- `Build: TJwtOptions`

---

**Dext Framework** - Modern Web Development for Delphi 🚀
