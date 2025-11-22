unit Dext.Core.HandlerInvoker;

interface

uses
  System.SysUtils,
  System.Rtti,
  System.TypInfo,
  Dext.Http.Interfaces,
  Dext.Core.Controllers,
  Dext.Core.ModelBinding;

type
  { Invoker básico - FASE 1.1 }
  // Definição de tipos de handlers genéricos
  THandlerProc<T> = reference to procedure(Arg1: T);
  THandlerProc<T1, T2> = reference to procedure(Arg1: T1; Arg2: T2);
  THandlerProc<T1, T2, T3> = reference to procedure(Arg1: T1; Arg2: T2; Arg3: T3);

  // Handlers returning IResult
  THandlerFunc<TResult> = reference to function: TResult;
  THandlerFunc<T, TResult> = reference to function(Arg1: T): TResult;
  THandlerFunc<T1, T2, TResult> = reference to function(Arg1: T1; Arg2: T2): TResult;
  THandlerFunc<T1, T2, T3, TResult> = reference to function(Arg1: T1; Arg2: T2; Arg3: T3): TResult;

  THandlerInvoker = class
  private
    FModelBinder: IModelBinder;
    FContext: IHttpContext;
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
    function Invoke<TResult>(AHandler: THandlerFunc<TResult>): Boolean; overload;
    function Invoke<T, TResult>(AHandler: THandlerFunc<T, TResult>): Boolean; overload;
    function Invoke<T1, T2, TResult>(AHandler: THandlerFunc<T1, T2, TResult>): Boolean; overload;
    function Invoke<T1, T2, T3, TResult>(AHandler: THandlerFunc<T1, T2, T3, TResult>): Boolean; overload;
  end;

implementation

{ THandlerInvoker }

{ THandlerInvoker }

constructor THandlerInvoker.Create(AContext: IHttpContext; AModelBinder: IModelBinder);
begin
  inherited Create;
  FContext := AContext;
  FModelBinder := AModelBinder;
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

  AHandler(Arg1, Arg2, Arg3);
  Result := True;
end;

function THandlerInvoker.Invoke<TResult>(AHandler: THandlerFunc<TResult>): Boolean;
var
  Res: TResult;
  ResIntf: IResult;
begin
  Res := AHandler();
  if TValue.From<TResult>(Res).TryAsType<IResult>(ResIntf) then
    ResIntf.Execute(FContext);
  Result := True;
end;

function THandlerInvoker.Invoke<T, TResult>(AHandler: THandlerFunc<T, TResult>): Boolean;
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

  Res := AHandler(Arg1);
  if TValue.From<TResult>(Res).TryAsType<IResult>(ResIntf) then
    ResIntf.Execute(FContext);
  Result := True;
end;

function THandlerInvoker.Invoke<T1, T2, TResult>(AHandler: THandlerFunc<T1, T2, TResult>): Boolean;
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

  Res := AHandler(Arg1, Arg2);
  if TValue.From<TResult>(Res).TryAsType<IResult>(ResIntf) then
    ResIntf.Execute(FContext);
  Result := True;
end;

function THandlerInvoker.Invoke<T1, T2, T3, TResult>(AHandler: THandlerFunc<T1, T2, T3, TResult>): Boolean;
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

  Res := AHandler(Arg1, Arg2, Arg3);
  if TValue.From<TResult>(Res).TryAsType<IResult>(ResIntf) then
    ResIntf.Execute(FContext);
  Result := True;
end;

end.
