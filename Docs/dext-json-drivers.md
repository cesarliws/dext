# Dext JSON - Arquitetura de Drivers

O **Dext Framework** possui um sistema de serialização JSON flexível e desacoplado, permitindo que você escolha qual biblioteca ("motor") JSON deseja utilizar por baixo dos panos.

Isso garante que o framework possa se adaptar a diferentes versões do Delphi e requisitos de performance, sem que você precise alterar seu código de negócio.

## Drivers Disponíveis

Atualmente, o Dext suporta dois drivers:

1.  **JsonDataObjects** (`Dext.Json.Driver.JsonDataObjects`)
    *   **Status:** Padrão (Default).
    *   **Descrição:** Uma das bibliotecas JSON mais rápidas e leves para Delphi.
    *   **Vantagens:** Performance extrema, suporte a versões antigas do Delphi.

2.  **System.JSON** (`Dext.Json.Driver.SystemJson`)
    *   **Status:** Nativo.
    *   **Descrição:** A biblioteca padrão incluída no Delphi (RTL).
    *   **Vantagens:** Sem dependências de terceiros, integração nativa.

## Como Configurar

A troca de driver é global e extremamente simples. Basta definir a propriedade `TDextJson.Provider` na inicialização da sua aplicação (por exemplo, no `dpr` ou no `initialization` de uma unit central).

### Usando o Driver Padrão (JsonDataObjects)

Não é necessário nenhuma configuração extra, pois este é o padrão.

```pascal
uses
  Dext.Json;

// ...
var Json := TDextJson.Serialize(MeuObjeto);
```

### Usando o Driver System.JSON

Adicione a unit do driver e configure o provider:

```pascal
uses
  Dext.Json,
  Dext.Json.Driver.SystemJson; // Adicione esta unit

begin
  // Configure o provider para usar a RTL nativa do Delphi
  TDextJson.Provider := TSystemJsonProvider.Create;

  // A partir de agora, todo o framework usará System.JSON
  var Json := TDextJson.Serialize(MeuObjeto);
end;
```

## Criando seu Próprio Driver

Se você deseja usar outra biblioteca (como SuperObject, XSuperObject, ou LkJSON), basta implementar a interface `IDextJsonProvider` e as interfaces de nó (`IDextJsonObject`, `IDextJsonArray`).

### 1. Implemente as Interfaces

Crie uma nova unit e implemente as interfaces definidas em `Dext.Json.Types`:

```pascal
type
  TMyCustomProvider = class(TInterfacedObject, IDextJsonProvider)
  public
    function CreateObject: IDextJsonObject;
    function CreateArray: IDextJsonArray;
    function Parse(const Json: string): IDextJsonNode;
  end;
```

### 2. Registre seu Driver

```pascal
TDextJson.Provider := TMyCustomProvider.Create;
```

## Compatibilidade

A camada de abstração do Dext garante que recursos avançados funcionem independentemente do driver escolhido:

*   Atributos (`[JsonName]`, `[JsonIgnore]`, etc.)
*   Conversão automática de tipos (String <-> Number)
*   Formatação de Datas (ISO8601, Unix Timestamp)
*   Estilos de Case (camelCase, snake_case)
*   Serialização de Records, Arrays e Listas Genéricas
