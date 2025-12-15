# Options Pattern no Dext

O padrão de Opções (`IOptions<T>`) permite acesso fortemente tipado a configurações, separando a lógica de leitura de configuração da lógica de consumo.

## Definindo a Classe de Configuração

Crie uma classe simples (POCO) que represente a seção de configuração desejada.

```pascal
type
  TMySettings = class
  private
    FMessage: string;
    FMaxRetries: Integer;
  public
    property Message: string read FMessage write FMessage;
    property MaxRetries: Integer read FMaxRetries write FMaxRetries;
  end;
```

## Configurando no `appsettings.json`

```json
{
  "AppSettings": {
    "Message": "Hello World",
    "MaxRetries": 5
  }
}
```

## Registrando no Container

Use `TOptionsServiceCollectionExtensions.Configure<T>` para vincular a classe à seção de configuração.

```pascal
uses
  Dext.Options.Extensions;

// ...

TOptionsServiceCollectionExtensions.Configure<TMySettings>(
  App.Services, 
  App.Configuration.GetSection('AppSettings')
);
```

## Injetando e Usando

Injete `IOptions<TMySettings>` no seu Controller ou Serviço.

```pascal
uses
  Dext.Options;

type
  TMyController = class
  private
    FSettings: IOptions<TMySettings>;
  public
    constructor Create(Settings: IOptions<TMySettings>);
    
    [DextGet('/config')]
    procedure GetConfig(Ctx: IHttpContext);
  end;

constructor TMyController.Create(Settings: IOptions<TMySettings>);
begin
  FSettings := Settings;
end;

procedure TMyController.GetConfig(Ctx: IHttpContext);
begin
  // Acesso tipado via .Value
  var Msg := FSettings.Value.Message;
  var Retries := FSettings.Value.MaxRetries;
  
  Ctx.Response.Json(Format('Msg: %s, Retries: %d', [Msg, Retries]));
end;
```

## Benefícios

*   **Tipagem Forte**: Evita erros de digitação de strings ("Magic Strings").
*   **Separação de Responsabilidades**: O Controller não precisa saber de onde vem a configuração (JSON, Env Var, etc.), apenas que ela existe.
*   **Testabilidade**: Fácil de mockar em testes unitários.
