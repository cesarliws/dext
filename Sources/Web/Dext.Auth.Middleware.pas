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
unit Dext.Auth.Middleware;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Rtti,
  Dext.Web.Interfaces,
  Dext.Auth.JWT,
  Dext.Auth.Identity;

type
  /// <summary>
  ///   Middleware that validates JWT tokens and populates the User principal.
  /// </summary>
  TJwtAuthenticationMiddleware = class(TInterfacedObject, IMiddleware)
  private
    FOptions: TJwtOptions;
    FTokenHandler: IJwtTokenHandler;
    FTokenPrefix: string; // e.g., "Bearer "
    
    function ExtractToken(const AAuthHeader: string): string;
    function CreatePrincipal(const AClaims: TArray<TClaim>): IClaimsPrincipal;
  public
    /// <summary>
    ///   Creates a new instance of TJwtAuthenticationMiddleware with default Bearer prefix.
    /// </summary>
    constructor Create(const AOptions: TJwtOptions); overload;
    /// <summary>
    ///   Creates a new instance of TJwtAuthenticationMiddleware with a custom token prefix.
    /// </summary>
    constructor Create(const AOptions: TJwtOptions; const ATokenPrefix: string); overload;
    
    /// <summary>
    ///   Invokes the middleware, validating the JWT and setting the HTTP context User if valid.
    /// </summary>
    procedure Invoke(AContext: IHttpContext; ANext: TRequestDelegate);
  end;

  /// <summary>
  ///   Extension methods for adding JWT authentication to the application pipeline.
  /// </summary>
  TApplicationBuilderJwtExtensions = class
  public
    /// <summary>
    ///   Adds JWT authentication middleware with the specified options.
    /// </summary>
    class function UseJwtAuthentication(const ABuilder: IApplicationBuilder; const AOptions: TJwtOptions): IApplicationBuilder; overload; static;
    
    /// <summary>
    ///   Adds JWT authentication middleware configured with a builder.
    /// </summary>
    class function UseJwtAuthentication(const ABuilder: IApplicationBuilder; const ASecretKey: string; AConfigurator: TJwtBuilderProc): IApplicationBuilder; overload; static;

    /// <summary>
    ///   Adds JWT authentication middleware using a fluent builder directly.
    /// </summary>
    class function UseJwtAuthentication(const ABuilder: IApplicationBuilder; const AJwtBuilder: TJwtOptionsBuilder): IApplicationBuilder; overload; static;

    /// <summary>
    ///   Configures JWT Authentication for Google OAuth2 using OIDC.
    /// </summary>
    class function UseGoogleAuthentication(const ABuilder: IApplicationBuilder; const AClientId, APublicKeyJwk: string): IApplicationBuilder; static;
    
    /// <summary>
    ///   Configures JWT Authentication for Microsoft Entra ID (Azure AD).
    /// </summary>
    class function UseEntraIdAuthentication(const ABuilder: IApplicationBuilder; const ATenantId, AClientId, APublicKeyJwk: string): IApplicationBuilder; static;

    /// <summary>
    ///   Configures JWT Authentication for a custom Keycloak server.
    /// </summary>
    class function UseKeycloakAuthentication(const ABuilder: IApplicationBuilder; const AServerUrl, ARealm, AClientId, APublicKeyJwk: string): IApplicationBuilder; static;
  end;

implementation

uses
  System.StrUtils;

{ TJwtAuthenticationMiddleware }

constructor TJwtAuthenticationMiddleware.Create(const AOptions: TJwtOptions);
begin
  Create(AOptions, 'Bearer ');
end;

constructor TJwtAuthenticationMiddleware.Create(const AOptions: TJwtOptions; const ATokenPrefix: string);
begin
  inherited Create;
  FOptions := AOptions;
  FTokenPrefix := ATokenPrefix;
  FTokenHandler := TJwtTokenHandler.Create(
    AOptions.SecretKey,
    AOptions.Issuer,
    AOptions.Audience,
    AOptions.ExpirationMinutes
  );
end;

function TJwtAuthenticationMiddleware.ExtractToken(const AAuthHeader: string): string;
begin
  Result := AAuthHeader;
  
  if FTokenPrefix <> '' then
  begin
    if StartsText(FTokenPrefix, AAuthHeader) then
      Result := Copy(AAuthHeader, Length(FTokenPrefix) + 1, MaxInt)
    else
      Result := '';
  end;
end;

function TJwtAuthenticationMiddleware.CreatePrincipal(const AClaims: TArray<TClaim>): IClaimsPrincipal;
var
  userName: string;
  claim: TClaim;
  identity: IIdentity;
begin
  userName := '';
  for claim in AClaims do
  begin
    if SameText(claim.ClaimType, TClaimTypes.Name) then
    begin
      userName := claim.Value;
      Break;
    end;
  end;
  
  if userName = '' then
  begin
    for claim in AClaims do
    begin
      if SameText(claim.ClaimType, TClaimTypes.NameIdentifier) then
      begin
        userName := claim.Value;
        Break;
      end;
    end;
  end;
  
  identity := TClaimsIdentity.Create(userName, 'JWT');
  Result := TClaimsPrincipal.Create(identity, AClaims);
end;

procedure TJwtAuthenticationMiddleware.Invoke(AContext: IHttpContext; ANext: TRequestDelegate);
var
  authHeader: string;
  token: string;
  validationResult: TJwtValidationResult;
  principal: IClaimsPrincipal;
begin
  if AContext.Request.Headers.ContainsKey('Authorization') then
  begin
    authHeader := AContext.Request.Headers['Authorization'];
    token := ExtractToken(authHeader);
    
    if token <> '' then
    begin
      validationResult := FTokenHandler.ValidateToken(token);
      
      if validationResult.IsValid then
      begin
        principal := CreatePrincipal(validationResult.Claims);
        AContext.User := principal;
      end;
    end;
  end;
  
  ANext(AContext);
end;

{ TApplicationBuilderJwtExtensions }

class function TApplicationBuilderJwtExtensions.UseJwtAuthentication(
  const ABuilder: IApplicationBuilder; const AOptions: TJwtOptions): IApplicationBuilder;
begin
  Result := ABuilder.UseMiddleware(TJwtAuthenticationMiddleware, AOptions);
end;

class function TApplicationBuilderJwtExtensions.UseJwtAuthentication(
  const ABuilder: IApplicationBuilder; const ASecretKey: string; 
  AConfigurator: TJwtBuilderProc): IApplicationBuilder;
var
  builder: TJwtOptionsBuilder;
begin
  builder := TJwtOptionsBuilder.Create(ASecretKey);
  if Assigned(AConfigurator) then
    AConfigurator(builder);
  
  Result := ABuilder.UseMiddleware(TJwtAuthenticationMiddleware, builder.Build);
end;

class function TApplicationBuilderJwtExtensions.UseJwtAuthentication(const ABuilder: IApplicationBuilder; const AJwtBuilder: TJwtOptionsBuilder): IApplicationBuilder;
begin
  Result := ABuilder.UseMiddleware(TJwtAuthenticationMiddleware, AJwtBuilder.Build);
end;

class function TApplicationBuilderJwtExtensions.UseGoogleAuthentication(
  const ABuilder: IApplicationBuilder; const AClientId, APublicKeyJwk: string): IApplicationBuilder;
var
  options: TJwtOptions;
begin
  options := TJwtOptions.Create('');
  options.Algorithm := 'RS256';
  options.Issuer := 'https://accounts.google.com';
  options.Audience := AClientId;
  options.PublicKey := APublicKeyJwk;
  Result := ABuilder.UseMiddleware(TJwtAuthenticationMiddleware, options);
end;

class function TApplicationBuilderJwtExtensions.UseEntraIdAuthentication(
  const ABuilder: IApplicationBuilder; const ATenantId, AClientId, APublicKeyJwk: string): IApplicationBuilder;
var
  options: TJwtOptions;
begin
  options := TJwtOptions.Create('');
  options.Algorithm := 'RS256';
  options.Issuer := 'https://login.microsoftonline.com/' + ATenantId + '/v2.0';
  options.Audience := AClientId;
  options.PublicKey := APublicKeyJwk;
  Result := ABuilder.UseMiddleware(TJwtAuthenticationMiddleware, options);
end;

class function TApplicationBuilderJwtExtensions.UseKeycloakAuthentication(
  const ABuilder: IApplicationBuilder; const AServerUrl, ARealm, AClientId, APublicKeyJwk: string): IApplicationBuilder;
var
  options: TJwtOptions;
begin
  options := TJwtOptions.Create('');
  options.Algorithm := 'RS256';
  options.Issuer := AServerUrl + '/realms/' + ARealm;
  options.Audience := AClientId;
  options.PublicKey := APublicKeyJwk;
  Result := ABuilder.UseMiddleware(TJwtAuthenticationMiddleware, options);
end;

end.

