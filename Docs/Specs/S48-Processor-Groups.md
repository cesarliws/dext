# 📑 S48: Windows Processor Groups Optimization (NUMA-Aware Scaling)

**Status:** ✅ Implemented
**Owner:** Cesar Romero & Engineering Team
**Created:** 2026-06-29
**Dependencies:** S39 (Native Server Engine)
**Enables:** Native scaling across >64 logical cores on Windows Server, NUMA-aware scheduling, and processor group load balancing.

---

## 1. Goal

Optimize the Dext Server framework's thread scheduling on high-core Windows machines (more than 64 logical processors) by implementing processor-group-aware thread allocation and CPU affinity. This ensures worker threads (such as `http.sys` and IOCP socket loops) scale linearly and utilize all available hardware nodes instead of being confined to a single processor group.

---

## 2. Technical Context & Objectives

By default, the Windows scheduler allocates processes and their child threads to a single **Processor Group** (up to 64 logical cores). On machines with 96, 128, or more logical cores, this means a standard application will leave any core belonging to other groups completely idle (0% utilization).

In high-throughput benchmarks, this default behavior creates a severe processor group bottleneck:
- A 96-core Windows Server instance is partitioned into **Group 0 (64 cores)** and **Group 1 (32 cores)**.
- Without explicit processor group management, all server worker threads run on Group 0, competing for 64 cores while 32 cores in Group 1 sit unused.
- The standard Delphi `CPUCount` utility may only return the active count of the *current* group (64) rather than the machine total (96), resulting in under-provisioning of IO workers.

```
                           ┌──────────────────────────────┐
                           │      Dext Server Process     │
                           └──────────────┬───────────────┘
                                          │
                   ┌──────────────────────┴──────────────────────┐
                   ▼                                             ▼
       ┌───────────────────────┐                     ┌───────────────────────┐
       │   Processor Group 0   │                     │   Processor Group 1   │
       │   (Cores 0 to 63)     │                     │   (Cores 64 to 95)    │
       └───────────┬───────────┘                     └───────────┬───────────┘
                   │                                             │
      Workers 1..64 bound to Group 0                Workers 65..96 bound to Group 1
```

### Objectives
- Automatically query system-wide CPU topologies (detecting all processor groups and total active processors).
- Distribute worker threads across all active processor groups using the `SetThreadGroupAffinity` Windows API.
- Prevent NUMA node memory latency penalties by aligning thread execution close to network interface interrupts (Receive Side Scaling).

---

## 3. Scope & Implementation

### 3.1 Processor Topology Discovery
We will implement topology detection by querying `kernel32.dll` APIs:
- `GetActiveProcessorGroupCount`: Retrieve the number of active processor groups.
- `GetActiveProcessorCount(GroupNumber)`: Retrieve the number of logical cores in a specific group.
- Provide a unified fallback to standard `CPUCount` when running on systems with $\le 64$ cores or non-Windows platforms.

### 3.2 Thread Affinity Binding
We will define the WinAPI structures required for thread-to-group binding:
```pascal
type
  TGroupAffinity = record
    Mask: NativeUInt;
    Group: WORD;
    Reserved: array[0..2] of WORD;
  end;
  PGroupAffinity = ^TGroupAffinity;

function SetThreadGroupAffinity(
  hThread: THandle;
  const GroupAffinity: TGroupAffinity;
  PreviousGroupAffinity: PGroupAffinity
): BOOL; stdcall; external 'kernel32.dll';
```

When Dext initializes its server worker threads (e.g., in `TDextHttpSysEngine.Start` and socket engines):
1. Determine the target processor group for each worker thread using a round-robin distribution strategy.
2. Initialize a `TGroupAffinity` record with the group index and mask.
3. Call `SetThreadGroupAffinity` using the native thread handle before starting the thread's execution loop.

### 3.3 Target Files & Classes to Modify

To implement the Windows processor group affinity and discovery logic, the following units and classes should be created or updated:

#### [NEW] [Dext.Threading.ProcessorGroups.pas](file:///c:/dev/Dext/DextRepository/Sources/Core/Dext.Threading.ProcessorGroups.pas)
- **Purpose**: A new dedicated unit for Windows Processor Groups topology discovery and affinity binding wrappers.
- **Key API Exports**:
  - `GetSystemLogicalProcessorCount`: Helper function that returns the total system-wide core count on Windows (across all processor groups), falling back to Delphi's standard `CPUCount` on non-Windows platforms.
  - `SetThreadGroupAffinity`: WinAPI binding import.
  - `ApplyGroupAffinityToThread(ThreadHandle, GroupIndex, Mask)`: Helper function to apply CPU affinity to a given thread handle.
- *Alternative*: If a new unit is not desired, these functions can be added to [Dext.Utils.pas](file:///c:/dev/Dext/DextRepository/Sources/Core/Base/Dext.Utils.pas) within a Windows-specific conditional compile block.

#### [MODIFY] [Dext.Server.HttpSys.pas](file:///c:/dev/Dext/DextRepository/Sources/Server/Dext.Server.HttpSys.pas)
- **`TDextHttpSysEngine`**:
  - Update `Start` method: Query the new topology helper (`GetSystemLogicalProcessorCount`) when `FOptions.IoThreadCount <= 0` to accurately spawn workers for all logical cores across all processor groups.
- **`TDextHttpSysWorker`**:
  - Assign a target processor group index to each worker thread instance (e.g., during construction via round-robin distribution `I mod GroupCount`).
  - Update `Execute`: Call the affinity helper function with the worker's native `Handle` right before entering the execution loop.

#### [MODIFY] [Dext.Server.Iocp.pas](file:///c:/dev/Dext/DextRepository/Sources/Server/Dext.Server.Iocp.pas)
- **`TDextIocpEngine`**:
  - Update `Start` method: Replace standard `CPUCount` with the system-wide processor topology helper when auto-detecting worker count.
- **`TDextIocpWorker`**:
  - Assign a target processor group index to each worker thread instance.
  - Update `Execute`: Bind the IOCP worker thread to its designated processor group and CPU mask prior to processing IO port completion packets.

---

## 4. Verification & Benchmarking

### Automated Tests
- Validate that the topology detection APIs correctly identify the hardware layout in different virtualized and physical environments.
- Verify that `SetThreadGroupAffinity` calls return `True` on multi-group machines and degrade gracefully (do not crash) on single-group or older Windows operating systems.

### Manual Verification & Benchmarking
- Deploy a test server using a 96-core `c6i.24xlarge` AWS instance running Windows Server 2022.
- Inject high-throughput request traffic using a client machine and monitor task manager / resource monitor.
- **Success Criteria**: Verify that CPU utilization is evenly distributed across both Processor Group 0 and Processor Group 1, achieving uniform saturation of all 96 cores.

---

*Created by Cesar Romero & Antigravity AI — June 2026*
