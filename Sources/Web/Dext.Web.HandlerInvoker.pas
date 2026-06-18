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
    function Validate(const AValue: TValue): Boolean;
    /// <summary>Resolves and binds an individual argument based on its type.</summary>
    function ResolveArgument<T>: T;
    /// <summary>Frees all objects instantiated by binding that are not managed elsewhere.</summary>
    procedure CleanupBoundObjects;
  public
    constructor Create(AContext: IHttpContext; AModelBinder: IModelBinder);

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

{ THandlerInvoker }

constructor THandlerInvoker.Create(AContext: IHttpContext; AModelBinder: IModelBinder);
begin
  inherited Create;
  FContext := AContext;
  FModelBinder := AModelBinder;
  FBoundObjects := nil;  // Will be populated as objects are resolved
end;

procedure THandlerInvoker.CleanupBoundObjects;
var
  I: Integer;
  Obj: TObject;
begin
  for I := 0 to High(FBoundObjects) do
  begin
    Obj := FBoundObjects[I];
    if Obj <> nil then
       Obj.Free;
  end;
  FBoundObjects := nil;
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

function THandlerInvoker.ResolveArgument<T>: T;
var
  Bound: Boolean;
  Svc: TValue;
  IsEntity: Boolean;
  CtxRtti: TRttiContext;
  Typ: TRttiType;
  Attr: TCustomAttribute;
begin
  Result := Default(T);
  // 1. Verify if IHttpContext
  if TypeInfo(T) = TypeInfo(IHttpContext) then
    Result := TValue.From<IHttpContext>(FContext).AsType<T>
  // 2. Special Records (TGUID, TUUID) -> Route binding (like primitives)
  else if (TypeInfo(T) = TypeInfo(TGUID)) or (TypeInfo(T) = TypeInfo(TUUID)) then
  begin
    if FContext.Request.RouteParams.Count > 0 then
      Result := TModelBinderHelper.BindRoute<T>(FModelBinder, FContext)
    else
      Result := TModelBinderHelper.BindQuery<T>(FModelBinder, FContext);
  end
  // 3. Records -> Hybrid Binding (respects [FromHeader], [FromQuery], [FromRoute], [FromBody] attributes)
  else if PTypeInfo(TypeInfo(T)).Kind = tkRecord then
  begin
    // Use hybrid binding that supports mixed sources based on field attributes
    Result := FModelBinder.BindRecordHybrid(TypeInfo(T), FContext).AsType<T>;
  end
  // 4. Classes -> Try DI first, then Body/Query
  else if PTypeInfo(TypeInfo(T)).Kind = tkClass then
  begin
    Bound := False;
    
    // For Classes, try DI first
    try
      Svc := FModelBinder.BindServices(TypeInfo(T), FContext);
      if (not Svc.IsEmpty) and (Svc.AsObject <> nil) then
      begin
         Result := Svc.AsType<T>;
         Bound := True;
      end;
    except
      // Ignore service binding errors, cascade to Body/Query
    end;

    if not Bound then
    begin
       // Smart Binding: GET/DELETE -> Query, POST/PUT/PATCH -> Body
       if (FContext.Request.Method = 'GET') or (FContext.Request.Method = 'DELETE') then
         Result := TModelBinderHelper.BindQuery<T>(FModelBinder, FContext)
       else
         Result := TModelBinderHelper.BindBody<T>(FModelBinder, FContext);
       
       // Track the created object for cleanup.
       // Entities ([Table]) are NOT tracked because the DbContext assumes ownership.
       if TValue.From<T>(Result).AsObject <> nil then
       begin
         IsEntity := False;
         CtxRtti := TReflection.Context;
         try
           Typ := CtxRtti.GetType(TypeInfo(T));
           if Typ <> nil then
           begin
             for Attr in Typ.GetAttributes do
             begin
               IsEntity := Attr.ClassName = 'TableAttribute';
               if IsEntity then Break;
             end;
           end;
         finally
         ;
         end;

         if not IsEntity then
         begin
           SetLength(FBoundObjects, Length(FBoundObjects) + 1);
           FBoundObjects[High(FBoundObjects)] := TValue.From<T>(Result).AsObject;
         end;
       end;
    end;
  end
  // 5. Interfaces -> Services
  else if PTypeInfo(TypeInfo(T)).Kind = tkInterface then
    Result := FModelBinder.BindServices(TypeInfo(T), FContext).AsType<T>
  // 6. Primitives -> Route (if available) or Query
  else
  begin
    if FContext.Request.RouteParams.Count > 0 then
      Result := TModelBinderHelper.BindRoute<T>(FModelBinder, FContext)
    else
      Result := TModelBinderHelper.BindQuery<T>(FModelBinder, FContext);
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
      Arg1 := ResolveArgument<T>;

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
      Arg1 := ResolveArgument<T1>;
      Arg2 := ResolveArgument<T2>;

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
    Arg1 := ResolveArgument<T1>;
    Arg2 := ResolveArgument<T2>;
    Arg3 := ResolveArgument<T3>;

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
      Arg1 := ResolveArgument<T>;
      // Skip validation for TGUID/TUUID (no validation attributes, and TValue.From fails)
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
      Arg1 := ResolveArgument<T1>;
      Arg2 := ResolveArgument<T2>;

      // Skip validation for TGUID/TUUID (no validation attributes, and TValue.From fails)
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
    Arg1 := ResolveArgument<T1>;
    Arg2 := ResolveArgument<T2>;
    Arg3 := ResolveArgument<T3>;

    // Skip validation for TGUID/TUUID (no validation attributes, and TValue.From fails)
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
  Args: TArray<TValue>;
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
    Args := FModelBinder.BindMethodParameters(AMethod, FContext);
  except
    on E: Exception do
    begin
      FContext.Response.Status(400).Json(Format('{"error": "Bad Request: %s"}', [E.Message]));
      Exit(False);
    end;
  end;

  // VALIDATION: Validate all record parameters
  for I := 0 to High(Args) do
  begin
    if not Validate(Args[I]) then Exit(False);
  end;

  try
    ResultValue := AMethod.Invoke(AInstance, Args);

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

