# 🚀 Dext Framework - V1.0 Beta Plan

Este documento consolida o plano de trabalho para a fase **Beta V1.0**. O objetivo é garantir que todas as funcionalidades implementadas estejam documentadas, testadas e prontas para uso em produção.

> ⚠️ **Documento em Construção**: Este roteiro está sendo atualizado ativamente. Estamos realizando uma auditoria completa no código-fonte e descobrindo funcionalidades já implementadas que não estavam documentadas. Novas features podem ser adicionadas ou movidas de categoria a qualquer momento.

### 🗺️ Roadmaps Detalhados (Spec & Tracking)
Para detalhes técnicos e status granular de cada módulo, consulte:
- [**Web Framework Roadmap**](../Roadmap/web-roadmap.md) (Abstrações HTTP, MVC, SignalR)
- [**ORM Roadmap**](../Roadmap/orm-roadmap.md) (Dialetos, Type System, Performance)
- [**Infra & CLI Roadmap**](../Roadmap/infra-roadmap.md) (Hosting, DI, Logging)

---

## 📋 1. Inventário de Funcionalidades (Feature Set)

### 🌐 Dext.Web
| Feature | Status | Notas |
|---------|--------|-------|
| **Minimal APIs** (`MapGet`, `MapPost`) | ✅ Pronto | Testado em `Dext.Starter.Admin` |
| **Controllers** (`TController`) | ✅ Pronto | Testado em `Web.ControllerExample` |
| **Model Binding** (JSON Body -> Record/Class) | ✅ Pronto | Suporte a aninhamento e listas |
| **Dependency Injection** (Scoped/Singleton/Transient) | ✅ Pronto | Integração total com HttpContext |
| **Middleware Pipeline** | ✅ Pronto | Custom Middlewares suportados |
| **Static Files** | ✅ Pronto | Suporte a MIME types e cache |
| **Cookies** | ✅ Pronto | Leitura/Escrita com opções de segurança |
| **Multipart/Form-Data** | ✅ Pronto | Upload de arquivos via `IFormFile` |
| **Response Compression** | ✅ Pronto | GZip nativo |
| **HTTPS/SSL** | ✅ Pronto | Suporte OpenSSL 1.1 e 3.0 |
| **CORS** | ✅ Pronto | Middleware com Policy Builder |
| **Rate Limiting** | ✅ Pronto | Token Bucket & Fixed Window |
| **Health Checks** | ✅ Pronto | Endpoint `/health` extensível |
| **API Versioning** | ✅ Pronto | Via URL, Header ou Query String |
| **OpenAPI / Swagger** | ✅ Pronto | Geração automática de documentação |
| **Stream Responses** | ✅ Pronto | `Response.Write(TStream)` |
| **Response Caching** | ✅ Pronto | `[ResponseCache]` header control |
| **Filters Pipeline** | ✅ Pronto | Action & Result Filters (`LogAction`, `RequireHeader`) |
| **JWT Authentication** | ✅ Pronto | Geração e Validação de Tokens (HS256) |
| **Validation** | ✅ Pronto | Library de validação com Atributos (`[Required]`, `[Email]`) |
| **Options Pattern** | ✅ Pronto | Binding de configuração para classes (`IOptions<T>`) |

### 🛠️ Dext.Web Middlewares (Built-in)
| Middleware | Classe | Função |
|------------|--------|--------|
| **Exception Handler** | `TExceptionHandlerMiddleware` | Captura exceções globais e retorna JSON/ProblemDetails ou página de erro. |
| **HTTP Logging** | `THttpLoggingMiddleware` | Loga requisições, respostas, headers e body (configurável). |
| **CORS** | `TCorsMiddleware` | Gerencia Cross-Origin Resource Sharing com policies flexíveis. |
| **Rate Limiting** | `TRateLimitMiddleware` | Limita requisições por IP, rota ou chave customizada (Token Bucket, Fixed Window). |
| **Static Files** | `TStaticFileMiddleware` | Serve arquivos estáticos com negociação de MIME types. |
| **Multi-Tenancy** | `TMultiTenancyMiddleware` | Resolve o Tenant atual e popula o contexto. |
| **Startup Lock** | `TStartupLockMiddleware` | Retorna 503 se a aplicação estiver em estado de inicialização/migração. |
| **Compression** | `TCompressionMiddleware` | Comprime respostas (GZip) se suportado pelo cliente. |

### 🗄️ Dext.Entity (ORM)
| Feature | Status | Notas |
|---------|--------|-------|
| **CRUD Operations** (Add, Update, Remove, Find) | ✅ Pronto | Básico funcional |
| **Fluent Query API** (`Where`, `OrderBy`, `Take`) | ✅ Pronto | Tradução SQL robusta |
| **Relationships** (1:1, 1:N) | ✅ Pronto | `Include` (Eager Loading) funcional |
| **Attributes Mapping** (`[Table]`, `[Column]`) | ✅ Pronto | |
| **Migrations** (CLI & Runtime) | ✅ Pronto | `migrate:up`, `down`, `generate` |
| **Multi-Tenancy** | ✅ Pronto | Schema-based, DB-based, Column-based |
| **Advanced Types** (UUID, JSON, Arrays) | ✅ Pronto | Serialização automática |
| **Bulk Operations** | ✅ Pronto | Update/Delete em massa |
| **Advanced Querying** | 🟡 Parcial | `Join` e `GroupBy` (In-Memory ✅, SQL Pending ⚠️) |
| **Inheritance Mapping** (TPH) | ✅ Pronto | Discriminator column suportado |
| **Lazy Loading** | ✅ Pronto | `Lazy<T>`, `IList<T>` e `ILazy<T>` wrapper |
| **Scaffolding** (DB First) | ✅ Pronto | Geração de Entities via Schema do Banco |
| **Soft Delete** | ✅ Pronto | Atributo `[SoftDelete]` |
| **Optimistic Concurrency** | ✅ Pronto | Atributo `[Version]` |


### ⚙️ Infraestrutura & CLI
| Feature | Status | Notas |
|---------|--------|-------|
| **CLI Tool** (`dext.exe`) | ✅ Pronto | Gerenciamento de migrations |
| **Async Tasks** (`TAsyncTask`) | ✅ Pronto | Primitivas modernas de concorrência |
| **Logging** (`ILogger`) | ✅ Pronto | Abstração de log |
| **Configuration** (`IConfiguration`) | ✅ Pronto | JSON file provider |

### 🔄 Hosting & Lifecycle
| Feature | Status | Notas |
|---------|--------|-------|
| **Application State** (`IAppStateObserver`) | ✅ Pronto | Estados: Starting, Seeding, Running, Stopping |
| **Graceful Shutdown** (`IHostApplicationLifetime`) | ✅ Pronto | Tokens para `Started`, `Stopping`, `Stopped` |
| **Background Services** (`IHostedService`) | ✅ Pronto | Tarefas assíncronas em background com DI |
| **Startup Lock** (`TStartupLockMiddleware`) | ✅ Pronto | Bloqueia requests com 503 durante o boot |

---

## 📚 2. Plano de Documentação e Exemplos

O foco agora é criar **um exemplo para cada funcionalidade** e unificar a documentação.

### Documentação
- [ ] **Criar "The Dext Book"**: Um único arquivo Markdown (ou Wiki) compilando todos os guias (similar ao manual do Laravel/Django).
- [ ] **API Reference**: Gerar documentação automática do código (PasDoc ou similar) se possível, ou focar em guias práticos.

### Novos Exemplos Necessários
1.  **Dext.Examples.Streaming**: Demonstrar download e upload de arquivos grandes (Stream Writing + Multipart).
2.  **Dext.Examples.MultiTenancy**: Demonstrar implementação completa de SaaS (Schema por Tenant).
3.  **Dext.Examples.ComplexQuerying**: Demonstrar queries avançadas do ORM com JSON, Arrays e relatórios.

### Atualização de Exemplos Existentes
- [ ] Atualizar `Web.TaskFlowAPI` para usar os novos recursos de Cookies e Compression.
- [ ] Revisar `Dext.Starter.Admin` para garantir uso das melhores práticas atuais.

---

## 🛠️ 3. Qualidade de Código & Manutenção

- [ ] **Otimização de Generics**: Revisar uso intensivo de Generics para evitar "code bloat" e melhorar tempo de compilação.
- [ ] **Code Review Geral**: Revisão focada em consistência, vazamento de memória e exceções não tratadas.
- [ ] **Formatação & Estilo**: Padronizar alinhamento e formatação (Object Pascal Style Guide).
- [ ] **Guia do Agente (Agent Guidelines)**: Criar documentação técnica (`.agent/rules.md` ou `CONTRIBUTING_AI.md`) detalhando padrões de projeto, regras de arquitetura e instruções para configurar/orientar agentes de IA no desenvolvimento do Dext.

---

## 🧪 4. Estratégia de Testes

### Matriz de Suporte a Bancos de Dados
Implementar testes de integração rodando a suite de testes do ORM contra containers Docker de cada banco.

| Banco de Dados | Dialeto Implementado? | Testes Automatizados? | Status |
|----------------|-----------------------|-----------------------|--------|
| **SQLite** | ✅ Sim | ✅ Sim | 🟢 Estável |
| **PostgreSQL** | ✅ Sim | ✅ Sim | 🟢 Estável |
| **SQL Server** | ✅ Sim | ✅ Sim | 🟢 Estável |
| **Firebird** | ✅ Sim | ✅ Sim | 🟢 Estável |
| **MySQL / MariaDB** | ✅ Sim | ❌ Não (Manual) | 🟡 Beta (Precisa de Validação) |
| **Oracle** | ✅ Sim | ❌ Não (Manual) | 🟡 Beta (Precisa de Validação) |
| **InterBase** | ✅ Sim | ❌ Não (Manual) | 🟡 Beta (Precisa de Validação) |

> **Ação Imediata**: Criar `Docker-Compose` environment para subir todos os bancos e script de teste unificado.

### Plano de Testes de Web
- [ ] Criar testes de integração HTTP (rodar servidor real e fazer requests reais) para validar:
    - Cookies persistência/leitura.
    - Upload de arquivos binários.
    - Compressão (verificar Content-Encoding header).
    - Concorrência (Apache Bench / k6).

---

## 🚀 5. Benchmarks

Estabelecer uma baseline de performance para a V1.

1.  **Web Framework (Requests/sec)**:
    -   Hello World (Plain Text).
    -   JSON Serialization (Objeto pequeno e grande).
    -   DB Read (1 query simples).
    -   *Ferramenta*: `wrk` ou `k6`.
    -   *Comparativo*: vs DataSnap, vs Horse (se aplicável), vs ASP.NET Core (como referência de alvo).

2.  **ORM (Op/sec)**:
    -   Bulk Insert (10k registros).
    -   Select com Hydration (10k registros).
    -   *Comparativo*: vs FireDAC puro.

---

## 🔮 6. Roadmap Futuro (Pós-V1)

Funcionalidades movidas para v1.1 ou v2.0:
- **WebSockets**: Suporte nativo para comunicação bidirecional em tempo real (necessário para Dext Forum).
- **Server-Sent Events (SSE)**: Alternativa leve a WebSockets para pushes unidirecionais.
- **Background Jobs/Queues**: Sistema de filas para processamento assíncrono robusto (integração Redis/RabbitMQ).
- **Scheduled Jobs (CRON)**: Agendamento de tarefas recorrentes (ex: relatórios diários, limpeza de dados).

- **Docker Tooling**: Templates de `Dockerfile` e comando `dext docker init` para facilitar o deployment. (Prioritário)
- **Telemetry & Observability**: Suporte a OpenTelemetry (Tracing/Metrics) e dashboards nativos.
- **Testing Ecosystem**: Framework `Dext.Mock` e Fluent Assertions (`Expect(X).Should.Be(Y)`).
- **Advanced Resilience**: Patterns de Retry, Circuit Breaker e Timeout na Async API.
- **Immutable Data Structures**: `ImmutableList<T>`, `ImmutableDictionary<K,V>` e `Nullable<T>` (ReadOnly) para concorrência segura (Scalability).
- **Kestrel NativeAOT**: Driver de alta performance via ponte com .NET (Experimental).
- **View Engine**: Integração com **WebStencils** (novo engine do Delphi) ou criação de sintaxe Razor-like.
- **Server Adapters**: Suportar deployment em **WebBroker** (ISAPI/Apache/IIS) além do Indy.
- **Native Integration**: Explorar integração opcional com **LiveBindings** para cenários RAD e adapters para **DataSnap**.
- **JSON Columns (JSONB Support)**: Implementação do suporte real no ORM para o atributo `[JsonColumn]`.
- **Suporte a NoSQL** (MongoDB no ORM).
- **Distributed Caching** (Redis implementation - Em Progresso).


