# 🧩 Dext Specifications - The Best of Both Worlds

Combinamos a elegância da **Criteria API do Spring4D** com a arquitetura limpa do **Specification Pattern (Ardalis)**.

## 🎯 O Conceito

Em vez de espalhar lógica de consulta (`Where`, `OrderBy`) por todo o código ou concatenar strings SQL, encapsulamos regras de negócio em classes reutilizáveis chamadas **Specifications**.

A "mágica" está na sintaxe fluente que permite escrever expressões lógicas em Delphi que são convertidas em uma Árvore de Expressões (AST) em tempo de execução.

## 📦 Exemplo Prático

### 1. Definindo a Specification

```pascal
type
  TExpensiveProductsSpec = class(TSpecification<TProduct>)
  public
    constructor Create(MinPrice: Currency); reintroduce;
  end;

constructor TExpensiveProductsSpec.Create(MinPrice: Currency);
begin
  inherited Create;
  
  // ✨ Sintaxe Mágica: Prop('Name') > Value
  Where( 
    (Prop('Price') > MinPrice) and 
    (Prop('IsActive') = True) 
  );
  
  AddInclude('Category');
  ApplyPaging(0, 10);
end;
```

### 2. Usando no Repositório (Futuro)

```pascal
var
  Spec := TExpensiveProductsSpec.Create(100.00);
  Products := Repository.List(Spec);
```

## 🛠️ Como Funciona (Under the Hood)

1.  **`Prop('Name')`**: Retorna um record `TProperty`.
2.  **`>` (Operator Overloading)**: O operador `GreaterThan` retorna um record `TExpression` contendo um `IExpression` (nó da árvore).
3.  **`and` (Logical Operator)**: O operador `LogicalAnd` combina dois `TExpression` em um novo nó `AND`.
4.  **`Where(...)`**: Recebe a árvore final e armazena na Specification.

### Geração de SQL

O `TSQLWhereGenerator` percorre a árvore de critérios e gera SQL parametrizado automaticamente:

```sql
-- Exemplo de saída gerada para a Spec acima
WHERE ((Price > :p1) AND (IsActive = :p2))
-- Parâmetros: p1=100, p2=True
```

## 🚀 Benefícios

1.  **Type Safety**: Erros de sintaxe são pegos em tempo de compilação (ex: tentar comparar tipos incompatíveis, se expandirmos a tipagem).
2.  **Database Agnostic**: A árvore de critérios é abstrata. Um `Visitor` pode traduzi-la para SQL (FireDAC), JSON (para API), ou até filtrar uma lista em memória!
3.  **Clean Architecture**: Regras de consulta ficam na camada de Domínio, não na Infraestrutura.
4.  **Testabilidade**: Você pode testar se a Spec gera a árvore correta sem precisar de um banco de dados.
5.  **Segurança**: Geração automática de parâmetros previne SQL Injection.

## 📂 Estrutura dos Arquivos

- `Dext.Specifications.Interfaces.pas`: Contratos base (`ISpecification`, `IExpression`).
- `Dext.Specifications.Types.pas`: Implementações dos nós da árvore (`TBinaryExpression`, etc).
- `Dext.Specifications.Criteria.pas`: A mágica dos operadores (`Prop`, `TExpression`).
- `Dext.Specifications.Base.pas`: Classe base `TSpecification<T>`.

---

**Dext Framework** - Pushing Delphi to the Limit! 🚀
