# 10. Tópicos Avançados

Mergulhos profundos em infraestrutura e padrões avançados.

## Capítulos

1. [Injeção de Dependência](injecao-dependencia.md) - Registro de serviços & lifetimes
2. [Background Services](background-services.md) - Serviços hospedados
3. [Configuração](configuracao.md) - Padrão `IOptions<T>`
4. [API Assíncrona](async-api.md) - `TAsyncTask` e concorrência
5. [Diagnósticos e Debugging](diagnosticos-debugging.md) - Stack traces com alocação zero e símbolos assíncronos
6. [Serialização e Globalização](serializacao-globalizacao.md) - Lidar com locales e formatos JSON
7. [Pipeline de Resiliência](resiliencia.md) - Tratamento de falhas estilo Polly (Retry, Circuit Breaker, Fallback, Timeout)
8. [Persistent Background Jobs](background-jobs.md) - Tarefas agendadas e atrasadas fora do processo principal
9. [Filtros Dinâmicos de Query](filtros-dinamicos-query.md) - Ignorar Soft Delete e Multi-Tenancy sob demanda
10. [Otimização com Delphi64RTL (Win64)](performance-delphi64rtl.md) - Usando assembly otimizado e SIMD

## Exemplos Rápidos

### Injeção de Dependência

```pascal
// Opções de lifetime
Services.AddSingleton<ILogger, TConsoleLogger>;    // Uma instância
Services.AddScoped<IUserService, TUserService>;     // Por requisição
Services.AddTransient<IValidator, TValidator>;       // Nova a cada vez
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

### Configuração

```pascal
type
  TDatabaseOptions = class
    ConnectionString: string;
    MaxPoolSize: Integer;
  end;

Services.Configure<TDatabaseOptions>(Config.GetSection('Database'));

// Uso
procedure DoWork(Options: IOptions<TDatabaseOptions>);
begin
  var ConnStr := Options.Value.ConnectionString;
end;
```

### Tasks Assíncronas

```pascal
TAsyncTask.Run(procedure
  begin
    // Trabalho em background
    Sleep(5000);
    Log('Concluído!');
  end);
```

---

[← CLI](../09-cli/README.md) | [Apêndice →](../apendice/sistema-tipos.md)
