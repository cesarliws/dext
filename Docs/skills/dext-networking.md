---
name: dext-networking
description: Make HTTP, REST, TCP, UDP and MQTT connections from Delphi using the Dext NET client/server stack. Use when implementing low-level socket communication, custom protocols, or MQTT messaging.
---

# Dext Networking (REST, Sockets, and MQTT)

Fluent REST client, high-performance low-level TCP/UDP sockets, and native MQTT v3.1.1 messaging.

## Core Import

```pascal
uses
  Dext.Net.RestClient,   // TRestClient
  Dext.Net.RestRequest,  // Fluent request builder
  Dext.Threading.Async;  // TAsyncTask integration
```

> `TRestClient` is a **record** — create cheaply, no `.Free` needed. It shares a thread-safe connection pool internally.

## Basic Usage

```pascal
var Client := TRestClient.Create('https://api.example.com');

// Fire-and-forget style
Client.Get('/users/1')
  .OnComplete(procedure(Res: IRestResponse)
    begin
      WriteLn('Status: ', Res.StatusCode);
      WriteLn('Body: ', Res.ContentString);
    end)
  .Start;
```

## HTTP Methods

```pascal
Client.Get('/resource');
Client.Post('/resource');
Client.Put('/resource');
Client.Delete('/resource');
Client.Patch('/resource');
```

## Building Requests

```pascal
// Headers and query parameters
Client.Get('/search')
  .Header('Authorization', 'Bearer ' + Token)
  .Header('X-Custom', 'Value')
  .QueryParam('q', 'delphi')
  .QueryParam('page', '1')
  .Start;

// JSON body (auto-serialized)
var User := TUser.Create('Alice');
try
  Client.Post('/users')
    .Body(User)     // Serialized to JSON automatically
    .Start;
finally
  User.Free;
end;

// Raw JSON string
Client.Post('/data')
  .JsonBody('{"name":"test"}')
  .Start;

// Stream body (file upload)
Client.Post('/upload')
  .Body(FileStream)
  .Start;
```

## Typed Responses (Auto-Deserialization)

```pascal
// Generic typed response
Client.Get<TUser>('/users/1')
  .OnComplete(procedure(User: TUser)
    begin
      WriteLn('User: ', User.Name);
    end)
  .Start;

// List response
Client.Get<IList<TUser>>('/users')
  .OnComplete(procedure(Users: IList<TUser>)
    begin
      for var U in Users do WriteLn(U.Name);
    end)
  .Start;
```

## Synchronous Execution

Block the current thread and wait for the result (use in console apps or background workers):

```pascal
var User := Client.Get<TUser>('/users/1').Await;
WriteLn(User.Name);

var Res := Client.Post('/data').JsonBody('{}').Await;
WriteLn(Res.StatusCode);
```

## Task Chaining

```pascal
Client.Get<TToken>('/auth/token')
  .ThenBy<TUser>(function(Token: TToken): TUser
    begin
      Result := Client.Get('/profile')
        .Header('Authorization', Token.AccessToken)
        .Execute<TUser>
        .Await;
    end)
  .OnComplete(procedure(User: TUser)
    begin
      UpdateUI(User);  // UI thread
    end)
  .Start;
```

## Cancellation

```pascal
var CTS := TCancellationTokenSource.Create;

Client.Get('/long-process')
  .Cancellation(CTS.Token)
  .Start;

// Later
CTS.Cancel;
```

## Authentication Providers

```pascal
// Bearer token (JWT)
Client.Authenticator(TBearerAuthProvider.Create('my-jwt-token'));

// Basic auth
Client.Authenticator(TBasicAuthProvider.Create('user', 'password'));

// API key in header
Client.Authenticator(TApiKeyAuthProvider.Create('X-API-Key', 'secret'));
```

## Response Object

```pascal
IRestResponse = interface
  StatusCode: Integer;         // 200, 404, etc.
  ContentString: string;       // Raw body as string
  ContentStream: TStream;      // Body as stream
  Headers: TStrings;           // Response headers
  IsSuccess: Boolean;          // StatusCode in 200-299
end;
```

## Error Handling

```pascal
Client.Get('/data')
  .OnComplete(procedure(Res: IRestResponse)
    begin
      if Res.IsSuccess then
        Process(Res.ContentString)
      else
        WriteLn('Error: ', Res.StatusCode);
    end)
  .OnException(procedure(Ex: Exception)
    begin
      WriteLn('Network error: ', Ex.Message);
    end)
  .Start;
```

## Connection Pool

`TRestClient` uses a shared `TConnectionPool` internally:
- Reuses `THttpClient` instances — no TCP/SSL overhead per request
- Fully thread-safe — safe to share across threads
- Automatic stale connection cleanup

No configuration needed; pooling is on by default.

## Legacy Delphi Compatibility & Indy Fallback

When compiling on legacy Delphi compilers (Delphi XE2 to XE7), `Dext.Net` replaces the native `THttpClient` engine with an Indy-based `TIdHTTP` engine (`TDextIndyHttpEngine`) automatically.

- **OpenSSL Requirement**: When Indy fallback is active (on legacy compilers or if forced via define `DEXT_FORCE_INDY`), HTTPS requests require OpenSSL DLLs (`ssleay32.dll` and `libeay32.dll` on Windows) to be present in the executable directory or path.

## DI Registration

Register as singleton for the best pool reuse:

```pascal
Services.AddSingleton<IExternalApiClient, TExternalApiClient>(
  function(P: IServiceProvider): TObject
  begin
    Result := TExternalApiClient.Create(
      TRestClient.Create('https://api.external.com'));
  end);
```

## Low-Level Sockets (TCP & UDP)

For low-level socket protocol implementation, use native non-blocking server and client modules.

### TCP Server and Client

```pascal
uses
  Dext.Net.Tcp,
  Dext.Core.Span;

// Server
var Server := TDextTcpServer.Create;
Server.OnDataSpan := procedure(const Connection: ITcpConnection; const Data: TByteSpan)
  begin
    Connection.Send(Data); // Echo
  end;
Server.Bind('0.0.0.0', 8080);
Server.Start;

// Client
var Client := TDextTcpClient.Create;
Client.Connect('127.0.0.1', 8080);
Client.Send(TBytes.Create($01, $02));
var Buffer: TBytes;
SetLength(Buffer, 1024);
var ReadLen := Client.Receive(Buffer, 2000);
```

### Protocol Decoupling (IConnectionHandler)

Implement `IConnectionHandler` to decouple raw network operations from HTTP processing inside the core IOCP/Epoll engine:

```pascal
uses
  Dext.Server.Engine.Interfaces,
  Dext.Core.Span;

type
  TCustomProtoHandler = class(TInterfacedObject, IConnectionHandler)
  public
    procedure OnConnect(const Connection: IDextTransportConnection);
    procedure OnDisconnect(const Connection: IDextTransportConnection);
    procedure OnData(const Connection: IDextTransportConnection; const Span: TByteSpan);
    procedure OnError(const Connection: IDextTransportConnection; Ex: Exception);
  end;
```

---

## Native MQTT v3.1.1 (Client & Broker)

`Dext.Net` includes a native pub/sub message router, client, and broker server.

```pascal
uses
  Dext.Net.Mqtt;

// Broker Server
var Broker := TDextMqttServer.Create;
Broker.Bind('0.0.0.0', 1883);
Broker.Start;

// Client
var Client := TDextMqttClient.Create;
Client.Connect('127.0.0.1', 1883, 'MyDelphiClient');
Client.OnMessageReceived := procedure(const Msg: TMqttMessage)
  begin
    WriteLn('Received: ', Msg.Topic, ' - ', Length(Msg.Payload), ' bytes');
  end;
Client.Subscribe('sensors/+/status');
Client.Publish('sensors/kitchen/status', TEncoding.UTF8.GetBytes('online'));
```



