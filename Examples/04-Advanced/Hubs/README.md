# Dext.Hubs Example

This example demonstrates real-time communication using Dext.Web.Hubs.

## Features Demonstrated

- ✅ Creating a Hub class (`TDemoHub`)
- ✅ Lifecycle methods (`OnConnectedAsync`, `OnDisconnectedAsync`)
- ✅ Broadcasting to all clients
- ✅ Group management (join/leave)
- ✅ Sending to specific groups
- ✅ Server-side push (periodic time updates)
- ✅ JavaScript client integration

## Prerequisites

1. Build the Dext packages in order:
   - `Dext.Core`
   - `Dext.EF.Core`  
   - `Dext.Web.Core`
   - `Dext.Web.Hubs` (or `Dext.Web.Hubs` if renamed)

2. Ensure the packages are in your library path.

## Running the Example

### Build

```powershell
cd ..\..\Examples\04-Advanced\Hubs
dcc32 HubsExample.dpr
```

### Run

```powershell
HubsExample.exe
```

### Access

Open your browser to: **http://localhost:5000**

## What Happens

1. Server starts on port 5000
2. Opens hub endpoint at `/hubs/demo`
3. Serves static HTML from `./wwwroot`
4. Every 5 seconds, broadcasts server time to all clients
5. Clients can:
   - Connect/disconnect
   - Send messages to all users
   - Join/leave groups
   - Send messages to specific groups

## Project Structure

```
Examples/Hubs/
├── HubsExample.dpr        # Main application
├── README.md              # This file
└── wwwroot/
    ├── index.html         # Demo web page
    └── dext-hubs.js       # JavaScript client
```

## Code Highlights

### Creating a Hub

```pascal
type
  TDemoHub = class(THub)
  public
    [HubMethod]
    procedure SendMessage(const User, Message: string);
    [HubMethod]
    procedure JoinGroup(const GroupName: string);
  end;

procedure TDemoHub.SendMessage(const User, Message: string);
begin
  // Broadcast to all connected clients
  Clients.All.SendAsync('ReceiveMessage', [User, Message]);
end;

procedure TDemoHub.JoinGroup(const GroupName: string);
begin
  // Add connection to group
  Groups.AddToGroupAsync(Context.ConnectionId, GroupName);
  
  // Notify caller
  Clients.Caller.SendAsync('JoinedGroup', [GroupName]);
end;
```

### Registering the Hub

```pascal
App.UseHubs;
MapHub(App, '/hubs/demo', TDemoHub);
```

### Sending from Anywhere

```pascal
// Get hub context from anywhere in your code
var Hub := THubExtensions.GetHubContext;

// Send to all clients
Hub.Clients.All.SendAsync('ServerTime', [Now]);

// Send to specific group
Hub.Clients.Group('admins').SendAsync('Alert', ['Important!']);
```

### JavaScript Client

```javascript
const hub = new DextHubConnection('/hubs/demo');

hub.on('ReceiveMessage', (user, message) => {
  console.log(`${user}: ${message}`);
});

await hub.start();
await hub.invoke('SendMessage', 'John', 'Hello!');
```

## Transports

Negotiation advertises WebSockets only when the active HTTP engine supports
upgrade, with Server-Sent Events as the automatic fallback. Long Polling is not
advertised. Authentication credentials and the connection principal are kept
across negotiation, connection, and invocation requests.

## See Also

- [Dext.Web.Hubs Documentation](../../Docs/hubs.md)
- [Implementation Plan](../../Docs/Plans/dext-hubs-implementation-plan.md)
