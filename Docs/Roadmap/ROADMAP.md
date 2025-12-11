# 🗺️ Project Dext - Roadmap & Status

Bem-vindo ao documento oficial de roadmap do **Project Dext**. Este documento serve como ponto central para acompanhar o progresso do desenvolvimento, entender a visão do projeto e comparar funcionalidades com outros frameworks.

> **Visão:** Criar o "ASP.NET Core para Delphi" — um framework web moderno, modular, de alto desempenho e com uma experiência de desenvolvimento (DX) superior.

---

## 📊 Status Atual do Projeto: **Beta 0.96** 🚀

O framework possui todas as funcionalidades core implementadas e testadas. Estamos na fase final de polimento, documentação e preparação para v1.0.

### 🏆 Comparativo de Funcionalidades

Abaixo, comparamos o Dext com as principais alternativas do mercado Delphi e sua inspiração direta (.NET).

| Funcionalidade | ⚡ Dext | 🐴 Horse | 📦 DMVC | 🔷 ASP.NET Core |
| :--- | :---: | :---: | :---: | :---: |
| **Arquitetura** | Modular (Microsoft.Extensions.* style) | Middleware-based (Express.js style) | MVC Clássico | Modular |
| **Injeção de Dependência** | ✅ **Nativa & First-Class** (Scoped, Transient, Singleton) | ❌ (Requer lib externa) | ⚠️ (Limitada/Externa) | ✅ Nativa |
| **Scoped Services** | ✅ **Por Requisição** (DbContext, UoW) | ❌ | ❌ | ✅ |
| **Minimal APIs** | ✅ `App.MapGet('/route', ...)` | ✅ | ❌ | ✅ |
| **Controllers** | ✅ Suporte completo (Attributes) | ❌ | ✅ | ✅ |
| **Action Filters** | ✅ **Declarativo** (OnExecuting/Executed) | ❌ | ✅ | ✅ |
| **Model Binding** | ✅ **Avançado** (Body, Query, Route, Header, Services) | ⚠️ Básico | ✅ | ✅ |
| **Validation** | ✅ **Automática** (Attributes + Minimal APIs) | ❌ | ✅ | ✅ |
| **Middleware Pipeline** | ✅ Robusto (`UseMiddleware<T>`) | ✅ Simples | ✅ | ✅ |
| **Autenticação/AuthZ** | ✅ **Nativa** (Identity, JWT, Policies) | ⚠️ (Middleware externo) | ✅ | ✅ |
| **OpenAPI / Swagger** | ✅ **Nativo** (Geração automática + Global Responses) | ✅ (Swagger-UI) | ✅ | ✅ |
| **Caching** | ✅ **Nativo** (In-Memory, Response Cache) | ❌ | ❌ | ✅ |
| **Rate Limiting** | ✅ **Avançado** (4 algoritmos, Partition Strategies) | ⚠️ (Middleware externo) | ✅ | ✅ |
| **Static Files** | ✅ Middleware nativo | ❌ | ⚠️ (Manual) | ✅ |
| **Problem Details** | ✅ RFC 7807 | ❌ | ⚠️ | ✅ |
| **HTTP Logging** | ✅ Estruturado | ❌ | ⚠️ | ✅ |
| **CORS** | ✅ Configurável | ⚠️ (Middleware externo) | ✅ | ✅ |
| **Async/Await** | ❌ (Limitação da linguagem*) | ❌ | ❌ | ✅ |

*\* O Dext utiliza Tasks e Futures para operações assíncronas onde possível.*

**Legenda:**
- ✅ = Suporte completo e nativo
- ⚠️ = Suporte parcial ou requer configuração adicional
- ❌ = Não suportado ou requer biblioteca externa

---

## 📅 Roadmap Detalhado para v1.0

### 1. Core & Arquitetura (✅ Concluído)
- [x] **IHost / IWebApplication**: Abstração do ciclo de vida da aplicação.
- [x] **Dependency Injection**: Container IOC completo (Singleton, Scoped, Transient).
- [x] **Activator**: Suporte a Pure DI, Manual, e Hybrid Injection.
- [x] **Configuration**: Sistema de configuração (JSON, Environment Variables).
- [x] **Logging**: Abstração `ILogger` com múltiplos sinks (Console, File).

### 2. HTTP & Routing (✅ Concluído)
- [x] **HttpContext**: Abstração robusta de Request/Response.
- [x] **RemoteIpAddress**: Identificação real do cliente por IP.
- [x] **Routing**: Árvore de rotas eficiente, parâmetros de rota, constraints.
- [x] **Minimal APIs**: Métodos de extensão `MapGet`, `MapPost`, etc.
- [x] **Model Binding**: Binding inteligente de parâmetros (JSON -> Record/Class).
- [x] **Case-Insensitive Binding**: Suporte a binding independente de case.
- [x] **Content Negotiation**: Suporte a JSON nativo (`Dext.Json`).

### 3. Middleware & Pipeline (✅ Concluído)
- [x] **Middleware Factory**: Criação e injeção de middlewares tipados.
- [x] **Singleton Middleware**: Suporte a middlewares com estado persistente.
- [x] **Exception Handling**: Middleware global de tratamento de erros (RFC 7807 Problem Details).
- [x] **HTTP Logging**: Logging estruturado de requisições/respostas.
- [x] **CORS**: Configuração flexível de Cross-Origin Resource Sharing.
- [x] **Static Files**: Servir arquivos estáticos (HTML, CSS, JS, imagens).

### 4. Funcionalidades Avançadas (✅ Concluído)
- [x] **Controllers**: Suporte a Controllers baseados em classes com Atributos (`[HttpGet]`, `[Route]`).
- [x] **Authentication**: Sistema base (`IIdentity`, `IPrincipal`) e JWT Bearer.
- [x] **Caching**: Abstração `IDistributedCache` com implementações Memory e Response Cache.
- [x] **Rate Limiting**: Sistema avançado com 4 algoritmos:
  - [x] Fixed Window (janela fixa)
  - [x] Sliding Window (janela deslizante, mais preciso)
  - [x] Token Bucket (permite bursts controlados)
  - [x] Concurrency Limiter (limite de requisições simultâneas)
- [x] **Partition Strategies**: Múltiplas estratégias de particionamento:
  - [x] Por IP (padrão)
  - [x] Por Header (API Key, Authorization)
  - [x] Por Route
  - [x] Custom (função personalizada)
- [x] **Global Rate Limits**: Proteção de recursos do servidor independente do cliente.
- [x] **Validation**: Integração automática de validação (Attributes) em Controllers e Minimal APIs.
- [x] **Swagger/OpenAPI**: Geração automática de documentação com Global Responses.
- [x] **Action Filters**: Sistema declarativo de filtros:
  - [x] OnActionExecuting / OnActionExecuted
  - [x] Short-circuit support
  - [x] Exception handling em filtros
  - [x] Filtros built-in (LogAction, RequireHeader, ResponseCache, AddHeader)
# 🗺️ Project Dext - Roadmap & Status

Bem-vindo ao documento oficial de roadmap do **Project Dext**. Este documento serve como ponto central para acompanhar o progresso do desenvolvimento, entender a visão do projeto e comparar funcionalidades com outros frameworks.

> **Visão:** Criar o "ASP.NET Core para Delphi" — um framework web moderno, modular, de alto desempenho e com uma experiência de desenvolvimento (DX) superior.

---

## 📊 Status Atual do Projeto: **Beta 0.95** 🚀

O framework possui todas as funcionalidades core implementadas e testadas. Estamos na fase final de polimento, documentação e preparação para v1.0.

### 🏆 Comparativo de Funcionalidades

Abaixo, comparamos o Dext com as principais alternativas do mercado Delphi e sua inspiração direta (.NET).

| Funcionalidade | ⚡ Dext | 🐴 Horse | 📦 DMVC | 🔷 ASP.NET Core |
| :--- | :---: | :---: | :---: | :---: |
| **Arquitetura** | Modular (Microsoft.Extensions.* style) | Middleware-based (Express.js style) | MVC Clássico | Modular |
| **Configuration** | ✅ **Nativa** (JSON, Env) | ⚠️ (Ini/Registry) | ⚠️ (Ini) | ✅ |
| **Injeção de Dependência** | ✅ **Nativa & First-Class** (Scoped, Transient, Singleton) | ❌ (Requer lib externa) | ⚠️ (Limitada/Externa) | ✅ Nativa |
| **Scoped Services** | ✅ **Por Requisição** (DbContext, UoW) | ❌ | ❌ | ✅ |
| **Minimal APIs** | ✅ `App.MapGet('/route', ...)` | ✅ | ❌ | ✅ |
| **Controllers** | ✅ Suporte completo (Attributes) | ❌ | ✅ | ✅ |
| **Action Filters** | ✅ **Declarativo** (OnExecuting/Executed) | ❌ | ✅ | ✅ |
| **Model Binding** | ✅ **Avançado** (Body, Query, Route, Header, Services) | ⚠️ Básico | ✅ | ✅ |
| **Validation** | ✅ **Automática** (Attributes + Minimal APIs) | ❌ | ✅ | ✅ |
| **Middleware Pipeline** | ✅ Robusto (`UseMiddleware<T>`) | ✅ Simples | ✅ | ✅ |
| **Autenticação/AuthZ** | ✅ **Nativa** (Identity, JWT, Policies) | ⚠️ (Middleware externo) | ✅ | ✅ |
| **OpenAPI / Swagger** | ✅ **Nativo** (Geração automática + Global Responses) | ✅ (Swagger-UI) | ✅ | ✅ |
| **Caching** | ✅ **Nativo** (In-Memory, Response Cache) | ❌ | ❌ | ✅ |
| **Rate Limiting** | ✅ **Avançado** (4 algoritmos, Partition Strategies) | ⚠️ (Middleware externo) | ✅ | ✅ |
| **Static Files** | ✅ Middleware nativo | ❌ | ⚠️ (Manual) | ✅ |
| **Problem Details** | ✅ RFC 7807 | ❌ | ⚠️ | ✅ |
| **HTTP Logging** | ✅ Estruturado | ❌ | ⚠️ | ✅ |
| **CORS** | ✅ Configurável | ⚠️ (Middleware externo) | ✅ | ✅ |
| **Async/Await** | ❌ (Limitação da linguagem*) | ❌ | ❌ | ✅ |

*\* O Dext utiliza Tasks e Futures para operações assíncronas onde possível.*

**Legenda:**
- ✅ = Suporte completo e nativo
- ⚠️ = Suporte parcial ou requer configuração adicional
- ❌ = Não suportado ou requer biblioteca externa

---

## 📅 Roadmaps Específicos

O desenvolvimento do Dext é dividido em três grandes áreas. Consulte os roadmaps específicos para detalhes:

### 1. [🌐 Web Framework Roadmap](Docs/WEB_ROADMAP.md)
Foco em APIs, MVC, Views, OpenTelemetry e DX.

### 2. [🗺️ ORM Roadmap](Docs/ORM_ROADMAP.md)
Foco no Dext Entity, banco de dados, performance e queries.

### 3. [🏗️ Infrastructure Roadmap](Docs/INFRA_ROADMAP.md)
Foco em performance extrema (http.sys, epoll), gerenciamento de memória e otimizações de baixo nível.

### 4. [☁️ Cloud & Microservices Roadmap](Docs/CLOUD_ROADMAP.md)
Foco em orquestração (Aspire-like), service discovery, resiliência e componentes distribuídos.

### 5. [🧠 AI Roadmap](Docs/AI_ROADMAP.md)
Foco em GenAI, Semantic Kernel, RAG e integração com LLMs.

### 6. [🛠️ IDE Integration Roadmap](Docs/IDE_ROADMAP.md)
Foco em produtividade, code intelligence, wizards e integração com a IDE do Delphi.

---

## 📅 Roadmap Geral (High Level)

### 1. Core & Arquitetura (✅ Concluído)
- [x] **IHost / IWebApplication**: Abstração do ciclo de vida da aplicação.
- [x] **Dependency Injection**: Container IOC completo (Singleton, Scoped, Transient).
- [x] **Activator**: Suporte a Pure DI, Manual, e Hybrid Injection.
- [x] **Configuration**: Sistema de configuração (JSON, Environment Variables).
- [x] **Logging**: Abstração `ILogger` com múltiplos sinks (Console, File).

### 2. HTTP & Routing (✅ Concluído)
- [x] **HttpContext**: Abstração robusta de Request/Response.
- [x] **RemoteIpAddress**: Identificação real do cliente por IP.
- [x] **Routing**: Árvore de rotas eficiente, parâmetros de rota, constraints.
- [x] **Minimal APIs**: Métodos de extensão `MapGet`, `MapPost`, etc.
- [x] **Model Binding**: Binding inteligente de parâmetros (JSON -> Record/Class).
- [x] **Case-Insensitive Binding**: Suporte a binding independente de case.
- [x] **Content Negotiation**: Suporte a JSON nativo (`Dext.Json`).

### 3. Middleware & Pipeline (✅ Concluído)
- [x] **Middleware Factory**: Criação e injeção de middlewares tipados.
- [x] **Singleton Middleware**: Suporte a middlewares com estado persistente.
- [x] **Exception Handling**: Middleware global de tratamento de erros (RFC 7807 Problem Details).
- [x] **HTTP Logging**: Logging estruturado de requisições/respostas.
- [x] **CORS**: Configuração flexível de Cross-Origin Resource Sharing.
- [x] **Static Files**: Servir arquivos estáticos (HTML, CSS, JS, imagens).

### 4. Funcionalidades Avançadas (✅ Concluído)
- [x] **Controllers**: Suporte a Controllers baseados em classes com Atributos (`[HttpGet]`, `[Route]`).
- [x] **Authentication**: Sistema base (`IIdentity`, `IPrincipal`) e JWT Bearer.
- [x] **Caching**: Abstração `IDistributedCache` com implementações Memory e Response Cache.
- [x] **Rate Limiting**: Sistema avançado com 4 algoritmos:
  - [x] Fixed Window (janela fixa)
  - [x] Sliding Window (janela deslizante, mais preciso)
  - [x] Token Bucket (permite bursts controlados)
  - [x] Concurrency Limiter (limite de requisições simultâneas)
- [x] **Partition Strategies**: Múltiplas estratégias de particionamento:
  - [x] Por IP (padrão)
  - [x] Por Header (API Key, Authorization)
  - [x] Por Route
  - [x] Custom (função personalizada)
- [x] **Global Rate Limits**: Proteção de recursos do servidor independente do cliente.
- [x] **Validation**: Integração automática de validação (Attributes) em Controllers e Minimal APIs.
- [x] **Swagger/OpenAPI**: Geração automática de documentação com Global Responses.
- [x] **Action Filters**: Sistema declarativo de filtros:
  - [x] OnActionExecuting / OnActionExecuted
  - [x] Short-circuit support
  - [x] Exception handling em filtros
  - [x] Filtros built-in (LogAction, RequireHeader, ResponseCache, AddHeader)
  - [x] Controller-level e Method-level filters
- [x] **Health Checks**: Middleware de monitoramento de saúde (`/health`) com suporte a checks customizados.
- [x] **Background Services**: Suporte a `IHostedService` e `TBackgroundService` para tarefas em segundo plano.
- [x] **Options Pattern**: Configuração fortemente tipada via `IOptions<T>`.

### 5. Entity ORM (✅ Alpha 0.6 - Funcional)
- [x] **Basic CRUD**: Operações Create, Read, Update, Delete.
- [x] **Composite Keys**: Suporte a chaves primárias compostas.
- [x] **Fluent API**: Consultas fluentes (`Query()`, `Where()`, `Skip()`, `Take()`).
- [x] **Lazy Loading**: Carregamento tardio com `VirtualInterface` e `ILazy<T>`.
- [x] **Eager Loading**: Carregamento antecipado com `.Include()`.
- [x] **Explicit Loading**: Carregamento manual com `Entry().Reference().Load()`.
- [x] **Naming Strategy**: Estratégias de nomenclatura (SnakeCase, CamelCase, etc.).
- [x] **External Mapping**: Mapeamento fluente externo (`TEntityMap<T>`).
- [x] **Nullable Support**: Suporte completo a `Nullable<T>` para campos opcionais e Foreign Keys.
  - Tipos: `Nullable<Integer>`, `Nullable<String>`, `Nullable<TGUID>`, etc.
  - Compatibilidade: Spring4D e Delphi nativo
  - Funcionalidades: Persist, Hydrate, Foreign Key loading
- [x] **Optimistic Concurrency**: Controle de concorrência via `[Version]`.
- [x] **Database Support**:
  - ✅ **SQLite**: Suporte completo e testado
  - ✅ **PostgreSQL**: Suporte completo e validado (incluindo Nullable)
  - ⚠️ **Firebird**: Próximo na fila para validação completa
- [x] **Database Configuration**: Sistema de configuração para alternar facilmente entre bancos
  - `TDbConfig` helper class
  - Suporte a múltiplos providers
  - Configuração via código ou environment variables
- [ ] **Migrations**: Sistema de migração de schema (planejado para v1.0).

### 6. Ecossistema & Tooling (📅 Planejado para v1.1)
- [ ] **CLI**: Ferramenta de linha de comando (`dext new webapi`).
- [ ] **Templates**: Templates de projeto para Delphi (IDE Wizards).
- [ ] **Web Stencils**: Integração com engine de renderização server-side.
- [ ] **Docker**: Imagens oficiais e exemplos de deploy.
- [ ] **Distributed Cache**: Implementação Redis para `IDistributedCache`.
- [ ] **Distributed Rate Limiting**: Suporte a Redis para Rate Limiting distribuído.

### 7. Documentação & Qualidade (🚧 Em Andamento)
- [x] **Integration Tests**: Testes de integração completos (MinimalAPITest, ControllerExample).
- [x] **Configuration Docs**: Documentação do sistema de configuração.
- [x] **Rate Limiting Docs**: Documentação completa do sistema de Rate Limiting.
- [x] **Action Filters Docs**: Documentação completa do sistema de Action Filters.
- [x] **Scoped Services Docs**: Documentação do Scoped Lifetime.
- [x] **Health Checks Docs**: Documentação de Health Checks.
- [x] **Background Services Docs**: Documentação de Background Services.
- [x] **Options Pattern Docs**: Documentação do padrão Options.
- [x] **Lazy Loading Docs**: Documentação do mecanismo de Lazy Loading.
- [ ] **Unit Tests**: Cobertura abrangente (Core, DI, Http).
- [ ] **Documentation**: Site de documentação oficial (VitePress/Docusaurus).
- [ ] **Samples**: Repositório de exemplos "Real World".

---

## 🎯 Próximos Passos para v1.0

1. **Testes Unitários**: Aumentar cobertura de testes automatizados.
2. **Documentação**: Criar site de documentação oficial.
3. **Performance**: Benchmarks e otimizações.
4. **Estabilidade**: Testes de carga e stress.

---

## 🤝 Como Contribuir

O projeto é Open Source e aceita contribuições!
1.  Faça um Fork do repositório.
2.  Crie uma branch para sua feature (`git checkout -b feature/AmazingFeature`).
3.  Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`).
4.  Push para a branch (`git push origin feature/AmazingFeature`).
5.  Abra um Pull Request.

---

*Última atualização: 02 de Dezembro de 2025*
