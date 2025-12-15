# Background Services (Hosted Services)

O Dext suporta a execução de tarefas em segundo plano (Background Services) que iniciam e param junto com a aplicação. Isso é ideal para processamento de filas, tarefas agendadas, ou monitoramento contínuo.

## Conceito

Um `Hosted Service` é uma classe que implementa `IHostedService` e é gerenciada pelo container de DI. O Dext fornece uma classe base `TBackgroundService` que facilita a criação de workers que rodam em uma thread separada.

## Criando um Worker

Implemente uma classe herdando de `TBackgroundService` e sobrescreva o método `Execute`. O método recebe um `ICancellationToken` para gerenciar o cancelamento gracioso.

```pascal
uses
  Dext.Hosting.BackgroundService,
  Dext.Core.CancellationToken;

type
  TWorkerService = class(TBackgroundService)
  protected
    procedure Execute(Token: ICancellationToken); override;
  end;

implementation

procedure TWorkerService.Execute(Token: ICancellationToken);
begin
  WriteLn('👷 Worker iniciado.');
  
  while not Token.IsCancellationRequested do
  begin
    try
      // Realizar trabalho...
      WriteLn('Processando...');
      
      // Aguardar com suporte a cancelamento
      if Token.WaitForCancellation(5000) = wrSignaled then
        Break; // Cancelamento solicitado
        
    except
      on E: Exception do
        WriteLn('Erro: ' + E.Message);
    end;
  end;
  
  WriteLn('👷 Worker finalizado.');
end;
```

## Registrando o Serviço

Use o método de extensão `AddBackgroundServices`:

```pascal
uses
  Dext.Core.Extensions,
  Dext.Hosting.BackgroundService;

// ...

TDextServiceCollectionExtensions.AddBackgroundServices(App.Services)
  .AddHostedService<TWorkerService>
  .AddHostedService<TEmailProcessorService>
  .Build;
```

## Ciclo de Vida

1.  Quando `App.Run` é chamado, o `THostedServiceManager` inicia todos os serviços registrados (`StartAsync`).
2.  Cada `TBackgroundService` cria uma thread dedicada e chama `Execute`.
3.  Quando a aplicação é encerrada (ex: Ctrl+C ou `App.Stop`), o `THostedServiceManager` solicita o cancelamento (`StopAsync`).
4.  O `Token.IsCancellationRequested` torna-se `True` e o `WaitForCancellation` retorna imediatamente.
5.  O serviço tem um tempo para finalizar suas operações graciosamente antes da thread ser encerrada.
