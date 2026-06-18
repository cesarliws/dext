---
name: dext-realtime
description: Add real-time two-way communication to Dext Web APIs using SignalR-compatible Hubs over WebSockets. Use when building chat, notifications, live dashboards, or any server-push feature.
---

# Dext Real-Time (Hubs)

SignalR-compatible WebSocket abstraction. Server can push messages to clients; clients can invoke server methods.

## Core Import

```pascal
uses
  Dext.Web.Hubs; // THub, [HubName], Clients
```

## Define a Hub

```pascal
type
  [HubName('notifications')]
  TNotificationHub = class(THub)
  public
    // Called BY the client
    procedure SendGlobal(Msg: string);
    procedure JoinRoom(RoomId: string);
    procedure SendToRoom(RoomId, Msg: string);
  end;

procedure TNotificationHub.SendGlobal(Msg: string);
begin
  // Push to ALL connected clients
  Clients.All.Invoke('ReceiveNotification', [Msg]);
end;

procedure TNotificationHub.JoinRoom(RoomId: string);
begin
  Groups.Add(Context.ConnectionId, RoomId);
end;

procedure TNotificationHub.SendToRoom(RoomId, Msg: string);
begin
  Clients.Group(RoomId).Invoke('NewMessage', [Msg]);
end;
```

## Client Targeting

```pascal
Clients.All.Invoke('Method', [Args]);             // All connected clients
Clients.Caller.Invoke('Confirmation', ['OK']);     // Only the sender
Clients.Group('room-123').Invoke('Msg', [Data]);   // A named group
Clients.User('user-guid').Invoke('Private', [Msg]); // Specific user
```

## Connection Lifecycle

```pascal
procedure TNotificationHub.OnConnected;
begin
  WriteLn('Client connected: ', Context.ConnectionId);
  // e.g. auto-join a group
  Groups.Add(Context.ConnectionId, 'global');
end;

procedure TNotificationHub.OnDisconnected(Exception: Exception);
begin
  WriteLn('Disconnected: ', Context.ConnectionId);
  if Exception <> nil then
    WriteLn('Reason: ', Exception.Message);
end;
```

## Register Hub in Pipeline

```pascal
// In Startup Configure (or equivalent)
App.Builder
  .UseExceptionHandler
  .UseAuthentication
  .MapHub<TNotificationHub>('/hubs/notifications')
  .MapControllers
  .UseSwagger(...);
```

## JavaScript Client (Browser)

Dext includes a lightweight native JS client (`dext-hubs.js`) supporting WebSockets (`webSockets`) and Server-Sent Events (`serverSentEvents`):

```javascript
import { DextHubConnection } from './dext-hubs.js';

const connection = new DextHubConnection('/hubs/notifications', {
  transport: 'webSockets' // 'webSockets' (default) or 'serverSentEvents'
});

// Listen for server push
connection.on('ReceiveNotification', (msg) => {
  console.log('Notification:', msg);
});

// Start connection
await connection.start();

// Invoke server method
await connection.invoke('SendGlobal', 'Hello!');
```

You can also use the standard ASP.NET Core SignalR client library if needed.

## Push from Outside a Hub (Background Service)

Inject `IHubContext<TMyHub>` to push messages from services or background workers:

```pascal
type
  TAlertService = class(TInterfacedObject, IAlertService)
  private
    FHubContext: IHubContext<TNotificationHub>;
  public
    constructor Create(HubContext: IHubContext<TNotificationHub>);
    procedure SendAlert(Msg: string);
  end;

procedure TAlertService.SendAlert(Msg: string);
begin
  FHubContext.Clients.All.Invoke('ReceiveNotification', [Msg]);
end;
```

Register:
```pascal
Services.AddScoped<IAlertService, TAlertService>;
// IHubContext<T> is auto-registered when MapHub<T> is used
```

## Groups API

```pascal
Groups.Add(Context.ConnectionId, 'group-name');    // Add to group
Groups.Remove(Context.ConnectionId, 'group-name'); // Remove from group
```

## Delphi Hub Client (Desktop/VCL/FMX)

For Delphi client applications, use `TDextHubConnectionBuilder` to configure a full-duplex client.

### Core Client Imports

```pascal
uses
  Dext.Web.Hubs.Client,
  Dext.Web.Hubs.Client.Types;
```

### Config and Connect

```pascal
var
  LConn: IDextHubConnection;
begin
  LConn := TDextHubConnectionBuilder.New
    .WithUrl('http://localhost:8080/hubs/notifications')
    .WithTransport(ctWebSocket) // ctWebSocket or ctServerSentEvents
    .WithHeader('Authorization', 'Bearer token')
    .WithQueryParam('deviceId', 'XYZ')
    .WithUIThreadMarshaling(True) // Marshals callbacks to the Main UI Thread
    .Build;

  // Listen to connection status
  LConn.OnConnected(procedure(const ConnId: string) begin ... end);
  LConn.OnDisconnected(procedure(const Err: Exception) begin ... end);

  // Listen to server events
  LConn.On('ReceiveNotification', procedure(const Msg: string)
    begin
      // Safe to update UI directly since WithUIThreadMarshaling is True
      ShowMessage(Msg);
    end);

  LConn.Start;
end;
```

### Send & Invoke (Client to Server)

```pascal
// Fire-and-forget:
LConn.Send('SendGlobal', ['Hello from Delphi Client!']);

// Invoke expecting typed return value:
TConnectionHelper.Invoke<string>(
  LConn,
  'CalculateHash',
  ['input_string'],
  procedure(const Result: string; const Error: Exception)
  begin
    if Error <> nil then
      ShowMessage('Error: ' + Error.Message)
    else
      ShowMessage('Result: ' + Result);
  end
);
```


