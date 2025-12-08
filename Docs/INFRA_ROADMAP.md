# 🏗️ Dext Infrastructure - Roadmap

Este documento centraliza o desenvolvimento da infraestrutura de baixo nível do framework, com foco em **Performance Extrema** e **Eficiência de Recursos**.

> **Visão:** Prover uma fundação sólida, "Metal-to-the-Pedal", que permita ao Dext competir em performance com frameworks Go, Rust e .NET (Kestrel).

---

## 🚀 High Performance HTTP Server (Clean Room Implementation)

Reescrita do núcleo HTTP para eliminar gargalos de arquiteturas legadas (Indy/WebBroker) e explorar recursos nativos do SO.

### 1. Windows: Kernel Mode (`http.sys`)
Integração direta com o driver `http.sys` do Windows (mesma stack do IIS e Kestrel).
- [ ] **Native API Binding**: Importação da `httpapi.dll` (HttpInitialize, HttpCreateHttpHandle).
- [ ] **Zero-Copy**: Utilizar buffers do kernel para evitar cópias desnecessárias de memória.
- [ ] **Kernel-Mode Caching**: Servir arquivos estáticos e respostas cacheadas diretamente do Kernel.
- [ ] **Port Sharing**: Permitir compartilhar a porta 80/443 com IIS e outras apps.
- [ ] **HTTP/3 (QUIC)**: Suporte experimental ao novo protocolo HTTP sobre UDP para performance em redes instáveis.

### 2. Linux: Event-Driven I/O (`epoll`)
Modelo não-bloqueante para alta concorrência no Linux.
- [ ] **Epoll Integration**: Uso de `epoll_create1`, `epoll_ctl`, `epoll_wait`.
- [ ] **Thread Pool**: Workers fixos (CPU Bound) processando eventos de I/O de milhares de conexões.
- [ ] **Non-Blocking Sockets**: Eliminar o modelo "Thread-per-Connection".

### 3. Memory & String Optimization (Zero-Allocation)
Eliminar o custo de conversão `UTF-8` <-> `UTF-16` (UnicodeString) no core do framework.
- [ ] **RawUTF8 / Span<byte>**: Tipo de dados base para manipulação de strings sem conversão.
- [ ] **Zero-Allocation Parsing**: Roteamento e Headers processados varrendo bytes diretamente.
- [ ] **UTF-8 JSON Parser**: Novo parser JSON otimizado para ler/escrever UTF-8 diretamente, sem alocações intermediárias de strings Delphi.

---

## 🛠️ Core Infrastructure

### 1. Telemetry & Observability Foundation
Base para o suporte a OpenTelemetry nos frameworks superiores.
- [ ] **Activity/Span API**: Abstração para rastreamento distribuído.
- [ ] **Metrics API**: Contadores, Histogramas e Gauges de alta performance.
- [ ] **Logging Abstraction**: Zero-allocation logging interface.

### 2. Advanced Async & Concurrency
Evolução da `Fluent Tasks API` para suportar cenários complexos de orquestração e alta performance.

- [x] **Fluent Tasks Core**: Implementação base (`TAsyncTask`, `ThenBy`, `WithCancellation`).
- [x] **Unsynchronized Callbacks**: Opção para executar callbacks em thread de background (evitar gargalo na Main Thread).
  - *API*: `.OnCompleteAsync(proc)`, `.OnExceptionAsync(proc)`
- [ ] **Composition Patterns (Fork/Join)**:
  - `WhenAll(Tasks)`: Aguardar múltiplas tasks finalizarem (Scatter-Gather).
  - `WhenAny(Tasks)`: Retornar assim que a primeira task finalizar (Redundancy/Race).
- [ ] **Parallel Data Processing**:
  - Integração com loops paralelos fluentes.
  - *Exemplo*: `TAsyncTask.For(0, 1000).Process(procedure(I) ...).Start`
- [ ] **Resilience Patterns**:
  - **Retry**: `.Retry(Count, Delay)` para falhas transientes.
  - **Circuit Breaker**: Proteger recursos externos de sobrecarga.
  - **Timeout**: `Timeout(500ms)` forçando cancelamento se exceder o tempo.
- [ ] **Progress Reporting**:
  - Suporte a `IProgress<T>` para notificar progresso granular sem acoplar com UI.
- [ ] **Telemetry Hooks**:
  - Log automático de tempo de execução, exceções e cancelamentos via `Core.Telemetry`.

---
