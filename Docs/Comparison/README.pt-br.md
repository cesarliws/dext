# Dext Framework — Documentação de Posicionamento e Marketing

Esta pasta contém os documentos de posicionamento estratégico e comparações técnicas para o Dext Framework.

---

## Mapa de Documentos

### 1. [`Dext_vs_DotNet_Narrative.pt-br.md`](./Dext_vs_DotNet_Narrative.pt-br.md) — *A História*

> **"Por que o Dext foi construído — e o que ele representa para o Delphi em 2026."**

Um documento narrativo, focado na leitura humana. Ideal para postagens em blogs, fóruns de tecnologia, apresentações para a comunidade ou para qualquer pessoa que queira ter uma primeira impressão geral do Dext. Explica o *porquê* e os impactos práticos, em vez de focar apenas em listagens de recursos.

**Ideal para:**
- Posts em blogs e artigos para a comunidade
- Tópicos de introdução em fóruns de programação e comunidades Delphi
- Leitura rápida para CTOs e gerentes de engenharia
- Desenvolvedores vindos de outros ecossistemas (como .NET, Java ou Go) avaliando o Dext pela primeira vez

---

### 2. [`Feature_Comparison_Dext_vs_DotNet.pt-br.md`](./Feature_Comparison_Dext_vs_DotNet.pt-br.md) — *A Tabela de Referência*

> **"O que o Dext faz — recurso por recurso, lado a lado com o .NET."**

Um documento técnico, objetivo e altamente estruturado. Está organizado em quatro blocos distintos:
- **Bloco A**: Mais de 60 recursos em paridade funcional total com o ASP.NET Core + EF Core
- **Bloco B**: 17 recursos exclusivos do Dext (indisponíveis de forma nativa no ecossistema .NET)
- **Bloco C**: Lacunas honestas e roadmap de desenvolvimento do framework
- **Bloco D**: Diferenças de plataforma e contexto que não se aplicam ao Delphi por design

**Ideal para:**
- Líderes técnicos que precisam fazer uma avaliação formal de tecnologia
- Desenvolvedores que buscam um dicionário preciso ou consulta rápida de recursos
- Links em relações públicas ou no README do projeto como comprovação técnica de recursos
- Contribuidores de código open-source analisando onde focar esforços

---

### 3. [`Dext_ORM_Capabilities.pt-br.md`](./Dext_ORM_Capabilities.pt-br.md) — *O Deep-Dive no ORM*

> **"Como o Dext ORM funciona — arquitetura, código e capacidades exclusivas."**

Um mergulho técnico focado exclusivamente no ORM e na camada de acesso a dados. Contém exemplos de código reais lado a lado (Delphi vs C#) para todos os padrões essenciais de persistência, incluindo seções detalhadas sobre Mapeamento Aninhado (Multi-Mapping), Stored Procedures declarativas, Smart Properties, EntityDataSet, Consultas em Colunas JSON e as otimizações de arquitetura de alto desempenho em tempo de compilação.

**Ideal para:**
- Desenvolvedores Delphi adotando ou aprendendo o Dext.ORM
- Escritores técnicos documentando as capacidades do ORM
- Equipes migrando de soluções legadas como FireDAC ou outros frameworks de mercado para o Dext
- Engenheiros avaliando a profundidade do ORM de forma independente do restante do framework

---

### 4. [`Open_Source_Licensing_Enterprise.pt-br.md`](./Open_Source_Licensing_Enterprise.pt-br.md) — *O Guia de Segurança Corporativa*

> **"Por que a Apache 2.0 importa — conformidade legal, proteção de patentes e validação automática no pipeline de CI/CD."**

Um whitepaper focado na avaliação jurídica e de compliance corporativo. Cobre a importância estratégica da licença Apache 2.0 sobre outras opções (GPL, MIT, LGPL), como o Dext é validado por ferramentas automatizadas de análise de licenças (como o Snyk) e o que isso significa para o desenvolvimento de produtos comerciais proprietários.

**Ideal para:**
- Departamentos jurídicos e setores de compras de grandes empresas
- CTOs e arquitetos de software avaliando riscos de licenciamento de terceiros
- Organizações com diretrizes estritas de PI (Propriedade Intelectual) e patentes
- Equipes que operam verificação automatizada de conformidade no pipeline de CI/CD

---

## Ordem de Leitura Recomendada por Perfil

| Seu perfil... | Comece por | Em seguida, leia |
|:---|:---|:---|
| **Desenvolvedor .NET / Java / Go** curioso sobre Dext | A História (Narrative) | Tabela de Referência (Bloco B) |
| **Líder Técnico / Arquiteto** avaliando a stack | Tabela de Referência | Mergulho no ORM (ORM Capabilities) |
| **Desenvolvedor Delphi** adotando o framework | Mergulho no ORM (ORM Capabilities) | — |
| **CTO / Gestor** precisando de uma visão executiva | A História (pule para "Os Números") | Guia de Segurança Corporativa (Licensing) |
| **Jurídico / Compliance Corporativo** | Guia de Segurança Corporativa (Licensing) | — |
| **Contribuidor do Projeto** | Tabela de Referência (Bloco C - Roadmap) | Visão Geral do Ecossistema |

---

## Referências Externas

- 📘 [Visão Geral do Ecossistema Dext](https://github.com/dotpas/dext/blob/main/Docs/Dext_Ecosystem_Overview.pt-br.md) — Deep-dive arquitetônico: pipelines de alocação zero, coleções SIMD e Binary Code Folding.
- 📗 [Índice de Recursos Implementados](https://github.com/dotpas/dext/blob/main/Docs/Features_Implemented_Index.pt-br.md) — Lista completa de funcionalidades implementadas e especificações técnicas de design.
- 🗺️ [Roadmap](https://github.com/dotpas/dext/blob/main/Docs/ROADMAP.md) — Cronograma de entrega planejado por ondas (Waves).

---

*Dext Framework | Maio de 2026*
