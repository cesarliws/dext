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
unit Dext.Web.Formatters.Json;

interface

uses
  System.SysUtils,
  System.Rtti,
  Dext.Web.Interfaces,
  Dext.Web.Formatters.Interfaces,
  Dext.Json;

type
  /// <summary>
  ///   Default JSON output formatter using Dext.Json high-performance engine.
  ///   Supports application/json and text/json media types.
  /// </summary>
  TJsonOutputFormatter = class(TInterfacedObject, IOutputFormatter)
  public
    /// <summary>Determines if the formatter can handle the requested response type.</summary>
    function CanWriteResult(const Context: IOutputFormatterContext): Boolean;
    /// <summary>Returns the media types supported by this formatter (JSON).</summary>
    function GetSupportedMediaTypes: TArray<string>;
    /// <summary>Serializes the object in the context and writes it to the response stream.</summary>
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
  Json := TDextJson.Serialize(Context.&Object);
  Context.HttpContext.Response.Write(Json);
end;

end.

