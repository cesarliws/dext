# Delphi Hub Client

Dext Framework provides a high-performance native SignalR client for Delphi, enabling Desktop (VCL/FMX) or console applications to connect to Dext Hubs or compatible ASP.NET Core SignalR servers.

> 📦 **Example**: [Hub Client Tests](../../../Tests/Hubs/Dext.Web.Hubs.Client.Tests.pas)

## Key Features

- **Multi-Transport Support**: Native high-performance WebSockets and Server-Sent Events (SSE).
- **Automatic Negotiation**: Negotiates the preferred transport and protocol format (JSON).
- **Threading / Marshaling Management**: Option for automatic main-thread (UI Thread) marshaling, allowing safe updates to VCL/FMX visual controls.
- **Heartbeat & Ping**: Automatically sends ping messages to keep the connection alive and detect disconnects.
- **Fluent API (Fluent Builder)**: Simplified connection configuration.

---

## Configuration & Connecting

Use the `TDextHubConnectionBuilder` class to create and configure the connection.

```pascal
uses
  Dext.Web.Hubs.Client,
  Dext.Web.Hubs.Client.Types;

var
  LConnection: IDextHubConnection;
begin
  LConnection := TDextHubConnectionBuilder.New
    .WithUrl('http://localhost:8080/hubs/chat')
    .WithTransport(ctWebSocket) // Prefers WebSocket (ctWebSocket or ctServerSentEvents)
    .WithHeader('Authorization', 'Bearer token_here') // Custom headers
    .WithQueryParam('userId', '123') // Query parameters
    .WithUIThreadMarshaling(True) // Redirects callbacks to Main Thread (UI)
    .Build;

  // Register Status Callbacks
  LConnection.OnConnected(
    procedure(const AConnectionId: string)
    begin
      ShowMessage('Connected with ID: ' + AConnectionId);
    end);

  LConnection.OnDisconnected(
    procedure(const AError: Exception)
    begin
      if Assigned(AError) then
        ShowMessage('Disconnected due to error: ' + AError.Message)
      else
        ShowMessage('Cleanly disconnected.');
    end);

  // Start the Connection Asynchronously
  LConnection.Start;
end;
```

---

## Receiving Server Messages

To listen for event/method calls triggered by the server, use the `On` methods.

### 1. With Simple Arguments (Common Overloads)

```pascal
// Receiving 1 string from the server
LConnection.On('ReceiveMessage',
  procedure(const AMessage: string)
  begin
    MemoLog.Lines.Add(AMessage);
  end);

// Receiving 2 strings from the server
LConnection.On('ReceiveComplexMessage',
  procedure(const AUser, AMessage: string)
  begin
    MemoLog.Lines.Add(AUser + ': ' + AMessage);
  end);
```

### 2. With Generic or Complex Arguments

If the server sends multiple arguments of different types, you can implement the `IHubCallback` interface to decode values manually.

---

## Sending Messages to the Server

### 1. Send without response (Fire-and-forget)
Use the `Send` method to invoke a server method without waiting for a return value.

```pascal
LConnection.Send('SendMessage', ['Delphi_User', 'Hello from Delphi VCL!']);
```

### 2. Invoke expecting a response (Call with Return Value)
To invoke methods that return a value from the server asynchronously, use the static generic helper `TConnectionHelper.Invoke<T>`.

```pascal
TConnectionHelper.Invoke<string>(
  LConnection, 
  'CalculateHash', 
  ['text_to_hash'],
  procedure(const AResult: string; const AError: Exception)
  begin
    if Assigned(AError) then
      ShowMessage('Error: ' + AError.Message)
    else
      ShowMessage('Calculated Hash: ' + AResult);
  end
);
```

---

## Lifecycle & Tear Down

To stop the connection and clean up associated resources (such as sockets and ping/reader threads):

```pascal
LConnection.Stop;
```

---

[← Real-Time](README.md) | [Next: Testing →](../08-testing/README.md)
