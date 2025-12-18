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
{  Updated: 2025-12-10 - Refactored ownership model for explicit memory     }
{                        management. Interface-based services are managed   }
{                        by ARC, class-based services by explicit Free.     }
{                                                                           }
{***************************************************************************}
unit Dext.DI.Core;

interface

uses
  System.SysUtils, System.Generics.Collections, System.SyncObjs,
  Dext.DI.Interfaces;

type
  /// <summary>
  ///   Describes a service registration in the DI container.
  ///   Contains metadata about how to create and manage the service instance.
  /// </summary>
  TServiceDescriptor = class
  public
    ServiceType: TServiceType;
    ImplementationClass: TClass;
    Lifetime: TServiceLifetime;
    Factory: TFunc<IServiceProvider, TObject>;
    /// <summary>
    ///   Indicates if this service was registered as an interface type.
    ///   Interface services are managed by ARC (TInterfacedObject).
    ///   Class services are managed explicitly by the DI container (Free).
    /// </summary>
    IsInterfaceService: Boolean;
    
    constructor Create(const AServiceType: TServiceType;
      AImplementationClass: TClass; ALifetime: TServiceLifetime;
      AFactory: TFunc<IServiceProvider, TObject>);
    function Clone: TServiceDescriptor;
    destructor Destroy; override;
  end;

  TDextServiceScope = class;

  /// <summary>
  ///   The service provider (DI container) that resolves service instances.
  ///   Manages two separate storage mechanisms:
  ///   - FSingletons/FScopedInstances: For class-based services (explicit Free)
  ///   - FSingletonInterfaces/FScopedInterfaces: For interface-based services (ARC)
  /// </summary>
  TDextServiceProvider = class(TInterfacedObject, IServiceProvider)
  private
    FDescriptors: TObjectList<TServiceDescriptor>;
    
    // Class-based service storage (DI owns and frees these)
    FSingletons: TDictionary<string, TObject>;
    FScopedInstances: TDictionary<string, TObject>;
    
    // Interface-based service storage (ARC manages these)
    FSingletonInterfaces: TDictionary<string, IInterface>;
    FScopedInterfaces: TDictionary<string, IInterface>;
    
    FIsRootProvider: Boolean;
    FParentProvider: IServiceProvider;
    FLock: TCriticalSection;
    FOwnsDescriptors: Boolean;

    function CreateInstance(ADescriptor: TServiceDescriptor): TObject;
    function FindDescriptor(const AServiceType: TServiceType): TServiceDescriptor;
  public
    constructor Create(const ADescriptors: TObjectList<TServiceDescriptor>); overload;
    constructor CreateScoped(AParent: IServiceProvider; const ADescriptors: TObjectList<TServiceDescriptor>); overload;
    destructor Destroy; override;

    function GetService(const AServiceType: TServiceType): TObject;
    function GetServiceAsInterface(const AServiceType: TServiceType): IInterface;
    function GetRequiredService(const AServiceType: TServiceType): TObject;
    function CreateScope: IServiceScope;
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
  // Determine ownership model based on how the service was registered
  IsInterfaceService := AServiceType.IsInterface;
end;

destructor TServiceDescriptor.Destroy;
begin
  Factory := nil; // Explicitly release the closure reference
  inherited;
end;

function TServiceDescriptor.Clone: TServiceDescriptor;
begin
  Result := TServiceDescriptor.Create(ServiceType, ImplementationClass, Lifetime, Factory);
  Result.IsInterfaceService := IsInterfaceService;
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
var
  Descriptor: TServiceDescriptor;
begin
  Descriptor := TServiceDescriptor.Create(
    AServiceType, AImplementationClass, TServiceLifetime.Singleton, AFactory);
  FDescriptors.Add(Descriptor);
  Result := Self;
end;

function TDextServiceCollection.AddTransient(const AServiceType: TServiceType;
  const AImplementationClass: TClass;
  const AFactory: TFunc<IServiceProvider, TObject>): IServiceCollection;
var
  Descriptor: TServiceDescriptor;
begin
  Descriptor := TServiceDescriptor.Create(
    AServiceType, AImplementationClass, TServiceLifetime.Transient, AFactory);
  FDescriptors.Add(Descriptor);
  Result := Self;
end;

function TDextServiceCollection.AddScoped(const AServiceType: TServiceType;
  const AImplementationClass: TClass;
  const AFactory: TFunc<IServiceProvider, TObject>): IServiceCollection;
var
  Descriptor: TServiceDescriptor;
begin
  Descriptor := TServiceDescriptor.Create(
    AServiceType, AImplementationClass, TServiceLifetime.Scoped, AFactory);
  FDescriptors.Add(Descriptor);
  Result := Self;
end;

function TDextServiceCollection.BuildServiceProvider: IServiceProvider;
begin
  Result := TDextServiceProvider.Create(FDescriptors);
end;

{ TDextServiceProvider }

constructor TDextServiceProvider.Create(const ADescriptors: TObjectList<TServiceDescriptor>);
var
  Desc: TServiceDescriptor;
begin
  inherited Create;
  // Create our own list container, but share the items (owned by Collection)
  FDescriptors := TObjectList<TServiceDescriptor>.Create(False);
  for Desc in ADescriptors do
    FDescriptors.Add(Desc);
  FOwnsDescriptors := True;

  // Class-based storage (DI owns these objects)
  FSingletons := TDictionary<string, TObject>.Create;
  FScopedInstances := TDictionary<string, TObject>.Create;
  
  // Interface-based storage (ARC owns these objects)
  FSingletonInterfaces := TDictionary<string, IInterface>.Create;
  FScopedInterfaces := TDictionary<string, IInterface>.Create;
  
  FLock := TCriticalSection.Create;
  FIsRootProvider := True;
  FParentProvider := nil;
end;

constructor TDextServiceProvider.CreateScoped(AParent: IServiceProvider; 
  const ADescriptors: TObjectList<TServiceDescriptor>);
var
  Desc: TServiceDescriptor;
begin
  inherited Create;
  FDescriptors := TObjectList<TServiceDescriptor>.Create(False);
  for Desc in ADescriptors do
    FDescriptors.Add(Desc);
  FOwnsDescriptors := True;

  // Scoped providers don't manage singletons - they delegate to parent
  FSingletons := nil;
  FSingletonInterfaces := nil;
  
  // But they do manage scoped instances
  FScopedInstances := TDictionary<string, TObject>.Create;
  FScopedInterfaces := TDictionary<string, IInterface>.Create;
  
  FLock := TCriticalSection.Create;
  FIsRootProvider := False;
  FParentProvider := AParent;
end;

destructor TDextServiceProvider.Destroy;
var
  SingletonObj: TObject;
  ScopedObj: TObject;
  Key: string;
begin
  // === SINGLETON CLEANUP (only for root provider) ===
  if FIsRootProvider then
  begin
    // 1. Free class-based singletons (non-TInterfacedObject)
    //    TInterfacedObject instances will be freed by ARC when FSingletonInterfaces is cleared
    if Assigned(FSingletons) then
    begin
      for Key in FSingletons.Keys do
      begin
        if FSingletons.TryGetValue(Key, SingletonObj) then
        begin
          // Only free if NOT a TInterfacedObject (ARC will handle those)
          if not (SingletonObj is TInterfacedObject) then
            SingletonObj.Free;
        end;
      end;
      FSingletons.Free;
    end;
    
    // 2. Clear interface-based singletons (ARC manages the objects)
    if Assigned(FSingletonInterfaces) then
    begin
      FSingletonInterfaces.Clear; // ARC will free TInterfacedObject instances
      FSingletonInterfaces.Free;
    end;
  end;

  // === SCOPED CLEANUP ===
  // 1. Free class-based scoped instances (non-TInterfacedObject only)
  if Assigned(FScopedInstances) then
  begin
    for Key in FScopedInstances.Keys do
    begin
      if FScopedInstances.TryGetValue(Key, ScopedObj) then
      begin
        if not (ScopedObj is TInterfacedObject) then
          ScopedObj.Free;
      end;
    end;
    FScopedInstances.Free;
  end;
  
  // 2. Clear interface-based scoped instances (ARC manages)
  if Assigned(FScopedInterfaces) then
  begin
    FScopedInterfaces.Clear;
    FScopedInterfaces.Free;
  end;

  FLock.Free;
  
  if FOwnsDescriptors and Assigned(FDescriptors) then
    FDescriptors.Free;

  inherited Destroy;
end;

function TDextServiceProvider.CreateScope: IServiceScope;
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
          Result := FParentProvider.GetService(AServiceType);
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
        Result := CreateInstance(Descriptor);
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
  // Special handling for IServiceProvider to return Self without dictionary cycle
  if AServiceType.IsInterface and IsEqualGUID(AServiceType.AsInterface, IServiceProvider) then
    Exit(Self);

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
            // Note: The object is now owned by ARC via the interface reference
          end;
          Result := Intf;
        end
        else
          Result := FParentProvider.GetServiceAsInterface(AServiceType);
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
