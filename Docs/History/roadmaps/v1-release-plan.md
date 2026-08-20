# 🗺️ Dext Framework - V1.0 Release Plan

This document outlines the critical steps and features required to reach the **v1.0 (Production Ready)** milestone. The focus is on stability, thread safety, developer experience, and web standard compliance.

## 🎯 Primary Goals

1.  **Robustness**: Ensure the ORM and Web layer can handle concurrent loads without leaks or race conditions.
2.  **Completeness**: Add missing features expected in a modern web framework (SSL, Compression, Content Neg).
3.  **Type Safety**: Reduce "magic strings" in the ORM through a strong metadata system.

---

## 📅 Roadmap Phases

### Phase 1: Core Stability & Concurrency (ORM) ✅ **COMPLETED**

Ensuring the data access layer is thread-safe and performant is the top priority.

-   [x] **Connection Pooling Architecture**
    -   Implement a generic `IConnectionPool` interface.
    -   Create concrete implementations (e.g., `TFireDACConnectionPool`).
    -   Ensure `DbContext` requests a connection from the pool and releases it immediately upon destruction.
-   [x] **Thread-Safety Validation**
    -   Refactor `AddDbContext` to strictly support **Transient** (safe default) or **Scoped** (requires scope management) lifetimes.
    -   Validate "Non-Pooling" scenarios: Ensure connections are cleanly opened/closed if no pool is active.
-   [x] **Stress Testing**
    -   Create a multithreaded test suite (simulating concurrent HTTP requests).
    -   Validate potential memory leaks or cross-thread contamination in the `IdentityMap`.

### Phase 2: Application Lifecycle & Data Integrity ✅ **COMPLETED**

Prevent data corruption during startup and ensure orderly application states.

-   [x] **Startup States**
    -   Define application states: `Starting`, `Migrating`, `Seeding`, `Running`, `Stopping`.
-   [x] **Migration/Seeding Lock**
    -   Implement a mechanism to block incoming HTTP requests (returning `503 Service Unavailable`) while the database is being migrated or seeded.
    -   Ensure robust error handling: if migration fails, the app should likely halt or stay in maintenance mode.
-   [x] **Graceful Shutdown**
    -   Ensure all background tasks and pending requests are handled before killing the process.

### Phase 3: ORM Developer Experience (DX) & Metadata ✅ **COMPLETED**

Improving how developers interact with the ORM and performance optimization.

-   [x] **Metadata System V2 (`TEntityType<T>`)**
    -   Create static metadata defining the mapping: `Property -> Column -> Type`.
    -   Implement generic helpers to allow strongly-typed queries (e.g., `.Select(User.Name)` instead of `.Select('Name')`).
-   [x] **Startup Validation**
    -   Read RTTI at startup and cross-reference with registered metadata.
    -   **Fail Fast**: Raise exceptions immediately if metadata does not match the actual class structure.
-   [x] **Performance**
    -   Use the pre-calculated metadata to avoid repetitive RTTI lookups during request processing.

### Phase 4: Web Package Feature Completeness ✅ **COMPLETED**

Features required for a modern, production-grade API.

-   [x] **Response Compression**
    -   Implement Middleware for `Gzip` compression.
    -   Respect `Accept-Encoding` headers.
-   [x] **HTTPS / SSL Support**
    -   Simplify SSL configuration in `TIndyWebServer` (via `UseHttps`).
    -   Support loading certificates from file/store.
-   [x] **Content Negotiation**
    -   Implement `IOutputFormatter` architecture.
    -   Respect `Accept` headers.
-   [x] **Cookies & Multipart/Form-Data**
    -   Support for reading/writing cookies.
    -   Basic lightweight multipart parser for file uploads.
-   [x] **Global Exception Handling**
    -   Implement `UseExceptionHandler` middleware.
    -   Standardize error responses using **RFC 7807 (Problem Details)**.

---

## 📝 Definition of Done (DoD) for V1.0

-   [x] All Phase 1 tests pass under load (concurrency stress test).
-   [x] Simple SSL/HTTPS setup verified.
-   [x] Metadata system operational in the `EntityDemo`.
-   [x] Documentation updated with new configuration options.
-   [x] No known memory leaks in core scenarios.
