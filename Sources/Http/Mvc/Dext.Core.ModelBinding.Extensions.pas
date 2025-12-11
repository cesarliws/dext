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
unit Dext.Core.ModelBinding.Extensions;

interface

uses
  System.SysUtils,
  System.Rtti,
  Dext.Http.Interfaces,
  Dext.Http.Core,
  Dext.Core.ModelBinding;

type
  // ✅ INTERFACE FINAL (sem genéricos)
  IApplicationBuilderWithModelBinding = interface
    ['{8A3B7C5D-2E4F-4A9D-B1C6-9F7E5D3A2B1C}']
    function Build: IApplicationBuilder;
  end;

  // ✅ BUILDER CONCRETO (com genéricos)
  TApplicationBuilderWithModelBinding = class(TInterfacedObject, IApplicationBuilderWithModelBinding)
  private
    FBuilder: TApplicationBuilder;
    FModelBinder: IModelBinder;
  public
    constructor Create(ABuilder: TApplicationBuilder);

    // ✅ MÉTODOS GENÉRICOS (apenas na classe)
    function MapPost<T>(const Path: string; Handler: TProc<T>): TApplicationBuilderWithModelBinding;
    function MapGet<T>(const Path: string; Handler: TProc<T>): TApplicationBuilderWithModelBinding;

    // ✅ MÉTODO FINAL (retorna interface)
    function Build: IApplicationBuilder;
  end;

  // ✅ FACTORY para criar o builder
  TApplicationBuilderModelBindingExtensions = class
  public
    class function WithModelBinding(AppBuilder: IApplicationBuilder): TApplicationBuilderWithModelBinding; static;
  end;

implementation

{ TApplicationBuilderWithModelBinding }

constructor TApplicationBuilderWithModelBinding.Create(ABuilder: TApplicationBuilder);
begin
  inherited Create;
  FBuilder := ABuilder;
  FModelBinder := TModelBinder.Create;
end;

function TApplicationBuilderWithModelBinding.MapPost<T>(const Path: string;
  Handler: TProc<T>): TApplicationBuilderWithModelBinding;
begin
  FBuilder.Map(Path,
    procedure(Context: IHttpContext)
    var
      BodyData: T;
      Value: TValue;
    begin
      try
        Value := FModelBinder.BindBody(TypeInfo(T), Context);
        BodyData := Value.AsType<T>;
        Handler(BodyData);
      except
        on E: Exception do
        begin
          Context.Response.StatusCode := 400;
          Context.Response.Json(Format('{"error":"%s"}', [E.Message]));
        end;
      end;
    end
  );
  Result := Self;
end;

function TApplicationBuilderWithModelBinding.MapGet<T>(const Path: string;
  Handler: TProc<T>): TApplicationBuilderWithModelBinding;
begin
  FBuilder.Map(Path,
    procedure(Context: IHttpContext)
    var
      Data: T;
      Value: TValue;
    begin
      try
        Value := FModelBinder.BindQuery(TypeInfo(T), Context);
        Data := Value.AsType<T>;
        Handler(Data);
      except
        on E: Exception do
        begin
          Context.Response.StatusCode := 400;
          Context.Response.Json(Format('{"error":"%s"}', [E.Message]));
        end;
      end;
    end
  );
  Result := Self;
end;

function TApplicationBuilderWithModelBinding.Build: IApplicationBuilder;
begin
  Result := FBuilder;
end;

{ TApplicationBuilderModelBindingExtensions }

class function TApplicationBuilderModelBindingExtensions.WithModelBinding(
  AppBuilder: IApplicationBuilder): TApplicationBuilderWithModelBinding;
begin
  Result := TApplicationBuilderWithModelBinding.Create(AppBuilder as TApplicationBuilder);
end;

end.

