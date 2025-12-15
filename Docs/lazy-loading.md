# 💤 Lazy Loading no Dext ORM

O Dext ORM suporta **Lazy Loading** (carregamento tardio) de propriedades de navegação, permitindo que dados relacionados sejam carregados do banco de dados apenas quando forem acessados pela primeira vez.

## Como Funciona

O Lazy Loading no Dext utiliza uma combinação de **Interfaces Virtuais (`TVirtualInterface`)** e um tipo genérico auxiliar `ILazy<T>`.

Quando uma entidade é carregada do banco de dados (`Hydrate`), o framework injeta automaticamente proxies nas propriedades marcadas como `lazy`.

### Implementação Técnica

1.  **`ILazy<T>`**: Uma interface que envolve o valor real. Possui propriedades `Value` (o dado real) e `IsValueCreated` (booleano).
2.  **`TLazy<T>`**: Um record que implementa a estrutura para armazenar a interface.
3.  **`TVirtualInterface`**: O framework cria dinamicamente uma implementação de `ILazy<T>` em tempo de execução.
4.  **`TLazyInvokeHandler`**: Intercepta as chamadas aos métodos da interface (`GetValue`, `GetIsValueCreated`). Quando `GetValue` é chamado pela primeira vez, ele executa a consulta no banco de dados e armazena o resultado.

## Como Usar

Para habilitar o Lazy Loading em suas entidades, utilize o tipo `Lazy<T>` para propriedades de referência (1:1 ou N:1) e `Lazy<TList<T>>` para coleções (1:N).

### Exemplo de Entidade

```pascal
type
  [Table('Users')]
  TUser = class
  private
    FId: Integer;
    FName: string;
    FAddressId: Integer;
    // Lazy Reference
    FAddress: Lazy<TAddress>; 
    function GetAddress: TAddress;
  public
    property Id: Integer read FId write FId;
    property Name: string read FName write FName;
    property AddressId: Integer read FAddressId write FAddressId;
    
    // A propriedade pública expõe o tipo real (TAddress)
    // O getter acessa FAddress.Value, disparando o carregamento
    property Address: TAddress read GetAddress;
  end;

  [Table('Addresses')]
  TAddress = class
  private
    FId: Integer;
    FStreet: string;
    // Lazy Collection
    FUsers: Lazy<TList<TUser>>;
    function GetUsers: TList<TUser>;
  public
    constructor Create;
    destructor Destroy; override;
    
    property Id: Integer read FId write FId;
    property Street: string read FStreet write FStreet;
    
    // A propriedade pública expõe a lista (TList<TUser>)
    property Users: TList<TUser> read GetUsers;
  end;

implementation

function TUser.GetAddress: TAddress;
begin
  // Acessar .Value dispara o Lazy Loading se ainda não carregado
  Result := FAddress.Value;
end;

constructor TAddress.Create;
begin
  // Inicializa a coleção lazy vazia para evitar Access Violation em novas entidades
  // O framework substituirá isso pela implementação VirtualInterface ao carregar do DB
  FUsers := Lazy<TList<TUser>>.Create(TList<TUser>.Create);
end;

function TAddress.GetUsers: TList<TUser>;
begin
  Result := FUsers.Value;
end;
```

## Comportamento e Detalhes

### Carregamento Automático vs. Explícito

*   **Automático**: Basta acessar a propriedade (ex: `MyUser.Address.Street`). O framework carregará os dados transparentemente.
*   **Explícito**: Você pode forçar o carregamento usando `Entry(Entity).Collection('Users').Load`.

**Nota Importante**: O framework possui proteção contra duplicação. Se você acessar a propriedade (disparando o lazy load) e depois chamar `.Load` explicitamente, o framework detectará que a coleção já contém itens e não duplicará os dados.

### Prevenção de Recursão

O mecanismo de Lazy Loading possui proteções internas (`FLoaded` flag) para evitar loops infinitos caso haja referências circulares durante o processo de hidratação.

## Limitações Atuais e Known Issues

*   **Concurrency**: Testes de concorrência (`Optimistic Concurrency`) podem falhar em cenários complexos de Lazy Loading.
*   **Fluent API**: Algumas operações da Fluent API (`Any`, `FirstOrDefault`) podem não interagir perfeitamente com propriedades Lazy ainda não carregadas.

## Debugging

Se precisar depurar o Lazy Loading, verifique a unit `Dext.Entity.LazyLoading.pas`. O `TLazyInvokeHandler` é o coração do mecanismo.
