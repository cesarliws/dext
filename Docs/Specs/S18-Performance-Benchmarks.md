# 📑 S18: Performance Benchmarks Specification

**Status:** 📝 Draft  
**Owner:** Cesar Romero & Engineering Team  
**Reviewers:** Community / Architects  
**Dependencies:** S07 (Reflection), S39 (Native Server)

---

## 1. Goal

Establish a formal, highly-rigorous microbenchmarking suite (`Dext.Benchmarks`) to monitor Dext Framework performance, prevent regressions, and prove the efficiency gains of raw I/O engines and reflection caches. 

This will be powered by importing the **`Spring.Benchmark`** engine (a native Delphi port of *Google Benchmark* under Apache 2.0) directly into the repository.

---

## 2. Infrastructure Setup & Source Import

To keep Dext self-contained and free of external tooling requirements at compile-time:
* The unit `Spring.Benchmark.pas` will be copied into `External/Spring4D/Spring.Benchmark.pas`.
* This file is licensed under the **Apache License, Version 2.0**, which is fully compatible with Dext's distribution terms, provided the original header copyright notices are preserved.

### Directory Mapping
```
DextRepository/
├── External/
│   └── Spring4D/
│       └── Spring.Benchmark.pas       <-- Imported benchmarking engine
├── Benchmarks/
│   ├── Dext.Benchmarks.dpr            <-- Console runner for benchmarks
│   ├── Dext.Benchmarks.dproj
│   └── Sources/
│       ├── BM.Reflection.pas          <-- RTTI performance tests
│       ├── BM.Json.pas                <-- JSON parser / serializer tests
│       ├── BM.Orm.pas                 <-- Hydration & DB mapping tests
│       └── BM.Network.pas             <-- HTTP/2 and WebSocket roundtrip tests
```

---

## 3. Core Features of the Benchmarking Engine

By leveraging `Spring.Benchmark`, Dext gains advanced performance measurement capabilities out-of-the-box:

### 3.1. Automatic Iteration & Scaling
The engine runs each benchmark in a loop, dynamically increasing the iteration count until it achieves statistical significance. This filters out operating system scheduler latency and background CPU spikes.

### 3.2. Multi-Threaded Scalability
Provides thread-scaling execution (`->ThreadRange(1, 8)` or `->Threads(4)`), allowing us to measure lock-contention issues under heavy parallel execution (critical for testing the thread-safety and performance of caches).

### 3.3. Custom Counters (throughput, bytes/sec)
Supports defining metrics that will be printed in the benchmark report:
* **Throughput**: Records/sec, requests/sec, or items processed.
* **Bandwidth**: Bytes processed per second (e.g. JSON serialization throughput).

---

## 4. Tracked Metrics & "Golden Indicators"

Every benchmark run must calculate and report the following standard indicators:

| Indicator | Metric | Capturing Strategy | Goal |
| :--- | :---: | :--- | :--- |
| **Time/Op** | Real CPU Time (ns / µs) | High-Resolution Performance Counter | Minimize latency per operation |
| **Throughput** | Ops / Sec | Calculated by engine | Maximize throughput |
| **Allocations** | Bytes Allocated / Op | FastMM5 or native memory manager hooks | **Zero-allocation** for core loops |
| **Scalability** | Multi-threaded speedup | Concurrent thread run | Linear scaling with CPU cores |

### 4.1. Capture Memory Allocations (Zero-Allocation Goal)
To measure memory allocations per iteration in Delphi, we will register a custom counter that hooks into the memory manager.

```pascal
type
  TMemoryTracker = record
  private
    FStartAllocated: Int64;
    class function GetTotalAllocatedBytes: Int64; static;
  public
    procedure Start;
    function Stop(const AIterationCount: Int64): Double;
  end;

class function TMemoryTracker.GetTotalAllocatedBytes: Int64;
var
  State: TMemoryManagerState;
begin
  GetMemoryManager(State);
  // Aggregate allocated blocks from state (or use FastMM5 specific tracking if available)
  Result := State.TotalAllocatedMediumBlocksSize + 
            State.TotalAllocatedLargeBlocksSize + 
            State.TotalAllocatedSmallBlocksSize;
end;

procedure TMemoryTracker.Start;
begin
  FStartAllocated := GetTotalAllocatedBytes;
end;

function TMemoryTracker.Stop(const AIterationCount: Int64): Double;
begin
  Result := (GetTotalAllocatedBytes - FStartAllocated) / AIterationCount;
  if Result < 0 then Result := 0; // Prevent noise from asynchronous frees
end;
```

---

## 5. Benchmark Targets

### 5.1. Reflection Cache (S07)
Validate the speed of retrieving attributes, properties, and constructors under extreme multi-threaded access.
* **Target**: `TReflection.GetType` hits vs. standard Delphi `TRttiContext.GetType`.
* **Expectation**: Sub-microsecond latency, 0 bytes allocated, linear thread scaling.

### 5.2. JSON Engine
Validate the performance of the Dext JSON parser and object binding engine.
* **BM_Json_IndividualObject**: Deserialization of simple JSON strings to individual entity records/classes (used extensively in `Find` operations and simple payloads).
* **BM_Json_BinaryParser_Serialization**: Serializing objects and lists to raw JSON buffers using the zero-allocation pointer-based binary writer.
* **BM_Json_BinaryParser_Deserialization**: Deserializing large JSON payloads (arrays of 10,000+ objects) using the stream-based pointer-driven binary reader.
* **Expectation**: At least 3x faster than traditional DOM-based engines (like `System.JSON` or `SuperObject`) with near-zero temporary memory allocations.

### 5.3. ORM Engine (Dext.Entity)
Measure the database mapping, hydration, and transaction pipeline performance.
* **BM_Orm_IndividualObject**: Hydrating and validating a single entity retrieved by ID.
* **BM_Orm_BulkOperations**: Batch processing of 1,000+ records (Insert, Update, Delete) with sequence HiLo pre-allocation (S46) enabled.
* **BM_Orm_StoredProcedures**: Executing stored procedures and mapping output cursors directly to strongly-typed records.
* **BM_Orm_Nested_Mapping**: Complex multi-join query mapping (Dapper-like multi-mapping of flattened SQL result sets into nested object graphs, e.g., mapping `Order -> Customer -> Items` recursively).
* **Expectation**: Zero-boxing of fields, minimal mapping overhead compared to raw `TFDQuery` field access, and efficient object lifecycle handling.

### 5.4. Webserver Engines (Dext.Web)
Compare the request/response latency, concurrency, and throughput of all supported server engines.
* **Engines compared**:
  * **Indy**: Classic blocking socket baseline.
  * **http.sys**: Windows kernel-level driver.
  * **epoll**: Linux native asynchronous engine.
  * **Delphi-Cross-Sockets (DCS)**: The cross-platform asynchronous socket library wrapper.
  * **WebBroker**: The legacy standard Delphi WebBroker engine, showing Dext's modernization improvements.
* **BM_Web_Ping_Pong**: Simple HTTP GET returning `{"status":"ok"}`.
* **BM_Web_Payload_Echo**: HTTP POST sending a 10KB JSON payload and echo-ing it back (testing serialization, deserialization, and body parsing buffers).
* **BM_Web_Concurrent_Connections**: Scaling up to 10,000 concurrent requests using a keep-alive pipeline.
* **Expectation**: `http.sys` and `epoll` should demonstrate a 5x-10x throughput improvement and significantly lower memory overhead compared to Indy and WebBroker. Comparison with DCS will validate our raw OS-native transport design.

### 5.5. High-Performance HTTP Client (Dext.Net)
To enable accurate high-concurrency client-side benchmarking and build realistic native microservice-to-microservice communication pipelines:
* **BM_Client_RawGet_Throughput**: Sequential and parallel HTTP GET execution compared against standard `THTTPClient`.
* **Zero-Allocation Target**: Leverage flat memory byte buffers (`Span<Byte>` or raw pointers) to parse incoming response chunks and headers without triggering continuous heap allocations and GC pressure.
* **Aggressive Connection Pooling**: Maintain persistent keep-alive TCP socket pools directly managed by Dext's async/IOCP worker threads, bypassing the WinHTTP or WinInet wrapper stacks.
* **Expectation**: At least 4x higher throughput and 90% lower memory allocation count compared to Delphi's stock `THTTPClient`.

---

## 6. Execution & CI/CD Integration

To ensure Dext's performance never degrades:
1. **Local Execution**: Running `Dext.Benchmarks.exe` outputs readable colored results directly to the console.
2. **CI/CD Regression Check**:
   * The benchmark runner supports exporting results to JSON: `Dext.Benchmarks.exe --benchmark_format=json`.
   * A PowerShell script runs during the PR pipeline, comparing the results against a `PERF_BASELINE.json`.
   * If any Golden Indicator degrades by more than **10%**, the build fails.

---

*Generated by Antigravity AI — June 2026*
