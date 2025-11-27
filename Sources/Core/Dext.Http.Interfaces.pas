unit Dext.Http.Interfaces;

interface

uses
  System.Classes,
  System.Rtti,
  System.SysUtils,
  System.Generics.Collections,
  Dext.DI.Interfaces,
  Dext.Auth.Identity,
  Dext.Configuration.Interfaces;

type
  IHttpContext = interface;
  IHttpRequest = interface;
  IHttpResponse = interface;
  IApplicationBuilder = interface;
  IWebHost = interface;
  IWebHostBuilder = interface;

  TRequestDelegate = reference to procedure(AContext: IHttpContext);
  TStaticHandler = reference to procedure(AContext: IHttpContext);
  TMiddlewareDelegate = reference to procedure(AContext: IHttpContext; ANext: TRequestDelegate);

  TEndpointMetadata = record
    Method: string;
    Path: string;
    Summary: string;
    Description: string;
    Tags: TArray<string>;
    Parameters: TArray<string>; // Added parameters
    Security: TArray<string>;   // Security schemes required
  end;

  IResult = interface
    ['{D6F5E4A3-9B2C-4D1E-8F7A-6C5B4E3D2F1A}']
    procedure Execute(AContext: IHttpContext);
  end;

  IHttpRequest = interface
    ['{C3E8F1A2-4B7D-4A9C-9E2B-8F6D5A1C3E7F}']
    function GetMethod: string;
    function GetPath: string;
    function GetQuery: TStrings;
    function GetBody: TStream;
    function GetRouteParams: TDictionary<string, string>;
    function GetHeaders: TDictionary<string, string>;
    function GetRemoteIpAddress: string; // ✅ Added
    property Method: string read GetMethod;
    property Path: string read GetPath;
    property Query: TStrings read GetQuery;
    property Body: TStream read GetBody;
    property RouteParams: TDictionary<string, string> read GetRouteParams;
    property Headers: TDictionary<string, string> read GetHeaders;
    property RemoteIpAddress: string read GetRemoteIpAddress; // ✅ Added
  end;

  IHttpResponse = interface
    ['{D4F9E2A1-5B8C-4D3A-8E7B-6F5A2D1C9E8F}']
    function GetStatusCode: Integer;
    function Status(AValue: Integer): IHttpResponse;
    procedure SetStatusCode(AValue: Integer);
    procedure SetContentType(const AValue: string);
    procedure SetContentLength(const AValue: Int64); // ✅ Added
    procedure Write(const AContent: string); overload;
    procedure Write(const ABuffer: TBytes); overload; // ✅ Added
    procedure Json(const AJson: string);
    procedure AddHeader(const AName, AValue: string);
    property StatusCode: Integer read GetStatusCode write SetStatusCode;
  end;

  IHttpContext = interface
    ['{E5F8D2C1-9A4E-4B7D-8C3B-6F5A1D2E8C9F}']
    function GetRequest: IHttpRequest;
    function GetResponse: IHttpResponse;
    procedure SetResponse(const AValue: IHttpResponse);
    function GetServices: IServiceProvider;
    procedure SetServices(const AValue: IServiceProvider);
    function GetUser: IClaimsPrincipal;
    procedure SetUser(const AValue: IClaimsPrincipal);
    property Request: IHttpRequest read GetRequest;
    property Response: IHttpResponse read GetResponse write SetResponse;
    property Services: IServiceProvider read GetServices write SetServices;
    property User: IClaimsPrincipal read GetUser write SetUser;
  end;

  IMiddleware = interface
    ['{F1E8D2C3-9A4E-4B7D-8C5B-6F5A1D2E8C9F}']
    procedure Invoke(AContext: IHttpContext; ANext: TRequestDelegate);
  end;

  IApplicationBuilder = interface
    ['{A2F8C5D1-8B4E-4A7D-9C3B-6E8F4A2D1C7A}']
    function GetServiceProvider: IServiceProvider;
    function UseMiddleware(AMiddleware: TClass): IApplicationBuilder; overload;
    function UseMiddleware(AMiddleware: TClass; const AParam: TValue): IApplicationBuilder; overload;
    function UseMiddleware(AMiddleware: TClass; const AParams: array of TValue): IApplicationBuilder; overload;
    function UseMiddleware(AMiddleware: IMiddleware): IApplicationBuilder; overload; // ✅ Singleton Middleware
    
    // ✅ Functional Middleware
    function Use(AMiddleware: TMiddlewareDelegate): IApplicationBuilder;

    function UseModelBinding: IApplicationBuilder;

    function Map(const APath: string; ADelegate: TRequestDelegate): IApplicationBuilder;
    function MapEndpoint(const AMethod, APath: string; ADelegate: TRequestDelegate): IApplicationBuilder;
    function MapPost(const Path: string; Handler: TStaticHandler): IApplicationBuilder;
    function MapGet(const Path: string; Handler: TStaticHandler): IApplicationBuilder;
    function MapPut(const Path: string; Handler: TStaticHandler): IApplicationBuilder;
    function MapDelete(const Path: string; Handler: TStaticHandler): IApplicationBuilder;
    function Build: TRequestDelegate;
    
    function GetRoutes: TArray<TEndpointMetadata>; // ✅ Introspection
    procedure UpdateLastRouteMetadata(const AMetadata: TEndpointMetadata); // ✅ For fluent API
  end;

  IWebHost = interface
    ['{B3E7D4F1-9C6E-4B8A-8D2C-7F5A1B3E8D9F}']
    procedure Run;
    procedure Stop;
  end;

  IWebHostBuilder = interface
    ['{C4F8E5D2-8D4E-4A7D-9C3B-6E8F4A2D1C7B}']
    function ConfigureServices(AConfigurator: TProc<IServiceCollection>): IWebHostBuilder;
    function Configure(AConfigurator: TProc<IApplicationBuilder>): IWebHostBuilder;
    function Build: IWebHost;
  end;

  IWebApplication = interface
    ['{B6C96B49-0292-42A6-A767-C7EAF52F71FC}']
    function GetServices: IServiceCollection;
    function UseMiddleware(Middleware: TClass): IWebApplication;
    function MapControllers: IWebApplication;
    function GetApplicationBuilder: IApplicationBuilder; // ✅ NOVO
    function GetConfiguration: IConfiguration; // ✅ Configuration
    procedure Run(Port: Integer = 8080);

    // Fluent interface para DI
    function Services: IServiceCollection;
    property Configuration: IConfiguration read GetConfiguration;
  end;

  TDextWebHost = class
    class function CreateDefaultBuilder: IWebHostBuilder;
  end;

implementation

uses
  Dext.WebHost;

{ TDextWebHost }

class function TDextWebHost.CreateDefaultBuilder: IWebHostBuilder;
begin
  Result := TWebHostBuilder.Create;
end;

end.
