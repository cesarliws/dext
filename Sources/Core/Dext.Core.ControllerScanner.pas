unit Dext.Core.ControllerScanner;

interface

uses
  System.Classes,
  System.Generics.Collections,
  System.Rtti,
  System.SysUtils,
  System.TypInfo,
  Dext.Core.Routing,
  Dext.DI.Interfaces,
  Dext.Http.Interfaces,
  Dext.OpenAPI.Attributes;

type
  TControllerMethod = record
    Method: TRttiMethod;
    RouteAttribute: DextRouteAttribute;
    Path: string;
    HttpMethod: string;
  end;

  TControllerInfo = record
    RttiType: TRttiType;
    Methods: TArray<TControllerMethod>;
    ControllerAttribute: DextControllerAttribute;
  end;

  // Novo tipo para cache de métodos
  TCachedMethod = record
    TypeName: string;
    MethodName: string;
    IsClass: Boolean;
    FullPath: string;
    HttpMethod: string;
  end;

  IControllerScanner = interface
    function FindControllers: TArray<TControllerInfo>;
    procedure RegisterServices(Services: IServiceCollection);
    function RegisterRoutes(AppBuilder: IApplicationBuilder): Integer;
    procedure RegisterControllerManual(AppBuilder: IApplicationBuilder);
  end;

  TControllerScanner = class(TInterfacedObject, IControllerScanner)
  private
    FCtx: TRttiContext;
    FServiceProvider: IServiceProvider;
    FCachedMethods: TList<TCachedMethod>;
    procedure ExecuteCachedMethod(Context: IHttpContext; const CachedMethod: TCachedMethod);
  public
    constructor Create(AServiceProvider: IServiceProvider);
    destructor Destroy; override;
    function FindControllers: TArray<TControllerInfo>;
    procedure RegisterServices(Services: IServiceCollection);
    function RegisterRoutes(AppBuilder: IApplicationBuilder): Integer;
    procedure RegisterControllerManual(AppBuilder: IApplicationBuilder);
  end;

implementation

uses
  Dext.Core.ModelBinding,
  Dext.Core.HandlerInvoker;

{ TControllerScanner }

constructor TControllerScanner.Create(AServiceProvider: IServiceProvider);
begin
  inherited Create;
  FCtx := TRttiContext.Create;
  FServiceProvider := AServiceProvider;
  FCachedMethods := TList<TCachedMethod>.Create;
end;

//function TControllerScanner.FindControllers: TArray<TControllerInfo>;
//var
//  Types: TArray<TRttiType>;
//  RttiType: TRttiType;
//  ControllerInfo: TControllerInfo;
//  Controllers: TList<TControllerInfo>;
//  Method: TRttiMethod;
//  MethodInfo: TControllerMethod;
//  Attr: TCustomAttribute;
//begin
//  Controllers := TList<TControllerInfo>.Create;
//  try
//    Types := FCtx.GetTypes;
//
//    for RttiType in Types do
//    begin
//      // ✅ FILTRAR: Apenas records com métodos estáticos
//      if (RttiType.TypeKind = tkRecord) and RttiType.IsRecord then
//      begin
//        // Verificar se tem métodos com atributos de rota
//        var HasRouteMethods := False;
//        var MethodsList: TList<TControllerMethod> := TList<TControllerMethod>.Create;
//
//        try
//          for Method in RttiType.GetMethods do
//          begin
//            // ✅ APENAS MÉTODOS ESTÁTICOS
//            if not Method.IsStatic then
//              Continue;
//
//            // ✅ PROCURAR ATRIBUTOS [DextGet], [DextPost], etc.
//            for Attr in Method.GetAttributes do
//            begin
//              if Attr is DextRouteAttribute then
//              begin
//                MethodInfo.Method := Method;
//                MethodInfo.RouteAttribute := DextRouteAttribute(Attr);
//                MethodInfo.Path := MethodInfo.RouteAttribute.Path;
//                MethodInfo.HttpMethod := MethodInfo.RouteAttribute.Method;
//
//                MethodsList.Add(MethodInfo);
//                HasRouteMethods := True;
//                Break; // Um método pode ter apenas um atributo de rota
//              end;
//            end;
//          end;
//
//          // ✅ SE TEM MÉTODOS DE ROTA, ADICIONAR COMO CONTROLLER
//          if HasRouteMethods then
//          begin
//            ControllerInfo.RttiType := RttiType;
//            ControllerInfo.Methods := MethodsList.ToArray;
//
//            // ✅ VERIFICAR ATRIBUTO [DextController] PARA PREFIXO
//            ControllerInfo.ControllerAttribute := nil;
//            for Attr in RttiType.GetAttributes do
//            begin
//              if Attr is DextControllerAttribute then
//              begin
//                ControllerInfo.ControllerAttribute := DextControllerAttribute(Attr);
//                Break;
//              end;
//            end;
//
//            Controllers.Add(ControllerInfo);
//          end;
//
//        finally
//          MethodsList.Free;
//        end;
//      end;
//    end;
//
//    Result := Controllers.ToArray;
//
//  finally
//    Controllers.Free;
//  end;
//end;

function TControllerScanner.FindControllers: TArray<TControllerInfo>;
var
  Types: TArray<TRttiType>;
  RttiType: TRttiType;
  ControllerInfo: TControllerInfo;
  Controllers: TList<TControllerInfo>;
  Method: TRttiMethod;
  MethodInfo: TControllerMethod;
  Attr: TCustomAttribute;
begin
  Controllers := TList<TControllerInfo>.Create;
  try
    Types := FCtx.GetTypes;

    WriteLn('🔍 Scanning ', Length(Types), ' types...');

    for RttiType in Types do
    begin
      // ✅ FILTRAR: Records ou Classes
      if (RttiType.TypeKind in [tkRecord, tkClass]) then
      begin
        // Verificar se tem métodos com atributos de rota
        var HasRouteMethods := False;
        var MethodsList: TList<TControllerMethod> := TList<TControllerMethod>.Create;

        try
          var Methods := RttiType.GetMethods;

          for Method in Methods do
          begin
            // ✅ APENAS MÉTODOS ESTÁTICOS (para records) ou PÚBLICOS (para classes)
            if (RttiType.TypeKind = tkRecord) and (not Method.IsStatic) then
              Continue;

            // Para classes, aceitamos métodos de instância
            if (RttiType.TypeKind = tkClass) and (Method.Visibility <> mvPublic) and (Method.Visibility <> mvPublished) then
               Continue;

            var Attributes := Method.GetAttributes;

            // ✅ PROCURAR ATRIBUTOS [DextGet], [DextPost], etc.
            for Attr in Attributes do
            begin
              if Attr is DextRouteAttribute then
              begin
                MethodInfo.Method := Method;
                MethodInfo.RouteAttribute := DextRouteAttribute(Attr);
                MethodInfo.Path := MethodInfo.RouteAttribute.Path;
                MethodInfo.HttpMethod := MethodInfo.RouteAttribute.Method;

                MethodsList.Add(MethodInfo);
                HasRouteMethods := True;
                Break;
              end;
            end;
          end;

          // ✅ SE TEM MÉTODOS DE ROTA, ADICIONAR COMO CONTROLLER
          if HasRouteMethods then
          begin
            WriteLn('    🎉 ADDING CONTROLLER: ', RttiType.Name);
            ControllerInfo.RttiType := RttiType;
            ControllerInfo.Methods := MethodsList.ToArray;

            // ✅ VERIFICAR ATRIBUTO [DextController] PARA PREFIXO
            ControllerInfo.ControllerAttribute := nil;
            var TypeAttributes := RttiType.GetAttributes;
            for Attr in TypeAttributes do
            begin
              if Attr is DextControllerAttribute then
              begin
                ControllerInfo.ControllerAttribute := DextControllerAttribute(Attr);
                Break;
              end;
            end;

            Controllers.Add(ControllerInfo);
          end;

        finally
          MethodsList.Free;
        end;
      end;
    end;

    Result := Controllers.ToArray;
    WriteLn('🎯 Total controllers found: ', Length(Result));

  finally
    Controllers.Free;
  end;
end;

procedure TControllerScanner.RegisterServices(Services: IServiceCollection);
var
  Controllers: TArray<TControllerInfo>;
  Controller: TControllerInfo;
begin
  Controllers := FindControllers;
  WriteLn('🔧 Registering ', Length(Controllers), ' controllers in DI...');

  for Controller in Controllers do
  begin
    if Controller.RttiType.TypeKind = tkClass then
    begin
      // Register as Transient
      var ClassType := Controller.RttiType.AsInstance.MetaclassType;
      Services.AddTransient(TServiceType.FromClass(ClassType), ClassType);
      WriteLn('  ✅ Registered service: ', Controller.RttiType.Name);
    end;
  end;
end;

function TControllerScanner.RegisterRoutes(AppBuilder: IApplicationBuilder): Integer;
var
  Controllers: TArray<TControllerInfo>;
  Controller: TControllerInfo;
  ControllerMethod: TControllerMethod;
  FullPath: string;
begin
  Result := 0;
  Controllers := FindControllers;

  WriteLn('🔍 Found ', Length(Controllers), ' controllers:');

  // ✅ CACHE DE MÉTODOS PARA EVITAR PROBLEMAS DE REFERÊNCIA RTTI
  for Controller in Controllers do
  begin
    // ✅ CALCULAR PREFIXO DO CONTROLLER
    var Prefix := '';
    if Assigned(Controller.ControllerAttribute) then
      Prefix := Controller.ControllerAttribute.Prefix;

    WriteLn('  📦 ', Controller.RttiType.Name, ' (Prefix: "', Prefix, '")');

    for ControllerMethod in Controller.Methods do
    begin
      // ✅ CONSTRUIR PATH COMPLETO: Prefix + MethodPath
      FullPath := Prefix + ControllerMethod.Path;

      WriteLn('    ', ControllerMethod.HttpMethod, ' ', FullPath, ' -> ', ControllerMethod.Method.Name);

      // ✅ VERIFICAR [SwaggerIgnore]
      var IsIgnored := False;
      for var Attr in ControllerMethod.Method.GetAttributes do
        if Attr is SwaggerIgnoreAttribute then
        begin
          IsIgnored := True;
          Break;
        end;

      if IsIgnored then
      begin
        WriteLn('      🚫 Ignored by [SwaggerIgnore]');
        Continue;
      end;

      // ✅ CRIAR CACHE DO MÉTODO
      var CachedMethod: TCachedMethod;
      CachedMethod.TypeName := Controller.RttiType.QualifiedName;
      CachedMethod.MethodName := ControllerMethod.Method.Name;
      CachedMethod.IsClass := (Controller.RttiType.TypeKind = tkClass);
      CachedMethod.FullPath := FullPath;
      CachedMethod.HttpMethod := ControllerMethod.HttpMethod;
      FCachedMethods.Add(CachedMethod);

      // ✅ REGISTRAR ROTA USANDO CACHE (EVITA PROBLEMAS DE REFERÊNCIA RTTI)
      AppBuilder.MapEndpoint(ControllerMethod.HttpMethod, FullPath,
        procedure(Context: IHttpContext)
        begin
          // Buscar o método cacheado correspondente
          var FoundCachedMethod: TCachedMethod;
          var Found := False;

          for var Cached in FCachedMethods do
          begin
            if (Cached.FullPath = FullPath) and (Cached.HttpMethod = ControllerMethod.HttpMethod) then
            begin
              FoundCachedMethod := Cached;
              Found := True;
              Break;
            end;
          end;

          if Found then
            ExecuteCachedMethod(Context, FoundCachedMethod)
          else
           // Context.Response.Status(500).Json('{"error": "Cached method not found"}');
        begin
          // Fallback para records estáticos (apenas log por enquanto, ou implementar InvokeStatic)
          Context.Response.Json(Format('{"message": "Auto-route: %s (%s) - Static Record not fully supported yet"}',
            [FullPath, ControllerMethod.HttpMethod]));
        end;
        end);

      // ✅ PROCESSAR ATRIBUTOS DE SEGURANÇA (SwaggerAuthorize)
      var SecuritySchemes := TList<string>.Create;
      try
        // 1. Atributos do Controller
        var TypeAttrs := Controller.RttiType.GetAttributes;
        for var Attr in TypeAttrs do
          if Attr is SwaggerAuthorizeAttribute then
            SecuritySchemes.Add(SwaggerAuthorizeAttribute(Attr).Scheme);

        // 2. Atributos do Método
        var MethodAttrs := ControllerMethod.Method.GetAttributes;
        for var Attr in MethodAttrs do
          if Attr is SwaggerAuthorizeAttribute then
            SecuritySchemes.Add(SwaggerAuthorizeAttribute(Attr).Scheme);

        // 3. Atualizar Metadados da Rota
        if SecuritySchemes.Count > 0 then
        begin
          var Routes := AppBuilder.GetRoutes;
          if Length(Routes) > 0 then
          begin
            var Metadata := Routes[High(Routes)];
            Metadata.Security := SecuritySchemes.ToArray;
            AppBuilder.UpdateLastRouteMetadata(Metadata);
            WriteLn('      🔒 Secured with: ', string.Join(', ', Metadata.Security));
          end;
        end;
      finally
        SecuritySchemes.Free;
      end;

      // ✅ PROCESSAR [SwaggerOperation] e [SwaggerResponse]
      var Routes := AppBuilder.GetRoutes;
      if Length(Routes) > 0 then
      begin
        var Metadata := Routes[High(Routes)];
        var Updated := False;

        for var Attr in ControllerMethod.Method.GetAttributes do
        begin
          if Attr is SwaggerOperationAttribute then
          begin
            var OpAttr := SwaggerOperationAttribute(Attr);
            if OpAttr.Summary <> '' then Metadata.Summary := OpAttr.Summary;
            if OpAttr.Description <> '' then Metadata.Description := OpAttr.Description;
            if Length(OpAttr.Tags) > 0 then Metadata.Tags := OpAttr.Tags;
            Updated := True;
          end;
        // Note: SwaggerResponseAttribute would require extending TEndpointMetadata to support custom responses
        // For now, we only support default 200 OK response generation
        end;

        if Updated then
          AppBuilder.UpdateLastRouteMetadata(Metadata);
      end;

      Inc(Result);
    end;
  end;

  WriteLn('✅ Registered ', Result, ' auto-routes');
  WriteLn('💾 Cached ', FCachedMethods.Count, ' methods for runtime execution');
end;

destructor TControllerScanner.Destroy;
begin
  FCachedMethods.Free;
  inherited;
end;

procedure TControllerScanner.ExecuteCachedMethod(Context: IHttpContext; const CachedMethod: TCachedMethod);
var
  Ctx: TRttiContext;
  ControllerType: TRttiType;
  Method: TRttiMethod;
  ControllerInstance: TObject;
begin
  WriteLn('🔄 Executing cached method: ', CachedMethod.TypeName, '.', CachedMethod.MethodName);

  Ctx := TRttiContext.Create;
  try
    // ✅ RE-OBTER O TIPO EM TEMPO DE EXECUÇÃO
    ControllerType := Ctx.FindType(CachedMethod.TypeName);
    if ControllerType = nil then
    begin
      WriteLn('❌ Controller type not found: ', CachedMethod.TypeName);
      Context.Response.Status(500).Json(Format('{"error": "Controller type not found: %s"}', [CachedMethod.TypeName]));
      Exit;
    end;

    // ✅ ENCONTRAR O MÉTODO EM TEMPO DE EXECUÇÃO
    Method := nil;
    for var M in ControllerType.GetMethods do
    begin
      if M.Name = CachedMethod.MethodName then
      begin
        Method := M;
        Break;
      end;
    end;

    if Method = nil then
    begin
      WriteLn('❌ Method not found: ', CachedMethod.TypeName, '.', CachedMethod.MethodName);
      Context.Response.Status(500).Json(Format('{"error": "Method not found: %s.%s"}', [CachedMethod.TypeName, CachedMethod.MethodName]));
      Exit;
    end;

     WriteLn('✅ Found method: ', Method.Name, ' with ', Length(Method.GetParameters), ' parameters');

    // ✅ EXECUTAR CONFORME O TIPO (CLASSE OU RECORD)
    if CachedMethod.IsClass then
    begin
      // ✅ RESOLVER INSTÂNCIA VIA DI
      ControllerInstance := Context.GetServices.GetService(
        TServiceType.FromClass(ControllerType.AsInstance.MetaclassType));

      if ControllerInstance = nil then
      begin
        WriteLn('❌ Controller instance not found: ', CachedMethod.TypeName);
        Context.Response.Status(500).Json(Format('{"error": "Controller instance not found: %s"}', [CachedMethod.TypeName]));
        Exit;
      end;

      WriteLn('✅ Controller instance resolved: ', ControllerInstance.ClassName);

      // ✅ INVOCAR O MÉTODO
      var Binder: IModelBinder := TModelBinder.Create;
      var Invoker := THandlerInvoker.Create(Context, Binder);
      try
        Invoker.InvokeAction(ControllerInstance, Method);
        WriteLn('✅ Method invoked successfully: ', CachedMethod.TypeName, '.', CachedMethod.MethodName);
      finally
        Invoker.Free;
        Binder := nil;
      end;
    end
    else
    begin
      // ✅ RECORDS ESTÁTICOS (implementação futura)
      WriteLn('📝 Static record method - not fully implemented yet');
      Context.Response.Json(Format('{"message": "Auto-route: %s (%s) - Static Record"}',
        [CachedMethod.FullPath, CachedMethod.HttpMethod]));
    end;

  except
    on E: Exception do
    begin
      WriteLn('❌ Error executing cached method ', CachedMethod.TypeName, '.', CachedMethod.MethodName, ': ', E.ClassName, ': ', E.Message);
      Context.Response.Status(500).Json(Format('{"error": "Execution failed: %s"}', [E.Message]));
    end;
  end;
end;

// Mantenha o método RegisterControllerManual existente...
procedure TControllerScanner.RegisterControllerManual(AppBuilder: IApplicationBuilder);
begin
  WriteLn('🔧 Registering TTaskHandlers manually...');

  // Registrar manualmente os métodos do TTaskHandlers
  var Routes: TArray<TArray<string>> := [
    ['GET', '/api/tasks', 'GetTasks'],
    ['GET', '/api/tasks/{id}', 'GetTask'],
    ['POST', '/api/tasks', 'CreateTask'],
    ['PUT', '/api/tasks/{id}', 'UpdateTask'],
    ['DELETE', '/api/tasks/{id}', 'DeleteTask'],
    ['GET', '/api/tasks/search', 'SearchTasks'],
    ['GET', '/api/tasks/status/{status}', 'GetTasksByStatus'],
    ['GET', '/api/tasks/priority/{priority}', 'GetTasksByPriority'],
    ['GET', '/api/tasks/overdue', 'GetOverdueTasks'],
    ['POST', '/api/tasks/bulk/status', 'BulkUpdateStatus'],
    ['POST', '/api/tasks/bulk/delete', 'BulkDeleteTasks'],
    ['PATCH', '/api/tasks/{id}/status', 'UpdateTaskStatus'],
    ['POST', '/api/tasks/{id}/complete', 'CompleteTask'],
    ['POST', '/api/tasks/{id}/start', 'StartTask'],
    ['POST', '/api/tasks/{id}/cancel', 'CancelTask'],
    ['GET', '/api/tasks/stats', 'GetTasksStats'],
    ['GET', '/api/tasks/stats/status', 'GetStatusCounts']
  ];

  for var Route in Routes do
  begin
    var HttpMethod := Route[0];
    var Path := Route[1];
    var MethodName := Route[2];

    WriteLn('  ', HttpMethod, ' ', Path, ' -> ', MethodName);

    if HttpMethod = 'GET' then
      AppBuilder.MapGet(Path,
        procedure(Context: IHttpContext)
        begin
          Context.Response.Json(Format('{"message": "Manual auto-route: %s -> %s"}', [Path, MethodName]));
        end)
    else if HttpMethod = 'POST' then
      AppBuilder.MapPost(Path,
        procedure(Context: IHttpContext)
        begin
          Context.Response.Json(Format('{"message": "Manual auto-route: %s -> %s"}', [Path, MethodName]));
        end)
    else if HttpMethod = 'PUT' then
      AppBuilder.Map(Path,
        procedure(Context: IHttpContext)
        begin
          Context.Response.Json(Format('{"message": "Manual auto-route: %s -> %s"}', [Path, MethodName]));
        end)
    else if HttpMethod = 'DELETE' then
      AppBuilder.Map(Path,
        procedure(Context: IHttpContext)
        begin
          Context.Response.Json(Format('{"message": "Manual auto-route: %s -> %s"}', [Path, MethodName]));
        end)
    else if HttpMethod = 'PATCH' then
      AppBuilder.Map(Path,
        procedure(Context: IHttpContext)
        begin
          Context.Response.Json(Format('{"message": "Manual auto-route: %s -> %s"}', [Path, MethodName]));
        end);
  end;
end;

end.
