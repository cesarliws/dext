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
{  Author:  Cesar Romero & Antigravity                                      }
{  Created: 2026-01-21                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.Net.Authentication;

interface

uses
  System.SysUtils,
  System.Classes,
  System.DateUtils,
  System.NetConsts,
  System.Net.HttpClient,
  System.Net.URLClient,
  System.NetEncoding,
  System.SyncObjs,
  System.JSON;

type
  /// <summary>Base interface for HTTP authentication providers.</summary>
  IAuthenticationProvider = interface
    ['{E1D2C3B4-A5B6-4C7D-8E9F-0A1B2C3D4E5F}']
    /// <summary>Returns the formatted value to be used in the Authorization header.</summary>
    function GetHeaderValue: string;
  end;

  /// <summary>Bearer Token authentication provider (RFC 6750), common in JWT.</summary>
  TBearerAuthProvider = class(TInterfacedObject, IAuthenticationProvider)
  private
    FToken: string;
  public
    constructor Create(const AToken: string);
    function GetHeaderValue: string;
  end;

  /// <summary>Basic authentication provider (RFC 7617) using Username and Password with Base64.</summary>
  TBasicAuthProvider = class(TInterfacedObject, IAuthenticationProvider)
  private
    FUsername: string;
    FPassword: string;
  public
    constructor Create(const AUsername, APassword: string);
    function GetHeaderValue: string;
  end;

  TApiKeyAuthProvider = class(TInterfacedObject, IAuthenticationProvider)
  private
    FKey: string;
    FValue: string;
  public
    constructor Create(const AKey, AValue: string);
    function GetHeaderValue: string;
    property Key: string read FKey;
  end;

  /// <summary>
  ///   OAuth 2.0 Client Credentials authentication provider (RFC 6749 Section 4.4).
  ///   Designed for machine-to-machine (M2M) communication where no user context is needed.
  ///   Automatically fetches and caches the access token, refreshing it when expired.
  /// </summary>
  /// <remarks>
  ///   Thread-safe: uses a critical section to protect concurrent token refresh.
  ///   The token is refreshed 30 seconds before actual expiration to avoid edge cases.
  /// </remarks>
  TOAuth2ClientCredentialsProvider = class(TInterfacedObject, IAuthenticationProvider)
  private
    FTokenUrl: string;
    FClientId: string;
    FClientSecret: string;
    FScope: string;
    FCachedToken: string;
    FExpiresAt: TDateTime;
    FLock: TCriticalSection;
    /// <summary>Fetches a new access token from the authorization server.</summary>
    procedure RefreshToken;
  public
    /// <summary>Creates an OAuth2 Client Credentials provider.</summary>
    /// <param name="ATokenUrl">The token endpoint URL (e.g. https://auth.example.com/oauth/token).</param>
    /// <param name="AClientId">The client identifier issued by the authorization server.</param>
    /// <param name="AClientSecret">The client secret issued by the authorization server.</param>
    /// <param name="AScope">Optional space-separated list of requested scopes.</param>
    constructor Create(const ATokenUrl, AClientId, AClientSecret: string;
      const AScope: string = '');
    destructor Destroy; override;
    function GetHeaderValue: string;
  end;

implementation
uses
  Dext.Net.RestClient, //-->Referência circular;
  Dext.Net.RestRequest;

{ TBearerAuthProvider }

constructor TBearerAuthProvider.Create(const AToken: string);
begin
  inherited Create;
  FToken := AToken;
end;

function TBearerAuthProvider.GetHeaderValue: string;
begin
  Result := 'Bearer ' + FToken;
end;

{ TBasicAuthProvider }

constructor TBasicAuthProvider.Create(const AUsername, APassword: string);
begin
  inherited Create;
  FUsername := AUsername;
  FPassword := APassword;
end;

function TBasicAuthProvider.GetHeaderValue: string;
var
  Auth: string;
begin
  Auth := FUsername + ':' + FPassword;
  Result := 'Basic ' + TNetEncoding.Base64.Encode(Auth).Replace(#13#10, '');
end;

{ TApiKeyAuthProvider }

constructor TApiKeyAuthProvider.Create(const AKey, AValue: string);
begin
  inherited Create;
  FKey := AKey;
  FValue := AValue;
end;

function TApiKeyAuthProvider.GetHeaderValue: string;
begin
  Result := FValue;
end;

{ TOAuth2ClientCredentialsProvider }

constructor TOAuth2ClientCredentialsProvider.Create(const ATokenUrl, AClientId, AClientSecret: string;
  const AScope: string);
begin
  inherited Create;
  FTokenUrl := ATokenUrl;
  FClientId := AClientId;
  FClientSecret := AClientSecret;
  FScope := AScope;
  FCachedToken := '';
  FExpiresAt := 0;
  FLock := TCriticalSection.Create;
end;

destructor TOAuth2ClientCredentialsProvider.Destroy;
begin
  FLock.Free;
  inherited;
end;

procedure TOAuth2ClientCredentialsProvider.RefreshToken;
var
  LBody: TStringStream;
  LBodyContent: string;
  LJson: TJSONObject;
  LExpiresIn: Integer;
  LRestClient: IRestResponse;
begin
  LBodyContent :=
    'grant_type=client_credentials' +
    '&client_id=' + TNetEncoding.URL.Encode(FClientId) +
    '&client_secret=' + TNetEncoding.URL.Encode(FClientSecret);

  if FScope <> '' then
    LBodyContent := LBodyContent + '&scope=' + TNetEncoding.URL.Encode(FScope);

  LBody := TStringStream.Create(LBodyContent, TEncoding.UTF8);
  try
    LRestClient := RestClient
      .ContentType(TDextContentType.ctFormUrlEncoded)
      .Post(FTokenUrl, LBody)
      .Await;
  finally
    LBody.Free;
  end;

  if (LRestClient.StatusCode < 200) or (LRestClient.StatusCode >= 300) then
    raise Exception.CreateFmt(
      'OAuth2 token request failed (HTTP %d): %s',
      [LRestClient.StatusCode, LRestClient.ContentString]);

  LJson := TJSONObject.ParseJSONValue(LRestClient.ContentString) as TJSONObject;
  try
    if LJson = nil then
      raise Exception.Create('Invalid token response.');

    FCachedToken := LJson.GetValue<string>('access_token','');

    LExpiresIn := LJson.GetValue<Integer>('expires_in',3600);
    // Set expiration with 30-second safety margin
    FExpiresAt := IncSecond(Now, LExpiresIn - 30);
  finally
    LJson.Free;
  end;

end;

function TOAuth2ClientCredentialsProvider.GetHeaderValue: string;
begin
  FLock.Enter;
  try
    if (FCachedToken = '') or (Now >= FExpiresAt) then
      RefreshToken;
    Result := 'Bearer ' + FCachedToken;
  finally
    FLock.Leave;
  end;
end;

end.
