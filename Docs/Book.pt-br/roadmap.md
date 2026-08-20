# 🗺️ Dext Framework - Roadmap & Status

Bem-vindo ao roadmap oficial do **Dext Framework**. Este documento centraliza o progresso do desenvolvimento, a visão do projeto e o comparativo com o ecossistema Delphi e .NET.

> **Visão:** Criar o "ASP.NET Core para Delphi" — um framework web modular, de alto desempenho e com uma experiência de desenvolvimento (DX) superior.

---

## 🏎️ Comparativo de Funcionalidades

Dext foi desenhado para preencher as lacunas de arquitetura no ecossistema Delphi, trazendo padrões modernos de injeção de dependência e desacoplamento.

| Funcionalidade | ⚡ Dext | 🐴 Horse | 📦 DMVC | 🔷 ASP.NET Core |
| :--- | :---: | :---: | :---: | :---: |
| **Arquitetura** | Modular (.NET style) | Middleware-based | MVC Clássico | Modular |
| **Real-Time (Hubs)** | ✅ Nativo | ⚠️ Externo | ❌ | ✅ (SignalR) |
| **DI First-Class** | ✅ Nativo (Scoped) | ❌ | ⚠️ Limitado | ✅ Nativa |
| **Minimal APIs** | ✅ | ✅ | ❌ | ✅ |
| **Model Binding** | ✅ Avançado | ⚠️ Básico | ✅ | ✅ |
| **OpenAPI / Swagger** | ✅ Nativo | ✅ | ✅ | ✅ |
| **Rate Limiting** | ✅ Avançado | ⚠️ Externo | ✅ | ✅ |
| **Problem Details** | ✅ RFC 7807 | ❌ | ⚠️ | ✅ |

---

## 🚀 Status de Implementação (Fase 1: RC 1.0)

O Dext Framework alcançou maturidade de produção em seu núcleo (Core), Web e Data. Abaixo, o detalhamento técnico das funcionalidades validadas:

### 🧩 Dext.Core & Foundation (Concluído)
- [x] **Injeção de Dependência**: Suporte a ARC/Não-ARC, ciclos de vida (Singleton, Transient, Scoped) e Auto-Collections.
- [x] **Smart Reflection**: Metadata Engine com cache global e resolução recursiva de propriedades.
- [x] **Performance Engine**: Serialização JSON de alta velocidade (Utf8) e `Dext.Core.Span` para zero-allocation.
- [x] **Configuração Hierárquica**: Suporte a JSON, YAML, EnvVars e Options Pattern (`IOptions<T>`).
- [x] **Tipos Modernos**: Suporte nativo a **UUID v7**, Nullable<T> e Smart Enums.
- [x] **Async/Await**: Implementação fluente via `TAsyncTask` com suporte a `CancellationToken`.

### 📚 Dext.Collections (Concluído)
- [x] **Estruturas Modernas**: List, Dictionary e HashSet otimizados; versões Concurrent (thread-safe).
- [x] **Frozen Collections**: Estruturas imutáveis de alta performance otimizadas para leitura (.NET 8 style).
- [x] **Channels**: Primitivas de comunicação assíncrona Producer/Consumer (Go-style pipelines).
- [x] **Aceleração Hardware**: Processamento em lote via **SIMD & Vectors** (AVX/SSE).

### 🌐 Dext.Web Framework (Concluído)
- [x] **Minimal API & Bootstrapping**: Inicialização fluente de middleware pipeline e serviços.
- [x] **Roteamento Avançado**: Parâmetros dinâmicos, restrições e versionamento nativo (Header, Query, Path).
- [x] **Model Binding Híbrido**: Vinculação inteligente de Body, Query, Route, Header e Services.
- [x] **Real-time & Hubs**: Suporte a **SSE (Server-Sent Events)** e Hubs inspirados no SignalR.
- [x] **Middleware Nativo**: ProblemDetails (RFC 7807), Compression (GZip), CORS e Rate Limiting.
- [x] **Zero-Leak Management**: Tracking de ciclo de vida de objetos integrado ao ChangeTracker do ORM.

### 🗄️ Dext.Entity ORM (Concluído)
- [x] **Unit of Work & Repository**: `TDbContext` e `DbSet<T>` com Change Tracking automático.
- [x] **Query Engine**: Consultas fluídas com suporte a Join, GroupBy, Paging e Aggregates.
- [x] **Relacionamentos**: Suporte total a 1:1, 1:N e N:M com Lazy & Eager Loading (`Include`).
- [x] **Poliglotismo**: Dialetos estáveis para PostgreSQL, SQL Server, MySQL, SQLite, Oracle e Firebird.
- [x] **Migrations System**: Versão Code-First automatizada para evolução de schema.
- [x] **EntityDataSet**: Componente VCL/FMX com suporte a Design-Time Data Preview.

### 🔌 Dext.Net & Testing (Concluído)
- [x] **Fluent REST Client**: Connection Pooling, Retry automático e OAuth 2.0 (Client Credentials).
- [x] **Testing Engine**: Mocking dinâmico via Proxies, Fluent Assertions e Snapshot Testing.
- [x] **Dext CLI**: Dashboard UI Web, executor de testes de alta velocidade e integração TestInsight.

---

## 📅 Roadmaps Detalhados

Para acompanhamento granular de cada frente de trabalho, consulte os roteiros específicos:

- [🌐 Web Framework](roadmap/web.md)
- [🗺️ ORM & Data](roadmap/orm.md)
- [🏗️ Infra & CLI](roadmap/infrastructure.md)
- [🧠 AI & Futuro](roadmap/ai-future.md)
- [🛠️ Integração IDE](roadmap/ide-integration.md)
- [☁️ Cloud Native](roadmap/cloud-native.md)
- [🖥️ Desktop UI](roadmap/desktop-ui.md)
- [📋 **Tarefas Pendentes (V1.0 Backlog)**](roadmap/tarefas-pendentes.md) ⭐ NOVO

---

## 🎯 Próximos Passos (v1.1+)

1. **Performance**: Otimizações de baixo nível no pipeline de middlewares (Zero-allocation targets).
2. **Dext AI**: Orquestração de LLMs e Semantic Kernel para Delphi.
3. **Cloud Native**: Adaptadores para AWS Lambda e Azure Functions.
4. **Desktop MVU**: Evolução do módulo Dext.UI para arquitetura reativa.

---

[← Guia de Depuração Avançada](apendice/debug-avancado.md) | [Voltar ao Início](README.md)
