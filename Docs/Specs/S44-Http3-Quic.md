# 📑 S44: HTTP/3 & QUIC Transport Engine

**Status:** 📝 Draft
**Owner:** Cesar Romero & Engineering Team
**Created:** 2026-06-18
**Dependencies:** S39 (Native Server Engine - abstraction interfaces)
**Enables:** Low-latency connection migration, zero-RTT connection handshake, packet-loss resilience for REST/gRPC.

---

## 1. Goal

Establish the architecture and specification for the **HTTP/3 and QUIC transport protocol layer** (RFC 9000, RFC 9114) in the Dext Framework. This spec details the native UDP-based transport implementation and integration with Dext's core stream abstraction models.

---

## 2. Technical Context & Objectives

Unlike HTTP/2 which multiplexes streams over a single TCP connection (making it susceptible to TCP Head-of-Line blocking if a packet is lost), HTTP/3 operates over **QUIC**, which uses **UDP** as its underlying transport layer.

```
┌───────────────────────────────────────────┐
│              Dext.Web                     │
├───────────────────────────────────────────┤
│        HTTP/3 Layer (RFC 9114)            │
├───────────────────┬───────────────────────┤
│ QPACK (RFC 9204)  │   QUIC (RFC 9000)     │
├───────────────────┴───────────────────────┤
│          TLS 1.3 (RFC 9001)               │
├───────────────────────────────────────────┤
│                UDP Sockets                │
└───────────────────────────────────────────┘
```

### 2.1 Core Architectural Requirements
1. **QPACK Compression (RFC 9204)**: Dynamic and static table-based header compression optimized for out-of-order stream delivery.
2. **QUIC Connection State Machine**: Handshakes, connection IDs (allowing connection migration when clients switch networks), and congestion control.
3. **UDP Packet Loop**: A high-efficiency packet reader using `recvmmsg` (on Linux) or overlapping UDP operations (on Windows IOCP).

---

## 3. Implementation Plan & Milestones

### Phase 1: UDP Socket Engine
- Implement high-throughput asynchronous UDP sockets under Windows IOCP and Linux `epoll`.
- Support batch packet reception to minimize syscall overhead.

### Phase 2: QUIC Protocol Implementation
- Implement QUIC packet parsing (long/short headers, connection IDs, crypto frames).
- Integrate TLS 1.3 handshake callbacks (directly decrypting QUIC packets).
- Implement QUIC stream state machine (unidirectional and bidirectional streams).

### Phase 3: QPACK & HTTP/3 Mapping
- Implement QPACK encoder/decoder.
- Map HTTP/3 frames (DATA, HEADERS, SETTINGS, CANCEL_PUSH) to QUIC streams.
- Integrate the HTTP/3 transport under Dext's `IWebHost` / `TRequestDelegate` pipeline.

---

*Created by Cesar Romero & Antigravity AI — June 2026*
