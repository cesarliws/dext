# JWT Authentication - Dext Framework

Sistema completo de autenticação e autorização usando JSON Web Tokens (JWT) para o Dext Framework.

## 🔐 Recursos

- **Geração de Tokens JWT** com HMAC-SHA256
- **Validação de Tokens** com verificação de assinatura e expiração
- **Claims-based Identity** para representar usuários autenticados
- **Middleware de Autenticação** que valida tokens automaticamente
- **Autorização baseada em Roles** (`IsInRole`)
- **Suporte a Claims personalizados**

## 📦 Componentes

### 1. `Dext.Auth.JWT` - Geração e Validação de Tokens

```pascal
var
  JwtHandler: TJwtTokenHandler;
  Claims: TArray<TClaim>;
  Token: string;
begin
  // Criar handler
  JwtHandler := TJwtTokenHandler.Create(
    'my-secret-key',      // Secret key
    'MyApp',              // Issuer (opcional)
    'MyAPI',              // Audience (opcional)
    60                    // Expiration em minutos
  );

  // Criar claims
  SetLength(Claims, 3);
  Claims[0] := TClaim.Create(TClaimTypes.NameIdentifier, '123');
  Claims[1] := TClaim.Create(TClaimTypes.Name, 'john.doe');
  Claims[2] := TClaim.Create(TClaimTypes.Role, 'Admin');

  // Gerar token
  Token := JwtHandler.GenerateToken(Claims);

  // Validar token
  var ValidationResult := JwtHandler.ValidateToken(Token);
  if ValidationResult.IsValid then
    WriteLn('Token válido!')
  else
    WriteLn('Erro: ' + ValidationResult.ErrorMessage);
end;
```

#### **Claims Builder (Fluent Interface)** ✨

Para facilitar a criação de claims, use o `TClaimsBuilder`:

```pascal
// ✅ Sintaxe fluente e elegante
var Claims := TClaimsBuilder.Create
  .WithNameIdentifier('123')
  .WithName('john.doe')
  .WithEmail('john@example.com')
  .WithRole('Admin')
  .WithRole('User')  // Múltiplas roles
  .WithGivenName('John')
  .WithFamilyName('Doe')
  .AddClaim('custom_claim', 'custom_value')  // Claims personalizados
  .Build;

// Gerar token com os claims
Token := JwtHandler.GenerateToken(Claims);
```

**Métodos disponíveis:**
- `WithNameIdentifier(value)` - Define o ID do usuário (`sub`)
- `WithName(value)` - Define o nome do usuário (`name`)
- `WithEmail(value)` - Define o email (`email`)
- `WithRole(value)` - Adiciona uma role (`role`) - pode ser chamado múltiplas vezes
- `WithGivenName(value)` - Define o primeiro nome (`given_name`)
- `WithFamilyName(value)` - Define o sobrenome (`family_name`)
- `AddClaim(type, value)` - Adiciona um claim personalizado
- `Build` - Retorna o array de claims
- `Count` - Retorna o número de claims

### 2. `Dext.Auth.Identity` - Identidade e Claims

```pascal
// Criar identidade
var Identity: IIdentity := TClaimsIdentity.Create('john.doe', 'JWT');

// Criar principal com claims
var Principal: IClaimsPrincipal := TClaimsPrincipal.Create(Identity, Claims);

// Usar claims
if Principal.Identity.IsAuthenticated then
begin
  WriteLn('User: ' + Principal.Identity.Name);
  
  // Buscar claim específico
  var UserId := Principal.FindClaim(TClaimTypes.NameIdentifier).Value;
  
  // Verificar role
  if Principal.IsInRole('Admin') then
    WriteLn('User is an Admin');
end;
```

### 3. `Dext.Auth.Middleware` - Middleware de Autenticação

```pascal
// Configurar middleware
var Options := TJwtAuthenticationOptions.Default('my-secret-key');
Options.Issuer := 'MyApp';
Options.Audience := 'MyAPI';
Options.TokenPrefix := 'Bearer ';

App.UseMiddleware(TJwtAuthenticationMiddleware, TValue.From(Options));
```

O middleware:
1. Extrai o token do header `Authorization`
2. Valida a assinatura e expiração
3. Popula `Context.User` com o `IClaimsPrincipal`

## 🚀 Exemplo Completo

### 1. Configurar Aplicação

```pascal
program MyAuthApp;

uses
  Dext.Core.WebApplication,
  Dext.Auth.JWT,
  Dext.Auth.Identity,
  Dext.Auth.Middleware,
  Dext.Http.Results;

const
  SECRET_KEY = 'change-this-in-production';

var
  App: IWebApplication;
  JwtHandler: TJwtTokenHandler;
begin
  App := TDextApplication.Create;
  JwtHandler := TJwtTokenHandler.Create(SECRET_KEY, 'MyApp', 'MyAPI', 60);

  var Builder := App.GetApplicationBuilder;

  // Adicionar middleware de autenticação
  Builder.UseMiddleware(TJwtAuthenticationMiddleware,
    TValue.From(TJwtAuthenticationOptions.Default(SECRET_KEY)));

  // ... configurar rotas ...

  App.Run(8080);
end.
```

### 2. Endpoint de Login

```pascal
type
  TLoginRequest = record
    Username: string;
    Password: string;
  end;

// Endpoint público que gera token
TApplicationBuilderExtensions.MapPostR<TLoginRequest, IResult>(Builder, '/api/auth/login',
  function(Request: TLoginRequest): IResult
  var
    Claims: TArray<TClaim>;
    Token: string;
  begin
    // Validar credenciais (exemplo simples)
    if (Request.Username = 'admin') and (Request.Password = 'password') then
    begin
      // ✅ Criar claims com fluent builder
      Claims := TClaimsBuilder.Create
        .WithNameIdentifier('123')
        .WithName(Request.Username)
        .WithRole('Admin')
        .WithEmail('admin@example.com')
        .Build;

      // Gerar token
      Token := JwtHandler.GenerateToken(Claims);

      Result := Results.Ok(Format('{"token":"%s","expiresIn":3600}', [Token]));
    end
    else
      Result := Results.BadRequest('{"error":"Invalid credentials"}');
  end);
```

### 3. Endpoint Protegido

```pascal
// Endpoint que requer autenticação
TApplicationBuilderExtensions.MapGetR<IHttpContext, IResult>(Builder, '/api/protected',
  function(Context: IHttpContext): IResult
  var
    User: IClaimsPrincipal;
  begin
    User := Context.User;

    // Verificar autenticação
    if (User = nil) or not User.Identity.IsAuthenticated then
    begin
      Result := Results.StatusCode(401, '{"error":"Unauthorized"}');
      Exit;
    end;

    // Usuário autenticado - retornar dados
    Result := Results.Ok(Format(
      '{"message":"Hello, %s!","userId":"%s"}',
      [User.Identity.Name, User.FindClaim(TClaimTypes.NameIdentifier).Value]
    ));
  end);
```

### 4. Endpoint com Autorização por Role

```pascal
// Endpoint que requer role específica
TApplicationBuilderExtensions.MapGetR<IHttpContext, IResult>(Builder, '/api/admin',
  function(Context: IHttpContext): IResult
  var
    User: IClaimsPrincipal;
  begin
    User := Context.User;

    // Verificar autenticação
    if (User = nil) or not User.Identity.IsAuthenticated then
    begin
      Result := Results.StatusCode(401, '{"error":"Unauthorized"}');
      Exit;
    end;

    // Verificar role
    if not User.IsInRole('Admin') then
    begin
      Result := Results.StatusCode(403, '{"error":"Forbidden - Admin role required"}');
      Exit;
    end;

    // Admin autorizado
    Result := Results.Ok('{"message":"Welcome, Admin!"}');
  end);
```

## 🧪 Testando

### 1. Fazer Login

```bash
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"password"}'
```

Resposta:
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expiresIn": 3600
}
```

### 2. Acessar Endpoint Protegido

```bash
curl http://localhost:8080/api/protected \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

Resposta (sucesso):
```json
{
  "message": "Hello, admin!",
  "userId": "123"
}
```

### 3. Tentar Acessar sem Token

```bash
curl http://localhost:8080/api/protected
```

Resposta (erro 401):
```json
{
  "error": "Unauthorized"
}
```

### 4. Acessar Endpoint Admin

```bash
curl http://localhost:8080/api/admin \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

Resposta (se tiver role Admin):
```json
{
  "message": "Welcome, Admin!"
}
```

## 📋 Claims Padrão

O framework define constantes para claims comuns em `TClaimTypes`:

| Claim | Constante | Descrição |
|-------|-----------|-----------|
| `sub` | `NameIdentifier` | ID do usuário |
| `name` | `Name` | Nome do usuário |
| `email` | `Email` | Email |
| `role` | `Role` | Role/função |
| `given_name` | `GivenName` | Primeiro nome |
| `family_name` | `FamilyName` | Sobrenome |
| `exp` | `Expiration` | Timestamp de expiração |
| `iat` | `IssuedAt` | Timestamp de emissão |
| `iss` | `Issuer` | Emissor do token |
| `aud` | `Audience` | Audiência do token |

## 🔒 Segurança

### Boas Práticas

1. **Secret Key Forte**: Use uma chave longa e aleatória
   ```pascal
   // ❌ Ruim
   SecretKey := '123456';
   
   // ✅ Bom
   SecretKey := 'a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6';
   ```

2. **Armazenar Secret Key com Segurança**
   - Nunca commite a chave no código
   - Use variáveis de ambiente ou arquivo de configuração
   - Considere usar um key vault em produção

3. **HTTPS Obrigatório**
   - Sempre use HTTPS em produção
   - Tokens em HTTP podem ser interceptados

4. **Tempo de Expiração Adequado**
   ```pascal
   // Tokens de curta duração (15-60 min)
   JwtHandler := TJwtTokenHandler.Create(SecretKey, '', '', 30);
   
   // Implemente refresh tokens para sessões longas
   ```

5. **Validar Issuer e Audience**
   ```pascal
   Options.Issuer := 'MyApp';
   Options.Audience := 'MyAPI';
   ```

### Limitações Atuais

- ⚠️ Não há suporte para refresh tokens (planejado)
- ⚠️ Não há blacklist de tokens revogados (planejado)
- ⚠️ Apenas HMAC-SHA256 (RSA planejado)

## 🎯 Próximos Passos

- [ ] Implementar refresh tokens
- [ ] Suporte a RSA (RS256)
- [ ] Token blacklist/revogação
- [ ] Atributos `[Authorize]` e `[AllowAnonymous]` automáticos
- [ ] Integração com Identity providers (OAuth2, OpenID Connect)

---

**Desenvolvido com 🔐 para o Dext Framework**
