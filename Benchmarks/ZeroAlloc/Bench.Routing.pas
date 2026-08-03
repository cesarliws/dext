unit Bench.Routing;

interface

type
  TBenchRouting = class
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
  Dext.Server.Engine.Interfaces,
  Dext.Web.Routing,
  Dext.Web.Pipeline,
  Dext.Collections,
  Dext.Collections.Dict,
  Bench.Utils;

{ TMockHttpContext }

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
end;

function TMockHttpContext.GetItems: IDictionary<string, TValue>; begin Result := nil; end;
function TMockHttpContext.GetRequest: IHttpRequest; begin Result := FRequest; end;
function TMockHttpContext.GetResponse: IHttpResponse; begin Result := nil; end;
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

{ TBenchRouting }

class procedure TBenchRouting.Run;
const
  ITERATIONS = 10000;
var
  Routes: IList<TRouteDefinition>;
  Matcher: IRouteMatcher;
  Context1, Context2: IHttpContext;
  SW: TStopwatch;
  I: Integer;
  Handler: TRequestDelegate;
  RouteParams: TRouteValueDictionary;
  Metadata: TEndpointMetadata;
  AllocCountStart: Int64;
  AllocDelta: Int64;
begin
  Writeln('--- Routing Engine Benchmark ---');
  Writeln('Iterations: ', ITERATIONS);

  // Setup Routes
  Routes := TCollections.CreateList<TRouteDefinition>;
  for I := 1 to 50 do
    Routes.Add(TRouteDefinition.Create('GET', '/api/v1/resource' + I.ToString, nil));

  // Add some pattern routes
  Routes.Add(TRouteDefinition.Create('GET', '/api/users/{id}', nil));
  Routes.Add(TRouteDefinition.Create('POST', '/api/users/{id}/orders/{orderId}', nil));

  Matcher := TRouteMatcher.Create(Routes);
  try
    Context1 := TMockHttpContext.Create('GET', '/api/v1/resource50'); // Literal Match
    Context2 := TMockHttpContext.Create('POST', '/api/users/99/orders/Abc123XYz'); // Pattern Match

    // Literal Test
    SW := TStopwatch.StartNew;
    AllocCountStart := GetAllocatedBytes;
    
    for I := 1 to ITERATIONS do
    begin
      Matcher.FindMatchingRoute(Context1, Handler, RouteParams, Metadata);
    end;
    SW.Stop;
    
    AllocDelta := GetAllocatedBytes - AllocCountStart;

    Writeln('1. Literal Match (GET /api/v1/resource50)');
    Writeln(Format('   Time: %.2f ms', [SW.Elapsed.TotalMilliseconds]));
    Writeln(Format('   Allocations (approx): %d', [AllocDelta])); 


    // Pattern Test
    SW := TStopwatch.StartNew;
    AllocCountStart := GetAllocatedBytes;
    
    for I := 1 to ITERATIONS do
    begin
      Matcher.FindMatchingRoute(Context2, Handler, RouteParams, Metadata);
    end;
    SW.Stop;

    AllocDelta := GetAllocatedBytes - AllocCountStart;

    Writeln('2. Pattern Match (POST /api/users/99/orders/Abc123XYz)');
    Writeln(Format('   Time: %.2f ms', [SW.Elapsed.TotalMilliseconds]));
    Writeln(Format('   Allocations (approx): %d', [AllocDelta])); 

    Writeln('--------------------------------');
  finally
    for I := 0 to Routes.Count - 1 do
      Routes[I].Free;
  end;
end;

end.
