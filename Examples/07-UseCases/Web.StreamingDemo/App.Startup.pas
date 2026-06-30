unit App.Startup;

interface

uses
  System.SysUtils,
  Dext, Dext.DI.Interfaces,
  Dext.Web,
  Upload.Service,
  Upload.Endpoints,
  Download.Service,
  Download.Endpoints;

type
  TStartup = class(TInterfacedObject, IStartup)
  public
    procedure ConfigureServices(const Services: TDextServices; const Configuration: IConfiguration);
    procedure Configure(const App: IWebApplication);
  end;

implementation

{ TStartup }

procedure TStartup.ConfigureServices(const Services: TDextServices; const Configuration: IConfiguration);
begin
  // Register Services
  Services.AddScoped<IUploadService, TUploadService>;
  Services.AddScoped<IDownloadService, TDownloadService>;
end;

procedure TStartup.Configure(const App: IWebApplication);
var
  WebApp: TAppBuilder;
begin
  WebApp := App.GetBuilder;

  // Middleware
  WebApp.UseExceptionHandler;
  WebApp.UseStaticFiles; // Serves from wwwroot if needed

  // Map Feature Endpoints
  TUploadEndpoints.Map(WebApp);
  TDownloadEndpoints.Map(WebApp);
  
  Writeln('[*] Streaming Demo running at http://localhost:8080');
  Writeln('[*] - GET  /upload/form      - Simple upload form');
  Writeln('[*] - GET  /download/list    - List available files');
end;

end.
