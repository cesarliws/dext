# ⚡ Official Performance Report: FastPath & Data API (UseSql) [Win64 Release]

This document consolidates the performance testing and benchmark results performed on the **Dext Web Framework** in a **Win64 Release (64-bit)** environment over the kernel-mode `http.sys` driver.

---

## 🛠️ Environment Context and Setup

- **Build Architecture**: **Win64 (64-bit Release build)** via MSBuild / RAD Studio 12 (Delphi 37.0).
- **HTTP Engine**: Kernel-Mode `http.sys` (`http.sys - Kernel Mode Driver` on port 8086).
- **HTTP Stress Tool**: `bombardier-windows-amd64.exe` running with **125 concurrent connections in parallel** for 10 seconds.
- **Database**: In-Memory SQLite (`:memory:`) populated with **5,000 records**.

---

## 🌐 Benchmark Results: `http.sys` Kernel Mode Driver (Win64 Release)

### 1. HTTP Engine Comparison: Indy vs `http.sys`

| Metric | **Indy** (Thread Pool / Port 8085) | **http.sys** (Kernel Driver / Port 8086) | Impact / Gain |
| :--- | :--- | :--- | :--- |
| **Throughput (Reqs/sec)** | `2,479.90 req/s` | **`14,587.64 req/s`** | 🚀 **+488% throughput (5.8x faster)** |
| **Average Latency** | `51.39 ms` | **`8.45 ms`** | ⏱️ **83.5% reduction in average latency** |
| **Data Throughput** | `387.31 KB/s` | **`2.43 MB/s`** | 📈 **+527% network transfer speed** |

---

### 2. Standalone Route Stress Test: Traditional (`/ping`) vs FastPath (`/fastping`)

Tests executed on `http.sys` (Port 8086) with 125 concurrent connections:

| Endpoint | Reqs/sec (Average) | Average Latency | Peak Throughput | Impact |
| :--- | :--- | :--- | :--- | :--- |
| **`/ping`** (Traditional Route) | `14,587.64 req/s` | `8.45 ms` | `25,877 req/s` | Standard Minimal API with DI scope handling. |
| **`/fastping`** (**FastPath**) | **`16,068.46 req/s`** | **`7.74 ms`** | **`26,377 req/s`** | 🚀 **+10.1% higher throughput** & reduced latency via `MapFast`. |

> ⚡ **FastPath Benefit**: Bypassing DI scope creation (`TDextScope`) and RTTI inspection boosts baseline `http.sys` performance from **14.5k req/s to 16k+ req/s**.

---

### 3. Database Query Test with 5,000 Records (`/dicities` vs `/cities` vs `/fastcities`)

Dataset: `BenchmarkUsers` table populated with **5,000 records** in **SQLite File (`benchmark_test.db`)** with **Isolated `TDbContext` per-request + Connection Pooling (PoolMax=150 + Warmup)** running on `http.sys`:

| Endpoint / Scenario | Reqs/sec (Average) | Average Latency | Data Throughput | Description |
| :--- | :--- | :--- | :--- | :--- |
| **`/dicities`** (DI Scoped) | `12.02 req/s` | `1.78 s` | `1.92 MB/s` | Standard Model: `TDbContext` injected via DI Scoped (`AddScoped<TDbContext>`) + Traditional ORM (`Entities<T>.ToList`). |
| **`/cities`** (Manual ORM) | `6.44 req/s` | `1.44 s` | `2.45 MB/s` | Manual per-request `TDbContext` instantiation + Traditional ORM (`Entities<T>.ToList`). |
| **`/fastcities`** (**FastPath Data API**) | **`57.08 req/s`** | **`184.94 ms`** | **`20.35 MB/s`** | **FastPath Data API**: `UseSql` + Direct UTF-8 socket streaming (`IUtf8ResponseSink`). (**9.6x lower latency / +374% req/s & +10.6x data throughput over DI**) |

---

## 📌 Implementation References

The benchmark endpoints are defined in unit `BM.Http.pas`:

```pascal
// Traditional Ping
App.MapGet('/ping', procedure(Context: IHttpContext)
begin
  Context.Response.Write('pong');
end);

// FastPath Ping (DI Scope & RTTI Bypass)
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

