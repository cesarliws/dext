program Dext.Examples.ComplexQuerying;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  Dext.MM,
  Dext.Utils,
  System.SysUtils,
  System.Classes,
  Dext, Dext.DI.Interfaces,
  Dext.Web,
  Dext.Entity,
  Dext.Json,
  ComplexQuerying.Entities in 'Domain\ComplexQuerying.Entities.pas',
  ComplexQuerying.DbContext in 'Domain\ComplexQuerying.DbContext.pas',
  ComplexQuerying.Endpoints in 'Features\ComplexQuerying.Endpoints.pas',
  ComplexQuerying.Service in 'Features\ComplexQuerying.Service.pas';

type
  TComplexQueryingStartup = class(TInterfacedObject, IStartup)
  public
    procedure ConfigureServices(const Services: TDextServices; const Configuration: IConfiguration);
    procedure Configure(const App: IWebApplication);
  end;

{ TComplexQueryingStartup }

procedure TComplexQueryingStartup.ConfigureServices(const Services: TDextServices; const Configuration: IConfiguration);
begin
  // Configure Database Context
  Services.AddDbContext<TQueryDbContext>(
    procedure(Options: TDbContextOptions)
    begin
      Options.UseSQLite('complex_queries.db');
      Options.WithPooling(True, 10);
      Options.UseSnakeCaseNamingConvention;
    end);

  // Services
  Services.AddScoped<IOrderService, TOrderService>;
  Services.AddScoped<IReportService, TReportService>;
end;

procedure TComplexQueryingStartup.Configure(const App: IWebApplication);
var
  WebApp: TAppBuilder;
begin
  WebApp := App.GetBuilder;

  // Global JSON settings
  JsonDefaultSettings(JsonSettings.Default.CamelCase.CaseInsensitive);

  // Exception Handler
  WebApp.UseExceptionHandler;
  WebApp.UseMiddleware(TRequestLoggingMiddleware);

  // Map Endpoints
  TComplexQueryingEndpoints.Map(WebApp);

  WriteLn('[*] Complex Querying Demo running at http://localhost:8080');
  WriteLn('[*] Endpoints:');
  WriteLn('    GET  /api/orders                - List orders with filters');
  WriteLn('    GET  /api/orders/{id}           - Get order with details');
  WriteLn('    GET  /api/orders/search         - Advanced search with JSON metadata');
  WriteLn('    GET  /api/reports/sales         - Sales report (aggregations)');
  WriteLn('    GET  /api/reports/top-customers - Top customers report');
  WriteLn('    POST /api/seed                  - Seed sample data');
end;

var
  App: IWebApplication;
begin
  try
    SetConsoleCharSet;
    
    App := TDextApplication.Create;
    App.UseStartup(TComplexQueryingStartup.Create);
    App.Run(8080);
    
    ConsolePause;
  except
    on E: Exception do
    begin
      WriteLn(E.ClassName, ': ', E.Message);
      ConsolePause;
    end;
  end;
end.
