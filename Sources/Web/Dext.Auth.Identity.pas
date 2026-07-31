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
  Dext.Auth.JWT,
  Dext.Collections,
  Dext.Collections.Dict;

type
  /// <summary>
  ///   Contract that defines the basic identity of a user (Name, Authentication Type).
  /// </summary>
  IIdentity = interface
    ['{F8E9D2C3-4A5B-6C7D-8E9F-0A1B2C3D4E5F}']
    /// <summary>Gets the name of the identity.</summary>
    function GetName: string;
    /// <summary>Indicates whether the user has been authenticated.</summary>
    function GetIsAuthenticated: Boolean;
    /// <summary>Gets the type of authentication used.</summary>
    function GetAuthenticationType: string;
    
    /// <summary>User identity name.</summary>
    property Name: string read GetName;
    /// <summary>Is authenticated.</summary>
    property IsAuthenticated: Boolean read GetIsAuthenticated;
    /// <summary>Authentication type.</summary>
    property AuthenticationType: string read GetAuthenticationType;
  end;

  /// <summary>
  ///   Contract for a Claims-based Principal, allowing for Role validation and access to user metadata.
  /// </summary>
  IClaimsPrincipal = interface
    ['{A1B2C3D4-E5F6-7890-1234-567890ABCDEF}']
    /// <summary>Gets the user's primary identity.</summary>
    function GetIdentity: IIdentity;
    /// <summary>Gets the associated claims array.</summary>
    function GetClaims: TArray<TClaim>;
    /// <summary>Finds a claim of a specific type.</summary>
    function FindClaim(const AClaimType: string): TClaim;
    /// <summary>Checks if the principal contains a claim of a specific type.</summary>
    function HasClaim(const AClaimType: string): Boolean;
    /// <summary>Checks if the user belongs to a specific security role.</summary>
    function IsInRole(const ARole: string): Boolean;
    
    /// <summary>The primary identity.</summary>
    property Identity: IIdentity read GetIdentity;
    /// <summary>All claims of the user.</summary>
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
    /// <summary>Initializes a new instance of TClaimsIdentity.</summary>
    constructor Create(const AName: string; const AAuthenticationType: string = 'JWT');
    
    /// <summary>Gets the user name.</summary>
    function GetName: string;
    /// <summary>Gets whether the user is authenticated.</summary>
    function GetIsAuthenticated: Boolean;
    /// <summary>Gets the authentication type.</summary>
    function GetAuthenticationType: string;
    
    /// <summary>User identity name.</summary>
    property Name: string read GetName;
    /// <summary>Is authenticated.</summary>
    property IsAuthenticated: Boolean read GetIsAuthenticated;
    /// <summary>Authentication type.</summary>
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
    /// <summary>Initializes a new instance of TClaimsPrincipal.</summary>
    constructor Create(const AIdentity: IIdentity; const AClaims: TArray<TClaim>);
    
    /// <summary>Gets the identity.</summary>
    function GetIdentity: IIdentity;
    /// <summary>Gets the claims.</summary>
    function GetClaims: TArray<TClaim>;
    /// <summary>Finds a claim by type.</summary>
    function FindClaim(const AClaimType: string): TClaim;
    /// <summary>Checks if a claim exists.</summary>
    function HasClaim(const AClaimType: string): Boolean;
    /// <summary>Checks if the user has a specific role.</summary>
    function IsInRole(const ARole: string): Boolean;
    
    /// <summary>Identity.</summary>
    property Identity: IIdentity read GetIdentity;
    /// <summary>Claims list.</summary>
    property Claims: TArray<TClaim> read GetClaims;
  end;

  /// <summary>Callback signature for policy evaluation.</summary>
  TAuthorizationPolicyCallback = reference to function(const APrincipal: IClaimsPrincipal): Boolean;

  /// <summary>
  ///   Global registry for named authorization policies.
  /// </summary>
  TAuthorizationPolicyRegistry = class
  private
    class var FPolicies: IDictionary<string, TAuthorizationPolicyCallback>;
    class constructor CreateClass;
  public
    /// <summary>Registers a named policy validation callback.</summary>
    class procedure RegisterPolicy(const AName: string; const ACallback: TAuthorizationPolicyCallback);
    /// <summary>Evaluates a registered policy against the principal.</summary>
    class function Evaluate(const AName: string; const APrincipal: IClaimsPrincipal): Boolean;
  end;

  /// <summary>
  ///   Common claim types.
  /// </summary>
  TClaimTypes = class
  public
    /// <summary>Subject identifier (sub).</summary>
    const NameIdentifier = 'sub';
    /// <summary>Name (name).</summary>
    const Name = 'name';
    /// <summary>Email address (email).</summary>
    const Email = 'email';
    /// <summary>Role identifier (role).</summary>
    const Role = 'role';
    /// <summary>Given name (given_name).</summary>
    const GivenName = 'given_name';
    /// <summary>Family name (family_name).</summary>
    const FamilyName = 'family_name';
    /// <summary>Expiration (exp).</summary>
    const Expiration = 'exp';
    /// <summary>Issued at (iat).</summary>
    const IssuedAt = 'iat';
    /// <summary>Issuer (iss).</summary>
    const Issuer = 'iss';
    /// <summary>Audience (aud).</summary>
    const Audience = 'aud';
  end;

  /// <summary>
  ///   Fluent builder to facilitate the assembly of Claims sets.
  /// </summary>
  IClaimsBuilder = interface
    ['{B2C3D4E5-F6A7-8B9C-0D1E-2F3A4B5C6D7E}']
    /// <summary>Adds a custom claim.</summary>
    function AddClaim(const AType, AValue: string): IClaimsBuilder;
    /// <summary>Adds a NameIdentifier claim.</summary>
    function WithNameIdentifier(const AValue: string): IClaimsBuilder;
    /// <summary>Adds a Name claim.</summary>
    function WithName(const AValue: string): IClaimsBuilder;
    /// <summary>Adds an Email claim.</summary>
    function WithEmail(const AValue: string): IClaimsBuilder;
    /// <summary>Adds a Role claim.</summary>
    function WithRole(const AValue: string): IClaimsBuilder;
    /// <summary>Adds a GivenName claim.</summary>
    function WithGivenName(const AValue: string): IClaimsBuilder;
    /// <summary>Adds a FamilyName claim.</summary>
    function WithFamilyName(const AValue: string): IClaimsBuilder;
    /// <summary>Builds the final claims array.</summary>
    function Build: TArray<TClaim>;
    /// <summary>Returns the current number of claims.</summary>
    function Count: Integer;
  end;

  /// <summary>
  ///   Default implementation of the Claims builder.
  /// </summary>
  TClaimsBuilder = class(TInterfacedObject, IClaimsBuilder)
  private
    FClaims: IList<TClaim>;
  public
    /// <summary>Creates a new instance of TClaimsBuilder.</summary>
    constructor Create;
    /// <summary>Destroys the TClaimsBuilder instance.</summary>
    destructor Destroy; override;

    /// <summary>Adds a custom claim.</summary>
    function AddClaim(const AType, AValue: string): IClaimsBuilder;
    /// <summary>Adds the 'sub' (subject/user ID) claim.</summary>
    function WithNameIdentifier(const AValue: string): IClaimsBuilder;
    /// <summary>Adds the 'name' claim.</summary>
    function WithName(const AValue: string): IClaimsBuilder;
    /// <summary>Adds the 'email' claim.</summary>
    function WithEmail(const AValue: string): IClaimsBuilder;
    /// <summary>Adds the 'role' claim.</summary>
    function WithRole(const AValue: string): IClaimsBuilder;
    /// <summary>Adds the 'given_name' claim.</summary>
    function WithGivenName(const AValue: string): IClaimsBuilder;
    /// <summary>Adds the 'family_name' claim.</summary>
    function WithFamilyName(const AValue: string): IClaimsBuilder;
    /// <summary>Builds and returns the claims array.</summary>
    function Build: TArray<TClaim>;
    /// <summary>Returns the number of claims in the builder.</summary>
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
  claim: TClaim;
begin
  for claim in FClaims do
  begin
    if SameText(claim.ClaimType, AClaimType) then
      Exit(claim);
  end;
  
  Result.ClaimType := '';
  Result.Value := '';
end;

function TClaimsPrincipal.HasClaim(const AClaimType: string): Boolean;
var
  claim: TClaim;
begin
  claim := FindClaim(AClaimType);
  Result := claim.ClaimType <> '';
end;

function TClaimsPrincipal.IsInRole(const ARole: string): Boolean;
var
  claim: TClaim;
begin
  for claim in FClaims do
  begin
    if SameText(claim.ClaimType, TClaimTypes.Role) and SameText(claim.Value, ARole) then
      Exit(True);
  end;
  
  Result := False;
end;

{ TAuthorizationPolicyRegistry }

class constructor TAuthorizationPolicyRegistry.CreateClass;
begin
  FPolicies := TCollections.CreateDictionaryIgnoreCase<string, TAuthorizationPolicyCallback>();
end;

class procedure TAuthorizationPolicyRegistry.RegisterPolicy(const AName: string; const ACallback: TAuthorizationPolicyCallback);
begin
  FPolicies.AddOrSetValue(AName, ACallback);
end;

class function TAuthorizationPolicyRegistry.Evaluate(const AName: string; const APrincipal: IClaimsPrincipal): Boolean;
var
  callback: TAuthorizationPolicyCallback;
begin
  if FPolicies.TryGetValue(AName, callback) then
    Result := callback(APrincipal)
  else
    Result := False;
end;

{ TClaimsBuilder }

constructor TClaimsBuilder.Create;
begin
  inherited Create;
  FClaims := TCollections.CreateList<TClaim>;
end;

destructor TClaimsBuilder.Destroy;
begin
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
