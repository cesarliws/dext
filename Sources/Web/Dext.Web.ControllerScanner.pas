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
unit Dext.Web.ControllerScanner;

interface

uses
  System.Classes,
  System.Rtti,
  System.SysUtils,
  System.TypInfo,
  Dext.Web.Routing.Attributes,
  Dext.DI.Interfaces,
  Dext.Filters,
  Dext.Web.Interfaces,
  Dext.Collections,
  Dext.OpenAPI.Attributes;

type
  TControllerMethod = record
    Method: TRttiMethod;
    RouteAttribute: RouteAttribute;
    Path: string;
    HttpMethod: string;
  end;

  TControllerInfo = record
    RttiType: TRttiType;
    Methods: TArray<TControllerMethod>;
    ControllerAttribute: ApiControllerAttribute;
  end;

  TCachedMethod = record
    TypeName: string;
    MethodName: string;
    IsClass: Boolean;
    FullPath: string;
    HttpMethod: string;
    RequiresAuth: Boolean;
  end;

  IControllerScanner = interface
    function FindControllers: TArray<TControllerInfo>;
    procedure RegisterServices(Services: IServiceCollection);
    function RegisterRoutes(AppBuilder: IApplicationBuilder): Integer;
  end;

  TControllerScanner = class(TInterfacedObject, IControllerScanner)
  private
    FCachedMethods: IList<TCachedMethod>;
    procedure ExecuteCachedMethod(Context: IHttpContext; const CachedMethod: TCachedMethod);
    function CreateHandler(const AMethod: TCachedMethod): TRequestDelegate;
  public
    constructor Create;
    destructor Destroy; override;
    function FindControllers: TArray<TControllerInfo>;
    procedure RegisterServices(Services: IServiceCollection);
    function RegisterRoutes(AppBuilder: IApplicationBuilder): Integer;
  end;

implementation

uses
  Dext.Auth.Attributes,
  Dext.Core.Activator,
  Dext.Utils,
  Dext.Web.HandlerInvoker,
  Dext.Web.ModelBinding;

{ TControllerScanner }

constructor TControllerScanner.Create;
begin
  inherited Create;
  FCachedMethods := TCollections.CreateList<TCachedMethod>;
end;

function TControllerScanner.FindControllers: TArray<TControllerInfo>;
var
  Types: TArray<TRttiType>;
  RttiType: TRttiType;
  ControllerInfo: TControllerInfo;
  Controllers: IList<TControllerInfo>;
  Method: TRttiMethod;
  MethodInfo: TControllerMethod;
  Attr: TCustomAttribute;
  HasRouteMethods: Boolean;
  MethodsList: IList<TControllerMethod>;
  Methods: TArray<TRttiMethod>;
  Attributes: TArray<TCustomAttribute>;
  VerbAttrs: TArray<RouteAttribute>;
  PathAttrs: TArray<RouteAttribute>;
  VCount: Integer;
  PCount: Integer;
  J, K: Integer;
  Combined: Boolean;
  V: RouteAttribute;
  P: RouteAttribute;
  R: RouteAttribute;
  TypeAttributes: TArray<TCustomAttribute>;
begin
  Controllers := TCollections.CreateList<TControllerInfo>;
  try
    Types := TActivator.GetRttiContext.GetTypes;

    SafeWriteLn('🔍 ' + Format('Scanning %d types...', [Length(Types)]));

    for RttiType in Types do
    begin
      // FILTER: Records or Classes
      if (RttiType.TypeKind in [tkRecord, tkClass]) then
      begin
        // Verificar se tem métodos com atributos de rota
        HasRouteMethods := False;
        MethodsList := TCollections.CreateList<TControllerMethod>;

        Methods := RttiType.GetMethods;

        for Method in Methods do
        begin
          // ONLY STATIC METHODS (for records) or PUBLIC METHODS (for classes)
          if (RttiType.TypeKind = tkRecord) and (not Method.IsStatic) then
            Continue;

          // Para classes, aceitamos métodos de instância
          if (RttiType.TypeKind = tkClass) and (Method.Visibility <> mvPublic) and (Method.Visibility <> mvPublished) then
             Continue;

          Attributes := Method.GetAttributes;
          VCount := 0;
          PCount := 0;

          SetLength(VerbAttrs, Length(Attributes));
          SetLength(PathAttrs, Length(Attributes));

          // Separate Attributes without dynamic object allocation (TCollections.CreateList)
          for Attr in Attributes do
          begin
            if Attr is RouteAttribute then
            begin
              R := RouteAttribute(Attr);
              if R.Method <> '' then
              begin
                VerbAttrs[VCount] := R;
                Inc(VCount);
              end
              else
              begin
                PathAttrs[PCount] := R;
                Inc(PCount);
              end;
            end;
          end;

          Combined := False;

          // COMBINE: HttpGet (Verb without Path) + Route (Path without Verb)
          for J := 0 to VCount - 1 do
          begin
            V := VerbAttrs[J];
            for K := 0 to PCount - 1 do
            begin
              P := PathAttrs[K];
              if (V.Path = '') and (P.Method = '') then
              begin
                MethodInfo.Method := Method;
                MethodInfo.Path := P.Path;
                MethodInfo.HttpMethod := V.Method;
                MethodInfo.RouteAttribute := V; // ou P
                MethodsList.Add(MethodInfo);
                HasRouteMethods := True;
                Combined := True;
              end;
            end;
          end;

          // If nothing was combined (e.g. independent routes), add individually
          if not Combined then
          begin
            for Attr in Attributes do
            begin
              if Attr is RouteAttribute then
              begin
                R := RouteAttribute(Attr);
                MethodInfo.Method := Method;
                MethodInfo.Path := R.Path;
                MethodInfo.HttpMethod := R.Method;
                MethodInfo.RouteAttribute := R;
                MethodsList.Add(MethodInfo);
                HasRouteMethods := True;
              end;
            end;
          end;
        end;

        // IF ROUTE METHODS EXIST, ADD AS CONTROLLER
        if HasRouteMethods then
        begin
          SafeWriteLn('    ⚡ ADDING CONTROLLER: ' + RttiType.Name);
          ControllerInfo.RttiType := RttiType;
          ControllerInfo.Methods := MethodsList.ToArray;

          // CHECK [ApiController] ATTRIBUTE FOR PREFIX
          ControllerInfo.ControllerAttribute := nil;
          TypeAttributes := RttiType.GetAttributes;
          for Attr in TypeAttributes do
          begin
            if Attr is ApiControllerAttribute then
            begin
              ControllerInfo.ControllerAttribute := ApiControllerAttribute(Attr);
              Break;
            end;
          end;

          Controllers.Add(ControllerInfo);
        end;
      end;
    end;

    Result := Controllers.ToArray;
    SafeWriteLn('✨ ' + Format('Total controllers found: %d', [Length(Result)]));

    {$IFDEF MSWINDOWS}{$WARN SYMBOL_PLATFORM OFF}
    if (Length(Result) = 0) and (DebugHook <> 0) then
    begin
      SafeWriteLn('');
      SafeWriteLn('❌  NO CONTROLLERS FOUND!');
      SafeWriteLn('💡  TIP: If your controllers are not being detected, they might have been optimized away by the linker.');
      SafeWriteLn('    To fix this, add a reference to the controller class in the initialization section of its unit:');
      SafeWriteLn('    initialization');
      SafeWriteLn('      TMyController.ClassName;');
      SafeWriteLn('');
    end;
    {$WARN SYMBOL_PLATFORM ON}{$ENDIF}
  finally
    // Controllers is ARC
  end;
end;

procedure TControllerScanner.RegisterServices(Services: IServiceCollection);
var
  Controllers: TArray<TControllerInfo>;
  Controller: TControllerInfo;
begin
  Controllers := FindControllers;
  SafeWriteLn('⚙️ ' + Format('Registering %d controllers in DI...', [Length(Controllers)]));

  for Controller in Controllers do
  begin
    if Controller.RttiType.TypeKind = tkClass then
    begin
      // Register as Transient
      Services.AddTransient(TServiceType.FromClass(Controller.RttiType.AsInstance.MetaclassType), Controller.RttiType.AsInstance.MetaclassType);
      SafeWriteLn('  ✅ Registered service: ' + Controller.RttiType.Name);
    end;
  end;
end;

function TControllerScanner.RegisterRoutes(AppBuilder: IApplicationBuilder): Integer;
var
  Controllers: TArray<TControllerInfo>;
  Controller: TControllerInfo;
  ControllerMethod: TControllerMethod;
  FullPath: string;
  Prefix: string;
  Attr: TCustomAttribute;
  TypeAttr: TCustomAttribute;
  IsIgnored: Boolean;
  CachedMethod: TCachedMethod;
  ControllerRequiresAuth: Boolean;
  MethodRequiresAuth: Boolean;
  MethodAllowsAnonymous: Boolean;
  SecuritySchemes: IList<string>;
  LScheme: string;
  Routes: TArray<TEndpointMetadata>;
  Metadata: TEndpointMetadata;
  MetadataUpdated: Boolean;
  Updated: Boolean;
  TagAttr: SwaggerTagAttribute;
  Params: TArray<TRttiParameter>;
  Param: TRttiParameter;
  ParamType: TRttiType;
  OpAttr: SwaggerOperationAttribute;
  ResponsesList: TArray<TOpenAPIResponseMetadata>;
  RespAttr: SwaggerResponseAttribute;
  RespMeta: TOpenAPIResponseMetadata;
  R: RouteAttribute;
begin
  Result := 0;
  Controllers := FindControllers;

  SafeWriteLn('🔍 ' + Format('Found %d controllers:', [Length(Controllers)]));

  // METHOD CACHE TO AVOID RTTI REFERENCE ISSUES
  for Controller in Controllers do
  begin
    // CALCULATE CONTROLLER PREFIX
    Prefix := '';
    if Assigned(Controller.ControllerAttribute) then
      Prefix := Controller.ControllerAttribute.Prefix;

    // ? FIX: CHECK FOR [Route] ATTRIBUTE ON CLASS TO OVERRIDE/SET PREFIX
    // This allows support for [ApiController, Route('/api/events')] syntax
    for Attr in Controller.RttiType.GetAttributes do
    begin
      if Attr is RouteAttribute then
      begin
        R := RouteAttribute(Attr);
        if R.Path <> '' then
          Prefix := R.Path;
        // Break? Usually one route attribute per class.
        Break;
      end;
    end;

    SafeWriteLn('  🔹 ' + Format('  %s (Prefix: "%s")', [Controller.RttiType.Name, Prefix]));

    for ControllerMethod in Controller.Methods do
    begin
      // BUILD FULL PATH: Prefix + MethodPath
      FullPath := Prefix + ControllerMethod.Path;

      SafeWriteLn(Format('    %s %s -> %s', [ControllerMethod.HttpMethod, FullPath, ControllerMethod.Method.Name]));

      // ? VERIFICAR [SwaggerIgnore]
      IsIgnored := False;
      for Attr in ControllerMethod.Method.GetAttributes do
        if Attr is SwaggerIgnoreAttribute then
        begin
          IsIgnored := True;
          Break;
        end;

      if IsIgnored then
      begin
        SafeWriteLn('      🚫 Ignored by [SwaggerIgnore]');
        Continue;
      end;

      // ? CRIAR CACHE DO MÉTODO
      CachedMethod.TypeName := Controller.RttiType.QualifiedName;
      CachedMethod.MethodName := ControllerMethod.Method.Name;
      CachedMethod.IsClass := (Controller.RttiType.TypeKind = tkClass);
      CachedMethod.FullPath := FullPath;
      CachedMethod.HttpMethod := ControllerMethod.HttpMethod;

      // ? CHECK AUTH ATTRIBUTES (Controller or Method level)
      // RULE: [AllowAnonymous] on method OVERRIDES [Authorize] on controller
      ControllerRequiresAuth := False;
      MethodRequiresAuth := False;
      MethodAllowsAnonymous := False;
      SecuritySchemes := TCollections.CreateList<string>;

      // Check controller level [Authorize]
      for Attr in Controller.RttiType.GetAttributes do
        if (Attr is Dext.Auth.Attributes.AuthorizeAttribute) or (Attr.ClassName = 'AuthorizeAttribute') then
        begin
          ControllerRequiresAuth := True;
          SecuritySchemes.Add(Dext.Auth.Attributes.AuthorizeAttribute(Attr).Scheme);
        end;

      // Check method level attributes
      for Attr in ControllerMethod.Method.GetAttributes do
      begin
        if (Attr is Dext.Auth.Attributes.AuthorizeAttribute) or (Attr.ClassName = 'AuthorizeAttribute') then
        begin
          MethodRequiresAuth := True;
          LScheme := Dext.Auth.Attributes.AuthorizeAttribute(Attr).Scheme;
          if (LScheme <> '') and (SecuritySchemes.IndexOf(LScheme) < 0) then
            SecuritySchemes.Add(LScheme);
        end;

        if (Attr is AllowAnonymousAttribute) or (Attr.ClassName = 'AllowAnonymousAttribute') then
          MethodAllowsAnonymous := True;
      end;

      // Final decision:
      // - If method has [AllowAnonymous], it's always allowed (overrides controller [Authorize])
      // - Otherwise, auth is required if controller OR method has [Authorize]
      if MethodAllowsAnonymous then
      begin
        CachedMethod.RequiresAuth := False;
        SecuritySchemes.Clear; // Skip security definitions in Swagger too if anonymous
      end
      else
        CachedMethod.RequiresAuth := ControllerRequiresAuth or MethodRequiresAuth;

      FCachedMethods.Add(CachedMethod);

      // REGISTER ROUTE USING CACHE
      AppBuilder.MapEndpoint(ControllerMethod.HttpMethod, FullPath, CreateHandler(CachedMethod));

      // UPDATE ROUTE METADATA (Security, Anonymous, etc.)
      Routes := AppBuilder.GetRoutes;
      if Length(Routes) > 0 then
      begin
        Metadata := Routes[High(Routes)];
        MetadataUpdated := False;
        Updated := False;

        if (SecuritySchemes.Count > 0) then
        begin
           Metadata.Security := SecuritySchemes.ToArray;
           SafeWriteLn('      🔒 Secured with: ' + string.Join(', ', Metadata.Security));
           MetadataUpdated := True;
        end;

        if MethodAllowsAnonymous then
        begin
          Metadata.AllowAnonymous := True;
          SafeWriteLn('      🔓 Allows Anonymous Access');
          MetadataUpdated := True;
        end;

        // 1. Controller [SwaggerTag]
        for TypeAttr in Controller.RttiType.GetAttributes do
        begin
          if TypeAttr is SwaggerTagAttribute then
          begin
            TagAttr := SwaggerTagAttribute(TypeAttr);
            if Length(Metadata.Tags) = 0 then
            begin
              SetLength(Metadata.Tags, 1);
              Metadata.Tags[0] := TagAttr.Tag;
              Updated := True;
            end;
          end;
        end;

        // 2. Extract RequestType from method parameters (for POST/PUT/PATCH)
        if (ControllerMethod.HttpMethod = 'POST') or
           (ControllerMethod.HttpMethod = 'PUT') or
           (ControllerMethod.HttpMethod = 'PATCH') then
        begin
          Params := ControllerMethod.Method.GetParameters;
          for Param in Params do
          begin
            ParamType := Param.ParamType;
            if (ParamType <> nil) and (ParamType.TypeKind in [tkRecord, tkMRecord]) then
            begin
              // Ignore IHttpContext and basic types
              if not SameText(ParamType.Name, 'IHttpContext') then
              begin
                Metadata.RequestType := ParamType.Handle;
                Updated := True;
                SafeWriteLn('      📥 RequestType: ' + ParamType.Name);
                Break;
              end;
            end;
          end;
        end;

        // 3. Method [SwaggerOperation]
        for Attr in ControllerMethod.Method.GetAttributes do
        begin
          if Attr is SwaggerOperationAttribute then
          begin
            OpAttr := SwaggerOperationAttribute(Attr);
            if OpAttr.Summary <> '' then Metadata.Summary := OpAttr.Summary;
            if OpAttr.Description <> '' then Metadata.Description := OpAttr.Description;
            if Length(OpAttr.Tags) > 0 then Metadata.Tags := OpAttr.Tags;
            Updated := True;
          end;
        end;

        // 4. Method [SwaggerResponse] -> populate Responses array
        SetLength(ResponsesList, 0);
        for Attr in ControllerMethod.Method.GetAttributes do
        begin
          if Attr is SwaggerResponseAttribute then
          begin
            RespAttr := SwaggerResponseAttribute(Attr);
            RespMeta.StatusCode := RespAttr.StatusCode;
            RespMeta.Description := RespAttr.Description;
            RespMeta.MediaType := RespAttr.ContentType;
            if RespAttr.SchemaClass <> nil then
              RespMeta.SchemaType := RespAttr.SchemaClass.ClassInfo
            else
              RespMeta.SchemaType := nil;
            SetLength(ResponsesList, Length(ResponsesList) + 1);
            ResponsesList[High(ResponsesList)] := RespMeta;
            Updated := True;
          end;
        end;
        if Length(ResponsesList) > 0 then
          Metadata.Responses := ResponsesList;

        if MetadataUpdated or Updated then
          AppBuilder.UpdateLastRouteMetadata(Metadata);
      end;

      Inc(Result);
    end;
  end;

  SafeWriteLn('✅ ' + Format('Registered %d auto-routes', [Result]));
  SafeWriteLn('💾 ' + Format('Cached %d methods for runtime execution', [FCachedMethods.Count]));
end;

destructor TControllerScanner.Destroy;
begin
  inherited;
end;

function TControllerScanner.CreateHandler(const AMethod: TCachedMethod): TRequestDelegate;
begin
  Result := procedure(Context: IHttpContext)
  begin
    ExecuteCachedMethod(Context, AMethod);
  end;
end;

procedure TControllerScanner.ExecuteCachedMethod(Context: IHttpContext; const CachedMethod: TCachedMethod);
var
  ControllerType: TRttiType;
  Method: TRttiMethod;
  ControllerInstance: TObject;
  FilterAttr: TCustomAttribute;
  Filter: IActionFilter;
  M: TRttiMethod;
  FilterList: IList<TCustomAttribute>;
  ActionDescriptor: TActionDescriptor;
  ExecutingContext: IActionExecutingContext;
  Binder: IModelBinder;
  Invoker: THandlerInvoker;
  ExecutedContext: IActionExecutedContext;
  I: Integer;
begin
  SafeWriteLn('🚀 ' + Format('Executing: %s -> %s.%s', [CachedMethod.FullPath, CachedMethod.TypeName, CachedMethod.MethodName]));

  // ? ENFORCE AUTHORIZATION
  if CachedMethod.RequiresAuth then
  begin
    if (Context.User = nil) or (Context.User.Identity = nil) or (not Context.User.Identity.IsAuthenticated) then
    begin
      SafeWriteLn('❌ Authorization failed: User not authenticated');
      Context.Response.Status(401).Json('{"error": "Unauthorized"}');
      Exit;
    end;
  end;

  // Use the global context via TActivator to avoid per-thread pool overhead.
    // RE-ACQUIRE TYPE AT RUNTIME
    ControllerType := TActivator.GetRttiContext.FindType(CachedMethod.TypeName);
    if ControllerType = nil then
    begin
      SafeWriteLn('❌ Controller type not found: ' + CachedMethod.TypeName);
      Context.Response.Status(500).Json(Format('{"error": "Controller type not found: %s"}', [CachedMethod.TypeName]));
      Exit;
    end;

    // FIND METHOD AT RUNTIME
    Method := nil;
    for M in ControllerType.GetMethods do
    begin
      if M.Name = CachedMethod.MethodName then
      begin
        Method := M;
        Break;
      end;
    end;

    if Method = nil then
    begin
      SafeWriteLn('❌ ' + Format('Method not found: %s.%s', [CachedMethod.TypeName, CachedMethod.MethodName]));
      Context.Response.Status(500).Json(Format('{"error": "Method not found: %s.%s"}', [CachedMethod.TypeName, CachedMethod.MethodName]));
      Exit;
    end;

    FilterList := TCollections.CreateList<TCustomAttribute>;
    // Controller Level
    for FilterAttr in ControllerType.GetAttributes do
      if Supports(FilterAttr, IActionFilter) then
        FilterList.Add(FilterAttr);

    // Method Level
    for FilterAttr in Method.GetAttributes do
      if Supports(FilterAttr, IActionFilter) then
        FilterList.Add(FilterAttr);

    // ? EXECUTE ACTION FILTERS - OnActionExecuting
    ActionDescriptor.ControllerName := CachedMethod.TypeName;
    ActionDescriptor.ActionName := CachedMethod.MethodName;
    ActionDescriptor.HttpMethod := CachedMethod.HttpMethod;
    ActionDescriptor.Route := CachedMethod.FullPath;

    // ? FIX: Use interface variable to prevent premature destruction (RefCount issue)
    ExecutingContext := TActionExecutingContext.Create(Context, ActionDescriptor);
    try
      for FilterAttr in FilterList do
      begin
        if Supports(FilterAttr, IActionFilter, Filter) then
        begin
          Filter.OnActionExecuting(ExecutingContext);

          // Check for short-circuit
          if Assigned(ExecutingContext.Result) then
          begin
            SafeWriteLn('⚠️ Filter short-circuited execution');
            ExecutingContext.Result.Execute(Context);
            Exit;
          end;
        end;
      end;
    except
      on E: Exception do
      begin
        SafeWriteLn('❌ Error in OnActionExecuting filter: ' + E.Message);
        raise;
      end;
    end;

    // EXECUTE CONTROLLER METHOD
    try
      if CachedMethod.IsClass then
      begin
        // RESOLVE INSTANCE VIA DI
        ControllerInstance := Context.GetServices.GetService(
          TServiceType.FromClass(ControllerType.AsInstance.MetaclassType));

        if ControllerInstance = nil then
        begin
          SafeWriteLn('❌ Controller instance not found: ' + CachedMethod.TypeName);
          Context.Response.Status(500).Json(Format('{"error": "Controller instance not found: %s"}', [CachedMethod.TypeName]));
          Exit;
        end;

        Binder := TModelBinder.Create;
        Invoker := THandlerInvoker.Create(Context, Binder);
        try
          Invoker.InvokeAction(ControllerInstance, Method);
        finally
          Invoker.Free;
          Binder := nil;
          // Transient controllers MUST be freed by the invoker
          if ControllerInstance <> nil then
          begin
            ControllerInstance.Free;
          end;
        end;
      end
      else
      begin
        // STATIC RECORDS
        Binder := TModelBinder.Create;
        Invoker := THandlerInvoker.Create(Context, Binder);
        try
          Invoker.InvokeAction(nil, Method);
        finally
          Invoker.Free;
          Binder := nil;
        end;
      end;

      // ? EXECUTE ACTION FILTERS - OnActionExecuted
      ExecutedContext := TActionExecutedContext.Create(Context, ActionDescriptor, nil, nil);
      // Execute filters in reverse order
      for I := FilterList.Count - 1 downto 0 do
      begin
        FilterAttr := FilterList[I];
        if Supports(FilterAttr, IActionFilter, Filter) then
          Filter.OnActionExecuted(ExecutedContext);
      end;

    except
      on E: Exception do
      begin
        SafeWriteLn('❌ Error executing method: ' + E.Message);

        // ? EXECUTE ACTION FILTERS - OnActionExecuted (with exception)
        ExecutedContext := TActionExecutedContext.Create(Context, ActionDescriptor, nil, E);
        for I := FilterList.Count - 1 downto 0 do
        begin
          FilterAttr := FilterList[I];
          if Supports(FilterAttr, IActionFilter, Filter) then
          begin
            Filter.OnActionExecuted(ExecutedContext);
            if ExecutedContext.ExceptionHandled then
            begin
              SafeWriteLn('🛡️ Exception handled by filter');
              Exit; // Don't re-raise
            end;
          end;
        end;

        Context.Response.Status(500).Json(Format('{"error": "Execution failed: %s"}', [E.Message]));
      end;
    end;
end;

end.
