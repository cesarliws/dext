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
{  Author:  Cesar Romero & Contributors                                     }
{  Created: 2026-03-05                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.Web.WebBroker;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Rtti,
  Web.HTTPApp,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.Web.Interfaces,
  Dext.DI.Interfaces,
  Dext.Auth.Identity,
  Dext.Web.Results,
  Dext, // Para TDextServices
  Dext.Json,
  Dext.Server.Engine.Interfaces;

type
  // -------------------------------------------------------------------------
  // TDextWebBrokerRequest - IHttpRequest backed by TWebRequest
  // -------------------------------------------------------------------------
  /// <summary>
  ///   Implementation of <see cref="IHttpRequest"/> for the Delphi WebBroker pattern.
  /// </summary>
  TDextWebBrokerRequest = class(TInterfacedObject, IHttpRequest)
  private
    FWebRequest: TWebRequest;
    FQuery: IStringDictionary;
    FBody: TStream;
    FHeaders: IStringDictionary;
    FCookies: IStringDictionary;
    FRouteParams: TRouteValueDictionary;
    FFiles: IFormFileCollection;
    function ParseQueryString(const AQuery: string): IStringDictionary;
    function BuildHeaders: IStringDictionary;
    function BuildCookies: IStringDictionary;
  public
    constructor Create(AWebRequest: TWebRequest);
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
    property Method: string read GetMethod;
    property Path: string read GetPath;
    property Query: IStringDictionary read GetQuery;
    property Body: TStream read GetBody;
    property RouteParams: TRouteValueDictionary read GetRouteParams;
    property Headers: IStringDictionary read GetHeaders;
    property Cookies: IStringDictionary read GetCookies;
    property Files: IFormFileCollection read GetFiles;
    property RemoteIpAddress: string read GetRemoteIpAddress;
  end;

  TCookieEntry = record
    Name: string;
    Value: string;
    Options: TCookieOptions;
  end;

  // -------------------------------------------------------------------------
  // TDextWebBrokerResponse - IHttpResponse backed by TWebResponse (buffered)
  // -------------------------------------------------------------------------
  /// <summary>
  ///   Implementation of <see cref="IHttpResponse"/> for the Delphi WebBroker pattern.
  /// </summary>
  TDextWebBrokerResponse = class(TInterfacedObject, IHttpResponse)
  private
    FWebResponse: TWebResponse;
    FBuffer: TMemoryStream;
    FStatusCode: Integer;
    FContentType: string;
    FCustomHeaders: TStringList;
    FCookies: array of TCookieEntry;
    FHtmx: IHtmxResponse;
    FHeaders: IStringDictionary;
    procedure FlushToWebResponse;
  public
    constructor Create(AWebResponse: TWebResponse);
    destructor Destroy; override;

    function GetHtmx: IHtmxResponse;
    function GetHeaders: IStringDictionary;

    function Status(AValue: Integer): IHttpResponse;
    function GetStatusCode: Integer;
    function GetContentType: string;
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
    property StatusCode: Integer read GetStatusCode write SetStatusCode;
    property ContentType: string read GetContentType write SetContentType;
  end;

  // -------------------------------------------------------------------------
  // TDextWebBrokerContext - IHttpContext for a single WebBroker request
  // -------------------------------------------------------------------------
  TDextWebBrokerContext = class(TInterfacedObject, IHttpContext)
  private
    FRequest: IHttpRequest;
    FResponse: IHttpResponse;
    FScope: IServiceScope;
    FServices: IServiceProvider;
    FUser: IClaimsPrincipal;
    FItems: IDictionary<string, TValue>;
  public
    /// <summary>
    ///   Takes pre-created request/response objects so callers can keep
    ///   typed references (avoids unsafe interface-to-class cast).
    /// </summary>
    constructor Create(const ARequest: IHttpRequest; const AResponse: IHttpResponse;
      const AServices: IServiceProvider);
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
    /// <summary>
    ///   Sets the route parameters for the request.
    /// </summary>
    procedure SetRouteParams(const AParams: TRouteValueDictionary);
    property Connection: IDextServerConnection read GetConnection;
    property Request: IHttpRequest read GetRequest;
    property Response: IHttpResponse read GetResponse write SetResponse;
    property Services: IServiceProvider read GetServices write SetServices;
    property User: IClaimsPrincipal read GetUser write SetUser;
    property Items: IDictionary<string, TValue> read GetItems;
  end;

  // -------------------------------------------------------------------------
  // TDextWebBrokerServer - no-op IWebHost (WebBroker/IIS is the real server)
  // -------------------------------------------------------------------------
  TDextWebBrokerServer = class(TInterfacedObject, IWebHost)
  public
    function GetPort: Integer;
    procedure Run;
    procedure Start;
    procedure Stop;
  end;

  // -------------------------------------------------------------------------
  // TDextWebBrokerApp - global coordinator for DLL/CGI lifecycle
  // -------------------------------------------------------------------------
  /// <summary>
  ///   Global coordinator for the lifecycle of Dext applications running under WebBroker (DLL/CGI).
  /// </summary>
  TDextWebBrokerApp = class
  strict private
    class var FPipeline: TRequestDelegate;
    class var FServiceProvider: IServiceProvider;
    class var FApp: IWebApplication;
  public
    /// <summary>
    ///   Call once at DLL/program load. Builds the Dext pipeline and stores the
    ///   service provider and request delegate for use on every incoming request.
    /// </summary>
    class procedure Configure(Startup: IStartup);
    /// <summary>
    ///   Dispatches a single WebBroker request through the Dext pipeline.
    ///   Should be called from the OnBeforeDispatch event of a WebBroker DataModule (e.g., TDextWebModule).
    /// </summary>
    class procedure HandleRequest(Req: TWebRequest; Resp: TWebResponse);
    /// <summary>
    ///   Release all resources. Call from library finalization or CGI program end.
    /// </summary>
    class procedure Shutdown;
  end;

  // -------------------------------------------------------------------------
  // TDextWebModule - TWebModule wired to TDextWebBrokerApp
  // -------------------------------------------------------------------------
  /// <summary>
  ///   Specialized TWebModule to facilitate the bridge between WebBroker and Dext routes.
  /// </summary>
  TDextWebModule = class(TWebModule)
  public
    constructor Create(AOwner: TComponent); override;
  published
    procedure WebModuleBeforeDispatch(Sender: TObject; Request: TWebRequest;
      Response: TWebResponse; var Handled: Boolean);
  end;

implementation

uses
  System.NetEncoding,
  Dext.Web,
  Dext.Web.WebApplication;

// Known header field names exposed by TWebRequest.GetFieldByName
const
  KnownHeaders: array[0..13] of string = (
    'Authorization',
    'Content-Type',
    'Content-Length',
    'Accept',
    'Accept-Language',
    'Accept-Encoding',
    'Host',
    'User-Agent',
    'Referer',
    'Cookie',
    'X-Forwarded-For',
    'X-Forwarded-Proto',
    'X-Real-IP',
    'Origin'
  );

{ TDextWebBrokerRequest }

constructor TDextWebBrokerRequest.Create(AWebRequest: TWebRequest);
begin
  inherited Create;
  FWebRequest := AWebRequest;
  FRouteParams.Clear;
  FFiles := TFormFileCollection.Create(TCollections.CreateList<IFormFile>);
end;

destructor TDextWebBrokerRequest.Destroy;
begin
  FBody.Free;
  FRouteParams.Clear;
  FHeaders := nil;
  FCookies := nil;
  FFiles := nil;
  inherited;
end;

function TDextWebBrokerRequest.ParseQueryString(const AQuery: string): IStringDictionary;
var
  Params: TArray<string>;
  Param: string;
  Parts: TArray<string>;
begin
  Result := TCollections.CreateStringDictionary(True);
  if AQuery = '' then
    Exit;

  Params := AQuery.Split(['&']);
  for Param in Params do
  begin
    if Param = '' then
      Continue;

    Parts := Param.Split(['='], 2);
    if Length(Parts) = 2 then
      Result.AddOrSetValue(TNetEncoding.URL.Decode(Parts[0]), TNetEncoding.URL.Decode(Parts[1]))
    else
      Result.AddOrSetValue(TNetEncoding.URL.Decode(Parts[0]), '');
  end;
end;

function TDextWebBrokerRequest.BuildHeaders: IStringDictionary;
var
  HeaderName: string;
  HeaderValue: string;
begin
  Result := TCollections.CreateStringDictionary(True);
  for HeaderName in KnownHeaders do
  begin
    HeaderValue := FWebRequest.GetFieldByName(HeaderName);
    if HeaderValue <> '' then
      Result.AddOrSetValue(HeaderName, HeaderValue);
  end;
end;

function TDextWebBrokerRequest.BuildCookies: IStringDictionary;
var
  CookieStr: string;
  Pairs: TArray<string>;
  Pair: string;
  Parts: TArray<string>;
begin
  Result := TCollections.CreateStringDictionary(True);
  CookieStr := FWebRequest.GetFieldByName('Cookie');
  if CookieStr = '' then Exit;
  Pairs := CookieStr.Split([';']);
  for Pair in Pairs do
  begin
    Parts := Pair.Trim.Split(['='], 2);
    if Length(Parts) = 2 then
      Result.AddOrSetValue(Parts[0].Trim, TNetEncoding.URL.Decode(Parts[1].Trim))
    else if (Length(Parts) = 1) and (Parts[0].Trim <> '') then
      Result.AddOrSetValue(Parts[0].Trim, '');
  end;
end;

function TDextWebBrokerRequest.GetMethod: string;
begin
  Result := FWebRequest.Method;
end;

function TDextWebBrokerRequest.GetPath: string;
begin
  Result := FWebRequest.PathInfo;
  if Result = '' then
    Result := '/';
end;

function TDextWebBrokerRequest.GetQuery: IStringDictionary;
begin
  if FQuery = nil then
    FQuery := ParseQueryString(FWebRequest.Query);
  Result := FQuery;
end;

function TDextWebBrokerRequest.GetQueryParam(const AName: string): string;
begin
  if not GetQuery.TryGetValue(AName, Result) then
    Result := '';
end;

function TDextWebBrokerRequest.GetBody: TStream;
var
  RawBytes: TBytes;
begin
  if FBody = nil then
  begin
    RawBytes := FWebRequest.RawContent;
    FBody := TBytesStream.Create(RawBytes);
    FBody.Position := 0;
  end;
  Result := FBody;
end;

function TDextWebBrokerRequest.GetRouteParams: TRouteValueDictionary;
begin
  Result := FRouteParams;
end;

function TDextWebBrokerRequest.GetHeaders: IStringDictionary;
begin
  if FHeaders = nil then
    FHeaders := BuildHeaders;
  Result := FHeaders;
end;

function TDextWebBrokerRequest.GetHeader(const AName: string): string;
begin
  Result := FWebRequest.GetFieldByName(AName);
end;

function TDextWebBrokerRequest.GetRemoteIpAddress: string;
begin
  Result := FWebRequest.RemoteIP;
end;

function TDextWebBrokerRequest.GetCookies: IStringDictionary;
begin
  if FCookies = nil then
    FCookies := BuildCookies;
  Result := FCookies;
end;

function TDextWebBrokerRequest.GetFiles: IFormFileCollection;
begin
  Result := FFiles;
end;

{ TDextWebBrokerResponse }

constructor TDextWebBrokerResponse.Create(AWebResponse: TWebResponse);
begin
  inherited Create;
  FWebResponse := AWebResponse;
  FBuffer := TMemoryStream.Create;
  FStatusCode := 200;
  FContentType := 'text/plain; charset=utf-8';
  FCustomHeaders := TStringList.Create;
  FCustomHeaders.NameValueSeparator := '=';
end;

destructor TDextWebBrokerResponse.Destroy;
begin
  FBuffer.Free;
  FCustomHeaders.Free;
  inherited;
end;

procedure TDextWebBrokerResponse.FlushToWebResponse;
var
  I: Integer;
  Entry: TCookieEntry;
  CookieStr: string;
  Opts: TCookieOptions;
begin
  FWebResponse.StatusCode := FStatusCode;
  FWebResponse.ContentType := FContentType;

  // Custom headers
  for I := 0 to FCustomHeaders.Count - 1 do
    FWebResponse.SetCustomHeader(
      FCustomHeaders.Names[I],
      FCustomHeaders.ValueFromIndex[I]
    );

  // Cookies
  for Entry in FCookies do
  begin
    Opts := Entry.Options;
    CookieStr := Format('%s=%s', [Entry.Name, TNetEncoding.URL.Encode(Entry.Value)]);
    if Opts.Path <> '' then
      CookieStr := CookieStr + '; Path=' + Opts.Path;
    if Opts.Domain <> '' then
      CookieStr := CookieStr + '; Domain=' + Opts.Domain;
    if Opts.Expires <> 0 then
      CookieStr := CookieStr + '; Expires=' +
        FormatDateTime('ddd, dd mmm yyyy hh:nn:ss "GMT"', Opts.Expires, TFormatSettings.Invariant);
    if Opts.HttpOnly then
      CookieStr := CookieStr + '; HttpOnly';
    if Opts.Secure then
      CookieStr := CookieStr + '; Secure';
    if Opts.SameSite <> '' then
      CookieStr := CookieStr + '; SameSite=' + Opts.SameSite;
    FWebResponse.SetCustomHeader('Set-Cookie', CookieStr);
  end;

  // Body
  if FBuffer.Size > 0 then
  begin
    FBuffer.Position := 0;
    FWebResponse.ContentStream := FBuffer;
    FWebResponse.ContentLength := FBuffer.Size;
  end;
end;

function TDextWebBrokerResponse.Status(AValue: Integer): IHttpResponse;
begin
  FStatusCode := AValue;
  Result := Self;
end;

function TDextWebBrokerResponse.GetStatusCode: Integer;
begin
  Result := FStatusCode;
end;

function TDextWebBrokerResponse.GetContentType: string;
begin
  Result := FContentType;
end;

procedure TDextWebBrokerResponse.SetStatusCode(AValue: Integer);
begin
  FStatusCode := AValue;
end;

procedure TDextWebBrokerResponse.SetContentType(const AValue: string);
begin
  FContentType := AValue;
end;

procedure TDextWebBrokerResponse.SetContentLength(const AValue: Int64);
begin
  // Will be derived from buffer at flush time; ignore explicit set
end;

procedure TDextWebBrokerResponse.Flush;
begin
  // No-op for buffered WebBroker
end;

procedure TDextWebBrokerResponse.Write(const AContent: string);
var
  Bytes: TBytes;
begin
  Bytes := TEncoding.UTF8.GetBytes(AContent);
  if Length(Bytes) > 0 then
    FBuffer.WriteBuffer(Bytes[0], Length(Bytes));
end;

procedure TDextWebBrokerResponse.Write(const ABuffer: TBytes);
begin
  if Length(ABuffer) > 0 then
    FBuffer.WriteBuffer(ABuffer[0], Length(ABuffer));
end;

procedure TDextWebBrokerResponse.Write(const AStream: TStream);
begin
  FBuffer.CopyFrom(AStream, 0);
end;

procedure TDextWebBrokerResponse.Json(const AJson: string);
var
  Bytes: TBytes;
begin
  FContentType := 'application/json; charset=utf-8';
  Bytes := TEncoding.UTF8.GetBytes(AJson);
  if Length(Bytes) > 0 then
    FBuffer.WriteBuffer(Bytes[0], Length(Bytes));
end;

procedure TDextWebBrokerResponse.Json(const AValue: TValue);
begin
  Json(TDextJson.Serialize(AValue));
end;

function TDextWebBrokerResponse.GetHtmx: IHtmxResponse;
begin
  if FHtmx = nil then
    FHtmx := THtmxResponse.Create(Self);
  Result := FHtmx;
end;

function TDextWebBrokerResponse.GetHeaders: IStringDictionary;
var
  i: Integer;
begin
  if FHeaders = nil then
  begin
    FHeaders := TCollections.CreateStringDictionary(True);
    for i := 0 to FCustomHeaders.Count - 1 do
      FHeaders.AddOrSetValue(FCustomHeaders.Names[i], FCustomHeaders.ValueFromIndex[i]);
  end;
  Result := FHeaders;
end;

procedure TDextWebBrokerResponse.AddHeader(const AName, AValue: string);
begin
  FCustomHeaders.Add(AName + '=' + AValue);
  if FHeaders <> nil then
    FHeaders.AddOrSetValue(AName, AValue);
end;

procedure TDextWebBrokerResponse.AppendCookie(const AName, AValue: string;
  const AOptions: TCookieOptions);
var
  Entry: TCookieEntry;
  NewLen: Integer;
begin
  Entry.Name := AName;
  Entry.Value := AValue;
  Entry.Options := AOptions;
  NewLen := Length(FCookies) + 1;
  SetLength(FCookies, NewLen);
  FCookies[NewLen - 1] := Entry;
end;

procedure TDextWebBrokerResponse.AppendCookie(const AName, AValue: string);
begin
  AppendCookie(AName, AValue, TCookieOptions.Default);
end;

procedure TDextWebBrokerResponse.DeleteCookie(const AName: string);
var
  Opts: TCookieOptions;
begin
  Opts := TCookieOptions.Default;
  Opts.Expires := Now - 1;
  AppendCookie(AName, '', Opts);
end;

procedure TDextWebBrokerResponse.Redirect(const AUrl: string; APermanent: Boolean);
begin
  if APermanent then
    FStatusCode := 301
  else
    FStatusCode := 302;
  AddHeader('Location', AUrl);
end;

procedure TDextWebBrokerResponse.Unauthorized(const AMessage: string);
begin
  FStatusCode := 401;
  if AMessage <> '' then Write(AMessage);
end;

procedure TDextWebBrokerResponse.Forbidden(const AMessage: string);
begin
  FStatusCode := 403;
  if AMessage <> '' then Write(AMessage);
end;

procedure TDextWebBrokerResponse.BadRequest(const AMessage: string);
begin
  FStatusCode := 400;
  if AMessage <> '' then Write(AMessage);
end;

procedure TDextWebBrokerResponse.NotFound(const AMessage: string);
begin
  FStatusCode := 404;
  if AMessage <> '' then Write(AMessage);
end;

{ TDextWebBrokerContext }

constructor TDextWebBrokerContext.Create(const ARequest: IHttpRequest;
  const AResponse: IHttpResponse; const AServices: IServiceProvider);
begin
  inherited Create;
  FRequest := ARequest;
  FResponse := AResponse;
  FScope := AServices.CreateScope;
  FServices := FScope.ServiceProvider;
  FItems := TCollections.CreateDictionary<string, TValue>;
end;

destructor TDextWebBrokerContext.Destroy;
begin
  FItems := nil;
  FRequest := nil;
  FResponse := nil;
  FServices := nil;
  FScope := nil; // Disposes scoped services for this request
  inherited;
end;

function TDextWebBrokerContext.GetConnection: IDextServerConnection;
begin
  Result := nil;
end;

function TDextWebBrokerContext.GetRequest: IHttpRequest;
begin
  Result := FRequest;
end;

function TDextWebBrokerContext.GetResponse: IHttpResponse;
begin
  Result := FResponse;
end;

procedure TDextWebBrokerContext.SetResponse(const AValue: IHttpResponse);
begin
  FResponse := AValue;
end;

function TDextWebBrokerContext.GetServices: IServiceProvider;
begin
  Result := FServices;
end;

procedure TDextWebBrokerContext.SetServices(const AValue: IServiceProvider);
begin
  FServices := AValue;
end;

function TDextWebBrokerContext.GetUser: IClaimsPrincipal;
begin
  Result := FUser;
end;

procedure TDextWebBrokerContext.SetUser(const AValue: IClaimsPrincipal);
begin
  FUser := AValue;
end;

function TDextWebBrokerContext.GetItems: IDictionary<string, TValue>;
begin
  Result := FItems;
end;

procedure TDextWebBrokerContext.SetRouteParams(const AParams: TRouteValueDictionary);
begin
  if FRequest is TDextWebBrokerRequest then
    TDextWebBrokerRequest(FRequest).FRouteParams := AParams;
end;

function TDextWebBrokerContext.GetSession: IStreamableSession;
var
  LManager: IStreamableSessionManager;
  LId: string;
begin
  LId := FRequest.GetHeader('Dext-Session-Id');
  if LId = '' then
    Exit(nil);
    
  LManager := TDextServices.GetService<IStreamableSessionManager>(FServices);
  if LManager <> nil then
    Result := LManager.GetSession(LId)
  else
    Result := nil;
end;

{ TDextWebBrokerServer }

function TDextWebBrokerServer.GetPort: Integer;
begin
  Result := 0;
end;

procedure TDextWebBrokerServer.Run;
begin
  // No-op: WebBroker host handles the event loop
end;

procedure TDextWebBrokerServer.Start;
begin
  // No-op
end;

procedure TDextWebBrokerServer.Stop;
begin
  // No-op
end;

{ TDextWebBrokerApp }

class procedure TDextWebBrokerApp.Configure(Startup: IStartup);
var
  Factory: TServerFactory;
begin
  FApp := WebApplication;

  // Register a server factory that captures pipeline+services and returns a
  // no-op host. WebBroker/IIS owns the actual accept loop.
  Factory := function(Port: Integer; Pipeline: TRequestDelegate;
    Services: IServiceProvider): IWebHost
  begin
    FPipeline := Pipeline;
    FServiceProvider := Services;
    Result := TDextWebBrokerServer.Create;
  end;

  FApp.UseServerFactory(Factory);
  FApp.UseStartup(Startup);
  FApp.BuildServices;

  // Start the pipeline (runs hosted services, migrations, etc.)
  // Use port 0 - the factory ignores it.
  FApp.Start(0);
end;

class procedure TDextWebBrokerApp.HandleRequest(Req: TWebRequest; Resp: TWebResponse);
var
  DextReq: TDextWebBrokerRequest;
  DextResp: TDextWebBrokerResponse;
  Ctx: IHttpContext;
begin
  if not Assigned(FPipeline) then
  begin
    Resp.StatusCode := 503;
    Resp.Content := 'Dext pipeline not configured';
    Exit;
  end;

  // Create typed objects first so we can call FlushToWebResponse after the pipeline
  DextReq := TDextWebBrokerRequest.Create(Req);
  DextResp := TDextWebBrokerResponse.Create(Resp);
  Ctx := TDextWebBrokerContext.Create(DextReq, DextResp, FServiceProvider);
  try
    FPipeline(Ctx);
    DextResp.FlushToWebResponse;
  except
    on E: Exception do
    begin
      Resp.StatusCode := 500;
      Resp.Content := 'Internal Server Error: ' + E.Message;
    end;
  end;
  Ctx := nil; // Release scope and scoped services
end;

class procedure TDextWebBrokerApp.Shutdown;
begin
  if FApp <> nil then
  begin
    FApp.Stop;
    FApp := nil;
  end;
  FPipeline := nil;
  FServiceProvider := nil;
end;

{ TDextWebModule }

constructor TDextWebModule.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BeforeDispatch := WebModuleBeforeDispatch;
end;

procedure TDextWebModule.WebModuleBeforeDispatch(Sender: TObject;
  Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
begin
  TDextWebBrokerApp.HandleRequest(Request, Response);
  Handled := True;
end;

initialization

finalization
  TDextWebBrokerApp.Shutdown;

end.
