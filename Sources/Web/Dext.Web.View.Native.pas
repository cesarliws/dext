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
unit Dext.Web.View.Native;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Rtti,
  Dext.Web.Interfaces,
  Dext.Web.View,
  Dext.Templating,
  Dext.DI.Interfaces,
  Dext.Collections,
  Dext.Collections.Dict;

type
  /// <summary>
  ///   Native Dext View Engine based on Dext.Templating (Razor-like AST engine).
  /// </summary>
  TDextNativeViewEngine = class(TInterfacedObject, IViewEngine)
  private
    FOptions: TViewOptions;
    FEngine: ITemplateEngine;
  public
    constructor Create(const AOptions: TViewOptions);
    destructor Destroy; override;
    function Render(AContext: IHttpContext; const AViewName: string; AViewData: IViewData): string;
  end;

implementation

{ TDextNativeViewEngine }

constructor TDextNativeViewEngine.Create(const AOptions: TViewOptions);
begin
  inherited Create;
  FOptions := AOptions;
  FEngine := TTemplating.CreateEngine;
  FEngine.IsHtmlMode := True;
  FEngine.TemplateLoader := TFileSystemTemplateLoader.Create(FOptions.TemplateRoot);
  (FEngine as TDextTemplateEngine).TemplateRoot := FOptions.TemplateRoot;
end;

destructor TDextNativeViewEngine.Destroy;
begin
  FEngine := nil;
  FOptions.Free;
  inherited;
end;

function TDextNativeViewEngine.Render(AContext: IHttpContext; const AViewName: string; AViewData: IViewData): string;
var
  Context: ITemplateContext;
  LViewPath: string;
  ObjPair: TPair<string, TObject>;
  Pair: TPair<string, TValue>;
begin
  Context := TTemplating.CreateContext;

  for Pair in AViewData.Values do
  begin
    if not Pair.Value.IsEmpty then
      Context.SetValue(Pair.Key, Pair.Value.ToString);
  end;

  for ObjPair in AViewData.Objects do
    Context.SetObject(ObjPair.Key, ObjPair.Value);

  LViewPath := AViewName;
  if not LViewPath.Contains('.') then
    LViewPath := LViewPath + '.html';

  TMonitor.Enter(Self);
  try
    Result := FEngine.RenderTemplate(LViewPath, Context);
  finally
    TMonitor.Exit(Self);
  end;
end;

end.
