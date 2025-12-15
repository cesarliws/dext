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
unit Dext.Web.HandlerInvoker;

interface

uses
  System.SysUtils,
  System.Rtti,
  System.TypInfo,
  Dext.Web.Interfaces,
  Dext.Web.Controllers,
  Dext.Web.ModelBinding;

type
  { Invoker básico - FASE 1.1 }
  // Definição de tipos de handlers genéricos
  THandlerProc<T> = reference to procedure(Arg1: T);
  THandlerProc<T1, T2> = reference to procedure(Arg1: T1; Arg2: T2);
  THandlerProc<T1, T2, T3> = reference to procedure(Arg1: T1; Arg2: T2; Arg3: T3);

  // Handlers returning IResult
  // Handlers returning IResult - Use distinct type to help overload resolution
  THandlerResultFunc<TResult> = reference to function: TResult;
  THandlerResultFunc<T, TResult> = reference to function(Arg1: T): TResult;
  THandlerResultFunc<T1, T2, TResult> = reference to function(Arg1: T1; Arg2: T2): TResult;
  THandlerResultFunc<T1, T2, T3, TResult> = reference to function(Arg1: T1; Arg2: T2; Arg3: T3): TResult;
  
  // Legacy Aliases - Redefined explicitly to avoid compiler issues with generic aliasing
  THandlerFunc<TResult> = reference to function: TResult;
  THandlerFunc<T, TResult> = reference to function(Arg1: T): TResult;
  THandlerFunc<T1, T2, TResult> = reference to function(Arg1: T1; Arg2: T2): TResult;
  THandlerFunc<T1, T2, T3, TResult> = reference to function(Arg1: T1; Arg2: T2; Arg3: T3): TResult;

  // Handlers with explicit IHttpContext parameter (better UX)
  THandlerProcWithContext<T> = reference to procedure(Arg1: T; Ctx: IHttpContext);
  THandlerProcWithContext<T1, T2> = reference to procedure(Arg1: T1; Arg2: T2; Ctx: IHttpContext);
  THandlerFuncWithContext<T, TResult> = reference to function(Arg1: T; Ctx: IHttpContext): TResult;

  THandlerInvoker = class
  private
    FModelBinder: IModelBinder;
    FContext: IHttpContext;
    function Validate(const AValue: TValue): Boolean;
  public
    constructor Create(AContext: IHttpContext; AModelBinder: IModelBinder);

    // Invocação estática (legado/simples)
    /// <summary>
    ///   Invokes a static handler (procedure(Ctx: IHttpContext)).
    /// </summary>
    function Invoke(AHandler: TStaticHandler): Boolean; overload;

    /// <summary>
    ///   Invokes a generic handler with 1 argument.
    ///   Performs automatic binding based on argument type:
    ///   - IHttpContext: Injected directly.
    ///   - Record: Bound from Body (POST/PUT) or Query (GET/DELETE).
    ///   - Interface: Bound from Services (DI).
    ///   - Primitive: Bound from Route (if available) or Query.
    /// </summary>
    function Invoke<T>(AHandler: THandlerProc<T>): Boolean; overload;

    /// <summary>
    ///   Invokes a generic handler with 2 arguments.
    /// </summary>
    function Invoke<T1, T2>(AHandler: THandlerProc<T1, T2>): Boolean; overload;
    
    /// <summary>
    ///   Invokes a generic handler with 3 arguments.
    /// </summary>
    function Invoke<T1, T2, T3>(AHandler: THandlerProc<T1, T2, T3>): Boolean; overload;

    // Invoke for handlers returning IResult
    function Invoke<TResult>(AHandler: THandlerResultFunc<TResult>): Boolean; overload;
    function Invoke<T, TResult>(AHandler: THandlerResultFunc<T, TResult>): Boolean; overload;
    function Invoke<T1, T2, TResult>(AHandler: THandlerResultFunc<T1, T2, TResult>): Boolean; overload;
    function Invoke<T1, T2, T3, TResult>(AHandler: THandlerResultFunc<T1, T2, T3, TResult>): Boolean; overload;

    /// <summary>
    ///   Invokes a controller action method dynamically using RTTI.
    ///   Uses convention: First param is IHttpContext, rest are route params as strings.
    /// </summary>
    function InvokeAction(AInstance: TObject; AMethod: TRttiMethod): Boolean;
  end;

implementation

uses
  System.Generics.Collections,
  Dext.Json,
  Dext.Validation;

{ THandlerInvoker }

constructor THandlerInvoker.Create(AContext: IHttpContext; AModelBinder: IModelBinder);
begin
  inherited Create;
  FContext := AContext;
  FModelBinder := AModelBinder;
end;

function THandlerInvoker.Validate(const AValue: TValue): Boolean;
begin
  if AValue.Kind <> tkRecord then Exit(True);

  var ValidationResult := TValidator.Validate(AValue);
  try
    if not ValidationResult.IsValid then
    begin
      FContext.Response.Status(400).Json(TDextJson.Serialize(ValidationResult.Errors));
      Result := False;
    end
    else
      Result := True;
  finally
    ValidationResult.Free;
  end;
end;

function THandlerInvoker.Invoke(AHandler: TStaticHandler): Boolean;
begin
  AHandler(FContext);
  Result := True;
end;

function THandlerInvoker.Invoke<T>(AHandler: THandlerProc<T>): Boolean;
var
  Arg1: T;
begin
  // 1. Verify if IHttpContext
  if TypeInfo(T) = TypeInfo(IHttpContext) then
    Arg1 := TValue.From<IHttpContext>(FContext).AsType<T>
  // 2. Records -> Body OR Query (Smart Binding)
  else if PTypeInfo(TypeInfo(T)).Kind = tkRecord then
  begin
    // Smart Binding: GET/DELETE -> Query, POST/PUT/PATCH -> Body
    if (FContext.Request.Method = 'GET') or (FContext.Request.Method = 'DELETE') then
      Arg1 := TModelBinderHelper.BindQuery<T>(FModelBinder, FContext)
    else
      Arg1 := TModelBinderHelper.BindBody<T>(FModelBinder, FContext);
  end
  // 3. Interfaces -> Services
  else if PTypeInfo(TypeInfo(T)).Kind = tkInterface then
    Arg1 := FModelBinder.BindServices(TypeInfo(T), FContext).AsType<T>
  // 4. Primitives -> Route (if available) or Query
  else
  begin
    if FContext.Request.RouteParams.Count > 0 then
      Arg1 := TModelBinderHelper.BindRoute<T>(FModelBinder, FContext)
    else
      Arg1 := TModelBinderHelper.BindQuery<T>(FModelBinder, FContext);
  end;

  if not Validate(TValue.From<T>(Arg1)) then Exit(False);

  AHandler(Arg1);
  Result := True;
end;

function THandlerInvoker.Invoke<T1, T2>(AHandler: THandlerProc<T1, T2>): Boolean;
var
  Arg1: T1;
  Arg2: T2;
begin
  // Argumento 1
  if TypeInfo(T1) = TypeInfo(IHttpContext) then
    Arg1 := TValue.From<IHttpContext>(FContext).AsType<T1>
  else if PTypeInfo(TypeInfo(T1)).Kind = tkRecord then
  begin
    if (FContext.Request.Method = 'GET') or (FContext.Request.Method = 'DELETE') then
      Arg1 := TModelBinderHelper.BindQuery<T1>(FModelBinder, FContext)
    else
      Arg1 := TModelBinderHelper.BindBody<T1>(FModelBinder, FContext);
  end
  else if PTypeInfo(TypeInfo(T1)).Kind = tkInterface then
    Arg1 := FModelBinder.BindServices(TypeInfo(T1), FContext).AsType<T1>
  else
  begin
    if FContext.Request.RouteParams.Count > 0 then
      Arg1 := TModelBinderHelper.BindRoute<T1>(FModelBinder, FContext)
    else
      Arg1 := TModelBinderHelper.BindQuery<T1>(FModelBinder, FContext);
  end;

  // Argumento 2
  if TypeInfo(T2) = TypeInfo(IHttpContext) then
    Arg2 := TValue.From<IHttpContext>(FContext).AsType<T2>
  else if PTypeInfo(TypeInfo(T2)).Kind = tkRecord then
  begin
    if (FContext.Request.Method = 'GET') or (FContext.Request.Method = 'DELETE') then
      Arg2 := TModelBinderHelper.BindQuery<T2>(FModelBinder, FContext)
    else
      Arg2 := TModelBinderHelper.BindBody<T2>(FModelBinder, FContext);
  end
  else if PTypeInfo(TypeInfo(T2)).Kind = tkInterface then
    Arg2 := FModelBinder.BindServices(TypeInfo(T2), FContext).AsType<T2>
  else
  begin
    if FContext.Request.RouteParams.Count > 0 then
      Arg2 := TModelBinderHelper.BindRoute<T2>(FModelBinder, FContext)
    else
      Arg2 := TModelBinderHelper.BindQuery<T2>(FModelBinder, FContext);
  end;

  if not Validate(TValue.From<T1>(Arg1)) then Exit(False);
  if not Validate(TValue.From<T2>(Arg2)) then Exit(False);

  AHandler(Arg1, Arg2);
  Result := True;
end;

function THandlerInvoker.Invoke<T1, T2, T3>(AHandler: THandlerProc<T1, T2, T3>): Boolean;
var
  Arg1: T1;
  Arg2: T2;
  Arg3: T3;
begin
  // Argumento 1
  if TypeInfo(T1) = TypeInfo(IHttpContext) then
    Arg1 := TValue.From<IHttpContext>(FContext).AsType<T1>
  else if PTypeInfo(TypeInfo(T1)).Kind = tkRecord then
  begin
    if (FContext.Request.Method = 'GET') or (FContext.Request.Method = 'DELETE') then
      Arg1 := TModelBinderHelper.BindQuery<T1>(FModelBinder, FContext)
    else
      Arg1 := TModelBinderHelper.BindBody<T1>(FModelBinder, FContext);
  end
  else if PTypeInfo(TypeInfo(T1)).Kind = tkInterface then
    Arg1 := FModelBinder.BindServices(TypeInfo(T1), FContext).AsType<T1>
  else
  begin
    if FContext.Request.RouteParams.Count > 0 then
      Arg1 := TModelBinderHelper.BindRoute<T1>(FModelBinder, FContext)
    else
      Arg1 := TModelBinderHelper.BindQuery<T1>(FModelBinder, FContext);
  end;

  // Argumento 2
  if TypeInfo(T2) = TypeInfo(IHttpContext) then
    Arg2 := TValue.From<IHttpContext>(FContext).AsType<T2>
  else if PTypeInfo(TypeInfo(T2)).Kind = tkRecord then
  begin
    if (FContext.Request.Method = 'GET') or (FContext.Request.Method = 'DELETE') then
      Arg2 := TModelBinderHelper.BindQuery<T2>(FModelBinder, FContext)
    else
      Arg2 := TModelBinderHelper.BindBody<T2>(FModelBinder, FContext);
  end
  else if PTypeInfo(TypeInfo(T2)).Kind = tkInterface then
    Arg2 := FModelBinder.BindServices(TypeInfo(T2), FContext).AsType<T2>
  else
  begin
    if FContext.Request.RouteParams.Count > 0 then
      Arg2 := TModelBinderHelper.BindRoute<T2>(FModelBinder, FContext)
    else
      Arg2 := TModelBinderHelper.BindQuery<T2>(FModelBinder, FContext);
  end;

  // Argumento 3
  if TypeInfo(T3) = TypeInfo(IHttpContext) then
    Arg3 := TValue.From<IHttpContext>(FContext).AsType<T3>
  else if PTypeInfo(TypeInfo(T3)).Kind = tkRecord then
  begin
    if (FContext.Request.Method = 'GET') or (FContext.Request.Method = 'DELETE') then
      Arg3 := TModelBinderHelper.BindQuery<T3>(FModelBinder, FContext)
    else
      Arg3 := TModelBinderHelper.BindBody<T3>(FModelBinder, FContext);
  end
  else if PTypeInfo(TypeInfo(T3)).Kind = tkInterface then
    Arg3 := FModelBinder.BindServices(TypeInfo(T3), FContext).AsType<T3>
  else
  begin
    if FContext.Request.RouteParams.Count > 0 then
      Arg3 := TModelBinderHelper.BindRoute<T3>(FModelBinder, FContext)
    else
      Arg3 := TModelBinderHelper.BindQuery<T3>(FModelBinder, FContext);
  end;

  if not Validate(TValue.From<T1>(Arg1)) then Exit(False);
  if not Validate(TValue.From<T2>(Arg2)) then Exit(False);
  if not Validate(TValue.From<T3>(Arg3)) then Exit(False);

  AHandler(Arg1, Arg2, Arg3);
  Result := True;
end;

function THandlerInvoker.Invoke<TResult>(AHandler: THandlerResultFunc<TResult>): Boolean;
var
  Res: TResult;
  ResIntf: IResult;
begin
  Res := AHandler();
  if TValue.From<TResult>(Res).TryAsType<IResult>(ResIntf) then
    ResIntf.Execute(FContext);
  Result := True;
end;

function THandlerInvoker.Invoke<T, TResult>(AHandler: THandlerResultFunc<T, TResult>): Boolean;
var
  Arg1: T;
  Res: TResult;
  ResIntf: IResult;
begin
  // 1. Verify if IHttpContext
  if TypeInfo(T) = TypeInfo(IHttpContext) then
    Arg1 := TValue.From<IHttpContext>(FContext).AsType<T>
  // 2. Records -> Body OR Query (Smart Binding)
  else if PTypeInfo(TypeInfo(T)).Kind = tkRecord then
  begin
    if (FContext.Request.Method = 'GET') or (FContext.Request.Method = 'DELETE') then
      Arg1 := TModelBinderHelper.BindQuery<T>(FModelBinder, FContext)
    else
      Arg1 := TModelBinderHelper.BindBody<T>(FModelBinder, FContext);
  end
  // 3. Interfaces -> Services
  else if PTypeInfo(TypeInfo(T)).Kind = tkInterface then
    Arg1 := FModelBinder.BindServices(TypeInfo(T), FContext).AsType<T>
  // 4. Primitives -> Route (if available) or Query
  else
  begin
    if FContext.Request.RouteParams.Count > 0 then
      Arg1 := TModelBinderHelper.BindRoute<T>(FModelBinder, FContext)
    else
      Arg1 := TModelBinderHelper.BindQuery<T>(FModelBinder, FContext);
  end;

  if not Validate(TValue.From<T>(Arg1)) then Exit(False);

  Res := AHandler(Arg1);
  if TValue.From<TResult>(Res).TryAsType<IResult>(ResIntf) then
    ResIntf.Execute(FContext);
  Result := True;
end;

function THandlerInvoker.Invoke<T1, T2, TResult>(AHandler: THandlerResultFunc<T1, T2, TResult>): Boolean;
var
  Arg1: T1;
  Arg2: T2;
  Res: TResult;
  ResIntf: IResult;
begin
  // Argumento 1
  if TypeInfo(T1) = TypeInfo(IHttpContext) then
    Arg1 := TValue.From<IHttpContext>(FContext).AsType<T1>
  else if PTypeInfo(TypeInfo(T1)).Kind = tkRecord then
  begin
    if (FContext.Request.Method = 'GET') or (FContext.Request.Method = 'DELETE') then
      Arg1 := TModelBinderHelper.BindQuery<T1>(FModelBinder, FContext)
    else
      Arg1 := TModelBinderHelper.BindBody<T1>(FModelBinder, FContext);
  end
  else if PTypeInfo(TypeInfo(T1)).Kind = tkInterface then
    Arg1 := FModelBinder.BindServices(TypeInfo(T1), FContext).AsType<T1>
  else
  begin
    if FContext.Request.RouteParams.Count > 0 then
      Arg1 := TModelBinderHelper.BindRoute<T1>(FModelBinder, FContext)
    else
      Arg1 := TModelBinderHelper.BindQuery<T1>(FModelBinder, FContext);
  end;

  // Argumento 2
  if TypeInfo(T2) = TypeInfo(IHttpContext) then
    Arg2 := TValue.From<IHttpContext>(FContext).AsType<T2>
  else if PTypeInfo(TypeInfo(T2)).Kind = tkRecord then
  begin
    if (FContext.Request.Method = 'GET') or (FContext.Request.Method = 'DELETE') then
      Arg2 := TModelBinderHelper.BindQuery<T2>(FModelBinder, FContext)
    else
      Arg2 := TModelBinderHelper.BindBody<T2>(FModelBinder, FContext);
  end
  else if PTypeInfo(TypeInfo(T2)).Kind = tkInterface then
    Arg2 := FModelBinder.BindServices(TypeInfo(T2), FContext).AsType<T2>
  else
  begin
    if FContext.Request.RouteParams.Count > 0 then
      Arg2 := TModelBinderHelper.BindRoute<T2>(FModelBinder, FContext)
    else
      Arg2 := TModelBinderHelper.BindQuery<T2>(FModelBinder, FContext);
  end;

  if not Validate(TValue.From<T1>(Arg1)) then Exit(False);
  if not Validate(TValue.From<T2>(Arg2)) then Exit(False);

  Res := AHandler(Arg1, Arg2);
  if TValue.From<TResult>(Res).TryAsType<IResult>(ResIntf) then
    ResIntf.Execute(FContext);
  Result := True;
end;

function THandlerInvoker.Invoke<T1, T2, T3, TResult>(AHandler: THandlerResultFunc<T1, T2, T3, TResult>): Boolean;
var
  Arg1: T1;
  Arg2: T2;
  Arg3: T3;
  Res: TResult;
  ResIntf: IResult;
begin
  // Argumento 1
  if TypeInfo(T1) = TypeInfo(IHttpContext) then
    Arg1 := TValue.From<IHttpContext>(FContext).AsType<T1>
  else if PTypeInfo(TypeInfo(T1)).Kind = tkRecord then
  begin
    if (FContext.Request.Method = 'GET') or (FContext.Request.Method = 'DELETE') then
      Arg1 := TModelBinderHelper.BindQuery<T1>(FModelBinder, FContext)
    else
      Arg1 := TModelBinderHelper.BindBody<T1>(FModelBinder, FContext);
  end
  else if PTypeInfo(TypeInfo(T1)).Kind = tkInterface then
    Arg1 := FModelBinder.BindServices(TypeInfo(T1), FContext).AsType<T1>
  else
  begin
    if FContext.Request.RouteParams.Count > 0 then
      Arg1 := TModelBinderHelper.BindRoute<T1>(FModelBinder, FContext)
    else
      Arg1 := TModelBinderHelper.BindQuery<T1>(FModelBinder, FContext);
  end;

  // Argumento 2
  if TypeInfo(T2) = TypeInfo(IHttpContext) then
    Arg2 := TValue.From<IHttpContext>(FContext).AsType<T2>
  else if PTypeInfo(TypeInfo(T2)).Kind = tkRecord then
  begin
    if (FContext.Request.Method = 'GET') or (FContext.Request.Method = 'DELETE') then
      Arg2 := TModelBinderHelper.BindQuery<T2>(FModelBinder, FContext)
    else
      Arg2 := TModelBinderHelper.BindBody<T2>(FModelBinder, FContext);
  end
  else if PTypeInfo(TypeInfo(T2)).Kind = tkInterface then
    Arg2 := FModelBinder.BindServices(TypeInfo(T2), FContext).AsType<T2>
  else
  begin
    if FContext.Request.RouteParams.Count > 0 then
      Arg2 := TModelBinderHelper.BindRoute<T2>(FModelBinder, FContext)
    else
      Arg2 := TModelBinderHelper.BindQuery<T2>(FModelBinder, FContext);
  end;

  // Argumento 3
  if TypeInfo(T3) = TypeInfo(IHttpContext) then
    Arg3 := TValue.From<IHttpContext>(FContext).AsType<T3>
  else if PTypeInfo(TypeInfo(T3)).Kind = tkRecord then
  begin
    if (FContext.Request.Method = 'GET') or (FContext.Request.Method = 'DELETE') then
      Arg3 := TModelBinderHelper.BindQuery<T3>(FModelBinder, FContext)
    else
      Arg3 := TModelBinderHelper.BindBody<T3>(FModelBinder, FContext);
  end
  else if PTypeInfo(TypeInfo(T3)).Kind = tkInterface then
    Arg3 := FModelBinder.BindServices(TypeInfo(T3), FContext).AsType<T3>
  else
  begin
    if FContext.Request.RouteParams.Count > 0 then
      Arg3 := TModelBinderHelper.BindRoute<T3>(FModelBinder, FContext)
    else
      Arg3 := TModelBinderHelper.BindQuery<T3>(FModelBinder, FContext);
  end;

  if not Validate(TValue.From<T1>(Arg1)) then Exit(False);
  if not Validate(TValue.From<T2>(Arg2)) then Exit(False);
  if not Validate(TValue.From<T3>(Arg3)) then Exit(False);

  Res := AHandler(Arg1, Arg2, Arg3);
  if TValue.From<TResult>(Res).TryAsType<IResult>(ResIntf) then
    ResIntf.Execute(FContext);
  Result := True;
end;

function THandlerInvoker.InvokeAction(AInstance: TObject; AMethod: TRttiMethod): Boolean;
var
  Args: TArray<TValue>;
  ResultValue: TValue;
  ResIntf: IResult;
  I: Integer;
begin
  // ✅ VERIFICAÇÃO DE SEGURANÇA APRIMORADA
  if not Assigned(AMethod) then
  begin
    FContext.Response.Status(500).Json('{"error": "Internal server error: Method reference lost"}');
    Exit(False);
  end;

  // ✅ DYNAMIC BINDING: Use ModelBinder to resolve all parameters
  // This supports: IHttpContext, Route Params, Query Params, Body (Records), Services (Interfaces)
  try
    Args := FModelBinder.BindMethodParameters(AMethod, FContext);
  except
    on E: Exception do
    begin
      FContext.Response.Status(400).Json(Format('{"error": "Bad Request: %s"}', [E.Message]));
      Exit(False);
    end;
  end;

  // ✅ VALIDATION: Validate all record parameters
  for I := 0 to High(Args) do
  begin
    if not Validate(Args[I]) then Exit(False);
  end;

  try
    ResultValue := AMethod.Invoke(AInstance, Args);

    // ✅ LIDAR COM PROCEDURES (SEM RETORNO)
    if ResultValue.IsEmpty then
    begin
      // Não faz nada - o controller já setou a resposta via Ctx.Response
    end
    else
    begin
      // ✅ VERIFICAR SE RETORNOU IResult (APENAS SE NÃO ESTIVER VAZIO)
      if ResultValue.TryAsType<IResult>(ResIntf) then
      begin
        ResIntf.Execute(FContext);
      end
      else
      begin
        // ✅ AUTO-SERIALIZATION
        FContext.Response.Json(TDextJson.Serialize(ResultValue));
      end;
    end;

  except
    on E: Exception do
    begin
      FContext.Response.Status(500).Json(Format('{"error": "Method invocation failed: %s"}', [E.Message]));
      Exit(False);
    end;
  end;

  Result := True;
end;

end.



