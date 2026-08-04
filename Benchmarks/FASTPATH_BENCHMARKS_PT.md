# ⚡ Relatório Oficial de Performance: FastPath & Engine `http.sys` [Win64 Release]

Este documento consolida os resultados dos testes de estresse efetuados no **Dext Web Framework** em ambiente **Win64 Release (64-bit)** utilizando o driver nativo em modo kernel `http.sys`.

---

## 🛠️ Contexto e Configuração do Ambiente

- **Arquitetura da Compilação**: **Win64 (64-bit Release build)** via MSBuild / RAD Studio 12 (Delphi 37.0).
- **Engine HTTP**: Kernel-Mode `http.sys` (`http.sys - Kernel Mode Driver` na porta 8086).
- **Ferramenta de Estresse HTTP**: `bombardier-windows-amd64.exe` rodando com **125 conexões concorrentes em paralelo** por 10 segundos.

---

## 🌐 Resultados dos Benchmarks no `http.sys` (Win64 Release)

### 1. Comparativo de Engine: Indy vs `http.sys`

| Métrica | **Indy** (Thread Pool / Porta 8085) | **http.sys** (Kernel Driver / Porta 8086) | Ganho / Impacto |
| :--- | :--- | :--- | :--- |
| **Throughput (Reqs/sec)** | `2.479,90 req/s` | **`14.587,64 req/s`** | 🚀 **+488% de vazão (5,8x mais rápido)** |
| **Latência Média** | `51,39 ms` | **`8,45 ms`** | ⏱️ **Redução de 83,5% na latência** |
| **Banda Passante** | `387,31 KB/s` | **`2,43 MB/s`** | 📈 **+527% de taxa de transferência** |

---

### 2. Estresse de Rotas Standalone: Tradicional (`/ping`) vs FastPath (`/fastping`)

Testes executados no `http.sys` (Porta 8086) com 125 conexões concorrentes:

| Endpoint | Reqs/sec (Média) | Latência Média | Pico de Throughput | Impacto |
| :--- | :--- | :--- | :--- | :--- |
| **`/ping`** (Rota Padrão) | `14.587,64 req/s` | `8,45 ms` | `25.877 req/s` | Minimal API padrão com escopo DI. |
| **`/fastping`** (**FastPath**) | **`16.068,46 req/s`** | **`7.74 ms`** | **`26.377 req/s`** | 🚀 **+10,1% throughput** e menor latência via `MapFast`. |

> ⚡ **Ganho do FastPath**: O bypass do escopo de DI (`TDextScope`) e inspeção RTTI eleva o desempenho do `http.sys` de **14,5k req/s para mais de 16k req/s**.

---

### 3. Consulta ao Banco de Dados com 5.000 Registros (`/cities` vs `/fastcities`)

Massa de teste: Tabela `"BenchmarkUsers"` com **5.000 registros** em banco de dados **PostgreSQL 64-bit (`dext_test`)** via driver nativo FireDAC (`libpq.dll`), rodando em `http.sys` sob 10 conexões concorrentes (`bombardier -c 10`):

| Endpoint / Cenário | Reqs/sec (Média) | Latência Média | Banda Passante (Throughput) | Descrição |
| :--- | :--- | :--- | :--- | :--- |
| **`/cities`** (ORM Tradicional) | `2,34 req/s` | `2,77 s` | `1,22 MB/s` | Modelo Padrão: ORM Tradicional (`Entities<T>.ToList`) + Inspecção RTTI + Serialização JSON por entidade no heap. |
| **`/fastcities`** (**FastPath Data API**) | **`43,47 req/s`** | **`223,87 ms`** | **`16,74 MB/s`** | **FastPath Data API**: `UseSql` + Streaming direto UTF-8 inlinado via motor nativo **`TUtf8JsonWriter`** (`Dext.Json.Utf8.pas`). (**12,3x menor latência / +1.757% req/s & +13,7x vazão de dados**) |

---

> 💡 **Decomposição do Tempo de Execução (Server Tracing Log)**:
> - **ORM Tradicional (`/cities`)**:
>   - `Execução SQL (Query)`: ~1.100 ms a 2.400 ms
>   - `Serialização JSON + RTTI`: ~55 ms a 250 ms
>   - `Desalocação do Heap (FreeCtx)`: ~25 ms a 108 ms
>   - **Total por requisição**: **~2,77 s**
> - **FastPath Data API (`/fastcities` com `TUtf8JsonWriter` Inlinado)**:
>   - `Query + Streaming Direto UTF-8`: **~94 ms a 200 ms** (gravando blocos UTF-8 diretamente no socket à medida que o `IDbReader` avança)
>   - `Alocações no Heap / GC Overhead`: **0 ms**
>   - **Total por requisição**: **~223 ms**

---

## 📌 Referências de Código

As rotas estão registradas na unidade `BM.Http.pas`:

```pascal
// Ping Tradicional
App.MapGet('/ping', procedure(Context: IHttpContext)
begin
  Context.Response.Write('pong');
end);

// FastPath Ping (Bypass de DI Scope e RTTI)
App.MapFast('GET', '/fastping', procedure(const Req: IHttpRequest; const Res: IHttpResponse)
begin
  Res.SendJsonUtf8('{"message":"pong"}');
end);

// Rota Tradicional ORM (Entities<T>.ToList)
App.MapGet('/cities', procedure(Context: IHttpContext)
begin
  Context.Response.Json(TValue.From<TArray<BM.Orm.TBenchmarkUser>>(BM.Orm.GCtx.Entities<BM.Orm.TBenchmarkUser>.ToList.ToArray));
end);

// Rota FastPath Data API (UseSql + Motor Nativo TUtf8JsonWriter + Streaming UTF-8 Direct)
App.MapFast('GET', '/fastcities', procedure(const Req: IHttpRequest; const Res: IHttpResponse)
begin
  BM.Orm.GCtx.UseSql('SELECT "Id", "Name", "Email", "Age" FROM "BenchmarkUsers"')
    .ExecuteToUtf8Stream(Res.GetOutputStream);
end);
```

