program Dext.DITest;

uses
  Dext.MM,
  System.SysUtils,
  Dext.DI.Interfaces,
  Dext.DI.Core,
  Dext.DI.Extensions;

{$APPTYPE CONSOLE}

{$R *.res}

type
  ILogger = interface
    ['{A1B2C3D4-E5F6-4A7B-8C9D-0E1F2A3B4C5D}']
    procedure Log(const AMessage: string);
  end;

  TConsoleLogger = class(TInterfacedObject, ILogger)
  public
    procedure Log(const AMessage: string);
  end;

  IDataService = interface
    ['{B2C3D4E5-F6A7-4B8C-9D0E-1F2A3B4C5D6E}']
    function GetData: string;
  end;

  TDataService = class(TInterfacedObject, IDataService)
  private
    FLogger: ILogger;
  public
    constructor Create(ALogger: ILogger);
    function GetData: string;
  end;

{ TConsoleLogger }

procedure TConsoleLogger.Log(const AMessage: string);
begin
  Writeln('LOG: ', AMessage);
end;

{ TDataService }

constructor TDataService.Create(ALogger: ILogger);
begin
  inherited Create;
  FLogger := ALogger;
end;

function TDataService.GetData: string;
begin
  FLogger.Log('Getting data...'); /// ERRO AQUI FLogger = nil
  Result := 'Hello from DataService!';
end;

var
  Services: IServiceCollection;
  Provider: IServiceProvider;
  Logger: ILogger;
  DataService: IDataService;
begin
  try
    // Configurar serviços
    Services := TDextServiceCollection.Create;

    // Registrar serviços usando helpers genéricos - agora com interfaces!
    TServiceCollectionExtensions.AddSingleton<ILogger, TConsoleLogger>(Services);
    // TServiceCollectionExtensions.AddTransient<IDataService, TDataService>(Services);
    // Registrar IDataService com factory para injetar ILogger
    TServiceCollectionExtensions.AddTransient<IDataService, TDataService>(
      Services,
      function(Provider: IServiceProvider): TObject
      begin
        var LoggerInstance := TServiceProviderExtensions.GetService<ILogger>(Provider);
        Result := TDataService.Create(LoggerInstance);
      end
    );

    // Construir provider
    Provider := Services.BuildServiceProvider;

    // Resolver serviços
    Logger := TServiceProviderExtensions.GetService<ILogger>(Provider);
    DataService := TServiceProviderExtensions.GetService<IDataService>(Provider);

    // Usar serviços
    if Assigned(Logger) then
      Logger.Log('Application started');

    if Assigned(DataService) then
      Writeln('Data: ', DataService.GetData);

    // Testar singleton - mesma instância
    var Logger2: ILogger := TServiceProviderExtensions.GetService<ILogger>(Provider);
    if Logger = Logger2 then
      Writeln('? Singleton working - same instance')
    else
      Writeln('? Singleton broken - different instances');

  except
    on E: Exception do
      Writeln('Error: ', E.Message);
  end;

  Readln;
end.
