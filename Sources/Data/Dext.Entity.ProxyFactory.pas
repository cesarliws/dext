unit Dext.Entity.ProxyFactory;

interface

uses
  System.SysUtils,
  System.TypInfo,
  System.Rtti,
  Dext.Collections,
  System.Classes,
  Dext.Core.Activator,
  Dext.Core.Reflection,
  Dext.Entity.Core,
  Dext.Entity.DbSet,
  Dext.Entity.Dialects,
  Dext.Entity.LazyLoader,
  Dext.Entity.Drivers.Interfaces,
  Dext.Entity.Mapping,
  Dext.Entity.TypeConverters,
  Dext.Interception,
  Dext.Interception.ClassProxy,
  Dext.Interception.Proxy;

type
  /// <summary>
  ///   Interceptor to handle Lazy Loading for Auto-Proxies.
  /// </summary>
  TLazyProxyInterceptor = class(TInterfacedObject, IInterceptor)
  private
    FLoader: ILazyLoader;
    FPropName: string;
    FLoaded: Boolean;
  public
    constructor Create(const ALoader: ILazyLoader; const APropName: string);
    procedure Intercept(const Invocation: IInvocation);
  end;

  /// <summary>
  ///   Factory to create proxied entities for Auto-Lazy loading.
  /// </summary>
  TEntityProxyFactory = class
  public
    class function CreateInstance<T: class>(AContext: IDbContext): T; overload;
    class function CreateInstance<T: class>(ALoader: ILazyLoader): T; overload;
    /// <summary>
    ///  Creates a TClassProxy for an entity using a manual Loader.
    ///  NOTE: Caller is responsible for freeing the Proxy object (which frees the Instance if OwnsInstance is True).
    /// </summary>
    class function CreateProxyObject<T: class>(ALoader: ILazyLoader): TClassProxy; static;
    class function NeedsProxy(AParam: PTypeInfo; AContext: IDbContext): Boolean; static;
  end;

implementation

uses
  Dext.Entity.Context;

threadvar
  GInsideIntercept: Boolean;

{ TLazyProxyInterceptor }

constructor TLazyProxyInterceptor.Create(const ALoader: ILazyLoader; const APropName: string);
begin
  inherited Create;
  FLoader := ALoader;
  FPropName := APropName;
  FLoaded := False;
end;

procedure TLazyProxyInterceptor.Intercept(const Invocation: IInvocation);
var
  Instance: TObject;
  RType: TRttiType;
  RField: TRttiField;

  function GetBackingField(AType: TRttiType; const APropName: string): TRttiField;
  begin
    Result := AType.GetField('F' + APropName);
    if Result = nil then
      Result := AType.GetField(APropName);
  end;

begin
  Instance := Invocation.Target.AsObject;
  if Instance = nil then
  begin
    Invocation.Proceed;
    Exit;
  end;


  if GInsideIntercept then
  begin
    // If we are already intercepting, it means Invocation.Proceed is causing recursion.
    // In this case, we MUST access the field directly to break the loop.
    try
      RType := TReflection.Context.GetType(Instance.ClassType);
      if RType <> nil then
      begin
        RField := GetBackingField(RType, FPropName);
        if RField <> nil then
        begin
          if SameText(Invocation.Method.Name, 'Get' + FPropName) or 
             SameText(Invocation.Method.Name, FPropName) then
            Invocation.Result := RField.GetValue(Instance)
          else if SameText(Invocation.Method.Name, 'Set' + FPropName) and (Length(Invocation.Arguments) > 0) then
            RField.SetValue(Instance, Invocation.Arguments[0]);
        end;
      end;
    except
      raise;
    end;
    Exit;
  end;

  if SameText(Invocation.Method.Name, 'Get' + FPropName) or 
     SameText(Invocation.Method.Name, FPropName) then
  begin
    GInsideIntercept := True;
    try
      if not FLoaded then
      begin
        if FLoader <> nil then
          FLoader.Load(Instance, FPropName);

        RType := TReflection.Context.GetType(Instance.ClassType);
        if RType <> nil then
        begin
          RField := GetBackingField(RType, FPropName);
          if RField <> nil then
          begin
            // A failed load (for example before the primary key is hydrated)
            // must remain retryable on the next getter invocation.
            if RField.GetValue(Instance).IsObject then
              FLoaded := (RField.GetValue(Instance).AsObject <> nil) and
                (not (RField.GetValue(Instance).AsObject is TStrings) or
                 (TStrings(RField.GetValue(Instance).AsObject).Count > 0))
            else
              FLoaded := not RField.GetValue(Instance).IsEmpty;
          end;
        end;
      end;

      // Access the field directly. This is safer and faster for Lazy properties.
      try
        RType := TReflection.Context.GetType(Instance.ClassType);
        if RType <> nil then
        begin
          RField := GetBackingField(RType, FPropName);
          if RField <> nil then
            Invocation.Result := RField.GetValue(Instance)
          else
            Invocation.Proceed; // Fallback
        end
        else
          Invocation.Proceed;
      except
        raise;
      end;
    finally
      GInsideIntercept := False;
    end;
  end
  else
    Invocation.Proceed;
end;

{ TEntityProxyFactory }

class function TEntityProxyFactory.NeedsProxy(AParam: PTypeInfo; AContext: IDbContext): Boolean;
var
  Map: TEntityMap;
  Prop: TPropertyMap;
  RType: TRttiType;
  RProp: TRttiProperty;
begin
  Result := False;
  Map := TEntityMap(AContext.GetMapping(AParam));
  if Map = nil then Exit;
  
  // Explicitly marked as Proxy, or ANY property is lazy
  if Map.IsProxy then Exit(True);
  
  try
    RType := TReflection.Context.GetType(Map.EntityType);
    for Prop in Map.Properties.Values do
    begin
      RProp := RType.GetProperty(Prop.PropertyName);
      if Prop.IsLazy or
         ((RProp <> nil) and RProp.PropertyType.IsInstance and
          RProp.PropertyType.AsInstance.MetaclassType.InheritsFrom(TStrings)) then
      begin
         if RType = nil then Continue;
         // If it's NOT a Lazy<T> record property, then we might need a proxy for it
         if (RProp <> nil) and (not RProp.PropertyType.Name.StartsWith('Lazy<')) then
           Exit(True);
      end;
    end;
    for RProp in RType.GetProperties do
      if (RProp.PropertyType.IsInstance) and
         RProp.PropertyType.AsInstance.MetaclassType.InheritsFrom(TStrings) and
         (not Map.Properties.ContainsKey(RProp.Name)) then
        Exit(True);
  except
    raise;
  end;
end;

class function TEntityProxyFactory.CreateInstance<T>(ALoader: ILazyLoader): T;
var
  Proxy: TClassProxy;
begin
  Proxy := CreateProxyObject<T>(ALoader);
  if Proxy <> nil then
    Result := T(Proxy.Instance)
  else
    Result := T(TActivator.CreateInstance(TClass(T), []));
end;

class function TEntityProxyFactory.CreateProxyObject<T>(ALoader: ILazyLoader): TClassProxy;
var
  Interceptors: IList<IInterceptor>;
  Map: TEntityMap;
  Prop: TPropertyMap;
  RType: TRttiType;
  RProp: TRttiProperty;
begin
  Map := TModelBuilder.Instance.GetMap(TypeInfo(T));
  if Map = nil then
    Exit(nil);

  Interceptors := TCollections.CreateList<IInterceptor>;
  try
    RType := TReflection.Context.GetType(TypeInfo(T));
    for Prop in Map.Properties.Values do
    begin
      RProp := RType.GetProperty(Prop.PropertyName);
      if Prop.IsLazy or
         ((RProp <> nil) and RProp.PropertyType.IsInstance and
          RProp.PropertyType.AsInstance.MetaclassType.InheritsFrom(TStrings)) then
      begin
        if (RProp <> nil) and (not RProp.PropertyType.Name.StartsWith('Lazy<')) then
          Interceptors.Add(TLazyProxyInterceptor.Create(ALoader, Prop.PropertyName));
      end;
    end;
    for RProp in RType.GetProperties do
      if (RProp.PropertyType.IsInstance) and
         RProp.PropertyType.AsInstance.MetaclassType.InheritsFrom(TStrings) and
         (not Map.Properties.ContainsKey(RProp.Name)) then
        Interceptors.Add(TLazyProxyInterceptor.Create(ALoader, RProp.Name));
  except
    raise;
  end;
  
  if Interceptors.Count = 0 then
    Exit(nil);

  Result := TClassProxy.Create(TClass(T), Interceptors.ToArray, True);
end;

class function TEntityProxyFactory.CreateInstance<T>(AContext: IDbContext): T;
var
  Interceptors: IList<IInterceptor>;
  Map: TEntityMap;
  Prop: TPropertyMap;
  Proxy: TClassProxy;
  RType: TRttiType;
  RProp: TRttiProperty;
  Loader: ILazyLoader;
begin
  if not NeedsProxy(TypeInfo(T), AContext) then
    Exit(T(TActivator.CreateInstance(TClass(T), [])));

  Map := TEntityMap(AContext.GetMapping(TypeInfo(T)));
  Interceptors := TCollections.CreateList<IInterceptor>;
  Loader := TDextLazyLoader.Create(AContext);
  
  try
    RType := TReflection.Context.GetType(TypeInfo(T));
    for Prop in Map.Properties.Values do
    begin
      RProp := RType.GetProperty(Prop.PropertyName);
      if Prop.IsLazy or
         ((RProp <> nil) and RProp.PropertyType.IsInstance and
          RProp.PropertyType.AsInstance.MetaclassType.InheritsFrom(TStrings)) then
      begin
        // Only add proxy interceptor if NOT a Lazy<T> record
        if (RProp <> nil) and (not RProp.PropertyType.Name.StartsWith('Lazy<')) then
          Interceptors.Add(TLazyProxyInterceptor.Create(Loader, Prop.PropertyName));
      end;
    end;
    for RProp in RType.GetProperties do
      if RProp.PropertyType.IsInstance and
         RProp.PropertyType.AsInstance.MetaclassType.InheritsFrom(TStrings) and
         (not Map.Properties.ContainsKey(RProp.Name)) then
        Interceptors.Add(TLazyProxyInterceptor.Create(Loader, RProp.Name));
  except
    raise;
  end;
    
  // DbSet IdentityMap manages the entity lifetime, so Proxy should NOT own the instance.
  // This prevents Double Free during TDbContext.Destroy.
  Proxy := TClassProxy.Create(TClass(T), Interceptors.ToArray, False);
  AContext.TrackProxy(Proxy);
  Result := T(Proxy.Instance);
end;

end.
