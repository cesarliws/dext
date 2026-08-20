# 🗺️ Dext Framework - Roadmap & Status

Welcome to the official **Dext Framework** roadmap. This document centralizes development progress, project vision, and comparisons with the Delphi and .NET ecosystems.

> **Vision:** Create "ASP.NET Core for Delphi" — a modern, modular, high-performance web framework with superior Developer Experience (DX).

---

## 🏎️ Feature Comparison

Dext is designed to bridge architectural gaps in the Delphi ecosystem, bringing modern dependency injection patterns and decoupling.

| Feature | ⚡ Dext | 🐴 Horse | 📦 DMVC | 🔷 ASP.NET Core |
| :--- | :---: | :---: | :---: | :---: |
| **Architecture** | Modular (.NET style) | Middleware-based | Classic MVC | Modular |
| **Real-Time (Hubs)** | ✅ Native | ⚠️ External | ❌ | ✅ (SignalR) |
| **DI First-Class** | ✅ Native (Scoped) | ❌ | ⚠️ Limited | ✅ Native |
| **Minimal APIs** | ✅ | ✅ | ❌ | ✅ |
| **Model Binding** | ✅ Advanced | ⚠️ Basic | ✅ | ✅ |
| **OpenAPI / Swagger** | ✅ Native | ✅ | ✅ | ✅ |
| **Rate Limiting** | ✅ Advanced | ⚠️ External | ✅ | ✅ |
| **Problem Details** | ✅ RFC 7807 | ❌ | ⚠️ | ✅ |

---

## 🚀 Implementation Status (Phase 1: RC 1.0)

The Dext Framework has reached production-grade maturity in its Core, Web, and Data layers. Below is the technical breakdown of validated features:

### 🧩 Dext.Core & Foundation (Completed)
- [x] **Dependency Injection**: Support for ARC/Non-ARC, lifetimes (Singleton, Transient, Scoped), and Auto-Collections.
- [x] **Smart Reflection**: Metadata Engine with global caching and recursive property resolution.
- [x] **Performance Engine**: High-speed JSON serialization (Utf8) and `Dext.Core.Span` for zero-allocation.
- [x] **Hierarchical Configuration**: Support for JSON, YAML, EnvVars, and Options Pattern (`IOptions<T>`).
- [x] **Modern Types**: Native support for **UUID v7**, Nullable<T>, and Smart Enums.
- [x] **Async/Await**: Fluent implementation via `TAsyncTask` with `CancellationToken` support.

### 📚 Dext.Collections (Completed)
- [x] **Modern Structures**: Optimized List, Dictionary, and HashSet; Concurrent (thread-safe) versions.
- [x] **Frozen Collections**: High-performance immutable structures optimized for reading (.NET 8 style).
- [x] **Channels**: Async Producer/Consumer primitives (Go-style pipelines).
- [x] **Hardware Acceleration**: Batch processing via **SIMD & Vectors** (AVX/SSE).

### 🌐 Dext.Web Framework (Completed)
- [x] **Minimal API & Bootstrapping**: Fluent initialization of middleware pipeline and services.
- [x] **Advanced Routing**: Dynamic parameters, constraints, and native versioning (Header, Query, Path).
- [x] **Hybrid Model Binding**: Smart binding for Body, Query, Route, Header, and Services.
- [x] **Real-time & Hubs**: Support for **SSE (Server-Sent Events)** and SignalR-inspired Hubs.
- [x] **Native Middleware**: ProblemDetails (RFC 7807), Compression (GZip), CORS, and Rate Limiting.
- [x] **Zero-Leak Management**: Object lifecycle tracking integrated with ORM ChangeTracker.

### 🗄️ Dext.Entity ORM (Completed)
- [x] **Unit of Work & Repository**: `TDbContext` and `DbSet<T>` with automatic Change Tracking.
- [x] **Query Engine**: Fluent queries with support for Join, GroupBy, Paging, and Aggregates.
- [x] **Relationships**: Full support for 1:1, 1:N, and N:M with Lazy & Eager Loading (`Include`).
- [x] **Multi-Dialect**: Stable dialects for PostgreSQL, SQL Server, MySQL, SQLite, Oracle, and Firebird.
- [x] **Migrations System**: Automated Code-First evolution for schema management.
- [x] **EntityDataSet**: VCL/FMX component with Design-Time Data Preview support.

### 🔌 Dext.Net & Testing (Completed)
- [x] **Fluent REST Client**: Connection Pooling, Auto-Retry, and OAuth 2.0 (Client Credentials).
- [x] **Testing Engine**: Dynamic Mocking via Proxies, Fluent Assertions, and Snapshot Testing.
- [x] **Dext CLI**: Web UI Dashboard, high-speed test runner, and TestInsight integration.

---

## 📅 Detailed Roadmaps

For granular tracking of each workstream, refer to the specific roadmaps:

- [🌐 Web Framework](roadmap/web.md)
- [🗺️ ORM & Data](roadmap/orm.md)
- [🏗️ Infrastructure & CLI](roadmap/infrastructure.md)
- [🧠 AI & Future](roadmap/ai-future.md)
- [🛠️ IDE Integration](roadmap/ide-integration.md)
- [☁️ Cloud Native](roadmap/cloud-native.md)
- [🖥️ Desktop UI](roadmap/desktop-ui.md)
- [📋 **Pending Tasks (Backlog V1.0)**](roadmap/pending-tasks.md) ⭐ NEW

---

## 🎯 Next Steps (v1.1+)

1. **Performance**: Low-level optimizations in the middleware pipeline (Zero-allocation targets).
2. **Dext AI**: LLM orchestration and Semantic Kernel for Delphi.
3. **Cloud Native**: Adapters for AWS Lambda and Azure Functions.
4. **Desktop MVU**: Evolution of Dext.UI towards reactive architecture.

---

[← Advanced Debugging Guide](appendix/advanced-debug.md) | [Back to Home](README.md)
