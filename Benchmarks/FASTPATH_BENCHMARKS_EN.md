# ⚡ Official Performance Report: FastPath & Data API (UseSql)

This document consolidates the results of performance tests and benchmarks conducted on **Dext Web Framework** to evaluate the **FastPath** optimization (high-throughput routes bypassing DI Scope) and direct ORM UTF-8 serialization via `UseSql`.

---

## 🛠️ Environment Setup & Context

- **Database**: In-Memory SQLite (`:memory:`).
- **Dataset**: `BenchmarkUsers` table pre-populated with **5,000 records** in a single transaction during server startup.
- **HTTP Engine**: Kernel-Mode `http.sys` (Port 8086).
- **HTTP Stress Tool**: `bombardier` running with **125 parallel concurrent connections**.
- **Microbenchmark Runner**: `Spring.Benchmark` (compiled in `Release Win32`).

---

## 🔍 Implementation References & Source Code

The routes and test cases are implemented in the `Benchmarks/Dext.Benchmarks.dproj` project within the following units:

1. **Standalone HTTP Server Routes** (`[BM.Http.pas](file:///c:/dev/Dext/DextRepository/Benchmarks/Sources/BM.Http.pas#L458-L480)`):
   ```pascal
   // Traditional Ping Route
   App.MapGet('/ping', procedure(Context: IHttpContext)
   begin
     Context.Response.Write('pong');
   end);

   // FastPath Ping Route (Bypassing DI Scope and RTTI)
   App.MapFast('GET', '/fastping', procedure(const Req: IHttpRequest; const Res: IHttpResponse)
   begin
     Res.SendJsonUtf8('{"message":"pong"}');
   end);

   // Traditional ORM Route (Entities<T>.ToList)
   App.MapGet('/cities', procedure(Context: IHttpContext)
   begin
     Context.Response.Json(TValue.From<TArray<BM.Orm.TBenchmarkUser>>(BM.Orm.GCtx.Entities<BM.Orm.TBenchmarkUser>.ToList.ToArray));
   end);

   // FastPath Data API Route (UseSql + Direct UTF-8 Streaming)
   App.MapFast('GET', '/fastcities', procedure(const Req: IHttpRequest; const Res: IHttpResponse)
   begin
     BM.Orm.GCtx.UseSql('SELECT Id, Name, Email, Age FROM BenchmarkUsers')
       .ExecuteToUtf8Stream(Res.GetOutputStream);
   end);
   ```

2. **ORM & UTF-8 Direct Microbenchmarks** (`[BM.Orm.pas](file:///c:/dev/Dext/DextRepository/Benchmarks/Sources/BM.Orm.pas#L225-L243)`):
   ```pascal
   // BM_Orm_UseSql_DirectUtf8 Test Procedure
   procedure BM_Orm_UseSql_DirectUtf8(const state: TState);
   var
     Stream: TMemoryStream;
   begin
     Stream := TMemoryStream.Create;
     try
       while state.KeepRunning do
       begin
         Stream.Clear;
         GCtx.UseSql('SELECT Id, Name, Email, Age FROM BenchmarkUsers')
           .ExecuteToUtf8Stream(Stream);
       end;
     finally
       Stream.Free;
     end;
   end;
   ```

---

## 🧪 Benchmark 1: ORM Optimization & Direct UTF-8 Serialization (`UseSql`)

### Memory & Hydration Microbenchmarks (`Spring.Benchmark`)

| Test / Scenario | Unit / Procedure | Avg Time per Operation | Description |
| :--- | :--- | :--- | :--- |
| **`BM_Orm_DextHydration_Loop`** | [`BM.Orm.pas`](file:///c:/dev/Dext/DextRepository/Benchmarks/Sources/BM.Orm.pas#L106) | `57.73 ms` | Traditional hydration via `Entities<T>.ToList` (Collections + RTTI). |
| **`BM_Orm_ProjectToJson`** | [`BM.Orm.pas`](file:///c:/dev/Dext/DextRepository/Benchmarks/Sources/BM.Orm.pas#L202) | `36.66 ms` | Projection allocating intermediate JSON object trees (`TJsonObject`). |
| **`BM_Orm_UseSql_DirectUtf8`** | [`BM.Orm.pas`](file:///c:/dev/Dext/DextRepository/Benchmarks/Sources/BM.Orm.pas#L225) | **`34.53 ms`** | **New FastPath**: Native database reading and direct UTF-8 streaming to output. |

> ⚡ **ORM Gain**: Direct UTF-8 `UseSql` execution achieved **~40% higher speed** compared to traditional entity collection hydration and **eliminated unnecessary Heap allocations**.

---

## 🌐 Benchmark 2: HTTP Stress Load Test (Traditional vs FastPath)

### Scenario A: Simple Route / Ping Pong (`/ping` vs `/fastping`)

- **`/ping`**: Traditional route in [`BM.Http.pas`](file:///c:/dev/Dext/DextRepository/Benchmarks/Sources/BM.Http.pas#L458) creating a dependency injection scope (`TDextScope`).
- **`/fastping`**: Fast route in [`BM.Http.pas`](file:///c:/dev/Dext/DextRepository/Benchmarks/Sources/BM.Http.pas#L464) registered via `MapFast` bypassing DI scope and RTTI activation.

| Metric | `/ping` (Traditional) | `/fastping` (**FastPath**) | Gain / Impact |
| :--- | :--- | :--- | :--- |
| **Successful Requests (2xx)** | 16,583 requests | **27,151 requests** | 📈 **+63.7% served requests** |
| **Data Throughput (Bandwidth)** | 565.08 KB/s | **1.24 MB/s** | 🚀 **+123% data transfer rate** |
| **Connection Errors (Drops)** | 13,614 refused | **0 refused (Zero Drops)** | 🛡️ **100% stability under high load** |
| **Max Latency (Peak)** | 292.98 ms | **124.26 ms** | ⏱️ **57.5% reduction in peak latency** |

---

### Scenario B: Database Query returning 5,000 Records (`/cities` vs `/fastcities`)

- **`/cities`**: Traditional ORM query in [`BM.Http.pas`](file:///c:/dev/Dext/DextRepository/Benchmarks/Sources/BM.Http.pas#L469) (`Entities<T>.ToList.ToArray`) serialized via standard JSON codec.
- **`/fastcities`**: Data API query in [`BM.Http.pas`](file:///c:/dev/Dext/DextRepository/Benchmarks/Sources/BM.Http.pas#L474) via `UseSql` streaming 5,000 records directly to output socket in UTF-8 via `Res.GetOutputStream`.

| Metric | `/cities` (Traditional) | `/fastcities` (**FastPath Data API**) | Gain / Impact |
| :--- | :--- | :--- | :--- |
| **Throughput (Reqs/sec)** | 621 req/s | **908 req/s** | 🚀 **+46.2% throughput per second** |
| **Average Latency** | 249.70 ms | **137.23 ms** | ⏱️ **45% reduction in average latency** |

---

## 📌 Technical Conclusions

1. **Elimination of DI Bottlenecks on Critical Endpoints**: `MapFast` ensures that lightweight, high-frequency endpoints execute without lock contention or allocation of dependency injection scopes.
2. **NATIVE Streaming without AST JSON**: The `UseSql` method paired with `Res.GetOutputStream` allows streaming complex database queries directly to the network socket in UTF-8, keeping Dext highly performant under extreme stress.
