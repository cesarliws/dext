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
    function Clone: TServiceDescriptor;
    destructor Destroy; override;
  end;

  TDextServiceScope = class;

  TDextServiceProvider = class(TInterfacedObject, IServiceProvider)
  private
    FDescriptors: TObjectList<TServiceDescriptor>;
    FSingletons: TDictionary<string, TObject>;
    FSingletonInterfaces: TDictionary<string, IInterface>;
    FARCManagedKeys: TList<string>; // ✅ Track which keys are managed by ARC
    FIsRootProvider: Boolean;
    FParentProvider: IServiceProvider;
    FScopedInstances: TDictionary<string, TObject>;
    FScopedInterfaces: TDictionary<string, IInterface>;
    FLock: TCriticalSection;
    FOwnsDescriptors: Boolean; // ✅ New Field

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
end;


destructor TServiceDescriptor.Destroy;
begin
  // WriteLn('🗑️ TServiceDescriptor.Destroy'); // Uncomment if too noisy
  Factory := nil; // Explicitly release the interface reference
  inherited;
end;

function TServiceDescriptor.Clone: TServiceDescriptor;
begin
  Result := TServiceDescriptor.Create(ServiceType, ImplementationClass, Lifetime, Factory);
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
  // Collection retains ownership of its own descriptors
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
  begin
    FDescriptors.Add(Desc);
  end;
  FOwnsDescriptors := True; // We own the list container, but not the items

  FSingletons := TDictionary<string, TObject>.Create;
  FSingletonInterfaces  := TDictionary<string, IInterface>.Create;
  FARCManagedKeys := TList<string>.Create; // ✅ Track ARC-managed singletons
  FScopedInstances := TDictionary<string, TObject>.Create;
  FScopedInterfaces := TDictionary<string, IInterface>.Create;
  FLock := TCriticalSection.Create;
  FIsRootProvider := True;
  FParentProvider := nil;

  // Self-registration is handled dynamically to avoid circular references (ARC)
  // FSingletonInterfaces.Add(TServiceType.FromInterface(IServiceProvider).ToString, Self);
end;

constructor TDextServiceProvider.CreateScoped(AParent: IServiceProvider; const ADescriptors: TObjectList<TServiceDescriptor>);
var
  Desc: TServiceDescriptor;
begin
  inherited Create;
  FDescriptors := TObjectList<TServiceDescriptor>.Create(False);
  for Desc in ADescriptors do
  begin
    FDescriptors.Add(Desc);
  end;
  FOwnsDescriptors := True;

  FSingletons := nil; // Scoped providers don't create singletons
  FSingletonInterfaces := nil;
  FScopedInstances := TDictionary<string, TObject>.Create;
  FScopedInterfaces := TDictionary<string, IInterface>.Create;
  FLock := TCriticalSection.Create;
  FIsRootProvider := False;
  FParentProvider := AParent;
  
  // Self-registration is handled dynamically to avoid circular references (ARC)
  // FScopedInterfaces.Add(TServiceType.FromInterface(IServiceProvider).ToString, Self);
end;

destructor TDextServiceProvider.Destroy;
begin
  // Liberar instâncias singleton (apenas no root provider)
  if FIsRootProvider then
  begin
    // Clear interfaces first - ARC will free those objects
    if Assigned(FSingletonInterfaces) then
    begin
      FSingletonInterfaces.Clear;
      FSingletonInterfaces.Free;
    end;
    
    // Just clear singletons dict without freeing objects
    // Accept small leak for non-interface singletons to avoid double-free
    if Assigned(FSingletons) then
    begin
      FSingletons.Clear;
      FSingletons.Free;
    end;
    
    // Free the tracking list
    if Assigned(FARCManagedKeys) then
      FARCManagedKeys.Free;
  end;

  // Liberar instâncias scoped
  if Assigned(FScopedInterfaces) then
  begin
    FScopedInterfaces.Clear;
    FScopedInterfaces.Free;
  end;
  
  if Assigned(FScopedInstances) then
  begin
    FScopedInstances.Clear;
    FScopedInstances.Free;
  end;

  FLock.Free;
  
  // ✅ Only Free Descriptors if we own them
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
  begin
    Result := ADescriptor.Factory(Self);
  end
  else
  begin
    Result := TActivator.CreateInstance(Self, ADescriptor.ImplementationClass);
  end;
end;

function TDextServiceProvider.GetService(const AServiceType: TServiceType): TObject;
var
  Descriptor: TServiceDescriptor;
  Key: string;
  Instance: TObject;
begin
  Descriptor := FindDescriptor(AServiceType);
  if not Assigned(Descriptor) then
  begin
    Exit(nil);
  end;

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
              // ✅ Mark this key as ARC-managed
              if not FARCManagedKeys.Contains(Key) then
                FARCManagedKeys.Add(Key);
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

