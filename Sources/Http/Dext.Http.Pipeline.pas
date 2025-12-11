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
// Dext.Http.Pipeline.pas - ATUALIZAR
unit Dext.Http.Pipeline;

interface

uses
  System.Generics.Collections,
  Dext.Http.Interfaces, Dext.Http.Routing;

type
  IDextPipeline = interface
    ['{A3B4C5D6-E7F8-4A9B-8C0D-1E2F3A4B5C6D}']
    procedure Execute(AContext: IHttpContext);
  end;

  TDextPipeline = class(TInterfacedObject, IDextPipeline)
  private
    FMappedRoutes: TDictionary<string, TRequestDelegate>;       // Rotas fixas
    FRoutePatterns: TDictionary<TRoutePattern, TRequestDelegate>; // ✅ NOVO: Padrões com parâmetros
    FMiddlewarePipeline: TRequestDelegate;

//    function FindMatchingRoute(const APath: string;
//      out AHandler: TRequestDelegate;
//      out ARouteParams: TDictionary<string, string>): Boolean;
  public
    constructor Create(AMappedRoutes: TDictionary<string, TRequestDelegate>;
      ARoutePatterns: TDictionary<TRoutePattern, TRequestDelegate>; // ✅ NOVO: Receber padrões
      APipeline: TRequestDelegate);
    destructor Destroy; override;
    procedure Execute(AContext: IHttpContext);
  end;

implementation

uses
  Dext.Http.Indy;

{ TDextPipeline }

constructor TDextPipeline.Create(AMappedRoutes: TDictionary<string, TRequestDelegate>;
  ARoutePatterns: TDictionary<TRoutePattern, TRequestDelegate>;
  APipeline: TRequestDelegate);
var
  Path: string;
  Handler: TRequestDelegate;
  RoutePattern: TRoutePattern;
begin
  inherited Create;

  // ✅ Clonar rotas fixas
  FMappedRoutes := TDictionary<string, TRequestDelegate>.Create;
  for Path in AMappedRoutes.Keys do
  begin
    if AMappedRoutes.TryGetValue(Path, Handler) then
      FMappedRoutes.Add(Path, Handler);
  end;

  // ✅ NOVO: Clonar padrões de rota
  FRoutePatterns := TDictionary<TRoutePattern, TRequestDelegate>.Create;
  for RoutePattern in ARoutePatterns.Keys do
  begin
    if ARoutePatterns.TryGetValue(RoutePattern, Handler) then
    begin
      // Criar nova instância do padrão (clone)
      var NewPattern := TRoutePattern.Create(RoutePattern.Pattern);
      FRoutePatterns.Add(NewPattern, Handler);
    end;
  end;

  FMiddlewarePipeline := APipeline;
end;

destructor TDextPipeline.Destroy;
var
  RoutePattern: TRoutePattern;
begin
  FMappedRoutes.Free;

  // ✅ NOVO: Liberar padrões de rota
  for RoutePattern in FRoutePatterns.Keys do
    RoutePattern.Free;
  FRoutePatterns.Free;

  inherited Destroy;
end;

// ✅ NOVO: Método para encontrar rota correspondente
//function TDextPipeline.FindMatchingRoute(const APath: string;
//  out AHandler: TRequestDelegate;
//  out ARouteParams: TDictionary<string, string>): Boolean;
//var
//  RoutePattern: TRoutePattern;
//begin
//  ARouteParams := nil;
//  Result := False;
//
//  // 1. Tentar rota fixa exata
//  if FMappedRoutes.TryGetValue(APath, AHandler) then
//    Exit(True);
//
//  // 2. ✅ NOVO: Tentar padrões de rota com parâmetros
//  for RoutePattern in FRoutePatterns.Keys do
//  begin
//    if RoutePattern.Match(APath, ARouteParams) then
//    begin
//      AHandler := FRoutePatterns[RoutePattern];
//      Exit(True);
//    end;
//  end;
//end;

procedure TDextPipeline.Execute(AContext: IHttpContext);
begin
  // ✅ Apenas executa o pipeline completo
  // O roteamento agora está DENTRO do pipeline como um middleware
  FMiddlewarePipeline(AContext);
end;

//procedure TDextPipeline.Execute(AContext: IHttpContext);
//var
//  Handler: TRequestDelegate;
//  RouteParams: TDictionary<string, string>;
//  IndyContext: TIndyHttpContext;
//begin
//  var Path := AContext.Request.Path;
//
//  // ✅ USAR novo método de busca
//  if FindMatchingRoute(Path, Handler, RouteParams) then
//  begin
//    try
//      // ✅ INJETAR parâmetros de rota se encontrados
//      if Assigned(RouteParams) and (AContext is TIndyHttpContext) then
//      begin
//        IndyContext := TIndyHttpContext(AContext);
//        IndyContext.SetRouteParams(RouteParams);
//      end;
//
//      Handler(AContext);
//    finally
//      RouteParams.Free;
//    end;
//  end
//  else
//  begin
//    // Executar pipeline de middlewares
//    FMiddlewarePipeline(AContext);
//  end;
//end;

end.

