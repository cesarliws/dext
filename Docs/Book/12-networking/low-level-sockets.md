# 🌐 Low-Level Sockets (TCP and UDP)

The `Dext.Net` module offers high-performance, non-blocking components for low-level TCP and UDP networking, optimized for maximum throughput and zero heap allocation overhead.

## TCP Server (`TDextTcpServer`)

The `TDextTcpServer` relies on high-performance native engines (IOCP on Windows, Epoll on Linux) allowing concurrent, asynchronous connection handling.

### Echo Server Example
```pascal
var
  Server: TDextTcpServer;
begin
  Server := TDextTcpServer.Create;
  try
    // Set the data event handler
    Server.OnDataSpan :=
      procedure(const AConnection: ITcpConnection; const AData: TByteSpan)
      begin
        // Echoes data back asynchronously
        AConnection.Send(AData);
      end;

    // Bind and start the server
    Server.Bind('127.0.0.1', 8080);
    Server.Start;
    
    Writeln('Server listening on port: ', Server.ListenPort);
    Readln;
    Server.Stop;
  finally
    Server.Free;
  end;
end;
```

---

## TCP Client (`TDextTcpClient`)

The `TDextTcpClient` is a simple, lightweight TCP client that natively supports synchronous reads with configurable timeouts.

```pascal
var
  Client: TDextTcpClient;
  Buffer: TBytes;
  ReadCount: Integer;
begin
  Client := TDextTcpClient.Create;
  try
    Client.Connect('127.0.0.1', 8080);
    
    // Send data
    Client.Send(TBytes.Create($01, $02, $03));
    
    // Receive with a 2000ms timeout
    SetLength(Buffer, 1024);
    ReadCount := Client.Receive(Buffer, 2000);
    
    Client.Disconnect;
  finally
    Client.Free;
  end;
end;
```

---

## UDP Server (`TDextUdpServer`) and Client (`TDextUdpClient`)

The UDP module exposes similar API constructs with native support for broadcast and multicast.

```pascal
// UDP Server
Server := TDextUdpServer.Create;
Server.OnPacketSpanReceived :=
  procedure(const APacket: TUdpSpanPacket)
  begin
    // Send reply to remote address
    Server.SendTo(APacket.RemoteAddress, APacket.RemotePort, APacket.Data);
  end;
Server.Bind('127.0.0.1', 9090);
Server.Start;

// UDP Client
Client := TDextUdpClient.Create;
Client.Send('127.0.0.1', 9090, TBytes.Create($01, $02));
```

---

## Protocol Decoupling (`IConnectionHandler`)

To implement custom wire protocols without HTTP parsing overhead, the core IOCP/Epoll engines can be bound directly to an `IConnectionHandler` interface.

```pascal
type
  TMyHandler = class(TInterfacedObject, IConnectionHandler)
  public
    procedure OnConnect(const AConnection: IDextTransportConnection);
    procedure OnDisconnect(const AConnection: IDextTransportConnection);
    procedure OnData(const AConnection: IDextTransportConnection; const ASpan: TByteSpan);
    procedure OnError(const AConnection: IDextTransportConnection; AException: Exception);
  end;
```
