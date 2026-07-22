# Spec: SIMD Quad Algorithm - Otimização de Busca em Arrays Primitivos

## Metadados
- **Status:** Reservado para o Futuro (Ideia / Estudo)
- **Autor Original:** Daniel Lemire
- **Data do Artigo:** 27/04/2026
- **Fonte:** [You can beat the binary search - Lemire's Blog](https://lemire.me/blog/2026/04/27/you-can-beat-the-binary-search/)
- **Público-Alvo no Dext:** Equipe de Arquitetura Core (ORM, Cache, Indexação em Memória)

---

## 1. Contexto e Motivação
Historicamente, a busca binária (`BinarySearch`) tem sido a solução padrão para encontrar elementos em arrays ordenados, possuindo complexidade de tempo $O(\log N)$. No entanto, a busca binária clássica apresenta gargalos significativos em arquiteturas de hardware modernas (CPUs Intel, AMD e Apple Silicon):

1. **Branch Misprediction (Erro de Predição de Desvio):** A decisão de pular para a metade superior ou inferior do array tem exatamente 50% de probabilidade em cada iteração. O hardware não consegue prever o salto com eficiência, o que causa limpezas de pipeline no processador e desperdiça ciclos de clock.
2. **Latência de Memória:** O acesso não contíguo aos elementos durante os saltos binários falha em utilizar os benefícios do pre-fetch e causa falhas de cache (*Cache Misses*).

## 2. O Algoritmo: SIMD Quad Search
O algoritmo proposto por Lemire ("SIMD Quad") mitiga esses problemas e supera a busca binária significativamente em arrays extensos (especialmente os que não cabem no cache - *cold cache*). 

A abordagem combina duas inovações de baixo nível:
1. **Busca Interpolada Quaternária (Base-4):** Em vez de dividir o range de busca pela metade (base-2), o algoritmo avalia três pontos simultâneos, dividindo o array em quatro blocos (quartos). Processadores modernos conseguem carregar e comparar múltiplos endereços de memória simultaneamente (Memory-Level Parallelism).
2. **Verificação SIMD (Single Instruction, Multiple Data):** Ao isolar o "bloco" final (ex: os últimos 16 elementos prováveis), o algoritmo carrega o bloco inteiro em registradores SIMD (SSE2/AVX ou ARM NEON) e efetua a comparação simultânea com o valor alvo sem usar nenhum "if", eliminando o branch misprediction no trecho final da busca.

## 3. Aplicações Potenciais no Dext Framework
Embora essa implementação não deva substituir métodos genéricos (`TList<T>.BinarySearch`) que lidam com ponteiros e `IComparer`, ela é extremamente valiosa para a construção de motores internos de alta performance baseados em tipos primitivos (`Integer`, `Int64`).

**Ideias de Aplicação:**
- **Motores de Indexação (ORM):** Criação de índices ultra-rápidos em memória para mapeamento de chaves primárias (PKs) numéricas em listas de entidades.
- **Estruturas de Cache e Redis Client:** Arrays paralelos ou Bitmaps compactados (semelhante ao Roaring Bitmap) para rastrear o estado sujo (*dirty state*), expiração ou presença de chaves/entidades cacheadas na memória. Forte candidato para otimização interna da futura implementação do **Redis Client** (conforme especificado na [S13-Redis-Client.md](S13-Redis-Client.md)).
- **Filtros e Paginação de Alta Carga:** Interseção de grandes conjuntos de IDs ao processar consultas massivas no lado da aplicação.

## 4. Desafios de Implementação (Delphi)
Para que essa spec vire realidade no Dext Framework, os seguintes desafios técnicos deverão ser superados:
- **Intrínsecas SIMD em Delphi:** Delphi não possui o mesmo mapeamento direto de intrínsecas SIMD que o C/C++ possui (como `_mm_cmpeq_epi16`). Será necessário estudar o uso da `System.Math.Vectors` ou o uso direto de **Assembly Inline** (ex: `PAND`, `POR`, instruções XMM/YMM).
- **Multi-arquitetura:** Garantir que o fallback para busca linear/binária aconteça graciosamente caso a arquitetura alvo (ex: plataformas mais antigas) não suporte o subset específico de instruções SIMD adotado.

---

## 5. Código de Referência (C++ original)
Código original como prova de conceito (POC) demonstrando a estrutura Quaternária + SIMD para arrays de inteiros de 16-bits sem sinal.

```cpp
bool simd_quad(const uint16_t *carr, int32_t cardinality, uint16_t pos) {
    constexpr int32_t gap = 16;
    if (cardinality < gap) {
      for (int32_t j = 0; j < cardinality; j++) {
          if (carr[j] == pos) return true;
        }
        return false;
    }
    int32_t num_blocks = cardinality / gap;
    int32_t base = 0;
    int32_t n = num_blocks;
    
    // Quaternary Search
    while (n > 3) {
      int32_t quarter = n >> 2;
      int32_t k1 = carr[(base + quarter + 1) * gap - 1];
      int32_t k2 = carr[(base + 2 * quarter + 1) * gap - 1];
      int32_t k3 = carr[(base + 3 * quarter + 1) * gap - 1];
      int32_t c1 = (k1 < pos);
      int32_t c2 = (k2 < pos);
      int32_t c3 = (k3 < pos);
      base += (c1 + c2 + c3) * quarter;
      n -= 3 * quarter;
    }
    
    // Binary fallback for remaining < 3 blocks
    while (n > 1) {
        int32_t half = n >> 1;
        base = (carr[(base + half + 1) * gap - 1] < pos) ? base + half : base;
        n -= half;
    }
    int32_t lo = (carr[(base + 1) * gap - 1] < pos) ? base + 1 : base;

    // SIMD Check
    if (lo < num_blocks) {
        const uint16_t *blk = carr + lo * gap;
#ifdef __ARM_NEON
        uint16x8_t needle = vdupq_n_u16(pos);
        uint16x8_t v0 = vld1q_u16(blk);
        uint16x8_t v1 = vld1q_u16(blk + 8);
        uint16x8_t hit = vorrq_u16(vceqq_u16(v0, needle), vceqq_u16(v1, needle));
        return vmaxvq_u16(hit) != 0;
#else
        __m128i needle = _mm_set1_epi16((short)pos);
        __m128i v0 = _mm_loadu_si128((const __m128i *)blk);
        __m128i v1 = _mm_loadu_si128((const __m128i *)(blk + 8));
        __m128i hit = _mm_or_si128(_mm_cmpeq_epi16(v0, needle), _mm_cmpeq_epi16(v1, needle));
        return _mm_movemask_epi8(hit) != 0;
#endif
    }

    for (int32_t j = num_blocks * gap; j < cardinality; j++) {
        uint16_t v = carr[j];
        if (v >= pos) return (v == pos);
    }
    return false;
}
```

---

## 6. Otimizações Adicionais: Branchless Binary Search e Chunks

Além do algoritmo SIMD Quad, técnicas adicionais de *mechanical sympathy*
podem ser aplicadas para otimizar buscas em estruturas do Dext:

### 6.1. Busca Binária Branchless (Sem Desvios)
Em uma busca binária padrão, o desvio condicional (`if`) na comparação de
valores tem 50% de probabilidade de erro de predição pelo processador (*branch
misprediction*). Podemos mitigar isso com:
1. **Iterações Fixas:** Eliminar o `while left < right` usando um loop `for`
   de tamanho fixo $\lceil \log_2 N \rceil$.
2. **Seleção Branchless:** No Delphi, usar **Assembly Inline (`asm`)** para
   aplicar instruções `CMOVxx` (Conditional Move), evitando saltos condicionais.

### 6.2. Processamento em Lotes (Chunking) e SIMD
Para otimizar o uso do cache de CPU e permitir a auto-vetorização:
* Reordenar loops para iterar as etapas de busca no laço externo, e processar
  um bloco contíguo de dados (ex: chunks de 16 elementos) no laço interno.
* Elidir checagens de limites de array (`{$NOBOUNDS ON}`) nos trechos críticos.

Exemplo conceitual de busca binária branchless em Delphi Assembly:
```pascal
// Exemplo de uso de CMOV para busca branchless de chaves
function BranchlessSearch(const Arr: PInteger; Len, Target: Integer): Integer;
asm
  // EAX = Arr, EDX = Len, ECX = Target
  // Implementação utilizando CMOV para evitar desvios
  // ...
end;
```

