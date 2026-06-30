# S13: High-Performance Redis Client (Dext.Redis)

## 🎯 Goal
Implement a native, high-performance Redis client for the Dext Framework that follows the "batteries included" philosophy. The client must be fully integrated with Dext's async/await infrastructure, connection pooling, and zero-allocation JSON engine.

## 📝 Background
Existing Delphi Redis clients often rely on blocking Indy components or lack modern Redis feature support (RESP3, Client-side caching). Dext requires a client that matches its high-concurrency architecture.

## 🏗️ Architecture & Requirements

### 1. Protocol Support
- **RESP2/RESP3**: Full support for the Redis Serialization Protocol.
- **Binary-Safe**: Handles raw bytes and complex strings without encoding overhead.
- **Zero-Allocation Parsing**: Reuse buffers and leverage Dext's low-level memory management to minimize GC pressure.

### 2. High-Performance Core
- **Async/Await**: Native integration with `Dext.Threading.Async`. No blocking calls in the main execution path.
- **Socket Engine**: Built directly on top of the raw TCP socket transport layer exposed in **Spec S47** (`TDextTcpClient`), utilizing the framework's native non-blocking IOCP (Windows) and epoll (Linux) backend drivers instead of legacy blocking models.
- **Connection Pooling**: Integrated with `Dext.Net.ConnectionPool` for efficient resource management.

### 3. Key Features
- **Commands**: Support for Strings, Hashes, Lists, Sets, Sorted Sets, and Streams.
- **RedisJSON**: Native integration with `Dext.Json` for ultra-fast object serialization.
- **Pub/Sub**: Implementation using `Dext.Collections.Channels` for reactive message handling.
- **Pipelining & Transactions**: Batching commands to reduce network round-trips.
- **Lua Scripting**: Easy execution of server-side scripts.

### 4. Developer Experience (DX)
- **Fluent API**: Type-safe and discoverable command interface.
- **Smart Types**: Automatic conversion between Redis types and `Dext.Core.SmartTypes`.
- **Dependency Injection**: Seamless registration in the Dext DI container.

## 📅 Roadmap (Phased Implementation)

### Phase 1: Core Foundation (The Engine)
- RESP2/RESP3 Parser (Zero-allocation).
- Socket management with SSL/TLS support.
- Connection Pool integration.
- Basic commands (GET, SET, DEL, EXPIRE).

### Phase 2: Advanced Data Structures
- Hashes, Lists, and Sets.
- Pipelining support.
- Pub/Sub integration with Channels (crucial for distributed HTMX/SSE telemetry as defined in S23).

### Phase 3: Dext Ecosystem Integration
- `RedisJSON` module support using `Dext.Json`.
- Cache provider for `Dext.Entity` (Second-level cache).
- Distributed Locking (Redlock implementation).
- Distributed Session Manager (`TRedisStreamableSessionManager`) for HTMX and Streamable Sessions, as defined in S23.

### Phase 4: Modern Redis Features
- Redis Streams.
- Client-side caching.
- Redis Bloom/Search/TimeSeries (as optional extensions).

## ✅ Definition of Done
- Benchmarks showing superiority or parity with top-tier Redis clients in other languages.
- Full test coverage for async execution and connection recovery.
- Integrated documentation in "The Dext Book".
