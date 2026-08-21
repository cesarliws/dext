# Configuração

Gerenciamento moderno de configuração usando `IConfiguration` e `IOptions<T>`.

> 📦 **Exemplo**: [Core.TestConfig](../../../Examples/Core.TestConfig/)

> [!TIP]
> A configuração do Dext segue os mesmos padrões do ASP.NET Core, facilitando a aplicação de boas práticas modernas em aplicações Delphi.

## Estrutura de Arquivos

Uma aplicação Dext típica usa arquivos de configuração por ambiente:

```
projeto/
├── appsettings.json              # Configurações base/compartilhadas
├── appsettings.Development.json  # Sobrescritas de desenvolvimento
├── appsettings.Production.json   # Sobrescritas de produção
└── appsettings.yaml              # Formato YAML alternativo
```

## Carregando Configuração

### A partir de JSON

```pascal
uses
  Dext.Configuration.Json,
  Dext.Configuration.EnvironmentVariables;

var
  Config: IConfigurationRoot;
  Env: string;
begin
  Env := GetEnvironmentVariable('DEXT_ENVIRONMENT'); // ex: 'Development'
  
  Config := TConfigurationBuilder.Create
    .Add(TJsonConfigurationSource.Create('appsettings.json'))
    .Add(TJsonConfigurationSource.Create('appsettings.' + Env + '.json', True)) // Opcional
    .Add(TEnvironmentVariablesConfigurationSource.Create)  // Sobrescreve com vars de ambiente
    .Build;
end;
```

### A partir de YAML

```pascal
uses
  Dext.Configuration.Yaml;

Config := TConfigurationBuilder.Create
  .Add(TYamlConfigurationSource.Create('appsettings.yaml'))
  .Build;
```

### Exemplo appsettings.json

```json
{
  "Database": {
    "Provider": "PostgreSQL",
    "ConnectionString": "Server=localhost;Database=myapp",
    "MaxPoolSize": 10
  },
  "Jwt": {
    "SecretKey": "ALTERE_EM_PRODUCAO",
    "ExpirationMinutes": 60
  },
  "Features": {
    "EnableCache": true,
    "CacheTTL": 300
  }
}
```

### Exemplo appsettings.yaml

```yaml
Database:
  Provider: PostgreSQL
  ConnectionString: Server=localhost;Database=myapp
  MaxPoolSize: 10

Jwt:
  SecretKey: ALTERE_EM_PRODUCAO
  ExpirationMinutes: 60

Features:
  EnableCache: true
  CacheTTL: 300
```

## Lendo Valores

```pascal
// Valores simples
var DbProvider := Config['Database:Provider'];
var MaxPool := Config.GetValue<Integer>('Database:MaxPoolSize');

// Com valores padrão
var CacheTTL := Config.GetValue<Integer>('Features:CacheTTL', 60);
```

## Padrão Options (`IOptions<T>`)

Mapeie seções de configuração para classes fortemente tipadas para segurança de tipos e suporte ao IntelliSense.

### 1. Definir Classe de Opções

```pascal
type
  TDatabaseOptions = class
  public
    Provider: string;
    ConnectionString: string;
    MaxPoolSize: Integer;
  end;
  
  TJwtOptions = class
  public
    SecretKey: string;
    ExpirationMinutes: Integer;
  end;
```

### 2. Registrar Opções

```pascal
Services.Configure<TDatabaseOptions>(Config.GetSection('Database'));
Services.Configure<TJwtOptions>(Config.GetSection('Jwt'));
```

### 3. Injetar e Usar

```pascal
type
  TUserService = class
  private
    FDbOptions: IOptions<TDatabaseOptions>;
  public
    constructor Create(DbOptions: IOptions<TDatabaseOptions>);
    procedure Connect;
  end;

procedure TUserService.Connect;
begin
  var ConnStr := FDbOptions.Value.ConnectionString;
  var MaxPool := FDbOptions.Value.MaxPoolSize;
  // Usar valores...
end;
```

## Variáveis de Ambiente

Sobrescreva qualquer valor de configuração com variáveis de ambiente. Use duplo underscore `__` para chaves aninhadas:

```bash
# Windows
set Database__ConnectionString=postgresql://user:pass@prod-server/mydb
set Jwt__SecretKey=chave-secreta-producao

# Linux/macOS
export Database__ConnectionString=postgresql://user:pass@prod-server/mydb
export Jwt__SecretKey=chave-secreta-producao
```

> [!IMPORTANT]
> Variáveis de ambiente têm precedência sobre configuração em arquivo quando adicionadas por último na cadeia do builder.

## Configuração por Ambiente

### Padrão 1: Variável DEXT_ENVIRONMENT

```pascal
var Env := GetEnvironmentVariable('DEXT_ENVIRONMENT');
if Env = '' then Env := 'Development';

Config := TConfigurationBuilder.Create
  .Add(TJsonConfigurationSource.Create('appsettings.json'))
  .Add(TJsonConfigurationSource.Create('appsettings.' + Env + '.json', True))
  .Add(TEnvironmentVariablesConfigurationSource.Create)
  .Build;
```

### Padrão 2: Usar appsettings.Development.json para Desenvolvimento Local

**appsettings.json** (base - commitado no controle de versão):
```json
{
  "Database": {
    "Provider": "PostgreSQL",
    "ConnectionString": ""
  }
}
```

**appsettings.Development.json** (sobrescritas locais - pode ser ignorado no git):
```json
{
  "Database": {
    "ConnectionString": "Server=localhost;Database=dev_db;User=dev"
  }
}
```

## Hierarquia de Precedência (Pipeline de 5 Camadas)

O Dext adota o padrão enterprise moderno de configuração (Twelve-Factor App) com 5 camadas de precedência LIFO:

```
[1] Arquivos Base (appsettings.json / appsettings.yaml)   --> Fallback
[2] Arquivo de Ambiente (appsettings.{Env}.json / .yaml)   --> Sobrescreve Base
[3] User Secrets (Somente em ambiente Development)        --> Sobrescreve Arquivo de Ambiente
[4] Variáveis de Ambiente do S.O.                         --> Sobrescreve Arquivos e Secrets
[5] Argumentos de Linha de Comando (CLI)                  --> Prioridade Máxima
```

## Argumentos de Linha de Comando (CLI)

Sobrescreva qualquer parâmetro de configuração diretamente via argumentos de linha de comando no startup da aplicação.

```pascal
uses
  Dext.Configuration.CommandLine;

Config := TConfigurationBuilder.Create
  .Add(TCommandLineConfigurationSource.Create) // Utiliza ParamStr(1..ParamCount)
  .Build;
```

Formatos suportados:
- `--Server:Port=9090` ou `/Server:Port=9090`
- `--Database__Password=Secret` (converte automaticamente `__` para `:`)
- `--Server:Port 9090` (chave e valor separados por espaço)
- Aliases curtos via mapeamento `IDictionary<string, string>` (ex: `-p 8080`).

## User Secrets

Mantenha credenciais e chaves de desenvolvimento isoladas fora da árvore do repositório Git.

```pascal
uses
  Dext.Configuration.UserSecrets;

Config := TConfigurationBuilder.Create
  .Add(TUserSecretsConfigurationSource.Create('meu-app-secrets-guid', True))
  .Build;
```

Localização nos sistemas:
- **Windows**: `%APPDATA%\Dext\UserSecrets\<UserSecretsId>\secrets.json`
- **Linux/macOS**: `~/.dext/usersecrets/<UserSecretsId>/secrets.json`

## Boas Práticas

> [!CAUTION]
> **Nunca commite segredos no controle de versão!** Use User Secrets em desenvolvimento e variáveis de ambiente ou gerenciadores de segredos em produção.

1. **Use `IOptions<T>`** - Fornece segurança de tipos em tempo de compilação e IntelliSense
2. **Configure em camadas** - Arquivo base → Arquivo de ambiente → User Secrets → Variáveis de ambiente → Argumentos CLI
3. **Mantenha segredos fora do código** - Use User Secrets localmente e variáveis de ambiente em produção
4. **Use flag Optional** - Marque arquivos específicos de ambiente como `Optional := True`
5. **Valide a configuração** - Verifique valores obrigatórios na inicialização

---

[← Background Services](background-services.md) | [Próximo: API Assíncrona →](async-api.md)
