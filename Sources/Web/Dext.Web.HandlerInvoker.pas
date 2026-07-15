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
  Dext.Types.UUID,
  Dext.Web.Interfaces,
  Dext.Web.Controllers,
  Dext.Web.ModelBinding,
  Dext.Utils;

type
  THandlerInvoker = class;

  { Basic Invoker - PHASE 1.1 }
  // Generic handler type definitions
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

  TDextArgBinder = function(Invoker: THandlerInvoker): TValue;

  TDextBinderFactory<T> = class
  private
    class var FIsEntity: Boolean;
    class constructor Create;
  public
    class function Bind(Invoker: THandlerInvoker): TValue;
  end;

  /// <summary>
  ///   Engine responsible for orchestrating handler invocation (Minimal API and Controllers).
  ///   Manages argument resolution via Model Binding, validation execution,
  ///   and the lifecycle of objects created during the request.
  /// </summary>
  THandlerInvoker = class
  private
    FModelBinder: IModelBinder;
    FContext: IHttpContext;
    FBoundObjects: TArray<TObject>;  // Tracks objects created by Model Binding for automatic cleanup
    FBoundObjectCount: Integer;
    FArgsBuffer: TArray<TValue>;
    function Validate(const AValue: TValue): Boolean;
    /// <summary>Frees all objects instantiated by binding that are not managed elsewhere.</summary>
    procedure CleanupBoundObjects;
  public
    constructor Create(AContext: IHttpContext; AModelBinder: IModelBinder);
    property Context: IHttpContext read FContext;
    property ModelBinder: IModelBinder read FModelBinder;
    procedure Track(const AValue: TValue; AIsEntity: Boolean = False);

    /// <summary>Invokes a simple static handler.</summary>
    function Invoke(AHandler: TStaticHandler): Boolean; overload;

    /// <summary>
    ///   Invokes a generic handler with 1 argument.
    ///   Performs automatic binding: Context, Records (Hybrid), Classes (Body/Query), Services, or Primitives.
    /// </summary>
    function Invoke<T>(AHandler: THandlerProc<T>): Boolean; overload;

    /// <summary>Invokes a generic handler with 2 arguments.</summary>
    function Invoke<T1, T2>(AHandler: THandlerProc<T1, T2>): Boolean; overload;
    
    /// <summary>Invokes a generic handler with 3 arguments.</summary>
    function Invoke<T1, T2, T3>(AHandler: THandlerProc<T1, T2, T3>): Boolean; overload;

    // Methods for handlers returning IResult
    function Invoke<TResult>(AHandler: THandlerResultFunc<TResult>): Boolean; overload;
    function Invoke<T, TResult>(AHandler: THandlerResultFunc<T, TResult>): Boolean; overload;
    function Invoke<T1, T2, TResult>(AHandler: THandlerResultFunc<T1, T2, TResult>): Boolean; overload;
    function Invoke<T1, T2, T3, TResult>(AHandler: THandlerResultFunc<T1, T2, T3, TResult>): Boolean; overload;

    /// <summary>
    ///   Dynamically invokes a controller action method using RTTI.
    ///   Supports parameter injection, auto-validation, and automatic result serialization.
    /// </summary>
    function InvokeAction(AInstance: TObject; AMethod: TRttiMethod): Boolean;
  end;

implementation

uses
  Dext.Json
  {$IFDEF DEXT_ENABLE_ENTITY}
  ,Dext.Entity.Attributes
  {$ENDIF}
  ,Dext.Validation
  ,Dext.Core.Reflection
  ,Dext.DI.Interfaces;

{ TDextBinderFactory<T> }

class constructor TDextBinderFactory<T>.Create;
var
  CtxRtti: TRttiContext;
  Typ: TRttiType;
  Attr: TCustomAttribute;
begin
  FIsEntity := False;
  if PTypeInfo(TypeInfo(T)).Kind = tkClass then
  begin
    CtxRtti := TReflection.Context;
    Typ := CtxRtti.GetType(TypeInfo(T));
    if Typ <> nil then
    begin
      for Attr in Typ.GetAttributes do
      begin
        if Attr.ClassName = 'TableAttribute' then
        begin
          FIsEntity := True;
          Break;
        end;
      end;
    end;
  end;
end;

class function TDextBinderFactory<T>.Bind(Invoker: THandlerInvoker): TValue;
var
  BoundVal: TValue;
begin
  if TypeInfo(T) = TypeInfo(IHttpContext) then
    Exit(TValue.From<IHttpContext>(Invoker.Context));

  if TypeInfo(T) = TypeInfo(TGUID) then
  begin
    if Invoker.Context.Request.RouteParams.Count > 0 then
      Exit(TValue.From<TGUID>(TModelBinderHelper.BindRoute<TGUID>(
        Invoker.ModelBinder, Invoker.Context)))
    else
      Exit(TValue.From<TGUID>(TModelBinderHelper.BindQuery<TGUID>(
        Invoker.ModelBinder, Invoker.Context)));
  end;

  if TypeInfo(T) = TypeInfo(TUUID) then
  begin
    if Invoker.Context.Request.RouteParams.Count > 0 then
      Exit(TValue.From<TUUID>(TModelBinderHelper.BindRoute<TUUID>(
        Invoker.ModelBinder, Invoker.Context)))
    else
      Exit(TValue.From<TUUID>(TModelBinderHelper.BindQuery<TUUID>(
        Invoker.ModelBinder, Invoker.Context)));
  end;

  if PTypeInfo(TypeInfo(T)).Kind = tkRecord then
  begin
    Exit(Invoker.ModelBinder.BindRecordHybrid(TypeInfo(T), Invoker.Context));
  end;

  if PTypeInfo(TypeInfo(T)).Kind = tkClass then
  begin
    BoundVal := TValue.Empty;
    try
      BoundVal := Invoker.ModelBinder.BindServices(TypeInfo(T), Invoker.Context);
    except
    end;

    if not BoundVal.IsEmpty and (BoundVal.AsObject <> nil) then
      Exit(BoundVal);

    if (Invoker.Context.Request.Method = 'GET') or
       (Invoker.Context.Request.Method = 'DELETE') then
      BoundVal := TValue.From<T>(TModelBinderHelper.BindQuery<T>(
        Invoker.ModelBinder, Invoker.Context))
    else
      BoundVal := TValue.From<T>(TModelBinderHelper.BindBody<T>(
        Invoker.ModelBinder, Invoker.Context));

    Invoker.Track(BoundVal, FIsEntity);
    Exit(BoundVal);
  end;

  if PTypeInfo(TypeInfo(T)).Kind = tkInterface then
  begin
    Exit(Invoker.ModelBinder.BindServices(TypeInfo(T), Invoker.Context));
  end;

  if Invoker.Context.Request.RouteParams.Count > 0 then
    Result := TValue.From<T>(TModelBinderHelper.BindRoute<T>(
      Invoker.ModelBinder, Invoker.Context))
  else
    Result := TValue.From<T>(TModelBinderHelper.BindQuery<T>(
      Invoker.ModelBinder, Invoker.Context));
end;

{ THandlerInvoker }

constructor THandlerInvoker.Create(AContext: IHttpContext; AModelBinder: IModelBinder);
begin
  inherited Create;
  FContext := AContext;
  FModelBinder := AModelBinder;
  FBoundObjects := nil;  // Will be populated as objects are resolved
  FBoundObjectCount := 0;
end;

procedure THandlerInvoker.CleanupBoundObjects;
var
  I: Integer;
  Obj: TObject;
begin
  for I := 0 to FBoundObjectCount - 1 do
  begin
    Obj := FBoundObjects[I];
    if Obj <> nil then
       Obj.Free;
  end;
  FBoundObjects := nil;
  FBoundObjectCount := 0;
end;

procedure THandlerInvoker.Track(const AValue: TValue; AIsEntity: Boolean);
begin
  if (AValue.Kind = tkClass) and (AValue.AsObject <> nil) and
     (not AIsEntity) then
  begin
    if FBoundObjectCount = Length(FBoundObjects) then
    begin
      if FBoundObjectCount = 0 then
        SetLength(FBoundObjects, 4)
      else
        SetLength(FBoundObjects, FBoundObjectCount * 2);
    end;
    FBoundObjects[FBoundObjectCount] := AValue.AsObject;
    Inc(FBoundObjectCount);
  end;
end;

function THandlerInvoker.Validate(const AValue: TValue): Boolean;
var
  ValidationResult: TValidationResult;
  I: Integer;
  Meta: TTypeMetadata;
  ValidatorIntf: IInterface;
  Validator: IValidator;
begin
  Result := True;
  
  // Handle Arrays/Collections
  if AValue.Kind = tkDynArray then
  begin
    for I := 0 to AValue.GetArrayLength - 1 do
    begin
      if not Validate(AValue.GetArrayElement(I)) then
        Exit(False); // Stop at first item with errors for now, or collect all?
    end;
    Exit;
  end;

  if (AValue.Kind <> tkRecord) and (AValue.Kind <> tkClass) then Exit(True);
  if (AValue.Kind = tkClass) and (AValue.AsObject = nil) then Exit(True);

  Meta := TReflection.GetMetadata(AValue.TypeInfo);
  ValidatorIntf := nil;
  if (Meta.ValidatorInterfaceType <> nil) and (FContext.Services <> nil) then
  begin
    try
      ValidatorIntf := FContext.Services.GetServiceAsInterface(TServiceType.FromInterface(Meta.ValidatorInterfaceType));
    except
      // DI resolution failed
    end;
  end;

  if (ValidatorIntf <> nil) and Supports(ValidatorIntf, IValidator, Validator) then
    ValidationResult := Validator.ValidateInstance(AValue)
  else
    ValidationResult := TValidator.Validate(AValue);
  try
    if not ValidationResult.IsValid then
    begin
      FContext.Response.Status(400).Json(TDextJson.Serialize(ValidationResult.Errors));
      Result := False;
    end;
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
  try
    try
      Arg1 := TDextBinderFactory<T>.Bind(Self).AsType<T>;

      if not Validate(TValue.From<T>(Arg1)) then Exit(False);

      AHandler(Arg1);
      Result := True;
    except
      on E: Exception do
      begin
        SafeWriteln('[Dext.Web] Binding/Validation Error: ' + E.ClassName + ': ' + E.Message);
        FContext.Response.Status(400).Json(Format('{"error": "Binding error: %s"}', [E.Message]));
        Result := False;
      end;
    end;
  finally
    CleanupBoundObjects;
  end;
end;

function THandlerInvoker.Invoke<T1, T2>(AHandler: THandlerProc<T1, T2>): Boolean;
var
  Arg1: T1;
  Arg2: T2;
begin
  try
    try
      Arg1 := TDextBinderFactory<T1>.Bind(Self).AsType<T1>;
      Arg2 := TDextBinderFactory<T2>.Bind(Self).AsType<T2>;

      if not Validate(TValue.From<T1>(Arg1)) then Exit(False);
      if not Validate(TValue.From<T2>(Arg2)) then Exit(False);

      AHandler(Arg1, Arg2);
      Result := True;
    except
      on E: Exception do
      begin
        SafeWriteln('[Dext.Web] Binding/Validation Error: ' + E.ClassName + ': ' + E.Message);
        FContext.Response.Status(400).Json(Format('{"error": "Binding error: %s"}', [E.Message]));
        Result := False;
      end;
    end;
  finally
    CleanupBoundObjects;
  end;
end;

function THandlerInvoker.Invoke<T1, T2, T3>(AHandler: THandlerProc<T1, T2, T3>): Boolean;
var
  Arg1: T1;
  Arg2: T2;
  Arg3: T3;
begin
  try
    Arg1 := TDextBinderFactory<T1>.Bind(Self).AsType<T1>;
    Arg2 := TDextBinderFactory<T2>.Bind(Self).AsType<T2>;
    Arg3 := TDextBinderFactory<T3>.Bind(Self).AsType<T3>;

    if not Validate(TValue.From<T1>(Arg1)) then Exit(False);
    if not Validate(TValue.From<T2>(Arg2)) then Exit(False);
    if not Validate(TValue.From<T3>(Arg3)) then Exit(False);

    AHandler(Arg1, Arg2, Arg3);
    Result := True;
  finally
    CleanupBoundObjects;
  end;
end;

function THandlerInvoker.Invoke<TResult>(AHandler: THandlerResultFunc<TResult>): Boolean;
var
  Res: TResult;
  ResIntf: IResult;
begin
  try
    Res := AHandler();
    if TValue.From<TResult>(Res).TryAsType<IResult>(ResIntf) then
      ResIntf.Execute(FContext);
    Result := True;
  finally
    CleanupBoundObjects;
  end;
end;

function THandlerInvoker.Invoke<T, TResult>(AHandler: THandlerResultFunc<T, TResult>): Boolean;
var
  Arg1: T;
  Res: TResult;
  ResIntf: IResult;
begin
  try
    try
      Arg1 := TDextBinderFactory<T>.Bind(Self).AsType<T>;
      if (TypeInfo(T) <> TypeInfo(TGUID)) and (TypeInfo(T) <> TypeInfo(TUUID)) then
      begin
        if not Validate(TValue.From<T>(Arg1)) then Exit(False);
      end;
      Res := AHandler(Arg1);
      if TValue.From<TResult>(Res).TryAsType<IResult>(ResIntf) then
        ResIntf.Execute(FContext);
      Result := True;
    except
      on E: Exception do
      begin
        SafeWriteln('[Dext.Web] Binding/Validation Error: ' + E.ClassName + ': ' + E.Message);
        FContext.Response.Status(400).Json(Format('{"error": "Binding error: %s"}', [E.Message]));
        Result := False;
      end;
    end;
  finally
    CleanupBoundObjects;
  end;
end;

function THandlerInvoker.Invoke<T1, T2, TResult>(AHandler: THandlerResultFunc<T1, T2, TResult>): Boolean;
var
  Arg1: T1;
  Arg2: T2;
  Res: TResult;
  ResIntf: IResult;
begin
  try
    try
      Arg1 := TDextBinderFactory<T1>.Bind(Self).AsType<T1>;
      Arg2 := TDextBinderFactory<T2>.Bind(Self).AsType<T2>;

      if (TypeInfo(T1) <> TypeInfo(TGUID)) and (TypeInfo(T1) <> TypeInfo(TUUID)) then
      begin
        if not Validate(TValue.From<T1>(Arg1)) then Exit(False);
      end;
      if (TypeInfo(T2) <> TypeInfo(TGUID)) and (TypeInfo(T2) <> TypeInfo(TUUID)) then
      begin
        if not Validate(TValue.From<T2>(Arg2)) then Exit(False);
      end;

      Res := AHandler(Arg1, Arg2);
      if TValue.From<TResult>(Res).TryAsType<IResult>(ResIntf) then
        ResIntf.Execute(FContext);
      Result := True;
    except
      on E: Exception do
      begin
        SafeWriteln('[Dext.Web] Binding/Validation Error: ' + E.ClassName + ': ' + E.Message);
        FContext.Response.Status(400).Json(Format('{"error": "Binding error: %s"}', [E.Message]));
        Result := False;
      end;
    end;
  finally
    CleanupBoundObjects;
  end;
end;

function THandlerInvoker.Invoke<T1, T2, T3, TResult>(AHandler: THandlerResultFunc<T1, T2, T3, TResult>): Boolean;
var
  Arg1: T1;
  Arg2: T2;
  Arg3: T3;
  Res: TResult;
  ResIntf: IResult;
begin
  try
    Arg1 := TDextBinderFactory<T1>.Bind(Self).AsType<T1>;
    Arg2 := TDextBinderFactory<T2>.Bind(Self).AsType<T2>;
    Arg3 := TDextBinderFactory<T3>.Bind(Self).AsType<T3>;

    if (TypeInfo(T1) <> TypeInfo(TGUID)) and (TypeInfo(T1) <> TypeInfo(TUUID)) then
    begin
      if not Validate(TValue.From<T1>(Arg1)) then Exit(False);
    end;
    if (TypeInfo(T2) <> TypeInfo(TGUID)) and (TypeInfo(T2) <> TypeInfo(TUUID)) then
    begin
      if not Validate(TValue.From<T2>(Arg2)) then Exit(False);
    end;
    if (TypeInfo(T3) <> TypeInfo(TGUID)) and (TypeInfo(T3) <> TypeInfo(TUUID)) then
    begin
      if not Validate(TValue.From<T3>(Arg3)) then Exit(False);
    end;

    Res := AHandler(Arg1, Arg2, Arg3);
    if TValue.From<TResult>(Res).TryAsType<IResult>(ResIntf) then
      ResIntf.Execute(FContext);
    Result := True;
  finally
    CleanupBoundObjects;
  end;
end;

function THandlerInvoker.InvokeAction(AInstance: TObject; AMethod: TRttiMethod): Boolean;
var
  ResultValue: TValue;
  ResIntf: IResult;
  I: Integer;
begin
  // ? VERIFICAÇÃO DE SEGURANÇA APRIMORADA
  if not Assigned(AMethod) then
  begin
    FContext.Response.Status(500).Json('{"error": "Internal server error: Method reference lost"}');
    Exit(False);
  end;

  // ? DYNAMIC BINDING: Use ModelBinder to resolve all parameters
  // This supports: IHttpContext, Route Params, Query Params, Body (Records), Services (Interfaces)
  try
    FModelBinder.BindMethodParameters(AMethod, FContext, FArgsBuffer);
  except
    on E: Exception do
    begin
      FContext.Response.Status(400).Json(Format('{"error": "Bad Request: %s"}', [E.Message]));
      Exit(False);
    end;
  end;

  // VALIDATION: Validate all record parameters
  for I := 0 to High(FArgsBuffer) do
  begin
    if not Validate(FArgsBuffer[I]) then Exit(False);
  end;

  try
    ResultValue := AMethod.Invoke(AInstance, FArgsBuffer);

    // LIDAR COM PROCEDURES (SEM RETORNO)
    if ResultValue.IsEmpty then
    begin
      // Não faz nada - o controller já setou a resposta via Ctx.Response
    end
    else
    begin
      // VERIFICAR SE RETORNOU IResult (APENAS SE NÃO ESTIVER VAZIO)
      if ResultValue.TryAsType<IResult>(ResIntf) then
      begin
        ResIntf.Execute(FContext);
      end
      else
      begin
        // AUTO-SERIALIZATION
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

