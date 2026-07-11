# Spec S56 - Json Parser NextGen (Zero Allocation & SIMD)

## 1. Visão Geral e Motivação

A atual implementação do parser JSON do Dext (`DextJsonDataObjects.pas`) já é extremamente otimizada, sendo considerada uma das melhores implementações para Delphi com parseamento direto em UTF-8, string interning e alocações rápidas. 

No entanto, ela foi desenhada baseando-se nas capacidades do compilador de uma época anterior aos tipos modernos de manipulação de memória (como Spans) e sem aproveitar extensamente as instruções vetoriais (SIMD) disponíveis em processadores modernos.

**Objetivo desta Spec:**
Propor e estruturar a criação de um parser JSON "NextGen", focado em **Zero Allocation, TSpan e aceleração SIMD**. O objetivo não é substituir ou refatorar imediatamente a unit atual, mas sim **criar uma unit paralela** (`Dext.Core.Json.NextGen.pas`) para viabilizar testes de benchmarks (A/B) e validar os limites absolutos de performance e throughput (GB/s) de parsing em Delphi.

## 2. Pilares Arquiteturais

### 2.1. Core com TSpan<Char> / TSpan<Byte> (Zero Allocation)
O parser tradicional gerencia substrings alocando memória ou incrementando contadores de referência. No modelo NextGen:
- O parser recebe um único buffer de entrada (string gigante ou memory-mapped file).
- Chaves (`Names`) e Valores (`Values`) são extraídos como `TSpan<Char>` ou `TSpan<Byte>`, guardando apenas um ponteiro para o início do token e seu comprimento (`Length`).
- Alocação no Heap (`.AsString`) ocorre exclusivamente no último momento (Lazy Allocation), apenas se o usuário pedir explicitamente a conversão. Para extração de literais e tipagem primitiva, a alocação de chaves/valores é estritamente **zero**.

### 2.2. Aceleração com SIMD (Varredura Estrutural)
O gargalo no parser atual é descobrir o início e fim dos tokens lendo caractere a caractere. Com SIMD (SSE4.2, AVX2 ou NEON):
- O JSON é lido em blocos de 16 ou 32 bytes de uma vez diretamente para os registradores vetoriais.
- Uma máscara de bits é aplicada para localizar instantaneamente caracteres de controle estrutural: `"`, `\`, `{`, `}`, `[`, `]`, `:`, `,`.
- Usa-se a instrução `_BitScanForward` (BSF) / `_tzcnt` para pular diretamente para o próximo caractere estrutural de interesse em poucos ciclos de CPU, ignorando blocos sem marcações (como espaços em branco e longos valores textuais).

### 2.3. Tokenizer Sem Estado (State Machine Vetorizada)
A técnica de **Structural Indexing** (inspirada pelo simdjson) permite dividir o parseamento em duas fases super rápidas:
- **Fase 1 (SIMD - Indexação):** Varre o JSON na velocidade de banda de memória, gerando um array simples de inteiros (`TArray<Integer>`) com os índices literais de onde os tokens estruturais iniciam.
- **Fase 2 (Parse Linear):** O parser consome esse array sem a necessidade de processar branches de verificação de término de string ou escape. A navegação passa a ser puramente linear, maximizando o uso do cache L1/L2 e evitando falhas de predição de desvio (branch mispredictions).

### 2.4. Perfect Hashing e Alloc-Free Dictionaries
- O atual TStringIntern mitiga colisões de strings gerando hashes (FNV-1a) no momento da criação das chaves.
- Com chaves como `TSpan<Char>`, um dicionário alloc-free permite busca direta via `CompareMem` ou SIMD intrínseco.
- Em cenários de tipagem forte (Data Binding onde as propriedades conhecidas da classe são mapeadas no JSON), pode-se implementar um **Perfect Hashing Algorithm**. Isso transforma o match de chaves em um lookup absoluto de tempo constante ($O(1)$) eliminando colisões em tempo de execução e, claro, alocações de string.

## 3. Micro-Otimizações Complementares

Apesar dos pilares cobrirem o ganho estrutural principal, outras áreas críticas passarão por refinamento agressivo:

1. **Parser UTF-8 Agressivo:**
   - Trocar verificações manuais de `isWhitespace`, `isDigit` por **tabelas de lookup estáticas (256 bytes)**. Isso remove *branches* no hot path das funções de tokenização léxica (`LexNumber`, `LexString`).

2. **Otimização Extrema no Parse Numérico:**
   - Números costumam ser gargalos frequentes. O NextGen deve usar parse com tabelas de potências pré-calculadas e o menor número possível de multiplicações iterativas.
   - Chamadas nativas de fallback como `StrToInt64`/`StrToFloat` do RTL deverão atuar *apenas* em casos excepcionais (underflow/overflow/complex scientific notation).

3. **Pool de Objetos (Object Pooling):**
   - Apesar do `USE_FAST_NEWINSTANCE` ser excelente, aplicações de streaming e alto throughput sofrem com criação/destruição frenética de `TJsonObject`, `TJsonArray` e `TJsonDataValue`.
   - Um Ring Buffer ou Memory Pool para a engine JSON reduziria drasticamente a fragmentação e invocação do gerenciador de memória do Delphi.

4. **Escrita (Serialization) via Buffer Agressivo:**
   - O atual `TJsonStringBuilder` será substituído ou superado por um buffer nativo `TBytes` pré-alocado.
   - Escrita rápida feita exclusivamente via `SetLength` otimizado, `Move` bloqueado, e aritmética de `PChar` agressiva, minimizando checagens de bound-limits no loop de construção de payload.

## 4. Plano de Execução e Testes

1. **Implementação da Nova Unit:**
   - Criar `Dext.Core.Json.NextGen.pas` (sem alterar o `DextJsonDataObjects.pas` padrão para preservar retrocompatibilidade da engine atual).
2. **Definição das Estruturas Span:**
   - Implementar e usar a mecânica de `TSpan` para o tokenizer sem cópia.
3. **Escrita das Rotinas SIMD (Apenas Delphi moderno / X64):**
   - Inserir blocos Assembly (`asm`) ou classes helpers para as instruções AVX2 / SSE4.
4. **Bateria de Benchmarks:**
   - Criar console de benchmarking em `Tests/Benchmarks/JsonNextGenBenchmarks`.
   - Comparar throughput (MB/s) usando payloads JSON variados (simples, profundos, massivos).
   - Validar perfil de memória (Memory footprint / Gen0 Collections equivalent) sob stress contínuo.

Esta abordagem mudará o patamar da engine de parser do Dext em operações extremas de microsserviços.
