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
  Dext.Http.Interfaces,
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
    constructor Create(const AOptions: TJwtOptions); overload;
    constructor Create(const AOptions: TJwtOptions; const ATokenPrefix: string); overload;
    
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
    class function UseJwtAuthentication(const ABuilder: IApplicationBuilder; const ASecretKey: string; AConfigurator: TProc<TJwtOptionsBuilder>): IApplicationBuilder; overload; static;
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
  WriteLn('AUTH: ExtractToken called with: ', AAuthHeader);
  Result := AAuthHeader;
  
  if FTokenPrefix <> '' then
  begin
    WriteLn('AUTH: Token prefix configured: ', FTokenPrefix);
    if StartsText(FTokenPrefix, AAuthHeader) then
    begin
      Result := Copy(AAuthHeader, Length(FTokenPrefix) + 1, MaxInt);
      WriteLn('AUTH: Extracted token (first 50 chars): ', Copy(Result, 1, 50));
    end
    else
    begin
      WriteLn('AUTH: Header does not start with expected prefix');
      Result := '';
    end;
  end;
end;

function TJwtAuthenticationMiddleware.CreatePrincipal(const AClaims: TArray<TClaim>): IClaimsPrincipal;
var
  UserName: string;
  Claim: TClaim;
  Identity: IIdentity;
begin
  // Extract username from claims (try 'name' first, then 'sub')
  UserName := '';
  for Claim in AClaims do
  begin
    if SameText(Claim.ClaimType, TClaimTypes.Name) then
    begin
      UserName := Claim.Value;
      Break;
    end;
  end;
  
  if UserName = '' then
  begin
    for Claim in AClaims do
    begin
      if SameText(Claim.ClaimType, TClaimTypes.NameIdentifier) then
      begin
        UserName := Claim.Value;
        Break;
      end;
    end;
  end;
  
  Identity := TClaimsIdentity.Create(UserName, 'JWT');
  Result := TClaimsPrincipal.Create(Identity, AClaims);
end;

procedure TJwtAuthenticationMiddleware.Invoke(AContext: IHttpContext; ANext: TRequestDelegate);
var
  AuthHeader: string;
  Token: string;
  ValidationResult: TJwtValidationResult;
  Principal: IClaimsPrincipal;
begin
  try
    WriteLn('AUTH: Middleware Invoke started');
    // Try to get Authorization header
    if AContext.Request.Headers.ContainsKey('Authorization') then
    begin
      AuthHeader := AContext.Request.Headers['Authorization'];
      WriteLn('AUTH: Header found');
      Token := ExtractToken(AuthHeader);
      
      if Token <> '' then
      begin
        // Validate token
        WriteLn('AUTH: Validating token...');
        ValidationResult := FTokenHandler.ValidateToken(Token);
        
        if ValidationResult.IsValid then
        begin
          // Create principal and set user
          Principal := CreatePrincipal(ValidationResult.Claims);
          AContext.User := Principal;
          
          WriteLn(Format('AUTH: User authenticated: %s', [Principal.Identity.Name]));
        end
        else
        begin
          WriteLn(Format('AUTH: Token validation failed: %s', [ValidationResult.ErrorMessage]));
        end;
      end;
    end
    else
    begin
      WriteLn('AUTH: No Authorization header found');
    end;
    
    // Continue pipeline
    ANext(AContext);
  except
    on E: Exception do
      WriteLn('AUTH: Exception in middleware: ', E.ClassName, ': ', E.Message);
  end;
end;

{ TApplicationBuilderJwtExtensions }

class function TApplicationBuilderJwtExtensions.UseJwtAuthentication(
  const ABuilder: IApplicationBuilder; const AOptions: TJwtOptions): IApplicationBuilder;
begin
  Result := ABuilder.UseMiddleware(TJwtAuthenticationMiddleware, AOptions);
end;

class function TApplicationBuilderJwtExtensions.UseJwtAuthentication(
  const ABuilder: IApplicationBuilder; const ASecretKey: string; 
  AConfigurator: TProc<TJwtOptionsBuilder>): IApplicationBuilder;
var
  Builder: TJwtOptionsBuilder;
  Options: TJwtOptions;
begin
  Builder := TJwtOptionsBuilder.Create(ASecretKey);
  try
    if Assigned(AConfigurator) then
      AConfigurator(Builder);
    Options := Builder.Build;
  finally
    Builder.Free;
  end;

  Result := ABuilder.UseMiddleware(TJwtAuthenticationMiddleware, Options);
end;

end.

