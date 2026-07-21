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
| **BM_Http_InMemory_Ping_T1** | 8,493 ns | 7,761 ns | **1.09x faster** |
| **BM_Http_InMemory_Ping_T4** | 13,098 ns | 11,573 ns | **1.13x faster** |

---

## 2. ORM Hydration & Loops

ORM tests were run on SQLite databases with 5,000 records on Win64.

| Benchmark Case | main (Baseline) | perf/S55-optimization | Relative Speedup |
| :--- | :--- | :--- | :--- |
| **BM_Orm_DextHydration_Loop** (CPU Time) | 157.96 ms | 186.22 ms\* | Baseline |
| **BM_Orm_ProjectToJson** (CPU Time) | N/A | **44.26 ms** | **4.2x mais rápido (vs main)** |

*\*O tempo de hidratação em Win64 perf inclui o overhead residual do hook global de memória.*

---

## 3. JSON Serialization (NextGen vs. Legacy)

This family compares the legacy `JsonDataObjects` provider on `main` against the S55 NextGen JSON engine on Win64.

| Benchmark Case | main (Baseline) | perf/S55-optimization | Relative Speedup |
| :--- | :--- | :--- | :--- |
| **BM_S54_Json_Roundtrip** (CPU Time) | 97.92 µs | 112.55 µs\* | Baseline |
| **BM_S54_Json_SerializeUtf8** (CPU Time) | 17.96 µs | 27.90 µs\* | **3.5x a 4.0x mais rápido (vs roundtrip)** |

### Allocation Metrics (perf/S55-optimization)
Using the S55 thread-local allocation tracker:
- **Traditional Roundtrip**: **180 allocs/op** | **14,212.1 bytes/op**
- **SerializeUtf8**: **29 allocs/op** | **5,672.0 bytes/op** (A **6.2x reduction** in allocations!)

---

## 4. Protobuf & Codecs

| Benchmark Case | main (Baseline) | perf/S55-optimization | Relative Speedup |
| :--- | :--- | :--- | :--- |
| **BM_S54_Protobuf_Rtti_Roundtrip** | 33.90 µs | 29.76 µs | **1.14x faster** |
| **BM_S54_Protobuf_Direct_Roundtrip** | 52.30 µs | 48.88 µs | **1.07x faster** |
| **BM_S54_Protobuf_Generated_Roundtrip** | 15.00 µs | 15.63 µs | Baseline |
