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
{  Author:  Cesar Romero & Antigravity                                      }
{  Created: 2026-08-10                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.Web.Antiforgery;

interface

uses
  System.SysUtils,
  Dext.Collections.Dict,
  Dext.Web.Interfaces;

type
  /// <summary>
  ///   Exception thrown when anti-forgery validation fails.
  /// </summary>
  EAntiforgeryValidationException = class(Exception);

  /// <summary>
  ///   Pair of tokens used for Cross-Site Request Forgery protection.
  /// </summary>
  TAntiforgeryTokenSet = record
    CookieToken: string;
    RequestToken: string;
    FormFieldName: string;
    HeaderName: string;
    constructor Create(const ACookieToken, ARequestToken, AFormFieldName, AHeaderName: string);
  end;

  /// <summary>
  ///   Interface for Anti-Forgery token generator and validator (CSRF Protection).
  /// </summary>
  IAntiforgery = interface
    ['{E1D2C3B4-A5B6-7890-1234-56789ABCDEF0}']
    function GetTokens(AContext: IHttpContext): TAntiforgeryTokenSet;
    procedure ValidateRequest(AContext: IHttpContext);
    function GetHtmlField(AContext: IHttpContext): string;
  end;

  /// <summary>
  ///   Implementation of IAntiforgery using HMAC-SHA256 tokens and constant-time comparison.
  /// </summary>
  TAntiforgery = class(TInterfacedObject, IAntiforgery)
  private
    FSecretKey: string;
    FRequireHeaderOrOriginOnHttps: Boolean;
    function GenerateRandomToken: string;
    function ComputeHmacSha256Token(const ACookieToken: string): string;
    function FixedTimeEquals(const Left, Right: string): Boolean;
    function IsHex64(const AStr: string): Boolean;
    function ExtractHostFromUrl(const AUrl: string): string;
    function NormalizeHostAndPort(const AHostPort: string; AIsHttps: Boolean): string;
    function DetectIsHttps(Req: IHttpRequest): Boolean;
    function DetectHostHeader(Req: IHttpRequest): string;
  public
    constructor Create(const ASecretKey: string = ''; const ARequireHeaderOrOriginOnHttps: Boolean = True);
    
    function GetTokens(AContext: IHttpContext): TAntiforgeryTokenSet;
    procedure ValidateRequest(AContext: IHttpContext);
    function GetHtmlField(AContext: IHttpContext): string;
    function HtmlEscape(const AStr: string): string;
  end;

implementation

uses
  System.Hash,
  System.StrUtils,
  Dext.Types.UUID;

{ TAntiforgeryTokenSet }

constructor TAntiforgeryTokenSet.Create(const ACookieToken, ARequestToken, AFormFieldName, AHeaderName: string);
begin
  CookieToken := ACookieToken;
  RequestToken := ARequestToken;
  FormFieldName := AFormFieldName;
  HeaderName := AHeaderName;
end;

{ TAntiforgery }

constructor TAntiforgery.Create(const ASecretKey: string; const ARequireHeaderOrOriginOnHttps: Boolean);
begin
  inherited Create;
  FRequireHeaderOrOriginOnHttps := ARequireHeaderOrOriginOnHttps;
  if ASecretKey.IsEmpty then
    FSecretKey := TUUID.NewV7.ToString
  else
    FSecretKey := ASecretKey;
end;

function TAntiforgery.GenerateRandomToken: string;
begin
  Result := TUUID.NewV7.ToString;
end;

function TAntiforgery.ComputeHmacSha256Token(const ACookieToken: string): string;
var
  HmacHex: string;
begin
  HmacHex := THashSHA2.GetHMAC(ACookieToken, FSecretKey);
  Result := LowerCase(HmacHex) + '.' + ACookieToken;
end;

function TAntiforgery.FixedTimeEquals(const Left, Right: string): Boolean;
var
  i, Diff: Integer;
  LeftLen, RightLen: Integer;
begin
  LeftLen := Length(Left);
  RightLen := Length(Right);
  Diff := LeftLen xor RightLen;

  for i := 1 to LeftLen do
  begin
    if i <= RightLen then
      Diff := Diff or (Ord(Left[i]) xor Ord(Right[i]))
    else
      Diff := Diff or Ord(Left[i]);
  end;

  Result := (Diff = 0);
end;

function TAntiforgery.HtmlEscape(const AStr: string): string;
begin
  Result := StringReplace(AStr, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
  Result := StringReplace(Result, '''', '&#39;', [rfReplaceAll]);
end;

function TAntiforgery.IsHex64(const AStr: string): Boolean;
var
  ch: Char;
begin
  if Length(AStr) <> 64 then
    Exit(False);

  for ch in AStr do
  begin
    if not CharInSet(ch, ['0'..'9', 'a'..'f', 'A'..'F']) then
      Exit(False);
  end;
  Result := True;
end;

function TAntiforgery.ExtractHostFromUrl(const AUrl: string): string;
var
  SchemePos, PathPos: Integer;
begin
  Result := Trim(AUrl);
  if Result.IsEmpty then
    Exit;

  SchemePos := Pos('://', Result);
  if SchemePos > 0 then
    Delete(Result, 1, SchemePos + 2);

  PathPos := Pos('/', Result);
  if PathPos > 0 then
    Result := Copy(Result, 1, PathPos - 1);

  PathPos := Pos('?', Result);
  if PathPos > 0 then
    Result := Copy(Result, 1, PathPos - 1);
end;

function TAntiforgery.NormalizeHostAndPort(const AHostPort: string; AIsHttps: Boolean): string;
var
  ColonPos, CloseBracketPos: Integer;
  HostPart, PortPart: string;
begin
  Result := Trim(AHostPort);
  if Result.IsEmpty then
    Exit;

  if Result.StartsWith('[') then
  begin
    CloseBracketPos := Pos(']', Result);
    if CloseBracketPos > 0 then
    begin
      HostPart := Copy(Result, 1, CloseBracketPos);
      PortPart := Copy(Result, CloseBracketPos + 1, Length(Result));
      if PortPart.StartsWith(':') then
        Delete(PortPart, 1, 1)
      else
        PortPart := '';
    end
    else
      HostPart := Result;
  end
  else
  begin
    ColonPos := Pos(':', Result);
    if ColonPos > 0 then
    begin
      HostPart := Copy(Result, 1, ColonPos - 1);
      PortPart := Copy(Result, ColonPos + 1, Length(Result));
    end
    else
      HostPart := Result;
  end;

  if (PortPart = '80') and not AIsHttps then
    PortPart := ''
  else if (PortPart = '443') and AIsHttps then
    PortPart := '';

  if not PortPart.IsEmpty then
    Result := HostPart + ':' + PortPart
  else
    Result := HostPart;
end;

function TAntiforgery.DetectIsHttps(Req: IHttpRequest): Boolean;
var
  ProtoVal: string;
begin
  Result := False;
  if (Req = nil) or (Req.Headers = nil) then
    Exit;

  if Req.Headers.TryGetValue('X-Forwarded-Proto', ProtoVal) then
    Exit(SameText(Trim(ProtoVal), 'https'));

  if Req.Headers.TryGetValue('Forwarded', ProtoVal) and ContainsText(ProtoVal, 'proto=https') then
    Exit(True);

  if Req.Headers.TryGetValue('Origin', ProtoVal) then
    Exit(ProtoVal.StartsWith('https://', True));

  if Req.Headers.TryGetValue('Referer', ProtoVal) then
    Exit(ProtoVal.StartsWith('https://', True));
end;

function TAntiforgery.DetectHostHeader(Req: IHttpRequest): string;
begin
  Result := '';
  if (Req <> nil) and (Req.Headers <> nil) then
  begin
    if not Req.Headers.TryGetValue('Host', Result) then
      Req.Headers.TryGetValue('X-Forwarded-Host', Result);
  end;
end;

function TAntiforgery.GetTokens(AContext: IHttpContext): TAntiforgeryTokenSet;
var
  CookieToken, ReqToken: string;
  Req: IHttpRequest;
  CookieHeader: string;
begin
  CookieToken := '';

  if (AContext <> nil) and (AContext.Request <> nil) then
  begin
    Req := AContext.Request;
    if Req.Cookies <> nil then
      Req.Cookies.TryGetValue('__AntiforgeryToken', CookieToken);

    if CookieToken.IsEmpty and (Req.Headers <> nil) and Req.Headers.TryGetValue('Cookie', CookieHeader) then
    begin
      // Extract __AntiforgeryToken cookie if present
      if ContainsText(CookieHeader, '__AntiforgeryToken=') then
      begin
        CookieToken := Copy(CookieHeader, Pos('__AntiforgeryToken=', CookieHeader) + 19, 36);
      end;
    end;
  end;

  if CookieToken.IsEmpty then
    CookieToken := GenerateRandomToken;

  ReqToken := ComputeHmacSha256Token(CookieToken);

  Result := TAntiforgeryTokenSet.Create(
    CookieToken,
    ReqToken,
    '__RequestVerificationToken',
    'X-CSRF-TOKEN'
  );
end;

procedure TAntiforgery.ValidateRequest(AContext: IHttpContext);
var
  Req: IHttpRequest;
  CookieHeader, CookieToken: string;
  HeaderToken: string;
  SubmittedToken: string;
  SigPart, PayloadPart: string;
  ExpectedToken: string;
  IsHttps: Boolean;
  HostHeader: string;
  OriginHeader, RefererHeader: string;
  OriginHost, RefererHost: string;
  DotPos: Integer;
begin
  if (AContext = nil) or (AContext.Request = nil) then
    raise EAntiforgeryValidationException.Create('Invalid HTTP context');

  Req := AContext.Request;

  // Safe HTTP verb check: GET, HEAD, OPTIONS, TRACE are safe methods
  if SameText(Req.Method, 'GET') or SameText(Req.Method, 'HEAD') or
     SameText(Req.Method, 'OPTIONS') or SameText(Req.Method, 'TRACE') then
    Exit;

  IsHttps := DetectIsHttps(Req);
  HostHeader := DetectHostHeader(Req);

  // 1. Strict Origin/Referer verification on HTTPS
  if IsHttps then
  begin
    OriginHeader := '';
    RefererHeader := '';

    if Req.Headers <> nil then
    begin
      Req.Headers.TryGetValue('Origin', OriginHeader);
      Req.Headers.TryGetValue('Referer', RefererHeader);
    end;

    if FRequireHeaderOrOriginOnHttps and OriginHeader.IsEmpty and RefererHeader.IsEmpty then
      raise EAntiforgeryValidationException.Create('HTTPS anti-forgery policy requires Origin or Referer header');

    if not OriginHeader.IsEmpty then
    begin
      OriginHost := NormalizeHostAndPort(ExtractHostFromUrl(OriginHeader), True);
      if not SameText(OriginHost, NormalizeHostAndPort(HostHeader, True)) then
        raise EAntiforgeryValidationException.Create('Origin header host mismatch');
    end
    else if not RefererHeader.IsEmpty then
    begin
      RefererHost := NormalizeHostAndPort(ExtractHostFromUrl(RefererHeader), True);
      if not SameText(RefererHost, NormalizeHostAndPort(HostHeader, True)) then
        raise EAntiforgeryValidationException.Create('Referer header host mismatch');
    end;
  end;

  // 2. Extract Cookie Token
  CookieToken := '';
  if Req.Cookies <> nil then
    Req.Cookies.TryGetValue('__AntiforgeryToken', CookieToken);

  if CookieToken.IsEmpty and (Req.Headers <> nil) and Req.Headers.TryGetValue('Cookie', CookieHeader) then
  begin
    if ContainsText(CookieHeader, '__AntiforgeryToken=') then
      CookieToken := Copy(CookieHeader, Pos('__AntiforgeryToken=', CookieHeader) + 19, 36);
  end;

  if CookieToken.IsEmpty then
    raise EAntiforgeryValidationException.Create('Missing anti-forgery cookie token');

  // 3. Extract Submitted Request Token from Header or Form
  SubmittedToken := '';
  if (Req.Headers <> nil) and Req.Headers.TryGetValue('X-CSRF-TOKEN', HeaderToken) then
    SubmittedToken := HeaderToken;

  if SubmittedToken.IsEmpty then
    raise EAntiforgeryValidationException.Create('Missing anti-forgery request token');

  // 4. Validate Token Format ([64-hex-signature].[payload])
  DotPos := Pos('.', SubmittedToken);
  if DotPos <> 65 then
    raise EAntiforgeryValidationException.Create('Invalid anti-forgery token format');

  SigPart := Copy(SubmittedToken, 1, 64);
  PayloadPart := Copy(SubmittedToken, 66, Length(SubmittedToken));

  if not IsHex64(SigPart) or not SameText(PayloadPart, CookieToken) then
    raise EAntiforgeryValidationException.Create('Anti-forgery token payload mismatch');

  // 5. Constant-time signature verification
  ExpectedToken := ComputeHmacSha256Token(CookieToken);
  if not FixedTimeEquals(SubmittedToken, ExpectedToken) then
    raise EAntiforgeryValidationException.Create('Anti-forgery token signature invalid (tampered token)');
end;

function TAntiforgery.GetHtmlField(AContext: IHttpContext): string;
var
  Tokens: TAntiforgeryTokenSet;
begin
  Tokens := GetTokens(AContext);
  Result := Format(
    '<input name="%s" type="hidden" value="%s" />',
    [HtmlEscape(Tokens.FormFieldName), HtmlEscape(Tokens.RequestToken)]
  );
end;

end.
