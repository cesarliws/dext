# Dext.Persistence (Facade Unit)

A unit `Dext.Persistence` atua como o ponto de entrada principal (Facade) para o framework Dext ORM. Seu objetivo é simplificar a cláusula `uses` das suas aplicações, centralizando os tipos mais comuns.

## ✅ O que está incluído

Você pode usar apenas `Dext.Persistence` para acessar:

### Interfaces Principais
*   `IDbContext`
*   `IDbSet`
*   `IExpression`
*   `TDbContext` (Classe concreta)

### Atributos de Mapeamento
*   `[Table('Name')]`
*   `[Column('Name')]`
*   `[PK]`
*   `[AutoInc]`
*   `[ForeignKey('Column')]`
*   `[NotMapped]`
*   `[Version]` (Concorrência Otimista)

### Tipos Auxiliares
*   `Lazy<T>` (Record implementado localmente para facilidade de uso)
*   `TPropExpression` (Alias para construção de queries type-safe)
*   `Specification` (Helper estático para Fluent API)
*   `TCascadeAction` (Enum)
*   `TQueryGrouping` (Helper para GroupBy)
*   `TQueryJoin` (Helper para Joins)

## ⚠️ Limitações e Units Adicionais Necessárias

Devido a limitações da linguagem Delphi, **tipos genéricos (Interfaces e Classes)** não podem ser facilmente exportados via aliases. Você deve adicionar as units originais ao seu `uses` quando precisar desses tipos específicos.

### 1. Fluent Query & LINQ (`Dext.Entity.Query`)
Necessário para usar `TFluentQuery<T>` e métodos de extensão LINQ.
*   `TFluentQuery<T>`

### 2. Especificações (`Dext.Specifications.Base` / `Interfaces`)
Necessário para criar especificações customizadas ou usar interfaces de paginação.
*   `TSpecification<T>` (Classe Base)
*   `ISpecification<T>` (Interface)
*   `IPagedResult<T>` (Interface)

### 3. Agrupamento (`Dext.Entity.Grouping`)
Necessário para trabalhar com resultados agrupados.
*   `IGrouping<K, V>`

### 4. Fluent Builder (`Dext.Specifications.Fluent`)
Necessário se você estiver instanciando builders manualmente (raro, geralmente usa-se `Specification`).
*   `TSpecificationBuilder<T>`

## Exemplo de Uso Recomendado

```pascal
unit MyDomain.Services;

interface

uses
  Dext.Persistence,           // Tipos base
  Dext.Entity.Query,          // Para TFluentQuery<T>
  Dext.Specifications.Base;   // Para TSpecification<T>

type
  TMyService = class
  public
    function GetAdults: TFluentQuery<TUser>;
  end;
```
