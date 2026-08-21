---
name: dext-background
description: Run background workers, load configuration from JSON/YAML/env, and use async tasks with TAsyncTask in Dext applications. Use when adding scheduled jobs, configuration management, or non-blocking async operations.
---

# Dext Background Services, Configuration & Async

## Background Services (`IHostedService`)

### Define a Background Service

```pascal
uses
  Dext.Hosting; // IHostedService, ICancellationToken

type
  TCleanupService = class(TInterfacedObject, IHostedService)
  private
    FLogger: ILogger;
    FCancelled: Boolean;
  public
    constructor Create(Logger: ILogger);  // DI-injected
    procedure StartAsync(CancellationToken: ICancellationToken);
    procedure StopAsync(CancellationToken: ICancellationToken);
  end;

procedure TCleanupService.StartAsync(CancellationToken: ICancellationToken);
begin
  TAsyncTask.Run(procedure
    begin
      while not CancellationToken.IsCancellationRequested do
      begin
        try
          DoCleanup;
        except
          on E: Exception do
            FLogger.Error('Cleanup error: ' + E.Message);
        end;
        Sleep(60 * 60 * 1000);  // 1 hour
      end;
    end);
end;

procedure TCleanupService.StopAsync(CancellationToken: ICancellationToken);
begin
  FCancelled := True;
end;
```

### Register

```pascal
Services.AddHostedService<TCleanupService>;
```

### Use Scoped Services Inside a Background Worker

Create a scope to get per-request services (DbContext, etc.):

```pascal
procedure TCleanupService.DoWork;
begin
  var Scope := FServiceProvider.CreateScope;
  try
    var Db := Scope.ServiceProvider.GetService(TAppDbContext) as TAppDbContext;
    var u := TLog.Props;
    Db.Logs.Where(u.CreatedAt < (Now - 30)).Delete;
    Db.SaveChanges;
  finally
    Scope := nil;
  end;
end;
```

---

## Configuration (`IConfiguration`)

### File Structure

```
project/
├── appsettings.json               # Base settings (committed)
├── appsettings.Development.json   # Dev overrides (may be gitignored)
├── appsettings.Production.json    # Prod overrides
```

### Load Configuration

```pascal
uses
  Dext.Configuration.Json,
  Dext.Configuration.UserSecrets,
  Dext.Configuration.EnvironmentVariables,
  Dext.Configuration.CommandLine;

var Env := GetEnvironmentVariable('DEXT_ENVIRONMENT');
if Env = '' then Env := 'Development';

var Config := TConfigurationBuilder.Create
  .Add(TJsonConfigurationSource.Create('appsettings.json'))
  .Add(TJsonConfigurationSource.Create('appsettings.' + Env + '.json', True)) // optional
  .Add(TUserSecretsConfigurationSource.Create('app-secrets-id', True))       // dev secrets
  .Add(TEnvironmentVariablesConfigurationSource.Create)                       // env vars
  .Add(TCommandLineConfigurationSource.Create)                                // CLI args (highest)
  .Build;
```

YAML alternative:
```pascal
uses Dext.Configuration.Yaml;
Config := TConfigurationBuilder.Create
  .Add(TYamlConfigurationSource.Create('appsettings.yaml'))
  .Build;
```

### Read Values

```pascal
var Provider := Config['Database:Provider'];
var MaxPool  := Config.GetValue<Integer>('Database:MaxPoolSize');
var TTL      := Config.GetValue<Integer>('Features:CacheTTL', 60); // with default
```

### Options Pattern (Strongly Typed)

```pascal
// 1. Define options class
type
  TJwtOptions = class
  public
    SecretKey: string;
    ExpirationMinutes: Integer;
  end;

// 2. Register in ConfigureServices
Services.Configure<TJwtOptions>(Configuration.GetSection('Jwt'));

// 3. Inject and use
type
  TAuthService = class
  private
    FJwt: IOptions<TJwtOptions>;
  public
    constructor Create(Jwt: IOptions<TJwtOptions>);
    function GenerateToken: string;
  end;

function TAuthService.GenerateToken: string;
begin
  var Secret := FJwt.Value.SecretKey;
  var Expiry := FJwt.Value.ExpirationMinutes;
  // ...
end;
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
  }
}
```

### Environment Variable Overrides

Use double underscore `__` for nested keys:

```bash
# Windows
set Database__ConnectionString=postgresql://user:pass@prod/db
set Jwt__SecretKey=super-secret-key

# Linux/macOS
export Database__ConnectionString=postgresql://...
```

Environment variables take precedence over file config when added last in the builder chain.

---

## Persistent Background Jobs

Persistent Background Jobs allow you to enqueue out-of-process, scheduled, or delayed tasks that survive application crashes and restarts. The engine automatically serializes the job parameters and saves them to a persistent datastore (such as SQLite or In-Memory).

> [!IMPORTANT]
> The SQLite storage provider (`TSqliteJobStorage`) resides in the **`Dext.EF.Core`** package to keep **`Dext.Core`** clean of database dependencies (like FireDAC). If you configure your application to use the `"SQLite"` provider, ensure your application references the `Dext.EF.Core` package.

### Configuration in `appsettings.json`
```json
{
  "Dext": {
    "BackgroundJobs": {
      "Storage": {
        "Provider": "SQLite", // "SQLite" or "InMemory"
        "ConnectionString": "DataSource=dext_jobs.db"
      },
      "Server": {
        "WorkerCount": 4,
        "PollIntervalInSeconds": 5
      }
    }
  }
}
```

### Registration
```pascal
uses
  Dext.DI.Interfaces,
  Dext.BackgroundJobs.Config;

procedure ConfigureServices(const Services: IServiceCollection);
begin
  Services.AddTransient<TEmailService>;
  Services.AddBackgroundJobs; // Register background jobs storage & server client
end;
```

### Usage
```pascal
uses
  System.TimeSpan,
  Dext.BackgroundJobs.Intf;

// 1. Initialize once at startup (after resolving IJobClient)
TDextJobs.Initialize(ServiceProvider.GetRequiredService<IJobClient>);

// 2. Enqueue immediately (Fire-and-Forget)
var JobId1 := TDextJobs.Enqueue<TEmailService>('SendWelcomeEmail', ['user@example.com', 123]);

// 3. Schedule with delay
var JobId2 := TDextJobs.Schedule<TEmailService>('SendWelcomeEmail', ['user@example.com', 123], TTimeSpan.FromHours(1));
```

---

## Async API (`TAsyncTask`)

```pascal
uses
  Dext.Core.Async; // TAsyncTask, TCancellationTokenSource
```

### Fire and Forget

```pascal
TAsyncTask.Run(procedure
  begin
    DoHeavyWork;  // Runs in background thread
  end);
```

### With Result + Chaining

```pascal
TAsyncTask.Run<TUserProfile>(
  function: TUserProfile
  begin
    Result := ApiService.GetProfile(UserId);
  end)
  .ThenBy<Boolean>(
    function(Profile: TUserProfile): Boolean
    begin
      Result := Profile.IsActive;
    end)
  .OnComplete(
    procedure(IsActive: Boolean)
    begin
      // Executed on UI thread
      UpdateUI(IsActive);
    end)
  .Start;
```

### Exception Handling

```pascal
TAsyncTask.Run(procedure
  begin
    raise EInvalidOperation.Create('Background error');
  end)
  .OnException(procedure(Ex: Exception)
    begin
      ShowMessage('Error: ' + Ex.Message);  // UI thread
    end)
  .Start;
```

### Cancellation

```pascal
var CTS := TCancellationTokenSource.Create;

TAsyncTask.Run(procedure
  begin
    while not CTS.Token.IsCancellationRequested do
      ProcessNext;
  end)
  .Start;

// Cancel later
CTS.Cancel;
```

### Synchronous Wait (Console / Background Workers)

```pascal
var User := Client.Get<TUser>('/users/1').Await; // Blocks thread
```

