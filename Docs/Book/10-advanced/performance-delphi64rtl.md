# Delphi64RTL Optimization (Win64)

Dext is engineered for high native performance out of the box. However, under extreme concurrency and heavy load on 64-bit Windows (Win64), the standard Delphi RTL (Run-Time Library) can sometimes become a lock-contention bottleneck due to frequent memory allocations and intensive string manipulation.

To address this, Dext optionally supports **Delphi64RTL**, a community-driven optimization library (RDP1974) that replaces critical Delphi RTL routines with highly optimized x86-64 Assembly implementations and SIMD instructions.

---

## Why Use It?

* **Optimized Memory Manager (`RDPMM64`)**: Drastically reduces lock contention in multi-threaded environments under high concurrent loads (such as the HTTP.sys worker loop or async background tasks).
* **High-Performance String Functions**: Replaces standard string routines with hand-optimized Assembly variants designed for modern CPUs.
* **SIMD Instructions (`RDPSimd64`)**: Accelerates low-level mathematical and logical routines using vector instructions (AVX/SSE).
* **Proven Performance Gains**: In our end-to-end benchmarks (HTTP.sys server + embedded database backend), adding Delphi64RTL yielded a **2x to 3x increase in throughput (req/s)** and significantly improved tail latencies under heavy concurrency.

---

## When to Use It?

* **64-bit Windows (Win64) Only**: The Delphi64RTL library target is exclusively Win64.
* **High-Scale Applications**: Production REST/JSON services handling hundreds of concurrent connections or running CPU-bound processing.

---

## How to Use It in Dext

Delphi64RTL is an **optional** dependency. To avoid code bloat or configuration coupling, it is not bundled directly in the Dext source repository, but support is pre-configured in the benchmark project.

### Step 1: Download the Library
Clone the Delphi64RTL repository to any directory on your computer or to a local external folder within your project (e.g., `External/Delphi64RTL`):

```bash
git clone https://github.com/RDP1974/Delphi64RTL.git
```

### Step 2: Configure the Search Path
Add the directory where Delphi64RTL was downloaded to your search paths:
* In Delphi IDE: Navigate to **Building > Delphi Compiler > Search path** under your project options (or globally in IDE Library Path).
* Via MSBuild: Pass it using the `/p:DCC_UnitSearchPath` parameter.

### Step 3: Add to your Project File (.dpr)
Add `RDPMM64` and `RDPSimd64` as the **very first** units in your project's `uses` clause, wrapped in conditional directives to maintain cross-platform compatibility:

```pascal
program MyDextServer;

{$APPTYPE CONSOLE}
{$DEFINE USE_RDP} // Define this flag to enable optimizations

uses
  {$IFDEF WIN64}
    {$IFDEF USE_RDP}
    RDPMM64,
    RDPSimd64,
    {$ENDIF}
  {$ENDIF}
  System.SysUtils,
  Dext.Web.WebApplication,
  // ... other units
```

> [!IMPORTANT]
> The `RDPMM64` unit must be listed before almost all other units in the `.dpr` file to ensure it initializes the optimized memory manager correctly as the process starts up.
