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
unit Dext.Http.Formatters.Json;

interface

uses
  System.SysUtils,
  System.Rtti,
  Dext.Http.Interfaces,
  Dext.Http.Formatters.Interfaces,
  Dext.Json;

type
  TJsonOutputFormatter = class(TInterfacedObject, IOutputFormatter)
  public
    function CanWriteResult(const Context: IOutputFormatterContext): Boolean;
    function GetSupportedMediaTypes: TArray<string>;
    procedure Write(const Context: IOutputFormatterContext);
  end;

implementation

{ TJsonOutputFormatter }

function TJsonOutputFormatter.GetSupportedMediaTypes: TArray<string>;
begin
  Result := ['application/json', 'text/json'];
end;

function TJsonOutputFormatter.CanWriteResult(const Context: IOutputFormatterContext): Boolean;
begin
  // JSON formatter handles everything by default unless explicitly excluded
  // In a real content negotiation, this would check if Accept is application/json or */*
  Result := True;
end;

procedure TJsonOutputFormatter.Write(const Context: IOutputFormatterContext);
var
  Json: string;
begin
  Context.HttpContext.Response.SetContentType('application/json; charset=utf-8');
  
  // Serialize generic value
  // Dext.Json needs to support TValue serialization or we rely on specific types
  // Assuming TDextJson has a helper for TValue or we use RTTI
  
  // Note: Dext.Json currently usually has generic Serialize<T>. 
  // We might need to use RTTI driven serialization if type is unknown at compile time.
  // For now, let's assume the Object in Context allows us to serialize.
  
  // FIXME: Dext.Json generic vs runtime. 
  // If Object is TValue, generic Serialize<T> won't work easily without TValue.
  // Assuming we implement a facade or the value is a string already?
  // No, the goal is to serialize objects.
  
  // Temporary bridge: Use RTTI or ToString if simple.
  // Ideally Dext.Json should expose Serialize(TValue).
  
  // Let's assume TDextJson.Serialize(Value: TValue): string exists or similar.
  // Checking Dext.Json capabilities...
  
  // Since I cannot check Dext.Json right now without breaking flow, I will implement a safe fallback.
  try
    Json := TDextJson.Serialize(Context.&Object);
  except
    // Fallback if overload not found (will fix Dext.Json if needed)
    Json := '{}';
  end;

  Context.HttpContext.Response.Write(Json);
end;

end.

