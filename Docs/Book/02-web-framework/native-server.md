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

## Linux epoll Thread Management

On Linux, Dext implements a high-performance **Multi-Reactor Architecture** combined with socket-level load balancing. 

Instead of a single thread accepting connections and dispatching them to worker threads (which creates a bottleneck), Dext distributes event loops at the OS level:

1. **Multi-Reactor with SO_REUSEPORT**: 
   When the engine starts, it spawns a pool of worker threads (`TDextEpollWorker`) defaulting to the number of CPU cores. Each worker thread runs its own independent `epoll` instance (`epoll_create1`) and binds to the exact same listening address/port using the socket option `SO_REUSEPORT`. This allows the Linux kernel to automatically load-balance incoming TCP connection requests across the worker threads' event loops at the kernel level, achieving zero-overhead connection acceptance.

2. **Edge-Triggered and One-Shot Event Loop**:
   Each worker thread monitors its sockets in Edge-Triggered (`EPOLLET`) and One-Shot (`EPOLLONESHOT`) mode. This configuration guarantees:
   - Max efficiency of `epoll_wait` notifications.
   - Strict thread-safety: once a client socket registers an event, it will not trigger on any other worker's loop until explicitly re-armed.

3. **Asynchronous Request Dispatching**:
   Once a worker thread detects an incoming request, it reads and parses the HTTP payload into memory. If the parsing succeeds, it does not process the user request synchronously. Instead, it dispatches the request to the global Delphi Thread Pool (`TTask.Run`). This decouples network I/O from application business logic, preventing slow request handlers or blocking database calls from starving the socket event loops.

4. **Asynchronous Writing and Connection Rearming**:
   - The thread pool thread processes the request and writes the response.
   - If the response cannot be completely sent in a single non-blocking `writev` system call, the remaining buffer is registered for `EPOLLOUT` events, which are handled by the worker thread's event loop to avoid blocking the worker or the thread pool.
   - Once all response data is written, the socket is either re-armed for the next request (keep-alive) or gracefully shut down/closed.

5. **Advanced Linux Kernel Optimizations**:
   - **Thread Core Affinity (CPU Pinning)**: Binds each `TDextEpollWorker` thread to a dedicated physical CPU core using `pthread_setaffinity_np` to eliminate context switching, thread migration, and CPU cache thrashing.
   - **TCP_DEFER_ACCEPT**: Postpones waking up worker threads until client data is received, minimizing idle wake-ups from empty TCP connections.
   - **TCP Fast Open (TFO)**: Allows incoming SYN packets to carry HTTP request payloads, saving one RTT for recurring clients.
   - **Zero-Copy File Transmission (sendfile)**: Serving static files via `sendfile()` streams the file descriptor data directly into the network socket at the kernel level, skipping user-space heap allocations.
   - **Context Pooling**: Workers reuse pre-allocated connection contexts (`TDextEpollContext`) to avoid heap fragmentation and Garbage Collector overhead.
   - **Keep-Alive & Timeout Drainage**: Integrated socket Keep-Alive configurations alongside an active worker sweep that automatically terminates idle connections (>15s) under high descriptor pressure.
   - **SO_LINGER Graceful Close**: Avoids dropping packets on termination by enforcing socket lingering.

## Windows Processor Groups Scaling

On high-core Windows machines (more than 64 logical processors), the OS partitions CPU cores into **Processor Groups** (max 64 cores per group). By default, a process is bound to a single group, leaving all other groups completely idle.

The Dext Native Server Engine solves this bottleneck by implementing **Processor-Group-Aware Scheduling** (using the `Dext.Threading.ProcessorGroups` unit):
1. **Topology Discovery**: Auto-detects all active processor groups and system-wide logical processors via the `GetSystemLogicalProcessorCount` helper.
2. **Dynamic Thread Provisioning**: Spawns worker threads matching the total system-wide cores (e.g. 96 workers on a 2x48-core system) instead of being restricted to the starting group.
3. **Thread Affinity Balancing**: Dynamically assigns each I/O worker thread to a specific processor group and affinity mask in a round-robin manner via `SetThreadGroupAffinity` before starting its event/request loop.

This achieves linear scalability and 100% CPU utilization across all processor groups and NUMA nodes.

## Windows Kernel HTTPS/SSL Configuration (`http.sys`)

When utilizing `.UseNativeServer` on Windows (`http.sys`), TLS/HTTPS encryption processing is delegated directly to the Windows Kernel (SChannel), providing zero-copy performance.

Under `http.sys`, the Windows Kernel manages SSL certificates via the System Certificate Store (`LocalMachine\My`).

### Option 1: Automated Setup via Dext CLI (Recommended)

Run the Dext CLI as Administrator to generate certificates, import private keys, and perform Kernel port binding automatically:

```bash
dext dev-certs https --trust
```

### Option 2: Manual Setup via Administrator Command Prompt

If you want to manually bind an existing certificate to your port in the Kernel:

1. **Import PKCS#12 (`.pfx`) Bundle with Private Key:**
   ```powershell
   Import-PfxCertificate -FilePath "server.pfx" -CertStoreLocation Cert:\LocalMachine\My -Password (ConvertTo-SecureString "dba" -AsPlainText -Force)
   ```

2. **Bind Certificate Thumbprint to Port in Windows Kernel via `netsh`:**
   ```cmd
   netsh http add sslcert ipport=0.0.0.0:8080 certhash=YOUR_SHA1_THUMBPRINT appid={4f3b2c10-8a9b-4d7e-8f12-3456789abcde}
   ```

3. **Verify active Kernel SSL bindings:**
   ```cmd
   netsh http show sslcert ipport=0.0.0.0:8080
   ```

---

> netsh http add urlacl url=https://+:8080/ user=Everyone
> ```

---

## 🔒 Native HTTPS and TLS on Linux (`epoll` + OpenSSL)

On Linux (WSL2, Ubuntu, Debian, or RHEL), Dext leverages the **`epoll`** engine paired with the **OpenSSL 3.x Memory BIO Engine** in a fully decoupled architecture, delivering zero-copy TLS encryption at maximum performance without requiring reverse proxies (Nginx/HAProxy).

> [!IMPORTANT]
> Native OpenSSL is **off** by default (`{.$DEFINE DEXT_ENABLE_SSL}` in `Sources/Common/Dext.inc`). Linux64 install does not need `libssl` in the SDK until you enable it. For HTTPS, uncomment `{$DEFINE DEXT_ENABLE_SSL}`, install `libssl-dev`, update the SDK Manager cache, and rebuild. See [cannot find -lcrypto](../../Articles/2026-08-28-dext-openssl-linux-sdk-cannot-find-lcrypto-pt-br.md).

### 1. Required Linux Packages

Install the OpenSSL development libraries:

```bash
# Ubuntu / Debian / WSL2
sudo apt update
sudo apt install -y libssl-dev openssl

# RHEL / AlmaLinux / Rocky Linux
sudo dnf install -y openssl-devel openssl
```

### 2. Generating Development Certificates with OpenSSL

```bash
# 1. Generate CA Private Key and Root Certificate
openssl req -x509 -newkey rsa:4096 -nodes -keyout ca.key -out ca.crt -days 365 -subj "/CN=Dext Test CA"

# 2. Generate Server Private Key and CSR
openssl req -newkey rsa:2048 -nodes -keyout server.key -out server.csr -subj "/CN=localhost"

# 3. Sign Certificate with SAN (Subject Alternative Name) Extension
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 365 \
  -extfile <(printf "subjectAltName=DNS:localhost,IP:127.0.0.1")
```

### 3. Pascal Code (Linux Native Server)

```pascal
var
  App: IWebApplication;
begin
  App := TWebApplication.Create;

  // On Linux, Dext automatically activates epoll with OpenSSL 3.x Memory BIOs
  App.UseNativeServer(
    ServerEngineOptions
      .WithHttps(True)
  );

  App.MapGet('/ping', function(Req: IHttpRequest; Res: IHttpResponse)
  begin
    Res.Send('PONG over HTTPS (Linux epoll)');
  end);

  App.Run(8443);
end.
```

### 4. Testing Connection with `curl`

```bash
curl --cacert ca.crt https://localhost:8443/ping
# Expected Response: PONG over HTTPS (Linux epoll)
```
