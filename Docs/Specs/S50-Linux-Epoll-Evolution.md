# 📑 S50: Linux Epoll Server Engine Evolution

**Status:** ✅ Finalized  
**Owner:** Cesar Romero & Engineering Team  
**Created:** 2026-07-05  
**Dependencies:** S39 (Native Server Engine)  
**Enables:** Ultra-low latency, zero-copy networking, and maximum throughput on Linux enterprise environments, directly competing with Nginx and Envoy.

---

## 1. Goal

Evolve the Dext Linux `epoll` socket engine (`TDextEpollEngine`) to achieve world-class efficiency, throughput, and resource utilization. By implementing kernel-level optimizations, CPU pinning, zero-copy file transmission, and memory allocation tuning, Dext will become a first-class citizen for high-concurrency Linux server deployments.

---

## 2. Target Optimizations & Technical Design

To maximize performance, Dext must leverage Linux-specific kernel capabilities to minimize context-switching, user-kernel memory copies, and thread synchronization bottlenecks.

```
                  Incoming TCP Connections (SO_REUSEPORT)
                                  │
         ┌────────────────────────┼────────────────────────┐
         ▼ (Core 0)               ▼ (Core 1)               ▼ (Core 2)
 ┌───────────────┐        ┌───────────────┐        ┌───────────────┐
 │ EpollWorker 0 │        │ EpollWorker 1 │        │ EpollWorker 2 │  ◄── [CPU Affinity Pinning]
 └───────┬───────┘        └───────┬───────┘        └───────┬───────┘
         │                        │                        │
         ├─► [TCP_DEFER_ACCEPT]   ├─► [TCP_DEFER_ACCEPT]   ├─► [TCP_DEFER_ACCEPT]
         ├─► [EPOLLET / Oneshot]  ├─► [EPOLLET / Oneshot]  ├─► [EPOLLET / Oneshot]
         │                        │                        │
         ▼                        ▼                        ▼
 ┌───────────────┐        ┌───────────────┐        ┌───────────────┐
 │ TTask.Run     │        │ TTask.Run     │        │ TTask.Run     │  ◄── [Delphi Thread Pool]
 └───────┬───────┘        └───────┬───────┘        └───────┬───────┘
         │                        │                        │
         └───────────┬────────────┴───────────┬────────────┘
                     ▼                        ▼
               [sendfile()]             [rpmalloc / Pools]
               Zero-Copy                Lock-Free Memory
```

---

## 3. Detailed Specifications

### 3.1. Thread Core Affinity (CPU Pinning)
*   **Concept:** Bind each `TDextEpollWorker` thread to a specific physical CPU core using `pthread_setaffinity_np`.
*   **Why:** Prevents the OS scheduler from migrating worker threads across different CPU cores, eliminating L1/L2/L3 cache line invalidations and reducing scheduling latency.
*   **Implementation:**
    ```pascal
    // Map thread handle to CPU core
    CPU_ZERO(Mask);
    CPU_SET(CoreId, Mask);
    pthread_setaffinity_np(ThreadHandle, SizeOf(Mask), @Mask);
    ```

### 3.2. TCP_DEFER_ACCEPT
*   **Concept:** Postpone waking up the worker thread on a new connection until the client transmits the first packet of data.
*   **Why:** Avoids waking up the reactor thread when a connection is established but no request data has been sent yet (e.g., pre-connections or network probes), reducing useless wake-ups.
*   **Implementation:** Set the socket option `TCP_DEFER_ACCEPT` on the listening socket with an integer timeout value in seconds.

### 3.3. TCP Fast Open (TFO - TCP_FASTOPEN)
*   **Concept:** Allow handshake data to be sent inside the initial SYN packet.
*   **Why:** Saves a complete Round-Trip Time (RTT) for recurring clients, dramatically improving response times for mobile or high-latency clients.
*   **Implementation:** Enable `TCP_FASTOPEN` on the server listener and handle incoming fast open packets via `accept` / `read`.

### 3.4. Zero-Copy File Transmission (`sendfile`)
*   **Concept:** Bypass user-space memory allocations when serving static files.
*   **Why:** Standard file sending reads file chunks into user memory (RAM) and writes them back to the network socket, causing multiple user/kernel boundary transitions. Using `sendfile()` streams the file descriptor data directly to the network socket descriptor at the kernel level.
*   **Implementation:** Add support for a specialized file response type (`TDextFileResult`) that delegates write execution to `sendfile(SocketFd, FileFd, Offset, Count)` inside the worker thread.

### 3.5. Lock-Free Buffer Pool (Slab / Ring Buffer)
*   **Concept:** Replace ad-hoc `TBytes` buffer allocations per read event with a pre-allocated pool of fixed-size buffers (e.g., 4KB slabs).
*   **Why:** Constant allocation and resizing of byte arrays triggers heap memory fragmentation and GC/ref-counting contention under heavy parallel loads.
*   **Implementation:** Each pinned `TDextEpollWorker` thread maintains a thread-local, lock-free ring of pre-allocated buffers. Workers borrow a buffer during `read()`, parse the HTTP request, and return the buffer once execution is dispatched.

### 3.6. Keep-Alive and Idle Timeout Management
*   **Concept:** Actively track and close inactive connections to protect server resources.
*   **Why:** Under high load, dead or slow clients can saturate the file descriptor limit (`RLIMIT_NOFILE`) of the Linux process, preventing new clients from connecting.
*   **Implementation:**
    *   Set TCP Keep-Alive options (`TCP_KEEPIDLE`, `TCP_KEEPINTVL`, `TCP_KEEPCNT`) on the client sockets.
    *   Maintain a thread-local timing wheel or priority queue inside the Epoll worker to track idle connection times and actively close sockets exceeding the HTTP Keep-Alive timeout.

### 3.7. SO_LINGER and Graceful Worker Draining
*   **Concept:** Ensure clean socket shutdowns without dropping active packets.
*   **Why:** Abruptly closing the server process could drop responses currently in the TCP transmission queue.
*   **Implementation:** Use `SO_LINGER` to block the socket close until queued packets are fully transmitted (or timeout expires). When stopping, stop accepting new connections first, let existing active requests finish, and then terminate the Epoll loop.

---

## 4. Verification Plan

### Automated Microbenchmarks
*   Configure the benchmark suite to run with `--server -epoll` on Linux under various CPU core mappings.
*   Measure memory allocator performance (`rpmalloc` vs native Linux malloc) during intensive request loops.

### Stress Testing
*   Measure latency spikes under 10k+ concurrent connections with `bombardier` to ensure `TCP_DEFER_ACCEPT` and keeping connections alive prevents degradation.
