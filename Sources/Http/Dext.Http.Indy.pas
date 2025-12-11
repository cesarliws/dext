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
unit Dext.Http.Indy;

interface

uses
  System.Classes, System.Generics.Collections, System.SysUtils, System.Generics.Defaults,
  IdCustomHTTPServer, IdContext, IdGlobal, IdURI, IdHeaderList,
  Dext.Http.Interfaces, Dext.DI.Interfaces, Dext.Auth.Identity;

type
  TIndyHttpRequest = class(TInterfacedObject, IHttpRequest)
  private
    FRequestInfo: TIdHTTPRequestInfo;
    FQuery: TStrings;
    FBodyStream: TStream;
    FRouteParams: TDictionary<string, string>;
    FHeaders: TDictionary<string, string>; // ✅ NOVO
    function ParseQueryString(const AQuery: string): TStrings;
    function ParseHeaders(AHeaderList: TIdHeaderList): TDictionary<string, string>; // ✅ NOVO
  public
    constructor Create(ARequestInfo: TIdHTTPRequestInfo);
    destructor Destroy; override;

    function GetMethod: string;
    function GetPath: string;
    function GetQuery: TStrings;
    function GetBody: TStream;
    function GetRouteParams: TDictionary<string, string>;
    function GetHeaders: TDictionary<string, string>;
    function GetRemoteIpAddress: string; // ✅ Added
  end;

  TIndyHttpResponse = class(TInterfacedObject, IHttpResponse)
  private
    FResponseInfo: TIdHTTPResponseInfo;
  public
    constructor Create(AResponseInfo: TIdHTTPResponseInfo);
    function Status(AValue: Integer): IHttpResponse;
    function GetStatusCode: Integer;
    procedure SetStatusCode(AValue: Integer);
    procedure SetContentType(const AValue: string);
    procedure SetContentLength(const AValue: Int64); // ✅ Added
    procedure Write(const AContent: string); overload;
    procedure Write(const ABuffer: TBytes); overload; // ✅ Added
    procedure Json(const AJson: string);
    procedure AddHeader(const AName, AValue: string); // ✅ NOVO: Implementação da interface
  end;

  TIndyHttpContext = class(TInterfacedObject, IHttpContext)
  private
    FRequest: IHttpRequest;
    FResponse: IHttpResponse;
    FServices: IServiceProvider;
    FUser: IClaimsPrincipal;
  public
    constructor Create(ARequestInfo: TIdHTTPRequestInfo;
      AResponseInfo: TIdHTTPResponseInfo; const AServices: IServiceProvider);
    procedure SetRouteParams(const AParams: TDictionary<string, string>);
    function GetRequest: IHttpRequest;
    function GetResponse: IHttpResponse;
    procedure SetResponse(const AValue: IHttpResponse);
    function GetServices: IServiceProvider;
    procedure SetServices(const AValue: IServiceProvider);
    function GetUser: IClaimsPrincipal;
    procedure SetUser(const AValue: IClaimsPrincipal);
  end;

implementation

{ TIndyHttpRequest }

constructor TIndyHttpRequest.Create(ARequestInfo: TIdHTTPRequestInfo);
begin
  inherited Create;
  FRequestInfo := ARequestInfo;
  FQuery := ParseQueryString(FRequestInfo.QueryParams);
  FRouteParams := TDictionary<string, string>.Create;
  FHeaders := ParseHeaders(FRequestInfo.RawHeaders); // ✅ NOVO: Parsear headers
  // Criar cópia do body stream para não depender do lifecycle do Indy
  if Assigned(FRequestInfo.PostStream) then
  begin
    FBodyStream := TMemoryStream.Create;
    FBodyStream.CopyFrom(FRequestInfo.PostStream, 0);
    FBodyStream.Position := 0;
  end;
end;

destructor TIndyHttpRequest.Destroy;
begin
  FQuery.Free;
  FBodyStream.Free;
  FRouteParams.Free;
  FHeaders.Free; // ✅ NOVO: Liberar headers
  inherited Destroy;
end;

// ✅ NOVO: Parsear headers do Indy para dicionário
function TIndyHttpRequest.ParseHeaders(AHeaderList: TIdHeaderList): TDictionary<string, string>;
var
  I: Integer;
  Name, Value: string;
begin
  Result := TDictionary<string, string>.Create(TIStringComparer.Ordinal);

  for I := 0 to AHeaderList.Count - 1 do
  begin
    Name := AHeaderList.Names[I];
    Value := AHeaderList.Values[Name];

    if not Name.IsEmpty then
    begin
      Result.AddOrSetValue(Name, Value);
    end;
  end;
end;

function TIndyHttpRequest.GetHeaders: TDictionary<string, string>;
begin
  Result := FHeaders; // ✅ NOVO: Retornar headers
end;

function TIndyHttpRequest.GetRemoteIpAddress: string;
begin
  Result := FRequestInfo.RemoteIP;
end;

function TIndyHttpRequest.ParseQueryString(const AQuery: string): TStrings;
var
  I: Integer;
  Params: TStringList;
begin
  Params := TStringList.Create;
  try
    Params.Delimiter := '&';
    Params.StrictDelimiter := True;
    Params.DelimitedText := AQuery;

    // Decodificar URL encoding
    for I := 0 to Params.Count - 1 do
    begin
      Params[I] := TIdURI.URLDecode(Params[I]);
    end;

    Result := Params;
  except
    Params.Free;
    raise;
  end;
end;

function TIndyHttpRequest.GetMethod: string;
begin
  Result := FRequestInfo.Command;
end;

function TIndyHttpRequest.GetPath: string;
begin
  Result := FRequestInfo.Document;
  // Garantir que paths vazios sejam '/'
  if Result = '' then
    Result := '/';
end;

function TIndyHttpRequest.GetQuery: TStrings;
begin
  Result := FQuery;
end;

function TIndyHttpRequest.GetRouteParams: TDictionary<string, string>;
begin
  Result := FRouteParams;
end;

function TIndyHttpRequest.GetBody: TStream;
begin
  Result := FBodyStream;
end;

{ TIndyHttpResponse }

constructor TIndyHttpResponse.Create(AResponseInfo: TIdHTTPResponseInfo);
begin
  inherited Create;
  FResponseInfo := AResponseInfo;
end;

// ✅ NOVO: Adicionar header à response
procedure TIndyHttpResponse.AddHeader(const AName, AValue: string);
begin
  FResponseInfo.CustomHeaders.AddValue(AName, AValue);
end;

function TIndyHttpResponse.GetStatusCode: Integer;
begin
  Result := FResponseInfo.ResponseNo;
end;

procedure TIndyHttpResponse.SetStatusCode(AValue: Integer);
begin
  FResponseInfo.ResponseNo := AValue;
end;

function TIndyHttpResponse.Status(AValue: Integer): IHttpResponse;
begin
  SetStatusCode(AValue);
  Result := Self;
end;

procedure TIndyHttpResponse.SetContentType(const AValue: string);
begin
  AddHeader('Content-Type', AValue);
  FResponseInfo.ContentType := AValue;
end;

procedure TIndyHttpResponse.SetContentLength(const AValue: Int64);
begin
  FResponseInfo.ContentLength := AValue;
end;

procedure TIndyHttpResponse.Write(const AContent: string);
begin
  FResponseInfo.ContentText := AContent;
  // Only set default content type if not already set
  if FResponseInfo.ContentType = '' then
    FResponseInfo.ContentType := 'text/plain; charset=utf-8';
end;

procedure TIndyHttpResponse.Write(const ABuffer: TBytes);
var
  Stream: TMemoryStream;
begin
  Stream := TMemoryStream.Create;
  if Length(ABuffer) > 0 then
    Stream.WriteBuffer(ABuffer[0], Length(ABuffer));
  Stream.Position := 0;
  
  FResponseInfo.ContentStream := Stream;
  FResponseInfo.FreeContentStream := True; // Indy will free the stream
end;

procedure TIndyHttpResponse.Json(const AJson: string);
begin
  FResponseInfo.ContentText := AJson;
  FResponseInfo.ContentType := 'application/json; charset=utf-8';
end;

{ TIndyHttpContext }

constructor TIndyHttpContext.Create(ARequestInfo: TIdHTTPRequestInfo;
  AResponseInfo: TIdHTTPResponseInfo; const AServices: IServiceProvider);
begin
  inherited Create;
  FRequest := TIndyHttpRequest.Create(ARequestInfo);
  FResponse := TIndyHttpResponse.Create(AResponseInfo);
  FServices := AServices;
end;

function TIndyHttpContext.GetRequest: IHttpRequest;
begin
  Result := FRequest;
end;

function TIndyHttpContext.GetResponse: IHttpResponse;
begin
  Result := FResponse;
end;

procedure TIndyHttpContext.SetResponse(const AValue: IHttpResponse);
begin
  FResponse := AValue;
end;

function TIndyHttpContext.GetServices: IServiceProvider;
begin
  Result := FServices;
end;

procedure TIndyHttpContext.SetServices(const AValue: IServiceProvider);
begin
  FServices := AValue;
end;

function TIndyHttpContext.GetUser: IClaimsPrincipal;
begin
  Result := FUser;
end;

procedure TIndyHttpContext.SetUser(const AValue: IClaimsPrincipal);
begin
  FUser := AValue;
end;

procedure TIndyHttpContext.SetRouteParams(const AParams: TDictionary<string, string>);
var
  IndyRequest: TIndyHttpRequest;
  Param: TPair<string, string>;
begin
  // ✅ CORREÇÃO: Cast manual em vez de Supports
  if FRequest is TIndyHttpRequest then
  begin
    IndyRequest := TIndyHttpRequest(FRequest);

    // Limpar parâmetros existentes e adicionar os novos
    IndyRequest.FRouteParams.Clear;
    for Param in AParams do
    begin
      IndyRequest.FRouteParams.Add(Param.Key, Param.Value);
    end;

    Writeln(Format('Injected route params: %d parameters', [AParams.Count]));
    for Param in AParams do
    begin
      Writeln(Format('  %s = %s', [Param.Key, Param.Value]));
    end;
  end
  else
  begin
    Writeln('WARNING: Cannot inject route params - request is not TIndyHttpRequest');
  end;
end;

end.

