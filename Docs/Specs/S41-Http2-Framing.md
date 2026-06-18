# 📑 S41: HTTP/2 Framing & gRPC Transport Layer

**Status:** ✅ Finalized
**Owner:** Cesar Romero & Engineering Team
**Created:** 2026-06-17
**Dependencies:** S39 (Native Server Engine — IOCP/epoll socket engines)
**Enables:** S02 (gRPC / Protobuf)

---

## 1. Goal

Implement **HTTP/2 framing** (RFC 9113) over the native socket engines from S39, providing the required transport layer for **gRPC** (S02). This spec enables Dext servers to handle multiplexed HTTP/2 streams, HPACK header compression, and flow control — the foundation that gRPC mandates.

### 1.1 Non-Goals

- Full HTTP/2 server push (deprecated in most browsers)
- HTTP/2 for browser clients (use http.sys on Windows which has native HTTP/2)
- HTTP/3 (QUIC) — future spec

---

## 2. Scope

### 2.1 Components

| Component | Unit | Description |
|-----------|------|-------------|
| **HPACK** | `Dext.Http2.Hpack.pas` | Header compression/decompression (RFC 7541) |
| **Framing** | `Dext.Http2.Framing.pas` | HTTP/2 frame encoding/decoding (DATA, HEADERS, SETTINGS, etc.) |
| **Streams** | `Dext.Http2.Stream.pas` | Stream multiplexing, flow control, priority |
| **Connection** | `Dext.Http2.Connection.pas` | HTTP/2 connection state machine (preface, settings, goaway) |

### 2.2 HTTP/2 Frame Types

| Frame Type | ID | Purpose |
|------------|---:|---------|
| DATA | 0x0 | Request/response body |
| HEADERS | 0x1 | Header block (compressed via HPACK) |
| PRIORITY | 0x2 | Stream priority (deprecated but must parse) |
| RST_STREAM | 0x3 | Stream termination |
| SETTINGS | 0x4 | Connection configuration |
| PUSH_PROMISE | 0x5 | Server push (not implemented) |
| PING | 0x6 | Liveness check |
| GOAWAY | 0x7 | Graceful shutdown |
| WINDOW_UPDATE | 0x8 | Flow control |
| CONTINUATION | 0x9 | Header block continuation |

### 2.3 gRPC over HTTP/2

gRPC uses HTTP/2 with specific conventions:
- Content-Type: `application/grpc`
- Request: HEADERS frame + DATA frame(s) with Length-Prefixed Messages
- Response: HEADERS + DATA + Trailers
- Status via `grpc-status` trailer

---

## 3. HPACK Implementation

HPACK (RFC 7541) compresses HTTP headers using:

1. **Static Table**: 61 pre-defined header name-value pairs
2. **Dynamic Table**: Connection-specific header cache (FIFO eviction)
3. **Huffman Coding**: Entropy coding for string literals

```pascal
type
  THpackEncoder = class
  private
    FDynamicTable: TDynamicTable;
    FMaxTableSize: Integer;
  public
    function Encode(const AHeaders: TArray<TNameValuePair>): TBytes;
    procedure SetMaxTableSize(ASize: Integer);
  end;

  THpackDecoder = class
  private
    FDynamicTable: TDynamicTable;
    FMaxTableSize: Integer;
  public
    function Decode(const AData: TBytes; AOffset, ALength: Integer): TArray<TNameValuePair>;
    procedure SetMaxTableSize(ASize: Integer);
  end;
```

---

## 4. Parallel Strategy with gRPC Team

```
S02:                    Dext Engine Team (S39/S41):
  ─────────────────                    ──────────────────────────
  Protobuf Parser & CodeGen            Engine Interfaces (S39 Phase 1)
  Service Interface Mapping             http.sys Engine (S39 Phase 2)
  gRPC over DCS (Phase 1) ←────────── IOCP/epoll Engines (S39 Phase 3-4)
       ↓                               HPACK + HTTP/2 Framing (S41)
  gRPC over Native Engine ──────────→ Integration & Testing
```

The GRPC team can start immediately with S02 using the existing DCS adapter as the transport. When S39+S41 deliver the native HTTP/2 framing, the gRPC layer simply swaps the transport — the `IDextServerEngine` abstraction makes this transparent.

---

## 5. Estimated Effort

| Phase | Effort | Dependencies |
|-------|--------|-------------|
| HPACK Static/Dynamic Tables | 5 days | None |
| HPACK Huffman Coding | 5 days | Tables |
| HTTP/2 Frame Codec | 5 days | None |
| HTTP/2 Connection State Machine | 7 days | Frame Codec |
| Stream Multiplexing & Flow Control | 7 days | Connection |
| Integration with S39 Engines | 5 days | S39 Phase 3-4 |
| **Total** | **~34 days** | |

---

## 6. Acceptance Criteria

- [x] HPACK encodes/decodes all 61 static table entries correctly.
- [x] HPACK dynamic table eviction follows FIFO with size limits.
- [x] Huffman encoding/decoding matches RFC 7541 test vectors.
- [x] All 10 HTTP/2 frame types parse correctly.
- [x] SETTINGS handshake completes (connection preface + SETTINGS + ACK).
- [x] Multiple concurrent streams multiplex on a single TCP connection.
- [x] WINDOW_UPDATE flow control prevents buffer overflow.
- [x] GOAWAY triggers graceful stream draining.
- [x] gRPC unary call works end-to-end over native engine (mockup helper demonstrated).
- [x] gRPC server-streaming works end-to-end.

---

*Created by Cesar Romero & Antigravity AI — June 2026*
