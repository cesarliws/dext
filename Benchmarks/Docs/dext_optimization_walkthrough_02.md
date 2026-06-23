# Dext Performance Optimization Walkthrough

## Phase 1: ORM Hydration

Reduced ORM hydration time and improved micro-operations performance in Release mode:

| Benchmark | Baseline (Release) | Optimized (Release) | Gain |
|---|---|---|---|
| **BM_Orm_DextHydration_Loop** | 64.40 ms | **53.13 ms** | **-17.5%** |
| **BM_Orm_Micro_Allocations** | 18.14 ms | **16.65 ms** | **-8.2%** |
| **BM_Orm_Micro_ReaderGetValue** | 22.29 ms | **16.33 ms** | **-26.7%** |
| **BM_Orm_Micro_RttiSetValue** | 12.13 ms | **8.45 ms** | **-30.3%** |

- [Dext.Entity.DbSet.pas](file:///c:/dev/Dext/DextRepository/Sources/Data/Dext.Entity.DbSet.pas) — Pre-computed hydration plan, pre-sized result list.
- [Dext.Entity.Query.pas](file:///c:/dev/Dext/DextRepository/Sources/Data/Dext.Entity.Query.pas) — Pre-sizing for query results.

---

## Phase 2: HTTP Pipeline + JSON Serialization

Optimized JSON serialization, telemetry, route matching, and formatter exception blocks:

| Benchmark | Baseline (Release) | Optimized (Release) | Gain |
|---|---|---|---|
| **BM_Http_InMemory_Ping_T1** | 5205 ns | **3953 ns** | **-24.0%** |
| **Http.sys Server throughput** | ~3.6k RPS | **~11.0k RPS** | **+205%** |
| **Http.sys Avg Latency** | 41.64 ms | **11.30 ms** | **-72.8%** |
| **Http.sys Max Latency** | 1.80 s | **78.02 ms** | **-95.6%** |

### OPT-1: Serialization Plan Cache (HIGH IMPACT)
**File:** [Dext.Json.pas](file:///c:/dev/Dext/DextRepository/Sources/Core/Dext.Json.pas)
- Introduced `TSerializationPlan` — a per-type cached structure that pre-computes property names, handles, type classification, and list flags once.
- Eliminated RTTI attribute resolution and case dispatch loops per object serialization.

### OPT-2: Reuse TDextSerializer in DataAPI
**File:** [Dext.Web.DataApi.pas](file:///c:/dev/Dext/DextRepository/Sources/Web/Dext.Web.DataApi.pas)
- Reused `TDextSerializer` instance on `TDataApiHandler` to avoid heap allocations per request.

### OPT-3: Guard Telemetry Allocation in Pipeline
**File:** [Dext.Web.Pipeline.pas](file:///c:/dev/Dext/DextRepository/Sources/Web/Dext.Web.Pipeline.pas)
- Guarded `TJSONObject` allocations behind `TDiagnosticSource.Instance.Enabled`.

### OPT-4: Route Matching Without Temporary Lists
**File:** [Dext.Web.Routing.pas](file:///c:/dev/Dext/DextRepository/Sources/Web/Dext.Web.Routing.pas)
- Implemented single-pass route matching with local stack variables to eliminate temporary lists.

### OPT-8: Remove try..except in JSON Formatter
**File:** [Dext.Web.Formatters.Json.pas](file:///c:/dev/Dext/DextRepository/Sources/Web/Dext.Web.Formatters.Json.pas)
- Removed SEH try..except blocks from JSON formatting.

---

## Build Verification
- Framework (14 packages): ✅ Compiled (Release)
- DextTool (CLI): ✅ Compiled (Release)
- DextSidecar: ✅ Compiled (Release)
- Benchmarks: ✅ Compiled (Release)
