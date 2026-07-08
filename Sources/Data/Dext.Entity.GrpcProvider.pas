{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2026 Cesar Romero & Dext Contributors             }
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
{  Author:  Cesar Romero & Dext Contributors                                }
{  Created: 2026-07-07                                                      }
{                                                                           }
{  Description:                                                             }
{    gRPC client and data provider bridge for TEntityDataSet.               }
{                                                                           }
{***************************************************************************}
unit Dext.Entity.GrpcProvider;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Rtti,
  System.TypInfo,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.Web.Interfaces,
  Dext.Web.Grpc.Server,
  Dext.Grpc.Codec,
  Dext.Serialization.Protobuf,
  Dext.Grpc.Attributes,
  Dext.DI.Interfaces,
  Dext.Server.Engine.Interfaces,
  Dext.Auth.Identity;

type
  IEntityDataProvider<T: class, constructor> = interface
    ['{789A5F12-3D2F-4A9B-8E7C-901D2E3F4A5B}']
    function FetchAll(const AQuery: string): TList<T>;
    procedure ApplyChanges(const AList: TList<T>);
  end;

  /// <summary>
  ///   gRPC Client to invoke remote gRPC methods.
  ///   Supports both real transport (stubbed) and direct in-process dispatching.
  /// </summary>
  TGrpcClient = class
  private
    FHost: string;
    FPort: Integer;
    FDispatcher: TDextGrpcDispatcher;
  public
    constructor Create(const AHost: string; APort: Integer); overload;
    constructor Create(ADispatcher: TDextGrpcDispatcher); overload;

    procedure CallMethod(const AServiceName, AMethodName: string;
      ARequest, AResponse: TObject);
  end;

  TGenericQueryRequest = class
  private
    FQuery: string;
  public
    [ProtoMember(1)]
    property Query: string read FQuery write FQuery;
  end;

  TGenericListResponse<TItem: class, constructor> = class
  private
    FItems: TList<TItem>;
  public
    constructor Create;
    destructor Destroy; override;
    property Items: TList<TItem> read FItems;
  end;

  /// <summary>
  ///   TEntityDataSet provider that syncs entities over gRPC.
  /// </summary>
  TEntitygRpcProvider<T: class, constructor> = class(
    TInterfacedObject, IEntityDataProvider<T>)
  private
    FClient: TGrpcClient;
    FServiceName: string;
  public
    constructor Create(AClient: TGrpcClient; const AServiceName: string);
    function FetchAll(const AQuery: string): TList<T>;
    procedure ApplyChanges(const AList: TList<T>);
  end;

implementation

type
  TMockHttpRequest = class(TInterfacedObject, IHttpRequest)
  private
    FPath: string;
    FBody: TStream;
    FHeaders: IStringDictionary;
  public
    constructor Create(const APath: string; ABody: TBytes);
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
    FBody: TMemoryStream;
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
    procedure AppendCookie(const AName, AValue: string;
      const AOptions: TCookieOptions); overload;
    procedure AppendCookie(const AName, AValue: string); overload;
    procedure DeleteCookie(const AName: string);
    procedure Redirect(const AUrl: string; APermanent: Boolean = False);
    procedure Unauthorized(const AMessage: string = '');
    procedure Forbidden(const AMessage: string = '');
    procedure BadRequest(const AMessage: string = '');
    procedure NotFound(const AMessage: string = '');
    function GetHtmx: IHtmxResponse;
    function GetHeaders: IStringDictionary;
    property Body: TMemoryStream read FBody;
    property Headers: IStringDictionary read FHeaders;
  end;

  TMockHttpContext = class(TInterfacedObject, IHttpContext)
  private
    FRequest: IHttpRequest;
    FResponse: IHttpResponse;
    FItems: IDictionary<string, TValue>;
  public
    constructor Create(AReq: IHttpRequest; ARes: IHttpResponse);
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
    function GetEndpointMetadata: TEndpointMetadata;
    procedure SetEndpointMetadata(const AMetadata: TEndpointMetadata);
    procedure SetRouteParams(const AParams: TRouteValueDictionary);
  end;

{ TMockHttpRequest }

constructor TMockHttpRequest.Create(const APath: string; ABody: TBytes);
begin
  FPath := APath;
  FBody := TBytesStream.Create(ABody);
  FHeaders := TCollections.CreateStringDictionary(True);
  FHeaders.Add('content-type', 'application/grpc');
end;

destructor TMockHttpRequest.Destroy;
begin
  FBody.Free;
  inherited;
end;

function TMockHttpRequest.GetMethod: string; begin Result := 'POST'; end;
function TMockHttpRequest.GetPath: string; begin Result := FPath; end;
function TMockHttpRequest.GetQuery: IStringDictionary; begin Result := nil; end;
function TMockHttpRequest.GetBody: TStream; begin Result := FBody; end;
function TMockHttpRequest.GetRouteParams: TRouteValueDictionary;
var
  Dict: TRouteValueDictionary;
begin
  Dict.Clear;
  Result := Dict;
end;
function TMockHttpRequest.GetHeaders: IStringDictionary; begin Result := FHeaders; end;
function TMockHttpRequest.GetRemoteIpAddress: string; begin Result := '127.0.0.1'; end;
function TMockHttpRequest.GetHeader(const AName: string): string;
begin
  if not FHeaders.TryGetValue(AName, Result) then Result := '';
end;
function TMockHttpRequest.GetQueryParam(const AName: string): string; begin Result := ''; end;
function TMockHttpRequest.GetCookies: IStringDictionary; begin Result := nil; end;
function TMockHttpRequest.GetFiles: IFormFileCollection; begin Result := nil; end;

{ TMockHttpResponse }

constructor TMockHttpResponse.Create;
begin
  FBody := TMemoryStream.Create;
  FHeaders := TCollections.CreateStringDictionary(True);
end;

destructor TMockHttpResponse.Destroy;
begin
  FBody.Free;
  inherited;
end;

function TMockHttpResponse.GetStatusCode: Integer; begin Result := FStatusCode; end;
function TMockHttpResponse.GetContentType: string; begin Result := FContentType; end;
function TMockHttpResponse.Status(AValue: Integer): IHttpResponse;
begin
  FStatusCode := AValue;
  Result := Self;
end;
procedure TMockHttpResponse.SetStatusCode(AValue: Integer); begin FStatusCode := AValue; end;
procedure TMockHttpResponse.SetContentType(const AValue: string); begin FContentType := AValue; end;
procedure TMockHttpResponse.SetContentLength(const AValue: Int64); begin end;
procedure TMockHttpResponse.Flush; begin end;
procedure TMockHttpResponse.Write(const AContent: string); begin end;
procedure TMockHttpResponse.Write(const ABuffer: TBytes);
begin
  if Length(ABuffer) > 0 then
    FBody.Write(ABuffer[0], Length(ABuffer));
end;
procedure TMockHttpResponse.Write(const AStream: TStream);
begin
  FBody.CopyFrom(AStream, AStream.Size - AStream.Position);
end;
procedure TMockHttpResponse.Json(const AJson: string); begin end;
procedure TMockHttpResponse.Json(const AValue: TValue); begin end;
procedure TMockHttpResponse.AddHeader(const AName, AValue: string);
begin
  FHeaders.AddOrSetValue(AName, AValue);
end;
procedure TMockHttpResponse.AppendCookie(const AName, AValue: string;
  const AOptions: TCookieOptions); begin end;
procedure TMockHttpResponse.AppendCookie(const AName, AValue: string); begin end;
procedure TMockHttpResponse.DeleteCookie(const AName: string); begin end;
procedure TMockHttpResponse.Redirect(const AUrl: string; APermanent: Boolean); begin end;
procedure TMockHttpResponse.Unauthorized(const AMessage: string); begin end;
procedure TMockHttpResponse.Forbidden(const AMessage: string); begin end;
procedure TMockHttpResponse.BadRequest(const AMessage: string); begin end;
procedure TMockHttpResponse.NotFound(const AMessage: string); begin end;
function TMockHttpResponse.GetHtmx: IHtmxResponse; begin Result := nil; end;
function TMockHttpResponse.GetHeaders: IStringDictionary; begin Result := FHeaders; end;

{ TMockHttpContext }

constructor TMockHttpContext.Create(AReq: IHttpRequest; ARes: IHttpResponse);
begin
  FRequest := AReq;
  FResponse := ARes;
  FItems := TCollections.CreateDictionary<string, TValue>;
end;

destructor TMockHttpContext.Destroy;
begin
  inherited;
end;

// Interface method mappings omitted for space, inline:
function TMockHttpContext.GetConnection: IDextServerConnection; begin Result := nil; end;
function TMockHttpContext.GetRequest: IHttpRequest; begin Result := FRequest; end;
function TMockHttpContext.GetResponse: IHttpResponse; begin Result := FResponse; end;
procedure TMockHttpContext.SetResponse(const AValue: IHttpResponse); begin FResponse := AValue; end;
function TMockHttpContext.GetServices: IServiceProvider; begin Result := nil; end;
procedure TMockHttpContext.SetServices(const AValue: IServiceProvider); begin end;
function TMockHttpContext.GetUser: IClaimsPrincipal; begin Result := nil; end;
procedure TMockHttpContext.SetUser(const AValue: IClaimsPrincipal); begin end;
function TMockHttpContext.GetItems: IDictionary<string, TValue>; begin Result := FItems; end;
function TMockHttpContext.GetSession: IStreamableSession; begin Result := nil; end;
function TMockHttpContext.GetEndpointMetadata: TEndpointMetadata;
var
  Meta: TEndpointMetadata;
begin
  Result := Meta;
end;
procedure TMockHttpContext.SetEndpointMetadata(
  const AMetadata: TEndpointMetadata); begin end;
procedure TMockHttpContext.SetRouteParams(
  const AParams: TRouteValueDictionary); begin end;

{ TGrpcClient }

constructor TGrpcClient.Create(const AHost: string; APort: Integer);
begin
  FHost := AHost;
  FPort := APort;
end;

constructor TGrpcClient.Create(ADispatcher: TDextGrpcDispatcher);
begin
  FDispatcher := ADispatcher;
end;

procedure TGrpcClient.CallMethod(const AServiceName, AMethodName: string;
  ARequest, AResponse: TObject);
var
  Compressed: Boolean;
  Context: IHttpContext;
  FramedReq: TBytes;
  MockReq: TMockHttpRequest;
  MockRes: TMockHttpResponse;
  MsgBytes: TBytes;
  MsgVal: string;
  Offset: Integer;
  ReqBytes: TBytes;
  ResBytes: TBytes;
  StatusVal: string;
begin
  ReqBytes := TProtobufSerializer.Serialize(ARequest);
  FramedReq := TGrpcMessageCodec.Encode(ReqBytes);

  if Assigned(FDispatcher) then
  begin
    MockReq := TMockHttpRequest.Create('/' + AServiceName + '/' + AMethodName,
      FramedReq);
    MockRes := TMockHttpResponse.Create;
    Context := TMockHttpContext.Create(MockReq, MockRes);

    FDispatcher.Invoke(Context);

    if MockRes.Headers.TryGetValue('grpc-status', StatusVal) and
       (StatusVal <> '0') then
    begin
      MockRes.Headers.TryGetValue('grpc-message', MsgVal);
      raise Exception.CreateFmt('gRPC Remote Error: %s (Status: %s)',
        [MsgVal, StatusVal]);
    end;

    if MockRes.Body.Size > 0 then
    begin
      SetLength(ResBytes, MockRes.Body.Size);
      MockRes.Body.Position := 0;
      MockRes.Body.Read(ResBytes[0], MockRes.Body.Size);
    end
    else
      SetLength(ResBytes, 0);

    Offset := 0;
    if TGrpcMessageCodec.TryDecode(ResBytes, Offset, Compressed, MsgBytes) then
      TProtobufSerializer.Deserialize(MsgBytes, AResponse)
    else
      raise Exception.Create('Failed to unpack gRPC response frame');
  end
  else
  begin
    raise Exception.Create(
      'Remote transport not implemented yet. Use in-process dispatcher.');
  end;
end;

{ TEntitygRpcProvider<T> }

constructor TEntitygRpcProvider<T>.Create(AClient: TGrpcClient;
  const AServiceName: string);
begin
  FClient := AClient;
  FServiceName := AServiceName;
end;

{ TGenericListResponse<TItem> }

constructor TGenericListResponse<TItem>.Create;
begin
  FItems := TList<TItem>.Create;
end;

destructor TGenericListResponse<TItem>.Destroy;
var
  Item: TItem;
begin
  for Item in FItems do
    Item.Free;
  FItems.Free;
  inherited;
end;

function TEntitygRpcProvider<T>.FetchAll(const AQuery: string): TList<T>;
var
  Request: TGenericQueryRequest;
  Response: TGenericListResponse<T>;
  Item: T;
begin
  Request := TGenericQueryRequest.Create;
  Request.Query := AQuery;
  Response := TGenericListResponse<T>.Create;
  try
    FClient.CallMethod(FServiceName, 'FetchAll', Request, Response);
    Result := TList<T>.Create;
    for Item in Response.Items do
    begin
      Result.Add(Item);
    end;
    Response.Items.Clear;
  finally
    Request.Free;
    Response.Free;
  end;
end;

procedure TEntitygRpcProvider<T>.ApplyChanges(const AList: TList<T>);
begin
end;

end.
