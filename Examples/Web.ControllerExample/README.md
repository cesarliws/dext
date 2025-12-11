# 🚀 Dext Framework - Controller Showcase

## 📖 Sobre o Projeto

Este é um **showcase completo** demonstrando todas as capacidades do **Dext Framework Controllers** - um framework web moderno para Delphi inspirado em ASP.NET Core.

## ✨ Features Implementadas

### 🔐 1. **JWT Authentication & Authorization**
- Middleware de autenticação JWT
- Atributo `[SwaggerAuthorize]` para proteção de controllers
- Validação automática de tokens
- Retorno 401 Unauthorized para requisições não autenticadas

### 📦 2. **Smart Parameter Binding**
- **Route Binding**: `[FromRoute]` - Parâmetros da URL
- **Body Binding**: `[FromBody]` - DTOs do corpo da requisição
- **Query Binding**: `[FromQuery]` - Parâmetros de query string
- **Header Binding**: `[FromHeader]` - Headers HTTP
- **Service Injection**: `[FromServices]` - Dependency Injection

### ✅ 3. **Automatic Validation**
- `[Required]` - Campos obrigatórios
- `[StringLength(min, max)]` - Validação de tamanho
- `[EmailAddress]` - Validação de email
- `[Range(min, max)]` - Validação de range numérico
- Retorno automático de 400 Bad Request com erros detalhados

### 🎯 4. **Auto JSON Serialization**
- Retorno direto de DTOs/Records
- Serialização automática para JSON
- Suporte a arrays e listas
- Configuração de case style (camelCase, PascalCase, snake_case)

### 🌐 5. **CORS Support**
- Middleware CORS configurável
- Suporte a preflight requests
- Headers customizáveis

### 📁 6. **Static Files**
- Middleware para servir arquivos estáticos
- Suporte completo a binários (imagens, fontes, etc.)
- MIME type detection automático
- Ideal para SPAs

## 🏗️ Arquitetura

```
Dext/
├── Sources/Core/
│   ├── Dext.Core.Controllers.pas       # Base para controllers
│   ├── Dext.Core.ControllerScanner.pas # Scanner e registro de rotas
│   ├── Dext.Core.HandlerInvoker.pas    # Invocação dinâmica de métodos
│   ├── Dext.Core.ModelBinding.pas      # Binding de parâmetros
│   ├── Dext.Validation.pas             # Sistema de validação
│   ├── Dext.Auth.Middleware.pas        # Autenticação JWT
│   ├── Dext.Http.Cors.pas              # CORS middleware
│   ├── Dext.Http.StaticFiles.pas       # Static files middleware
│   └── Dext.Json.pas                   # Serialização JSON
│
└── Examples/
    ├── Web.ControllerExample/          # Backend exemplo
    │   ├── WebControllerExample.dpr    # Backend exemplo
    │   ├── ControllerExample.Controller.pas # Controllers de exemplo
    │   └── WebClient/                  # Frontend React showcase
        ├── src/
        │   ├── api/client.ts           # Cliente API
        │   ├── pages/
        │   │   ├── LoginPage.tsx       # Página de login
        │   │   └── DashboardPage.tsx   # Dashboard principal
        │   └── App.tsx
        └── package.json
```

## 🎮 Como Usar

### Backend (Delphi)

```pascal
program Web.ControllerExample;

uses
  Dext.Core.WebApplication,
  Dext.DI.Extensions,
  Dext.Http.Cors,
  Dext.Http.StaticFiles,
  Dext.Auth.Middleware;

begin
  var App := TDextApplication.Create;
  
  // Register services
  TServiceCollectionExtensions.AddSingleton<IGreetingService, TGreetingService>(App.Services);
  TServiceCollectionExtensions.AddControllers(App.Services);
  
  // Middleware Pipeline
  App.GetApplicationBuilder
     .UseCors(TCorsOptions.Create)
     .UseStaticFiles(TStaticFileOptions.Create)
     .UseMiddleware(TJwtAuthenticationMiddleware, 
        TValue.From(TJwtAuthenticationOptions.Default('your-secret-key')));
     
  // Map controllers
  App.MapControllers;
  
  // Run
  App.Run(8080);
end.
```

### Controller Example

```pascal
[DextController('/api/greet')]
[SwaggerAuthorize('Bearer')]
TGreetingController = class
private
  FService: IGreetingService;
public
  constructor Create(AService: IGreetingService); // DI!
  
  [DextGet('/{name}')]
  procedure GetGreeting(Ctx: IHttpContext; [FromRoute] const Name: string);
  
  [DextPost('/')]
  procedure CreateGreeting(Ctx: IHttpContext; const Request: TGreetingRequest);
  
  [DextGet('/search')]
  procedure SearchGreeting(Ctx: IHttpContext; const Filter: TGreetingFilter);
end;

// DTO with validation
TGreetingRequest = record
  [Required]
  [StringLength(3, 50)]
  Name: string;
  [Required]
  Title: string;
end;
```

### Frontend (React + TypeScript)

```bash
cd Examples/WebClient
npm install
npm run dev
```

Acesse `http://localhost:5173` e faça login com:
- **Username**: `admin`
- **Password**: `admin`

## 🎨 Frontend Showcase

O frontend demonstra todas as features com uma UI moderna:

- **Glassmorphism Design** - Efeitos de vidro fosco
- **Smooth Animations** - Framer Motion
- **Dark Mode** - Gradientes purple/pink
- **Responsive** - Mobile-friendly
- **Real-time Validation** - Feedback visual imediato

### Abas do Dashboard:

1. **GET - Route Binding**
   - Demonstra `[FromRoute]`
   - Endpoint: `GET /api/greet/:name`

2. **POST - Body Validation**
   - Demonstra `[FromBody]` com validação
   - Endpoint: `POST /api/greet/`
   - Valida `[Required]` e `[StringLength]`

3. **GET - Query Binding**
   - Demonstra `[FromQuery]` com nomes customizados
   - Endpoint: `GET /api/greet/search?q=...&limit=...`

## 🔧 Tecnologias

### Backend
- **Delphi 11+** (Alexandria ou superior)
- **Indy** - HTTP Server
- **RTTI** - Reflection para binding dinâmico
- **JWT** - Autenticação

### Frontend
- **React 18** + **TypeScript**
- **Vite** - Build tool
- **Tailwind CSS** - Styling
- **Framer Motion** - Animations
- **Axios** - HTTP Client
- **Lucide React** - Icons

## 📝 Endpoints Disponíveis

### Auth
- `POST /api/auth/login` - Login (retorna JWT)

### Greetings (Protegido)
- `GET /api/greet/:name` - Get greeting by name
- `POST /api/greet/` - Create greeting (validação)
- `GET /api/greet/search` - Search greetings (query params)

## 🧪 Testando

### 1. Teste de Autenticação
```bash
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin"}'
```

### 2. Teste de Route Binding
```bash
curl http://localhost:8080/api/greet/John \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### 3. Teste de Validação
```bash
# Deve retornar 400 (nome muito curto)
curl -X POST http://localhost:8080/api/greet/ \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"Jo","title":"Mr"}'
```

## 🚀 Próximos Passos

- [ ] WebSocket support
- [ ] File upload/download
- [ ] Paginação
- [ ] Rate limiting showcase
- [ ] Response caching showcase
- [ ] OpenAPI/Swagger UI integration
- [ ] GraphQL support

## 📄 Licença

MIT License - Sinta-se livre para usar em seus projetos!

## 🤝 Contribuindo

Contribuições são bem-vindas! Abra uma issue ou PR.

## 📧 Contato

Desenvolvido com ❤️ usando Delphi e React

---

**Dext Framework** - Modern Web Development for Delphi
