# HTTP/2 Framing and HPACK Transport Layer

Dext provides a high-performance, native implementation of **HTTP/2 framing (RFC 9113)** and **HPACK header compression (RFC 7541)**. This layer serves as the foundation for the gRPC transport protocol (S02) and works directly on top of the native socket engines (S39).

---

## Architecture

The HTTP/2 transport layer is divided into four main components:

```
    IDextServerEngine (IOCP / epoll)
                 │
                 ▼ (Raw Bytes)
      TDextHttp2Connection
        ├── THpackDecoder & THpackEncoder (Header Compression)
        ├── TDextHttp2FrameCodec (TryReadFrame / Writers)
        └── TDextHttp2StreamMap (Ordered Array + Binary Search)
                 │
                 ▼ (Parsed Request Callback)
            OnRequest / gRPC Handler
```

### 1. HPACK Compressor (`Dext.Http2.Hpack.pas`)
HPACK reduces header size through:
- **Static Table**: A read-only array of 61 common header fields (RFC 7541 Appendix A).
- **Dynamic Table**: A connection-local ring-buffer of header fields (FIFO eviction by byte size).
- **Huffman Encoding**: An entropy-based compression system (fully supported in the decoder using a fast Huffman traversal).

### 2. Frame Codec (`Dext.Http2.Framing.pas`)
Implements zero-copy parsing and serialization for the 10 standard HTTP/2 frame types:
- `DATA` (0x0): Request/response body payload.
- `HEADERS` (0x1): Compressed HPACK headers.
- `RST_STREAM` (0x3): Stream cancellation.
- `SETTINGS` (0x4): Connection parameters.
- `PING` (0x6): Keep-alive and latency check.
- `GOAWAY` (0x7): Graceful shutdown / error indication.
- `WINDOW_UPDATE` (0x8): Flow control window updates.

### 3. Stream State Machine (`Dext.Http2.Stream.pas`)
Manages multiplexed concurrent streams (RFC 9113 §5.1) and handles:
- **State transitions**: `idle` ➔ `open` ➔ `half-closed` ➔ `closed`.
- **Flow control**: Tracks individual stream receive and send window sizes (default `65535` bytes).
- **Stream Map**: Implements a cache-friendly, sorted array of active streams using binary search for $O(\log n)$ lookup performance.

### 4. Connection Orchestrator (`Dext.Http2.Connection.pas`)
Manages connection-level handshakes (Client Preface `PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n` validation + initial `SETTINGS` frame exchange) and frames demultiplexing.

---

## gRPC Compatibility

gRPC requires HTTP/2 transport and relies on these conventions:
1. **Content-Type**: Must be `application/grpc`.
2. **Length-Prefixed Messages**: The request/response body inside `DATA` frames consists of a 5-byte header (`1 byte compressed flag` + `4 bytes big-endian length`) followed by the raw Protobuf message.
3. **Trailers**: Status codes are sent at the end of the response stream inside a final `HEADERS` frame (`grpc-status`, `grpc-message`).

---

## Example Usage

### Setting Up a Connection

Below is a conceptual example of using the connection directly on raw TCP socket loops:

```pascal
var
  Conn: TDextHttp2Connection;
begin
  Conn := TDextHttp2Connection.Create(THttp2ConnectionOptions.Default);
  try
    Conn.OnOutput := procedure(AData: PByte; ALen: Integer)
      begin
        // Send raw bytes to the TCP socket
        Socket.Send(AData, ALen);
      end;

    Conn.OnRequest := procedure(AConn: TObject; AStreamId: Cardinal;
      const AHeaders: TNameValuePairs; const ABody: TBytes)
      var
        ResponseHeaders: TNameValuePairs;
        ResponseBody: TBytes;
      begin
        // Process request
        SetLength(ResponseHeaders, 2);
        ResponseHeaders[0].Name := ':status';      ResponseHeaders[0].Value := '200';
        ResponseHeaders[1].Name := 'content-type'; ResponseHeaders[1].Value := 'application/json';
        
        ResponseBody := TEncoding.UTF8.GetBytes('{"msg": "Hello H2"}');
        Conn.SendResponse(AStreamId, ResponseHeaders, ResponseBody, True);
      end;

    // Loop: feed received bytes from socket to connection
    Conn.Feed(RecvBuffer, BytesRead);
  finally
    Conn.Free;
  end;
end;
```
