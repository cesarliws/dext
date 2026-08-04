# S57: FastPath ORM Hydration & Streaming Optimization

## 1. Context & Benchmark Diagnostics

In our high-concurrency tests executed across both **SQLite** and **PostgreSQL**, we measured execution performance and instrumented sub-step timing breakdown for REST endpoints within the Dext Framework.

### Reference Benchmark Results (5,000 Records per Request - PostgreSQL under 10 Concurrent Connections):

| Endpoint | Mechanism | Avg Latency | Reqs/sec (RPS) | Throughput |
| :--- | :--- | :--- | :--- | :--- |
| **`/cities`** | Traditional ORM (`Entities<T>.ToList` + RTTI Serializer) | 1,760 ms | 4.7 req/s | 2.03 MB/s |
| **`/fastcities`** | Data API Zero-Alloc (`UseSql` + `ExecuteToUtf8Proc` streaming) | 249 ms | 51.3 req/s | 15.02 MB/s |

### Primary Bottlenecks Identified in Traditional ORM:

1. **Massive Heap Allocation (Heap/Lock Contention)**:
   - For every request to `/cities`, the Dext ORM individually allocates **5,000 class object instances on the 64-bit heap** (via `TBenchmarkUser.Create`), in addition to internal list nodes and tracking structures.
   - Under 10 concurrent requests, **50,000 objects are allocated and freed on the heap simultaneously**, creating severe lock contention in Delphi's memory manager (`FastMM / RDPMM lock contention`).
2. **Heavy Deallocation Cost (`Ctx.Free`)**:
   - Freeing these 5,000 instances in `Ctx.Free` takes between **25ms and 85ms** strictly destroying objects on the heap.
3. **Reflection Overhead (`TValue.From<TArray<T>>`)**:
   - Passing generic entity arrays to the HTTP response serializer via `TValue` / RTTI incurs reflection overhead and runtime type boxing.

---

## 2. Optimization Proposals for Dext ORM

### Proposal A: Contiguous Memory Struct/Record Hydrator (Zero Object Overhead)
- **Concept**: For read-only queries or large datasets (`NoTracking`), offer a hydration mode where entities are read as *records* (value types) stored inside a single contiguous buffer (`TArray<TRecord>`), instead of individually allocated heap objects.
- **Benefits**:
  - Eliminates 5,000 memory manager calls per request.
  - Allocates the entire block in a single `SetLength`.
  - Memory deallocation time drops from ~50ms down to 0ms.

### Proposal B: Direct Query FastPath Streaming (`Entities<T>.ToJsonStream` / `ToUtf8Proc`)
- **Concept**: When the goal of a REST endpoint is simply to return JSON for queried entities, bypass the intermediate object instantiation phase in memory.
- **Mechanism**:
  - `DbSet<T>` will expose streaming methods such as `Entities<T>.Where(...).ExecuteToUtf8Proc(Proc)` or `ToJsonStream(Stream)`.
  - The driver reader (FireDAC/Native) reads the database query buffer and streams the JSON response directly into the HTTP socket's `IUtf8ResponseSink`.
- **Benefits**:
  - Achieves Data API (`/fastcities`) performance while preserving Dext ORM's fluent, strongly-typed API.

### Proposal C: CodeGen / RTTI Pre-Compiled Mappers
- **Concept**: Replace dynamic per-column RTTI inspection with pre-compiled mappers or delegates generated during `ModelBuilder` initialization.
- **Mechanism**: Map column ordinals directly to object field offsets during the initial connection setup, eliminating `TValue` and reflection calls during the fetch loop.

---

## 3. Future Implementation Roadmap

1. **Phase 1**: Develop support for `Entities<T>.AsNoTracking.ExecuteToUtf8Proc` in `Dext.Entity.Context.pas` and `Dext.Entity.DbSet.pas`.
2. **Phase 2**: Create comparative benchmarks in `Benchmarks/Sources/BM.Orm.pas` including the new ORM FastPath.
3. **Phase 3**: Evaluate Record-based Hydration support for high-frequency, read-heavy workloads.
