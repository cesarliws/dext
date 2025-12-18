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
 // Dext.Web.Core.pas - Versão Corrigida
unit Dext.Web.Core;

interface

uses
  System.Generics.Collections,
  System.SysUtils,
  System.Rtti,
  System.TypInfo,
  Dext.DI.Interfaces,
  Dext.Web.HandlerInvoker,
  Dext.Core.Activator,
  Dext.Web.Interfaces,
  Dext.Web.Routing;


type
  TMiddlewareRegistration = record
    MiddlewareClass: TClass;
    MiddlewareDelegate: TMiddlewareDelegate;
    MiddlewareInstance: IMiddleware; // ? Singleton Instance
    Parameters: TArray<TValue>;
    IsDelegate: Boolean;
    IsInstance: Boolean; // ? Flag for Singleton
  end;

  TAnonymousMiddleware = class(TInterfacedObject, IMiddleware)
  private
    FDelegate: TMiddlewareDelegate;
  public
    constructor Create(ADelegate: TMiddlewareDelegate);
    procedure Invoke(AContext: IHttpContext; ANext: TRequestDelegate);
  end;

  TApplicationBuilder = class(TInterfacedObject, IApplicationBuilder)
  private
    FMiddlewares: TList<TMiddlewareRegistration>;
    FRoutes: TList<TRouteDefinition>; // ? Changed to List of Definitions
    FServiceProvider: IServiceProvider;

    function CreateMiddlewarePipeline(const ARegistration: TMiddlewareRegistration; ANext: TRequestDelegate): TRequestDelegate;
  public
    constructor Create(AServiceProvider: IServiceProvider);
    destructor Destroy; override;
    function GetServiceProvider: IServiceProvider;

    function UseMiddleware(AMiddleware: TClass): IApplicationBuilder; overload;
    function UseMiddleware(AMiddleware: TClass; const AParam: TValue): IApplicationBuilder; overload;
    function UseMiddleware(AMiddleware: TClass; const AParams: array of TValue): IApplicationBuilder; overload;
    function UseMiddleware(AMiddleware: IMiddleware): IApplicationBuilder; overload; // ? Singleton
    
    // ? Functional Middleware
    function Use(AMiddleware: TMiddlewareDelegate): IApplicationBuilder;

    function UseModelBinding: IApplicationBuilder;

    function Map(const APath: string; ADelegate: TRequestDelegate): IApplicationBuilder;
    function MapEndpoint(const AMethod, APath: string; ADelegate: TRequestDelegate): IApplicationBuilder; // ? NOVO
    function MapPost(const Path: string; Handler: TStaticHandler): IApplicationBuilder; overload;
    function MapGet(const Path: string; Handler: TStaticHandler): IApplicationBuilder; overload;
    function MapPut(const Path: string; Handler: TStaticHandler): IApplicationBuilder; overload;
    function MapDelete(const Path: string; Handler: TStaticHandler): IApplicationBuilder; overload;
    function Build: TRequestDelegate;
    function GetRoutes: TArray<TEndpointMetadata>;
    procedure UpdateLastRouteMetadata(const AMetadata: TEndpointMetadata);
    procedure SetServiceProvider(const AProvider: IServiceProvider);
  end;

  TMiddleware = class(TInterfacedObject, IMiddleware)
  public
    procedure Invoke(AContext: IHttpContext; ANext: TRequestDelegate); virtual; abstract;
  end;

implementation

uses
  Dext.Web.ModelBinding,
  Dext.Web.Indy,
  Dext.Web.Pipeline,
  Dext.Web.RoutingMiddleware;

{ TAnonymousMiddleware }

constructor TAnonymousMiddleware.Create(ADelegate: TMiddlewareDelegate);
begin
  inherited Create;
  FDelegate := ADelegate;
end;

procedure TAnonymousMiddleware.Invoke(AContext: IHttpContext; ANext: TRequestDelegate);
begin
  FDelegate(AContext, ANext);
end;

function TApplicationBuilder.Use(AMiddleware: TMiddlewareDelegate): IApplicationBuilder;
var
  Registration: TMiddlewareRegistration;
begin
  Registration.IsDelegate := True;
  Registration.IsInstance := False; // ? Initialize explicitly
  Registration.MiddlewareDelegate := AMiddleware;
  Registration.MiddlewareInstance := nil; // ? Initialize explicitly
  Registration.MiddlewareClass := nil;
  SetLength(Registration.Parameters, 0);
  
  FMiddlewares.Add(Registration);
  Result := Self;
end;

// ... (Update CreateMiddlewarePipeline to handle delegate)

function TApplicationBuilder.CreateMiddlewarePipeline(const ARegistration: TMiddlewareRegistration;
  ANext: TRequestDelegate): TRequestDelegate;
var
  LServiceProvider: IServiceProvider;
  LRegistration: TMiddlewareRegistration; // ? Capture copy
begin
  LServiceProvider := FServiceProvider;
  LRegistration := ARegistration; // Copy record to local var for closure capture

  Result :=
    procedure(AContext: IHttpContext)
    var
      MiddlewareInstance: IMiddleware;
    begin
      if LRegistration.IsDelegate then
      begin
        // ? Handle Anonymous Middleware
        MiddlewareInstance := TAnonymousMiddleware.Create(LRegistration.MiddlewareDelegate);
      end
      else if LRegistration.IsInstance then
      begin
        // ? Handle Singleton Middleware
        MiddlewareInstance := LRegistration.MiddlewareInstance;
      end
      else
      begin
        // Handle Class Middleware
        var Obj := TActivator.CreateInstance(LServiceProvider, LRegistration.MiddlewareClass, LRegistration.Parameters);
        try
          if not Supports(Obj, IMiddleware, MiddlewareInstance) then
            raise EArgumentException.Create('Middleware must implement IMiddleware');
        except
          Obj.Free;
          raise;
        end;
      end;

      try
        if MiddlewareInstance = nil then
          raise EAccessViolation.Create('MiddlewareInstance is nil');

        MiddlewareInstance.Invoke(AContext, ANext);
      finally
        // Cleanup
      end;
    end;
end;

procedure InjectRouteParams(AContext: IHttpContext;
  const AParams: TDictionary<string, string>);
begin
  // Precisamos estender as implementações concretas para suportar RouteParams
  // Por enquanto, vamos adicionar suporte básico
  // Esta é uma implementação temporária - precisaremos atualizar TIndyHttpRequest
end;

{ TApplicationBuilder }

constructor TApplicationBuilder.Create(AServiceProvider: IServiceProvider);
begin
  inherited Create;
  FServiceProvider := AServiceProvider;
  FMiddlewares := TList<TMiddlewareRegistration>.Create;
  FRoutes := TList<TRouteDefinition>.Create;
end;

destructor TApplicationBuilder.Destroy;
var
  Route: TRouteDefinition;
begin
  FServiceProvider := nil;
  FMiddlewares.Free;
  for Route in FRoutes do
    Route.Free;
  FRoutes.Free;
  inherited Destroy;
end;

function TApplicationBuilder.GetServiceProvider: IServiceProvider;
begin
  Result := FServiceProvider;
end;

function TApplicationBuilder.UseMiddleware(AMiddleware: TClass; const AParam: TValue): IApplicationBuilder;
var
  Registration: TMiddlewareRegistration;
begin
  if not Supports(AMiddleware, IMiddleware) then
    raise EArgumentException.Create('Middleware must supports IMiddleware');

  Registration.MiddlewareClass := AMiddleware;
  Registration.IsDelegate := False;
  Registration.IsInstance := False; // ? Initialize explicitly
  Registration.MiddlewareDelegate := nil;
  Registration.MiddlewareInstance := nil; // ? Initialize explicitly
  SetLength(Registration.Parameters, 1);
  Registration.Parameters[0] := AParam;

  FMiddlewares.Add(Registration);

  Writeln('? MIDDLEWARE REGISTERED: ', AMiddleware.ClassName);
  if not AParam.IsEmpty then
    Writeln('   With parameter type: ', AParam.TypeInfo.Name);

  Result := Self;
end;

function TApplicationBuilder.UseMiddleware(AMiddleware: TClass; const AParams: array of TValue): IApplicationBuilder;
var
  Registration: TMiddlewareRegistration;
  I: Integer;
begin
  if not AMiddleware.InheritsFrom(TMiddleware) then
    raise EArgumentException.Create('Middleware must inherit from TMiddleware');

  Registration.MiddlewareClass := AMiddleware;
  Registration.IsDelegate := False;
  Registration.IsInstance := False; // ? Initialize explicitly
  Registration.MiddlewareDelegate := nil;
  Registration.MiddlewareInstance := nil; // ? Initialize explicitly
  SetLength(Registration.Parameters, Length(AParams));

  for I := 0 to High(AParams) do
    Registration.Parameters[I] := AParams[I];

  FMiddlewares.Add(Registration);
  FMiddlewares.Add(Registration);
  Result := Self;
end;

function TApplicationBuilder.UseMiddleware(AMiddleware: IMiddleware): IApplicationBuilder;
var
  Registration: TMiddlewareRegistration;
begin
  Registration.MiddlewareClass := nil;
  Registration.IsDelegate := False;
  Registration.IsInstance := True;
  Registration.MiddlewareInstance := AMiddleware;
  Registration.MiddlewareDelegate := nil;
  SetLength(Registration.Parameters, 0);

  FMiddlewares.Add(Registration);
  Writeln('? SINGLETON MIDDLEWARE REGISTERED: ', (AMiddleware as TObject).ClassName);
  
  Result := Self;
end;

function TApplicationBuilder.UseModelBinding: IApplicationBuilder;
begin
  // Por enquanto apenas retorna self - podemos adicionar configurações futuras
  // como opções de binding, validadores, etc.
  Result := Self;
end;



function TApplicationBuilder.UseMiddleware(AMiddleware: TClass): IApplicationBuilder;
var
  Registration: TMiddlewareRegistration; // ? USAR O NOVO RECORD
begin
  if not AMiddleware.InheritsFrom(TMiddleware) then
    raise EArgumentException.Create('Middleware must inherit from TMiddleware');

  // ? CRIAR REGISTRATION SEM PARÂMETROS
  Registration.MiddlewareClass := AMiddleware;
  Registration.IsDelegate := False;
  Registration.IsInstance := False; // ? Initialize explicitly
  Registration.MiddlewareDelegate := nil;
  Registration.MiddlewareInstance := nil; // ? Initialize explicitly
  SetLength(Registration.Parameters, 0); // Array vazio

  FMiddlewares.Add(Registration);
  Result := Self;
end;

function TApplicationBuilder.MapEndpoint(const AMethod, APath: string; ADelegate: TRequestDelegate): IApplicationBuilder;
var
  RouteDef: TRouteDefinition;
begin
  RouteDef := TRouteDefinition.Create(AMethod, APath, ADelegate);
  FRoutes.Add(RouteDef);
  Writeln(Format('?? REGISTERED %s %s', [AMethod, APath]));
  Result := Self;
end;

function TApplicationBuilder.Map(const APath: string;
  ADelegate: TRequestDelegate): IApplicationBuilder;
begin
  // Default to GET for legacy Map calls
  Result := MapEndpoint('GET', APath, ADelegate);
end;

function TApplicationBuilder.MapGet(const Path: string; Handler: TStaticHandler): IApplicationBuilder;
begin
  Result := MapEndpoint('GET', Path,
    procedure(Context: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Create;
      Invoker := THandlerInvoker.Create(Context, Binder);
      try
        Invoker.Invoke(Handler);
      finally
        Invoker.Free;
      end;
    end
  );
end;

function TApplicationBuilder.MapPost(const Path: string; Handler: TStaticHandler): IApplicationBuilder;
begin
  Result := MapEndpoint('POST', Path,
    procedure(Context: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Create;
      Invoker := THandlerInvoker.Create(Context, Binder);
      try
        Invoker.Invoke(Handler);
      finally
        Invoker.Free;
      end;
    end
  );
end;

function TApplicationBuilder.MapPut(const Path: string; Handler: TStaticHandler): IApplicationBuilder;
begin
  Result := MapEndpoint('PUT', Path,
    procedure(Context: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      // Method check is now handled by Routing Middleware, but double check is fine
      if Context.Request.Method <> 'PUT' then Exit;
      
      Binder := TModelBinder.Create;
      Invoker := THandlerInvoker.Create(Context, Binder);
      try
        Invoker.Invoke(Handler);
      finally
        Invoker.Free;
      end;
    end
  );
end;

function TApplicationBuilder.MapDelete(const Path: string; Handler: TStaticHandler): IApplicationBuilder;
begin
  Result := MapEndpoint('DELETE', Path,
    procedure(Context: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      if Context.Request.Method <> 'DELETE' then Exit;
      
      Binder := TModelBinder.Create;
      Invoker := THandlerInvoker.Create(Context, Binder);
      try
        Invoker.Invoke(Handler);
      finally
        Invoker.Free;
      end;
    end
  );
end;

// ---------------------------------------------------------------------------
// Helper Class to avoid Anonymous Method ActRec leaks
type
  IRoutingHandlerHelper = interface
    ['{19A95C1C-5C7F-4B8E-9C3E-8F3E5C7F4B8E}']
    procedure Invoke(Ctx: IHttpContext);
  end;

  TRoutingHandlerHelper = class(TInterfacedObject, IRoutingHandlerHelper)
  private
    FMw: IMiddleware;
    FNext: TRequestDelegate;
  public
    constructor Create(const Mw: IMiddleware; const Next: TRequestDelegate);
    destructor Destroy; override;
    procedure Invoke(Ctx: IHttpContext);
  end;

constructor TRoutingHandlerHelper.Create(const Mw: IMiddleware; const Next: TRequestDelegate);
begin
  inherited Create;
  FMw := Mw;
  FNext := Next;
end;

destructor TRoutingHandlerHelper.Destroy;
begin
  inherited;
end;

procedure TRoutingHandlerHelper.Invoke(Ctx: IHttpContext);
begin
  FMw.Invoke(Ctx, FNext);
end;

// Helper function to isolate capture scope and avoid ActRec cycles
function CreateRoutingDelegate(const Mw: IMiddleware; const Next: TRequestDelegate): TRequestDelegate;
var
  Helper: IRoutingHandlerHelper;
begin
  Helper := TRoutingHandlerHelper.Create(Mw, Next);
  Result := 
    procedure(Ctx: IHttpContext)
    begin
      Helper.Invoke(Ctx);
    end;
end;

function TApplicationBuilder.Build: TRequestDelegate;
var
  FinalPipeline: TRequestDelegate;
  RoutingMiddleware: IMiddleware;
  RouteMatcher: IRouteMatcher;
  RoutingHandler: TRequestDelegate;
begin
  // Pipeline final - retorna 404
  FinalPipeline :=
    procedure(AContext: IHttpContext)
    begin
      AContext.Response.StatusCode := 404;
      AContext.Response.Write('Not Found');
    end;

  // ? CRIAR RouteMatcher (interface - auto-gerenciável)
  RouteMatcher := TRouteMatcher.Create(FRoutes);

  // ? CRIAR RoutingMiddleware com a interface
  RoutingMiddleware := TRoutingMiddleware.Create(RouteMatcher);

  // ? USAR FUNÇÃO ISOLADA para criar o delegate
  // Isso impede que o delegate capture variáveis locais deste método Build (como ActRec)
  RoutingHandler := CreateRoutingDelegate(RoutingMiddleware, FinalPipeline);

  // Construir pipeline: outros middlewares ? roteamento ? 404
  for var I := FMiddlewares.Count - 1 downto 0 do
  begin
    RoutingHandler := CreateMiddlewarePipeline(FMiddlewares[I], RoutingHandler);
  end;

  Result := RoutingHandler;
end;


function TApplicationBuilder.GetRoutes: TArray<TEndpointMetadata>;
var
  I: Integer;
begin
  SetLength(Result, FRoutes.Count);
  for I := 0 to FRoutes.Count - 1 do
    Result[I] := FRoutes[I].Metadata;
end;

procedure TApplicationBuilder.UpdateLastRouteMetadata(const AMetadata: TEndpointMetadata);
begin
  if FRoutes.Count > 0 then
  begin
    FRoutes[FRoutes.Count - 1].Metadata := AMetadata;
  end;
end;

procedure TApplicationBuilder.SetServiceProvider(const AProvider: IServiceProvider);
begin
  FServiceProvider := AProvider;
end;

end.


