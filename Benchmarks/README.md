# ⚡ Dext Performance Benchmarks Suite

This directory contains the official performance benchmarking suite for the Dext Framework. The suite is designed to run both **isolated microbenchmarks** (in-memory routing, ORM hydration, reflection, JSON, codecs) and **high-concurrency network stress tests** comparing server engines (Indy vs. `http.sys`).

The suite currently acts as the home for three kinds of measurements:

- transport and server throughput (`Dext.Benchmarks.dpr`);
- data-structure and allocator comparisons (`CollectionsPerformance`, `GenericsScalability`, `ZeroAlloc`);
- codec and hydration work that supports S54 (`protobuf`, `JSON`, `ORM`, and `EntityDataSet`).

---

## 🚀 Getting Started

### 1. Requirements
* **Delphi 12 Athens (or newer)** (Compiler Version 37.0+ is recommended).
* **MSBuild** (configured via Delphi's `rsvars.bat` or the universal builder script).
* **Bombardier (optional)**: For running concurrent load tests. Download the pre-compiled binary for Windows (`bombardier-windows-amd64.exe`) from the [Bombardier Releases page](https://github.com/codesenberg/bombardier/releases) and place it in your tools folder (e.g., `C:\dev\tools\`).

### 2. Project Structure
* `Dext.Benchmarks.dpr`: Entry point that acts as both a microbenchmark runner and a standalone high-performance server.
* `run_load_test.ps1`: Automated PowerShell script to execute stress tests using `bombardier`.
* `Sources/BM.Http.pas`: Test cases for HTTP servers, mock contexts, and standalone servers.
* `Sources/BM.Orm.pas`: Hydration and ORM engine tests (raw dataset loop vs Dext Entity hydration).

---

## 🧭 Benchmark Map

### Core Runner

- `Dext.Benchmarks.dpr`: main executable for microbenchmarks and the standalone HTTP server mode.
- `run_load_test.ps1`: automated load test for the HTTP server engines.

### Focused Suites

- `CollectionsPerformance`: compares `Dext.Collections` against RTL collection types.
- `GenericsScalability`: measures generated type explosion and compilation/runtime characteristics.
- `ZeroAlloc`: tracks allocation-sensitive HTTP, routing, middleware, JSON, and ORM scenarios.


## 🗂️ Historical Results

Best benchmark results and noteworthy runs are tracked in [HISTORICAL_RESULTS.md](HISTORICAL_RESULTS.md). Keep that file updated whenever a new best result is confirmed so the current baseline stays easy to find.

### S54 Coverage Targets

These are the benchmark families that should be reported in the S54 roadmap and used for regression tracking:

- `BM_S54_Protobuf_Direct_Roundtrip`
- `BM_S54_Json_Roundtrip`
- `BM_S54_Orm_JsonConverter_Roundtrip`
- Protobuf RTTI vs direct-offset vs generated codec paths.
- JSON serialization and hydration using the shared field plan.
- ORM hydration and materialization using the shared field plan.
- `TEntityDataSet.Load<T>` and apply/sync flows driven by the same model.

---

## 📌 Running Guidance

Use these filters to focus on the S54 slice without starting the HTTP server path:
```powershell
.\Dext.Benchmarks.exe --benchmark_filter=BM_S54_
```

- Benchmark builds should use `Release` when the goal is throughput or allocation numbers.
- Use `Win32` and `Win64` when comparing codec hot paths; the Win32 delta is usually the most revealing.
- Keep benchmark cases deterministic and avoid mixing them with unit-test-only setup logic.
- Prefer isolated filters when measuring one subsystem so the result can be compared across sessions.

---

## 🛠️ How to Compile

To get realistic performance figures, **always compile the project in `Release` configuration**.

### A. Via the Universal Builder Script (Recommended)
From the root workspace directory, run:
```powershell
Powershell -ExecutionPolicy Bypass -File .\DelphiBuildDPROJ.ps1 -ProjectFile ".\DextRepository\Benchmarks\Dext.Benchmarks.dproj" -Config Release -Platform Win32
```

### B. Via Direct MSBuild Command (Windows)
From the `Benchmarks` directory, call `rsvars.bat` and compile:
```powershell
# Load Delphi environment variables
call "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"

# Compile clean Release build
msbuild Dext.Benchmarks.dproj /t:Clean;Build /p:Config=Release /p:Platform=Win32 /v:minimal /nologo
```

### C. Compiling for Linux (Cross-Compilation)
To compile for Linux64 using Delphi's cross compiler from Windows, run:
```powershell
# Using the Universal Builder Script
Powershell -ExecutionPolicy Bypass -File .\DelphiBuildDPROJ.ps1 -ProjectFile ".\DextRepository\Benchmarks\Dext.Benchmarks.dproj" -Config Release -Platform Linux64

# Or via Direct MSBuild Command
msbuild Dext.Benchmarks.dproj /t:Clean;Build /p:Config=Release /p:Platform=Linux64 /v:minimal /nologo
```
*Note: Make sure you have the Linux SDK configured in your RAD Studio IDE connection manager to allow successful cross-compilation.*

---

## 📊 Mode 1: Running Microbenchmarks

The microbenchmarks measure memory overhead, processing speed, and execution times using the `Spring.Benchmark` runner (a native Delphi port of Google Benchmark).

To execute the microbenchmarks, simply run the executable:
```powershell
.\Dext.Benchmarks.exe
```

### Command Line Options
You can control the microbenchmark execution using standard flags:

* **Filter benchmarks**: Run only specific tests matching a pattern:
  ```powershell
  # Run only HTTP benchmarks
  .\Dext.Benchmarks.exe --benchmark_filter=BM_Http
  
  # Run only ORM benchmarks
  .\Dext.Benchmarks.exe --benchmark_filter=BM_Orm
  ```
* **Change output format**: Export output to JSON or CSV for analytics:
  ```powershell
  .\Dext.Benchmarks.exe --benchmark_format=json
  ```
* **Repeat runs**: Repeat each test multiple times to calculate mean, median, and standard deviation:
  ```powershell
  .\Dext.Benchmarks.exe --benchmark_repetitions=5
  ```

---

## 🌐 Mode 2: Standalone HTTP Server

You can run the benchmark executable as a dedicated, standalone HTTP server (bypassing the Google Benchmark runner). This mode binds to port `8085` and exposes a `/ping` route.

```powershell
# Start Dext using the Kernel-mode http.sys engine
.\Dext.Benchmarks.exe --server -httpsys

# Start Dext using the Indy Thread-Pool engine
.\Dext.Benchmarks.exe --server -indy
```

---

## 🔥 Mode 3: Automated High-Concurrency Stress Test

To measure the true capacity of the servers under high parallel load (throughput and latency distribution), use the automated stress test script.

1. Ensure `bombardier-windows-amd64.exe` is located at `C:\dev\tools\`.
2. Open PowerShell and run:
   ```powershell
   # Run the comparative load test (125 concurrent channels, 10 seconds duration)
   .\run_load_test.ps1
   ```

The script will:
1. Spin up the Indy server in the background and bombard it using `bombardier`.
2. Shut down Indy, spin up the `http.sys` server, and bombard it under the same conditions.
3. Print a full throughput (RPS), data bandwidth (Throughput), and latency comparison report.

---

## 📈 Interpreting Results

### Microbenchmarks Report (Mode 1)
```
Benchmark                               Time             CPU   Iterations
-----------------------------------------------------------------------------
BM_Http_InMemory_Ping_T1/threads:1       5205 ns         5191 ns       117750
```
* **Time**: Real elapsed time per operation (lower is better).
* **CPU**: CPU thread time used per operation (lower is better).
* **Iterations**: Total loops executed to achieve statistical significance.

### Concurrent Load Test Report (Mode 3)
```
Statistics        Avg      Stdev        Max
  Reqs/sec     11469.94    2519.00   22347.36
  Latency       11.00ms     7.28ms   203.89ms
```
* **Reqs/sec (RPS)**: The total number of requests processed by Dext per second (higher is better).
* **Latency**: Response time to clients. `http.sys` should average ~11ms under 125 concurrent connections, maintaining low latency spikes.

---

## 🐧 Testing Benchmarks on Linux

Dext contains a high-performance native `epoll` socket server engine built specifically for Linux. You can compile and benchmark Dext directly on Linux to compare performance.

### 1. Compile the Benchmark for Linux
You can cross-compile the binary from Windows to Linux64 (refer to the **How to Compile - C** section above). The compiled binary `Dext.Benchmarks` will be outputted to:
```
DextRepository\Output\37.0\Linux64\Release\Dext.Benchmarks
```
Copy this binary to your target Linux system.

### 2. Standalone Server with Epoll
Execute the standalone Dext server using the high-performance native `epoll` engine on Linux:
```bash
# Allow executing the binary
chmod +x ./Dext.Benchmarks

# Start the epoll server (defaults to port 8085)
./Dext.Benchmarks --server -epoll
```
*(Note: Bypassing http.sys on Linux, `-epoll` or `-native` will automatically instantiate the `TDextEpollEngine` sockets.)*

### 3. Load Testing with Bombardier on Linux
To stress-test your server on Linux:
1. **Download Bombardier**: Get the pre-compiled binary for Linux from the [Bombardier Releases page](https://github.com/codesenberg/bombardier/releases):
   ```bash
   wget https://github.com/codesenberg/bombardier/releases/download/v1.2.6/bombardier-linux-amd64
   chmod +x bombardier-linux-amd64
   ```
2. **Execute Stress Test**: Send a load of 125 concurrent connections for 10 seconds to the epoll server:
   ```bash
   ./bombardier-linux-amd64 -c 125 -d 10s http://127.0.0.1:8085/ping
   ```

### 4. Running Microbenchmarks on Linux
To run the in-memory, routing, and ORM Google/Spring microbenchmarks on Linux:
```bash
./Dext.Benchmarks --benchmark_repetitions=3
```
*The `ReadLn` console blocking is automatically bypassed on non-Windows platforms so the suite runs cleanly inside Linux shell scripts and CI environments without hanging.*
