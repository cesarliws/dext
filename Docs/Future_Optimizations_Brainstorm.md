# Brainstorming: Futuras Otimizações de Compilação e Performance no Dext

Este documento reúne ideias e caminhos de otimização de performance e tempo de compilação no Dext Framework, baseando-se no aprendizado obtido com a otimização dos *Smart Types*.

---

## 1. Fluent Specifications (`Dext.Specifications.Fluent.pas` e `Base.pas`)

O framework de especificações constrói árvores de expressão (AST) usando métodos fluentes e operadores para encadear regras (ex: `Spec.And()`, `Spec.Or()`).

### Oportunidade
- A maioria desses métodos e operadores pode ser marcada com `inline`. 
- Isso fará com que o compilador elimine a chamada da função que apenas encapsula a criação do nó `TLogicalExpression` ou `TBinaryExpression`, otimizando a montagem de consultas em tempo de compilação e execução, reduzindo a sobrecarga de pilha.

---

## 2. Dext Collections & SIMD (`Dext.Collections.Simd.pas` e `Vector.pas`)

Para operações de array, agrupamentos ou cálculos vetoriais em lote no Dext Collections:

### Oportunidade
- As chamadas de loops de iteração e operações internas de SIMD/vetores são extremamente sensíveis ao overhead de chamada de função. 
- Garantir que as funções críticas de cópia, movimentação e comparação de blocos de memória estejam como `inline` permite que o compilador use registradores diretamente (evitando a criação de frames de pilha em loops apertados).

---

## 3. Injeção de Dependência (`Dext.DI.Core.pas` e `Dext.DI.Extensions.pas`)

O motor de DI lida muito com métodos genéricos como `Resolve<T>` ou `Register<T>`.

### Oportunidade
- A resolução de escopo em aplicações Web é executada a cada requisição HTTP. 
- Podemos reduzir o overhead de chamadas genéricas repetitivas fazendo cache de atalhos de ativação (`TActivator`) usando ponteiros de funções não-genéricas ou armazenando em dicionários indexados pelo ponteiro do `TypeInfo` (em vez de usar strings ou metadados pesados do RTTI toda vez).

---

## 4. Dext JSON (`Dext.Json.pas`)

O parser e serializador JSON lidam com loops complexos inspecionando propriedades de records e classes via RTTI.

### Oportunidade
- Métodos genéricos utilitários de serialização de tipos primitivos (como números, datas e moedas) podem ser inlinizados. 
- A extração de campos em records genéricos pode ser otimizada utilizando *desacopladores estáticos não-genéricos* para cachear o layout de memória de records uma única vez, acelerando drasticamente o throughput de serialização de APIs.
