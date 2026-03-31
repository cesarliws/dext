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
unit Dext.Web.Indy;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Rtti,
  IdCustomHTTPServer,
  IdContext,
  IdGlobal,
  IdHeaderList,
  IdURI,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.Web.Interfaces,
  Dext.DI.Interfaces,
  Dext.Auth.Identity,
  Dext.Web.Indy.Types,
  Dext.Json;

type
  TIndyHttpResponse = class(TInterfacedObject, IHttpResponse)
  private
    FResponseInfo: TIdHTTPResponseInfo;
  public
    constructor Create(AResponseInfo: TIdHTTPResponseInfo);
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
    property StatusCode: Integer read GetStatusCode write SetStatusCode;
    property ContentType: string read GetContentType write SetContentType;
  end;

  TIndyHttpRequest = class(TInterfacedObject, IHttpRequest)
  private
    FRequestInfo: TIdHTTPRequestInfo;
    FQuery: IStringDictionary;
    FBodyStream: TStream;
    FRouteParams: TRouteValueDictionary;
    FHeaders: IStringDictionary;
    FCookies: IStringDictionary;
    FFiles: IFormFileCollection;
    function ParseQueryString(const AQuery: string): IStringDictionary;
    function ParseHeaders(AHeaderList: TIdHeaderList): IStringDictionary;
    procedure ParseMultipart;
  public
    constructor Create(ARequestInfo: TIdHTTPRequestInfo);
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

  TIndyHttpContext = class(TInterfacedObject, IHttpContext)
  private
    FRequest: IHttpRequest;
    FResponse: IHttpResponse;
    FScope: IServiceScope; // Hold the scope for the request lifetime
    FServices: IServiceProvider;
    FUser: IClaimsPrincipal;
    FItems: IDictionary<string, TValue>;
    FContext: TIdContext;
  public
    constructor Create(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo;
      AResponseInfo: TIdHTTPResponseInfo; const AServices: IServiceProvider);
    destructor Destroy; override;
    procedure SetRouteParams(const AParams: TRouteValueDictionary);
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
    property Context: TIdContext read FContext;
  end;

implementation

uses
  System.DateUtils;

{ TIndyHttpRequest }

constructor TIndyHttpRequest.Create(ARequestInfo: TIdHTTPRequestInfo);
begin
  inherited Create;
  FRequestInfo := ARequestInfo;
  FRouteParams.Clear;
  FFiles := TFormFileCollection.Create(TCollections.CreateList<IFormFile>);
  // Note: FQuery, FHeaders, FBodyStream, FCookies are NIL and will be lazy loaded
end;

destructor TIndyHttpRequest.Destroy;
begin
  FQuery := nil;
  FBodyStream.Free;
  FHeaders := nil;
  FCookies := nil;
  FFiles := nil;
  inherited Destroy;
end;

// ? NOVO: Parsear headers do Indy para dicionário
function TIndyHttpRequest.ParseHeaders(AHeaderList: TIdHeaderList): IStringDictionary;
var
  I: Integer;
  Name, Value: string;
begin
  Result := TDextStringDictionary.Create as IStringDictionary;

  for I := 0 to AHeaderList.Count - 1 do
  begin
    Name := AHeaderList.Names[I];
    Value := AHeaderList.Values[Name];

    if not Name.IsEmpty then
    begin
      Result.SetItem(Name, Value);
    end;
  end;
end;

function TIndyHttpRequest.GetHeader(const AName: string): string;
begin
  Result := FRequestInfo.RawHeaders.Values[AName];
end;

function TIndyHttpRequest.GetHeaders: IStringDictionary;
begin
  if FHeaders = nil then
    FHeaders := ParseHeaders(FRequestInfo.RawHeaders);
  Result := FHeaders;
end;

function TIndyHttpRequest.GetRemoteIpAddress: string;
begin
  Result := FRequestInfo.RemoteIP;
end;

function TIndyHttpRequest.ParseQueryString(const AQuery: string): IStringDictionary;
var
  P, EndP: PChar;
  Key, Value: string;
  Len: Integer;
begin
  Result := TDextStringDictionary.Create as IStringDictionary;
  if AQuery = '' then Exit;
  
  P := PChar(AQuery);
  Len := Length(AQuery);
  EndP := P + Len;

  while P < EndP do
  begin
    var EqP := StrScan(P, '=');
    var AmpP := StrScan(P, '&');

    if (AmpP = nil) or (AmpP > EndP) then
      AmpP := EndP;

    if (EqP <> nil) and (EqP < AmpP) then
    begin
      SetString(Key, P, EqP - P);
      SetString(Value, EqP + 1, AmpP - (EqP + 1));
      Result.SetItem(TIdURI.URLDecode(Key), TIdURI.URLDecode(Value));
    end
    else
    begin
      SetString(Key, P, AmpP - P);
      if Key <> '' then
        Result.SetItem(TIdURI.URLDecode(Key), '');
    end;

    P := AmpP + 1;
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

function TIndyHttpRequest.GetQuery: IStringDictionary;
begin
  if FQuery = nil then
    FQuery := ParseQueryString(FRequestInfo.QueryParams);
  Result := FQuery;
end;

function TIndyHttpRequest.GetQueryParam(const AName: string): string;
begin
  if not GetQuery.TryGetValue(AName, Result) then
    Result := '';
end;

function TIndyHttpRequest.GetRouteParams: TRouteValueDictionary;
begin
  Result := FRouteParams;
end;

function TIndyHttpRequest.GetCookies: IStringDictionary;
var
  CookieHeader: string;
  Pairs: TArray<string>;
  Pair: string;
  Parts: TArray<string>;
begin
  if FCookies = nil then
  begin
    FCookies := TDextStringDictionary.Create as IStringDictionary;
    CookieHeader := FRequestInfo.RawHeaders.Values['Cookie'];
    if CookieHeader <> '' then
    begin
      Pairs := CookieHeader.Split([';']);
      for Pair in Pairs do
      begin
        Parts := Pair.Trim.Split(['='], 2);
        if Length(Parts) = 2 then
          FCookies.SetItem(Parts[0].Trim, TIdURI.URLDecode(Parts[1].Trim))
        else if (Length(Parts) = 1) and (Parts[0] <> '') then
          FCookies.SetItem(Parts[0].Trim, '');
      end;
    end;
  end;
  Result := FCookies;
end;

function TIndyHttpRequest.GetFiles: IFormFileCollection;
begin
  if FFiles.Count = 0 then
    ParseMultipart;
  Result := FFiles;
end;

procedure TIndyHttpRequest.ParseMultipart;
var
  Boundary, ContentTypeStr: string;
  Stream: TStream;
  P, NextP: Int64;
  BoundaryBytes: TBytes;

  function FindBytes(const B: TBytes; Start: Int64): Int64;
  var
    J: Integer;
    Match: Boolean;
  begin
    Result := -1;
    if Length(B) = 0 then Exit;
    Stream.Position := Start;
    while Stream.Position <= Stream.Size - Length(B) do
    begin
      Match := True;
      for J := 0 to Length(B) - 1 do
      begin
        var Bt: Byte;
        if (Stream.Read(Bt, 1) <> 1) or (Bt <> B[J]) then
        begin
          Match := False;
          Stream.Position := Stream.Position - J; 
          Break;
        end;
      end;
      if Match then
      begin
        Result := Stream.Position - Length(B);
        Exit;
      end;
    end;
  end;

  procedure ParsePart(Start, Finish: Int64);
  var
    HeaderList: TStringList;
    S, Line: string;
    HeaderEndPos: Int64;
    PartStream: TMemoryStream;
    PartName, PartFileName, PartContentType: string;
    ContentDisp: string;
    B: Byte;

    function ExtractValue(const Key: string): string;
    var
      KeyQuoted, KeyUnquoted: string;
      Idx, EndIdx: Integer;
      Val: string;
    begin
      Result := '';
      KeyQuoted := Key + '="';
      KeyUnquoted := Key + '=';
      
      // Try quoted first
      Idx := Pos(KeyQuoted, ContentDisp.ToLower);
      if Idx > 0 then
      begin
        Val := Copy(ContentDisp, Idx + Length(KeyQuoted), MaxInt);
        EndIdx := Pos('"', Val);
        if EndIdx > 0 then
          Result := Copy(Val, 1, EndIdx - 1);
      end
      else
      begin
        // Try unquoted
        Idx := Pos(KeyUnquoted, ContentDisp.ToLower);
        if Idx > 0 then
        begin
          Val := Copy(ContentDisp, Idx + Length(KeyUnquoted), MaxInt);
          // Find end: space, semicolon, or end of string
          EndIdx := 1;
          while (EndIdx <= Length(Val)) and (Val[EndIdx] <> ';') and (Val[EndIdx] <> ' ') do
            Inc(EndIdx);
          Result := Copy(Val, 1, EndIdx - 1);
        end;
      end;
    end;

  begin
    Stream.Position := Start;
    HeaderList := TStringList.Create;
    try
      while Stream.Position < Finish do
      begin
        S := '';
        if Stream.Read(B, 1) <> 1 then Break;
        while (B <> 10) and (Stream.Position < Finish) do
        begin
          if B <> 13 then S := S + Char(B);
          if Stream.Read(B, 1) <> 1 then Break;
        end;
        if S = '' then Break;
        HeaderList.Add(S);
      end;
      
      HeaderEndPos := Stream.Position;
      
      for Line in HeaderList do
      begin
        var LowerLine := Line.ToLower;
        if LowerLine.StartsWith('content-disposition:') then
        begin
          ContentDisp := Line;
          
          PartName := ExtractValue('name');
          // For filename, try 'filename' (not filename*)
          PartFileName := ExtractValue('filename');
        end
        else if LowerLine.StartsWith('content-type:') then
          PartContentType := Trim(Copy(Line, 14, MaxInt));
      end;
      
      if PartName <> '' then
      begin
        PartStream := TMemoryStream.Create;
        // The part content starts at HeaderEndPos and ends at Finish - 2 (CRLF before boundary)
        var ContentSize := Finish - HeaderEndPos - 2;
        if ContentSize > 0 then
        begin
          Stream.Position := HeaderEndPos;
          PartStream.CopyFrom(Stream, ContentSize);
        end;
        PartStream.Position := 0;
        FFiles.Add(TIndyFormFile.Create(PartName, PartFileName, PartContentType, PartStream));
      end;
    finally
      HeaderList.Free;
    end;
  end;

begin
  ContentTypeStr := FRequestInfo.ContentType;
  if not ContentTypeStr.ToLower.StartsWith('multipart/form-data') then Exit;
  
  var Idx := Pos('boundary=', ContentTypeStr.ToLower);
  if Idx = 0 then Exit;
  
  // Extract boundary value and clean it up
  var BoundaryValue := Copy(ContentTypeStr, Idx + 9, MaxInt);
  // Remove any trailing parameters (e.g., "; charset=...")
  var SemiPos := Pos(';', BoundaryValue);
  if SemiPos > 0 then
    BoundaryValue := Copy(BoundaryValue, 1, SemiPos - 1);
  // Remove surrounding quotes if present
  BoundaryValue := BoundaryValue.Trim;
  if (Length(BoundaryValue) > 1) and (BoundaryValue[1] = '"') and (BoundaryValue[Length(BoundaryValue)] = '"') then
    BoundaryValue := Copy(BoundaryValue, 2, Length(BoundaryValue) - 2);
  
  Boundary := '--' + BoundaryValue;
  BoundaryBytes := TEncoding.UTF8.GetBytes(Boundary);
  
  Stream := GetBody;
  if (Stream = nil) or (Stream.Size = 0) then
    Exit;
  
  P := FindBytes(BoundaryBytes, 0);
  while P >= 0 do
  begin
    NextP := FindBytes(BoundaryBytes, P + Length(BoundaryBytes));
    if NextP < 0 then Break;
    
    ParsePart(P + Length(BoundaryBytes) + 2, NextP); 
    P := NextP;
  end;
end;

function TIndyHttpRequest.GetBody: TStream;
var
  FormData: string;
begin
  if FBodyStream = nil then
  begin
    // Lazy load body
    if Assigned(FRequestInfo.PostStream) then
    begin
      try
        FRequestInfo.PostStream.Position := 0;
      except
        // Some streams might not support seeking
      end;
      FBodyStream := TMemoryStream.Create;
      FBodyStream.CopyFrom(FRequestInfo.PostStream, 0);
      FBodyStream.Position := 0;
    end
    else if (FRequestInfo.FormParams <> '') or (FRequestInfo.UnparsedParams <> '') then
    begin
      if FRequestInfo.UnparsedParams <> '' then
        FormData := FRequestInfo.UnparsedParams
      else
        FormData := FRequestInfo.FormParams;
        
      FBodyStream := TMemoryStream.Create;
      var Bytes := TEncoding.UTF8.GetBytes(FormData);
      if Length(Bytes) > 0 then
        FBodyStream.WriteBuffer(Bytes[0], Length(Bytes));
      FBodyStream.Position := 0;
    end;
  end;
  Result := FBodyStream;
end;

{ TIndyHttpResponse }

constructor TIndyHttpResponse.Create(AResponseInfo: TIdHTTPResponseInfo);
begin
  inherited Create;
  FResponseInfo := AResponseInfo;
end;

// ? NOVO: Adicionar header à response
procedure TIndyHttpResponse.AddHeader(const AName, AValue: string);
begin
  FResponseInfo.CustomHeaders.AddValue(AName, AValue);
end;

procedure TIndyHttpResponse.AppendCookie(const AName, AValue: string; const AOptions: TCookieOptions);
var
  CookieStr: string;
begin
  CookieStr := Format('%s=%s', [AName, TIdURI.URLEncode(AValue)]);
  if AOptions.Path <> '' then
    CookieStr := CookieStr + '; Path=' + AOptions.Path;
  if AOptions.Domain <> '' then
    CookieStr := CookieStr + '; Domain=' + AOptions.Domain;
  if AOptions.Expires <> 0 then
    CookieStr := CookieStr + '; Expires=' + FormatDateTime('ddd, dd mmm yyyy hh:nn:ss "GMT"', AOptions.Expires, TFormatSettings.Create('en-US'));
  if AOptions.HttpOnly then
    CookieStr := CookieStr + '; HttpOnly';
  if AOptions.Secure then
    CookieStr := CookieStr + '; Secure';
  if AOptions.SameSite <> '' then
    CookieStr := CookieStr + '; SameSite=' + AOptions.SameSite;

  FResponseInfo.CustomHeaders.AddValue('Set-Cookie', CookieStr);
end;

procedure TIndyHttpResponse.AppendCookie(const AName, AValue: string);
begin
  AppendCookie(AName, AValue, TCookieOptions.Default);
end;

procedure TIndyHttpResponse.DeleteCookie(const AName: string);
var
  Opts: TCookieOptions;
begin
  Opts := TCookieOptions.Default;
  Opts.Expires := Now - 1; // Expired yesterday
  AppendCookie(AName, '', Opts);
end;

function TIndyHttpResponse.GetStatusCode: Integer;
begin
  Result := FResponseInfo.ResponseNo;
end;

function TIndyHttpResponse.GetContentType: string;
begin
  Result := FResponseInfo.ContentType;
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
var
  CTLower: string;
begin
  FResponseInfo.ContentText := AContent;
  if FResponseInfo.ContentType = '' then
    FResponseInfo.ContentType := 'text/plain; charset=utf-8'
  else
  begin
    CTLower := LowerCase(FResponseInfo.ContentType);
    // Indy encodes ContentText using the response charset; without charset, legacy
    // defaults break Unicode (Arabic, emoji). Match WebBroker/DCS UTF-8 behavior.
    if (Pos('charset=', CTLower) = 0) and (Length(CTLower) >= 5) and (Copy(CTLower, 1, 5) = 'text/') then
      FResponseInfo.ContentType := FResponseInfo.ContentType + '; charset=utf-8';
  end;
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

procedure TIndyHttpResponse.Write(const AStream: TStream);
begin
  FResponseInfo.ContentStream := AStream;
  FResponseInfo.FreeContentStream := False; // We do not own external stream unless specified, usually caller owns it or it's a TFileStream.
  // Wait, IHttpResponse usually implies transferring ownership or copying? 
  // In pure abstraction, Write(Stream) usually copies. But for performance we might want to just assign.
  // Let's assume we copy for safety unless it's a memory stream we created.
  // BUT the roadmap says "support envio eficiente", implies no copy.
  // Dext.Web.Indy usually runs on same thread. 
  
  // Safe implementation for now:
  // If we assign AStream to ContentStream, Indy will read from it. We must ensure AStream stays alive.
  // Since we don't control AStream lifecycle here easily without taking ownership, copying is safer for general use.
  // However, for "Stream Writing" feature, we usually want to stream LARGE files.
  // Let's implement copy for now to be safe and consistent with buffering. 
  // Optimization to TFileStream can be done if we detect type or add WriteFile().
  
  var MemStream := TMemoryStream.Create;
  MemStream.CopyFrom(AStream, 0);
  MemStream.Position := 0;
  FResponseInfo.ContentStream := MemStream;
  FResponseInfo.FreeContentStream := True;
end;

procedure TIndyHttpResponse.Json(const AJson: string);
begin
  FResponseInfo.ContentText := AJson;
  FResponseInfo.ContentType := 'application/json; charset=utf-8';
end;

procedure TIndyHttpResponse.Json(const AValue: TValue);
begin
  Json(TDextJson.Serialize(AValue));
end;

{ TIndyHttpContext }

constructor TIndyHttpContext.Create(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo;
  AResponseInfo: TIdHTTPResponseInfo; const AServices: IServiceProvider);
begin
  inherited Create;
  FContext := AContext;
  FRequest := TIndyHttpRequest.Create(ARequestInfo);
  FResponse := TIndyHttpResponse.Create(AResponseInfo);
  
  // Create a new scope for THIS request. 
  // All Scoped services (like DbContext) resolved from this provider 
  // will be isolated to this request and destroyed when this context is released.
  FScope := AServices.CreateScope;
  FServices := FScope.ServiceProvider;
  
end;

destructor TIndyHttpContext.Destroy;
begin
  FItems := nil;
  FRequest := nil;
  FResponse := nil;
  FServices := nil;
  FScope := nil; // This will trigger the disposal of all Scoped services for this request
  inherited;
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

function TIndyHttpContext.GetItems: IDictionary<string, TValue>;
begin
  if FItems = nil then
    FItems := TCollections.CreateDictionary<string, TValue>;
  Result := FItems;
end;

procedure TIndyHttpContext.SetRouteParams(const AParams: TRouteValueDictionary);
var
  IndyRequest: TIndyHttpRequest;
begin
  if FRequest is TIndyHttpRequest then
  begin
    IndyRequest := TIndyHttpRequest(FRequest);
    IndyRequest.FRouteParams := AParams;
  end;
end;

end.
