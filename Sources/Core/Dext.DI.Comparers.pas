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
// Adicione esta unit
unit Dext.DI.Comparers;

interface

uses
  System.Generics.Defaults,
  System.Hash,
  System.SysUtils,
  Dext.DI.Interfaces;

type
  TServiceTypeComparer = class(TInterfacedObject, IEqualityComparer<TServiceType>)
  public
    function Equals(const Left, Right: TServiceType): Boolean; reintroduce;
    function GetHashCode(const Value: TServiceType): Integer; reintroduce;
  end;

implementation

{ TServiceTypeComparer }

function TServiceTypeComparer.Equals(const Left, Right: TServiceType): Boolean;
begin
  Result := Left = Right;
end;

function TServiceTypeComparer.GetHashCode(const Value: TServiceType): Integer;
var
  GuidStr: string;
  ClassPtr: Pointer;
begin
  if Value.IsInterface then
  begin
    // Para interfaces, usar hash do GUID como string
    GuidStr := GUIDToString(Value.AsInterface);
    Result := THashBobJenkins.GetHashValue(GuidStr);
  end
  else
  begin
    // Para classes, usar hash do ponteiro da classe
    ClassPtr := Pointer(Value.AsClass);
    Result := THashBobJenkins.GetHashValue(ClassPtr, SizeOf(Pointer));
  end;
end;

end.

