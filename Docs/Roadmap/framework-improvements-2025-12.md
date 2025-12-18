# 🚀 Framework Improvement Plan: Dext Next Steps

This document outlines the planned improvements for the Dext framework, derived from the requirements of the "Dext SO4" (Forum/Social) project and the "Thread Safe & Immutable" technical research.

## 1. Dext SO4 & Sidecar (Product-Driven Requirements)

The "Dext SO4" project acts as a definitive showcase and stress-test for the framework. It introduces the "Dext Sidecar" architecture (Local Agent + IDE Integration).

### 1.1. Real-Time Capabilities (WebSockets / SSE)
**Priority: High (Required for Forum & Sidecar Notifications)**
- **Server-Sent Events (SSE)**: Implement `IResponse.SendEvent(EventName, Data)` for one-way server-to-client updates (Notifications).
- **WebSockets**: Implement full duplex communication for the Chat feature.
- **Connection Management**: Handle persistent connections efficiently (epoll/IOCP integration in `Dext.Server`).

### 1.2. Dext Sidecar Architecture (Desktop Agentry)
**Priority: Medium (Innovative Feature)**
- **Localhost IPC**: Optimize `Dext.Server` for local loopback connections (ultra-fast startup, low memory footprint).
- **Single Instance Check**: Utility to ensure only one "Sidecar" agent runs per user session.
- **SQLite Indexing**: Ensure ORM performs optimally with SQLite for local indexing of VCL/RTL source code.

### 1.3. Advanced HTTP Features
**Priority: High (Required for Social Media Features)**
- **Multipart/Form-Data Streaming**: Robust parser for handling large video/GIF uploads without loading the entire stream into RAM.
- **Device Authorization Flow (RFC 8628)**: Implement OAuth 2.0 Device Flow to securely authenticate the IDE/Desktop Agent without handling passwords directly.

## 2. Core Framework Evolution (Technical Improvements)

Focus on making the framework more robust, thread-safe, and functional, inspired by the technical research.

### 2.1. Nullable<T> 2.0
**Priority: High (Improving DX & Performance)**
- **Thread-Safety**: Introduce `ImmutableNullable<T>` (read-only) for lock-free thread safety.
- **Atomic Operations**: Implement `AtomicNullable<T>` for high-concurrency scenarios using atomic intrinsics.
- **Functional Methods**: Add `Map`, `Match`, `Bind` methods for functional-style programming.
- **Serialization**: Native JSON/XML support (`ToJson`, `FromJson`).
- **Operators**: Complete set of comparison (`>`, `<`, `==`) and logical (`??`, `!`) operators.

### 2.2. Immutability & Lifecycle
**Priority: Medium (Architectural Robustness)**
- **IImmutableList<T>**: Implement immutable collections with ownership transfer semantics to solve Delphi's generic collection limitations safely.
- **Immutable Entities**: Support for read-only entities in ORM (`AsNoTracking` returning immutable snapshots).
- **IImmutableDbContext**: Context variant for safe, read-only data access in parallel threads.

### 2.3. Thread Safety Deep Dive
**Priority: Critical (Stability)**
- **DI Container**: Verify thread-safety of Singleton resolution and Scoped lifetime management under heavy load.
- **Request Scope**: Ensure `IHttpContext` and scoped services are properly isolated in async/parallel requests.

## 3. Roadmap Updates

These items complement the existing roadmap:

| Feature | Category | Status | Notes |
| :--- | :--- | :--- | :--- |
| **Real-Time (SSE/WS)** | Web | 📅 Planned v1.0 | Critical for Dext Forum |
| **Device Auth Flow** | Auth | 🆕 Proposed | For IDE Plugin integration |
| **Multipart Streaming** | Web | 🆕 Proposed | For Video Uploads |
| **Nullable 2.0** | Core | 🚀 In Progress | Merge Technical Research |
| **Immutability** | Core | 🆕 Proposed | Architectural improvement |
| **Sidecar Support** | Infra | 🆕 Proposed | Lightweight server mode |

## 4. Immediate Next Steps

1.  **Refine Nullable<T>**: Merge the technical research code into `Dext.Types.Nullable`.
2.  **Prototype Sidecar**: Create a small console app POC using Dext Server + SQLite to validate the architecture.
3.  **Plan Real-Time**: Design the API for SSE/WebSockets integration into the Middleware pipeline.
