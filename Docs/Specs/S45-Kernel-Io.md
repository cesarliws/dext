# 📑 S45: Advanced Kernel I/O (io_uring & kqueue)

**Status:** 📝 Draft
**Owner:** Cesar Romero & Engineering Team
**Created:** 2026-06-18
**Dependencies:** S39 (Native Server Engine)
**Enables:** Submission Queue polling, zero-syscall network operations, true native macOS/FreeBSD deployment support.

---

## 1. Goal

Integrate advanced, modern kernel-level I/O engines into the Dext Server framework, extending the native socket layer to support Linux `io_uring` and macOS/FreeBSD `kqueue`.

---

## 2. Technical Context & Objectives

While `epoll` is highly efficient, it still requires system calls (`epoll_wait`, `read`, `write`) that incur context switching overhead. Linux `io_uring` changes this by providing Shared Rings (Submission Queue and Completion Queue) between user space and kernel space, allowing asynchronous I/O without system calls in the hot path.

Similarly, macOS and FreeBSD use `kqueue` for efficient event notification. This spec outlines how we will implement native kqueue and io_uring selectors to work with Dext's thread pool architecture.

```
                  ┌─────────────────────────────┐
                  │   Dext.Server.Connection    │
                  └──────────────┬──────────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         ▼                       ▼                       ▼
   [io_uring Engine]      [epoll Engine]         [kqueue Engine]
    Linux 5.1+             Linux Legacy           macOS & BSD
```

---

## 3. Scope & Implementation

### 3.1 Linux `io_uring` Implementation
- **Shared Memory Queues**: Define record structures representing the Submission Queue Entry (SQE) and Completion Queue Entry (CQE) mapping directly to Linux kernel definitions.
- **SQPOLL (Submission Queue Polling)**: Enable kernel thread polling of the submission queue, allowing the Dext network engine to send and receive network packets with zero syscalls.
- **Buffer Registration**: Register I/O buffers with the kernel (`io_uring_register`) to eliminate page table mapping overhead during socket transfers.

### 3.2 macOS/FreeBSD `kqueue` Implementation
- **Kevent Binding**: Map `kevent` structures and system calls.
- **Mac Event Loop**: Implement `TKqueueSelector` wrapping `kqueue()` and `kevent()`, allowing local development on macOS to run with optimized native selectors instead of falling back to raw TCP emulation or DCS.

---

## 4. Verification & Benchmarking
- **Syscall Auditing**: Use tools like `strace` on Linux to verify that the hot path of network reads/writes under `io_uring` issues zero system calls.
- **Comparative Benchmarks**: Run performance comparisons between IOCP, epoll, and io_uring under identical connection stress scenarios.

---

*Created by Cesar Romero & Antigravity AI — June 2026*
