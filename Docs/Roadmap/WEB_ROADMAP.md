# 🌐 Dext Web Framework - Roadmap

Este documento foca nas funcionalidades de alto nível do framework web (API, MVC, Views), construído sobre a infraestrutura do Dext.

> **Visão:** Um framework web completo, produtivo e moderno, comparável ao ASP.NET Core e Spring Boot.

---

## 🚀 Funcionalidades Core (Web)

### 0. HTTP Abstractions (Refactoring for Performance) 🔥
Blindagem das interfaces para suportar alta performance (Zero-Copy) no futuro.
- [ ] **Lazy Headers/Query**: `GetHeader(Name)` ao invés de retornar `TDictionary` completo.
- [ ] **Items Bag**: Adicionar `Items: TDictionary<string, TValue>` em `IHttpContext` para comunicação entre Middlewares.
- [ ] **Stream Writing**: Adicionar `Response.Write(TStream)` para suportar envio eficiente de arquivos.
- [ ] **Body Abstraction**: Abstrair o acesso ao Body para suportar `Span<Byte>` futuramente.

### 1. Web API Improvements (Prioridade Alta) 🔥
Melhorias na experiência de construção de APIs robustas e profissionais.
- [x] **Content Negotiation Avançado**: Suporte a múltiplos formatos de saída baseados no header `Accept`.
  - [x] Interfaces: `IOutputFormatter` (JSON, XML, CSV).
  - [x] Implementação padrão JSON (já existente, mas desacoplar).
  - [ ] Suporte a XML (`text/xml`, `application/xml`) -> *Próximo passo.*
- [x] **API Versioning**: Estratégias para versionamento de endpoints.
  - [x] Via URL: `/v1/users` (Route Constraints).
  - [x] Via Query String: `?api-version=1.0`.
  - [x] Via Header: `X-Version: 1.0` ou `Accept` header.
- [ ] **OData Support**: Suporte parcial a queryable APIs (integrado com Dext Entity).
- [ ] **GraphQL Support**: Endpoint `/graphql` nativo com suporte a Queries, Mutations e Subscriptions.
- [ ] **gRPC Support**: Implementação de serviços gRPC de alta performance (Protobuf).

### 2. MVC & Views Engine
Expansão do suporte para aplicações Web completas (Server-Side Rendering).
- [ ] **Views Engine**: Sistema de templates para renderização de HTML no servidor.
  - Sintaxe inspirada em Razor (`@Model.Name`) ou Mustache.
  - Suporte a Layouts e Partials.
- [ ] **MVC Controllers**: Suporte completo ao padrão MVC.
  - `ViewResult`: Retornar views de controllers.
  - `ViewBag`/`ViewData`: Passagem de dados dinâmica.
  - `TagHelpers`: Componentes reutilizáveis em views (ex: `<dext-form>`).

### 3. Observability & Monitoring
Suporte nativo a padrões abertos de monitoramento para produção.
- [ ] **OpenTelemetry Support**: Integração completa com OTel.
  - Rastreamento automático de Requests (Middleware).
  - Propagação de Contexto (W3C Trace Context).
  - Exportadores para Jaeger/Zipkin/OTLP.
- [ ] **Metrics Dashboard**: Endpoint `/metrics` (Prometheus format) nativo.

### 4. Real-Time & Eventing (SignalR-like)
Suporte a comunicação bidirecional em tempo real.
- [ ] **Dext.Hubs**: Abstração de alto nível para WebSockets (similar ao SignalR Hubs).
  - RPC Cliente-Servidor (`Clients.All.SendAsync`).
  - Gerenciamento de Grupos e Conexões.
  - Fallback automático (Long Polling / SSE).
- [ ] **Server-Sent Events (SSE)**: Suporte nativo para streaming de eventos unidirecional.

### 5. UI & Frontend Strategy
Estratégia para construção de interfaces modernas, focando em produtividade e simplicidade (Server-Driven UI).

#### A. Modern Server-Side UI (HTMX)
- [ ] **HTMX Integration**: Suporte nativo a respostas parciais (HTML Fragments) e headers do HTMX (`HX-Trigger`, `HX-Redirect`).
  - Permite criar SPAs (Single Page Apps) sem escrever JavaScript complexo.
- [ ] **UI Components Library**: Biblioteca de componentes web (Bootstrap/Tailwind) encapsulados em classes Delphi.
  - Licença amigável (MIT/Apache), sem dependências de terceiros duvidosas.

#### B. Legacy Bridge (Migration Path)
- [ ] **VCL/FMX Bridge API**: Camada de compatibilidade para expor lógicas de negócio legadas como APIs REST/HTMX.
- [ ] **Form Renderer**: (Experimental) Renderizar Forms VCL simples como HTML para facilitar migração gradual.

#### C. Future: Dext Blazor / WASM
- [ ] **Server-Side Rendering**: Modelo de componentes stateful no servidor (via WebSocket/SignalR), similar ao Blazor Server.
- [ ] **WebAssembly Compiler**: (Long Term) Investigação sobre compilação de Delphi para WASM para rodar lógica no cliente.

---

### 6. Security & Identity
Modernização da stack de autenticação para padrões de mercado (OAuth2/OIDC).

#### A. Authentication Handlers
- [ ] **OAuth2 & OpenID Connect (OIDC)**: Client genérico para autenticação com qualquer provedor compatível (Auth0, Keycloak, Azure AD).
- [ ] **Social Providers**: Configurações pré-definidas para Google, Facebook, GitHub, Microsoft.
- [ ] **Enterprise SSO**: Suporte a Single Sign-On via SAML 2.0 ou OIDC para integração corporativa.

#### B. Authorization & Policy
- [ ] **Policy-Based Authorization**: Sistema flexível de políticas (`[Authorize('MustBeAdmin')]`) além de simples Roles.
- [ ] **Resource-Based Auth**: Autorização baseada no recurso sendo acessado (ex: "Usuário pode editar ESTE documento?").

---

## 📅 Roadmap de Integração

### Fase 1: Fundação (Infraestrutura)
*Depende de:* [INFRA_ROADMAP.md](INFRA_ROADMAP.md)
- [ ] Migrar para o novo servidor HTTP de alta performance (http.sys/epoll).
- [ ] Adotar `RawUTF8` no pipeline de processamento de requisições.

### Fase 2: Ecosystem
- [ ] **Dext.Identity**: Sistema de identidade completo (Users, Roles, Claims, OAuth2/OIDC).
- [ ] **Dext.Blazor**: (Futuro) Componentes UI server-side ou integração com WebAssembly.
