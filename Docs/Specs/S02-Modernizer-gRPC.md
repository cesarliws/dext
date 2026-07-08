# 📑 S02: Modernizer (gRPC & Protobuf) Specification

**Status:** ✅ Implemented  
**Owner:** Cesar Romero & Engineering Team  
**Reviewers:** Architecture Team
**Created:** 2026-06-17  
**Last Updated:** 2026-07-07
**Dependencies:** S39 (Native Server Engine), S41 (HTTP/2 Framing)
**Enables:** S39 Phase 5 (Integration)

---

## 1. Goal

Provide a high-performance, binary transport alternative to REST/JSON. The goal is to replace legacy connectivity technologies (DataSnap, RDW, RTC, RemObjects) with a modern, cross-platform standard based on gRPC and Protocol Buffers.

This spec details the integration of the gRPC protocol, Protobuf serialization, Code-First class mappings, Proto-First code generation, and the `TEntityDataSet` bridging layer into the Dext ecosystem, aligned with the `IDextServerEngine` interface (S39).

---

## 2. Architecture Overview

```
                      +---------------------------------------+
                      |         gRPC Client App (VCL/FMX)      |
                      |  [TEntityDataSet] <-> [TgRpcClient]  |
                      +---------------------------------------+
                                          |
                                    (gRPC Channel)
                                          |
                                          v
                      +---------------------------------------+
                      |          IDextServerEngine            |
                      |  [DCS / Indy (Dev)] | [Native (Prod)] |
                      +---------------------------------------+
                                          |
                             (application/grpc Route)
                                          |
                                          v
                      +---------------------------------------+
                      |          Dext.Web.Grpc.Server         |
                      |  [gRPC Dispatcher] <-> [TServiceMap]  |
                      +---------------------------------------+
                                          |
                            (Method Invocation & RTTI)
                                          |
                                          v
                      +---------------------------------------+
                      |         gRPC Service Implementor      |
                      |      [TMyGrpcService: IMyService]     |
                      +---------------------------------------+
```

---

## 3. Protocol & Serialization Layer

### 3.1. gRPC Length-Prefixed Message (LPM)

Every gRPC frame is wrapped in a 5-byte header:
- **Compressed-Flag** (1 byte): `0` = uncompressed, `1` = compressed.
- **Message-Length** (4 bytes, Big-Endian): Length of the Protobuf-serialized payload.

```pascal
type
  /// Reader / Writer for gRPC Length-Prefixed Messages
  TGrpcMessageCodec = record
  public
    class function TryDecode(const ABuffer: TBytes; var AOffset: Integer;
      var ACompressed: Boolean; out AMsgBytes: TBytes): Boolean; static;
    class function Encode(const AMsgBytes: TBytes; ACompress: Boolean = False): TBytes; static;
  end;
```

### 3.2. Code-First Protobuf Mapping

Dext gRPC supports defining services and messages using native Delphi classes and interfaces marked with attributes.

```pascal
type
  [GrpcMessage]
  TUserRequest = class
  private
    FUserId: string;
  public
    [ProtoMember(1)]
    property UserId: string read FUserId write FUserId;
  end;

  [GrpcMessage]
  TUserResponse = class
  private
    FUserId: string;
    FName: string;
    FEmail: string;
  public
    [ProtoMember(1)]
    property UserId: string read FUserId write FUserId;
    [ProtoMember(2)]
    property Name: string read FName write FName;
    [ProtoMember(3)]
    property Email: string read FEmail write FEmail;
  end;

  [GrpcService('dext.identity.v1.UserService')]
  IUserService = interface(IInvokable)
    ['{E8F8B6C7-674A-4835-AB37-A3BA476C55AA}']
    [GrpcMethod('GetUser')]
    function GetUser(const ARequest: TUserRequest): TUserResponse;
  end;
```

---

## 4. Server Dispatcher & Pipeline Integration

The gRPC server acts as a middleware or handler registered in the web host pipeline. When the pipeline receives a request with `Content-Type: application/grpc`:

1. The HTTP/2 request is intercepted.
2. The service and method names are parsed from the HTTP path (e.g. `/dext.identity.v1.UserService/GetUser`).
3. The request payload is read, stripped of the 5-byte LPM header, and deserialized into the request class using the Protobuf engine.
4. The service implementation is resolved via the Dependency Injection container (DI) and executed.
5. The response class is serialized, wrapped in a 5-byte LPM header, and sent back inside an HTTP/2 DATA frame.
6. The request terminates with HTTP/2 Headers (Trailers) sending `grpc-status: 0` (OK) or appropriate error code.

```pascal
type
  TDextGrpcDispatcher = class(TInterfacedObject, TRequestDelegate)
  private
    FServiceRegistry: TDictionary<string, TGrpcServiceMeta>;
  public
    procedure Invoke(const AContext: IHttpContext);
    procedure RegisterService(const AInterface: TGUID; const AServiceImpl: TClass);
  end;
```

---

## 5. TEntityDataSet DataProvider

To bridge the traditional Delphi VCL/FMX data-binding world (`TDataSet`) with gRPC, S02 introduces the `TEntitygRpcProvider`.

```pascal
type
  TEntitygRpcProvider<T: class, constructor> = class(TInterfacedObject, IEntityDataProvider<T>)
  private
    FClient: TGrpcClient;
    FServiceName: string;
  public
    constructor Create(AClient: TGrpcClient; const AServiceName: string);
    function FetchAll(const AQuery: string): TList<T>;
    procedure ApplyChanges(const AList: TList<T>);
  end;
```

The `TEntityDataSet` binds directly to `TEntitygRpcProvider`. When the dataset performs operations:
- **Fetch**: Sends a gRPC request, receives a stream of entities (Server Streaming) or an array, and Populates the memory records.
- **ApplyUpdates**: Batches modified, inserted, and deleted records into a gRPC payload and submits them.

---

## 6. Parallel & Phased Work Strategy

By decoupling the high-performance transport (S39/S41) from the gRPC application layer, we enable parallel work between teams:

```
gRPC Team (S02):                        Engine Team (S39/S41):
───────────────────────────────         ───────────────────────────────
1. Protobuf Encoder/Decoder             1. IDextServerEngine API (Phase 1)
2. Service Registry & RTTI              2. http.sys / Epoll Loop (Phase 2-3)
3. TEntitygRpcProvider & Client         3. HTTP/2 Framing (S41)
4. gRPC over DCS / Indy adapter ───+    4. HTTP/2 Stream Multiplexing
                                   |
                                   v
5. Native Engine Integration ◄─────+
```

### Phase 1: Serialization & CodeGen (gRPC Team)
- Implement Protobuf reader/writer and attribute analyzer.
- Create CLI tool `dext compile-proto` to generate Delphi units from `.proto` files.

### Phase 2: Client & Server Abstractions (gRPC Team)
- Implement client channel connectivity.
- Implement server-side service registry and invocation framework.
- Verify using DCS (Delphi-Cross-Socket) wrapper as the temporary transport adapter.

### Phase 3: High-Performance Swapping (Joint Integration)
- Once S39 and S41 are complete, configure `TDextGrpcDispatcher` to run over `IDextServerEngine` with native HTTP/2 stream multiplexing.
- Perform comparison stress tests against Indy and DCS.

---

## 7. Acceptance Criteria

- [ ] Protobuf binary format matches standard Protobuf spec 100% (validated against Python client).
- [ ] A VCL project can populate a `TDBGrid` via gRPC using `TEntityDataSet` and `TEntitygRpcProvider`.
- [ ] Server supports Unary, Server-Streaming, Client-Streaming, and Bi-directional gRPC streaming.
- [ ] Performance shows at least 3x throughput improvement and 50% memory reduction compared to JSON/REST.
- [ ] Seamless integration into `UseNativeServer()` pipeline.

---

*Created by Cesar Romero & Antigravity AI — June 2026*

