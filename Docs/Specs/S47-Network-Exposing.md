# Spec S47: Expose TCP/UDP & MQTT Server/Client

**Status: ✅ Approved & Implemented**  
**Owner:** Cesar Romero & Engineering Team  
**Created:** 2026-06-28  
**Dependencies:** S39 (Native Server Engine)  
**Enables:** High-performance IoT gateways, raw TCP/UDP messaging, native MQTT client/server without third-party dependencies (CrossSocket, Indy, etc.).

---

## 1. Overview & Context

Currently, the Dext Framework implements native, high-performance, kernel-level I/O engines (`IOCP` on Windows and `epoll` on Linux) inside the `Dext.Server` layer. However, this infrastructure is tightly coupled to standard HTTP/1.1 parsing and WebSocket handshakes. All socket descriptors, connection loops, and raw buffers are processed internally and cannot be used for generic TCP/UDP workloads or IoT protocols.

In industrial automation, telematics, and Internet of Things (IoT) systems, developers must support raw socket streams (TCP/UDP) and lightweight broker-based protocols like **MQTT (Message Queuing Telemetry Transport)**.

This specification defines how Dext will:
1. **Refactor and Decouple** the core IOCP/Epoll engines to support arbitrary protocol handlers.
2. **Expose generic TCP** servers and clients.
3. **Expose generic UDP** servers and clients.
4. **Implement a native MQTT** client and server (broker) directly on top of the newly decoupled high-performance TCP engine.

---

## 2. Industry Reference Architecture

### A. ASP.NET Core Connection Abstractions
In modern .NET, Kestrel (the web server) is built on top of `Microsoft.AspNetCore.Connections.Abstractions`. 
- A connection is represented by a `ConnectionContext`.
- It exposes a `PipeReader` and `PipeWriter` for asynchronous stream processing.
- This allows developers to build custom TCP/UDP servers (such as Bedrock.Framework or custom MQTT brokers) directly on Kestrel's I/O transport layer without writing low-level Socket select loops.

### B. Java Netty
Netty separates transport (IOCP, epoll, kqueue) from logic using a `ChannelPipeline` and `ChannelHandler`. 
- Data flows through a series of handlers (e.g., `ByteToMessageDecoder`, `MessageToByteEncoder`).
- For MQTT, Netty provides `MqttDecoder` and `MqttEncoder`, which convert raw byte buffers into typed MQTT packet objects.

---

## 3. Detailed Architecture & Proposed Changes

### 3.1 Decoupling the Core I/O Engine (TCP Transport Layer)
Currently, `TDextIocpWorker.Execute` and `TDextEpollEngine` read from the socket and immediately call `TDextIocpHttpParser.TryParseRequest`.

We will refactor this structure into a decoupled pipeline:

```
┌────────────────────────────────────────────────────────┐
│             Dext.Server.Engine (IOCP/Epoll)            │
└──────────────────────────┬─────────────────────────────┘
                           │ (Connection & Buffer Events)
                           ▼
              [IDextTransportConnection]
              - Send(const ABuffer: TBytes)
              - Close()
                           │
         ┌─────────────────┼──────────────────┐
         ▼                 ▼                  ▼
┌─────────────────┐ ┌───────────────┐ ┌───────────────┐
│ HTTP/WebSocket  │ │  Raw TCP      │ │  MQTT Broker/ │
│ ProtocolHandler │ │  Server/Client│ │  Client       │
└─────────────────┘ └───────────────┘ └───────────────┘
```

#### Refactoring Steps:
1. Introduce `IDextTransportConnection` to represent a generic, thread-safe network channel.
2. Expose a generic `IConnectionHandler` interface:
   ```pascal
   type
     IConnectionHandler = interface
       ['{A672F8B0-4A0B-4712-A3DF-8BFCE48FA472}']
       procedure OnConnect(const AConnection: IDextTransportConnection);
       procedure OnDisconnect(const AConnection: IDextTransportConnection);
       procedure OnData(const AConnection: IDextTransportConnection; const ABuffer: TBytes; ALength: Integer);
       procedure OnError(const AConnection: IDextTransportConnection; AException: Exception);
     end;
   ```
3. Update `TDextIocpEngine` and `TDextEpollEngine` to accept an `IConnectionHandler` rather than internally tying the socket read loops to HTTP parsers. The HTTP stack will become an implementation of `IConnectionHandler`.

---

## 3.2 TCP Server & Client API Design

We will introduce `Dext.Net.Tcp` containing the high-performance wrappers:

```pascal
type
  ITcpConnection = interface(IDextTransportConnection)
    ['{E3C2B6A1-9F0D-47C1-B6C2-EA15C3847BE2}']
    function GetConnectionId: UInt64;
    function GetRemoteAddress: string;
    function GetRemotePort: Word;
    procedure Send(const ABuffer: TBytes); overload;
    procedure Send(const AStream: TStream); overload;
    procedure Close;
    property ConnectionId: UInt64 read GetConnectionId;
    property RemoteAddress: string read GetRemoteAddress;
    property RemotePort: Word read GetRemotePort;
  end;

  TTcpConnectionEvent = reference to procedure(const AConnection: ITcpConnection);
  TTcpDataEvent = reference to procedure(const AConnection: ITcpConnection; const AData: TBytes);

  TDextTcpServer = class
  private
    FEngine: IDextServerEngine;
    FOnConnect: TTcpConnectionEvent;
    FOnDisconnect: TTcpConnectionEvent;
    FOnData: TTcpDataEvent;
  public
    constructor Create(const AOptions: TServerEngineOptions);
    destructor Destroy; override;
    procedure Bind(const AAddress: string; APort: Word);
    procedure Start;
    procedure Stop;
    property OnConnect: TTcpConnectionEvent read FOnConnect write FOnConnect;
    property OnDisconnect: TTcpConnectionEvent read FOnDisconnect write FOnDisconnect;
    property OnData: TTcpDataEvent read FOnData write FOnData;
  end;

  TDextTcpClient = class
  private
    FSocket: TSocket;
    // Client-side IOCP/Epoll handler integration for non-blocking read
  public
    constructor Create;
    destructor Destroy; override;
    procedure Connect(const AAddress: string; APort: Word);
    procedure Disconnect;
    procedure Send(const ABuffer: TBytes);
    function Receive(var ABuffer: TBytes; ATimeoutMs: Integer = 5000): Integer;
  end;
```

---

## 3.3 UDP Server & Client API Design

UDP runs without connection states. The I/O engine must bind to `SOCK_DGRAM` and handle packet dispatching:

```pascal
type
  TUdpPacket = record
    RemoteAddress: string;
    RemotePort: Word;
    Data: TBytes;
  end;

  TUdpPacketEvent = reference to procedure(const APacket: TUdpPacket);

  TDextUdpServer = class
  public
    constructor Create(const AOptions: TServerEngineOptions);
    procedure Bind(const AAddress: string; APort: Word);
    procedure Start;
    procedure Stop;
    procedure SendTo(const AAddress: string; APort: Word; const AData: TBytes);
    property OnPacketReceived: TUdpPacketEvent read FOnPacketReceived write FOnPacketReceived;
  end;

  TDextUdpClient = class
  public
    procedure Send(const AAddress: string; APort: Word; const AData: TBytes);
    function Receive(out APacket: TUdpPacket; ATimeoutMs: Integer = 5000): Boolean;
  end;
```

---

## 3.4 MQTT Client & Server (Broker) Architecture

MQTT v3.1.1 and v5.0 are binary-framed packet protocols. Dext will provide a native parser inside `Dext.Net.Mqtt.Parser.pas` that encodes and decodes packets without heap allocations where possible.

### MQTT Control Packet Types:
- **CONNECT / CONNACK**: Handshake and session initiation.
- **PUBLISH / PUBACK / PUBREC / PUBREL / PUBCOMP**: Message publishing with QoS 0 (At most once), QoS 1 (At least once), and QoS 2 (Exactly once).
- **SUBSCRIBE / SUBACK**: Subscription to topic filters.
- **UNSUBSCRIBE / UNSUBACK**: Removal of subscriptions.
- **PINGREQ / PINGRESP**: Keep-alive ping mechanism.
- **DISCONNECT**: Clean disconnection.

### Broker Subscription Wildcard Matching:
The Broker (`TDextMqttServer`) must support:
- Single-level wildcard `+` (e.g. `sensors/+/temperature` matches `sensors/kitchen/temperature`).
- Multi-level wildcard `#` (e.g. `sensors/#` matches `sensors/kitchen/temperature` and `sensors/garden/humidity`).
- These filters will be resolved using an optimized trie-based prefix tree structure (`TDextMqttTopicTrie`).

```pascal
type
  TMqttMessage = record
    Topic: string;
    Payload: TBytes;
    QoS: Byte;
    Retain: Boolean;
  end;

  TMqttMessageEvent = reference to procedure(const AMessage: TMqttMessage);

  TDextMqttClient = class
  public
    constructor Create;
    destructor Destroy; override;
    procedure Connect(const AHost: string; APort: Word; const AClientId: string = '');
    procedure Disconnect;
    procedure Publish(const ATopic: string; const APayload: TBytes; AQoS: Byte = 0; ARetain: Boolean = False);
    procedure Subscribe(const ATopicFilter: string; AQoS: Byte = 0);
    procedure Unsubscribe(const ATopicFilter: string);
    property OnMessageReceived: TMqttMessageEvent read FOnMessageReceived write FOnMessageReceived;
  end;

  TDextMqttServer = class
  private
    FTcpServer: TDextTcpServer;
    // Session state dictionary and topic trie tree
  public
    constructor Create(const AOptions: TServerEngineOptions);
    destructor Destroy; override;
    procedure Start;
    procedure Stop;
    // Broker event hooks (auth callbacks, client connected, etc.)
  end;
```

---

## 4. Implementation Difficulty & Impact Analysis

### Difficulty:
- **Refactoring I/O Engine**: **Medium-High**. The risk of regression in the existing HTTP/1.1 and WebSocket engines is present. Complete code separation with abstract handlers is required.
- **TCP/UDP Wrappers**: **Medium**. Simple binding of system sockets to the IOCP/epoll selectors.
- **MQTT Parser**: **Medium**. Binary parsing of the MQTT protocol is straightforward but requires meticulous unit tests.
- **MQTT Broker**: **High**. Managing concurrent sessions, connection timeouts (keep-alive), client message queues, and QoS 1/2 state validation requires significant threading stability and validation.

### Impact:
- Opens up Dext for IoT gateways, edge routers, SCADA systems, and embedded long-lived TCP connection services.
- Replaces complex third-party stacks, allowing 100% native Pascal compile-once deploy-anywhere setups on Linux/Windows.

### 4.5 Impacted Codebase Files

The implementation of S47 will affect the following existing files and introduce new components:

#### Modified Files (Refactoring Core I/O Engine)
- [Dext.Server.Engine.Interfaces.pas](file:///c:/dev/Dext/DextRepository/Sources/Server/Dext.Server.Engine.Interfaces.pas) - Modify to introduce generic `IDextTransportConnection` and `IConnectionHandler` interfaces, separating them from the HTTP-specific request handlers.
- [Dext.Server.Iocp.pas](file:///c:/dev/Dext/DextRepository/Sources/Server/Dext.Server.Iocp.pas) - Decouple the Windows IOCP worker loops from HTTP parsing, forwarding events to the configured `IConnectionHandler`.
- [Dext.Server.Epoll.pas](file:///c:/dev/Dext/DextRepository/Sources/Server/Dext.Server.Epoll.pas) - Decouple the Linux Epoll worker loops from HTTP parsing, forwarding events to the configured `IConnectionHandler`.

#### New Files (TCP/UDP & MQTT Protocol Layer)
- `[NEW]` [Dext.Net.Tcp.pas](file:///c:/dev/Dext/DextRepository/Sources/Net/Dext.Net.Tcp.pas) - Implementation of raw TCP server (`TDextTcpServer`), client (`TDextTcpClient`), and connection wraps.
- `[NEW]` [Dext.Net.Udp.pas](file:///c:/dev/Dext/DextRepository/Sources/Net/Dext.Net.Udp.pas) - Implementation of raw UDP server (`TDextUdpServer`) and client (`TDextUdpClient`).
- `[NEW]` [Dext.Net.Mqtt.Parser.pas](file:///c:/dev/Dext/DextRepository/Sources/Net/Dext.Net.Mqtt.Parser.pas) - High-performance MQTT control packet binary encoder/decoder.
- `[NEW]` [Dext.Net.Mqtt.pas](file:///c:/dev/Dext/DextRepository/Sources/Net/Dext.Net.Mqtt.pas) - Implementation of `TDextMqttClient`, `TDextMqttServer` (Broker), and subscription trie pattern.

#### Testing & Verification Files
- `[NEW]` [Dext.Net.TcpTests.pas](file:///c:/dev/Dext/DextRepository/Tests/Server/Dext.Net.TcpTests.pas) - Unit and integration tests for the new TCP/UDP and MQTT layers.

---


## 5. Verification Plan

### 5.1 Automated Unit Tests
- **TCP Roundtrip Loop**: Spin up `TDextTcpServer` on dynamic port (`Port 0`), connect with `TDextTcpClient`, exchange 100MB of random payloads, verify integrity, and check for memory leaks.
- **UDP Echo**: Test packet sending and receiving using `TDextUdpServer` and `TDextUdpClient`.
- **MQTT Parser Suite**: Validate parser against standard MQTT binary payloads (handshake packets, QoS-framed publishes) to verify correct field extraction.
- **Trie Pattern Matcher**: Unit tests validating wildcard topic match results (`+`, `#`, system topics).

### 5.2 Manual Integration Verification
- Connect `TDextMqttClient` to a local Mosquitto Broker. Publish and subscribe to topics.
- Connect a Python/JS MQTT client (e.g. `paho-mqtt`) to `TDextMqttServer` (Broker), run stress testing tool (`mqtt-benchmark`) to measure throughput and memory overhead on Windows and Linux under 10k connections.

---
*Created by Cesar Romero & Antigravity AI — June 2026*
