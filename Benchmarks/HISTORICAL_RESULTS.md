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

## 🛠️ Future Benchmarks & Roadmap
1. **TCP Socket Tuning**: Adjust system-level TCP ports configuration to prevent "connection refused" errors under extreme concurrency.
2. **Windows Server 2025 Verification**: Evaluate performance under modern server environments.
3. **MSHeap Testing**: Contrast `tbbmalloc` with Windows MSHeap performance metrics.
4. **TechEmpower Preparation**: Mature the benchmarking configurations to eventually submit Dext to the official TechEmpower Web Framework Benchmarks.
