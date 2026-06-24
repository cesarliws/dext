unit BM.Http;

interface

uses
  Spring.Benchmark;

procedure BM_Http_Indy_Ping(const state: TState);
procedure BM_Http_HttpSys_Ping(const state: TState);
procedure BM_Http_InMemory_Ping(const state: TState);
procedure RunStandaloneServer(const AEngine: string);
procedure InitializeHttpBenchmarks;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.Rtti,
  System.Net.HttpClient,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.DI.Interfaces,
  Dext.Server.Engine.Interfaces,
  Dext.Server.Engine.Types,
  Dext.WebHost,
  Dext.Web.Interfaces,
  Dext.Web;

type
  { Mocking structures for in-memory HTTP pipeline execution }

  TMockHttpRequest = class(TInterfacedObject, IHttpRequest)
  private
    FHeaders: IStringDictionary;
    FQuery: IStringDictionary;
    FRouteParams: TRouteValueDictionary;
  public
    constructor Create;
    destructor Destroy; override;
    function GetMethod: string;
    function GetPath: string;
    function GetQuery: IStringDictionary;
    function GetBody: TStream;
    function GetRouteParams: TRouteValueDictionary;
    function GetHeaders: IStringDictionary;
    function GetRemoteIpAddress: string;
    function GetHeader(const AName: string): string;
    function GetQueryParam(const AName: string): string;
    function GetCookies: IStringDictionary;
    function GetFiles: IFormFileCollection;
  end;

  TMockHttpResponse = class(TInterfacedObject, IHttpResponse)
  private
    FStatusCode: Integer;
    FContentType: string;
    FHeaders: IStringDictionary;
  public
    constructor Create;
    destructor Destroy; override;
    function GetStatusCode: Integer;
    function GetContentType: string;
    function Status(AValue: Integer): IHttpResponse;
    procedure SetStatusCode(AValue: Integer);
    procedure SetContentType(const AValue: string);
    procedure SetContentLength(const AValue: Int64);
    procedure Flush;
    procedure Write(const AContent: string); overload;
    procedure Write(const ABuffer: TBytes); overload;
    procedure Write(const AStream: TStream); overload;
    procedure Json(const AJson: string); overload;
    procedure Json(const AValue: TValue); overload;
    procedure AddHeader(const AName, AValue: string);
    procedure AppendCookie(const AName, AValue: string; const AOptions: TCookieOptions); overload;
    procedure AppendCookie(const AName, AValue: string); overload;
    procedure DeleteCookie(const AName: string);
    procedure Redirect(const AUrl: string; APermanent: Boolean = False);
    procedure Unauthorized(const AMessage: string = '');
    procedure Forbidden(const AMessage: string = '');
    procedure BadRequest(const AMessage: string = '');
    procedure NotFound(const AMessage: string = '');
    function GetHtmx: IHtmxResponse;
    function GetHeaders: IStringDictionary;
  end;

  TMockHttpContext = class(TInterfacedObject, IHttpContext)
  private
    FRequest: IHttpRequest;
    FResponse: IHttpResponse;
    FServices: IServiceProvider;
    FItems: IDictionary<string, TValue>;
  public
    constructor Create(AReq: IHttpRequest; ARes: IHttpResponse; AServices: IServiceProvider);
    destructor Destroy; override;
    function GetConnection: IDextServerConnection;
    function GetRequest: IHttpRequest;
    function GetResponse: IHttpResponse;
    procedure SetResponse(const AValue: IHttpResponse);
    function GetServices: IServiceProvider;
    procedure SetServices(const AValue: IServiceProvider);
    function GetUser: IClaimsPrincipal;
    procedure SetUser(const AValue: IClaimsPrincipal);
    function GetItems: IDictionary<string, TValue>;
    function GetSession: IStreamableSession;
  end;

var
  GIndyHost: IWebApplication;
  GIndyPort: Integer;
  GNativeHost: IWebApplication;
  GNativePort: Integer;
  
  // Pipeline cache for in-memory routing benchmark
  GApp: IWebApplication;
  GPipeline: TRequestDelegate;

{ TMockHttpRequest }

constructor TMockHttpRequest.Create;
begin
  inherited Create;
  FHeaders := TDextStringDictionary.Create;
  FQuery := TDextStringDictionary.Create;
  FRouteParams.Clear;
end;

destructor TMockHttpRequest.Destroy;
begin
  FHeaders := nil;
  FQuery := nil;
  inherited;
end;

function TMockHttpRequest.GetBody: TStream; begin Result := nil; end;
function TMockHttpRequest.GetCookies: IStringDictionary; begin Result := nil; end;
function TMockHttpRequest.GetFiles: IFormFileCollection; begin Result := nil; end;
function TMockHttpRequest.GetHeader(const AName: string): string; begin Result := ''; end;
function TMockHttpRequest.GetHeaders: IStringDictionary; begin Result := FHeaders; end;
function TMockHttpRequest.GetMethod: string; begin Result := 'GET'; end;
function TMockHttpRequest.GetPath: string; begin Result := '/ping'; end;
function TMockHttpRequest.GetQuery: IStringDictionary; begin Result := FQuery; end;
function TMockHttpRequest.GetQueryParam(const AName: string): string; begin Result := ''; end;
function TMockHttpRequest.GetRemoteIpAddress: string; begin Result := '127.0.0.1'; end;
function TMockHttpRequest.GetRouteParams: TRouteValueDictionary; begin Result := FRouteParams; end;

{ TMockHttpResponse }

constructor TMockHttpResponse.Create;
begin
  inherited Create;
  FHeaders := TDextStringDictionary.Create;
  FStatusCode := 200;
  FContentType := 'text/plain';
end;

destructor TMockHttpResponse.Destroy;
begin
  FHeaders := nil;
  inherited;
end;

procedure TMockHttpResponse.AddHeader(const AName, AValue: string); begin FHeaders.Add(AName, AValue); end;
procedure TMockHttpResponse.AppendCookie(const AName, AValue: string; const AOptions: TCookieOptions); begin end;
procedure TMockHttpResponse.AppendCookie(const AName, AValue: string); begin end;
procedure TMockHttpResponse.BadRequest(const AMessage: string); begin FStatusCode := 400; end;
procedure TMockHttpResponse.DeleteCookie(const AName: string); begin end;
procedure TMockHttpResponse.Flush; begin end;
procedure TMockHttpResponse.Forbidden(const AMessage: string); begin FStatusCode := 403; end;
function TMockHttpResponse.GetContentType: string; begin Result := FContentType; end;
function TMockHttpResponse.GetHeaders: IStringDictionary; begin Result := FHeaders; end;
function TMockHttpResponse.GetHtmx: IHtmxResponse; begin Result := nil; end;
function TMockHttpResponse.GetStatusCode: Integer; begin Result := FStatusCode; end;
procedure TMockHttpResponse.Json(const AJson: string); begin FContentType := 'application/json'; end;
procedure TMockHttpResponse.Json(const AValue: TValue); begin FContentType := 'application/json'; end;
procedure TMockHttpResponse.NotFound(const AMessage: string); begin FStatusCode := 404; end;
procedure TMockHttpResponse.Redirect(const AUrl: string; APermanent: Boolean); begin FStatusCode := 302; end;
procedure TMockHttpResponse.SetContentLength(const AValue: Int64); begin end;
procedure TMockHttpResponse.SetContentType(const AValue: string); begin FContentType := AValue; end;
procedure TMockHttpResponse.SetStatusCode(AValue: Integer); begin FStatusCode := AValue; end;
function TMockHttpResponse.Status(AValue: Integer): IHttpResponse; begin FStatusCode := AValue; Result := Self; end;
procedure TMockHttpResponse.Unauthorized(const AMessage: string); begin FStatusCode := 401; end;
procedure TMockHttpResponse.Write(const AContent: string); begin end;
procedure TMockHttpResponse.Write(const ABuffer: TBytes); begin end;
procedure TMockHttpResponse.Write(const AStream: TStream); begin end;

{ TMockHttpContext }

constructor TMockHttpContext.Create(AReq: IHttpRequest; ARes: IHttpResponse; AServices: IServiceProvider);
begin
  inherited Create;
  FRequest := AReq;
  FResponse := ARes;
  FServices := AServices;
end;

destructor TMockHttpContext.Destroy;
begin
  FItems := nil;
  FRequest := nil;
  FResponse := nil;
  FServices := nil;
  inherited;
end;

function TMockHttpContext.GetConnection: IDextServerConnection; begin Result := nil; end;
function TMockHttpContext.GetRequest: IHttpRequest; begin Result := FRequest; end;
function TMockHttpContext.GetResponse: IHttpResponse; begin Result := FResponse; end;
procedure TMockHttpContext.SetResponse(const AValue: IHttpResponse); begin FResponse := AValue; end;
function TMockHttpContext.GetServices: IServiceProvider; begin Result := FServices; end;
procedure TMockHttpContext.SetServices(const AValue: IServiceProvider); begin FServices := AValue; end;
function TMockHttpContext.GetUser: IClaimsPrincipal; begin Result := nil; end;
procedure TMockHttpContext.SetUser(const AValue: IClaimsPrincipal); begin end;
function TMockHttpContext.GetSession: IStreamableSession; begin Result := nil; end;

function TMockHttpContext.GetItems: IDictionary<string, TValue>;
begin
  if FItems = nil then
    FItems := TCollections.CreateDictionary<string, TValue>;
  Result := FItems;
end;

{ Start/Stop servers }

procedure StartIndyServer;
var
  Builder: IWebHostBuilder;
begin
  if Assigned(GIndyHost) then Exit;
  
  Builder := TDextWebHost.CreateDefaultBuilder;
  Builder.Configure(
    procedure(App: IApplicationBuilder)
    begin
      App.MapGet('/ping',
        procedure(Context: IHttpContext)
        begin
          Context.Response.Write('pong');
        end);
    end);
    
  GIndyHost := Builder.Build as IWebApplication;
  GIndyHost.Start(0);
  GIndyPort := GIndyHost.Port;
end;

procedure StartNativeServer;
var
  Builder: IWebHostBuilder;
  PortTry: Integer;
begin
  if Assigned(GNativeHost) then Exit;
  
  Builder := TDextWebHost.CreateDefaultBuilder;
  Builder.Configure(
    procedure(App: IApplicationBuilder)
    begin
      App.MapGet('/ping',
        procedure(Context: IHttpContext)
        begin
          Context.Response.Write('pong');
        end);
    end);
    
  GNativeHost := Builder.Build as IWebApplication;
  GNativeHost.UseNativeServer(TServerEngineOptions.Default.WithBindAddress('localhost'));

  PortTry := 8090;
  while PortTry < 8100 do
  begin
    try
      GNativeHost.Start(PortTry);
      GNativePort := PortTry;
      Exit;
    except
      on E: EOSError do
      begin
        if E.ErrorCode = 5 then
          raise; // Propaga erro de permissão do http.sys imediatamente
        Inc(PortTry);
        if PortTry >= 8100 then
          raise;
      end;
      on E: Exception do
      begin
        Inc(PortTry);
        if PortTry >= 8100 then
          raise;
      end;
    end;
  end;
end;

procedure SetupInMemoryPipeline;
var
  Builder: IWebHostBuilder;
begin
  if Assigned(GPipeline) then Exit;

  Builder := TDextWebHost.CreateDefaultBuilder;
  Builder.Configure(
    procedure(App: IApplicationBuilder)
    begin
      App.MapGet('/ping',
        procedure(Context: IHttpContext)
        begin
          Context.Response.Write('pong');
        end);
    end);
  
  GApp := Builder.Build as IWebApplication;
  // Pre-build and cache the routing pipeline
  GPipeline := GApp.GetApplicationBuilder.Build;
end;

procedure CleanupServers;
begin
  if Assigned(GIndyHost) then
  begin
    GIndyHost.Stop;
    GIndyHost := nil;
  end;
  
  if Assigned(GNativeHost) then
  begin
    GNativeHost.Stop;
    GNativeHost := nil;
  end;

  GPipeline := nil;
  GApp := nil;
end;

{ Benchmarks }

procedure BM_Http_Indy_Ping(const state: TState);
var
  Client: THTTPClient;
  Url: string;
begin
  Url := 'http://127.0.0.1:' + IntToStr(GIndyPort) + '/ping';
  
  Client := THTTPClient.Create;
  try
    while state.KeepRunning do
    begin
      Client.Get(Url);
    end;
  finally
    Client.Free;
  end;
end;

procedure BM_Http_HttpSys_Ping(const state: TState);
var
  Client: THTTPClient;
  Url: string;
begin
  Url := 'http://127.0.0.1:' + IntToStr(GNativePort) + '/ping';
  
  Client := THTTPClient.Create;
  try
    while state.KeepRunning do
    begin
      Client.Get(Url);
    end;
  finally
    Client.Free;
  end;
end;

procedure BM_Http_InMemory_Ping(const state: TState);
var
  Req: IHttpRequest;
  Res: IHttpResponse;
  Ctx: IHttpContext;
begin
  // Reuse request structures across iterations to measure pure routing/delegation overhead
  Req := TMockHttpRequest.Create;
  Res := TMockHttpResponse.Create;
  Ctx := TMockHttpContext.Create(Req, Res, GApp.ServiceProvider);

  while state.KeepRunning do
  begin
    GPipeline(Ctx);
  end;
  
  Req := nil;
  Res := nil;
  Ctx := nil;
end;

procedure RunStandaloneServer(const AEngine: string);
var
  Host: IWebApplication;
  Builder: IWebHostBuilder;
begin
  Builder := TDextWebHost.CreateDefaultBuilder;
  Builder.Configure(
    procedure(App: IApplicationBuilder)
    begin
      App.MapGet('/ping',
        procedure(Context: IHttpContext)
        begin
          Context.Response.Write('pong');
        end);
    end);

  Host := Builder.Build as IWebApplication;

  if SameText(AEngine, '-httpsys') or SameText(AEngine, 'httpsys') then
  begin
    Host.UseNativeServer;
    Writeln('Starting http.sys server on http://127.0.0.1:8085/ping');
    Host.Start(8085);
  end
  else if SameText(AEngine, '-indy') or SameText(AEngine, 'indy') then
  begin
    Writeln('Starting Indy server on http://127.0.0.1:8085/ping');
    Host.Start(8085);
  end
  else
  begin
    Writeln('Unknown engine: ', AEngine);
    Exit;
  end;

  Writeln('Server is running. Press [ENTER] to stop.');
  Readln;
  Host.Stop;
end;

procedure InitializeHttpBenchmarks;
begin
  var IsServerMode := False;
  for var I := 1 to ParamCount do
    if SameText(ParamStr(I), '--server') then
      IsServerMode := True;

  if not IsServerMode then
  begin
    // Start all servers and setup pipelines before any benchmark runs
    StartIndyServer;
    StartNativeServer;
    SetupInMemoryPipeline;
  end;
end;

initialization
  // Run network benchmarks scaling from 1 to 4 threads
  Benchmark(BM_Http_Indy_Ping, 'BM_Http_Indy_Ping_T1').Threads(1);
  Benchmark(BM_Http_Indy_Ping, 'BM_Http_Indy_Ping_T4').Threads(4);
  
  Benchmark(BM_Http_HttpSys_Ping, 'BM_Http_HttpSys_Ping_T1').Threads(1);
  Benchmark(BM_Http_HttpSys_Ping, 'BM_Http_HttpSys_Ping_T4').Threads(4);
  
  // Run in-memory routing overhead benchmark scaling from 1 to 4 threads
  Benchmark(BM_Http_InMemory_Ping, 'BM_Http_InMemory_Ping_T1').Threads(1);
  Benchmark(BM_Http_InMemory_Ping, 'BM_Http_InMemory_Ping_T4').Threads(4);

finalization
  CleanupServers;

end.
