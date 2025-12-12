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
unit Dext.Auth.Identity;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Dext.Auth.JWT;

type
  /// <summary>
  ///   Represents the identity of a user.
  /// </summary>
  IIdentity = interface
    ['{F8E9D2C3-4A5B-6C7D-8E9F-0A1B2C3D4E5F}']
    function GetName: string;
    function GetIsAuthenticated: Boolean;
    function GetAuthenticationType: string;
    
    property Name: string read GetName;
    property IsAuthenticated: Boolean read GetIsAuthenticated;
    property AuthenticationType: string read GetAuthenticationType;
  end;

  /// <summary>
  ///   Represents a user principal with claims.
  /// </summary>
  IClaimsPrincipal = interface
    ['{A1B2C3D4-E5F6-7890-1234-567890ABCDEF}']
    function GetIdentity: IIdentity;
    function GetClaims: TArray<TClaim>;
    function FindClaim(const AClaimType: string): TClaim;
    function HasClaim(const AClaimType: string): Boolean;
    function IsInRole(const ARole: string): Boolean;
    
    property Identity: IIdentity read GetIdentity;
    property Claims: TArray<TClaim> read GetClaims;
  end;

  /// <summary>
  ///   Claims-based identity implementation.
  /// </summary>
  TClaimsIdentity = class(TInterfacedObject, IIdentity)
  private
    FName: string;
    FAuthenticationType: string;
    FIsAuthenticated: Boolean;
  public
    constructor Create(const AName: string; const AAuthenticationType: string = 'JWT');
    
    function GetName: string;
    function GetIsAuthenticated: Boolean;
    function GetAuthenticationType: string;
    
    property Name: string read GetName;
    property IsAuthenticated: Boolean read GetIsAuthenticated;
    property AuthenticationType: string read GetAuthenticationType;
  end;

  /// <summary>
  ///   Claims principal implementation.
  /// </summary>
  TClaimsPrincipal = class(TInterfacedObject, IClaimsPrincipal)
  private
    FIdentity: IIdentity;
    FClaims: TArray<TClaim>;
  public
    constructor Create(const AIdentity: IIdentity; const AClaims: TArray<TClaim>);
    
    function GetIdentity: IIdentity;
    function GetClaims: TArray<TClaim>;
    function FindClaim(const AClaimType: string): TClaim;
    function HasClaim(const AClaimType: string): Boolean;
    function IsInRole(const ARole: string): Boolean;
    
    property Identity: IIdentity read GetIdentity;
    property Claims: TArray<TClaim> read GetClaims;
  end;

  /// <summary>
  ///   Common claim types.
  /// </summary>
  TClaimTypes = class
  public
    const NameIdentifier = 'sub';      // Subject (user ID)
    const Name = 'name';                // User name
    const Email = 'email';              // Email address
    const Role = 'role';                // User role
    const GivenName = 'given_name';     // First name
    const FamilyName = 'family_name';   // Last name
    const Expiration = 'exp';           // Expiration time
    const IssuedAt = 'iat';             // Issued at time
    const Issuer = 'iss';               // Token issuer
    const Audience = 'aud';             // Token audience
  end;

  /// <summary>
  ///   Fluent builder for creating claims arrays (interface).
  /// </summary>
  IClaimsBuilder = interface
    ['{B2C3D4E5-F6A7-8B9C-0D1E-2F3A4B5C6D7E}']
    function AddClaim(const AType, AValue: string): IClaimsBuilder;
    function WithNameIdentifier(const AValue: string): IClaimsBuilder;
    function WithName(const AValue: string): IClaimsBuilder;
    function WithEmail(const AValue: string): IClaimsBuilder;
    function WithRole(const AValue: string): IClaimsBuilder;
    function WithGivenName(const AValue: string): IClaimsBuilder;
    function WithFamilyName(const AValue: string): IClaimsBuilder;
    function Build: TArray<TClaim>;
    function Count: Integer;
  end;

  /// <summary>
  ///   Fluent builder for creating claims arrays.
  /// </summary>
  TClaimsBuilder = class(TInterfacedObject, IClaimsBuilder)
  private
    FClaims: TList<TClaim>;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>
    ///   Adds a custom claim.
    /// </summary>
    function AddClaim(const AType, AValue: string): IClaimsBuilder;

    /// <summary>
    ///   Adds the 'sub' (subject/user ID) claim.
    /// </summary>
    function WithNameIdentifier(const AValue: string): IClaimsBuilder;

    /// <summary>
    ///   Adds the 'name' claim.
    /// </summary>
    function WithName(const AValue: string): IClaimsBuilder;

    /// <summary>
    ///   Adds the 'email' claim.
    /// </summary>
    function WithEmail(const AValue: string): IClaimsBuilder;

    /// <summary>
    ///   Adds the 'role' claim. Can be called multiple times for multiple roles.
    /// </summary>
    function WithRole(const AValue: string): IClaimsBuilder;

    /// <summary>
    ///   Adds the 'given_name' claim.
    /// </summary>
    function WithGivenName(const AValue: string): IClaimsBuilder;

    /// <summary>
    ///   Adds the 'family_name' claim.
    /// </summary>
    function WithFamilyName(const AValue: string): IClaimsBuilder;

    /// <summary>
    ///   Builds and returns the claims array.
    /// </summary>
    function Build: TArray<TClaim>;

    /// <summary>
    ///   Returns the number of claims currently in the builder.
    /// </summary>
    function Count: Integer;
  end;

implementation

{ TClaimsIdentity }

constructor TClaimsIdentity.Create(const AName, AAuthenticationType: string);
begin
  inherited Create;
  FName := AName;
  FAuthenticationType := AAuthenticationType;
  FIsAuthenticated := AName <> '';
end;

function TClaimsIdentity.GetName: string;
begin
  Result := FName;
end;

function TClaimsIdentity.GetIsAuthenticated: Boolean;
begin
  Result := FIsAuthenticated;
end;

function TClaimsIdentity.GetAuthenticationType: string;
begin
  Result := FAuthenticationType;
end;

{ TClaimsPrincipal }

constructor TClaimsPrincipal.Create(const AIdentity: IIdentity; const AClaims: TArray<TClaim>);
begin
  inherited Create;
  FIdentity := AIdentity;
  FClaims := AClaims;
end;

function TClaimsPrincipal.GetIdentity: IIdentity;
begin
  Result := FIdentity;
end;

function TClaimsPrincipal.GetClaims: TArray<TClaim>;
begin
  Result := FClaims;
end;

function TClaimsPrincipal.FindClaim(const AClaimType: string): TClaim;
var
  Claim: TClaim;
begin
  for Claim in FClaims do
  begin
    if SameText(Claim.ClaimType, AClaimType) then
      Exit(Claim);
  end;
  
  Result.ClaimType := '';
  Result.Value := '';
end;

function TClaimsPrincipal.HasClaim(const AClaimType: string): Boolean;
var
  Claim: TClaim;
begin
  Claim := FindClaim(AClaimType);
  Result := Claim.ClaimType <> '';
end;

function TClaimsPrincipal.IsInRole(const ARole: string): Boolean;
var
  Claim: TClaim;
begin
  for Claim in FClaims do
  begin
    if SameText(Claim.ClaimType, TClaimTypes.Role) and SameText(Claim.Value, ARole) then
      Exit(True);
  end;
  
  Result := False;
end;

{ TClaimsBuilder }

constructor TClaimsBuilder.Create;
begin
  inherited Create;
  FClaims := TList<TClaim>.Create;
end;

destructor TClaimsBuilder.Destroy;
begin
  FClaims.Free;
  inherited;
end;

function TClaimsBuilder.AddClaim(const AType, AValue: string): IClaimsBuilder;
begin
  FClaims.Add(TClaim.Create(AType, AValue));
  Result := Self;
end;

function TClaimsBuilder.WithNameIdentifier(const AValue: string): IClaimsBuilder;
begin
  Result := AddClaim(TClaimTypes.NameIdentifier, AValue);
end;

function TClaimsBuilder.WithName(const AValue: string): IClaimsBuilder;
begin
  Result := AddClaim(TClaimTypes.Name, AValue);
end;

function TClaimsBuilder.WithEmail(const AValue: string): IClaimsBuilder;
begin
  Result := AddClaim(TClaimTypes.Email, AValue);
end;

function TClaimsBuilder.WithRole(const AValue: string): IClaimsBuilder;
begin
  Result := AddClaim(TClaimTypes.Role, AValue);
end;

function TClaimsBuilder.WithGivenName(const AValue: string): IClaimsBuilder;
begin
  Result := AddClaim(TClaimTypes.GivenName, AValue);
end;

function TClaimsBuilder.WithFamilyName(const AValue: string): IClaimsBuilder;
begin
  Result := AddClaim(TClaimTypes.FamilyName, AValue);
end;

function TClaimsBuilder.Build: TArray<TClaim>;
begin
  Result := FClaims.ToArray;
end;

function TClaimsBuilder.Count: Integer;
begin
  Result := FClaims.Count;
end;

end.

