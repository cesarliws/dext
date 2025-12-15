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
  ///   Marks a handler as requiring authentication.
  /// </summary>
  AuthorizeAttribute = class(TCustomAttribute)
  private
    FRoles: string;
  public
    constructor Create; overload;
    constructor Create(const ARoles: string); overload;
    
    property Roles: string read FRoles;
  end;

  /// <summary>
  ///   Marks a handler as allowing anonymous access (bypasses authentication).
  /// </summary>
  AllowAnonymousAttribute = class(TCustomAttribute)
  end;

implementation

{ AuthorizeAttribute }

constructor AuthorizeAttribute.Create;
begin
  inherited Create;
  FRoles := '';
end;

constructor AuthorizeAttribute.Create(const ARoles: string);
begin
  inherited Create;
  FRoles := ARoles;
end;

end.

