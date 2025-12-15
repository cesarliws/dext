# 🚅 Dext Architecture: The Path to Extreme Performance

Este documento detalha as decisões arquiteturais focadas em performance extrema para o futuro do framework Dext. Ele explica as limitações do modelo atual (v1) e como a nova arquitetura (v2/Infra) resolverá estes gargalos utilizando conceitos modernos como **Zero-Allocation**, **Span<T>** e **Native Drivers**.

---

## 🛑 O Desafio: Limitações do Modelo Tradicional

Atualmente, a maioria dos frameworks Delphi (incluindo as primeiras versões do Dext) opera sobre bases sólidas, mas legadas, que impõem um teto de performance em cenários de alta concorrência (C10k+).

### 1. HTTP: O Modelo Bloqueante & Eager Loading
*   **Problema (Threading)**: O uso de servidores baseados em `TIdHTTPServer` (Indy) força o modelo **Thread-per-Connection**.
*   **Problema (Abstração)**: As interfaces atuais (`IHttpContext`, `IRequest`, `IResponse`) foram desenhadas assumindo que tudo está em memória.
    *   **Full Resource Loading**: Para servir um arquivo (ex: `FileResult`), o framework muitas vezes carrega o `TStream` inteiro para a memória antes de enviar, causando picos de uso de RAM em arquivos grandes.
    *   **Eager Headers Parsing**: Assim que a conexão é aceita, o framework lê e processa *todos* os Headers HTTP, Cookies e Query Parameters, mesmo que o endpoint não precise deles.
*   **Impacto**: 
    *   Consumo excessivo de memória (Stack por Thread + Buffers duplicados).
    *   Delay no TTFB (Time To First Byte) pois o processamento só inicia após o parsing completo da requisição.

### 2. JSON & Strings: O Custo do UTF-16
*   **Problema**: O Delphi utiliza `UnicodeString` (UTF-16) nativamente. A Web utiliza `UTF-8`.
*   **Impacto**: Toda requisição JSON recebida precisa ser convertida de Bytes (UTF-8) para String (UTF-16) antes de ser parseada. Isso gera:
    *   **Double Allocation**: Memória para o buffer de bytes + Memória para a string convertida.
    *   **MM Pressure**: O gerenciador de memória trabalha dobrado para alocar e liberar essas strings temporárias a cada requisição, aumentando a fragmentação.

### 3. Falta de Slicing (Span)
*   **Problema**: Para ler uma parte de uma string ou array (ex: ler o valor de um Header HTTP), o modelo tradicional faz um `Copy()`, criando uma nova string.
*   **Impacto**: Alocações desnecessárias. Se um Header tem 100 caracteres e queremos os 10 primeiros, alocamos uma nova string de 10 chars.

---

## ⚡ A Solução: Nova Arquitetura "Metal-to-the-Pedal"

A nova camada de infraestrutura do Dext foca em eliminar alocações e usar recursos nativos.

### 1. `TSpan<T>`: Memory Slicing
Inspirado no `Span<T>` do .NET e `std::span` do C++.

*   **O que é**: Uma `record` leve que representa uma "janela" sobre um bloco de memória existente, sem possuí-lo.
*   **Como funciona**: Em vez de copiar dados, apenas apontamos para o endereço de memória inicial e o tamanho.
*   **Benefício**: Parsing de HTTP Headers, Rotas e JSON com **Zero Alocações**.
    *   *Exemplo*: Ler `Authorizaton: Bearer xyz` não cria strings "Bearer" nem "xyz", apenas Spans apontando para o buffer original.

### 2. Zero-Allocation JSON Parser
Um novo motor JSON construído do zero sobre `TSpan<Byte>`.

*   **Mudança**: NÃO converte o payload para `UnicodeString`.
*   **Funcionamento**: Lê diretamente os bytes UTF-8 do stream de rede.
*   **Performance**: Navega pelo JSON token a token (Forward-Only) ou via Spans, eliminando a sobrecarga de transcoding UTF-8 <-> UTF-16.

### 3. Native Drivers (HTTP)
Substituição progressiva do motor Indy por drivers nativos não-bloqueantes.

#### Fase 1: NativeAOT (Kestrel Interop)
*   Utilizar o servidor **Kestrel** (ASP.NET Core) compilado como Native Library.
*   Uso de Pinned Memory para passar dados do .NET para o Delphi via ponteiros, sem cópia.
*   Traz performance "estado da arte" (milhões de req/s) imediatamente.

#### Fase 2: Drivers Nativos (Bare Metal)
*   **Windows**: Integração direta com `http.sys` (Kernel Mode). Cache e I/O gerenciados pelo Kernel.
*   **Linux**: Integração com `epoll` em um Event Loop próprio.
*   **Modelo de I/O**: `Async/Await` real em nível de socket, permitindo que poucas threads (ex: número de Cores da CPU) atendam milhares de conexões.

---

## 📊 Resumo Comparativo

| Recurso | Modelo Tradicional (Atual) | Nova Arquitetura (Futuro) |
| :--- | :--- | :--- |
| **I/O Model** | Blocking (1 Thread por Cliente) | Non-Blocking (Event Loop / Completion Ports) |
| **String Handling** | UTF-16 (Conversão obrigatória) | UTF-8 (Nativo via Span) |
| **JSON Parsing** | String-based (Allocation Heavy) | Byte-based (Zero-Allocation) |
| **Memory** | High MM usage (Create/Free constant) | Pool & Arena Allocation (Reuso) |
| **Escalabilidade** | Linear até ~500 conexões | Exponencial (C10k ready) |

---

> **Nota**: Estas mudanças são transparentes para a aplicação final (`Controllers`, `Minimal APIs`). A API pública do Dext permanece a mesma, enquanto o motor "sob o capô" é trocado por versões de alta performance.
