# 🧠 Dext AI - Roadmap

Este roadmap define a estratégia para integrar Inteligência Artificial Generativa (GenAI) e LLMs diretamente no ecossistema Dext.

> **Visão:** Trazer o poder de orquestração do **Semantic Kernel** e **LangChain** para o Delphi, permitindo que desenvolvedores construam aplicações "AI-Native" com a mesma facilidade que constroem APIs Web.

---

## 🤖 Dext.SemanticKernel (Orchestration)

Inspirado no Microsoft Semantic Kernel, este módulo será o "cérebro" para integrar LLMs com código nativo.

### 1. Core Abstractions
- [ ] **IChatCompletion**: Interface unificada para chat (OpenAI, Azure OpenAI, Anthropic, Ollama).
- [ ] **ITextEmbedding**: Interface para geração de vetores (embeddings).
- [ ] **Prompt Templates**: Engine para renderizar prompts dinâmicos com variáveis (`"Olá {{name}}, ajude-me com..."`).

### 2. Plugins & Native Functions (The "Glue")
A capacidade de LLMs chamarem código Delphi (Function Calling).
- [ ] **Native Plugins**: Expor classes Delphi como "Skills" para a IA usando RTTI.
  - Atributos: `[SKFunction]`, `[SKDescription]`.
  - Geração automática de Schema JSON para a LLM entender a função.
- [ ] **Planner**: Um agente que decide quais funções chamar para resolver uma solicitação complexa do usuário.

### 3. Structured Output (Pydantic-like)
- [ ] **Schema Validation**: Garantir que a IA retorne JSON válido que mapeia exatamente para um `record` ou `class` Delphi.
- [ ] **Auto-Repair**: Tentar corrigir JSON inválido automaticamente.

---

## 🧠 Memory & Vector Database (RAG)

Implementação do padrão RAG (Retrieval-Augmented Generation) para dar "memória" e contexto à IA.

### 1. Vector Store Abstraction (`IVectorStore`)
Interface genérica para armazenar e buscar vetores.
- [ ] **In-Memory Store**: Para testes e datasets pequenos.
- [ ] **Pgvector Support**: Integração nativa com PostgreSQL (via Dext ORM).
- [ ] **Qdrant/Pinecone**: Drivers para bancos vetoriais dedicados.

### 2. Document Processing
- [ ] **Text Splitters**: Utilitários para quebrar textos grandes em chunks (Token-based, Line-based).
- [ ] **Document Loaders**: Leitores para PDF, Text, Markdown.

---

## ⚡ Local Inference & Data

### 1. Local LLM Support
- [ ] **Ollama Integration**: Cliente nativo otimizado para Ollama (Llama 3, Phi-3).
- [ ] **ONNX Runtime**: (Investigação) Executar modelos menores (embeddings, classificação) in-process.

### 2. Data Processing
- [ ] **Dext.Data**: Estruturas de dados leves para manipulação tabular (inspirado em DataFrames, mas focado em performance e tipagem).

---

## 📅 Exemplo de Uso (Vision)

```delphi
var
  Kernel: IKernel;
  Result: string;
begin
  Kernel := TSemanticKernel.CreateBuilder
    .AddOpenAIChatCompletion('gpt-4')
    .AddPlugin<TOrderPlugin>('Orders') // Expose Delphi code
    .Build;

  // A IA decide chamar TOrderPlugin.GetOrderStatus(123) automaticamente
  Result := await Kernel.InvokeAsync('Qual o status do meu pedido 123?');
end;
```
