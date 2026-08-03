unit Bench.Middleware;

interface

type
  TBenchMiddleware = class
  public
    class procedure Run;
  end;

implementation

uses
  System.SysUtils,
  System.Diagnostics,
  System.Classes,
  System.Rtti,
  Dext.DI.Interfaces,
  Dext.Auth.Identity,
  Dext.Web.Interfaces,
  BM.Http,
  Dext.Server.Engine.Interfaces,
  Dext.Web.Pipeline,
  Dext.Web.Routing,
  Dext.Collections,
  Dext.Collections.Dict,
  Bench.Utils;

{ TMockHttpContext and others }

type
  TMockHttpRequest = class(TInterfacedObject, IHttpRequest)
  private
    FMethod: string;
    FPath: string;
    FPathBase: string;
    FQuery: IStringDictionary;
    FHeaders: IStringDictionary;
  public
    constructor Create(const AMethod, APath: string);
    destructor Destroy; override;

    function GetMethod: string;
    function GetPath: string;
    procedure SetPath(const AValue: string);
    function GetPathBase: string;
    procedure SetPathBase(const AValue: string);
    function ToAppUrl(const ARelativePath: string): string;
    function GetQuery: IStringDictionary;
    function GetBody: TStream;
    function GetRouteParams: TRouteValueDictionary;
    function GetHeaders: IStringDictionary;
    function GetRemoteIpAddress: string;

    function GetHeader(const AName: string): string;
    function GetQueryParam(const AName: string): string;
    function GetProtocol: string;
    function GetCookies: IStringDictionary;
    function GetFiles: IFormFileCollection;
    property PathBase: string read GetPathBase write SetPathBase;
  end;

  TMockHttpContext = class(TInterfacedObject, IHttpContext)
  private
    FRequest: IHttpRequest;
    FResponse: IHttpResponse;
  public
    constructor Create(const AMethod, APath: string);
    function GetRequest: IHttpRequest;
    function GetResponse: IHttpResponse;
    function GetItems: IDictionary<string, TValue>;
    function GetUser: IClaimsPrincipal;
    procedure SetUser(const AValue: IClaimsPrincipal);
    procedure SetResponse(const AValue: IHttpResponse);
    procedure SetServices(const AValue: IServiceProvider);
    function GetServices: IServiceProvider;
    function GetConnection: IDextServerConnection;
    function GetSession: IStreamableSession;
    function GetEndpointMetadata: TEndpointMetadata;
    procedure SetEndpointMetadata(const AMetadata: TEndpointMetadata);
    procedure SetRouteParams(const AParams: TRouteValueDictionary);
  end;

type
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

{ TMockHttpRequest }

constructor TMockHttpRequest.Create(const AMethod, APath: string);
begin
  inherited Create;
  FMethod := AMethod;
  FPath := APath;
  FQuery := TDextStringDictionary.Create;
  FHeaders := TDextStringDictionary.Create;
end;

destructor TMockHttpRequest.Destroy;
begin
  FQuery := nil;
  inherited;
end;

function TMockHttpRequest.GetBody: TStream; begin Result := nil; end;
function TMockHttpRequest.GetHeader(const AName: string): string; begin Result := ''; end;
function TMockHttpRequest.GetHeaders: IStringDictionary; begin Result := FHeaders; end;
function TMockHttpRequest.GetMethod: string; begin Result := FMethod; end;
function TMockHttpRequest.GetPath: string; begin Result := FPath; end;
procedure TMockHttpRequest.SetPath(const AValue: string); begin FPath := AValue; end;
function TMockHttpRequest.GetPathBase: string; begin Result := FPathBase; end;
procedure TMockHttpRequest.SetPathBase(const AValue: string); begin FPathBase := AValue; end;
function TMockHttpRequest.ToAppUrl(const ARelativePath: string): string;
var
  LBase, LRel: string;
begin
  LBase := GetPathBase;
  LRel := ARelativePath;
  if LBase = '/' then LBase := '';
  if (LRel <> '') and not LRel.StartsWith('/') then LRel := '/' + LRel;
  Result := LBase + LRel;
  if Result = '' then Result := '/';
end;
function TMockHttpRequest.GetProtocol: string; begin Result := 'HTTP/1.1'; end;
function TMockHttpRequest.GetQuery: IStringDictionary; begin Result := FQuery; end;
function TMockHttpRequest.GetQueryParam(const AName: string): string; begin Result := ''; end;
function TMockHttpRequest.GetRemoteIpAddress: string; begin Result := '127.0.0.1'; end;
function TMockHttpRequest.GetRouteParams: TRouteValueDictionary; begin Result.Clear; end;
function TMockHttpRequest.GetCookies: IStringDictionary; begin Result := nil; end;
function TMockHttpRequest.GetFiles: IFormFileCollection; begin Result := nil; end;

{ TMockHttpContext }

constructor TMockHttpContext.Create(const AMethod, APath: string);
begin
  FRequest := TMockHttpRequest.Create(AMethod, APath);
  FResponse := TMockHttpResponse.Create;
end;

function TMockHttpContext.GetItems: IDictionary<string, TValue>; begin Result := nil; end;
function TMockHttpContext.GetRequest: IHttpRequest; begin Result := FRequest; end;
function TMockHttpContext.GetResponse: IHttpResponse; begin Result := FResponse; end;
procedure TMockHttpContext.SetResponse(const AValue: IHttpResponse); begin end;
function TMockHttpContext.GetServices: IServiceProvider; begin Result := nil; end;
procedure TMockHttpContext.SetServices(const AValue: IServiceProvider); begin end;
function TMockHttpContext.GetConnection: IDextServerConnection; begin Result := nil; end;
function TMockHttpContext.GetSession: IStreamableSession; begin Result := nil; end;
function TMockHttpContext.GetEndpointMetadata: TEndpointMetadata; begin Result := Default(TEndpointMetadata); end;
procedure TMockHttpContext.SetEndpointMetadata(const AMetadata: TEndpointMetadata); begin end;
procedure TMockHttpContext.SetRouteParams(const AParams: TRouteValueDictionary); begin end;

function TMockHttpContext.GetUser: IClaimsPrincipal; begin Result := nil; end;
procedure TMockHttpContext.SetUser(const AValue: IClaimsPrincipal); begin end;

{ TBenchMiddleware }

class procedure TBenchMiddleware.Run;
const
  ITERATIONS = 10000;
var
  SW: TStopwatch;
  I: Integer;
  AllocCountStart: Int64;
  AllocDelta: Int64;
  Context: IHttpContext;
  Pipeline: IDextPipeline;
  FixedRoutes: IDictionary<string, TRequestDelegate>;
  PatternRoutes: IDictionary<TRoutePattern, TRequestDelegate>;
  PipelineDelegate: TRequestDelegate;
begin
  Writeln('--- Middleware Pipeline Benchmark ---');
  Writeln('Iterations: ', ITERATIONS);

  FixedRoutes := TCollections.CreateDictionary<string, TRequestDelegate>;
  PatternRoutes := TCollections.CreateDictionary<TRoutePattern, TRequestDelegate>;
  PipelineDelegate := procedure(ctx: IHttpContext)
  begin
    // End of pipeline
  end;
  
  Pipeline := TDextPipeline.Create(FixedRoutes, PatternRoutes, PipelineDelegate);
  Context := TMockHttpContext.Create('GET', '/api/users');

  SW := TStopwatch.StartNew;
  AllocCountStart := GetAllocatedBytes;
  
  for I := 1 to ITERATIONS do
  begin
    Pipeline.Execute(Context);
  end;
  SW.Stop;

  AllocDelta := GetAllocatedBytes - AllocCountStart;

  Writeln('1. Pipeline Execution');
  Writeln(Format('   Time: %.2f ms', [SW.Elapsed.TotalMilliseconds]));
  Writeln(Format('   Allocations (approx bytes): %d', [AllocDelta])); 
  Writeln('--------------------------------');
end;

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

end.
