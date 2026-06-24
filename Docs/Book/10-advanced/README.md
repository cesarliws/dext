# 10. Advanced Topics

Deep dives into infrastructure and advanced patterns.

## Chapters

1. [Dependency Injection](dependency-injection.md) - Service registration & lifetimes
2. [Background Services](background-services.md) - Hosted services
3. [Configuration](configuration.md) - `IOptions<T>` pattern
4. [Async API](async-api.md) - `TAsyncTask` and concurrency
5. [Event Bus](event-bus.md) - In-process publish/subscribe with DI integration
6. [Event Bus Comparison](event-bus-comparison.md) - Dext vs Delphi Event Bus vs NX Horizon
7. [Diagnostics & Debugging](diagnostics-debugging.md) - Zero-allocation stack traces and async symbols
8. [Serialization & Globalization](serialization-globalization.md) - Handling locales and JSON formats
9. [Resilience Pipeline](resilience.md) - Polly-style fault handling (Retry, Circuit Breaker, Fallback, Timeout)
10. [Persistent Background Jobs](background-jobs.md) - Out-of-process scheduled/delayed tasks
11. [Dynamic Query Filters](dynamic-query-filters.md) - Bypassing Soft Delete & Multi-Tenancy filters on demand
12. [Delphi64RTL Optimization (Win64)](performance-delphi64rtl.md) - Using optimized assembly and SIMD

## Quick Examples

### Dependency Injection

```pascal
// Lifetime options
Services.AddSingleton<ILogger, TConsoleLogger>;    // One instance
Services.AddScoped<IUserService, TUserService>;     // Per request
Services.AddTransient<IValidator, TValidator>;       // New each time
```

### Background Services

```pascal
type
  TCleanupService = class(TInterfacedObject, IHostedService)
  public
    procedure StartAsync(CancellationToken: ICancellationToken);
    procedure StopAsync(CancellationToken: ICancellationToken);
  end;

Services.AddHostedService<TCleanupService>;
```

### Configuration

```pascal
type
  TDatabaseOptions = class
    ConnectionString: string;
    MaxPoolSize: Integer;
  end;

Services.Configure<TDatabaseOptions>(Config.GetSection('Database'));

// Usage
procedure DoWork(Options: IOptions<TDatabaseOptions>);
begin
  var ConnStr := Options.Value.ConnectionString;
end;
```

### Event Bus

```pascal
Services
  .AddEventBus
  .AddEventHandler<TOrderPlacedEvent, TOrderEmailHandler>
  .AddEventPublisher<TOrderPlacedEvent>
  .AddEventBehavior<TEventExceptionBehavior>;

// Publish — typed, ISP-compliant
FPublisher.Publish(Event);
```

### Async Tasks

```pascal
TAsyncTask.Run(procedure
  begin
    // Background work
    Sleep(5000);
    Log('Done!');
  end);
```

---

[← CLI](../09-cli/README.md) | [Appendix →](../appendix/type-system.md)
