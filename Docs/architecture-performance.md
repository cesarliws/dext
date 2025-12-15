# 🚅 Dext Architecture: The Path to Extreme Performance

This document details the architectural decisions focused on extreme performance for the future of the Dext framework. It explains the limitations of the current model (v1) and how the new architecture (v2/Infra) will resolve these bottlenecks using modern concepts like **Zero-Allocation**, **Span<T>**, and **Native Drivers**.

---

## 🛑 The Challenge: Limitations of the Traditional Model

Currently, most Delphi frameworks (including early Dext versions) operate on solid but legacy foundations that impose a performance ceiling in high-concurrency scenarios (C10k+).

### 1. HTTP: Blocking Model & Eager Loading
*   **Problem (Threading)**: The use of `TIdHTTPServer` (Indy) forces the **Thread-per-Connection** model. For every connected client, an OS Thread is allocated.
*   **Problem (Abstraction)**: Current interfaces (`IHttpContext`, `IRequest`, `IResponse`) were designed assuming everything fits in memory.
    *   **Full Resource Loading**: To serve a file (e.g., `FileResult`), the framework often loads the entire `TStream` into memory before sending, causing RAM spikes for large files.
    *   **Eager Headers Parsing**: As soon as a connection is accepted, the framework reads and processes *all* HTTP Headers, Cookies, and Query Parameters, even if the endpoint doesn't need them.
*   **Impact**:
    *   Excessive memory consumption (1MB+ Stack per Thread + duplicated buffers).
    *   High CPU Context Switching when thousands of connections are active.
    *   Inefficiency in I/O Bound tasks (thread sits idle waiting for socket data).
    *   Delayed TTFB (Time To First Byte) because processing only starts after full request parsing.

### 2. JSON & Strings: The Cost of UTF-16
*   **Problem**: Delphi natively uses `UnicodeString` (UTF-16). The Web uses `UTF-8`.
*   **Impact**: Every received JSON request must be converted from Bytes (UTF-8) to String (UTF-16) before parsing. This generates:
    *   **Double Allocation**: Memory for the byte buffer + Memory for the converted string.
    *   **MM Pressure**: The memory manager (FastMM) works double-time to allocate and free these temporary strings for every request, increasing fragmentation.

### 3. Missing Slicing (Span)
*   **Problem**: To read a part of a string or array (e.g., reading an HTTP Header value), the traditional model uses `Copy()`, creating a new string.
*   **Impact**: Unnecessary allocations. If a Header has 100 characters and we need the first 10, we allocate a new 10-char string.

---

## ⚡ The Solution: "Metal-to-the-Pedal" Architecture

The new Dext infrastructure layer focuses on eliminating allocations and utilizing native resources.

### 1. `TSpan<T>`: Memory Slicing
Inspired by .NET's `Span<T>` and C++'s `std::span`.

*   **What it is**: A lightweight `record` representing a "window" over an existing memory block without owning it.
*   **How it works**: Instead of copying data, we point to the start memory address and length.
*   **Benefit**: Parsing HTTP Headers, Routes, and JSON with **Zero Allocations**.
    *   *Example*: Reading `Authorization: Bearer xyz` creates no "Bearer" or "xyz" strings, just Spans pointing to the original buffer.

### 2. Zero-Allocation JSON Parser
A new JSON engine built from scratch upon `TSpan<Byte>`.

*   **Change**: Does NOT convert payload to `UnicodeString`.
*   **Operation**: Reads UTF-8 bytes directly from the network stream.
*   **Performance**: Navigates JSON token-by-token (Forward-Only) or via Spans, eliminating UTF-8 <-> UTF-16 transcoding overhead.

### 3. Native Drivers (HTTP)
Progressive replacement of the Indy engine with non-blocking native drivers.

#### Phase 1: NativeAOT (Kestrel Interop)
*   Use **Kestrel** server (ASP.NET Core) compiled as a Native Library.
*   Use Pinned Memory to pass data from .NET to Delphi via pointers, zero-copy.
*   Delivers "state-of-the-art" performance (millions of req/s) immediately.

#### Phase 2: Native Drivers (Bare Metal)
*   **Windows**: Direct integration with `http.sys` (Kernel Mode). Cache and I/O managed by Kernel.
*   **Linux**: Integration with `epoll` in a custom Event Loop.
*   **I/O Model**: Real `Async/Await` at socket level, allowing a few threads (e.g., number of CPU Cores) to handle thousands of connections.

---

## 📊 Comparative Summary

| Feature | Traditional Model (Current) | New Architecture (Future) |
| :--- | :--- | :--- |
| **I/O Model** | Blocking (1 Thread per Client) | Non-Blocking (Event Loop / Completion Ports) |
| **String Handling** | UTF-16 (Mandatory Conversion) | UTF-8 (Native via Span) |
| **JSON Parsing** | String-based (Allocation Heavy) | Byte-based (Zero-Allocation) |
| **Memory** | High MM usage (Create/Free constant) | Pool & Arena Allocation (Reuse) |
| **Scalability** | Linear up to ~500 connections | Exponential (C10k ready) |

---

> **Note**: These changes are transparent to the final application (`Controllers`, `Minimal APIs`). Dext's public API remains the same, while the engine "under the hood" is swapped for high-performance versions.
