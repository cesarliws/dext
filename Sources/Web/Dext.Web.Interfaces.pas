{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2025 Cesar Romero & Dext Contributors             }
{                                                                           }
{           Licensed under the Apache License, Version 2.0 (the "License"); }
{           you may not use this file except in compliance with the License.}
{           You may obtain a copy of the License at                         }
{                                                                           }
{               http://www.apache.org/licenses/LICENSE-2.0                  }
{                                                                           }
{           Unless required by applicable law or agreed to in writing,      }
{           software distributed under the License is distributed on an     }
{           "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,    }
{           either express or implied. See the License for the specific     }
{           language governing permissions and limitations under the        }
{           License.                                                        }
{                                                                           }
{***************************************************************************}
{                                                                           }
{  Author:  Cesar Romero                                                    }
{  Created: 2025-12-08                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.Web.Interfaces;

interface

uses
  System.Classes,
  System.Rtti,
  System.SysUtils,
  System.TypInfo,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.DI.Interfaces,
  Dext.Auth.Identity,
  Dext.Configuration.Interfaces,
  Dext.Threading.CancellationToken,
  Dext.Server.Engine.Types,
  Dext.Server.Engine.Interfaces;

{$M+}
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
  TServerFactory = reference to function(Port: Integer; Pipeline: TRequestDelegate; Services: IServiceProvider): IWebHost;

  TOpenAPIResponseMetadata = record
    StatusCode: Integer;
    Description: string;
    MediaType: string;
    SchemaType: PTypeInfo;
  end;

  TEndpointMetadata = record
    Method: string;
    Path: string;
    Summary: string;
    Description: string;
    Tags: TArray<string>;
    Parameters: TArray<string>; // Added parameters
    Security: TArray<string>;   // Security schemes required
    ApiVersions: TArray<string>; // Supported API versions (e.g. '1.0', '2.0')
    RequestType: PTypeInfo;      // Type info for request body
    ResponseType: PTypeInfo;     // Type info for response body
    Responses: TArray<TOpenAPIResponseMetadata>; // Documented responses
    AllowAnonymous: Boolean;     // Skips authorization check
  end;

  TCookieOptions = record
    Path: string;
    Domain: string;
    Expires: TDateTime;
    HttpOnly: Boolean;
    Secure: Boolean;
    SameSite: string; // 'Lax', 'Strict', 'None'
    class function Default: TCookieOptions; static;
  end;

  TRouteParamPair = record
    Key: string;
    Value: string;
  end;

  /// <summary>
  ///   Optimized dictionary for storing route parameters.
  ///   Uses an internal fixed array to avoid heap allocations during route resolution (Zero-Allocation).
  /// </summary>
  TRouteValueDictionary = record
  private
    FPairs: array[0..15] of TRouteParamPair;
    FCount: Integer;
    function GetItem(const AKey: string): string;
  public
    /// <summary>Adds a key/value pair to the dictionary.</summary>
    procedure Add(const AKey, AValue: string);
    /// <summary>Clears all parameters without deallocating the structure.</summary>
    procedure Clear;
    /// <summary>Attempts to get a value by key. Returns True if found.</summary>
    function TryGetValue(const AKey: string; out AValue: string): Boolean;
    function ContainsKey(const AKey: string): Boolean;
    function GetKeyByIndex(AIndex: Integer): string;
    function GetValueByIndex(AIndex: Integer): string;
    /// <summary>Number of parameters currently stored.</summary>
    property Count: Integer read FCount;
    /// <summary>Indexed access to parameter values.</summary>
    property Items[const AKey: string]: string read GetItem; default;
  end;

  IFormFile = interface;

  IFormFileCollection = interface
    ['{F2B3C4D5-E6F7-4812-9012-3456789ABCDE}']
    function GetCount: Integer;
    function GetItem(AIndex: Integer): IFormFile;
    function GetFile(const AName: string): IFormFile;
    procedure Add(const AFile: IFormFile);
    property Count: Integer read GetCount;
    property Items[AIndex: Integer]: IFormFile read GetItem; default;
  end;

  IFormFile = interface
    ['{B1A2C3D4-E5F6-4789-0123-456789ABCDEF}']
    function GetFileName: string;
    function GetName: string; // Field name
    function GetContentType: string;
    function GetLength: Int64;
    function GetStream: TStream;
    property FileName: string read GetFileName;
    property Name: string read GetName;
    property ContentType: string read GetContentType;
    property Length: Int64 read GetLength;
    property Stream: TStream read GetStream;
  end;

  /// <summary>
  ///   Represents the result of an HTTP action execution.
  /// </summary>
  IResult = interface
    ['{D6F5E4A3-9B2C-4D1E-8F7A-6C5B4E3D2F1A}']
    procedure Execute(AContext: IHttpContext);
  end;

  /// <summary>
  ///   Abstraction of an incoming HTTP request. Provides access to verbs, paths, 
  ///   query parameters, headers, cookies, and files (multipart).
  /// </summary>
  IHttpRequest = interface
    ['{C3E8F1A2-4B7D-4A9C-9E2B-8F6D5A1C3E7F}']
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
    // TODO : Implement service scope
    // function GetServiceScope: IServiceScope; // Optional: Scope management
    function GetFiles: IFormFileCollection;
    
    /// <summary>HTTP Verb (GET, POST, etc.).</summary>
    property Method: string read GetMethod;
    /// <summary>Request path (e.g., /api/v1/users).</summary>
    property Path: string read GetPath;
    /// <summary>Dictionary of query string parameters.</summary>
    property Query: IStringDictionary read GetQuery;
    /// <summary>Stream containing the request body.</summary>
    property Body: TStream read GetBody;
    /// <summary>Parameters extracted from the route (e.g., {id}).</summary>
    property RouteParams: TRouteValueDictionary read GetRouteParams;
    /// <summary>Dictionary of HTTP headers.</summary>
    property Headers: IStringDictionary read GetHeaders;
    /// <summary>Dictionary of received cookies.</summary>
    property Cookies: IStringDictionary read GetCookies;
    /// <summary>Collection of files received via multipart/form-data.</summary>
    property Files: IFormFileCollection read GetFiles;
    /// <summary>Remote IP address of the client.</summary>
    property RemoteIpAddress: string read GetRemoteIpAddress;
  end;

  /// <summary>
  ///   Fluent interface for manipulating HTMX-specific response headers.
  /// </summary>
  IHtmxResponse = interface
    ['{8A2B3C4D-5E6F-7890-1234-56789ABCDEF0}']
    /// <summary>Triggers a client-side event (HX-Trigger).</summary>
    function Trigger(const AEvent: string): IHtmxResponse; overload;
    /// <summary>Triggers a client-side event with a JSON payload.</summary>
    function Trigger(const AEvent: string; const APayload: string): IHtmxResponse; overload;
    /// <summary>Overrides the target element (HX-Retarget).</summary>
    function Retarget(const ASelector: string): IHtmxResponse;
    /// <summary>Overrides the swap strategy (HX-Reswap).</summary>
    function Reswap(const ASwap: string): IHtmxResponse;
    /// <summary>Performs a client-side redirect (HX-Redirect).</summary>
    function Redirect(const AUrl: string): IHtmxResponse;
    /// <summary>Forces a full page refresh (HX-Refresh).</summary>
    function Refresh: IHtmxResponse;
    /// <summary>Overrides the part of the response that is swapped (HX-Reselect).</summary>
    function Reselect(const ASelector: string): IHtmxResponse;
    /// <summary>Pushes a new URL into the history stack (HX-Push-Url).</summary>
    function PushUrl(const AUrl: string): IHtmxResponse;
    /// <summary>Replaces the current URL in the history stack (HX-Replace-Url).</summary>
    function ReplaceUrl(const AUrl: string): IHtmxResponse;
    /// <summary>Allows you to do a client-side redirect that does not reload the page (HX-Location).</summary>
    function Location(const AUrl: string): IHtmxResponse;
  end;

  /// <summary>
  ///   Abstraction of an HTTP response to be sent. Allows setting status codes, 
  ///   headers, cookies, and writing the response body in various formats.
  /// </summary>
  IHttpResponse = interface
    ['{D4F9E2A1-5B8C-4D3A-8E7B-6F5A2D1C9E8F}']
    function GetStatusCode: Integer;
    function GetContentType: string;
    
    /// <summary>Sets the status code fluently and returns the interface itself.</summary>
    function Status(AValue: Integer): IHttpResponse;
    procedure SetStatusCode(AValue: Integer);
    procedure SetContentType(const AValue: string);
    procedure SetContentLength(const AValue: Int64);
    
    /// <summary>Flushes any buffered response data to the underlying transport.</summary>
    procedure Flush;
    
    /// <summary>Writes a string directly to the response body (UTF-8).</summary>
    procedure Write(const AContent: string); overload;
    /// <summary>Writes a raw byte buffer to the response body.</summary>
    procedure Write(const ABuffer: TBytes); overload;
    /// <summary>Writes a stream content directly to the transport (Streaming).</summary>
    procedure Write(const AStream: TStream); overload;
    /// <summary>Sends a formatted JSON string as response (sets Content-Type).</summary>
    procedure Json(const AJson: string); overload;
    /// <summary>Serializes a TValue (Object, Array, Primitive) to JSON and sends it.</summary>
    procedure Json(const AValue: TValue); overload;
    
    /// <summary>Adds a custom HTTP header to the response.</summary>
    procedure AddHeader(const AName, AValue: string);
    /// <summary>Appends a cookie to the response with advanced options (HttpOnly, Secure, etc.).</summary>
    procedure AppendCookie(const AName, AValue: string; const AOptions: TCookieOptions); overload;
    procedure AppendCookie(const AName, AValue: string); overload;
    /// <summary>Marks a cookie for removal on the client side.</summary>
    procedure DeleteCookie(const AName: string);
    
    /// <summary>Performs an HTTP redirect (302 Found by default).</summary>
    procedure Redirect(const AUrl: string; APermanent: Boolean = False);
    /// <summary>Sets status to 401 Unauthorized and writes an optional message.</summary>
    procedure Unauthorized(const AMessage: string = '');
    /// <summary>Sets status to 403 Forbidden and writes an optional message.</summary>
    procedure Forbidden(const AMessage: string = '');
    /// <summary>Sets status to 400 Bad Request and writes an optional message.</summary>
    procedure BadRequest(const AMessage: string = '');
    /// <summary>Sets status to 404 Not Found and writes an optional message.</summary>
    procedure NotFound(const AMessage: string = '');
    
    /// <summary>Access to HTMX-specific response modifiers.</summary>
    function GetHtmx: IHtmxResponse;
    
    /// <summary>Access to the outgoing HTTP headers.</summary>
    function GetHeaders: IStringDictionary;
    
    /// <summary>HTTP status code (e.g., 200, 404, 500).</summary>
    property StatusCode: Integer read GetStatusCode write SetStatusCode;
    /// <summary>Response MIME type (e.g., application/json).</summary>
    property ContentType: string read GetContentType write SetContentType;
    /// <summary>HTMX extensions.</summary>
    property Htmx: IHtmxResponse read GetHtmx;
    /// <summary>Dictionary of response headers.</summary>
    property Headers: IStringDictionary read GetHeaders;
  end;

  /// <summary>
  ///   Represents an independent session bound to a client, which can be
  ///   maintained across stateless POST requests and stream unidirectional Server-Sent Events.
  /// </summary>
  IStreamableSession = interface
    ['{F8A9C1D2-B3E4-4567-8901-23456789ABCD}']
    function GetId: string;
    procedure SetState(const AKey: string; const AValue: TValue);
    function GetState(const AKey: string): TValue;
    procedure RemoveState(const AKey: string);
    
    // Server-Side Event Methods
    procedure SendSseEvent(const AEventName, AData: string);
    function HasEvents: Boolean;
    function TryDequeueEvent(out AEventName, AData: string): Boolean;
    
    property Id: string read GetId;
  end;

  /// <summary>
  ///   High-level abstraction for broadcasting events to active streamable sessions.
  /// </summary>
  IEventStreamer = interface
    ['{E1F2A3B4-C5D6-4E7F-8901-234567890ABC}']
    /// <summary>Broadcasts an event to all active sessions.</summary>
    procedure PushEvent(const AEventName, AData: string);
    /// <summary>Sends an event to a specific session.</summary>
    procedure PushEventTo(const ASessionId, AEventName, AData: string);
  end;

  /// <summary>
  ///   Manages the lifecycle of streamable sessions independently of the HTTP connection.

  /// </summary>
  IStreamableSessionManager = interface
    ['{E7B8D2C3-A4F5-4678-9012-34567890BCDE}']
    function CreateSession: IStreamableSession;
    function GetSession(const ASessionId: string): IStreamableSession;
    procedure DestroySession(const ASessionId: string);
    /// <summary>
    ///   Starts the background GC scavenger.
    ///   AStoppingToken: optional host ApplicationStopping token — when cancelled,
    ///   the scavenger exits without waiting for the full interval.
    /// </summary>
    procedure StartScavenger(AIntervalSeconds: Integer = 60; ATimeoutMinutes: Integer = 30;
      const AStoppingToken: ICancellationToken = nil);
    procedure StopScavenger;
  end;

  /// <summary>
  ///   Encapsulates all specific information of an individual HTTP request.
  ///   Allows Middlewares and Controllers to access request data, configure the response,
  ///   and use services via Scoped Dependency Injection.
  /// </summary>
  IHttpContext = interface
    ['{E5F8D2C1-9A4E-4B7D-8C3B-6F5A1D2E8C9F}']
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
    
    /// <summary>Access to the underlying network connection.</summary>
    property Connection: IDextServerConnection read GetConnection;
    /// <summary>Access to the incoming request data.</summary>
    property Request: IHttpRequest read GetRequest;
    /// <summary>Access to the outgoing response.</summary>
    property Response: IHttpResponse read GetResponse write SetResponse;
    /// <summary>Scoped service provider for this request.</summary>
    property Services: IServiceProvider read GetServices write SetServices;
    /// <summary>Representation of the authenticated user (ClaimsPrincipal).</summary>
    property User: IClaimsPrincipal read GetUser write SetUser;
    /// <summary>Dictionary of useful items to share state between middlewares.</summary>
    property Items: IDictionary<string, TValue> read GetItems;
    /// <summary>Resolved streamable session (if enabled and matching Dext-Session-Id).</summary>
    property Session: IStreamableSession read GetSession;
  end;

  IMiddleware = interface
    ['{F1E8D2C3-9A4E-4B7D-8C5B-6F5A1D2E8C9F}']
    procedure Invoke(AContext: IHttpContext; ANext: TRequestDelegate);
  end;

  /// <summary>
  ///   Defines a mechanism to configure an application's request pipeline.
  /// </summary>
  IApplicationBuilder = interface
    ['{A2F8C5D1-8B4E-4A7D-9C3B-6E8F4A2D1C7A}']
    function GetServiceProvider: IServiceProvider;
    function UseMiddleware(AMiddleware: TClass): IApplicationBuilder; overload;
    function UseMiddleware(AMiddleware: TClass; const AParam: TValue): IApplicationBuilder; overload;
    function UseMiddleware(AMiddleware: TClass; const AParams: array of TValue): IApplicationBuilder; overload;
    function UseMiddleware(AMiddleware: IMiddleware): IApplicationBuilder; overload; // ? Singleton Middleware
    
    // ? Functional Middleware
    function Use(AMiddleware: TMiddlewareDelegate): IApplicationBuilder;

    function UseModelBinding: IApplicationBuilder;

    function Map(const APath: string; ADelegate: TRequestDelegate): IApplicationBuilder;
    function MapEndpoint(const AMethod, APath: string; ADelegate: TRequestDelegate): IApplicationBuilder;
    function MapPost(const Path: string; Handler: TStaticHandler): IApplicationBuilder;
    function MapGet(const Path: string; Handler: TStaticHandler): IApplicationBuilder;
    function MapPut(const Path: string; Handler: TStaticHandler): IApplicationBuilder;
    function MapDelete(const Path: string; Handler: TStaticHandler): IApplicationBuilder;
    function Build: TRequestDelegate;
    
    function GetRoutes: TArray<TEndpointMetadata>; // ? Introspection
    procedure UpdateLastRouteMetadata(const AMetadata: TEndpointMetadata); // ? For fluent API
    procedure SetServiceProvider(const AProvider: IServiceProvider); // ? Update Provider before Build
    
    /// <summary>
    ///   Registers an object to be disposed when the host shuts down.
    ///   Use for objects that should live for the lifetime of the application.
    /// </summary>
    procedure RegisterForDisposal(AObject: TObject);
  end;

  IWebHost = interface
    ['{B3E7D4F1-9C6E-4B8A-8D2C-7F5A1B3E8D9F}']
    function GetPort: Integer;
    procedure Run;
    procedure Start;
    procedure Stop;
    property Port: Integer read GetPort;
  end;

  IWebHostBuilder = interface
    ['{C4F8E5D2-8D4E-4A7D-9C3B-6E8F4A2D1C7B}']
    function ConfigureServices(AConfigurator: TProc<IServiceCollection>): IWebHostBuilder;
    function Configure(AConfigurator: TProc<IApplicationBuilder>): IWebHostBuilder;
    function UseUrls(const AUrls: string): IWebHostBuilder;
    function Build: IWebHost;
  end;

  /// <summary>
  ///   Wrapper for IApplicationBuilder to provide factory methods and extensions.
  /// </summary>
  TAppBuilder = record
  private
    FBuilder: IApplicationBuilder;
  public
    constructor Create(ABuilder: IApplicationBuilder);
    function Unwrap: IApplicationBuilder;
    class operator Implicit(const A: TAppBuilder): IApplicationBuilder;
  end;

  /// <deprecated>Use TAppBuilder instead</deprecated>
  TDextAppBuilder = TAppBuilder;

  // Forward declaration
  IWebApplication = interface;

  IStartup = interface
    ['{8A95A642-1246-4552-BD90-0824B7517E08}']
    procedure ConfigureServices(const Services: TDextServices; const Configuration: IConfiguration);
    procedure Configure(const App: IWebApplication);
  end;

  /// <summary>
  ///   Represents a hosted web application, allowing fluent configuration of services and routes.
  /// </summary>
  IWebApplication = interface(IWebHost)
    ['{B6C96B49-0292-42A6-A767-C7EAF52F71FC}']
    function GetServices: TDextServices;
    function GetBuilder: TAppBuilder;
    function UseMiddleware(Middleware: TClass): IWebApplication;
    function UseStartup(Startup: IStartup): IWebApplication; // ? Non-generic
    function MapControllers: IWebApplication;
    function GetApplicationBuilder: IApplicationBuilder;
    function GetConfiguration: IConfiguration;
    function GetServiceProvider: IServiceProvider;
    function BuildServices: IServiceProvider; // ? Automation
    procedure UseServerFactory(const AFactory: TServerFactory);
    procedure UseNativeServer; overload;
    procedure UseNativeServer(const AOptions: TServerEngineOptions); overload;
    procedure Run; overload;
    procedure Run(Port: Integer); overload;
    procedure Start; overload;
    procedure Start(Port: Integer); overload;
    procedure SetDefaultPort(Port: Integer);

    property Services: TDextServices read GetServices;
    property ServiceProvider: IServiceProvider read GetServiceProvider;
    property Builder: TAppBuilder read GetBuilder;
    property Configuration: IConfiguration read GetConfiguration;
    property Port: Integer read GetPort;
  end;

  TWebHost = class
    class function CreateDefaultBuilder: IWebHostBuilder;
  end;

  /// <deprecated>Use TWebHost instead</deprecated>
  TDextWebHost = TWebHost;

  TFormFileCollection = class(TInterfacedObject, IFormFileCollection)
  private
    FItems: IList<IFormFile>;
  public
    constructor Create(AItems: IList<IFormFile>);
    destructor Destroy; override;
    function GetCount: Integer;
    function GetItem(AIndex: Integer): IFormFile;
    function GetFile(const AName: string): IFormFile;
    procedure Add(const AFile: IFormFile);
  end;

{$M-}
implementation

uses
  Dext.WebHost;

{ TFormFileCollection }

constructor TFormFileCollection.Create(AItems: IList<IFormFile>);
begin
  inherited Create;
  FItems := AItems;
end;

destructor TFormFileCollection.Destroy;
begin
  FItems := nil;
  inherited;
end;

function TFormFileCollection.GetCount: Integer;
begin
  Result := FItems.Count;
end;

procedure TFormFileCollection.Add(const AFile: IFormFile);
begin
  FItems.Add(AFile);
end;

function TFormFileCollection.GetFile(const AName: string): IFormFile;
var
  AFile: IFormFile;
begin
  for AFile in FItems do
  begin
    if SameText(AFile.Name, AName) then
      Exit(AFile);
  end;
  Result := nil;
end;

function TFormFileCollection.GetItem(AIndex: Integer): IFormFile;
begin
  Result := FItems[AIndex];
end;

{ TDextWebHost }

class function TWebHost.CreateDefaultBuilder: IWebHostBuilder;
begin
  Result := TWebHostBuilder.Create;
end;

{ TDextAppBuilder }

constructor TAppBuilder.Create(ABuilder: IApplicationBuilder);
begin
  FBuilder := ABuilder;
end;

function TAppBuilder.Unwrap: IApplicationBuilder;
begin
  Result := FBuilder;
end;

class operator TAppBuilder.Implicit(const A: TAppBuilder): IApplicationBuilder;
begin
  Result := A.FBuilder;
end;

{ TCookieOptions }

class function TCookieOptions.Default: TCookieOptions;
begin
  Result.Path := '/';
  Result.Domain := '';
  Result.Expires := 0;
  Result.HttpOnly := True;
  Result.Secure := False;
  Result.SameSite := 'Lax';
end;

{ TRouteValueDictionary }

procedure TRouteValueDictionary.Add(const AKey, AValue: string);
begin
  if FCount < Length(FPairs) then
  begin
    FPairs[FCount].Key := AKey;
    FPairs[FCount].Value := AValue;
    Inc(FCount);
  end;
end;

procedure TRouteValueDictionary.Clear;
begin
  FCount := 0;
end;

function TRouteValueDictionary.GetItem(const AKey: string): string;
var
  I: Integer;
begin
  for I := 0 to FCount - 1 do
    if SameText(FPairs[I].Key, AKey) then
      Exit(FPairs[I].Value);
  Result := '';
end;

function TRouteValueDictionary.TryGetValue(const AKey: string; out AValue: string): Boolean;
var
  I: Integer;
begin
  for I := 0 to FCount - 1 do
    if SameText(FPairs[I].Key, AKey) then
    begin
      AValue := FPairs[I].Value;
      Exit(True);
    end;
  AValue := '';
  Result := False;
end;

function TRouteValueDictionary.ContainsKey(const AKey: string): Boolean;
var
  I: Integer;
begin
  for I := 0 to FCount - 1 do
    if SameText(FPairs[I].Key, AKey) then
      Exit(True);
  Result := False;
end;

function TRouteValueDictionary.GetKeyByIndex(AIndex: Integer): string;
begin
  if (AIndex >= 0) and (AIndex < FCount) then
    Result := FPairs[AIndex].Key
  else
    Result := '';
end;

function TRouteValueDictionary.GetValueByIndex(AIndex: Integer): string;
begin
  if (AIndex >= 0) and (AIndex < FCount) then
    Result := FPairs[AIndex].Value
  else
    Result := '';
end;

end.

