# 📈 Historical Benchmark Results

This document tracks historical benchmark runs for the Dext Framework across different environments, hardware configurations, and system combinations.

---

## 🖥️ Test Environment 1: Intel i9-9900 (Windows 11) - Community Run
* **Date**: June 23, 2026
* **Reporter**: Roberto Della Pasqua
* **Hardware**: Intel Core i9-9900, Windows 11
* **Engine / RTL**: Win64 with RDP64 RTL (tbbmalloc + SIMD)
* **Benchmark Tool**: `run_load_test.ps1` (Bombardier load tester)

### 📊 Results Table

| Server Engine | RTL / Memory Manager | Avg Requests/sec | Avg Latency | Max Latency | Std Dev (RPS) |
| :--- | :--- | :---: | :---: | :---: | :---: |
| **Indy (Default)** | Default Delphi RTL | 5,491.32 | 22.29 ms | 511.45 ms | 3,790.88 |
| **HTTP.sys (Default)** | Default Delphi RTL | 25,043.54 | 4.84 ms | 158.42 ms | 1,914.88 |
| **Indy (Optimized)** | RDP64 RTL (tbbmalloc + SIMD) | 29,971.74 | 3.91 ms | 1.32 s | 4,255.87 |
| **HTTP.sys (Optimized)** | **RDP64 RTL (tbbmalloc + SIMD)** | **128,485.38** | **0.95 ms (950 μs)** | **95.20 ms** | 27,475.16 |

---

## 🖥️ Test Environment 2: Local Developer Machine - First Run
* **Date**: June 23, 2026
* **Reporter**: Cezar (Local Run)
* **Hardware / OS**: Windows 11
* **Engine / RTL**: Win64 with RDP64 RTL (tbbmalloc + SIMD) + Hotpath optimizations
* **Benchmark Tool**: `run_load_test.ps1` (Bombardier load tester)

### 📊 Results Table

| Server Engine | Avg Requests/sec | Avg Latency | Max Latency | Total Successful Requests | Refused Connections |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Indy (Optimized)** | 8,371.09 | 16.35 ms | 910 ms | 67,783 | 9,317 |
| **HTTP.sys (Optimized)** | **17,178.90** | **7.28 ms** | **244.36 ms** | **154,673** | **16,591** |

> [!NOTE]
> During this local run, some connections were refused because the target port/socket queue limits were reached, or the server was actively closing connections due to system-level TCP socket exhaustion. We will tune TCP configuration and port binding settings in future runs.

---


---

## 🧪 Test Environment 3: Local S54 Microbenchmarks - Baseline Run
* **Date**: July 9, 2026
* **Reporter**: Cezar (Local Run)
* **Hardware / OS**: Windows 11
* **Engine / RTL**: Win32 Release
* **Benchmark Tool**: `Dext.Benchmarks.exe --benchmark_filter=BM_S54_`

### 📊 Results Table

| Benchmark | Time | CPU | Iterations |
| :--- | :---: | :---: | :---: |
| **BM_S54_Protobuf_Direct_Roundtrip** | 51,188 ns | 50,896 ns | 10,000 |
| **BM_S54_Json_Roundtrip** | 109,984 ns | 108,517 ns | 7,727 |
| **BM_S54_Orm_JsonConverter_Roundtrip** | 160,910 ns | 154,929 ns | 5,165 |

> [!NOTE]
> This run was captured after the S54 benchmark runner was split so the HTTP server path does not start when the filter is only `BM_S54_`. It is a local baseline for future regression tracking.

## 🖥️ Test Environment 4: WSL2 Ubuntu Linux (WSL bridge) - Epoll Otimizado
* **Date**: July 17, 2026
* **Reporter**: Cezar (Local Run)
* **Hardware**: Resource-constrained developer PC (WSL2 Ubuntu)
* **Engine / RTL**: Linux64 Release (Epoll optimized vs Indy)
* **Benchmark Tool**: Bombardier from Windows Host to WSL2 Guest

### 📊 Results Table

| Server Engine | Avg Reqs/sec | Avg Latency | Max Latency | Total Reqs |
| :--- | :---: | :---: | :---: | :---: |
| **Indy (Linux)** | 2,506.30 | 49.87 ms | 365.32 ms | 25,113 |
| **Epoll (Opt)** | **6,022.93** | **20.77 ms** | **1.60 s** | **60,166** |

> [!NOTE]
> This run compares Indy vs the optimized Epoll implementation on Linux.
> The optimized Epoll includes HTTP/1.1 Keep-Alive socket recycling,
> automatic header generation, Nagle's algorithm disabled (TCP_NODELAY),
> and connection sweep loop throttling. Performance improved by 2.4x
> over Indy and 16.3x over the original Epoll implementation.

## 🛠️ Future Benchmarks & Roadmap
1. **TCP Socket Tuning**: Adjust system-level TCP ports configuration to prevent "connection refused" errors under extreme concurrency.
2. **Windows Server 2025 Verification**: Evaluate performance under modern server environments.
3. **MSHeap Testing**: Contrast `tbbmalloc` with Windows MSHeap performance metrics.
4. **TechEmpower Preparation**: Mature the benchmarking configurations to eventually submit Dext to the official TechEmpower Web Framework Benchmarks.
