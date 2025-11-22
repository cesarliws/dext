unit Dext.DI.Core;

interface

uses
  System.SysUtils, System.Generics.Collections,
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

  TDextServiceProvider = class(TInterfacedObject, IServiceProvider)
  private
    FDescriptors: TObjectList<TServiceDescriptor>;
    FSingletons: TDictionary<string, TObject>;
    FSingletonInterfaces: TDictionary<string, IInterface>;
    FScopedInstances: TDictionary<TServiceType, TObject>;

    function CreateInstance(ADescriptor: TServiceDescriptor): TObject;
    function FindDescriptor(const AServiceType: TServiceType): TServiceDescriptor;
  public
    constructor Create(const ADescriptors: TObjectList<TServiceDescriptor>);
    destructor Destroy; override;

    function GetService(const AServiceType: TServiceType): TObject;
    function GetServiceAsInterface(const AServiceType: TServiceType): IInterface;
    function GetRequiredService(const AServiceType: TServiceType): TObject;
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
  FScopedInstances := TDictionary<TServiceType, TObject>.Create;
end;

destructor TDextServiceProvider.Destroy;
var
  SingletonPair: TPair<string, TObject>;
  Pair: TPair<TServiceType, TObject>;
  InterfacePair: TPair<string, IInterface>;
begin
  // Liberar instâncias singleton
  for SingletonPair in FSingletons do
    if Assigned(SingletonPair.Value) then
      SingletonPair.Value.Free;
  FSingletons.Free;

  for InterfacePair in FSingletonInterfaces do
    if Assigned(InterfacePair.Value) then
      InterfacePair.Value._Release;
  FSingletonInterfaces.Free;

  // Liberar instâncias scoped
  for Pair in FScopedInstances do
    if Assigned(Pair.Value) then
      Pair.Value.Free;
  FScopedInstances.Free;

  FDescriptors.Free;
  inherited Destroy;
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
    // Resolução via TActivator (suporta injeção de dependência no construtor)
    Result := TActivator.CreateInstance(Self, ADescriptor.ImplementationClass, []);
end;

function TDextServiceProvider.GetService(const AServiceType: TServiceType): TObject;
var
  Descriptor: TServiceDescriptor;
  Key: string;
begin
  Key := AServiceType.ToString;
  Descriptor := FindDescriptor(AServiceType);
  if not Assigned(Descriptor) then
    Exit(nil);

  case Descriptor.Lifetime of
    TServiceLifetime.Singleton:
    begin
      if not FSingletons.TryGetValue(Key, Result) then
      begin
        Result := CreateInstance(Descriptor);
        FSingletons.Add(Key, Result);
      end;
    end;

    TServiceLifetime.Transient:
    begin
      Result := CreateInstance(Descriptor);
    end;

    TServiceLifetime.Scoped:
    begin
      if not FScopedInstances.TryGetValue(AServiceType, Result) then
      begin
        Result := CreateInstance(Descriptor);
        FScopedInstances.Add(AServiceType, Result);
      end;
    end;
  else
    Result := nil;
  end;
end;

function TDextServiceProvider.GetServiceAsInterface(const AServiceType: TServiceType): IInterface;
var
  Key: string;
  Instance: TObject;
  InterfaceInstance: IInterface;
begin
  Key := AServiceType.ToString;

  // ✅ PRIMEIRO: Tentar buscar da cache de interfaces
  if FSingletonInterfaces.TryGetValue(Key, Result) then
    Exit;

  // ✅ SEGUNDO: Buscar do container e converter para interface
  Instance := GetService(AServiceType);

  if Assigned(Instance) and Instance.GetInterface(AServiceType.AsInterface, InterfaceInstance) then
  begin
    // ✅ ARMAZENAR a interface (não apenas o objeto)
    FSingletonInterfaces.Add(Key, InterfaceInstance);
    Result := InterfaceInstance;
  end
  else
    Result := nil;
end;


function TDextServiceProvider.GetRequiredService(const AServiceType: TServiceType): TObject;
begin
  Result := GetService(AServiceType);
  if not Assigned(Result) then
    raise EDextDIException.Create('Service not registered');
end;

end.
