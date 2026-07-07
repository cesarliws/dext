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
unit Dext.Auth.Attributes;

interface

uses
  System.SysUtils,
  System.Rtti;

type
  /// <summary>
  ///   Marks a handler or controller as requiring authentication.
  ///   Optionally allows filtering by Roles, Policy, and Authentication Scheme.
  /// </summary>
  AuthorizeAttribute = class(TCustomAttribute)
  private
    FRoles: string;
    FScheme: string;
    FPolicy: string;
  public
    /// <summary>
    ///   Initializes a new instance of AuthorizeAttribute requiring authentication.
    /// </summary>
    constructor Create; overload;
    /// <summary>
    ///   Initializes a new instance of AuthorizeAttribute filtering by roles.
    /// </summary>
    constructor Create(const ARoles: string); overload;
    /// <summary>
    ///   Initializes a new instance of AuthorizeAttribute filtering by roles and scheme.
    /// </summary>
    constructor Create(const ARoles, AScheme: string); overload;
    
    /// <summary>
    ///   Allowed roles (comma-separated).
    /// </summary>
    property Roles: string read FRoles write FRoles;
    /// <summary>
    ///   Required authentication scheme.
    /// </summary>
    property Scheme: string read FScheme write FScheme;
    /// <summary>
    ///   Required authorization policy name.
    /// </summary>
    property Policy: string read FPolicy write FPolicy;
  end;

  /// <summary>
  ///   Marks a handler or controller as allowing anonymous access (bypasses authentication).
  /// </summary>
  AllowAnonymousAttribute = class(TCustomAttribute)
  end;

implementation

{ AuthorizeAttribute }

constructor AuthorizeAttribute.Create;
begin
  inherited Create;
  FRoles := '';
  FScheme := '';
  FPolicy := '';
end;

constructor AuthorizeAttribute.Create(const ARoles: string);
begin
  inherited Create;
  FPolicy := '';
  if SameText(ARoles, 'Bearer') or SameText(ARoles, 'Basic') or
     SameText(ARoles, 'OAuth2') or SameText(ARoles, 'OpenID') then
  begin
    FScheme := ARoles;
    FRoles := '';
  end
  else
  begin
    FRoles := ARoles;
    FScheme := '';
  end;
end;

constructor AuthorizeAttribute.Create(const ARoles, AScheme: string);
begin
  inherited Create;
  FRoles := ARoles;
  FScheme := AScheme;
  FPolicy := '';
end;

end.

