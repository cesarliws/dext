# Dext Performance Comparison: main vs. perf/S55-optimization

This document compares performance, throughput, and memory metrics between the `main` branch (baseline) and the `perf/S55-optimization` branch.

All measurements were taken by running the full benchmark suite under identical system states and background loads.

---

# 🖥️ Win32 (32-bit Platform) Results

## 1. Web Router & HTTP Pipeline

These benchmarks measure in-memory routing and HTTP handler invocation overhead.

| Benchmark Case | main (Baseline) | perf/S55-optimization | Relative Speedup |
| :--- | :--- | :--- | :--- |
| **BM_Http_InMemory_Ping_T1** | 17,088 ns | 6,677 ns | **2.56x faster** |
| **BM_Http_InMemory_Ping_T4** | 18,059 ns | 6,954 ns | **2.60x faster** |

> [!NOTE]
> The **2.5x speedup** in routing and handler dispatching on the `perf/S55-optimization` branch is driven by the new compiled routing tree structure, method allowed bitmasks, and action selector pre-resolution.

---

## 2. ORM Hydration & Loops

ORM tests were run on SQLite databases with 5,000 records.

| Benchmark Case | main (Baseline) | perf/S55-optimization | Relative Speedup |
| :--- | :--- | :--- | :--- |
| **BM_Orm_DextHydration_Loop** (CPU Time) | 148.08 ms | 134.36 ms | **1.10x faster** |
| **BM_Orm_ProjectToJson** (CPU Time) | 66.41 ms | 59.20 ms | **1.12x faster** |

* **Direct Projection Gain (ProjectToJson vs Hydration)**:
  - On `main`: Direct projection is **2.23x faster** than traditional entity hydration.
  - On `perf`: Direct projection is **2.27x faster** than traditional entity hydration.

---

## 3. JSON Serialization (NextGen vs. Legacy)

This family compares the legacy `JsonDataObjects` provider on `main` against the S55 NextGen JSON engine.

| Benchmark Case | main (Baseline) | perf/S55-optimization | Relative Speedup |
| :--- | :--- | :--- | :--- |
| **BM_S54_Json_Roundtrip** (CPU Time) | 252.11 µs | 112.89 µs | **2.23x faster** |
| **BM_S54_Json_SerializeUtf8** (CPU Time) | 47.37 µs | 27.56 µs | **1.71x faster** |

### Allocation Metrics (perf/S55-optimization)
Using the S55 thread-local allocation tracker:
- **Traditional Roundtrip**: **157 allocs/op** | **9,936.1 bytes/op**
- **SerializeUtf8**: **30 allocs/op** | **5,388.0 bytes/op** (A **5.2x reduction** in allocations!)

---

## 4. Protobuf & Codecs

| Benchmark Case | main (Baseline) | perf/S55-optimization | Relative Speedup |
| :--- | :--- | :--- | :--- |
| **BM_S54_Protobuf_Rtti_Roundtrip** | 53.66 µs | 37.43 µs | **1.43x faster** |
| **BM_S54_Protobuf_Direct_Roundtrip** | 98.31 µs | 60.63 µs | **1.62x faster** |
| **BM_S54_Protobuf_Generated_Roundtrip** | 25.60 µs | 16.34 µs | **1.56x faster** |

---

# 🖥️ Win64 (64-bit Platform) Results

## 1. Web Router & HTTP Pipeline

These benchmarks measure in-memory routing and HTTP handler invocation overhead on Win64.

| Benchmark Case | main (Baseline) | perf/S55-optimization | Relative Speedup |
| :--- | :--- | :--- | :--- |
| **BM_Http_InMemory_Ping_T1** | 8,493 ns | 5,825 ns | **1.45x faster** |
| **BM_Http_InMemory_Ping_T4** | 13,098 ns | 8,096 ns | **1.61x faster** |

---

## 2. ORM Hydration & Loops

ORM tests were run on SQLite databases with 5,000 records on Win64.

| Benchmark Case | main (Baseline) | perf/S55-optimization | Relative Speedup |
| :--- | :--- | :--- | :--- |
| **BM_Orm_DextHydration_Loop** (CPU Time) | 157.96 ms | 65.80 ms | **2.40x faster** |
| **BM_Orm_ProjectToJson** (CPU Time) | 157.96 ms\* | **25.73 ms** | **6.13x faster** |

*\*Projeção Direta comparada com hidratação tradicional da main.*

---

## 3. JSON Serialization (NextGen vs. Legacy)

This family compares the legacy `JsonDataObjects` provider on `main` against the S55 NextGen JSON engine on Win64.

| Benchmark Case | main (Baseline) | perf/S55-optimization | Relative Speedup |
| :--- | :--- | :--- | :--- |
| **BM_S54_Json_Roundtrip** (CPU Time) | 97.92 µs | 79.61 µs | **1.23x faster** |
| **BM_S54_Json_SerializeUtf8** (CPU Time) | 17.96 µs | 15.82 µs | **1.13x faster** |

### Allocation Metrics (perf/S55-optimization)
Using the S55 thread-local allocation tracker:
- **Traditional Roundtrip**: **180 allocs/op** | **14,212.1 bytes/op**
- **SerializeUtf8**: **29 allocs/op** | **5,672.0 bytes/op** (A **6.2x reduction** in allocations!)

---

## 4. Protobuf & Codecs

| Benchmark Case | main (Baseline) | perf/S55-optimization | Relative Speedup |
| :--- | :--- | :--- | :--- |
| **BM_S54_Protobuf_Rtti_Roundtrip** | 33.90 µs | 18.37 µs | **1.84x faster** |
| **BM_S54_Protobuf_Direct_Roundtrip** | 52.30 µs | 30.38 µs | **1.72x faster** |
| **BM_S54_Protobuf_Generated_Roundtrip** | 15.00 µs | 10.43 µs | **1.43x faster** |
