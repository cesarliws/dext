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

---

## 5. Diretrizes e Cuidados com a Diretiva `inline`

O uso indiscriminado da diretiva `inline` pode prejudicar o projeto de várias formas (gerando acoplamento circular, binary bloat e falhas de compilação incremental). Devemos seguir as seguintes regras arquiteturais:

### Quando usar `inline`:
1. **Métodos Folha Simples (Accessors)**: Métodos que apenas retornam ou alteram campos de classe/record (`getters` e `setters` sem ramificações lógicas complexas ou inicializações de objetos).
2. **Métodos de Encaminhamento Direto**: Métodos que apenas repassam parâmetros para outra rotina interna sem adicionar lógica estrutural (ex: `LHS + RHS` chamando `RHS + LHS`).
3. **Loops Apertados (SIMD / Vetores)**: Funções críticas de aritmética vetorial ou operações de bytes que são chamadas repetidamente e se beneficiam do uso direto de registradores da CPU.

### Quando EVITAR `inline`:
1. **Instanciação de Objetos**: Métodos que chamam construtores, alocam memória ou instanciam classes de AST (como `TPropertyExpression.Create`).
2. **Lógica Condicional Complexa**: Métodos com múltiplos caminhos de código (`if/else`), pois aumentam drasticamente a dispersão de cache L1 na CPU (Instruction Cache Misses).
3. **Conversões complexas e Variant**: Rotinas que envolvem manipulação de `Variant` ou conversões genéricas dinâmicas via `TValue`.
4. **Dependências em cascata**: Métodos que geram hints de unidades ausentes (Hint H2443). Se a rotina exige unidades no uses que o consumidor não tem, a diretiva deve ser removida.

