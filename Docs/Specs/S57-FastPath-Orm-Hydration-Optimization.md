# S57: FastPath ORM Hydration & Streaming Optimization

## 1. Context & Benchmark Diagnostics

In our high-concurrency tests executed across both **SQLite** and **PostgreSQL**, we measured execution performance and instrumented sub-step timing breakdowns for REST endpoints within the Dext Framework.

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

## 2. Technical Architecture & Affected Modules

To introduce FastPath capabilities into the ORM while preserving 100% backward compatibility with existing codebase applications, the changes are organized across the following core modules:

```
Sources/Data/
├── Dext.Entity.Context.pas       --> Add DbSet FastPath streaming entrypoints
├── Dext.Entity.DbSet.pas         --> Implement Direct Codec Hydration & Streamers
├── Dext.Entity.Query.pas         --> Add Direct Stream SQL generation without AST overhead
├── Dext.Entity.Core.pas          --> Interface contracts for IDbSetFastStream<T>
└── Dext.Entity.FastQuery.pas     --> Zero-Alloc UTF-8 database reader routines
```

### Module Responsibilities:

1. **`Dext.Entity.Core.pas`**:
   - Define `IDbSetFastStream<T>` contract extending `IDbSet<T>`.
   - Declare non-allocating callbacks and streaming delegate signatures (`TUtf8StreamCallback`, `TDbProjectionWriteProc`).
2. **`Dext.Entity.DbSet.pas`**:
   - Implement `ExecuteToUtf8Proc` directly on `TDbSet<T>`.
   - Create `THydrationPlan` cache during `ModelBuilder` initialization to resolve field offsets (`TRttiField.Offset`) and column ordinals once per DbContext definition.
3. **`Dext.Entity.Context.pas`**:
   - Expose `Entities<T>.AsNoTracking.ExecuteToUtf8Proc(...)`.
   - Integrate FastPath query execution with active transaction states (`InTransaction`).

---

## 3. Implementation Details & Optimization Proposals

### Proposal A: Contiguous Memory Struct/Record Hydrator (`AsRecords`)
- **Concept**: For high-volume read queries (`NoTracking`), hydrate database rows into value-type records inside a single contiguous buffer (`TArray<TRecord>`), bypassing individual `TObject.Create` heap allocations.
- **Implementation Strategy**:
  - Use `TDirectAccess` / `SetLength(ResultArray, RecordCount)` to allocate all memory in one contiguous block.
  - Populate fields directly using pre-calculated field offsets (`Pointer(NativeUInt(@Array[i]) + FieldOffset)^`).
- **Safety Concerns**:
  - Records cannot support lazy-loading proxies or change-tracking identity maps. Must be restricted to `NoTracking` read queries.

### Proposal B: Direct Query FastPath Streaming (`Entities<T>.ExecuteToUtf8Proc`)
- **Concept**: Stream queried entities directly into an HTTP response socket in UTF-8 JSON format without instantiating Delphi class objects or intermediate JSON AST trees (`TJsonObject`).
- **Implementation Details**:
  - `TDbSet<T>` executes the generated SQL query and iterates the driver dataset/reader.
  - Formats JSON tokens (`{"Id":`, `,"Name":"`, etc.) directly into a thread-local memory chunk buffer and invokes `Sink.WriteUtf8(Data, Len)`.
- **Benefits**:
  - Achieves Data API (`/fastcities`) performance while preserving Dext ORM's fluent `Where(...)` filtering API.

### Proposal C: CodeGen & Pre-Compiled RTTI Mappers (`THydrationPlan`)
- **Concept**: Replace dynamic per-column RTTI inspection during the fetch loop with a pre-compiled column-to-offset map (`THydrationPlan`).
- **Implementation Details**:
  - During the first query execution, build `TArray<TColumnBinding>` matching dataset column indexes directly to entity memory offsets and primitive setters (`SetInt32`, `SetString`, `SetDateTime`).
  - Cache `THydrationPlan` globally per `TDbContext` + `TEntity` mapping pair.

---

## 4. Preservation of Existing Contracts & Compatibility Safeguards

To prevent breaking existing codebases relying on Dext ORM, the following strict constraints must be maintained:

1. **Non-Breaking API**:
   - Existing `Entities<T>.ToList`, `Entities<T>.FirstOrDefault`, and tracking mechanisms will remain untouched.
   - FastPath methods will be additive (e.g., `Entities<T>.ExecuteToUtf8Proc` or `Entities<T>.AsRecords`).
2. **Transaction Integrity**:
   - FastPath streaming queries must respect active transactions (`BeginTransaction` / `Commit` / `Rollback`) on the active `TDbContext`.
3. **Multi-Tenancy & Global Filters**:
   - FastPath SQL generation MUST honor global query filters (`SoftDelete`, `TenantId`) registered on `TModelBuilder`, unless explicitly overridden with `IgnoreQueryFilters`.
4. **Thread Safety**:
   - Pre-compiled `THydrationPlan` caches must be read-only after initialization or protected by lock-free synchronization primitives (`TLightweightMutex` / `TMultiReadExclusiveWriteSynchronizer`).

---

## 5. Verification Plan & Testing Strategy

### Automated Tests to Write:

1. **Unit Tests (`Tests/Data/Dext.Entity.FastPath.Tests.pas`)**:
   - **Correctness Test**: Verify that JSON produced by `Entities<T>.ExecuteToUtf8Proc` matches `Entities<T>.ToList` JSON output byte-for-byte (field names, dates ISO 8601, nulls).
   - **Filter Compliance**: Verify that global query filters (`SoftDelete`, `TenantId`) are correctly appended to FastPath SQL queries.
   - **Transaction Isolation**: Test streaming execution inside uncommitted transactions.
2. **Concurrency & Memory Leak Verification**:
   - Run DUnitX suite with `FastMM4` leak detection enabled (`ReportMemoryLeaksOnShutdown := True`).
   - Run 100-thread stress tests under `Dext.Benchmarks.exe` ensuring zero memory leaks or double-frees.

---

## 6. Related Areas for Deep Analysis

1. **Driver-Specific Native Buffer Readers**:
   - Analyze if FireDAC `TFDQuery` or native SQLite/PostgreSQL C-APIs allow raw UTF-8 string pointer access without conversion to Delphi `UnicodeString`.
2. **IDE Expert & CodeGen Alignment (Spec S54)**:
   - Ensure the `THydrationPlan` structure aligns with static code generators in Spec S54 for future zero-reflection static compilation.
