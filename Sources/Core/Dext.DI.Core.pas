unit Dext.DI.Core;

interface

uses
  System.SysUtils, System.Generics.Collections, System.SyncObjs,
  Dext.DI.Interfaces;

type
  TServiceDescriptor = class
  public
    ServiceType: TServiceType;
    ImplementationClass: TClass;
    Lifetime: TServiceLifetime;
    Factory: TFunc<IServiceProvider, TObject>;
    constructor Create(const AServiceType: TServiceType;
      AImplementationClass: TClass; ALifetime: TServiceLifetime;
      AFactory: TFunc<IServiceProvider, TObject>);
  end;

  TDextServiceScope = class;

  TDextServiceProvider = class(TInterfacedObject, IServiceProvider)
  private
    FDescriptors: TObjectList<TServiceDescriptor>;
    FSingletons: TDictionary<string, TObject>;
    FSingletonInterfaces: TDictionary<string, IInterface>;
    FIsRootProvider: Boolean;
    FParentProvider: IServiceProvider;
    FScopedInstances: TDictionary<string, TObject>;
    FScopedInterfaces: TDictionary<string, IInterface>;
    FLock: TCriticalSection;

    function CreateInstance(ADescriptor: TServiceDescriptor): TObject;
    function FindDescriptor(const AServiceType: TServiceType): TServiceDescriptor;
  public
    constructor Create(const ADescriptors: TObjectList<TServiceDescriptor>); overload;
    constructor CreateScoped(AParent: IServiceProvider; const ADescriptors: TObjectList<TServiceDescriptor>); overload;
    destructor Destroy; override;

    function GetService(const AServiceType: TServiceType): TObject;
    function GetServiceAsInterface(const AServiceType: TServiceType): IInterface;
    function GetRequiredService(const AServiceType: TServiceType): TObject;
    function CreateScope: IInterface; // Returns IServiceScope
  end;

  TDextServiceScope = class(TInterfacedObject, IServiceScope)
  private
    FServiceProvider: IServiceProvider;
  public
    constructor Create(AServiceProvider: IServiceProvider);
    function GetServiceProvider: IServiceProvider;
  end;

  TDextServiceCollection = class(TInterfacedObject, IServiceCollection)
  private
    FDescriptors: TObjectList<TServiceDescriptor>;
  public
    constructor Create;
    destructor Destroy; override;

    function AddSingleton(const AServiceType: TServiceType;
                         const AImplementationClass: TClass;
                         const AFactory: TFunc<IServiceProvider, TObject> = nil): IServiceCollection; overload;

    function AddTransient(const AServiceType: TServiceType;
                          const AImplementationClass: TClass;
                          const AFactory: TFunc<IServiceProvider, TObject> = nil): IServiceCollection; overload;

    function AddScoped(const AServiceType: TServiceType;
                       const AImplementationClass: TClass;
                       const AFactory: TFunc<IServiceProvider, TObject> = nil): IServiceCollection; overload;

    function BuildServiceProvider: IServiceProvider;
  end;

implementation

uses
  System.Rtti,
  System.TypInfo,
  Dext.Core.Activator;

{ TServiceDescriptor }

constructor TServiceDescriptor.Create(const AServiceType: TServiceType;
  AImplementationClass: TClass; ALifetime: TServiceLifetime;
  AFactory: TFunc<IServiceProvider, TObject>);
begin
  inherited Create;
  ServiceType := AServiceType;
  ImplementationClass := AImplementationClass;
  Lifetime := ALifetime;
  Factory := AFactory;
end;

{ TDextServiceCollection }

constructor TDextServiceCollection.Create;
begin
  inherited Create;
  FDescriptors := TObjectList<TServiceDescriptor>.Create(True);
end;

destructor TDextServiceCollection.Destroy;
begin
  FDescriptors.Free;
  inherited Destroy;
end;

function TDextServiceCollection.AddSingleton(const AServiceType: TServiceType;
  const AImplementationClass: TClass;
  const AFactory: TFunc<IServiceProvider, TObject>): IServiceCollection;
begin
  FDescriptors.Add(TServiceDescriptor.Create(
    AServiceType, AImplementationClass, TServiceLifetime.Singleton, AFactory));
  Result := Self;
end;

function TDextServiceCollection.AddTransient(const AServiceType: TServiceType;
  const AImplementationClass: TClass;
  const AFactory: TFunc<IServiceProvider, TObject>): IServiceCollection;
begin
  FDescriptors.Add(TServiceDescriptor.Create(
    AServiceType, AImplementationClass, TServiceLifetime.Transient, AFactory));
  Result := Self;
end;

function TDextServiceCollection.AddScoped(const AServiceType: TServiceType;
  const AImplementationClass: TClass;
  const AFactory: TFunc<IServiceProvider, TObject>): IServiceCollection;
begin
  FDescriptors.Add(TServiceDescriptor.Create(
    AServiceType, AImplementationClass, TServiceLifetime.Scoped, AFactory));
  Result := Self;
end;

function TDextServiceCollection.BuildServiceProvider: IServiceProvider;
begin
  Result := TDextServiceProvider.Create(FDescriptors);
  // Prevenir que os descriptors sejam destruídos quando a collection for destruída
  FDescriptors.OwnsObjects := False;
end;

{ TDextServiceProvider }

constructor TDextServiceProvider.Create(const ADescriptors: TObjectList<TServiceDescriptor>);
begin
  inherited Create;
  FDescriptors := ADescriptors;
  FSingletons := TDictionary<string, TObject>.Create;
  FSingletonInterfaces  := TDictionary<string, IInterface>.Create;
  FScopedInstances := TDictionary<string, TObject>.Create;
  FScopedInterfaces := TDictionary<string, IInterface>.Create;
  FLock := TCriticalSection.Create;
  FIsRootProvider := True;
  FParentProvider := nil;
end;

constructor TDextServiceProvider.CreateScoped(AParent: IServiceProvider; const ADescriptors: TObjectList<TServiceDescriptor>);
begin
  inherited Create;
  FDescriptors := ADescriptors;
  FSingletons := nil; // Scoped providers don't create singletons
  FSingletonInterfaces := nil;
  FScopedInstances := TDictionary<string, TObject>.Create;
  FScopedInterfaces := TDictionary<string, IInterface>.Create;
  FLock := TCriticalSection.Create;
  FIsRootProvider := False;
  FParentProvider := AParent;
end;

destructor TDextServiceProvider.Destroy;
var
  SingletonPair: TPair<string, TObject>;
  ScopedPair: TPair<string, TObject>;
begin
  // Liberar instâncias singleton (apenas no root provider)
  if FIsRootProvider then
  begin
    if Assigned(FSingletons) then
    begin
      for SingletonPair in FSingletons do
        if Assigned(SingletonPair.Value) then
          SingletonPair.Value.Free;
      FSingletons.Free;
    end;
    
    if Assigned(FSingletonInterfaces) then
      FSingletonInterfaces.Free;
  end;

  // Liberar instâncias scoped
  if Assigned(FScopedInstances) then
  begin
    for ScopedPair in FScopedInstances do
      if Assigned(ScopedPair.Value) then
        ScopedPair.Value.Free;
    FScopedInstances.Free;
  end;

  if Assigned(FScopedInterfaces) then
    FScopedInterfaces.Free;

  FLock.Free;
  
  // FDescriptors is owned by TDextServiceCollection, do not free it here.
  // if FIsRootProvider then
  //   FDescriptors.Free;

  inherited Destroy;
end;

function TDextServiceProvider.CreateScope: IInterface;
var
  ScopedProvider: IServiceProvider;
begin
  ScopedProvider := TDextServiceProvider.CreateScoped(Self, FDescriptors);
  Result := TDextServiceScope.Create(ScopedProvider);
end;

function TDextServiceProvider.FindDescriptor(const AServiceType: TServiceType): TServiceDescriptor;
var
  Descriptor: TServiceDescriptor;
begin
  for Descriptor in FDescriptors do
  begin
    if Descriptor.ServiceType = AServiceType then
      Exit(Descriptor);
  end;
  Result := nil;
end;

function TDextServiceProvider.CreateInstance(ADescriptor: TServiceDescriptor): TObject;
begin
  if Assigned(ADescriptor.Factory) then
    Result := ADescriptor.Factory(Self)
  else
    Result := TActivator.CreateInstance(Self, ADescriptor.ImplementationClass);
end;

function TDextServiceProvider.GetService(const AServiceType: TServiceType): TObject;
var
  Descriptor: TServiceDescriptor;
  Key: string;
  Instance: TObject;
begin
  Descriptor := FindDescriptor(AServiceType);
  if not Assigned(Descriptor) then
    Exit(nil);

  Key := AServiceType.ToString;

  FLock.Enter;
  try
    case Descriptor.Lifetime of
      TServiceLifetime.Singleton:
      begin
        // Singletons are only created in the root provider
        if FIsRootProvider then
        begin
          if not FSingletons.TryGetValue(Key, Instance) then
          begin
            Instance := CreateInstance(Descriptor);
            FSingletons.Add(Key, Instance);
          end;
          Result := Instance;
        end
        else
        begin
          // Delegate to parent
          Result := FParentProvider.GetService(AServiceType);
        end;
      end;

      TServiceLifetime.Scoped:
      begin
        if not FScopedInstances.TryGetValue(Key, Instance) then
        begin
          Instance := CreateInstance(Descriptor);
          FScopedInstances.Add(Key, Instance);
        end;
        Result := Instance;
      end;

      TServiceLifetime.Transient:
      begin
        Result := CreateInstance(Descriptor);
      end;
    else
      Result := nil;
    end;
  finally
    FLock.Leave;
  end;
end;

function TDextServiceProvider.GetServiceAsInterface(const AServiceType: TServiceType): IInterface;
var
  Descriptor: TServiceDescriptor;
  Key: string;
  Intf: IInterface;
  Obj: TObject;
begin
  Descriptor := FindDescriptor(AServiceType);
  if not Assigned(Descriptor) then
    Exit(nil);

  Key := AServiceType.ToString;

  FLock.Enter;
  try
    case Descriptor.Lifetime of
      TServiceLifetime.Singleton:
      begin
        if FIsRootProvider then
        begin
            if not FSingletonInterfaces.TryGetValue(Key, Intf) then
            begin
              Obj := CreateInstance(Descriptor);
              if not Supports(Obj, AServiceType.AsInterface, Intf) then
              begin
                Obj.Free;
                raise EDextDIException.CreateFmt('Service %s does not implement interface %s',
                  [Obj.ClassName, GUIDToString(AServiceType.AsInterface)]);
              end;
              FSingletonInterfaces.Add(Key, Intf);
            end;
            Result := Intf;
        end
        else
        begin
          Result := FParentProvider.GetServiceAsInterface(AServiceType);
        end;
      end;

      TServiceLifetime.Scoped:
      begin
        if not FScopedInterfaces.TryGetValue(Key, Intf) then
        begin
          Obj := CreateInstance(Descriptor);
          if not Supports(Obj, AServiceType.AsInterface, Intf) then
          begin
            Obj.Free;
            raise EDextDIException.CreateFmt('Service %s does not implement interface %s',
              [Obj.ClassName, GUIDToString(AServiceType.AsInterface)]);
          end;
          FScopedInterfaces.Add(Key, Intf);
        end;
        Result := Intf;
      end;

      TServiceLifetime.Transient:
      begin
        Obj := CreateInstance(Descriptor);
        if not Supports(Obj, AServiceType.AsInterface, Intf) then
        begin
          Obj.Free;
          raise EDextDIException.CreateFmt('Service %s does not implement interface %s',
            [Obj.ClassName, GUIDToString(AServiceType.AsInterface)]);
        end;
        Result := Intf;
      end;
    else
      Result := nil;
    end;
  finally
    FLock.Leave;
  end;
end;

function TDextServiceProvider.GetRequiredService(const AServiceType: TServiceType): TObject;
begin
  Result := GetService(AServiceType);
  if not Assigned(Result) then
    raise EDextDIException.CreateFmt('Required service not found: %s', [AServiceType.ToString]);
end;

{ TDextServiceScope }

constructor TDextServiceScope.Create(AServiceProvider: IServiceProvider);
begin
  inherited Create;
  FServiceProvider := AServiceProvider;
end;

function TDextServiceScope.GetServiceProvider: IServiceProvider;
begin
  Result := FServiceProvider;
end;

end.
