# 📑 S43: Net-Advanced (MessagePack, Permessage-Deflate & Native TLS)

**Status:** 📝 Draft
**Owner:** Cesar Romero & Engineering Team
**Created:** 2026-06-18
**Dependencies:** S39 (Native Server Engine), S40 (WebSocket & SignalR Hubs), S41 (HTTP/2 Framing)
**Enables:** Enterprise Native Security (WSS/HTTPS) without Reverse Proxies, High-efficiency low-bandwidth IoT real-time clients.

---

## 1. Goal

Establish the architecture and specification for **Phase 2 Networking optimizations**, focusing on bandwidth reduction, binary serialization protocols, and native cross-platform transport security for raw sockets.

Specifically, this spec covers:
1. **MessagePack Hub Protocol**: A binary serialization protocol alternative to JSON for SignalR-compatible `Dext.Hubs`.
2. **Permessage-Deflate Extension**: Native RFC 7692 WebSocket compression to minimize bandwidth in real-time streams.
3. **Native OpenSSL TLS Engine**: Native OpenSSL integration for raw TCP Sockets (`IOCP` on Windows / `epoll` on Linux), enabling HTTPS/WSS/gRPC-TLS natively.

---

## 2. Scope & Technical Architecture

### 2.1 Component Architecture

```
┌──────────────────────────────────────────────────────────────┐
│  Dext.Web.Hubs (MessagePack Protocol & Payload Traversal)   │  <-- S43 Phase 1
├──────────────────────────────────────────────────────────────┤
│  Dext.WebSocket.Protocol (RFC 7692 Permessage-Deflate GZIP)  │  <-- S43 Phase 2
├──────────────────────────────────────────────────────────────┤
│  Dext.Server.TLS (Native OpenSSL Bio Sockets IOCP/epoll)     │  <-- S43 Phase 3
└──────────────────────────────────────────────────────────────┘
```

---

## 3. Detailed Features

### 3.1 MessagePack Hub Protocol
SignalR allows negotiation of the binary MessagePack format, resulting in dramatically smaller frames than standard JSON.

- **Protocol Identification**: Advertised as `messagepack` in the negotiate response.
- **Handshake Exchange**:
  ```
  Client -> Server: {"protocol":"messagepack","version":1}\x1e
  Server -> Client: {}\x1e (remains JSON for initial handshake frame)
  ```
- **Binary Wire Format**:
  Subsequent messages are formatted as MessagePack arrays following the ASP.NET Core SignalR MessagePack Hub Protocol specifications. Payload layout:
  ```
  [Length (varint)] [Message Array]
  ```
  Items in the array correspond to `[MessageType, Headers, InvocationId/Result, Target, Arguments/Item, Errors]`.
- **Implementation strategy**: Create `Dext.Web.Hubs.Protocol.MessagePack.pas` implementing `IHubProtocol` using the high-performance binary encoder of the Dext core.

### 3.2 WebSocket Permessage-Deflate (RFC 7692)
Enables WebSocket connections to negotiate GZIP compression of frame payloads.

- **Handshake Negotiation**:
  The client requests the extension via HTTP upgrade header:
  ```http
  Sec-WebSocket-Extensions: permessage-deflate; client_max_window_bits
  ```
  If accepted, the server responds:
  ```http
  Sec-WebSocket-Extensions: permessage-deflate
  ```
- **Frame Compression**:
  When active, compressed frames set the RSV1 bit to `1`. The payload is compressed using DEFLATE. The compression context (sliding LZ77 window) is maintained across frames unless `no_context_takeover` is negotiated.
- **Memory footprint control**: Limit memory allocations by using pooled state structures for ZLib compression/decompression contexts.

### 3.3 Native OpenSSL TLS Engine
Exposes native encryption/decryption in the pipeline before data reaches the HTTP/1.1, HTTP/2, or WebSocket frame parsers.

- **Asynchronous BIO Sockets**:
  Integrate OpenSSL's memory BIOs (`BIO_s_mem`) with IOCP and epoll.
  - Sockets receive encrypted data $\to$ write to incoming BIO $\to$ OpenSSL decrypts $\to$ framework reads plaintext.
  - Framework writes plaintext $\to$ OpenSSL encrypts $\to$ write to outgoing BIO $\to$ Socket sends encrypted data.
- **ALPN Negotiation**:
  Ensure OpenSSL ALPN (Application-Layer Protocol Negotiation) callbacks are wired to negotiate `h2` (HTTP/2) or `http/1.1` dynamically.
- **Certificate Handling**:
  Declarative setup supporting `.pem` and `.pfx` certificate stores.

---

## 4. Verification Plan

### Automated Tests
- MessagePack serialization/deserialization compliance testing against .NET SignalR client outputs.
- Permessage-deflate roundtrip test (fragmented compressed payloads).
- TLS Handshake validation & stress testing using raw TCP client with OpenSSL.

### Manual Verification
- Testing native Delphi Hub Client connecting to Dext Hubs over WSS (with native OpenSSL TLS) under Linux.
- Profiling memory allocations during high concurrent connections with Permessage-Deflate active.

---

*Created by Cesar Romero & Antigravity AI — June 2026*
