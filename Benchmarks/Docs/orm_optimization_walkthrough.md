# Dext ORM Hydration and List Pre-sizing Optimization Walkthrough

We optimized the performance of ORM hydration inside `TDbSet<T>` and `TFluentQuery<T>` by:
1. Replacing cell-level dictionary lookups, property resolution, default value checks, and type converters with a pre-compiled `THydrationPlan` built once per query.
2. Pre-sizing the generic list capacity (`Capacity`) before entering the row retrieval loops to avoid successive array resizing and element copying overheads.
3. Accessing the list via the concrete `TList<T>` variable (`LList.Add`) instead of the interface `Result.Add` to leverage Delphi's method inlining and bypass interface dispatch overhead.
4. Optimizing the database driver read loop (`TFireDACReader`) by caching `TField` references locally (avoiding `Fields[Index]` indexing calls) and removing the outer `try..except` exception frame setup overhead inside `FireDACFieldToTValue`.

## Changes Made

### 1. Pre-Compiled Hydration Plan (Phase 1)
- **`Dext.Entity.DbSet.pas`**:
  - Added `TColumnHydrationItem` and `THydrationPlan` records to store pre-mapped details about reader columns.
  - Implemented `BuildHydrationPlan(const Reader: IDbReader): THydrationPlan` to resolve column indexes, fields, properties, default values, and type converters once before entering loops.
  - Implemented overloaded versions of `Hydrate` and `HydrateTarget` that accept `THydrationPlan`.
  - Removed the old unused `private` overloaded methods `Hydrate` and `HydrateTarget` that did not take a plan, eliminating compiler hints `H2219`.
  - Refactored `ToList`, `TSqlQueryIterator.MoveNextCore`, and `TStreamingViewIterator.MoveNextCore` to build the plan when the query initializes and reuse it throughout iteration.
  - Added OpenTelemetry span attributes (`plan_build_ms` and `hydration_loop_ms`) inside `ToList` using a high-resolution `TStopwatch` to track plan generation and cell loop timings separately.

### 2. List Capacity Pre-sizing & Inlined Appends (Phase 2)
- **`Dext.Collections.pas`**:
  - Verified and ensured `property Capacity: Integer read GetCapacity write SetCapacity` is exposed in the public interface of `TList<T>`.
- **`Dext.Entity.DbSet.pas` & `Dext.Entity.Query.pas`**:
  - Replaced indirect `TCollections.CreateList<T>` / `TCollections.CreateObjectList<T>` instantiation with direct instantiation of `TList<T>`.
  - Added logic to inspect the specification:
    - If `Take(N)` is defined on the specification, set list capacity to `N`.
    - Otherwise, default to a sensible initial capacity of `64` to prevent initial micro-resizings during small-to-medium queries.
  - Replaced `Result.Add(Entity)` inside the hydration loops with `LList.Add(Entity)`. Since `TList<T>.Add` is marked `inline`, this allows the compiler to fully inline the list insertion, removing both the interface dispatch overhead and the standard method call overhead.

### 3. Driver Reader Optimization (Phase 3)
- **`Dext.Entity.Drivers.FireDAC.pas`**:
  - Cached `TField` references inside `TFireDACReader` constructor as a `TArray<TField>`, eliminating the `FQuery.Fields[Index]` lookup overhead for every single cell query.
  - Removed the outer redundant `try..except` block from the global `FireDACFieldToTValue` function, removing the exception frame setup overhead on every single retrieved field value.

---

## Validation Results

We successfully compiled the `Dext.Benchmarks` project with no warnings or hints and ran `Dext.Benchmarks.exe --benchmark_filter=BM_Orm`.

### Benchmark Performance Evolution

| Metric / Stage | Phase 0 (Unoptimized) | Phase 1 (Hydration Plan) | Phase 2 (List Capacity) | Phase 3 (Driver Optimized) |
| --- | --- | --- | --- | --- |
| **`BM_Orm_RawDataset_Loop`** | ~16.8 ms | ~36.6 ms | ~21.2 ms | **15.6 ms** |
| **`BM_Orm_DextHydration_Loop`** | **106.7 ms** | **90.1 ms** | **70.7 ms** | **60.1 ms** |

---

### Hotspot Decomposition Comparison: Phase 0 vs Phase 3 (5,000 records, 4 columns)

By decomposing the total hydration loop time, we can clearly isolate how the optimizations affected each component:

| Step / Component | Micro-Benchmark Reference | Time (Phase 0 - Original) | Time (Phase 3 - Fully Optimized) | Absolute Gain |
| --- | --- | --- | --- | --- |
| **Leitura do Driver** | `BM_Orm_Micro_ReaderGetValue` | 27.0 ms | **22.6 ms** | **-4.4 ms (-16.3%)** |
| **Alocação de Objetos** | `BM_Orm_Micro_Allocations` | 23.4 ms | **23.6 ms** | *(Constant)* |
| **Atribuição RTTI** | `BM_Orm_Micro_RttiSetValue` | 13.1 ms | **13.0 ms** | *(Constant)* |
| **Fluxo Interno/Controle** | *(Diferença)* | **43.2 ms** | **0.9 ms** | **-42.3 ms (-97.9%)** |
| **Total Hidratado** | `BM_Orm_DextHydration_Loop` | **106.7 ms** | **60.1 ms** | **-46.6 ms (-43.7% overall)** |

### Summary of Improvements

1. **Hydration Plan & Direct List Access**: Eliminated dynamic property mapping lookups and interface dispatch wrapper calls, virtually removing the `Fluxo Interno/Controle` overhead (went from **43.2 ms** to **0.9 ms**).
2. **List Capacity Pre-sizing**: Prevented memory re-allocations and elements copy operations on the heap.
3. **Driver Reading Optimization**: Saved **4.4 ms** on reading data from FireDAC/SQLite by avoiding field index lookups and omitting the outer try-except wrapper.
4. **Cumulative Impact**: The entire ORM hydration loop is now **43.7% faster** overall, running in **60.1 ms** instead of **106.7 ms**!
