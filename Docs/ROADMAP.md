# 🗺️ Dext Framework: Master Roadmap

This is the centralized roadmap for the Dext Framework. It tracks the progress of core features, architectural specifications, and the path to the V1.0 Stable release.

> [!TIP]
> This document is the Single Source of Truth for project status. Individual language-specific guides in the Book point here.

---

# 🇬🇧 English: Roadmap & Backlog

## 🟢 Wave 1: Quick Wins & Visibility (Immediate)
Status | Task | Spec | Description
:---: | :--- | :---: | :---
✅ | **Dynamic Port Binding** | [S08](Specs/S08-Dynamic-Ports.md) | Support for Port 0 (OS chooses free port) for Demos and CI.
✅ | **DataAPI Conventions** | [S04](Specs/S04-DataApi-Conventions.md) | Auto-discovery, 'T' prefix stripping, and Smart Attributes.
✅ | **DataAPI Observability** | - | CRUD diagnostic logs and mapping tracking.
🟡 | **Examples Roadmap** | [Ref](roadmap/EXAMPLES_ROADMAP.md) | Create high-fidelity examples for existing features.
🟡 | **Agent Guidelines** | [AI](CONTRIBUTING_AI.md) | Finalize `CONTRIBUTING_AI.md` and related Workflows.

## 🔵 Wave 2: Performance & Productivity (Foundation)
Status | Task | Spec | Description
:---: | :--- | :---: | :---
✅ | **High-Perf Reflection** | [S07](Specs/S07-High-Perf-Reflection.md) | Thread-safe RTTI cache with lock-free fast paths, zero-boxing type handlers, and ISO 8601 date binding.
✅ | **Advanced Scaffolding** | [S01](Specs/S01-Advanced-Scaffolding.md) | New CLI template engine (`dext new`, `dext add`).
✅ | **Template Engine** | [S09](Specs/S09-Template-Engine.md) | Zero-dependency AST-based template engine (Razor-like).
✅ | **Advanced Template Engine** | [S12](Specs/S12-Template-Engine-Advanced.md) | Phases 1-6 complete: layouts, partials, inheritance, AST cache, smart positions, @encoded, and high-performance TDataSet/Streaming iterators.
✅ | **Schema Migrations** | [S11](Specs/S11-Migration-Finalization.md) | Attribute-based renaming detection and CLI automation.
✅ | **Prop & Nullable Convergence** | [S22](Specs/S22-Prop-Nullable-Convergence.md) | Interoperability between Smart Properties and Nullable values via composition.
✅ | **DbContext Auto-Hydration** | [S30](Specs/S30-DbContext-AutoHydration.md) | Eliminate generic IDbSet boilerplate getters.
✅ | **Fluent Validation API** | [S31](Specs/S31-Validation.md) | Strong-typed fluent validation engine integrated with Prop<T> and Web model binding.
✅ | **Resilience Pipeline** | [S32](Specs/S32-Resilience-Pipeline.md) | Polly-style transient-fault handling (Retry, Circuit Breaker, Fallback, Timeout) for generic I/O.
✅ | **Persistent Background Jobs** | [S33](Specs/S33-Background-Jobs.md) | Out-of-process scheduled/recurring background tasks with database/SQLite/InMemory persistence.
✅ | **Dynamic Query Filters** | [S34](Specs/S34-Dynamic-Query-Filters.md) | Bypassing global query filters (soft-delete, multi-tenancy) dynamically via `IgnoreQueryFilters`.
✅ | **Soft Delete Evolution** | [S21](Specs/S21-SoftDelete-Timestamp-Audit.md) | Soft Delete based on nullable timestamps for audit trails.
✅ | **Database Sequences & HiLo** | [S46](Specs/S46-Sequence-Generators.md) | Database sequences and thread-safe HiLo pre-allocation registry for client-side ID assignment, unlocking high-performance bulk inserts.
✅ | **FluentQuery Join Evolution**| [S19](Specs/S19-FluentQuery-Join-Evolution.md) | Unified strongly-typed fluent SQL joins (Inner, Left, Right, Full, Cross).
✅ | **Fluent REST Evolution** | [S20](Specs/S20-Fluent-Rest-Evolution.md) | Enhanced TRestClient factories and native record/array payload support.
✅ | **Native Delphi IDE Test Runner** | [S36](Specs/S36-IDE-Test-Runner.md) | Native IDE Test Runner expert with decoupled DUnitX, DUnit, DUnit2, and TestInsight integrations and rich reporting.
🟡 | **Dext IDE Explorer** | [S05](Specs/S05-Advanced-Tooling.md) | Initial visual tool for Migrations inside the IDE (Only TFDConnection scaffolding implemented).
🔴 | **Dext Studio (Expert)**| [S15](Specs/S15-Dext-Studio-IDE-Expert.md) | Visual IDE Expert for schema mapping and continuous syncing via YAML.
🟡 | **Production Middleware** | - | SPA Fallback, Forwarded Headers, and Resilience.

## 🔴 Wave 3: Enterprise & Modernization (Stability)
Status | Task | Spec | Description
:---: | :--- | :---: | :---
🟡 | **gRPC & Protobuf** | [S02](Specs/S02-Modernizer-gRPC.md) | Code-first Protobuf services and TEntityDataSet/TEntitygRpcProvider integration.
✅ | **Native Server Engine** | [S39](Specs/S39-Native-Server-Engine.md) | 100% Pascal High-performance server engine (http.sys, epoll sockets).
✅ | **WebSocket & SignalR** | [S40](Specs/S40-WebSocket-SignalR.md) | RFC 6455 protocol codec and SignalR-compatible Hub transport integration.
✅ | **HTTP/2 Framing** | [S41](Specs/S41-Http2-Framing.md) | HTTP/2 HPACK compression, frame codec, and stream multiplexing for gRPC.
🟡 | **OAuth2 & OIDC** | [S06](Specs/S06-Security-Identity.md) | Native support for JWT, Google, and Microsoft Login.
✅ | **Live Tracing (Core)** | [S03](Specs/S03-Live-Observability.md) | Real-time instrumentation infrastructure (TDiagnosticSource).
🟡 | **Observability Dashboard**| - | Built-in web UI for real-time log and SQL visualization.
🔴 | **EntityDataSet Providers** | - | Pluggable providers (REST/gRPC) for EntityDataSet.
🔴 | **Redis Client (Dext.Redis)** | [S13](Specs/S13-Redis-Client.md) | High-performance async Redis client with RESP3 and RedisJSON support.
🟡 | **SOA via Interfaces** | [S14](Specs/S14-SOA-Interfaces.md) | Transparent Code-First gRPC mapping for Delphi Interfaces.
✅ | **APM & Telemetry Sinks** | [S35](Specs/S35-APM-Log-Sinks.md) | Asynchronous batch-oriented telemetry sinks targeting Seq and OpenTelemetry (OTLP) collectors.
✅ | **Indy HTTP Fallback** | [S37](Specs/S37-Http-Engine-Indy-Fallback.md) | Abstract HTTP Client layer to support Indy fallback on older Delphi versions.
✅ | **Delphi Hub Client** | [S42](Specs/S42-Delphi-Hub-Client.md) | Native Delphi client connection library for Dext Hubs (WebSocket/SSE).

## 🔮 Future / Post-V1
- [ ] **OData Support**: Full OData query support.
- [ ] **GraphQL**: Native layer for data graphs.
- [ ] **Microservices Mesh**: Service discovery and native Load Balancing.

---

# 🇧🇷 Português: Roadmap & Backlog

## 🟢 Onda 1: Quick Wins & Visibilidade (Imediato)
Status | Tarefa | Spec | Descrição
:---: | :--- | :---: | :---
✅ | **Portas Dinâmicas** | [S08](Specs/S08-Dynamic-Ports.md) | Suporte a Porta 0 (SO escolhe porta livre) para Demos e CI.
✅ | **Convenções DataAPI** | [S04](Specs/S04-DataApi-Conventions.md) | Auto-discovery, remover prefixo 'T' e Smart Attributes.
✅ | **Observabilidade DataAPI** | - | Logs de diagnóstico CRUD e rastreamento de mapeamento.
🟡 | **Roadmap de Exemplos** | [Ref](roadmap/EXAMPLES_ROADMAP.md) | Criar exemplos de alta fidelidade para features existentes.
🟡 | **Agent Guidelines** | [AI](CONTRIBUTING_AI.md) | Finalizar o `CONTRIBUTING_AI.md` e Workflows.

## 🔵 Onda 2: Performance & Produtividade (Fundação)
Status | Tarefa | Spec | Descrição
:---: | :--- | :---: | :---
✅ | **High-Perf Reflection** | [S07](Specs/S07-High-Perf-Reflection.md) | Cache de RTTI thread-safe com fast paths lock-free, handlers sem boxing e binding ISO 8601.
✅ | **Scaffolding Avançado** | [S01](Specs/S01-Advanced-Scaffolding.md) | Novo motor de templates CLI (`dext new`, `dext add`).
✅ | **Motor de Templates** | [S09](Specs/S09-Template-Engine.md) | Motor de templates baseado em AST, zero dependência (estilo Razor).
✅ | **Motor de Templates Avançado** | [S12](Specs/S12-Template-Engine-Advanced.md) | Fases 1-6 completas: layouts, partials, herança, cache de AST, posições inteligentes, @encoded e iteradores TDataSet/Streaming de alta performance.
✅ | **Migrations de Schema** | [S11](Specs/S11-Migration-Finalization.md) | Detecção de renomeação por atributos e automação CLI.
✅ | **Convergência Prop/Nullable** | [S22](Specs/S22-Prop-Nullable-Convergence.md) | Interoperabilidade entre Smart Properties e valores Nullable via composição.
✅ | **Auto-Hidratação de DbContext** | [S30](Specs/S30-DbContext-AutoHydration.md) | Eliminar boilerplate getters de IDbSet genéricos.
✅ | **API de Validação Fluent** | [S31](Specs/S31-Validation.md) | Motor de validação fluente fortemente tipado com suporte a Prop<T> e model binding Web.
✅ | **Resilience Pipeline** | [S32](Specs/S32-Resilience-Pipeline.md) | Tratamento de falhas estilo Polly (Retry, Circuit Breaker, Fallback, Timeout) genérico para I/O.
✅ | **Persistent Background Jobs** | [S33](Specs/S33-Background-Jobs.md) | Processamento de tarefas em background agendadas/recorrentes fora do processo com persistência em BD/SQLite/InMemory.
✅ | **Filtros Dinâmicos de Query** | [S34](Specs/S34-Dynamic-Query-Filters.md) | Bypass dinâmico de filtros globais de query (soft-delete, multi-tenancy) via `IgnoreQueryFilters`.
✅ | **Evolução do Soft Delete** | [S21](Specs/S21-SoftDelete-Timestamp-Audit.md) | Soft Delete baseado em timestamps anuláveis para trilhas de auditoria.
✅ | **Database Sequences & HiLo** | [S46](Specs/S46-Sequence-Generators.md) | Mapeamento de sequences e pré-alocador HiLo thread-safe para geração de IDs no cliente, desbloqueando inserções em lote (bulk).
✅ | **Evolução de Joins FluentQuery**| [S19](Specs/S19-FluentQuery-Join-Evolution.md) | Joins fluentes e fortemente tipados unificados (Inner, Left, Right, Full, Cross).
✅ | **Evolução REST Fluente** | [S20](Specs/S20-Fluent-Rest-Evolution.md) | Factories aprimoradas para TRestClient e suporte nativo a records/arrays.
✅ | **Test Runner Nativo na IDE** | [S36](Specs/S36-IDE-Test-Runner.md) | Plugin Expert nativo de Test Runner na IDE com integração DUnitX, DUnit, DUnit2 e TestInsight desacoplada e relatórios ricos.
🟡 | **Dext IDE Explorer** | [S05](Specs/S05-Advanced-Tooling.md) | Ferramenta visual inicial para Migrations na IDE (Somente scaffolding de TFDConnection implementado).
🔴 | **Dext Studio (Expert)**| [S15](Specs/S15-Dext-Studio-IDE-Expert.md) | Expert visual na IDE para mapeamento de schema e sync contínuo via YAML.
🟡 | **Middleware Pack** | - | SPA Fallback, Forwarded Headers e Resiliência.

## 🔴 Onda 3: Enterprise & Modernização (Estabilidade)
Status | Tarefa | Spec | Descrição
:---: | :--- | :---: | :---
🟡 | **gRPC & Protobuf** | [S02](Specs/S02-Modernizer-gRPC.md) | Motor nativo IOCP/EPOLL para comunicação binária.
✅ | **Motor de Servidor Nativo** | [S39](Specs/S39-Native-Server-Engine.md) | Motor de servidor de alta performance 100% Pascal (http.sys, epoll sockets).
✅ | **WebSocket & SignalR** | [S40](Specs/S40-WebSocket-SignalR.md) | Codec do protocolo RFC 6455 e integração do transporte de Hub compatível com SignalR.
✅ | **HTTP/2 Framing** | [S41](Specs/S41-Http2-Framing.md) | Compressão HPACK HTTP/2, codec de frames e multiplexação de streams para gRPC.
🟡 | **OAuth2 & OIDC** | [S06](Specs/S06-Security-Identity.md) | Suporte nativo a JWT, Google/Microsoft Login.
✅ | **Live Tracing (Core)** | [S03](Specs/S03-Live-Observability.md) | Infraestrutura de instrumentação em tempo real.
🟡 | **Dashboard Log Live** | - | Interface web para visualização de logs e SQL em tempo real.
🔴 | **Provider de EntityDataSet** | - | Providers plugáveis (REST/gRPC) para o EntityDataSet.
🔴 | **Redis Client (Dext.Redis)** | [S13](Specs/S13-Redis-Client.md) | Client Redis async de alta performance com suporte a RESP3 e RedisJSON.
🟡 | **SOA via Interfaces** | [S14](Specs/S14-SOA-Interfaces.md) | SOA e RPC via gRPC Code-First transparente para interfaces Delphi.
✅ | **APM & Telemetry Sinks** | [S35](Specs/S35-APM-Log-Sinks.md) | Envio assíncrono em lotes de telemetria e logs para Seq e coletores OpenTelemetry (OTLP).
✅ | **Indy HTTP Fallback** | [S37](Specs/S37-Http-Engine-Indy-Fallback.md) | Abstração do cliente HTTP para suporte a fallback com Indy em versões antigas.
✅ | **Cliente Hub Delphi** | [S42](Specs/S42-Delphi-Hub-Client.md) | Biblioteca cliente nativa em Delphi para conexão com Dext Hubs (WebSocket/SSE).

## 🔮 Futuro / Pós-V1
- [ ] **Suporte a OData**: Suporte completo a queries OData.
- [ ] **GraphQL**: Camada nativa para exposição de grafos de dados.
- [ ] **Microservices Mesh**: Service discovery e Load Balancing nativo.

- UI Nativo com Skia

---
*Last update: June 2026*
