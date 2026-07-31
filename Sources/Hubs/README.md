# 🔌 Dext.Hubs Package

Real-Time Communication for Dext Framework (SignalR-like).

## Package Information

- **Package Name:** `Dext.Web.Hubs`
- **Dependencies:** `Dext.Core`, `Dext.Web.Core`
- **Type:** Runtime Package (BPL)

## Files Included

```
Sources/
├── Dext.Web.Hubs.dpk                      # Package source
├── Hubs/
│   ├── Dext.Web.Hubs.pas                  # Main exports unit
│   ├── Dext.Web.Hubs.Interfaces.pas       # Core interfaces (SignalR-compatible)
│   ├── Dext.Web.Hubs.Types.pas            # Types, records, exceptions
│   ├── Dext.Web.Hubs.Hub.pas              # THub base class
│   ├── Dext.Web.Hubs.Connections.pas      # TConnectionManager, TGroupManager
│   ├── Dext.Web.Hubs.Clients.pas          # IClientProxy implementations
│   ├── Dext.Web.Hubs.Context.pas          # IHubContext implementation
│   ├── Dext.Web.Hubs.Protocol.Json.pas    # JSON serialization
│   ├── Dext.Web.Hubs.Middleware.pas       # HTTP middleware
│   ├── Dext.Web.Hubs.Extensions.pas       # MapHub, UseHubs extensions
│   ├── Transports/
│   │   └── Dext.Web.Hubs.Transport.SSE.pas # SSE transport
│   └── wwwroot/
│       └── dext-hubs.js               # JavaScript client
```

## Build Instructions

### Option 1: Using IDE

1. Open `Sources/DextFramework.groupproj` in the Delphi IDE
2. Right-click on `Dext.Web.Hubs.dpk` and select "Add Existing Project"
3. Build all projects in order:
   - Dext.Core
   - Dext.EF.Core
   - Dext.Web.Core
   - **Dext.Hubs** ← New package
   - Dext.Testing

### Option 2: Using Command Line

```powershell
# From Sources directory
cd ..\..\Sources

# Build dependencies first
msbuild Dext.Core.dproj /t:Build /p:Config=Debug /p:Platform=Win32
msbuild Dext.EF.Core.dproj /t:Build /p:Config=Debug /p:Platform=Win32
msbuild Dext.Web.Core.dproj /t:Build /p:Config=Debug /p:Platform=Win32

# Build Hubs package (after creating .dproj)
msbuild Dext.Web.Hubs.dproj /t:Build /p:Config=Debug /p:Platform=Win32
```

### Creating the DPROJ

Since the .dproj file is large and complex, I recommend creating it through the IDE:

1. Open `Dext.Web.Hubs.dpk` in Delphi
2. IDE will offer to create the .dproj - accept it
3. Configure the following settings:
   - **Output directory:** `..\Output\$(ProductVersion)\$(Platform)\$(Config)`
   - **Unit output directory:** `..\Output\$(ProductVersion)\$(Platform)\$(Config)`
   - **Search path:** `..\Output\$(ProductVersion)\$(Platform)\$(Config)`
   - **Namespace prefixes:** `System;Xml;Data;Datasnap;Web;Soap`

## Usage

### 1. Add to your project

```pascal
uses
  Dext.Web.Hubs,
  Dext.Web.Hubs.Extensions;
```

### 2. Create a Hub

```pascal
type
  TMyHub = class(THub)
  public
    [HubMethod]
    procedure SendMessage(const Text: string);
    [HubMethod]
    procedure JoinGroup(const GroupName: string);
  end;

procedure TMyHub.SendMessage(const Text: string);
begin
  Clients.All.SendAsync('ReceiveMessage', [TValue.From(Text)]);
end;

procedure TMyHub.JoinGroup(const GroupName: string);
begin
  Groups.AddToGroupAsync(Context.ConnectionId, GroupName);
end;
```

Only methods explicitly annotated with `[HubMethod]` are remotely invokable.
Other public methods remain server-side helpers and cannot be called by a client.

### 3. Register the Hub

```pascal
App.UseHubs;
MapHub(App, '/hubs/myhub', TMyHub);
```

### 4. Connect from JavaScript

```html
<script src="/dext-hubs.js"></script>
<script>
  const hub = new DextHubConnection('/hubs/myhub');
  
  hub.on('ReceiveMessage', (msg) => {
    console.log('Received:', msg);
  });
  
  await hub.start();
  await hub.invoke('SendMessage', 'Hello!');
</script>
```

## Testing

Run the unit tests:

```powershell
cd ..\..\Tests\Hubs
dcc32 TestDextHubs.dpr
TestDextHubs.exe
```

## Documentation

- **User Guide:** [Docs/hubs.md](../../Docs/hubs.md)
- **Implementation Plan:** [Docs/Plans/dext-hubs-implementation-plan.md](../../Docs/Plans/dext-hubs-implementation-plan.md)

## What's Implemented

| Feature | Status |
|---------|--------|
| SignalR-compatible interfaces | ✅ |
| THub base class | ✅ |
| IClientProxy (All, Client, Group, User) | ✅ |
| IGroupManager | ✅ |
| IConnectionManager | ✅ |
| JSON Protocol | ✅ |
| SSE Transport | ✅ |
| Negotiate endpoint | ✅ |
| Method invocation | ✅ |
| MapHub extension | ✅ |
| JavaScript client | ✅ |
| Reconnection logic | ✅ |

## What's NOT Implemented Yet (Phase 4)

| Feature | Planned For |
|---------|-------------|
| WebSocket transport | v1.1 |
| MessagePack protocol | v1.1 |
| Streaming results | v1.1 |
| Connection authentication | v1.1 |
