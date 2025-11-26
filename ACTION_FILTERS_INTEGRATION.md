# Action Filters - Guia de Integração

## ✅ Arquivos Já Criados

1. **`Dext.Filters.pas`** - Interfaces e classes base
2. **`Dext.Filters.BuiltIn.pas`** - Filtros prontos para uso

## 📝 Alterações Necessárias no `Dext.Core.ControllerScanner.pas`

### 1. Adicionar ao `uses` (implementation)

```pascal
uses
  Dext.Auth.Attributes,
  Dext.Core.ModelBinding,
  Dext.Core.HandlerInvoker,
  Dext.Filters;  // ← ADICIONAR ESTA LINHA
```

### 2. Atualizar `TCachedMethod` (por volta da linha 30-38)

```pascal
TCachedMethod = record
  TypeName: string;
  MethodName: string;
  IsClass: Boolean;
  FullPath: string;
  HttpMethod: string;
  RequiresAuth: Boolean;
  Filters: TArray<TCustomAttribute>; // ← ADICIONAR ESTA LINHA
end;
```

### 3. Coletar Filtros no `RegisterRoutes` (por volta da linha 350)

Encontre este trecho:

```pascal
CachedMethod.RequiresAuth := HasAuthorizeAttribute and not HasAllowAnonymousAttribute;
end;

WriteLn('📝 Caching: ', CachedMethod.FullPath, ' -> ', CachedMethod.TypeName, '.', CachedMethod.MethodName);
FCachedMethods.Add(CachedMethod);
```

Substitua por:

```pascal
CachedMethod.RequiresAuth := HasAuthorizeAttribute and not HasAllowAnonymousAttribute;
end;

// ✅ COLLECT ACTION FILTERS
var FilterList := TList<TCustomAttribute>.Create;
try
  // Collect from controller level
  for var Attr in Controller.RttiType.GetAttributes do
    if Supports(Attr, IActionFilter) then
      FilterList.Add(Attr);
  
  // Collect from method level (method filters run after controller filters)
  for var Attr in ControllerMethod.Method.GetAttributes do
    if Supports(Attr, IActionFilter) then
      FilterList.Add(Attr);
  
  CachedMethod.Filters := FilterList.ToArray;
finally
  FilterList.Free;
end;

WriteLn('📝 Caching: ', CachedMethod.FullPath, ' -> ', CachedMethod.TypeName, '.', CachedMethod.MethodName);
if Length(CachedMethod.Filters) > 0 then
  WriteLn('  🎯 Filters: ', Length(CachedMethod.Filters));
FCachedMethods.Add(CachedMethod);
```

### 4. Executar Filtros no `ExecuteCachedMethod` (por volta da linha 435)

Encontre o início do método:

```pascal
procedure TControllerScanner.ExecuteCachedMethod(Context: IHttpContext; const CachedMethod: TCachedMethod);
var
  Ctx: TRttiContext;
  ControllerType: TRttiType;
  Method: TRttiMethod;
  ControllerInstance: TObject;
begin
  WriteLn('🔄 Executing cached method: ', CachedMethod.TypeName, '.', CachedMethod.MethodName);
  WriteLn('🔄 Executing: ', CachedMethod.FullPath, ' -> ', CachedMethod.TypeName, '.', CachedMethod.MethodName);

  // ✅ ENFORCE AUTHORIZATION
  if CachedMethod.RequiresAuth then
  begin
    // ... código de autorização ...
  end;
```

Adicione LOGO APÓS a verificação de autorização:

```pascal
  // ✅ EXECUTE ACTION FILTERS - OnActionExecuting
  var ActionDescriptor: TActionDescriptor;
  ActionDescriptor.ControllerName := CachedMethod.TypeName;
  ActionDescriptor.ActionName := CachedMethod.MethodName;
  ActionDescriptor.HttpMethod := CachedMethod.HttpMethod;
  ActionDescriptor.Route := CachedMethod.FullPath;
  
  var ExecutingContext := TActionExecutingContext.Create(Context, ActionDescriptor);
  try
    for var FilterAttr in CachedMethod.Filters do
    begin
      var Filter: IActionFilter;
      if Supports(FilterAttr, IActionFilter, Filter) then
      begin
        Filter.OnActionExecuting(ExecutingContext);
        
        // Check for short-circuit
        if Assigned(ExecutingContext.Result) then
        begin
          WriteLn('⚡ Filter short-circuited execution');
          ExecutingContext.Result.Execute(Context);
          Exit;
        end;
      end;
    end;
  finally
    ExecutingContext := nil;
  end;
```

### 5. Executar Filtros APÓS a action (no final do método, antes do `except`)

Encontre o final da execução do método (por volta da linha 530):

```pascal
    end;

  except
    on E: Exception do
    begin
      WriteLn('❌ Error executing cached method ', CachedMethod.TypeName, '.', CachedMethod.MethodName, ': ', E.ClassName, ': ', E.Message);
      Context.Response.Status(500).Json(Format('{"error": "Execution failed: %s"}', [E.Message]));
    end;
  end;
end;
```

Modifique para:

```pascal
    end;

    // ✅ EXECUTE ACTION FILTERS - OnActionExecuted
    var ExecutedContext := TActionExecutedContext.Create(Context, ActionDescriptor, nil, nil);
    try
      // Execute filters in reverse order
      for var I := High(CachedMethod.Filters) downto Low(CachedMethod.Filters) do
      begin
        var FilterAttr := CachedMethod.Filters[I];
        var Filter: IActionFilter;
        if Supports(FilterAttr, IActionFilter, Filter) then
          Filter.OnActionExecuted(ExecutedContext);
      end;
    finally
      ExecutedContext := nil;
    end;

  except
    on E: Exception do
    begin
      WriteLn('❌ Error executing cached method ', CachedMethod.TypeName, '.', CachedMethod.MethodName, ': ', E.ClassName, ': ', E.Message);
      
      // ✅ EXECUTE ACTION FILTERS - OnActionExecuted (with exception)
      var ExecutedContext := TActionExecutedContext.Create(Context, ActionDescriptor, nil, E);
      try
        for var I := High(CachedMethod.Filters) downto Low(CachedMethod.Filters) do
        begin
          var FilterAttr := CachedMethod.Filters[I];
          var Filter: IActionFilter;
          if Supports(FilterAttr, IActionFilter, Filter) then
          begin
            Filter.OnActionExecuted(ExecutedContext);
            if ExecutedContext.ExceptionHandled then
            begin
              WriteLn('✅ Exception handled by filter');
              Exit; // Don't re-raise
            end;
          end;
        end;
      finally
        ExecutedContext := nil;
      end;
      
      Context.Response.Status(500).Json(Format('{"error": "Execution failed: %s"}', [E.Message]));
    end;
  end;
end;
```

## 🎯 Como Usar (Exemplo)

```pascal
uses
  Dext.Filters.BuiltIn;

type
  [DextController('/api')]
  TUserController = class
  public
    [DextGet('/users')]
    [LogAction]  // ← Loga tempo de execução
    [ResponseCache(60)]  // ← Cache por 60 segundos
    function GetUsers: IResult;
    
    [DextPost('/users')]
    [RequireHeader('X-API-Key', 'API Key is required')]  // ← Valida header
    [LogAction]
    function CreateUser: IResult;
  end;
```

## ✅ Próximos Passos

1. Aplicar as alterações acima no `Dext.Core.ControllerScanner.pas`
2. Compilar e testar
3. Criar exemplo no `ControllerExample.dpr`

---

**IMPORTANTE**: As alterações são incrementais. Faça uma de cada vez e compile para verificar.
