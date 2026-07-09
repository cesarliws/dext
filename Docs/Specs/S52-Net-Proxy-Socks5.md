# 📑 S52: SOCKS5 Proxy Client & Server Specification

**Status:** 📝 Draft  
**Owner:** Cesar Romero & Engineering Team  
**Reviewers:** Architecture Team, Community  
**Created:** 2026-07-08  
**Last Updated:** 2026-07-08  
**Dependencies:** S39 (Native Server Engine), S43 (Net-Advanced - Native TLS)

---

## 1. Goal

Provide support for SOCKS5 proxying (RFC 1928) in Dext. This includes a 
production-ready client implementation supporting username/password 
authentication, SOCKS5h (remote DNS), Socks over TLS, and automatic 
reconnection, as well as laying out the backlog architecture for a future 
SOCKS5 server and UDP tunneling support.

This is highly requested for enterprise setups, secure IoT gateways, and 
private networking topologies.

---

## 2. Technical Architecture

### 2.1 Scope Segmentation

To maximize time-to-market and focus on high-impact features, the project is
divided into two distinct phases:

```
┌────────────────────────────────────────────────────────┐
│ Phase 1: SOCKS5 Client (Core Target)                   │
├────────────────────────────────────────────────────────┤
│ - TCP CONNECT command (RFC 1928)                       │
│ - Username/Password Auth (RFC 1929)                    │
│ - SOCKS5h (Remote DNS resolution)                      │
│ - Socks over TLS (Encrypted proxy tunnel)              │
│ - Auto-reconnection & pipeline integration            │
└────────────────────────────────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│ Phase 2: SOCKS5 Server & Advanced features (Backlog)   │
├────────────────────────────────────────────────────────┤
│ - SOCKS5 Server Engine (Multi-threaded / Async)        │
│ - UDP ASSOCIATE command (UDP tunneling)                │
│ - Connection Multiplexing                              │
│ - Client Certificate Authentication                    │
└────────────────────────────────────────────────────────┘
```

---

## 3. Phase 1: Client Architecture & Integration

The SOCKS5 client will be integrated directly into the `Dext.Net` socket 
pipeline. When active, it intercepts the raw connection establishment before 
handing control over to higher-level protocols (HTTP/1.1, HTTP/2, gRPC, 
WebSockets, or MQTT).

### 3.1 Connection Handshake Flow (Socks over TLS)

When SOCKS over TLS is enabled, the TLS handshake is performed *before* the 
SOCKS5 negotiation begins.

```
Client                     Proxy Server                  Target Host
  │                              │                            │
  │─── [1] TCP Connect ─────────>│                            │
  │─── [2] TLS Handshake ───────>│                            │
  │    (Encrypted Tunnel Est.)   │                            │
  │                              │                            │
  │─── [3] SOCKS5 Greeting ─────>│                            │
  │─── [4] Auth Method Choice ──>│                            │
  │─── [5] Authenticate ────────>│                            │
  │─── [6] CONNECT command ─────>│─── [7] Connect to Target ─>│
  │<── [8] Connect Response ─────│<── [9] Connected ──────────│
  │                              │                            │
  │ <======= Encrypted Data Tunnel (End-to-End Plain/TLS) ====>│
```

### 3.2 Wire Protocol (Client Snippets)

Client initialization sending supported authentication methods (0x00 = No 
Auth, 0x02 = Username/Password):

```
+----+----------+----------+
|VER | NMETHODS | METHODS  |
+----+----------+----------+
| 05 |    02    |  00  02  |
+----+----------+----------+
```

CONNECT Request format targeting remote DNS (ATYP = 0x03):

```
+----+-----+-------+------+----------+----------+
|VER | CMD |  RSV  | ATYP | DST.ADDR | DST.PORT |
+----+-----+-------+------+----------+----------+
| 05 |  01 |  00   |  03  | variable |    2     |
+----+-----+-------+------+----------+----------+
```

### 3.3 Proposed Client Interface

```pascal
type
  TDextSocksVersion = (svSocks5);
  TDextSocksAuth = (saNone, saUserPassword);

  TDextSocks5Client = class
  private
    FHost: string;
    FPort: Word;
    FUseTLS: Boolean;
    FUsername: string;
    FPassword: string;
    FRemoteDNS: Boolean;
    FAutoReconnect: Boolean;
  public
    constructor Create(
      const AHost: string; 
      APort: Word; 
      AUseTLS: Boolean = False
    );
    procedure SetCredentials(
      const AUser, APass: string
    );
    
    // Configures the connection pipeline
    function Establish(
      Socket: TSocket
    ): Boolean;
    
    property RemoteDNS: Boolean 
      read FRemoteDNS write FRemoteDNS;
    property AutoReconnect: Boolean 
      read FAutoReconnect write FAutoReconnect;
  end;
```

---

## 4. Phase 2: Server Architecture (Backlog)

The Server will act as a listener on a designated port. It will utilize the 
asynchronous native server engine (`IOCP` / `epoll`) defined in **S39** to 
handle multiple clients concurrently.

### SOCKS5 Server responsibilities:
1. **Rule Engine & IP ACLs**: Restrict which clients can connect and which 
   target IPs/ports are allowed.
2. **DNS Forwarding**: Resolving hostnames requested by clients locally.
3. **UDP Associate**: Opening a secondary UDP port for relaying UDP packets.
4. **Certificate Setup**: Managing the TLS certificates used to secure the 
   incoming SOCKS connection.

---

## 5. Verification Plan

### Automated Tests
- Integration tests against standard SOCKS5 proxies (Dante, shadowsocks).
- Unit tests validating SOCKS5 greeting, RFC 1929 authentication, and command
  rejections.
- DNS leaks test to ensure `socks5h` uses remote resolution exclusively.

### Manual Verification
- Testing Dext gRPC and MQTT clients routing traffic through SOCKS5 over TLS.
- Intercepting traffic with Wireshark to verify TLS encryption of the proxy
  metadata.
