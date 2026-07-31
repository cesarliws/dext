# 🔒 Native SSL/TLS Architecture and Network Optimizations (S43)

The Dext Framework provides an advanced **Native SSL/TLS Security Subsystem** (`Dext.Net.Security`) and **Network Protocol Optimizations**, engineered for transparent encryption, high-performance compression, and binary serialization across all application layers (Web Servers, WebSocket Hubs, HTTP Clients, Redis Clients, and asynchronous TCP Sockets).

---

## 🎯 Key Features Delivered in Spec S43

1. **Unified TLS Abstraction (`Dext.Net.Security`)**: `IDextTLSEngine`, `IDextTLSContextProvider`, and `IDextTLSStream` interfaces decoupling transport I/O from encryption providers.
2. **Native OpenSSL 3.x Memory BIO Engine (`BIO_s_mem`)**: Asynchronous zero-copy/lock-free TLS handshake and framing for `epoll` (Linux) and `IOCP` (Windows) reactors.
3. **Native HTTP.sys & Schannel Bindings**: Direct Windows Kernel HTTPS support with seamless Windows Certificate Store integration.
4. **`dext dev-certs https` CLI Tool**: Pure Pascal CryptoAPI generator for self-signed X.509 development certificates with SAN extension (`localhost`, `127.0.0.1`) and automatic Root Certificate Store trust registration.
5. **WebSocket Permessage-Deflate (RFC 7692)**: Transparent zlib frame compression with sliding window support and extension negotiation.
6. **Binary MessagePack Protocol for SignalR Hubs**: High-speed compact binary protocol (`Dext.Web.Hubs.Protocol.MessagePack.pas`) fully compatible with SignalR.
7. **Redis SSL Support (`rediss://`)**: Transparent TLS encryption for `TDextRedisClient`.
8. **REST Client HTTPS Customization**: Fluent SSL options and custom verification callbacks (`IgnoreCertificateErrors`, `AllowSelfSigned`).

---

## ⚙️ Configuration & Fluent API

### 1. Web Server (`appsettings.json`)
```json
{
    "Server": {
        "Port": 8080,
        "UseHttps": "true",
        "SslProvider": "OpenSSL",
        "SslCert": "server.crt",
        "SslKey": "server.key"
    }
}
```

### 2. Redis SSL Client (`rediss://`)
```pascal
var
  Options: TDextRedisOptions;
  Client: TDextRedisClient;
begin
  Options := TDextRedisOptions.Default;
  Options.Host := '127.0.0.1';
  Options.Port := 6380;
  Options.UseSsl := True;
  Options.SslOptions.Provider := 'OpenSSL';
  
  Client := TDextRedisClient.Create(Options);
  Client.Connect;
end;
```

---

## 🚀 WebSocket Permessage-Deflate & SignalR MessagePack Hub

Dext automatically enables payload optimizations for high-frequency WebSocket channels:

```pascal
// Map Hub with MessagePack and Permessage-Deflate
App.Builder.MapHub<TChatHub>('/chat', procedure(Options: TDextHubOptions)
begin
  Options.EnableMessagePack := True;
  Options.EnablePermessageDeflate := True;
end);
```

---

## 📊 Performance & Validation

- **High-Load Throughput**: **32,338+ requests/second** with an average latency of **986 microseconds** under **32 concurrent connections** and **11 MB RAM** working set.
- **Cross-Platform Compatibility**: 100% unit and integration test pass rate on Linux x86_64 (`epoll` native) and Windows (`http.sys`/`IOCP`).
