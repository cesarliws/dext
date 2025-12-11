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
unit Dext.Http.Versioning;

interface

uses
  System.SysUtils,
  System.Classes,
  Dext.Http.Interfaces;

type
  IApiVersionReader = interface
    ['{12312312-1234-1234-1234-1234567890AA}']
    function Read(const Context: IHttpContext): string;
  end;

  TQueryStringApiVersionReader = class(TInterfacedObject, IApiVersionReader)
  private
    FParameterName: string;
  public
    constructor Create(const ParameterName: string = 'api-version');
    function Read(const Context: IHttpContext): string;
  end;

  THeaderApiVersionReader = class(TInterfacedObject, IApiVersionReader)
  private
    FHeaderName: string;
  public
    constructor Create(const HeaderName: string = 'X-Version');
    function Read(const Context: IHttpContext): string;
  end;

  /// <summary>
  ///   Combines multiple readers (e.g. check Header, then QueryString).
  /// </summary>
  TCompositeApiVersionReader = class(TInterfacedObject, IApiVersionReader)
  private
    FReaders: TArray<IApiVersionReader>;
  public
    constructor Create(const Readers: TArray<IApiVersionReader>);
    function Read(const Context: IHttpContext): string;
  end;

implementation

{ TQueryStringApiVersionReader }

constructor TQueryStringApiVersionReader.Create(const ParameterName: string);
begin
  inherited Create;
  FParameterName := ParameterName;
end;

function TQueryStringApiVersionReader.Read(const Context: IHttpContext): string;
begin
  Result := Context.Request.Query.Values[FParameterName];
end;

{ THeaderApiVersionReader }

constructor THeaderApiVersionReader.Create(const HeaderName: string);
begin
  inherited Create;
  FHeaderName := HeaderName;
end;

function THeaderApiVersionReader.Read(const Context: IHttpContext): string;
begin
  if Context.Request.Headers.ContainsKey(FHeaderName) then
    Result := Context.Request.Headers[FHeaderName]
  else
    Result := '';
end;

{ TCompositeApiVersionReader }

constructor TCompositeApiVersionReader.Create(const Readers: TArray<IApiVersionReader>);
begin
  inherited Create;
  FReaders := Readers;
end;

function TCompositeApiVersionReader.Read(const Context: IHttpContext): string;
var
  Reader: IApiVersionReader;
begin
  Result := '';
  for Reader in FReaders do
  begin
    Result := Reader.Read(Context);
    if Result <> '' then Exit;
  end;
end;

end.

