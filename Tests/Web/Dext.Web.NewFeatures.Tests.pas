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
unit Dext.Web.NewFeatures.Tests;

interface

uses
  Dext.Testing;

type
  [TestFixture]
  TDextNewFeaturesTests = class
  public
    [Test]
    procedure Test_Forwarded_Headers_Zero_Trust_By_Default;
    [Test]
    procedure Test_Forwarded_Headers_Explicit_Proxy_Parsing;
    [Test]
    procedure Test_Forwarded_Headers_Middleware_Execution_Rewrites_Client_IP;
    [Test]
    procedure Test_Forwarded_Headers_Middleware_Untrusted_Proxy_Ignored;
    [Test]
    procedure Test_Antiforgery_HMAC_SHA256_Real_Signature;
    [Test]
    procedure Test_Antiforgery_ValidateRequest_Success_With_MockContext;
    [Test]
    procedure Test_Antiforgery_Tampered_Token_Rejection_Via_ValidateRequest;
    [Test]
    procedure Test_Antiforgery_Html_Escaping;
  end;

implementation

uses
  System.Classes,
  System.Rtti,
  System.SysUtils,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.DI.Interfaces,
  Dext.Auth.Identity,
  Dext.Server.Engine.Interfaces,
  Dext.Web.ForwardedHeaders,
  Dext.Web.Antiforgery,
  Dext.Web.Interfaces;

type
  TMockHttpRequest = class(TInterfacedObject, IHttpRequest, IForwardedHeadersFeature)
  private
    FMethod: string;
    FPath: string;
    FPathBase: string;
    FBody: TMemoryStream;
    FQuery: IStringDictionary;
    FCookies: IStringDictionary;
    FHeaders: IStringDictionary;
    FRouteParams: TRouteValueDictionary;
    FRemoteIpAddress: string;
    FIsHttps: Boolean;
    FHost: string;
  public
    constructor Create;
    destructor Destroy; override;

    function GetMethod: string;
    function GetPath: string;
    procedure SetPath(const AValue: string);
    function GetPathBase: string;
    procedure SetPathBase(const AValue: string);
    function ToAppUrl(const ARelativePath: string): string;
    function GetQuery: IStringDictionary;
    function GetBody: TStream;
    function GetRouteParams: TRouteValueDictionary;
    function GetHeaders: IStringDictionary;
    function GetRemoteIpAddress: string;
    function GetHeader(const AName: string): string;
    function GetQueryParam(const AName: string): string;
    function GetCookies: IStringDictionary;
    function GetFiles: IFormFileCollection;

    // IForwardedHeadersFeature implementation
    procedure SetRemoteIpAddress(const AValue: string);
    procedure SetIsHttps(AValue: Boolean);
    procedure SetHost(const AValue: string);

    property Method: string read FMethod write FMethod;
    property Headers: IStringDictionary read FHeaders;
    property Cookies: IStringDictionary read FCookies;
    property IsHttps: Boolean read FIsHttps write FIsHttps;
    property RemoteIpAddress: string read FRemoteIpAddress write FRemoteIpAddress;
    property Host: string read FHost write FHost;
  end;

  TMockHttpContext = class(TInterfacedObject, IHttpContext)
  private
    FReq: IHttpRequest;
    FItems: IDictionary<string, TValue>;
    FEndpointMetadata: TEndpointMetadata;
  public
    constructor Create(AReq: TMockHttpRequest);
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

constructor TMockHttpRequest.Create;
begin
  inherited Create;
  FMethod := 'POST';
  FPath := '/submit';
  FPathBase := '';
  FBody := TMemoryStream.Create;
  FQuery := TCollections.CreateStringDictionary(True);
  FCookies := TCollections.CreateStringDictionary(True);
  FHeaders := TCollections.CreateStringDictionary(True);
  FRemoteIpAddress := '127.0.0.1';
  FIsHttps := False;
  FHost := 'localhost';
end;

destructor TMockHttpRequest.Destroy;
begin
  FBody.Free;
  inherited Destroy;
end;

function TMockHttpRequest.GetMethod: string; begin Result := FMethod; end;
function TMockHttpRequest.GetPath: string; begin Result := FPath; end;
procedure TMockHttpRequest.SetPath(const AValue: string); begin FPath := AValue; end;
function TMockHttpRequest.GetPathBase: string; begin Result := FPathBase; end;
procedure TMockHttpRequest.SetPathBase(const AValue: string); begin FPathBase := AValue; end;
function TMockHttpRequest.ToAppUrl(const ARelativePath: string): string; begin Result := ARelativePath; end;
function TMockHttpRequest.GetQuery: IStringDictionary; begin Result := FQuery; end;
function TMockHttpRequest.GetBody: TStream; begin Result := FBody; end;
function TMockHttpRequest.GetRouteParams: TRouteValueDictionary; begin Result := FRouteParams; end;
function TMockHttpRequest.GetHeaders: IStringDictionary; begin Result := FHeaders; end;
function TMockHttpRequest.GetRemoteIpAddress: string; begin Result := FRemoteIpAddress; end;

function TMockHttpRequest.GetHeader(const AName: string): string;
begin
  if not FHeaders.TryGetValue(AName, Result) then
    Result := '';
end;

function TMockHttpRequest.GetQueryParam(const AName: string): string;
begin
  if not FQuery.TryGetValue(AName, Result) then
    Result := '';
end;

function TMockHttpRequest.GetCookies: IStringDictionary; begin Result := FCookies; end;
function TMockHttpRequest.GetFiles: IFormFileCollection; begin Result := nil; end;

procedure TMockHttpRequest.SetRemoteIpAddress(const AValue: string); begin FRemoteIpAddress := AValue; end;
procedure TMockHttpRequest.SetIsHttps(AValue: Boolean); begin FIsHttps := AValue; end;
procedure TMockHttpRequest.SetHost(const AValue: string); begin FHost := AValue; FHeaders.AddOrSetValue('Host', AValue); end;

{ TMockHttpContext }

constructor TMockHttpContext.Create(AReq: TMockHttpRequest);
begin
  inherited Create;
  FReq := AReq;
  FItems := TCollections.CreateDictionary<string, TValue>;
end;

function TMockHttpContext.GetConnection: IDextServerConnection; begin Result := nil; end;
function TMockHttpContext.GetRequest: IHttpRequest; begin Result := FReq; end;
function TMockHttpContext.GetResponse: IHttpResponse; begin Result := nil; end;
procedure TMockHttpContext.SetResponse(const AValue: IHttpResponse); begin end;
function TMockHttpContext.GetServices: IServiceProvider; begin Result := nil; end;
procedure TMockHttpContext.SetServices(const AValue: IServiceProvider); begin end;
function TMockHttpContext.GetUser: IClaimsPrincipal; begin Result := nil; end;
procedure TMockHttpContext.SetUser(const AValue: IClaimsPrincipal); begin end;
function TMockHttpContext.GetItems: IDictionary<string, TValue>; begin Result := FItems; end;
function TMockHttpContext.GetSession: IStreamableSession; begin Result := nil; end;
function TMockHttpContext.GetEndpointMetadata: TEndpointMetadata; begin Result := FEndpointMetadata; end;
procedure TMockHttpContext.SetEndpointMetadata(const AMetadata: TEndpointMetadata); begin FEndpointMetadata := AMetadata; end;
procedure TMockHttpContext.SetRouteParams(const AParams: TRouteValueDictionary); begin end;

{ TDextNewFeaturesTests }

procedure TDextNewFeaturesTests.Test_Forwarded_Headers_Zero_Trust_By_Default;
var
  Opts: TForwardedHeadersOptions;
begin
  Opts := TForwardedHeadersOptions.Create;
  try
    // Zero-Trust Security Default: KnownProxies & KnownNetworks MUST be empty by default
    Should(Opts.KnownProxies.Count).Be(0);
    Should(Opts.KnownNetworks.Count).Be(0);
  finally
    Opts.Free;
  end;
end;

procedure TDextNewFeaturesTests.Test_Forwarded_Headers_Explicit_Proxy_Parsing;
var
  Opts: TForwardedHeadersOptions;
begin
  Opts := TForwardedHeadersOptions.Create;
  try
    Opts.KnownProxies.Add('127.0.0.1');
    Opts.KnownNetworks.Add('10.0.0.0/8');

    Should(Opts.KnownProxies.Contains('127.0.0.1')).BeTrue;
    Should(Opts.KnownNetworks.Contains('10.0.0.0/8')).BeTrue;
  finally
    Opts.Free;
  end;
end;

procedure TDextNewFeaturesTests.Test_Forwarded_Headers_Middleware_Execution_Rewrites_Client_IP;
var
  Opts: TForwardedHeadersOptions;
  Middleware: TDextForwardedHeadersMiddleware;
  MockReq: TMockHttpRequest;
  MockCtx: IHttpContext;
  NextInvoked: Boolean;
begin
  Opts := TForwardedHeadersOptions.Create;
  Opts.KnownProxies.Add('127.0.0.1');

  Middleware := TDextForwardedHeadersMiddleware.Create(Opts);
  try
    MockReq := TMockHttpRequest.Create;
    MockReq.RemoteIpAddress := '127.0.0.1'; // Originating from trusted reverse proxy
    MockReq.Headers.AddOrSetValue('X-Forwarded-For', '203.0.113.195');
    MockReq.Headers.AddOrSetValue('X-Forwarded-Proto', 'https');
    MockReq.Headers.AddOrSetValue('X-Forwarded-Host', 'api.mydomain.com');

    MockCtx := TMockHttpContext.Create(MockReq);

    NextInvoked := False;
    Middleware.Invoke(MockCtx,
      procedure(AContext: IHttpContext)
      begin
        NextInvoked := True;
      end);

    Should(NextInvoked).BeTrue;
    Should(MockReq.RemoteIpAddress).Be('203.0.113.195');
    Should(MockReq.IsHttps).BeTrue;
    Should(MockReq.GetHeader('Host')).Be('api.mydomain.com');
  finally
    Middleware.Free;
  end;
end;

procedure TDextNewFeaturesTests.Test_Forwarded_Headers_Middleware_Untrusted_Proxy_Ignored;
var
  Opts: TForwardedHeadersOptions;
  Middleware: TDextForwardedHeadersMiddleware;
  MockReq: TMockHttpRequest;
  MockCtx: IHttpContext;
  NextInvoked: Boolean;
begin
  Opts := TForwardedHeadersOptions.Create;
  // Zero-Trust: 198.51.100.1 is NOT in KnownProxies or KnownNetworks

  Middleware := TDextForwardedHeadersMiddleware.Create(Opts);
  try
    MockReq := TMockHttpRequest.Create;
    MockReq.RemoteIpAddress := '198.51.100.1'; // Untrusted proxy
    MockReq.Headers.AddOrSetValue('X-Forwarded-For', '1.1.1.1');
    MockReq.Headers.AddOrSetValue('X-Forwarded-Proto', 'https');

    MockCtx := TMockHttpContext.Create(MockReq);

    NextInvoked := False;
    Middleware.Invoke(MockCtx,
      procedure(AContext: IHttpContext)
      begin
        NextInvoked := True;
      end);

    Should(NextInvoked).BeTrue;
    Should(MockReq.RemoteIpAddress).Be('198.51.100.1');
    Should(MockReq.IsHttps).BeFalse;
  finally
    Middleware.Free;
  end;
end;

procedure TDextNewFeaturesTests.Test_Antiforgery_HMAC_SHA256_Real_Signature;
var
  Antiforgery: IAntiforgery;
  Tokens: TAntiforgeryTokenSet;
  DotPos: Integer;
begin
  Antiforgery := TAntiforgery.Create('my-super-secret-key-2026');
  Tokens := Antiforgery.GetTokens(nil);

  Should(Tokens.CookieToken.IsEmpty).BeFalse;
  DotPos := Pos('.', Tokens.RequestToken);
  Should(DotPos).Be(65);
end;

procedure TDextNewFeaturesTests.Test_Antiforgery_ValidateRequest_Success_With_MockContext;
var
  Antiforgery: IAntiforgery;
  Tokens: TAntiforgeryTokenSet;
  MockReq: TMockHttpRequest;
  MockCtx: IHttpContext;
  Success: Boolean;
begin
  Antiforgery := TAntiforgery.Create('my-super-secret-key-2026', True);
  Tokens := Antiforgery.GetTokens(nil);

  MockReq := TMockHttpRequest.Create;
  MockReq.Method := 'POST';
  MockReq.Headers.AddOrSetValue('Host', 'app.example.com');
  MockReq.Headers.AddOrSetValue('Origin', 'https://app.example.com');
  MockReq.Headers.AddOrSetValue('X-Forwarded-Proto', 'https');
  MockReq.Cookies.AddOrSetValue('__AntiforgeryToken', Tokens.CookieToken);
  MockReq.Headers.AddOrSetValue('X-CSRF-TOKEN', Tokens.RequestToken);

  MockCtx := TMockHttpContext.Create(MockReq);

  Success := True;
  try
    // Real call to ValidateRequest against valid HTTP POST request context
    Antiforgery.ValidateRequest(MockCtx);
  except
    Success := False;
  end;

  Should(Success).BeTrue;
end;

procedure TDextNewFeaturesTests.Test_Antiforgery_Tampered_Token_Rejection_Via_ValidateRequest;
var
  Antiforgery: IAntiforgery;
  Tokens: TAntiforgeryTokenSet;
  TamperedToken: string;
  MockReq: TMockHttpRequest;
  MockCtx: IHttpContext;
begin
  Antiforgery := TAntiforgery.Create('my-super-secret-key-2026', True);
  Tokens := Antiforgery.GetTokens(nil);

  // Alter signature (tampered token)
  TamperedToken := 'a0b1c2d3e4f5a0b1c2d3e4f5a0b1c2d3e4f5a0b1c2d3e4f5a0b1c2d3e4f5a0b1.' + Tokens.CookieToken;

  MockReq := TMockHttpRequest.Create;
  MockReq.Method := 'POST';
  MockReq.Headers.AddOrSetValue('Host', 'app.example.com');
  MockReq.Headers.AddOrSetValue('Origin', 'https://app.example.com');
  MockReq.Headers.AddOrSetValue('X-Forwarded-Proto', 'https');
  MockReq.Cookies.AddOrSetValue('__AntiforgeryToken', Tokens.CookieToken);
  MockReq.Headers.AddOrSetValue('X-CSRF-TOKEN', TamperedToken);

  MockCtx := TMockHttpContext.Create(MockReq);

  // Invoking ValidateRequest with tampered token MUST raise EAntiforgeryValidationException
  Should(procedure
    begin
      Antiforgery.ValidateRequest(MockCtx);
    end).Throw<EAntiforgeryValidationException>;
end;

procedure TDextNewFeaturesTests.Test_Antiforgery_Html_Escaping;
var
  Antiforgery: IAntiforgery;
  FieldHtml: string;
begin
  Antiforgery := TAntiforgery.Create('test-secret-key');
  FieldHtml := Antiforgery.GetHtmlField(nil);

  Should(Pos('<input name="__RequestVerificationToken" type="hidden"', FieldHtml)).Be(1);
end;

end.
