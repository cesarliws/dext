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
{  Author:  Cesar Romero & Contributors                                     }
{                                                                           }
{***************************************************************************}
{                                                                           }
{  DCS (Delphi-Cross-Socket) server adapter.                                }
{                                                                           }
{  Requires the DCS library in the project search path:                     }
{    https://github.com/winddriver/Delphi-Cross-Socket                      }
{                                                                           }
{  Usage:                                                                   }
{    App := WebApplication;                                                 }
{    App.UseServerFactory(TDextDCSServer.Factory);                          }
{    App.UseStartup(TMyStartup.Create);                                     }
{    App.Run(9000);                                                         }
{                                                                           }
{***************************************************************************}
unit Dext.Web.DCS;
{$I Dext.inc}

interface

{$IFDEF DEXT_ENABLE_DCS}
{$MESSAGE WARN 'You are compiling with DEXT_ENABLE_DCS. The Delphi-Cross-Socket library is licensed under LGPL-3.0. Statically linking this in closed-source commercial applications may violate terms unless distributed dynamically (DLL/BPL) or source/DCUs are provided.'}

uses
  System.Classes,
  System.SysUtils,
  System.Rtti,
  System.DateUtils,
  Net.CrossSocket.Base,
  Net.CrossHttpServer,
  Net.CrossHttpParams,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.Web.Interfaces,
  Dext.DI.Interfaces,
  Dext.Configuration.Interfaces,
  Dext.Auth.Identity,
  Dext.Web.Results,
  Dext.Json,
  Dext.Server.Engine.Interfaces;
{$ENDIF DEXT_ENABLE_DCS}

{$IFDEF DEXT_ENABLE_DCS}
type
  // -------------------------------------------------------------------------
  // TDextDCSFormFile - IFormFile backed by a DCS TFormField
  // -------------------------------------------------------------------------
  /// <summary>
  ///   Implementation of <see cref="IFormFile"/> for the DCS adapter.
  /// </summary>
  TDextDCSFormFile = class(TInterfacedObject, IFormFile)
  private
    FName: string;
    FFileName: string;
    FContentType: string;
    FStream: TBytesStream;
  public
    constructor Create(AField: TFormField);
    destructor Destroy; override;
    function GetFileName: string;
    function GetName: string;
    function GetContentType: string;
    function GetLength: Int64;
    function GetStream: TStream;
    property FileName: string read GetFileName;
    property Name: string read GetName;
    property ContentType: string read GetContentType;
    property Length: Int64 read GetLength;
    property Stream: TStream read GetStream;
  end;

  // -------------------------------------------------------------------------
  // TDextDCSRequest - IHttpRequest backed by ICrossHttpRequest
  // -------------------------------------------------------------------------
  /// <summary>
  ///   Implementation of <see cref="IHttpRequest"/> for the DCS (CrossSockets) server.
  /// </summary>
  TDextDCSRequest = class(TInterfacedObject, IHttpRequest)
  private
    FRequest: ICrossHttpRequest;
    FQuery: IStringDictionary;
    FBody: TStream;
    FHeaders: IStringDictionary;
    FCookies: IStringDictionary;
    FRouteParams: TRouteValueDictionary;
    FFiles: IFormFileCollection;
    procedure BuildFiles;
  public
    constructor Create(ARequest: ICrossHttpRequest);
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

  TDCSCookieEntry = record
    Name: string;
    Value: string;
    Options: TCookieOptions;
  end;

  // -------------------------------------------------------------------------
  // TDextDCSResponse - IHttpResponse backed by ICrossHttpResponse (buffered)
  // -------------------------------------------------------------------------
  /// <summary>
  ///   Implementation of <see cref="IHttpResponse"/> for the DCS (CrossSockets) server.
  ///   Uses an internal buffer to optimize data transmission.
  /// </summary>
  TDextDCSResponse = class(TInterfacedObject, IHttpResponse)
  private
    FResponse: ICrossHttpResponse;
    FBuffer: TMemoryStream;
    FStatusCode: Integer;
    FContentType: string;
    FCustomHeaders: TStringList;
    FCookies: array of TDCSCookieEntry;
    FHtmx: IHtmxResponse;
    FHeaders: IStringDictionary;
  public
    constructor Create(AResponse: ICrossHttpResponse);
    destructor Destroy; override;

    function GetHtmx: IHtmxResponse;
    function GetHeaders: IStringDictionary;

    /// <summary>
    ///   Writes buffered response data to the underlying ICrossHttpResponse.
    ///   Must be called exactly once after the pipeline completes.
    /// </summary>
    procedure FlushToResponse;

    function Status(AValue: Integer): IHttpResponse;
    function GetStatusCode: Integer;
    function GetContentType: string;
    procedure SetStatusCode(AValue: Integer);
    procedure SetContentType(const AValue: string);
    procedure SetContentLength(const AValue: Int64);
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
    procedure Flush;
    property StatusCode: Integer read GetStatusCode write SetStatusCode;
    property ContentType: string read GetContentType write SetContentType;
  end;

  // -------------------------------------------------------------------------
  // TDextDCSContext - IHttpContext for a single DCS request
  // -------------------------------------------------------------------------
  /// <summary>
  ///   HTTP context specific to the DCS adapter.
  /// </summary>
  TDextDCSContext = class(TInterfacedObject, IHttpContext)
  private
    FRequest: IHttpRequest;
    FResponse: IHttpResponse;
    FScope: IServiceScope;
    FServices: IServiceProvider;
    FUser: IClaimsPrincipal;
    FItems: IDictionary<string, TValue>;
  public
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
    property Request: IHttpRequest read GetRequest;
    property Response: IHttpResponse read GetResponse write SetResponse;
    property Services: IServiceProvider read GetServices write SetServices;
    property User: IClaimsPrincipal read GetUser write SetUser;
    property Items: IDictionary<string, TValue> read GetItems;
  end;

  // -------------------------------------------------------------------------
  // TDextDCSServer - IWebHost backed by ICrossHttpServer (DCS)
  // -------------------------------------------------------------------------
  /// <summary>
  ///   Web Server based on the DCS (Delphi-Cross-Socket) library.
  ///   Designed for high performance and I/O scalability.
  /// </summary>
  TDextDCSServer = class(TInterfacedObject, IWebHost)
  private
    FHttpServer: ICrossHttpServer;
    FPipeline: TRequestDelegate;
    FServices: IServiceProvider;
    FPort: Integer;
    FUseSsl: Boolean;
    FRunning: Boolean;
    procedure HandleDCSRequest(ARequest: ICrossHttpRequest;
      AResponse: ICrossHttpResponse; var AHandled: Boolean);
    procedure HandleDCSRoute(const ARequest: ICrossHttpRequest;
      const AResponse: ICrossHttpResponse; var AHandled: Boolean);
  public
    constructor Create(APort: Integer; APipeline: TRequestDelegate;
      const AServices: IServiceProvider);
    destructor Destroy; override;

    function GetPort: Integer;
    procedure Run;
    procedure Start;
    procedure Stop;

    /// <summary>
    ///   Convenience factory for use with IWebApplication.UseServerFactory.
    /// </summary>
    class function Factory: TServerFactory;
  end;

{$ENDIF DEXT_ENABLE_DCS}

implementation

{$IFDEF DEXT_ENABLE_DCS}
uses
  Dext.Utils,
  Dext.Hosting.ApplicationLifetime;

{ TDextDCSFormFile }

constructor TDextDCSFormFile.Create(AField: TFormField);
var
  Bytes: TBytes;
begin
  inherited Create;
  FName := AField.Name;
  FFileName := AField.FileName;
  FContentType := AField.ContentType;
  Bytes := AField.AsBytes;
  FStream := TBytesStream.Create(Bytes);
  FStream.Position := 0;
end;

destructor TDextDCSFormFile.Destroy;
begin
  FStream.Free;
  inherited;
end;

function TDextDCSFormFile.GetFileName: string;
begin
  Result := FFileName;
end;

function TDextDCSFormFile.GetName: string;
begin
  Result := FName;
end;

function TDextDCSFormFile.GetContentType: string;
begin
  Result := FContentType;
end;

function TDextDCSFormFile.GetLength: Int64;
begin
  Result := FStream.Size;
end;

function TDextDCSFormFile.GetStream: TStream;
begin
  FStream.Position := 0;
  Result := FStream;
end;

{ TDextDCSRequest }

constructor TDextDCSRequest.Create(ARequest: ICrossHttpRequest);
begin
  inherited Create;
  FRequest := ARequest;
  FRouteParams.Clear;
  FFiles := TFormFileCollection.Create(TCollections.CreateList<IFormFile>);
end;

destructor TDextDCSRequest.Destroy;
begin
  FBody.Free;
  FRouteParams.Clear;
  FHeaders := nil;
  FCookies := nil;
  FFiles := nil;
  inherited;
end;

procedure TDextDCSRequest.BuildFiles;
var
  I: Integer;
  MultiPart: THttpMultiPartFormData;
  Field: TFormField;
begin
  if FRequest.BodyType = btMultiPart then
  begin
    MultiPart := FRequest.Body as THttpMultiPartFormData;
    for I := 0 to MultiPart.Count - 1 do
    begin
      Field := MultiPart.Items[I];
      if Field.FileName <> '' then // only actual file uploads
        FFiles.Add(TDextDCSFormFile.Create(Field));
    end;
  end;
end;

function TDextDCSRequest.GetMethod: string;
begin
  Result := FRequest.Method;
end;

function TDextDCSRequest.GetPath: string;
begin
  Result := FRequest.Path;
  if Result = '' then
    Result := '/';
end;

function TDextDCSRequest.GetQuery: IStringDictionary;
var
  I: Integer;
  Item: TNameValue;
begin
  if FQuery = nil then
  begin
    FQuery := TCollections.CreateStringDictionary(True);
    for I := 0 to FRequest.Query.Count - 1 do
    begin
      Item := FRequest.Query.Items[I];
      if Item.Name <> '' then
        FQuery.AddOrSetValue(Item.Name, Item.Value);
    end;
  end;
  Result := FQuery;
end;

function TDextDCSRequest.GetQueryParam(const AName: string): string;
begin
  if not GetQuery.TryGetValue(AName, Result) then
    Result := '';
end;

function TDextDCSRequest.GetBody: TStream;
var
  Bytes: TBytes;
  Params: THttpUrlParams;
  Encoded: string;
  EncodedBytes: TBytes;
begin
  if FBody = nil then
  begin
    case FRequest.BodyType of
      btBinary:
        begin
          Bytes := TBytesStream(FRequest.Body).Bytes;
          FBody := TBytesStream.Create(Bytes);
          FBody.Position := 0;
        end;
      btUrlEncoded:
        begin
          Params := FRequest.Body as THttpUrlParams;
          Encoded := Params.Encode;
          FBody := TMemoryStream.Create;
          EncodedBytes := TEncoding.UTF8.GetBytes(Encoded);
          if Length(EncodedBytes) > 0 then
            FBody.WriteBuffer(EncodedBytes[0], Length(EncodedBytes));
          FBody.Position := 0;
        end;
      btMultiPart:
        begin
          // For multipart, body is accessed via Files; return empty stream here
          FBody := TMemoryStream.Create;
        end;
    else
      // btNone or unknown
      FBody := TMemoryStream.Create;
    end;
  end;
  Result := FBody;
end;

function TDextDCSRequest.GetRouteParams: TRouteValueDictionary;
begin
  Result := FRouteParams;
end;

function TDextDCSRequest.GetHeaders: IStringDictionary;
var
  I: Integer;
  Item: TNameValue;
begin
  if FHeaders = nil then
  begin
    FHeaders := TCollections.CreateStringDictionary(True);
    for I := 0 to FRequest.Header.Count - 1 do
    begin
      Item := FRequest.Header.Items[I];
      if Item.Name <> '' then
        FHeaders.AddOrSetValue(Item.Name, Item.Value);
    end;
  end;
  Result := FHeaders;
end;

function TDextDCSRequest.GetHeader(const AName: string): string;
begin
  FRequest.Header.GetParamValue(AName, Result);
end;

function TDextDCSRequest.GetRemoteIpAddress: string;
begin
  Result := FRequest.Connection.PeerAddr;
end;

function TDextDCSRequest.GetCookies: IStringDictionary;
var
  I: Integer;
  Item: TNameValue;
begin
  if FCookies = nil then
  begin
    FCookies := TCollections.CreateStringDictionary(True);
    for I := 0 to FRequest.Cookies.Count - 1 do
    begin
      Item := FRequest.Cookies.Items[I];
      if Item.Name <> '' then
        FCookies.AddOrSetValue(Item.Name, Item.Value);
    end;
  end;
  Result := FCookies;
end;

function TDextDCSRequest.GetFiles: IFormFileCollection;
begin
  if FFiles.Count = 0 then
    BuildFiles;
  Result := FFiles;
end;

{ TDextDCSResponse }

constructor TDextDCSResponse.Create(AResponse: ICrossHttpResponse);
begin
  inherited Create;
  FResponse := AResponse;
  FBuffer := TMemoryStream.Create;
  FStatusCode := 200;
  FContentType := 'text/plain; charset=utf-8';
  FCustomHeaders := TStringList.Create;
  FCustomHeaders.NameValueSeparator := '=';
end;

destructor TDextDCSResponse.Destroy;
begin
  FBuffer.Free;
  FCustomHeaders.Free;
  inherited;
end;

procedure TDextDCSResponse.FlushToResponse;
var
  I: Integer;
  Entry: TDCSCookieEntry;
  Bytes: TBytes;
  MaxAgeSecs: Integer;
begin
  FResponse.StatusCode := FStatusCode;
  FResponse.ContentType := FContentType;

  // Custom headers
  for I := 0 to FCustomHeaders.Count - 1 do
    FResponse.Header.Add(
      FCustomHeaders.Names[I],
      FCustomHeaders.ValueFromIndex[I]
    );

  // Cookies - convert TCookieOptions to DCS MaxAge (seconds from now)
  for Entry in FCookies do
  begin
    if Entry.Options.Expires = 0 then
      MaxAgeSecs := 0 // session cookie
    else
    begin
      MaxAgeSecs := Round((Entry.Options.Expires - Now) * SecsPerDay);
      if MaxAgeSecs < 0 then
        MaxAgeSecs := -1; // signal browser to delete the cookie
    end;
    FResponse.Cookies.AddOrSet(
      Entry.Name,
      Entry.Value,
      MaxAgeSecs,
      Entry.Options.Path,
      Entry.Options.Domain,
      Entry.Options.HttpOnly,
      Entry.Options.Secure
    );
  end;

  // Body - copy memory stream bytes into a TBytes and send
  if FBuffer.Size > 0 then
  begin
    SetLength(Bytes, FBuffer.Size);
    Move(FBuffer.Memory^, Bytes[0], FBuffer.Size);
    FResponse.Send(Bytes);
  end
  else
    FResponse.SendStatus(FStatusCode);
end;

function TDextDCSResponse.Status(AValue: Integer): IHttpResponse;
begin
  FStatusCode := AValue;
  Result := Self;
end;

function TDextDCSResponse.GetStatusCode: Integer;
begin
  Result := FStatusCode;
end;

function TDextDCSResponse.GetContentType: string;
begin
  Result := FContentType;
end;

procedure TDextDCSResponse.SetStatusCode(AValue: Integer);
begin
  FStatusCode := AValue;
end;

procedure TDextDCSResponse.SetContentType(const AValue: string);
begin
  FContentType := AValue;
end;

procedure TDextDCSResponse.SetContentLength(const AValue: Int64);
begin
  // Derived from buffer size at flush time
end;

procedure TDextDCSResponse.Write(const AContent: string);
var
  Bytes: TBytes;
begin
  Bytes := TEncoding.UTF8.GetBytes(AContent);
  if Length(Bytes) > 0 then
    FBuffer.WriteBuffer(Bytes[0], Length(Bytes));
end;

procedure TDextDCSResponse.Write(const ABuffer: TBytes);
begin
  if Length(ABuffer) > 0 then
    FBuffer.WriteBuffer(ABuffer[0], Length(ABuffer));
end;

procedure TDextDCSResponse.Write(const AStream: TStream);
begin
  FBuffer.CopyFrom(AStream, 0);
end;

procedure TDextDCSResponse.Json(const AJson: string);
var
  Bytes: TBytes;
begin
  FContentType := 'application/json; charset=utf-8';
  Bytes := TEncoding.UTF8.GetBytes(AJson);
  if Length(Bytes) > 0 then
    FBuffer.WriteBuffer(Bytes[0], Length(Bytes));
end;

procedure TDextDCSResponse.Json(const AValue: TValue);
begin
  Json(TDextJson.Serialize(AValue));
end;

function TDextDCSResponse.GetHtmx: IHtmxResponse;
begin
  if FHtmx = nil then
    FHtmx := THtmxResponse.Create(Self);
  Result := FHtmx;
end;

function TDextDCSResponse.GetHeaders: IStringDictionary;
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

procedure TDextDCSResponse.AddHeader(const AName, AValue: string);
begin
  FCustomHeaders.Add(AName + '=' + AValue);
  if FHeaders <> nil then
    FHeaders.AddOrSetValue(AName, AValue);
end;

procedure TDextDCSResponse.AppendCookie(const AName, AValue: string;
  const AOptions: TCookieOptions);
var
  Entry: TDCSCookieEntry;
  NewLen: Integer;
begin
  Entry.Name := AName;
  Entry.Value := AValue;
  Entry.Options := AOptions;
  NewLen := Length(FCookies) + 1;
  SetLength(FCookies, NewLen);
  FCookies[NewLen - 1] := Entry;
end;

procedure TDextDCSResponse.AppendCookie(const AName, AValue: string);
begin
  AppendCookie(AName, AValue, TCookieOptions.Default);
end;

procedure TDextDCSResponse.DeleteCookie(const AName: string);
var
  Opts: TCookieOptions;
begin
  Opts := TCookieOptions.Default;
  Opts.Expires := Now - 1; // yesterday → MaxAge < 0 → browser deletes
  AppendCookie(AName, '', Opts);
end;

procedure TDextDCSResponse.Redirect(const AUrl: string; APermanent: Boolean);
begin
  if APermanent then
    FStatusCode := 301
  else
    FStatusCode := 302;
  AddHeader('Location', AUrl);
end;

procedure TDextDCSResponse.Unauthorized(const AMessage: string);
begin
  FStatusCode := 401;
  if AMessage <> '' then Write(AMessage);
end;

procedure TDextDCSResponse.Forbidden(const AMessage: string);
begin
  FStatusCode := 403;
  if AMessage <> '' then Write(AMessage);
end;

procedure TDextDCSResponse.BadRequest(const AMessage: string);
begin
  FStatusCode := 400;
  if AMessage <> '' then Write(AMessage);
end;

procedure TDextDCSResponse.NotFound(const AMessage: string);
begin
  FStatusCode := 404;
  if AMessage <> '' then Write(AMessage);
end;

procedure TDextDCSResponse.Flush;
begin
  // No-op for DCS adapter
end;

{ TDextDCSContext }

constructor TDextDCSContext.Create(const ARequest: IHttpRequest;
  const AResponse: IHttpResponse; const AServices: IServiceProvider);
begin
  inherited Create;
  FRequest := ARequest;
  FResponse := AResponse;
  FScope := AServices.CreateScope;
  FServices := FScope.ServiceProvider;
  FItems := TCollections.CreateDictionary<string, TValue>;
end;

destructor TDextDCSContext.Destroy;
begin
  FItems := nil;
  FRequest := nil;
  FResponse := nil;
  FServices := nil;
  FScope := nil; // Disposes scoped services for this request
  inherited;
end;

function TDextDCSContext.GetRequest: IHttpRequest;
begin
  Result := FRequest;
end;

function TDextDCSContext.GetResponse: IHttpResponse;
begin
  Result := FResponse;
end;

procedure TDextDCSContext.SetResponse(const AValue: IHttpResponse);
begin
  FResponse := AValue;
end;

function TDextDCSContext.GetServices: IServiceProvider;
begin
  Result := FServices;
end;

procedure TDextDCSContext.SetServices(const AValue: IServiceProvider);
begin
  FServices := AValue;
end;

function TDextDCSContext.GetUser: IClaimsPrincipal;
begin
  Result := FUser;
end;

procedure TDextDCSContext.SetUser(const AValue: IClaimsPrincipal);
begin
  FUser := AValue;
end;

function TDextDCSContext.GetConnection: IDextServerConnection;
begin
  Result := nil;
end;

function TDextDCSContext.GetItems: IDictionary<string, TValue>;
begin
  Result := FItems;
end;

{ TDextDCSServer }

constructor TDextDCSServer.Create(APort: Integer; APipeline: TRequestDelegate;
  const AServices: IServiceProvider);
var
  ConfigIntf: IInterface;
  Config: IConfiguration;
  ServerSection: IConfigurationSection;
begin
  inherited Create;
  FPort := APort;
  FPipeline := APipeline;
  FServices := AServices;
  FRunning := False;
  FUseSsl := False;

  if FServices <> nil then
  begin
    ConfigIntf := FServices.GetServiceAsInterface(
      TServiceType.FromInterface(TypeInfo(IConfiguration)));
    if ConfigIntf <> nil then
    begin
      Config := ConfigIntf as IConfiguration;
      ServerSection := Config.GetSection('Server');
      if ServerSection <> nil then
        FUseSsl := SameText(ServerSection['UseHttps'], 'true');
    end;
  end;

  // 0 = let DCS choose the optimal number of I/O threads (CPU count)
  FHttpServer := TCrossHttpServer.Create(0, FUseSsl);
end;

destructor TDextDCSServer.Destroy;
begin
  Stop;
  FHttpServer := nil;
  FPipeline := nil;
  inherited;
end;

procedure TDextDCSServer.HandleDCSRequest(ARequest: ICrossHttpRequest;
  AResponse: ICrossHttpResponse; var AHandled: Boolean);
var
  DextReq: TDextDCSRequest;
  DextResp: TDextDCSResponse;
  Ctx: IHttpContext;
begin
  AHandled := True;
  DextReq := TDextDCSRequest.Create(ARequest);
  DextResp := TDextDCSResponse.Create(AResponse);
  Ctx := TDextDCSContext.Create(DextReq, DextResp, FServices);
  try
    FPipeline(Ctx);
    DextResp.FlushToResponse;
  except
    on E: Exception do
    begin
      AResponse.StatusCode := 500;
      AResponse.ContentType := 'text/plain; charset=utf-8';
      AResponse.Send('Internal Server Error: ' + E.Message);
    end;
  end;
  Ctx := nil; // Release scope and scoped services
end;

procedure TDextDCSServer.HandleDCSRoute(const ARequest: ICrossHttpRequest;
  const AResponse: ICrossHttpResponse; var AHandled: Boolean);
begin
  HandleDCSRequest(ARequest, AResponse, AHandled);
end;

function TDextDCSServer.GetPort: Integer;
begin
  Result := FPort;
end;

procedure TDextDCSServer.Start;
begin
  if FHttpServer.Active then Exit;

  FHttpServer.Addr := IPv4v6_ALL;
  FHttpServer.Port := FPort;
  FHttpServer.Compressible := True;

  FHttpServer.All('*', HandleDCSRoute);

  FHttpServer.Start;
  FRunning := True;

  // Capture actual port if dynamic port (0) was requested
  if (FPort = 0) then
    FPort := FHttpServer.Port;

  if FUseSsl then
    SafeWriteLn(Format('Dext/DCS server running on https://localhost:%d', [FPort]))
  else
    SafeWriteLn(Format('Dext/DCS server running on http://localhost:%d', [FPort]));
end;

procedure TDextDCSServer.Run;
var
  Lifetime: IHostApplicationLifetime;
  LifetimeIntf: IInterface;
begin
  Start;

  if FindCmdLineSwitch('no-wait', ['-', '/'], True) then
  begin
    SafeWriteLn('Automated test mode: Server started. Exiting run loop.');
    Exit;
  end;

  SafeWriteLn('Press Ctrl+C to stop the server...');

  // Resolve application lifetime for graceful shutdown support
  Lifetime := nil;
  LifetimeIntf := FServices.GetServiceAsInterface(
    TServiceType.FromInterface(TypeInfo(IHostApplicationLifetime)));
  if LifetimeIntf <> nil then
    Lifetime := LifetimeIntf as IHostApplicationLifetime;

  FRunning := True;
  while FRunning and FHttpServer.Active do
  begin
    Sleep(100);
    if (Lifetime <> nil) and
       Lifetime.ApplicationStopping.IsCancellationRequested then
      FRunning := False;
  end;

  if FHttpServer.Active then
    Stop;
end;

procedure TDextDCSServer.Stop;
begin
  FRunning := False;
  if FHttpServer <> nil then
  begin
    try
      FHttpServer.Stop;
    except
      // Silence exceptions during shutdown
    end;
  end;
end;

class function TDextDCSServer.Factory: TServerFactory;
begin
  Result :=
    function(Port: Integer; Pipeline: TRequestDelegate;
      Services: IServiceProvider): IWebHost
    begin
      Result := TDextDCSServer.Create(Port, Pipeline, Services);
    end;
end;

{$ENDIF DEXT_ENABLE_DCS}

end.
