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
{  Created: 2026-06-17                                                      }
{                                                                           }
{  Dext native adapters for web host, contexts, request, and responses.     }
{                                                                           }
{***************************************************************************}
unit Dext.Server.Native;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Rtti,
  System.SyncObjs,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.Web.Interfaces,
  Dext.DI.Interfaces,
  Dext.Auth.Identity,
  Dext.Web.Results,
  Dext.Json,
  Dext.Server.Engine.Types,
  Dext.Server.Engine.Interfaces;

type
  /// <summary>
  ///   Native form file implementation.
  /// </summary>
  TDextNativeFormFile = class(TInterfacedObject, IFormFile)
  private
    FName: string;
    FFileName: string;
    FContentType: string;
    FStream: TStream;
  public
    /// <summary>Initializes a new instance of the native form file adapter.</summary>
    constructor Create(const AName, AFileName, AContentType: string; AStream: TStream);
    /// <summary>Destroys the instance and frees the underlying stream.</summary>
    destructor Destroy; override;
    /// <summary>Returns the form field name.</summary>
    function GetName: string;
    /// <summary>Returns the filename sent by the client.</summary>
    function GetFileName: string;
    /// <summary>Returns the Content-Type of the uploaded file.</summary>
    function GetContentType: string;
    /// <summary>Returns the length of the file in bytes.</summary>
    function GetLength: Int64;
    /// <summary>Returns the file content stream.</summary>
    function GetStream: TStream;
  end;

  /// <summary>
  ///   Dext native implementation of IHttpRequest.
  /// </summary>
  TDextNativeHttpRequest = class(TInterfacedObject, IHttpRequest)
  private
    FRawRequest: IDextRawRequest;
    FQuery: IStringDictionary;
    FBodyStream: TStream;
    FRouteParams: TRouteValueDictionary;
    FHeaders: IStringDictionary;
    FCookies: IStringDictionary;
    FFiles: IFormFileCollection;
    FRemoteIp: string;
    function ParseQueryString(const AQuery: string): IStringDictionary;
    function ParseHeaders: IStringDictionary;
  public
    /// <summary>Initializes a new instance of the native HTTP request adapter.</summary>
    constructor Create(const ARawRequest: IDextRawRequest; const ARemoteIp: string);
    /// <summary>Destroys the instance and frees internal cached dictionary structures.</summary>
    destructor Destroy; override;

    /// <summary>Gets the HTTP request verb/method.</summary>
    function GetMethod: string;
    /// <summary>Gets the request URL path.</summary>
    function GetPath: string;
    /// <summary>Gets the collection of parsed query parameters.</summary>
    function GetQuery: IStringDictionary;
    /// <summary>Gets the body data stream.</summary>
    function GetBody: TStream;
    /// <summary>Gets the route parameters collection.</summary>
    function GetRouteParams: TRouteValueDictionary;
    /// <summary>Gets the request headers collection.</summary>
    function GetHeaders: IStringDictionary;
    /// <summary>Gets the remote client IP address.</summary>
    function GetRemoteIpAddress: string;
    /// <summary>Gets a specific header value by case-insensitive name.</summary>
    function GetHeader(const AName: string): string;
    /// <summary>Gets a specific query parameter value by name.</summary>
    function GetQueryParam(const AName: string): string;
    /// <summary>Gets the parsed cookies collection.</summary>
    function GetCookies: IStringDictionary;
    /// <summary>Gets the parsed multi-part uploaded files collection.</summary>
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

  /// <summary>
  ///   Dext native implementation of IHttpResponse.
  /// </summary>
  TDextNativeHttpResponse = class(TInterfacedObject, IHttpResponse)
  private
    FRawResponse: IDextRawResponse;
    FHtmx: IHtmxResponse;
    FHeaders: IStringDictionary;
  public
    /// <summary>Initializes a new instance of the native HTTP response adapter.</summary>
    constructor Create(const ARawResponse: IDextRawResponse);
    /// <summary>Destroys the instance.</summary>
    destructor Destroy; override;

    /// <summary>Gets the HTTP status code.</summary>
    function GetStatusCode: Integer;
    /// <summary>Gets the response Content-Type header value.</summary>
    function GetContentType: string;
    /// <summary>Sets the HTTP status code fluently.</summary>
    function Status(AValue: Integer): IHttpResponse;
    /// <summary>Sets the HTTP status code.</summary>
    procedure SetStatusCode(AValue: Integer);
    /// <summary>Sets the response Content-Type header.</summary>
    procedure SetContentType(const AValue: string);
    /// <summary>Sets the response Content-Length header.</summary>
    procedure SetContentLength(const AValue: Int64);
    /// <summary>Flushes buffered response data to the underlying transport.</summary>
    procedure Flush;
    /// <summary>Writes a UTF-8 string to the response body.</summary>
    procedure Write(const AContent: string); overload;
    /// <summary>Writes raw bytes to the response body.</summary>
    procedure Write(const ABuffer: TBytes); overload;
    /// <summary>Writes a stream contents directly to the response body.</summary>
    procedure Write(const AStream: TStream); overload;
    /// <summary>Sends a JSON string directly as response.</summary>
    procedure Json(const AJson: string); overload;
    /// <summary>Serializes a TValue to JSON and sends it.</summary>
    procedure Json(const AValue: TValue); overload;
    /// <summary>Adds a header value to the response.</summary>
    procedure AddHeader(const AName, AValue: string);
    /// <summary>Appends a cookie with options to the response.</summary>
    procedure AppendCookie(const AName, AValue: string; const AOptions: TCookieOptions); overload;
    /// <summary>Appends a cookie with default options to the response.</summary>
    procedure AppendCookie(const AName, AValue: string); overload;
    /// <summary>Sets a cookie to expire immediately to delete it.</summary>
    procedure DeleteCookie(const AName: string);
    /// <summary>Sends a redirect status code (301/302) with Location header.</summary>
    procedure Redirect(const AUrl: string; APermanent: Boolean = False);
    /// <summary>Sets 401 Unauthorized status and optional message.</summary>
    procedure Unauthorized(const AMessage: string = '');
    /// <summary>Sets 403 Forbidden status and optional message.</summary>
    procedure Forbidden(const AMessage: string = '');
    /// <summary>Sets 400 Bad Request status and optional message.</summary>
    procedure BadRequest(const AMessage: string = '');
    /// <summary>Sets 404 Not Found status and optional message.</summary>
    procedure NotFound(const AMessage: string = '');
    /// <summary>Returns the fluent HTMX helper interface.</summary>
    function GetHtmx: IHtmxResponse;
    /// <summary>Returns the response headers collection.</summary>
    function GetHeaders: IStringDictionary;

    property StatusCode: Integer read GetStatusCode write SetStatusCode;
    property ContentType: string read GetContentType write SetContentType;
    property Htmx: IHtmxResponse read GetHtmx;
    property Headers: IStringDictionary read GetHeaders;
  end;

  /// <summary>
  ///   Dext native implementation of IHttpContext.
  /// </summary>
  TDextNativeHttpContext = class(TInterfacedObject, IHttpContext)
  private
    FConnection: IDextServerConnection;
    FRequest: IHttpRequest;
    FResponse: IHttpResponse;
    FScope: IServiceScope;
    FServices: IServiceProvider;
    FUser: IClaimsPrincipal;
    FItems: IDictionary<string, TValue>;
  public
    /// <summary>Initializes a new request context with the native connection/request/response.</summary>
    constructor Create(
      const AConnection: IDextServerConnection;
      const ARawRequest: IDextRawRequest;
      const ARawResponse: IDextRawResponse;
      const AServices: IServiceProvider
    );
    /// <summary>Destroys the context and releases the request scope.</summary>
    destructor Destroy; override;

    /// <summary>Sets the route parameters dictionary for the request.</summary>
    procedure SetRouteParams(const AParams: TRouteValueDictionary);
    /// <summary>Returns the HTTP connection interface.</summary>
    function GetConnection: IDextServerConnection;
    /// <summary>Returns the HTTP request interface.</summary>
    function GetRequest: IHttpRequest;
    /// <summary>Returns the HTTP response interface.</summary>
    function GetResponse: IHttpResponse;
    /// <summary>Sets the HTTP response interface.</summary>
    procedure SetResponse(const AValue: IHttpResponse);
    /// <summary>Returns the request scoped service provider.</summary>
    function GetServices: IServiceProvider;
    /// <summary>Sets the request scoped service provider.</summary>
    procedure SetServices(const AValue: IServiceProvider);
    /// <summary>Returns the authenticated user principal.</summary>
    function GetUser: IClaimsPrincipal;
    /// <summary>Sets the authenticated user principal.</summary>
    procedure SetUser(const AValue: IClaimsPrincipal);
    /// <summary>Returns the items/state dictionary for the current request.</summary>
    function GetItems: IDictionary<string, TValue>;
    /// <summary>Returns the active session interface, if configured.</summary>
    function GetSession: IStreamableSession;

    property Request: IHttpRequest read GetRequest;
    property Response: IHttpResponse read GetResponse write SetResponse;
    property Services: IServiceProvider read GetServices write SetServices;
    property User: IClaimsPrincipal read GetUser write SetUser;
    property Items: IDictionary<string, TValue> read GetItems;
  end;

  /// <summary>
  ///   IWebHost implementation that wraps the native platform server engines.
  /// </summary>
  TDextNativeWebServer = class(TInterfacedObject, IWebHost)
  private
    FPort: Integer;
    FEngine: IDextServerEngine;
    FPipeline: TRequestDelegate;
    FServices: IServiceProvider;
    FRunning: Boolean;
  public
    /// <summary>Initializes a new native web server instance.</summary>
    constructor Create(
      APort: Integer;
      const APipeline: TRequestDelegate;
      const AServices: IServiceProvider;
      const AOptions: TServerEngineOptions
    );
    /// <summary>Destroys the server instance and stops the engine.</summary>
    destructor Destroy; override;

    /// <summary>Gets the port number the server is listening on.</summary>
    function GetPort: Integer;
    /// <summary>Starts the server and blocks the main thread (for CLI/Service usage).</summary>
    procedure Run;
    /// <summary>Starts the server in background threads (non-blocking, for VCL/GUI/Sidecar).</summary>
    procedure Start;
    /// <summary>Stops the server gracefully.</summary>
    procedure Stop;

    property Port: Integer read GetPort;
  end;

  /// <summary>Helper method to perform URL decoding on paths and query strings.</summary>
  function UrlDecode(const AStr: string): string;

implementation

uses
  Dext.Logging.Global,
  Dext.Utils;

function UrlDecode(const AStr: string): string;
var
  I: Integer;
  Ch: Char;
  Code: Integer;
begin
  Result := '';
  I := 1;
  while I <= Length(AStr) do
  begin
    Ch := AStr[I];
    if Ch = '%' then
    begin
      if I + 2 <= Length(AStr) then
      begin
        if TryStrToInt('$' + Copy(AStr, I + 1, 2), Code) then
        begin
          Result := Result + Char(Code);
          Inc(I, 2);
        end
        else
          Result := Result + Ch;
      end
      else
        Result := Result + Ch;
    end
    else if Ch = '+' then
      Result := Result + ' '
    else
      Result := Result + Ch;
    Inc(I);
  end;
end;

{ TDextNativeFormFile }

constructor TDextNativeFormFile.Create(const AName, AFileName, AContentType: string; AStream: TStream);
begin
  inherited Create;
  FName := AName;
  FFileName := AFileName;
  FContentType := AContentType;
  FStream := AStream;
end;

destructor TDextNativeFormFile.Destroy;
begin
  FStream.Free;
  inherited;
end;

function TDextNativeFormFile.GetContentType: string; begin Result := FContentType; end;
function TDextNativeFormFile.GetFileName: string; begin Result := FFileName; end;
function TDextNativeFormFile.GetLength: Int64; begin Result := FStream.Size; end;
function TDextNativeFormFile.GetName: string; begin Result := FName; end;
function TDextNativeFormFile.GetStream: TStream; begin Result := FStream; end;

{ TDextNativeHttpRequest }

constructor TDextNativeHttpRequest.Create(const ARawRequest: IDextRawRequest; const ARemoteIp: string);
begin
  inherited Create;
  FRawRequest := ARawRequest;
  FRemoteIp := ARemoteIp;
  FRouteParams.Clear;
  FFiles := TFormFileCollection.Create(TCollections.CreateList<IFormFile>);
end;

destructor TDextNativeHttpRequest.Destroy;
begin
  FQuery := nil;
  FBodyStream := nil;
  FHeaders := nil;
  FCookies := nil;
  FFiles := nil;
  FRawRequest := nil;
  inherited;
end;

function TDextNativeHttpRequest.GetMethod: string; begin Result := FRawRequest.Method; end;
function TDextNativeHttpRequest.GetPath: string;
begin
  Result := FRawRequest.Path;
  if Result = '' then Result := '/';
end;

function TDextNativeHttpRequest.GetBody: TStream;
begin
  if FBodyStream = nil then
    FBodyStream := FRawRequest.BodyStream;
  Result := FBodyStream;
end;

function TDextNativeHttpRequest.GetHeader(const AName: string): string;
begin
  Result := FRawRequest.GetHeader(AName);
end;

function TDextNativeHttpRequest.GetHeaders: IStringDictionary;
begin
  if FHeaders = nil then
    FHeaders := ParseHeaders;
  Result := FHeaders;
end;

function TDextNativeHttpRequest.ParseHeaders: IStringDictionary;
var
  Dict: TDictionary<string, string>;
  Pair: TPair<string, string>;
begin
  Result := TCollections.CreateStringDictionary(True);
  Dict := TDictionary<string, string>.Create;
  try
    FRawRequest.PopulateHeaders(Dict);
    for Pair in Dict do
      Result.SetItem(Pair.Key, Pair.Value);
  finally
    Dict.Free;
  end;
end;

function TDextNativeHttpRequest.GetRemoteIpAddress: string;
begin
  Result := FRemoteIp;
end;

function TDextNativeHttpRequest.GetRouteParams: TRouteValueDictionary;
begin
  Result := FRouteParams;
end;

function TDextNativeHttpRequest.GetQuery: IStringDictionary;
begin
  if FQuery = nil then
    FQuery := ParseQueryString(FRawRequest.QueryString);
  Result := FQuery;
end;

function TDextNativeHttpRequest.GetQueryParam(const AName: string): string;
begin
  if not GetQuery.TryGetValue(AName, Result) then
    Result := '';
end;

function TDextNativeHttpRequest.ParseQueryString(const AQuery: string): IStringDictionary;
var
  P, EndP: PChar;
  Key, Value: string;
  Len: Integer;
  EqP, AmpP: PChar;
  CleanQuery: string;
begin
  Result := TCollections.CreateStringDictionary(True);
  CleanQuery := AQuery;
  if CleanQuery.StartsWith('?') then
    CleanQuery := CleanQuery.Substring(1);
    
  if CleanQuery = '' then Exit;
  
  P := PChar(CleanQuery);
  Len := Length(CleanQuery);
  EndP := P + Len;

  while P < EndP do
  begin
    EqP := StrScan(P, '=');
    AmpP := StrScan(P, '&');

    if (AmpP = nil) or (AmpP > EndP) then
      AmpP := EndP;

    if (EqP <> nil) and (EqP < AmpP) then
    begin
      SetString(Key, P, EqP - P);
      SetString(Value, EqP + 1, AmpP - (EqP + 1));
      Result.SetItem(UrlDecode(Key), UrlDecode(Value));
    end
    else
    begin
      SetString(Key, P, AmpP - P);
      if Key <> '' then
        Result.SetItem(UrlDecode(Key), '');
    end;

    P := AmpP + 1;
  end;
end;

function TDextNativeHttpRequest.GetCookies: IStringDictionary;
var
  CookieHeader: string;
  Pairs: TArray<string>;
  Pair: string;
  Parts: TArray<string>;
begin
  if FCookies = nil then
  begin
    FCookies := TCollections.CreateStringDictionary(True);
    CookieHeader := GetHeader('Cookie');
    if CookieHeader <> '' then
    begin
      Pairs := CookieHeader.Split([';']);
      for Pair in Pairs do
      begin
        Parts := Pair.Trim.Split(['='], 2);
        if Length(Parts) = 2 then
          FCookies.SetItem(Parts[0].Trim, UrlDecode(Parts[1].Trim))
        else if (Length(Parts) = 1) and (Parts[0] <> '') then
          FCookies.SetItem(Parts[0].Trim, '');
      end;
    end;
  end;
  Result := FCookies;
end;

function TDextNativeHttpRequest.GetFiles: IFormFileCollection;
begin
  Result := FFiles;
end;

{ TDextNativeHttpResponse }

constructor TDextNativeHttpResponse.Create(const ARawResponse: IDextRawResponse);
begin
  inherited Create;
  FRawResponse := ARawResponse;
end;

destructor TDextNativeHttpResponse.Destroy;
begin
  FHeaders := nil;
  FHtmx := nil;
  FRawResponse := nil;
  inherited;
end;

procedure TDextNativeHttpResponse.AddHeader(const AName, AValue: string);
begin
  FRawResponse.SetHeader(AName, AValue);
  if FHeaders <> nil then
    FHeaders.AddOrSetValue(AName, AValue);
end;

procedure TDextNativeHttpResponse.AppendCookie(const AName, AValue: string; const AOptions: TCookieOptions);
var
  CookieStr: string;
begin
  CookieStr := Format('%s=%s', [AName, AValue]);
  if AOptions.Path <> '' then
    CookieStr := CookieStr + '; Path=' + AOptions.Path;
  if AOptions.Domain <> '' then
    CookieStr := CookieStr + '; Domain=' + AOptions.Domain;
  if AOptions.Expires <> 0 then
    CookieStr := CookieStr + '; Expires=' + FormatDateTime('ddd, dd mmm yyyy hh:nn:ss "GMT"', AOptions.Expires, TFormatSettings.Invariant);
  if AOptions.HttpOnly then
    CookieStr := CookieStr + '; HttpOnly';
  if AOptions.Secure then
    CookieStr := CookieStr + '; Secure';
  if AOptions.SameSite <> '' then
    CookieStr := CookieStr + '; SameSite=' + AOptions.SameSite;

  AddHeader('Set-Cookie', CookieStr);
end;

procedure TDextNativeHttpResponse.AppendCookie(const AName, AValue: string);
begin
  AppendCookie(AName, AValue, TCookieOptions.Default);
end;

procedure TDextNativeHttpResponse.DeleteCookie(const AName: string);
var
  Opts: TCookieOptions;
begin
  Opts := TCookieOptions.Default;
  Opts.Expires := Now - 1;
  AppendCookie(AName, '', Opts);
end;

procedure TDextNativeHttpResponse.Json(const AJson: string);
begin
  SetContentType('application/json; charset=utf-8');
  Write(AJson);
end;

procedure TDextNativeHttpResponse.Json(const AValue: TValue);
begin
  Json(TDextJson.Serialize(AValue));
end;

procedure TDextNativeHttpResponse.Redirect(const AUrl: string; APermanent: Boolean);
begin
  if APermanent then
    SetStatusCode(301)
  else
    SetStatusCode(302);
  AddHeader('Location', AUrl);
end;

procedure TDextNativeHttpResponse.SetContentLength(const AValue: Int64);
begin
  AddHeader('Content-Length', AValue.ToString);
end;

procedure TDextNativeHttpResponse.SetContentType(const AValue: string);
begin
  AddHeader('Content-Type', AValue);
end;

procedure TDextNativeHttpResponse.SetStatusCode(AValue: Integer);
begin
  FRawResponse.SetStatus(AValue);
end;

function TDextNativeHttpResponse.Status(AValue: Integer): IHttpResponse;
begin
  SetStatusCode(AValue);
  Result := Self;
end;

procedure TDextNativeHttpResponse.Unauthorized(const AMessage: string);
begin
  SetStatusCode(401);
  if AMessage <> '' then Write(AMessage);
end;

procedure TDextNativeHttpResponse.Forbidden(const AMessage: string);
begin
  SetStatusCode(403);
  if AMessage <> '' then Write(AMessage);
end;

procedure TDextNativeHttpResponse.BadRequest(const AMessage: string);
begin
  SetStatusCode(400);
  if AMessage <> '' then Write(AMessage);
end;

procedure TDextNativeHttpResponse.NotFound(const AMessage: string);
begin
  SetStatusCode(404);
  if AMessage <> '' then Write(AMessage);
end;

procedure TDextNativeHttpResponse.Flush;
begin
  FRawResponse.Flush;
end;

procedure TDextNativeHttpResponse.Write(const AContent: string);
var
  Bytes: TBytes;
begin
  Bytes := TEncoding.UTF8.GetBytes(AContent);
  FRawResponse.Write(Bytes, 0, Length(Bytes));
end;

procedure TDextNativeHttpResponse.Write(const ABuffer: TBytes);
begin
  FRawResponse.Write(ABuffer, 0, Length(ABuffer));
end;

procedure TDextNativeHttpResponse.Write(const AStream: TStream);
var
  Buffer: TBytes;
  ReadBytes: Integer;
begin
  SetLength(Buffer, 32768);
  AStream.Position := 0;
  while True do
  begin
    ReadBytes := AStream.Read(Buffer[0], Length(Buffer));
    if ReadBytes <= 0 then Break;
    FRawResponse.Write(Buffer, 0, ReadBytes);
  end;
end;

function TDextNativeHttpResponse.GetContentType: string;
begin
  Result := GetHeaders.GetValue('Content-Type');
end;

function TDextNativeHttpResponse.GetHeaders: IStringDictionary;
begin
  if FHeaders = nil then
    FHeaders := TCollections.CreateStringDictionary(True);
  Result := FHeaders;
end;

function TDextNativeHttpResponse.GetHtmx: IHtmxResponse;
begin
  if FHtmx = nil then
    FHtmx := THtmxResponse.Create(Self);
  Result := FHtmx;
end;

function TDextNativeHttpResponse.GetStatusCode: Integer;
begin
  Result := 200; // Native engine status code tracking could be added if needed, default to 200
end;

{ TDextNativeHttpContext }

constructor TDextNativeHttpContext.Create(
  const AConnection: IDextServerConnection;
  const ARawRequest: IDextRawRequest;
  const ARawResponse: IDextRawResponse;
  const AServices: IServiceProvider
);
begin
  inherited Create;
  FConnection := AConnection;
  FServices := AServices;
  FScope := nil;
  if AServices <> nil then
  begin
    // Create scope per request
    FScope := AServices.CreateScope;
    FServices := FScope.ServiceProvider;
  end;
  FRequest := TDextNativeHttpRequest.Create(ARawRequest, AConnection.RemoteAddress);
  FResponse := TDextNativeHttpResponse.Create(ARawResponse);
  FItems := TCollections.CreateDictionary<string, TValue>;
end;

destructor TDextNativeHttpContext.Destroy;
begin
  FRequest := nil;
  FResponse := nil;
  FItems := nil;
  FScope := nil;
  FServices := nil;
  FConnection := nil;
  inherited;
end;

function TDextNativeHttpContext.GetConnection: IDextServerConnection; begin Result := FConnection; end;
function TDextNativeHttpContext.GetItems: IDictionary<string, TValue>; begin Result := FItems; end;
function TDextNativeHttpContext.GetRequest: IHttpRequest; begin Result := FRequest; end;
function TDextNativeHttpContext.GetResponse: IHttpResponse; begin Result := FResponse; end;
procedure TDextNativeHttpContext.SetResponse(const AValue: IHttpResponse); begin FResponse := AValue; end;
function TDextNativeHttpContext.GetServices: IServiceProvider; begin Result := FServices; end;
procedure TDextNativeHttpContext.SetServices(const AValue: IServiceProvider); begin FServices := AValue; end;
function TDextNativeHttpContext.GetUser: IClaimsPrincipal; begin Result := FUser; end;
procedure TDextNativeHttpContext.SetUser(const AValue: IClaimsPrincipal); begin FUser := AValue; end;
function TDextNativeHttpContext.GetSession: IStreamableSession; begin Result := nil; end;

procedure TDextNativeHttpContext.SetRouteParams(const AParams: TRouteValueDictionary);
begin
  TDextNativeHttpRequest(FRequest).FRouteParams := AParams;
end;

{ TDextNativeWebServer }

constructor TDextNativeWebServer.Create(
  APort: Integer;
  const APipeline: TRequestDelegate;
  const AServices: IServiceProvider;
  const AOptions: TServerEngineOptions
);
begin
  inherited Create;
  FPort := APort;
  FPipeline := APipeline;
  FServices := AServices;
  FRunning := False;
  
  // Decide best engine based on platform/options
  {$IFDEF MSWINDOWS}
  FEngine := CreateNativeEngine(AOptions);
  {$ELSE}
  FEngine := CreateSocketEngine(AOptions);
  {$ENDIF}
end;

destructor TDextNativeWebServer.Destroy;
begin
  Stop;
  FEngine := nil;
  FPipeline := nil;
  inherited;
end;

function TDextNativeWebServer.GetPort: Integer;
begin
  Result := FPort;
end;

procedure TDextNativeWebServer.Run;
begin
  Start;
  
  if FindCmdLineSwitch('no-wait', ['-', '/'], True) then Exit;
  
  SafeWriteLn('Press Ctrl+C to stop the server...');
  while FRunning do
    Sleep(100);
end;

procedure TDextNativeWebServer.Start;
begin
  if FRunning then Exit;

  {$IFDEF MSWINDOWS}
  FEngine.Bind('127.0.0.1', FPort);
  {$ELSE}
  FEngine.Bind('0.0.0.0', FPort);
  {$ENDIF}
  FEngine.SetOnRequest(
    procedure(const AConnection: IDextServerConnection; const ARequest: IDextRawRequest; const AResponse: IDextRawResponse)
    var
      Ctx: IHttpContext;
    begin
      try
        Ctx := TDextNativeHttpContext.Create(AConnection, ARequest, AResponse, FServices);
        FPipeline(Ctx);
      except
        on E: Exception do
        begin
          AResponse.SetStatus(500);
          AResponse.SetHeader('Content-Type', 'text/plain; charset=utf-8');
          AResponse.Write(TEncoding.UTF8.GetBytes('Internal Server Error: ' + E.Message), 0, Length(E.Message) + 23);
        end;
      end;
    end
  );

  FEngine.Start;
  FPort := FEngine.ListenPort;
  FRunning := True;

  SafeWriteLn(Format('Dext high-performance native server running on http://localhost:%d', [FPort]));
end;

procedure TDextNativeWebServer.Stop;
begin
  if not FRunning then Exit;
  FRunning := False;
  FEngine.Stop;
end;

end.
