# ⚙️ Sistema de Configuração (Configuration)

O **Dext** possui um sistema de configuração robusto e flexível, inspirado no `Microsoft.Extensions.Configuration` do ASP.NET Core. Ele permite carregar configurações de múltiplas fontes (JSON, Variáveis de Ambiente, etc.) e acessá-las de forma unificada e tipada.

## 🚀 Visão Geral

O sistema de configuração é baseado em pares chave-valor, mas suporta estruturas hierárquicas (como objetos JSON). As chaves são separadas por dois pontos (`:`), permitindo acesso profundo a propriedades aninhadas.

### Principais Características

*   **Múltiplas Fontes**: Carregue configurações de arquivos JSON, variáveis de ambiente, argumentos de linha de comando (futuro), etc.
*   **Hierárquico**: Suporte a seções e sub-seções.
*   **Unificado**: Acesso transparente independente da origem do valor.
*   **Sobrescrita**: Fontes adicionadas por último sobrescrevem valores de fontes anteriores (ex: Variáveis de Ambiente sobrescrevem `appsettings.json`).

---

## 📦 Instalação

O sistema de configuração faz parte do core do Dext. Certifique-se de que seu projeto referencia as units necessárias:

```delphi
uses
  Dext.Configuration.Interfaces,
  Dext.Configuration.Core,
  Dext.Configuration.Json,
  Dext.Configuration.EnvironmentVariables;
```

---

## 🛠️ Como Usar

### 1. Construindo a Configuração

Utilize o `TConfigurationBuilder` para configurar as fontes e gerar a raiz de configuração (`IConfigurationRoot`).

```delphi
var
  Builder: IConfigurationBuilder;
  Config: IConfigurationRoot;
begin
  Builder := TConfigurationBuilder.Create
    .SetBasePath(GetCurrentDir)
    .AddJsonFile('appsettings.json', True) // Opcional = True
    .AddEnvironmentVariables; // Carrega variáveis de ambiente

  Config := Builder.Build;
end;
```

### 2. Acessando Valores

Você pode acessar valores simples usando a sintaxe de indexador ou métodos auxiliares.

**Exemplo de `appsettings.json`:**
```json
{
  "AppSettings": {
    "Message": "Olá Mundo",
    "MaxItems": 100
  },
  "Logging": {
    "LogLevel": {
      "Default": "Debug"
    }
  }
}
```

**Lendo valores:**

```delphi
var
  Message: string;
  MaxItems: Integer;
  LogLevel: string;
begin
  // Acesso direto por chave hierárquica
  Message := Config['AppSettings:Message']; 
  
  // Conversão de tipos (se disponível helpers, ou manual)
  MaxItems := StrToIntDef(Config['AppSettings:MaxItems'], 0);
  
  // Acesso profundo
  LogLevel := Config['Logging:LogLevel:Default'];
end;
```

### 3. Seções (Sections)

Para organizar melhor o código, você pode trabalhar com sub-seções da configuração.

```delphi
var
  AppSection: IConfigurationSection;
begin
  AppSection := Config.GetSection('AppSettings');
  
  // Agora as chaves são relativas à seção
  WriteLn(AppSection['Message']); // "Olá Mundo"
end;
```

---

## 🔌 Providers Suportados

### JSON Provider (`AddJsonFile`)

Carrega configurações de arquivos JSON. Suporta estruturas aninhadas e arrays.

```delphi
Builder.AddJsonFile('config.json', Optional: Boolean = False);
```

### Environment Variables Provider (`AddEnvironmentVariables`)

Carrega configurações das variáveis de ambiente do sistema operacional. Útil para Docker e CI/CD.

```delphi
Builder.AddEnvironmentVariables;
```

**Nota:** Variáveis de ambiente com `__` (duplo sublinhado) são convertidas para `:` na hierarquia de configuração.
Exemplo: `Logging__LogLevel__Default` mapeia para `Logging:LogLevel:Default`.

---

## 🧩 Exemplo Completo

Veja o exemplo em `Examples\TestConfig.dpr` para uma demonstração funcional.

```delphi
program TestConfig;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Dext.Configuration.Interfaces,
  Dext.Configuration.Core,
  Dext.Configuration.Json,
  Dext.Configuration.EnvironmentVariables;

begin
  try
    var Config := TConfigurationBuilder.Create
      .SetBasePath(GetCurrentDir)
      .AddJsonFile('appsettings.json', True)
      .AddEnvironmentVariables
      .Build;

    WriteLn('Message: ' + Config['AppSettings:Message']);
  except
    on E: Exception do
      WriteLn(E.ClassName, ': ', E.Message);
  end;
end.
```
