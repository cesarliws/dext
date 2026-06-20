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
{  DISCLAIMER:                                                              }
{  This file is part of the Dext Framework and provides an adapter for the  }
{  Indy components (Internet Direct) that ship natively with Delphi.        }
{                                                                           }
{  Indy (Internet Direct) is dual-licensed under the BSD and MPL licenses.  }
{  For more information, visit: https://www.indyproject.org/license/        }
{                                                                           }
{  The classes in this file (TDextIndy*) are original works of the Dext     }
{  contributors and do not contain source code copied or derived from the   }
{  Indy project itself. They serve as wrappers/adapters to integrate Indy   }
{  with Dext's internal architecture.                                       }
{                                                                           }
{***************************************************************************}
{  Author:  Cesar Romero                                                    }
{  Created: 2025-12-08                                                      }
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
  Dext, // Para TDextServices
  Dext.Auth.Identity,
  Dext.Web.Indy.Types,
  Dext.Web.Results,
  Dext.Json,
  Dext.Server.Engine.Interfaces;

type
  TIndyStreamMode = (ismNormal, ismBuffering, ismChunking);

  /// <summary>
  ///   <see cref="IHttpResponse"/> implementation for the Indy server.
  /// </summary>
  TDextIndyHttpResponse = class(TInterfacedObject, IHttpResponse)
  private
    FContext: TIdContext;
    FResponseInfo: TIdHTTPResponseInfo;
    FHtmx: IHtmxResponse;
    FHeaders: IStringDictionary;
    FStreamMode: TIndyStreamMode;
    FStreamBuffer: string;
    procedure WriteChunkUtf8(const AText: string);
  public
    procedure BeginStreamingResponse;
    procedure EndStreamingResponse;
    procedure Flush;
    function IsClientConnected: Boolean;

    constructor Create(AContext: TIdContext; AResponseInfo: TIdHTTPResponseInfo);
    function GetHtmx: IHtmxResponse;
    function GetHeaders: IStringDictionary;
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
    property StatusCode: Integer read GetStatusCode write SetStatusCode;
    property ContentType: string read GetContentType write SetContentType;
  end;

  /// <summary>
  ///   <see cref="IHttpRequest"/> implementation for the Indy server.
  ///   Includes support for parsing QueryString, Headers, Cookies and Multipart/form-data.
  /// </summary>
  TDextIndyHttpRequest = class(TInterfacedObject, IHttpRequest)
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

  /// <summary>
  ///   HTTP execution context for the Indy server.
  ///   Manages the lifecycle of the service scope (DI) per request.
  /// </summary>
  TDextIndyHttpContext = class(TInterfacedObject, IHttpContext)
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
    property Request: IHttpRequest read GetRequest;
    property Response: IHttpResponse read GetResponse write SetResponse;
    property Services: IServiceProvider read GetServices write SetServices;
    property User: IClaimsPrincipal read GetUser write SetUser;
    property Items: IDictionary<string, TValue> read GetItems;
    property Context: TIdContext read FContext;
  end;

implementation

uses
  System.DateUtils,
  IdIOHandler,
  IdIOHandlerSocket,
  IdSocketHandle;

{ TDextIndyHttpRequest }

constructor TDextIndyHttpRequest.Create(ARequestInfo: TIdHTTPRequestInfo);
begin
  inherited Create;
  FRequestInfo := ARequestInfo;
  FRouteParams.Clear;
  FFiles := TFormFileCollection.Create(TCollections.CreateList<IFormFile>);
  // Note: FQuery, FHeaders, FBodyStream, FCookies are NIL and will be lazy loaded
end;

destructor TDextIndyHttpRequest.Destroy;
begin
  FQuery := nil;
  FBodyStream.Free;
  FHeaders := nil;
  FCookies := nil;
  FFiles := nil;
  inherited Destroy;
end;

// NEW: Parse Indy headers to dictionary
function TDextIndyHttpRequest.ParseHeaders(AHeaderList: TIdHeaderList): IStringDictionary;
var
  I: Integer;
  Name, Value: string;
begin
  Result := TCollections.CreateStringDictionary(True);

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

function TDextIndyHttpRequest.GetHeader(const AName: string): string;
begin
  Result := FRequestInfo.RawHeaders.Values[AName];
end;

function TDextIndyHttpRequest.GetHeaders: IStringDictionary;
begin
  if FHeaders = nil then
    FHeaders := ParseHeaders(FRequestInfo.RawHeaders);
  Result := FHeaders;
end;

function TDextIndyHttpRequest.GetRemoteIpAddress: string;
begin
  Result := FRequestInfo.RemoteIP;
end;

function TDextIndyHttpRequest.ParseQueryString(const AQuery: string): IStringDictionary;
var
  P, EndP: PChar;
  Key, Value: string;
  Len: Integer;
  EqP, AmpP: PChar;
begin
  Result := TCollections.CreateStringDictionary(True);
  if AQuery = '' then Exit;
  
  P := PChar(AQuery);
  Len := Length(AQuery);
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

function TDextIndyHttpRequest.GetMethod: string;
begin
  Result := FRequestInfo.Command;
end;

function TDextIndyHttpRequest.GetPath: string;
begin
  Result := FRequestInfo.Document;
  // Ensure empty paths are '/'
  if Result = '' then
    Result := '/';
end;

function TDextIndyHttpRequest.GetQuery: IStringDictionary;
begin
  if FQuery = nil then
    FQuery := ParseQueryString(FRequestInfo.QueryParams);
  Result := FQuery;
end;

function TDextIndyHttpRequest.GetQueryParam(const AName: string): string;
begin
  if not GetQuery.TryGetValue(AName, Result) then
    Result := '';
end;

function TDextIndyHttpRequest.GetRouteParams: TRouteValueDictionary;
begin
  Result := FRouteParams;
end;

function TDextIndyHttpRequest.GetCookies: IStringDictionary;
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

function TDextIndyHttpRequest.GetFiles: IFormFileCollection;
begin
  if FFiles.Count = 0 then
    ParseMultipart;
  Result := FFiles;
end;

procedure TDextIndyHttpRequest.ParseMultipart;
var
  Boundary, ContentTypeStr: string;
  Stream: TStream;
  P, NextP: Int64;
  BoundaryBytes: TBytes;
  Idx, SemiPos: Integer;
  BoundaryValue: string;

  function FindBytes(const B: TBytes; Start: Int64): Int64;
  var
    J: Integer;
    Match: Boolean;
    Bt: Byte;
  begin
    Result := -1;
    if Length(B) = 0 then Exit;
    Stream.Position := Start;
    while Stream.Position <= Stream.Size - Length(B) do
    begin
      Match := True;
      for J := 0 to Length(B) - 1 do
      begin
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
    LowerLine: string;
    ContentSize: Int64;

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
        LowerLine := Line.ToLower;
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
        ContentSize := Finish - HeaderEndPos - 2;
        if ContentSize > 0 then
        begin
          Stream.Position := HeaderEndPos;
          PartStream.CopyFrom(Stream, ContentSize);
        end;
        PartStream.Position := 0;
        FFiles.Add(TDextIndyFormFile.Create(PartName, PartFileName, PartContentType, PartStream));
      end;
    finally
      HeaderList.Free;
    end;
  end;

begin
  ContentTypeStr := FRequestInfo.ContentType;
  if not ContentTypeStr.ToLower.StartsWith('multipart/form-data') then Exit;
  
  Idx := Pos('boundary=', ContentTypeStr.ToLower);
  if Idx = 0 then Exit;
  
  // Extract boundary value and clean it up
  BoundaryValue := Copy(ContentTypeStr, Idx + 9, MaxInt);
  // Remove any trailing parameters (e.g., "; charset=...")
  SemiPos := Pos(';', BoundaryValue);
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

function TDextIndyHttpRequest.GetBody: TStream;
var
  FormData: string;
  Bytes: TBytes;
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
      Bytes := TEncoding.UTF8.GetBytes(FormData);
      if Length(Bytes) > 0 then
        FBodyStream.WriteBuffer(Bytes[0], Length(Bytes));
      FBodyStream.Position := 0;
    end;
  end;
  Result := FBodyStream;
end;

{ TDextIndyHttpResponse }

constructor TDextIndyHttpResponse.Create(AContext: TIdContext; AResponseInfo: TIdHTTPResponseInfo);
begin
  inherited Create;
  FContext := AContext;
  FResponseInfo := AResponseInfo;
  FStreamMode := ismNormal;
  FStreamBuffer := '';
end;

// NEW: Add header to response
procedure TDextIndyHttpResponse.AddHeader(const AName, AValue: string);
begin
  FResponseInfo.CustomHeaders.AddValue(AName, AValue);
  if FHeaders <> nil then
    FHeaders.AddOrSetValue(AName, AValue);
end;

function TDextIndyHttpResponse.GetHeaders: IStringDictionary;
var
  i: Integer;
begin
  if FHeaders = nil then
  begin
    FHeaders := TCollections.CreateStringDictionary(True);
    for i := 0 to FResponseInfo.CustomHeaders.Count - 1 do
      FHeaders.AddOrSetValue(FResponseInfo.CustomHeaders.Names[i], FResponseInfo.CustomHeaders.ValueFromIndex[i]);
  end;
  Result := FHeaders;
end;

procedure TDextIndyHttpResponse.BeginStreamingResponse;
begin
  FStreamMode := ismBuffering;
  FStreamBuffer := '';
end;

procedure TDextIndyHttpResponse.WriteChunkUtf8(const AText: string);
var
  LBytes: TIdBytes;
begin
  if AText.IsEmpty then
    Exit;

  LBytes := ToBytes(AText, IndyTextEncoding_UTF8);
  FContext.Connection.IOHandler.Write(IntToHex(Length(LBytes), 1) + #13#10, IndyTextEncoding_UTF8);
  FContext.Connection.IOHandler.Write(LBytes);
  FContext.Connection.IOHandler.Write(#13#10, IndyTextEncoding_UTF8);
end;

procedure TDextIndyHttpResponse.Flush;
begin
  if FStreamMode = ismNormal then
  begin
    FStreamMode := ismBuffering;
    FStreamBuffer := FResponseInfo.ContentText;
    FResponseInfo.ContentText := '';
  end;

  if FStreamMode <> ismBuffering then
    Exit;

  FResponseInfo.TransferEncoding := 'chunked';
  FResponseInfo.CloseConnection := False;
  FResponseInfo.ContentText := '';
  FResponseInfo.WriteHeader;

  FStreamMode := ismChunking;
  if FStreamBuffer <> '' then
  begin
    WriteChunkUtf8(FStreamBuffer);
    FStreamBuffer := '';
  end;
end;

function TDextIndyHttpResponse.IsClientConnected: Boolean;
var
  IOSock: TIdIOHandlerSocket;
  Binding: TIdSocketHandle;
begin
  Result := False;
  if (FContext = nil) or (FContext.Connection = nil) then
    Exit;
  if not (FContext.Connection.IOHandler is TIdIOHandlerSocket) then
  begin
    Result := FContext.Connection.IOHandler <> nil;
    Exit;
  end;

  IOSock := TIdIOHandlerSocket(FContext.Connection.IOHandler);
  if IOSock.ClosedGracefully then
    Exit;

  Binding := IOSock.Binding;
  if (Binding = nil) or not Binding.HandleAllocated then
    Exit;

  try
    if Binding.Select(0) then
      Exit;
  except
    Exit;
  end;

  Result := True;
end;

procedure TDextIndyHttpResponse.EndStreamingResponse;
begin
  if FStreamMode = ismChunking then
  begin
    try
      FContext.Connection.IOHandler.Write('0'#13#10#13#10,
        IndyTextEncoding_UTF8);
    except
      // Cliente pode ter desconectado
    end;
    FStreamMode := ismNormal;
  end
  else if FStreamMode = ismBuffering then
  begin
    FStreamBuffer := '';
    FStreamMode := ismNormal;
  end;
end;

procedure TDextIndyHttpResponse.AppendCookie(const AName, AValue: string; const AOptions: TCookieOptions);
var
  CookieStr: string;
begin
  CookieStr := Format('%s=%s', [AName, TIdURI.URLEncode(AValue)]);
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

  FResponseInfo.CustomHeaders.AddValue('Set-Cookie', CookieStr);
end;

procedure TDextIndyHttpResponse.AppendCookie(const AName, AValue: string);
begin
  AppendCookie(AName, AValue, TCookieOptions.Default);
end;

procedure TDextIndyHttpResponse.DeleteCookie(const AName: string);
var
  Opts: TCookieOptions;
begin
  Opts := TCookieOptions.Default;
  Opts.Expires := Now - 1; // Expired yesterday
  AppendCookie(AName, '', Opts);
end;

procedure TDextIndyHttpResponse.Redirect(const AUrl: string; APermanent: Boolean);
begin
  if APermanent then
    FResponseInfo.ResponseNo := 301
  else
    FResponseInfo.ResponseNo := 302;
    
  FResponseInfo.CustomHeaders.Values['Location'] := AUrl;
end;

procedure TDextIndyHttpResponse.Unauthorized(const AMessage: string);
begin
  FResponseInfo.ResponseNo := 401;
  if AMessage <> '' then Write(AMessage);
end;

procedure TDextIndyHttpResponse.Forbidden(const AMessage: string);
begin
  FResponseInfo.ResponseNo := 403;
  if AMessage <> '' then Write(AMessage);
end;

procedure TDextIndyHttpResponse.BadRequest(const AMessage: string);
begin
  FResponseInfo.ResponseNo := 400;
  if AMessage <> '' then Write(AMessage);
end;

procedure TDextIndyHttpResponse.NotFound(const AMessage: string);
begin
  FResponseInfo.ResponseNo := 404;
  if AMessage <> '' then Write(AMessage);
end;

function TDextIndyHttpResponse.GetStatusCode: Integer;
begin
  Result := FResponseInfo.ResponseNo;
end;

function TDextIndyHttpResponse.GetContentType: string;
begin
  Result := FResponseInfo.ContentType;
end;

procedure TDextIndyHttpResponse.SetStatusCode(AValue: Integer);
begin
  FResponseInfo.ResponseNo := AValue;
end;

function TDextIndyHttpResponse.Status(AValue: Integer): IHttpResponse;
begin
  SetStatusCode(AValue);
  Result := Self;
end;

procedure TDextIndyHttpResponse.SetContentType(const AValue: string);
var
  LParts: TArray<string>;
  i: Integer;
  LPart: string;
begin
  // Do NOT use AddHeader for Content-Type, Indy handles it natively via properties.
  // Adding it to CustomHeaders leads to duplicate headers which confuses some HTTP clients.
  
  if AValue.Contains(';') then
  begin
    LParts := AValue.Split([';']);
    FResponseInfo.ContentType := LParts[0].Trim;
    for i := 1 to High(LParts) do
    begin
      LPart := LParts[i].Trim;
      if LPart.ToLower.StartsWith('charset=') then
        FResponseInfo.CharSet := LPart.Substring(8).Trim
      else
        // Other parameters (like boundary) stay in ContentType
        FResponseInfo.ContentType := FResponseInfo.ContentType + '; ' + LPart;
    end;
  end
  else
  begin
    FResponseInfo.ContentType := AValue;
  end;
end;

procedure TDextIndyHttpResponse.SetContentLength(const AValue: Int64);
begin
  FResponseInfo.ContentLength := AValue;
end;

procedure TDextIndyHttpResponse.Write(const AContent: string);
begin
  { In streaming mode the response is delivered via chunked transfer-encoding
    (see BeginStreamingResponse/Flush/EndStreamingResponse). ismBuffering
    accumulates until Flush sends the headers + buffered prefix; ismChunking
    writes each call as a chunk directly on the socket. Without this check,
    long-running handlers (SSE in particular) would buffer indefinitely in
    ContentText and never reach the wire because the handler never returns. }
  case FStreamMode of
    ismBuffering:
      FStreamBuffer := FStreamBuffer + AContent;
    ismChunking:
      WriteChunkUtf8(AContent);
  else
    { Append instead of overwrite so handlers that build the body in multiple
      calls accumulate correctly (e.g., TSSEWriter writes 'event:' then 'data:'
      in separate calls). Single-call handlers are unaffected because appending
      to an empty ContentText is equivalent to assignment. }
    FResponseInfo.ContentText := FResponseInfo.ContentText + AContent;
    if FResponseInfo.CharSet = '' then
      FResponseInfo.CharSet := 'utf-8';
    if FResponseInfo.ContentType = '' then
      FResponseInfo.ContentType := 'text/plain';
  end;
end;

procedure TDextIndyHttpResponse.Write(const ABuffer: TBytes);
var
  Stream: TMemoryStream;
begin
  if FStreamMode in [ismBuffering, ismChunking] then
  begin
    if Length(ABuffer) > 0 then
      Write(TEncoding.UTF8.GetString(ABuffer));
    Exit;
  end;

  Stream := TMemoryStream.Create;
  if Length(ABuffer) > 0 then
    Stream.WriteBuffer(ABuffer[0], Length(ABuffer));
  Stream.Position := 0;

  FResponseInfo.ContentStream := Stream;
  FResponseInfo.FreeContentStream := True; // Indy will free the stream
end;

procedure TDextIndyHttpResponse.Write(const AStream: TStream);
var
  MemStream: TMemoryStream;
  Raw: TBytes;
begin
  if FStreamMode in [ismBuffering, ismChunking] then
  begin
    MemStream := TMemoryStream.Create;
    try
      MemStream.CopyFrom(AStream, 0);
      SetLength(Raw, MemStream.Size);
      if MemStream.Size > 0 then
        Move(MemStream.Memory^, Raw[0], MemStream.Size);
      Write(TEncoding.UTF8.GetString(Raw));
    finally
      MemStream.Free;
    end;
    Exit;
  end;

  MemStream := TMemoryStream.Create;
  MemStream.CopyFrom(AStream, 0);
  MemStream.Position := 0;
  FResponseInfo.ContentStream := MemStream;
  FResponseInfo.FreeContentStream := True;
end;

procedure TDextIndyHttpResponse.Json(const AJson: string);
begin
  if FStreamMode in [ismBuffering, ismChunking] then
  begin
    SetContentType('application/json; charset=utf-8');
    Write(AJson);
    Exit;
  end;

  FResponseInfo.ContentText := AJson;
  FResponseInfo.ContentType := 'application/json';
  FResponseInfo.CharSet := 'utf-8';
end;

procedure TDextIndyHttpResponse.Json(const AValue: TValue);
begin
  Json(TDextJson.Serialize(AValue));
end;

function TDextIndyHttpResponse.GetHtmx: IHtmxResponse;
begin
  if FHtmx = nil then
    FHtmx := THtmxResponse.Create(Self);
  Result := FHtmx;
end;

{ TDextIndyHttpContext }

constructor TDextIndyHttpContext.Create(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo;
  AResponseInfo: TIdHTTPResponseInfo; const AServices: IServiceProvider);
begin
  inherited Create;
  FContext := AContext;
  FRequest := TDextIndyHttpRequest.Create(ARequestInfo);
  FResponse := TDextIndyHttpResponse.Create(AContext, AResponseInfo);
  
  // Create a new scope for THIS request. 
  // All Scoped services (like DbContext) resolved from this provider 
  // will be isolated to this request and destroyed when this context is released.
  FScope := AServices.CreateScope;
  FServices := FScope.ServiceProvider;
  
end;

destructor TDextIndyHttpContext.Destroy;
begin
  FItems := nil;
  FRequest := nil;
  FResponse := nil;
  FServices := nil;
  FScope := nil; // This will trigger the disposal of all Scoped services for this request
  inherited;
end;

function TDextIndyHttpContext.GetRequest: IHttpRequest;
begin
  Result := FRequest;
end;

function TDextIndyHttpContext.GetResponse: IHttpResponse;
begin
  Result := FResponse;
end;

procedure TDextIndyHttpContext.SetResponse(const AValue: IHttpResponse);
begin
  FResponse := AValue;
end;

function TDextIndyHttpContext.GetServices: IServiceProvider;
begin
  Result := FServices;
end;

function TDextIndyHttpContext.GetSession: IStreamableSession;
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

procedure TDextIndyHttpContext.SetServices(const AValue: IServiceProvider);
begin
  FServices := AValue;
end;

function TDextIndyHttpContext.GetUser: IClaimsPrincipal;
begin
  Result := FUser;
end;

procedure TDextIndyHttpContext.SetUser(const AValue: IClaimsPrincipal);
begin
  FUser := AValue;
end;

function TDextIndyHttpContext.GetConnection: IDextServerConnection;
begin
  Result := nil;
end;

function TDextIndyHttpContext.GetItems: IDictionary<string, TValue>;
begin
  if FItems = nil then
    FItems := TCollections.CreateDictionary<string, TValue>;
  Result := FItems;
end;

procedure TDextIndyHttpContext.SetRouteParams(const AParams: TRouteValueDictionary);
var
  IndyRequest: TDextIndyHttpRequest;
begin
  if FRequest is TDextIndyHttpRequest then
  begin
    IndyRequest := TDextIndyHttpRequest(FRequest);
    IndyRequest.FRouteParams := AParams;
  end;
end;

end.
