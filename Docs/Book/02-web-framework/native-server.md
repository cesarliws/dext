# Native Server Engine

Dext Framework includes a native, high-performance HTTP server engine driver. This engine bypasses standard adapters and integrates directly with OS-level high-performance APIs:
- **Windows**: Uses kernel-mode HTTP Server API (`http.sys`) with asynchronous socket handling.
- **Linux**: Uses edge-triggered Linux epoll (`epoll`) system calls for non-blocking I/O event loops.

By selecting the native engine, you minimize user-space overhead, context switching, and achieve near-hardware HTTP throughput and resource efficiency.

## Key Benefits
1. **OS Kernel Integration**: `http.sys` manages TCP connections, SSL handshakes, and response caching inside the Windows kernel, saving user-space CPU cycles.
2. **Zero-Allocation HTTP Parser**: Dext uses a custom, highly optimized incremental HTTP parser (`TDextIocpHttpParser`) that extracts routing segments and headers without heap allocations.
3. **High Concurrency Event Loops**: On Linux, the epoll event loop handles thousands of connections per thread concurrently using non-blocking sockets.

## Configuration

To activate the native server, cast your `IWebHost` instance to `IWebApplication` and call `.UseNativeServer`:

```pascal
program MyProject;

{$APPTYPE CONSOLE}

uses
  Dext.WebHost,
  Dext.Web;

var
  Builder: IWebHostBuilder;
  Host: IWebHost;
begin
  Builder := TDextWebHost.CreateDefaultBuilder;

  Builder.Configure(
    procedure(App: IApplicationBuilder)
    begin
      App.MapGet('/',
        procedure(Context: IHttpContext)
        begin
          Context.Response.Write('Hello from Native Server!');
        end);
    end);

  Host := Builder.Build;

  // Configure Dext to use the Native HTTP.sys / epoll server engine
  (Host as IWebApplication).UseNativeServer;

  Host.Run;
end.
```

## Configuration Options

You can tune the native engine's behavior using `TServerEngineOptions`:

```pascal
var
  Options: TServerEngineOptions;
begin
  Options := TServerEngineOptions.Create;
  Options.IoThreadCount := 4; // Number of worker threads (defaults to CPU count)
  Options.QueueLimit := 1000;  // Backlog/queue limit for incoming requests
  
  // Apply options when initializing the builder
  // ...
end;
```

## Windows Processor Groups Scaling

On high-core Windows machines (more than 64 logical processors), the OS partitions CPU cores into **Processor Groups** (max 64 cores per group). By default, a process is bound to a single group, leaving all other groups completely idle.

The Dext Native Server Engine solves this bottleneck by implementing **Processor-Group-Aware Scheduling** (using the `Dext.Threading.ProcessorGroups` unit):
1. **Topology Discovery**: Auto-detects all active processor groups and system-wide logical processors via the `GetSystemLogicalProcessorCount` helper.
2. **Dynamic Thread Provisioning**: Spawns worker threads matching the total system-wide cores (e.g. 96 workers on a 2x48-core system) instead of being restricted to the starting group.
3. **Thread Affinity Balancing**: Dynamically assigns each I/O worker thread to a specific processor group and affinity mask in a round-robin manner via `SetThreadGroupAffinity` before starting its event/request loop.

This achieves linear scalability and 100% CPU utilization across all processor groups and NUMA nodes.

> [!WARNING]
> On Windows, running `http.sys` servers requires appropriate URL reservation permissions. If you bind to all interfaces (`0.0.0.0`), Dext will register the strong wildcard prefix `http://+:port/` which requires running the application as Administrator, or configuring a URL ACL namespace reservation via:
> ```cmd
> netsh http add urlacl url=http://+:5000/ user=Everyone
> ```
