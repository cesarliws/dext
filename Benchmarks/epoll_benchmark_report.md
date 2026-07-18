# Technical Report: Dext Linux Epoll Socket Engine Optimization

This report details the diagnostics, optimizations, and benchmark results for the native Linux Epoll socket server engine in the Dext Framework.

---

## 1. Executive Summary

We investigated a performance bottleneck where the Linux Epoll engine under WSL2 yielded only **~368 reqs/sec** with **~333ms average latency**, while Indy (Thread-Pool) achieved **2,506 reqs/sec** under identical conditions.

By implementing high-resolution hotpath telemetry, we isolated the root causes. After correcting socket lifetime management, implementing HTTP/1.1 Keep-Alive, and disabling Nagle's algorithm, Epoll throughput increased to **6,022.93 reqs/sec** (a **16.3x speedup**) and average latency dropped to **20.77ms** (a **16x reduction**), outperforming Indy by **2.4x**.

---

## 2. Diagnostics & Root Causes

Through microsecond-level telemetry, we observed that while the server's internal request processing took only **0.86ms**, the client observed a **~290ms latency**. This discrepancy was traced to three distinct issues:

### A. The Reference-Counting Lifetime Bug
The `TDextEpollConnection` object (representing the request connection) was invoking `Close` (which closes the socket file descriptor) in its destructor:
```pascal
destructor TDextEpollConnection.Destroy;
begin
  Close; // <-- Bug: closed the socket prematurely
  inherited;
end;
```
Because the connection wrapper interface exited scope immediately after processing the request, it closed the socket under the hood on every single request.

### B. Lack of HTTP Keep-Alive Support
The Epoll response writer did not automatically calculate and inject `Content-Length` or `Connection` headers. Without these, the HTTP client could not determine message boundaries, making connection reuse impossible and forcing a new TCP connection (SYN/ACK handshake) for every request.

### C. Nagle's Algorithm & Delayed ACK Penalty
Because new TCP connections were created constantly, they fell victim to **Nagle's Algorithm** combined with the Windows/WSL virtual bridge **Delayed ACK** delay (up to 200ms of wait time for small packets like a 4-byte 'pong').

---

## 3. Implemented Optimizations

We applied the following surgical improvements to `Dext.Server.Epoll.pas`:

1. **Decoupled Connection Lifetime**: Removed the automatic `Close` call from the `TDextEpollConnection` destructor. Sockets are now owned and recycled exclusively by the Epoll worker loop.
2. **Implemented HTTP Keep-Alive**:
   - Sockets are now re-armed for `EPOLLIN` (read) instead of being closed if the client requests Keep-Alive.
   - Automatically injects `Content-Length` (using `FBodyLen`) and `Connection: keep-alive` (or `close`) response headers in `SendHeaders`.
3. **Disabled Nagle's Algorithm**: Configured `TCP_NODELAY` on accepted client sockets.
4. **Throttled Sweep Loop**: Throttled the inactive connection sweep scan to run at most once per second (reducing it from 60,000 runs to only 92).
5. **Hotpath Telemetry**: Added conditional telemetry (`DEXT_PROFILE_EPOLL=true`) tracking queue, handler, parse, and send durations in microseconds.

---

## 4. Benchmark Results

### Client Environment:
- **Command**: `bombardier-windows-amd64.exe -c 125 -d 10s http://localhost:8085/ping`
- **Concurrency**: 125 connections
- **Duration**: 10 seconds

### Comparison Table:

| Metric | Original Epoll | Indy (Thread-Pool) | Optimized Epoll |
| :--- | :---: | :---: | :---: |
| **Requests / sec** | 367.92 | 2,506.30 | **6,022.93** (🚀 **16.3x**) |
| **Avg Latency** | 333.64 ms | 49.87 ms | **20.77 ms** (📉 **16.0x**) |
| **Throughput** | 41.54 KB/s | 583.08 KB/s | **0.91 MB/s** |
| **Total Requests** | 3,796 | 25,113 | **60,166** |

---

## 5. How to Replicate

### Step 1: Build the Project
Compile the `Dext.Benchmarks` project in **Release** configuration for the **Linux 64-bit** platform in RAD Studio.

### Step 2: Start the Epoll Server (WSL2 Ubuntu)
Run the server with the profiling and keep-alive environment variables:
```bash
export DEXT_PROFILE_EPOLL=true
export DEXT_SIDECAR_ENABLED=false
./Dext_Benchmarks --server -epoll
```

### Step 3: Run the Load Test (Windows PowerShell)
```powershell
& "C:\dev\tools\bombardier-windows-amd64.exe" -c 125 -d 10s http://localhost:8085/ping
```
