# 📑 S43: Net-Advanced (MessagePack, Permessage-Deflate & Native TLS Architecture)

**Status:** 📝 Draft / In Progress
**Owner:** Cesar Romero & Engineering Team
**Created:** 2026-06-18
**Updated:** 2026-07-23
**Dependencies:** S39 (Native Server Engine), S40 (WebSocket & SignalR Hubs), S41 (HTTP/2 Framing)
**Enables:** Enterprise Native Security (WSS/HTTPS/TLS) across Web Servers (http.sys, epoll, IOCP, Indy), Redis Client (`TDextRedisClient`), REST Client (`TRestClient`), and Raw Sockets without requiring Reverse Proxies.

---

## 1. Goal & Vision

Establish an abstraction layer and concrete provider implementation for **SSL/TLS Security across the entire Dext Framework**, enabling high-performance, zero-allocation, transparent encryption across all networking modules.

Specifically, this spec covers:
1. **Unified SSL/TLS Abstraction Layer (`Dext.Net.Security.pas`)**: Interface-driven TLS engines (`IDextTLSEngine`, `IDextTLSContextProvider`, `IDextTLSStream`) decoupling transport logic from SSL implementations (OpenSSL 1.1/3.x, Windows Schannel / http.sys, Taurus TLS, Indy fallback).
2. **Native OpenSSL Memory BIO Engine (`Dext.Net.Security.OpenSSL.pas`)**: Zero-copy/low-allocation TLS handshake and framing for raw asynchronous TCP Sockets (`IOCP` on Windows / `epoll` on Linux).
3. **Windows `http.sys` Native SSL Binding**: Direct Windows Kernel SSL configuration and X.509 certificate store integration.
4. **`TDextRedisClient` SSL/TLS Support (`rediss://`)**: Transparent TLS wrapping for raw TCP Redis connections.
5. **`TRestClient` / `THttpClient` Transparent HTTPS**: Unified client SSL configuration.
6. **Fluent DSL & `appsettings.json` Integration**: Uniform, declarative configuration across Web Apps, Redis Client, and HTTP Clients.
7. **WebSocket Permessage-Deflate & MessagePack Hub Protocol**: Bandwidth and payload optimizations for SignalR and WebSockets.

---

## 2. Component Architecture

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                Dext Unified Fluent DSL                                 │
│       App.UseHttps(...)  |  TDextRedisOptions.UseSsl(...)  |  TRestOptions.UseSsl(...) │
└────────────────────────────────────────────────────────────────────────────────────────┘
                                            │
                                            ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        Dext.Net.Security Abstraction Layer                             │
│       IDextTLSContextProvider  │  IDextTLSEngine  │  IDextTLSStream  │  TDextTLSOptions   │
└────────────────────────────────────────────────────────────────────────────────────────┘
            │                                 │                                │
            ▼                                 ▼                                ▼
┌───────────────────────┐         ┌───────────────────────┐        ┌───────────────────────┐
│ OpenSSL Native Engine │         │ Windows Http.sys      │        │ Fallback / Indy /     │
│ (BIO_s_mem IOCP/epoll)│         │ (Kernel X.509 Store)  │        │ Taurus SSL Providers  │
└───────────────────────┘         └───────────────────────┘        └───────────────────────┘
            │                                 │                                │
            └─────────────────────────────────┼────────────────────────────────┘
                                              ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                     Consumer Framework Modules (HTTPS / WSS / TLS)                      │
│   Web Application (http.sys / epoll)  │  TDextRedisClient  │  TRestClient  │ Raw TCP   │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Core Abstraction Specification (`Dext.Net.Security`)

### 3.1 Data Types & Configurations
```pascal
type
  TDextTLSVersion = (tls1_0, tls1_1, tls1_2, tls1_3);
  TDextTLSVersions = set of TDextTLSVersion;
  TDextTLSMode = (tlsmClient, tlsmServer);

  TDextTLSOptions = record
    Enabled: Boolean;
    Mode: TDextTLSMode;
    CertFile: string;
    KeyFile: string;
    RootCertFile: string;
    CertHash: string;         // For Windows Cert Store / http.sys
    StoreName: string;        // Default 'MY'
    Protocols: TDextTLSVersions;
    VerifyServerCertificate: Boolean;
    ALPNProtocols: TArray<string>; // e.g. ['h2', 'http/1.1', 'redis']
    Provider: string;         // 'Auto', 'OpenSSL', 'HttpSys', 'Indy'
  end;
```

### 3.2 Interfaces
- **`IDextTLSContextProvider`**: Factory interface responsible for creating and configuring SSL contexts (loading keys, certificates, ALPN, and SSL methods).
- **`IDextTLSEngine`**: Asynchronous/Memory-based TLS processing engine. Consumes encrypted incoming wire data and produces plaintext data (and vice-versa) using OpenSSL memory BIOs (`BIO_s_mem`).
- **`IDextTLSStream`**: Synchronous or Task-based wrapper stream over standard `TStream` or raw socket file descriptors.

---

## 4. Specific Implementations & Integrations

### 4.1 Native OpenSSL Engine (Epoll / IOCP / Raw Sockets / Redis)
- **File**: `Dext.Net.Security.OpenSSL.pas`
- Encapsulates dynamic loading of OpenSSL (`libssl` / `libcrypto`, supporting 1.1.1 and 3.x).
- Uses `BIO_s_mem` pairs (`rbio`, `wbio`) so network IO reads encrypted data into `rbio`, `SSL_read` extracts plaintext, `SSL_write` puts plaintext into `wbio`, and `BIO_read` extracts encrypted data for socket transmission.

### 4.2 Windows `http.sys` Native Security
- **File**: `Dext.Server.HttpSys.pas`
- Configures SSL bindings using Windows HTTPS HTTP API parameters (`HTTP_SERVICE_CONFIG_SSL_SET`) or binds port to certificate thumbprints in the Windows Certificate Store.

### 4.3 Redis Client SSL (`TDextRedisClient`)
- **File**: `Dext.Net.Redis.pas`
- Updates `TDextRedisOptions` with `.UseSsl(True)` and `.SslOptions(...)`.
- When SSL is enabled, `TDextRedisClient` wraps its underlying TCP socket stream with `IDextTLSStream` during initial connection prior to issuing `AUTH` / `PING`.

### 4.4 REST Client HTTPS (`TRestClient`)
- **File**: `Dext.Net.RestClient.pas`
- Provides unified SSL certificate validation callbacks, TLS options, and automatic handling of `https://` URLs using the default system or OpenSSL TLS engine.

---

## 5. Implementation Phases & Milestones

- [ ] **Phase 1: Architecture & Abstraction (`Dext.Net.Security.pas`)**
  - Define `IDextTLSContextProvider`, `IDextTLSEngine`, `IDextTLSStream`, `TDextTLSOptions`.
  - Add unified configuration integration into `IConfiguration` / `appsettings.json`.
- [ ] **Phase 2: OpenSSL Engine & Redis Client Support**
  - Implement `Dext.Net.Security.OpenSSL.pas` (OpenSSL 1.1/3.x Memory BIOs).
  - Implement `TDextRedisClient` SSL connection capability (`rediss://`).
- [ ] **Phase 3: Native Web Server SSL Integration**
  - Implement Windows `http.sys` native SSL binding.
  - Integrate `IDextTLSEngine` into `TDextEpollEngine` and `TDextIocpEngine`.
  - Fix and update `Web.SslDemo` example to run natively on HTTPS with both http.sys and epoll.
- [ ] **Phase 4: Optimization, Permessage-Deflate & MessagePack**
  - Implement MessagePack Hub Protocol (`Dext.Web.Hubs.Protocol.MessagePack.pas`).
  - Implement WebSocket Permessage-Deflate (RFC 7692).

---

*Updated by Cesar Romero & Antigravity AI — July 2026*
