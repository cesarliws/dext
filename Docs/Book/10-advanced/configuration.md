# Configuration

Modern configuration management using `IConfiguration` and `IOptions<T>`.

> 📦 **Example**: [Core.TestConfig](../../../Examples/Core.TestConfig/)

> [!TIP]
> Dext configuration follows the same patterns as ASP.NET Core, making it easy to apply modern best practices in Delphi applications.

## File Structure

A typical Dext application uses environment-specific configuration files:

```
project/
├── appsettings.json              # Base/shared settings
├── appsettings.Development.json  # Development overrides
├── appsettings.Production.json   # Production overrides
└── appsettings.yaml              # Alternative YAML format
```

## Loading Configuration

### From JSON

```pascal
uses
  Dext.Configuration.Json,
  Dext.Configuration.EnvironmentVariables;

var
  Config: IConfigurationRoot;
  Env: string;
begin
  Env := GetEnvironmentVariable('DEXT_ENVIRONMENT'); // e.g., 'Development'
  
  Config := TConfigurationBuilder.Create
    .Add(TJsonConfigurationSource.Create('appsettings.json'))
    .Add(TJsonConfigurationSource.Create('appsettings.' + Env + '.json', True)) // Optional
    .Add(TEnvironmentVariablesConfigurationSource.Create)  // Override with env vars
    .Build;
end;
```

### From YAML

```pascal
uses
  Dext.Configuration.Yaml;

Config := TConfigurationBuilder.Create
  .Add(TYamlConfigurationSource.Create('appsettings.yaml'))
  .Build;
```

### appsettings.json Example

```json
{
  "Database": {
    "Provider": "PostgreSQL",
    "ConnectionString": "Server=localhost;Database=myapp",
    "MaxPoolSize": 10
  },
  "Jwt": {
    "SecretKey": "CHANGE_ME_IN_PRODUCTION",
    "ExpirationMinutes": 60
  },
  "Features": {
    "EnableCache": true,
    "CacheTTL": 300
  }
}
```

### appsettings.yaml Example

```yaml
Database:
  Provider: PostgreSQL
  ConnectionString: Server=localhost;Database=myapp
  MaxPoolSize: 10

Jwt:
  SecretKey: CHANGE_ME_IN_PRODUCTION
  ExpirationMinutes: 60

Features:
  EnableCache: true
  CacheTTL: 300
```

## Reading Values

```pascal
// Simple values
var DbProvider := Config['Database:Provider'];
var MaxPool := Config.GetValue<Integer>('Database:MaxPoolSize');

// With defaults
var CacheTTL := Config.GetValue<Integer>('Features:CacheTTL', 60);
```

## Options Pattern (`IOptions<T>`)

Bind configuration sections to strongly-typed classes for type safety and IntelliSense support.

### 1. Define Options Class

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

### 2. Register Options

```pascal
Services.Configure<TDatabaseOptions>(Config.GetSection('Database'));
Services.Configure<TJwtOptions>(Config.GetSection('Jwt'));
```

### 3. Inject and Use

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
  // Use values...
end;
```

## Environment Variables

Override any configuration value with environment variables. Use double underscore `__` for nested keys:

```bash
# Windows
set Database__ConnectionString=postgresql://user:pass@prod-server/mydb
set Jwt__SecretKey=super-secret-production-key

# Linux/macOS
export Database__ConnectionString=postgresql://user:pass@prod-server/mydb
export Jwt__SecretKey=super-secret-production-key
```

> [!IMPORTANT]
> Environment variables take precedence over file-based configuration when added last in the builder chain.

## Environment-Specific Configuration

### Pattern 1: DEXT_ENVIRONMENT Variable

```pascal
var Env := GetEnvironmentVariable('DEXT_ENVIRONMENT');
if Env = '' then Env := 'Development';

Config := TConfigurationBuilder.Create
  .Add(TJsonConfigurationSource.Create('appsettings.json'))
  .Add(TJsonConfigurationSource.Create('appsettings.' + Env + '.json', True))
  .Add(TEnvironmentVariablesConfigurationSource.Create)
  .Build;
```

### Pattern 2: Use appsettings.Development.json for Local Development

**appsettings.json** (base - committed to source control):
```json
{
  "Database": {
    "Provider": "PostgreSQL",
    "ConnectionString": ""
  }
}
```

**appsettings.Development.json** (local overrides - may be gitignored):
```json
{
  "Database": {
    "ConnectionString": "Server=localhost;Database=dev_db;User=dev"
  }
}
```

## Precedence Hierarchy (5-Layer Pipeline)

Dext follows the standard modern Twelve-Factor App configuration pipeline with 5 layers of precedence (LIFO):

```
[1] Base Files (appsettings.json / appsettings.yaml)   --> Fallback
[2] Environment File (appsettings.{Env}.json / .yaml)   --> Overrides Base
[3] User Secrets (Development environment only)         --> Overrides Env Files
[4] OS Environment Variables                            --> Overrides Files & Secrets
[5] Command Line Arguments (CLI)                        --> Highest Precedence
```

## Command Line Arguments

Override any configuration parameter via startup command-line arguments.

```pascal
uses
  Dext.Configuration.CommandLine;

Config := TConfigurationBuilder.Create
  .Add(TCommandLineConfigurationSource.Create) // Uses ParamStr(1..ParamCount)
  .Build;
```

Supported formats:
- `--Server:Port=9090` or `/Server:Port=9090`
- `--Database__Password=Secret` (automatically maps `__` to `:`)
- `--Server:Port 9090` (space-separated key and value)
- Short switch aliases via `IDictionary<string, string>` mappings (e.g., `-p 8080`).

## User Secrets

Keep sensitive development keys outside your Git repository.

```pascal
uses
  Dext.Configuration.UserSecrets;

Config := TConfigurationBuilder.Create
  .Add(TUserSecretsConfigurationSource.Create('my-app-secrets-guid', True))
  .Build;
```

Location:
- **Windows**: `%APPDATA%\Dext\UserSecrets\<UserSecretsId>\secrets.json`
- **Linux/macOS**: `~/.dext/usersecrets/<UserSecretsId>/secrets.json`

## Best Practices

> [!CAUTION]
> **Never commit secrets to source control!** Use User Secrets in development, and environment variables or secret managers in production.

1. **Use `IOptions<T>`** - Provides compile-time type safety and IntelliSense
2. **Layer your configuration** - Base file → Environment file → User Secrets → Environment variables → CLI args
3. **Keep secrets out of code** - Use User Secrets for local dev and environment variables for production
4. **Use Optional flag** - Mark environment-specific files as `Optional := True`
5. **Validate configuration** - Check required values at startup

---

[← Background Services](background-services.md) | [Next: Async API →](async-api.md)
