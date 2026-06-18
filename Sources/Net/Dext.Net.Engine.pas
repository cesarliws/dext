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
unit Dext.Net.Engine;

interface

{$IF defined(DEXT_FORCE_INDY) or (CompilerVersion < 29.0)}
uses
  System.Classes,
  System.SysUtils,
  System.Generics.Collections;

type
  TDextNetHeader = record
    Name: string;
    Value: string;
    constructor Create(const AName, AValue: string);
  end;
  TDextNetHeaders = TArray<TDextNetHeader>;
{$ELSE}
uses
  System.Classes,
  System.SysUtils,
  System.Generics.Collections,
  System.Net.URLClient,
  System.Net.HttpClient;

type
  TDextNetHeader = System.Net.URLClient.TNetHeader;
  TDextNetHeaders = System.Net.URLClient.TNetHeaders;
{$ENDIF}

type
  IDextHttpResponse = interface
    ['{F2C4E6A8-0246-80AC-CE02-4680ACE02468}']
    function GetStatusCode: Integer;
    function GetStatusText: string;
    function GetContentStream: TStream;
    function GetHeaders: TDextNetHeaders;
  end;

  IDextHttpEngine = interface
    ['{B9D8A7C6-B5E4-4D3C-2B1A-0F9E8D7C6B5A}']
    procedure SetConnectionTimeout(AMilliseconds: Integer);
    procedure SetSendTimeout(AMilliseconds: Integer);
    procedure SetResponseTimeout(AMilliseconds: Integer);
    function Execute(const AMethod, AUrl: string; const ABody: TStream; const AHeaders: TDextNetHeaders): IDextHttpResponse;
  end;

function CreateHttpEngine: IDextHttpEngine;

implementation

{$IF defined(DEXT_FORCE_INDY) or (CompilerVersion < 29.0)}
uses
  IdHTTP,
  IdSSLOpenSSL,
  IdSSL;
{$ENDIF}

{$IF defined(DEXT_FORCE_INDY) or (CompilerVersion < 29.0)}
{ TDextNetHeader }

constructor TDextNetHeader.Create(const AName, AValue: string);
begin
  Name := AName;
  Value := AValue;
end;
{$ENDIF}

type
  TDextHttpResponseImpl = class(TInterfacedObject, IDextHttpResponse)
  private
    FStatusCode: Integer;
    FStatusText: string;
    FContentStream: TMemoryStream;
    FHeaders: TDextNetHeaders;
  public
    constructor Create(AStatusCode: Integer; const AStatusText: string; AStream: TStream; const AHeaders: TDextNetHeaders);
    destructor Destroy; override;
    function GetStatusCode: Integer;
    function GetStatusText: string;
    function GetContentStream: TStream;
    function GetHeaders: TDextNetHeaders;
  end;

{ TDextHttpResponseImpl }

constructor TDextHttpResponseImpl.Create(AStatusCode: Integer; const AStatusText: string; AStream: TStream; const AHeaders: TDextNetHeaders);
begin
  inherited Create;
  FStatusCode := AStatusCode;
  FStatusText := AStatusText;
  FHeaders := AHeaders;
  FContentStream := TMemoryStream.Create;
  if Assigned(AStream) then
  begin
    AStream.Position := 0;
    FContentStream.CopyFrom(AStream, AStream.Size);
    FContentStream.Position := 0;
  end;
end;

destructor TDextHttpResponseImpl.Destroy;
begin
  FContentStream.Free;
  inherited;
end;

function TDextHttpResponseImpl.GetContentStream: TStream;
begin
  Result := FContentStream;
end;

function TDextHttpResponseImpl.GetHeaders: TDextNetHeaders;
begin
  Result := FHeaders;
end;

function TDextHttpResponseImpl.GetStatusCode: Integer;
begin
  Result := FStatusCode;
end;

function TDextHttpResponseImpl.GetStatusText: string;
begin
  Result := FStatusText;
end;

{$IF defined(DEXT_FORCE_INDY) or (CompilerVersion < 29.0)}
type
  TDextIndyHttpEngine = class(TInterfacedObject, IDextHttpEngine)
  private
    FIdHttp: TIdHTTP;
  public
    constructor Create;
    destructor Destroy; override;
    procedure SetConnectionTimeout(AMilliseconds: Integer);
    procedure SetSendTimeout(AMilliseconds: Integer);
    procedure SetResponseTimeout(AMilliseconds: Integer);
    function Execute(const AMethod, AUrl: string; const ABody: TStream; const AHeaders: TDextNetHeaders): IDextHttpResponse;
  end;

{ TDextIndyHttpEngine }

constructor TDextIndyHttpEngine.Create;
begin
  inherited Create;
  FIdHttp := TIdHTTP.Create(nil);
  FIdHttp.HandleRedirects := True;
end;

destructor TDextIndyHttpEngine.Destroy;
begin
  FIdHttp.Free;
  inherited;
end;

procedure TDextIndyHttpEngine.SetConnectionTimeout(AMilliseconds: Integer);
begin
  FIdHttp.ConnectTimeout := AMilliseconds;
end;

procedure TDextIndyHttpEngine.SetSendTimeout(AMilliseconds: Integer);
begin
  // Indy does not have a separate send timeout, we map to ReadTimeout
  FIdHttp.ReadTimeout := AMilliseconds;
end;

procedure TDextIndyHttpEngine.SetResponseTimeout(AMilliseconds: Integer);
begin
  FIdHttp.ReadTimeout := AMilliseconds;
end;

function TDextIndyHttpEngine.Execute(const AMethod, AUrl: string; const ABody: TStream; const AHeaders: TDextNetHeaders): IDextHttpResponse;
var
  Header: TDextNetHeader;
  HeadersList: TList<TDextNetHeader>;
  i: Integer;
  Line: string;
  Pos: Integer;
  ResponseStream: TMemoryStream;
  SSLIOHandler: TIdSSLIOHandlerSocketOpenSSL;
begin
  FIdHttp.Request.CustomHeaders.Clear;
  for i := 0 to High(AHeaders) do
  begin
    if SameText(AHeaders[i].Name, 'User-Agent') then
      FIdHttp.Request.UserAgent := AHeaders[i].Value
    else if SameText(AHeaders[i].Name, 'Content-Type') then
      FIdHttp.Request.ContentType := AHeaders[i].Value
    else if SameText(AHeaders[i].Name, 'Accept') then
      FIdHttp.Request.Accept := AHeaders[i].Value
    else
      FIdHttp.Request.CustomHeaders.Values[AHeaders[i].Name] := AHeaders[i].Value;
  end;

  if AUrl.StartsWith('https', True) then
  begin
    if not Assigned(FIdHttp.IOHandler) then
    begin
      SSLIOHandler := TIdSSLIOHandlerSocketOpenSSL.Create(FIdHttp);
      SSLIOHandler.SSLOptions.Method := sslvTLSv1_2;
      SSLIOHandler.SSLOptions.Mode := sslmClient;
      FIdHttp.IOHandler := SSLIOHandler;
    end;
  end;

  ResponseStream := TMemoryStream.Create;
  try
    try
      if SameText(AMethod, 'GET') then
        FIdHttp.Get(AUrl, ResponseStream)
      else if SameText(AMethod, 'POST') then
        FIdHttp.Post(AUrl, ABody, ResponseStream)
      else if SameText(AMethod, 'PUT') then
        FIdHttp.Put(AUrl, ABody, ResponseStream)
      else if SameText(AMethod, 'DELETE') then
        FIdHttp.Delete(AUrl, ResponseStream)
      else
        FIdHttp.DoRequest(AMethod, AUrl, ABody, ResponseStream, []);
    except
      on E: Exception do
      begin
        ResponseStream.Free;
        raise;
      end;
    end;

    HeadersList := TList<TDextNetHeader>.Create;
    try
      for i := 0 to FIdHttp.Response.RawHeaders.Count - 1 do
      begin
        Line := FIdHttp.Response.RawHeaders[i];
        Pos := Line.IndexOf(':');
        if Pos > 0 then
          HeadersList.Add(TDextNetHeader.Create(
            Line.Substring(0, Pos).Trim,
            Line.Substring(Pos + 1).Trim
          ));
      end;
      Result := TDextHttpResponseImpl.Create(
        FIdHttp.ResponseCode,
        FIdHttp.ResponseText,
        ResponseStream,
        HeadersList.ToArray
      );
    finally
      HeadersList.Free;
      ResponseStream.Free;
    end;
  except
    raise;
  end;
end;

{$ELSE}

type
  TDextNetHttpEngine = class(TInterfacedObject, IDextHttpEngine)
  private
    FClient: THTTPClient;
  public
    constructor Create;
    destructor Destroy; override;
    procedure SetConnectionTimeout(AMilliseconds: Integer);
    procedure SetSendTimeout(AMilliseconds: Integer);
    procedure SetResponseTimeout(AMilliseconds: Integer);
    function Execute(const AMethod, AUrl: string; const ABody: TStream; const AHeaders: TDextNetHeaders): IDextHttpResponse;
  end;

{ TDextNetHttpEngine }

constructor TDextNetHttpEngine.Create;
begin
  inherited Create;
  FClient := THTTPClient.Create;
end;

destructor TDextNetHttpEngine.Destroy;
begin
  FClient.Free;
  inherited;
end;

procedure TDextNetHttpEngine.SetConnectionTimeout(AMilliseconds: Integer);
begin
  FClient.ConnectionTimeout := AMilliseconds;
end;

procedure TDextNetHttpEngine.SetSendTimeout(AMilliseconds: Integer);
begin
  FClient.SendTimeout := AMilliseconds;
end;

procedure TDextNetHttpEngine.SetResponseTimeout(AMilliseconds: Integer);
begin
  FClient.ResponseTimeout := AMilliseconds;
end;

function TDextNetHttpEngine.Execute(const AMethod, AUrl: string; const ABody: TStream; const AHeaders: TDextNetHeaders): IDextHttpResponse;
var
  i: Integer;
  NetHeadersList: TList<TNetHeader>;
  Response: IHTTPResponse;
begin
  NetHeadersList := TList<TNetHeader>.Create;
  try
    for i := 0 to High(AHeaders) do
      NetHeadersList.Add(TNetHeader.Create(AHeaders[i].Name, AHeaders[i].Value));

    Response := FClient.Execute(AMethod, TURI.Create(AUrl), ABody, nil, NetHeadersList.ToArray) as IHTTPResponse;
    Result := TDextHttpResponseImpl.Create(
      Response.StatusCode,
      Response.StatusText,
      Response.ContentStream,
      Response.Headers
    );
  finally
    NetHeadersList.Free;
  end;
end;

{$ENDIF}

function CreateHttpEngine: IDextHttpEngine;
begin
  {$IF defined(DEXT_FORCE_INDY) or (CompilerVersion < 29.0)}
  Result := TDextIndyHttpEngine.Create;
  {$ELSE}
  Result := TDextNetHttpEngine.Create;
  {$ENDIF}
end;

end.
