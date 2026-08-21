# Spec 67: CommandLine & UserSecrets Configuration Providers

**Status:** Finalized  
**Author:** Dext Team  
**Date:** 2026-08-21  
**Area:** `Dext.Configuration` / `Dext.Web`

---

## 1. Contexto e Motivação

Atualmente, o **Dext Framework** (C:\dev\Dext\DextRepository) implementa a resolução de configurações através do `TConfigurationBuilder` em `Dext.Web.WebApplication.pas` com a seguinte hierarquia LIFO de 3 camadas:
1. `appsettings.json` / `appsettings.yaml` (Base)
2. `appsettings.{DEXT_ENVIRONMENT}.json` / `.yaml` (Ambiente)
3. Variáveis de Ambiente do S.O. (`Dext.Configuration.EnvironmentVariables.pas`)

Para equiparar o Dext ao padrão enterprise moderno (**Twelve-Factor App & Modern Configuration**) e suportar o pipeline completo de 5 camadas, esta especificação introduz:
1. **`CommandLineConfigurationProvider`**: Sobrescrita de configurações via argumentos de inicialização (`--Key=Value` ou `/Key=Value`).
2. **`UserSecretsConfigurationProvider`**: Isolamento de segredos de desenvolvimento local fora da árvore do Git (`secrets.json`).

---

## 2. Arquitetura da Hierarquia de Precedência (5 Camadas)

A ordem canônica de registro no `TConfigurationBuilder` do `WebApplication` é:

```
[1] Arquivos Base (JSON / YAML)               --> Menor Prioridade (Fallback)
[2] Arquivo de Ambiente ({Env}.json / .yaml)   --> Sobrescreve Base
[3] User Secrets (se Env = 'Development')     --> Sobrescreve Arquivo de Ambiente
[4] Variáveis de Ambiente do S.O.             --> Sobrescreve Arquivos e Secrets
[5] Argumentos de Linha de Comando (CLI)      --> Prioridade Máxima
```

---

## 3. Especificação do `TCommandLineConfigurationProvider`

### 3.1 Unidade e Localização
- **Nova Unit:** `Dext.Configuration.CommandLine.pas` em `DextRepository\Sources\Core\`.

### 3.2 Sintaxes de Argumentos Suportadas
O provedor deve iterar sobre `ParamStr(1..ParamCount)` (ou aceitar um `TArray<string>` customizado) e processar os seguintes formatos:

1. **Padrão com Chave e Valor (`--Key=Value` ou `/Key=Value`):**
   - `--Server:Port=9090` $\rightarrow$ Chave: `Server:Port`, Valor: `9090`
   - `--Database__Password=Secret` $\rightarrow$ Converte `__` para `:` $\rightarrow$ Chave: `Database:Password`, Valor: `Secret`
   - `/Faturamento:MaxDiscount=15` $\rightarrow$ Chave: `Faturamento:MaxDiscount`, Valor: `15`

2. **Padrão com Chave e Valor Separados por Espaço (`--Key Value`):**
   - `--Server:Port 9090` $\rightarrow$ Reconhece `--Server:Port` como chave e o próximo token `9090` como valor.

3. **Mapeamento de Aliases / Switches:**
   - Suporte opcional a dicionário de mapeamento de switches curtos (ex: `-p` $\rightarrow$ `Server:Port`, `-e` $\rightarrow$ `DEXT_ENVIRONMENT`).

### 3.3 Interface e Classes
```pascal
unit Dext.Configuration.CommandLine;

interface

uses
  System.SysUtils,
  System.Classes,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.Configuration.Interfaces,
  Dext.Configuration.Core;

type
  TCommandLineConfigurationProvider = class(TConfigurationProvider)
  private
    FArgs: TArray<string>;
    FSwitchMappings: IDictionary<string, string>;
    procedure ParseArgs;
  public
    constructor Create(const Args: TArray<string> = nil; const SwitchMappings: IDictionary<string, string> = nil);
    destructor Destroy; override;
    procedure Load; override;
  end;

  TCommandLineConfigurationSource = class(TInterfacedObject, IConfigurationSource)
  private
    FArgs: TArray<string>;
    FSwitchMappings: IDictionary<string, string>;
  public
    constructor Create(const Args: TArray<string> = nil; const SwitchMappings: IDictionary<string, string> = nil);
    destructor Destroy; override;
    function Build(Builder: IConfigurationBuilder): IConfigurationProvider;
  end;
```

---

## 4. Especificação do `TUserSecretsConfigurationProvider`

### 4.1 Unidade e Localização
- **Nova Unit:** `Dext.Configuration.UserSecrets.pas` em `DextRepository\Sources\Core\`.

### 4.2 Localização Física dos Arquivos de Segredos
O segredo é indexado por um `UserSecretsId` (GUID ou string única do projeto).

Caminhos padrão nos sistemas operacionais:
- **Windows:** `%APPDATA%\Dext\UserSecrets\<UserSecretsId>\secrets.json`  
  (ex: `C:\Users\<User>\AppData\Roaming\Dext\UserSecrets\<Id>\secrets.json`)
- **Linux / macOS:** `~/.dext/usersecrets/<UserSecretsId>/secrets.json`

### 4.3 Interface e Classes
```pascal
unit Dext.Configuration.UserSecrets;

interface

uses
  System.SysUtils,
  System.IOUtils,
  Dext.Configuration.Interfaces,
  Dext.Configuration.Core,
  Dext.Configuration.Json;

type
  TUserSecretsConfigurationProvider = class(TJsonConfigurationProvider)
  private
    FUserSecretsId: string;
  public
    constructor Create(const UserSecretsId: string; Optional: Boolean = True; ReloadOnChange: Boolean = False);
    property UserSecretsId: string read FUserSecretsId;
    class function ResolveSecretsFilePath(const UserSecretsId: string): string; static;
  end;

  TUserSecretsConfigurationSource = class(TInterfacedObject, IConfigurationSource)
  private
    FUserSecretsId: string;
    FOptional: Boolean;
    FReloadOnChange: Boolean;
  public
    constructor Create(const UserSecretsId: string; Optional: Boolean = True; ReloadOnChange: Boolean = False);
    function Build(Builder: IConfigurationBuilder): IConfigurationProvider;
  end;
```

---

## 5. Integração com `Dext.Web.WebApplication.pas`

Atualizar o construtor do `TWebApplication` para registrar os 5 provedores:

```pascal
  // 1. Arquivos Base
  ConfigBuilder.Add(TJsonConfigurationSource.Create('appsettings.json', True));
  ConfigBuilder.Add(TYamlConfigurationSource.Create('appsettings.yaml', True));
  ConfigBuilder.Add(TYamlConfigurationSource.Create('appsettings.yml', True));

  // 2. Arquivos de Ambiente ({Env})
  Env := GetEnvironmentVariable('DEXT_ENVIRONMENT');
  if Env = '' then Env := 'Production';
  
  ConfigBuilder.Add(TJsonConfigurationSource.Create('appsettings.' + Env + '.json', True));
  ConfigBuilder.Add(TYamlConfigurationSource.Create('appsettings.' + Env + '.yaml', True));
  ConfigBuilder.Add(TYamlConfigurationSource.Create('appsettings.' + Env + '.yml', True));

  // 3. User Secrets (Ativo somente em Development)
  if SameText(Env, 'Development') then
  begin
    SecretsId := GetEnvironmentVariable('DEXT_USERSECRETS_ID');
    if SecretsId <> '' then
      ConfigBuilder.Add(TUserSecretsConfigurationSource.Create(SecretsId, True));
  end;

  // 4. Variáveis de Ambiente do S.O.
  ConfigBuilder.Add(TEnvironmentVariablesConfigurationSource.Create);

  // 5. Linha de Comando (CLI Args - Prioridade Máxima)
  ConfigBuilder.Add(TCommandLineConfigurationSource.Create);
```

---

## 6. Critérios de Aceite (Acceptance Criteria)

- [x] **AC-1 (CLI Basic):** Executar com `--Server:Port=9000` sobrescreve qualquer valor de porta vindo de `appsettings.yaml` ou variáveis de ambiente.
- [x] **AC-2 (CLI Double Underscore):** Argumentos com `--Database__Password=SecretPass` são mapeados corretamente para a chave `Database:Password`.
- [x] **AC-3 (CLI Space Separator):** `--Database:Host 127.0.0.1` é interpretado identicamente a `--Database:Host=127.0.0.1`.
- [x] **AC-4 (User Secrets Storage):** Em ambiente `Development`, chaves presentes no `secrets.json` do usuário sobrescrevem `appsettings.Development.yaml`.
- [x] **AC-5 (User Secrets Isolation):** Em ambiente `Production`, `UserSecrets` **não** são carregados mesmo se o arquivo existir.
- [x] **AC-6 (Unit Tests):** Suíte de testes `Dext.Configuration.CommandLine.Tests.pas` e `Dext.Configuration.UserSecrets.Tests.pas` com 100% de cobertura e execução green.
