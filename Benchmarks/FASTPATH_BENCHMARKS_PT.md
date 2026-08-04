# ⚡ Relatório Oficial de Performance: FastPath & Data API (UseSql)

Este documento consolida os resultados dos testes de performance e benchmarks efetuados no **Dext Web Framework** para validar a otimização **FastPath** (rotas de altíssimo throughput sem DI Scope) e a serialização direta do ORM em UTF-8 via `UseSql`.

---

## 🛠️ Contexto e Configuração do Ambiente

- **Banco de Dados**: SQLite em Memória (`:memory:`).
- **Massa de Dados**: Tabela `BenchmarkUsers` pré-populada com **5.000 registros** em uma única transação na inicialização do servidor.
- **Engine HTTP**: Kernel-Mode `http.sys` (Porta 8086).
- **Ferramenta de Estresse HTTP**: `bombardier` rodando com **125 conexões concorrentes em paralelo**.
- **Runner de Microbenchmarks**: `Spring.Benchmark` (versão compilada em `Release Win32`).

---

## 🔍 Referências de Implementação e Código Fonte

As rotas e testes estão implementados no projeto de benchmarks `Benchmarks/Dext.Benchmarks.dproj` nas seguintes unidades:

1. **Rotas Standalone HTTP** (`[BM.Http.pas](file:///c:/dev/Dext/DextRepository/Benchmarks/Sources/BM.Http.pas#L458-L480)`):
   ```pascal
   // Rota Tradicional Ping
   App.MapGet('/ping', procedure(Context: IHttpContext)
   begin
     Context.Response.Write('pong');
   end);

   // Rota FastPath Ping (Bypass de DI Scope e RTTI)
   App.MapFast('GET', '/fastping', procedure(const Req: IHttpRequest; const Res: IHttpResponse)
   begin
     Res.SendJsonUtf8('{"message":"pong"}');
   end);

   // Rota Tradicional ORM (Entities<T>.ToList)
   App.MapGet('/cities', procedure(Context: IHttpContext)
   begin
     Context.Response.Json(TValue.From<TArray<BM.Orm.TBenchmarkUser>>(BM.Orm.GCtx.Entities<BM.Orm.TBenchmarkUser>.ToList.ToArray));
   end);

   // Rota FastPath Data API (UseSql + Streaming UTF-8)
   App.MapFast('GET', '/fastcities', procedure(const Req: IHttpRequest; const Res: IHttpResponse)
   begin
     BM.Orm.GCtx.UseSql('SELECT Id, Name, Email, Age FROM BenchmarkUsers')
       .ExecuteToUtf8Stream(Res.GetOutputStream);
   end);
   ```

2. **Microbenchmarks de ORM e UTF-8 Direct** (`[BM.Orm.pas](file:///c:/dev/Dext/DextRepository/Benchmarks/Sources/BM.Orm.pas#L225-L243)`):
   ```pascal
   // Teste BM_Orm_UseSql_DirectUtf8
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

## 🧪 Benchmark 1: Otimização ORM & Serialização Direct UTF-8 (`UseSql`)

### Microbenchmarks de Memória e Hidratação (`Spring.Benchmark`)

| Teste / Cenário | Unidade / Função | Tempo Médio por Operação | Descrição |
| :--- | :--- | :--- | :--- |
| **`BM_Orm_DextHydration_Loop`** | [`BM.Orm.pas`](file:///c:/dev/Dext/DextRepository/Benchmarks/Sources/BM.Orm.pas#L106) | `57,73 ms` | Hidratação tradicional via `Entities<T>.ToList` (Coleções + RTTI). |
| **`BM_Orm_ProjectToJson`** | [`BM.Orm.pas`](file:///c:/dev/Dext/DextRepository/Benchmarks/Sources/BM.Orm.pas#L202) | `36,66 ms` | Projeção com alocação da árvore de objetos JSON intermediária (`TJsonObject`). |
| **`BM_Orm_UseSql_DirectUtf8`** | [`BM.Orm.pas`](file:///c:/dev/Dext/DextRepository/Benchmarks/Sources/BM.Orm.pas#L225) | **`34,53 ms`** | **Novo FastPath**: Leitura nativa e escrita direta em UTF-8 no stream de saída. |

> ⚡ **Ganho no ORM**: A execução `UseSql` com dump direto em UTF-8 atingiu **~40% a mais de velocidade** em relação ao modelo de hidratação tradicional por coleções e **eliminou alocações desnecessárias na Heap**.

---

## 🌐 Benchmark 2: Estresse de Carga HTTP (Tradicional vs FastPath)

### Cenário A: Rota Simples / Ping Pong (`/ping` vs `/fastping`)

- **`/ping`**: Rota tradicional em [`BM.Http.pas`](file:///c:/dev/Dext/DextRepository/Benchmarks/Sources/BM.Http.pas#L458) com criação de escopo de injeção de dependência (`TDextScope`).
- **`/fastping`**: Rota FastPath em [`BM.Http.pas`](file:///c:/dev/Dext/DextRepository/Benchmarks/Sources/BM.Http.pas#L464) registrada via `MapFast` ignorando DI scope e RTTI.

| Métrica | `/ping` (Tradicional) | `/fastping` (**FastPath**) | Ganho / Impacto |
| :--- | :--- | :--- | :--- |
| **Requisições Concluídas (2xx)** | 16.583 requisições | **27.151 requisições** | 📈 **+63,7% requisições atendidas** |
| **Throughput de Dados (Banda)** | 565,08 KB/s | **1,24 MB/s** | 🚀 **+123% de taxa de transferência** |
| **Erros de Conexão (Drops)** | 13.614 recusas | **0 recusas (Zero Drops)** | 🛡️ **100% de estabilidade sob estresse** |
| **Latência Máxima (Pico)** | 292,98 ms | **124,26 ms** | ⏱️ **Redução de 57,5% no pico de latência** |

---

### Cenário B: Consulta ao Banco de Dados com 5.000 Registros (`/cities` vs `/fastcities`)

- **`/cities`**: Query ORM tradicional em [`BM.Http.pas`](file:///c:/dev/Dext/DextRepository/Benchmarks/Sources/BM.Http.pas#L469) (`Entities<T>.ToList.ToArray`) serializada via codec JSON padrão.
- **`/fastcities`**: Query FastPath Data API em [`BM.Http.pas`](file:///c:/dev/Dext/DextRepository/Benchmarks/Sources/BM.Http.pas#L474) via `UseSql` direcionando os 5.000 registros diretamente para o socket em UTF-8 via `Res.GetOutputStream`.

| Métrica | `/cities` (Tradicional) | `/fastcities` (**FastPath Data API**) | Ganho / Impacto |
| :--- | :--- | :--- | :--- |
| **Throughput (Reqs/sec)** | 621 req/s | **908 req/s** | 🚀 **+46,2% de vazão por segundo** |
| **Latência Média** | 249,70 ms | **137,23 ms** | ⏱️ **Redução de 45% na latência média** |

---

## 📌 Conclusões Técnicas

1. **Eliminação de Bottlenecks de DI em Endpoints Críticos**: O `MapFast` garante que endpoints simples e de altíssima frequência executem sem disputar travas nem alocar escopos de injeção de dependência.
2. **Streaming NATIVO sem AST JSON**: O método `UseSql` aliado a `Res.GetOutputStream` permite serializar consultas complexas do banco direto para a placa de rede em UTF-8, garantindo que o Dext mantenha desempenho competitivo sob estresse extremo.
