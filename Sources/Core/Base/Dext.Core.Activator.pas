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
unit Dext.Core.Activator;

interface

uses
  System.Rtti,
  System.SyncObjs,
  System.SysUtils,
  System.TypInfo,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.DI.Interfaces,
  Dext.DI.Attributes;
type
  /// <summary>
  /// Represents a cached constructor resolution entry, holding the method to invoke and its required parameter types.
  /// </summary>
  TConstructorEntry = record
    Method: TRttiMethod;
    ParamTypes: TArray<PTypeInfo>;
  end;

  /// <summary>
  ///   Central activation and dynamic instantiation service for Dext.
  ///   Manages object creation through RTTI, supporting dependency injection via constructor,
  ///   properties, and fields. Implements the "Greedy" strategy for constructor selection.
  /// </summary>
  TActivator = class
  public
    /// <summary>Instantiates a class using only positional manual arguments.</summary>
    class function CreateInstance(AClass: TClass; const AArgs: array of TValue): TObject; overload;

    /// <summary>Instantiates a class resolving ALL constructor dependencies via DI (Greedy Strategy - highest number of resolvable parameters).</summary>
    class function CreateInstance(AProvider: IServiceProvider; AClass: TClass): TObject; overload;

    /// <summary>Instantiates a class combining manual (positional) arguments and automatic DI resolution for the remaining parameters.</summary>
    class function CreateInstance(AProvider: IServiceProvider; AClass: TClass; const AArgs: array of TValue): TObject; overload;

    /// <summary>Instantiates a type (Class or Interface) based on PTypeInfo. Supports auto-instantiation of IList, IEnumerable, and IDictionary.</summary>
    class function CreateInstance(AProvider: IServiceProvider; AType: PTypeInfo): TValue; overload;

    /// <summary>Instantiates a class using a generic type parameter, relying on the parameterless constructor or manual arguments.</summary>
    class function CreateInstance<T: class>(const AArgs: array of TValue): T; overload;
    
    /// <summary>Instantiates a class using a generic type parameter without any manual arguments.</summary>
    class function CreateInstance<T: class>: T; overload;

    /// <summary>
    ///   Creates an instance using only RTTI, without requiring a configured ServiceProvider.
    ///   Prefers the parameterless constructor. For interface types, handles IList, IDictionary,
    ///   and types registered via RegisterDefault. Returns TValue.Empty when instantiation is
    ///   not possible. In DEBUG builds, emits diagnostic messages via OutputDebugString.
    ///   Designed for standalone JSON serialization in legacy projects without full DI setup.
    /// </summary>
    class function CreateInstanceRttiOnly(AType: PTypeInfo): TValue;

    /// <summary>Registers a default implementation class for a specific base class.</summary>
    class procedure RegisterDefault(ABase: TClass; AImpl: TClass); overload;
    
    /// <summary>Registers a default implementation class for a specific interface type.</summary>
    class procedure RegisterDefault(AInterface: PTypeInfo; AImpl: TClass); overload;
    
    /// <summary>Registers a default implementation class for a generic service interface.</summary>
    class procedure RegisterDefault<TService: IInterface; TImplementation: class>; overload;
    
    /// <summary>Resolves the configured default implementation for a given class. Returns the original class if no default is registered.</summary>
    class function ResolveImplementation(AClass: TClass): TClass;
    /// <summary>Detects if a PTypeInfo represents a list type (IList, TList, IEnumerable, etc.).</summary>
    class function IsListType(AType: PTypeInfo): Boolean;
    /// <summary>Gets the inner element type of a list (e.g., T from IList of T).</summary>
    class function GetListElementType(AType: PTypeInfo): PTypeInfo;
    /// <summary>Detects if a type represents a dictionary (IDictionary or TDictionary).</summary>
    class function IsDictionaryType(AType: PTypeInfo): Boolean;
    /// <summary>Gets the Key type of a dictionary.</summary>
    class function GetDictionaryKeyType(AType: PTypeInfo): PTypeInfo;
    /// <summary>Gets the Value type of a dictionary.</summary>
    class function GetDictionaryValueType(AType: PTypeInfo): PTypeInfo;
    /// <summary>Returns the global shared RTTI context.</summary>
    class function GetRttiContext: TRttiContext;
  private
    class var FDefaultImplementations: IDictionary<TClass, TClass>;
    class var FInterfaceDefaultImpl: IDictionary<PTypeInfo, TClass>;
    class var FConstructorCache: IDictionary<TClass, TConstructorEntry>;
    class var FHybridConstructorCache: IDictionary<string, TConstructorEntry>;
    class var FLock: TMREWSync;
    class constructor Create;
    class destructor Destroy;
    class function TryResolveService(AProvider: IServiceProvider; AParamType: TRttiType; out AResolvedService: TValue): Boolean;
    class procedure InjectFields(AProvider: IServiceProvider; AInstance: TObject; ATypeObj: TRttiType);
  end;

implementation

uses
  System.Classes,
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
  Dext.Core.Reflection,
  Dext.Utils;

function MakeTypedInterfaceValue(const AIntf: IInterface; AType: PTypeInfo): TValue;
var
  LTyped: IInterface;
  LGuid: TGUID;
begin
  if (AType <> nil) and (AType.Kind = tkInterface) then
  begin
    LGuid := GetTypeData(AType)^.Guid;
    if (not IsEqualGUID(LGuid, TGUID.Empty)) and Supports(AIntf, LGuid, LTyped) then
    begin
      TValue.Make(@LTyped, AType, Result);
      Exit;
    end;
  end;

  // Fallback for interfaces without GUID/special cases
  Result := TValue.From<IInterface>(AIntf);
end;

{ TActivator }

class constructor TActivator.Create;
begin
  FDefaultImplementations := TCollections.CreateDictionary<TClass, TClass>;
  FInterfaceDefaultImpl := TCollections.CreateDictionary<PTypeInfo, TClass>;
  FConstructorCache := TCollections.CreateDictionary<TClass, TConstructorEntry>;
  FHybridConstructorCache := TCollections.CreateDictionary<string, TConstructorEntry>;
  FLock := TMREWSync.Create;
  // Default framework mappings
  RegisterDefault(TStrings, TStringList);
end;

class destructor TActivator.Destroy;
begin
  FDefaultImplementations := nil;
  FInterfaceDefaultImpl := nil;
  FConstructorCache := nil;
  FHybridConstructorCache := nil;
  FLock.Free;
end;

class function TActivator.GetRttiContext: TRttiContext;
begin
  Result := TReflection.Context;
end;

class function TActivator.CreateInstanceRttiOnly(AType: PTypeInfo): TValue;
var
  BestMethod: TRttiMethod;
  Entry: TConstructorEntry;
  Method: TRttiMethod;
  RegisteredImpl: TClass;
  TargetClass: TClass;
  TypeObj: TRttiType;
  {$IFDEF DEBUG}
  HasDIConstructors: Boolean;
  {$ENDIF}
begin
  Result := TValue.Empty;
  if AType = nil then
    Exit;

  case AType.Kind of
    tkClass:
    begin
      TargetClass := ResolveImplementation(AType.TypeData.ClassType);

      // Fast path: reuse cached parameterless constructor
      FLock.BeginRead;
      try
        if FConstructorCache.TryGetValue(TargetClass, Entry) then
          if (Entry.Method <> nil) and (Length(Entry.ParamTypes) = 0) then
            Exit(TValue.From(Entry.Method.Invoke(TargetClass, []).AsObject));
      finally
        FLock.EndRead;
      end;

      TypeObj := GetRttiContext.GetType(TargetClass);
      if TypeObj = nil then
        Exit;

      BestMethod := nil;
      {$IFDEF DEBUG}
      HasDIConstructors := False;
      {$ENDIF}
      for Method in TypeObj.GetMethods do
      begin
        if not Method.IsConstructor then Continue;
        if Length(Method.GetParameters) = 0 then
        begin
          BestMethod := Method;
          Break;
        end;
        {$IFDEF DEBUG}
        if (Length(Method.GetParameters) > 0) and
           (Method.GetParameters[0].ParamType.TypeKind in [tkInterface, tkClass]) then
          HasDIConstructors := True;
        {$ENDIF}
      end;

      if BestMethod <> nil then
      begin
        Entry.Method := BestMethod;
        Entry.ParamTypes := nil;
        FLock.BeginWrite;
        try
          FConstructorCache.AddOrSetValue(TargetClass, Entry);
        finally
          FLock.EndWrite;
        end;
        {$IFDEF DEBUG}
        if HasDIConstructors then
          DebugLog(
            '[Dext.Json] INFO: Deserializing "' + TargetClass.ClassName + '" via RTTI-only ' +
            '(no ServiceProvider configured). DI constructor detected but ignored. ' +
            'Use JsonSettings.ServiceProvider(sp) for full DI support.');
        {$ENDIF}
        Result := TValue.From(BestMethod.Invoke(TargetClass, []).AsObject);
      end
      else
      begin
        {$IFDEF DEBUG}
        DebugLog(
          '[Dext.Json] WARNING: Cannot instantiate "' + TargetClass.ClassName + '" — ' +
          'no parameterless constructor found. ' +
          'Use JsonSettings.ServiceProvider(sp) to enable DI-based construction.');
        {$ENDIF}
      end;
    end;

    tkInterface:
    begin
      // IList<T>, IDictionary<K,V> and RegisterDefault mappings work with nil provider
      if IsListType(AType) or IsDictionaryType(AType) or
         FInterfaceDefaultImpl.TryGetValue(AType, RegisteredImpl) then
        Result := CreateInstance(nil, AType)
      else
      begin
        {$IFDEF DEBUG}
        DebugLog(
          '[Dext.Json] WARNING: Cannot instantiate interface "' + string(AType^.Name) + '" — ' +
          'no implementation registered. ' +
          'Use TActivator.RegisterDefault<IService, TImpl> or ' +
          'configure a ServiceProvider via JsonSettings.ServiceProvider(sp).');
        {$ENDIF}
      end;
    end;
  end;
end;

class procedure TActivator.RegisterDefault(ABase: TClass; AImpl: TClass);
begin
  if ABase <> nil then
    FDefaultImplementations.AddOrSetValue(ABase, AImpl);
end;

class procedure TActivator.RegisterDefault(AInterface: PTypeInfo; AImpl: TClass);
begin
  if AInterface <> nil then
    FInterfaceDefaultImpl.AddOrSetValue(AInterface, AImpl);
end;

class procedure TActivator.RegisterDefault<TService, TImplementation>;
begin
  RegisterDefault(TypeInfo(TService), TImplementation);
end;

class function TActivator.ResolveImplementation(AClass: TClass): TClass;
begin
  if (AClass = nil) or not FDefaultImplementations.TryGetValue(AClass, Result) then
    Result := AClass;
end;

class function TActivator.TryResolveService(AProvider: IServiceProvider; AParamType: TRttiType; out AResolvedService: TValue): Boolean;
var
  LServiceType: TServiceType;
  LGuid: TGUID;
  LIntf: IInterface;
  LCls: TClass;
  LObj: TObject;
begin
  AResolvedService := TValue.Empty;
  Result := False;

  if AProvider = nil then
    Exit;

  if AParamType.TypeKind = tkInterface then
  begin
    LGuid := TRttiInterfaceType(AParamType).GUID;
    if (AParamType.Handle <> nil) or (not LGuid.IsEmpty) then
    begin
      LServiceType := TServiceType.FromInterface(AParamType.Handle);
      LIntf := AProvider.GetServiceAsInterface(LServiceType);
      if LIntf <> nil then
      begin
        AResolvedService := MakeTypedInterfaceValue(LIntf, AParamType.Handle);
        Result := True;
      end;
    end;
  end
  else if AParamType.TypeKind = tkClass then
  begin
    LCls := TRttiInstanceType(AParamType).MetaclassType;
    LServiceType := TServiceType.FromClass(LCls);
    LObj := AProvider.GetService(LServiceType);
    if LObj <> nil then
    begin
      AResolvedService := TValue.From(LObj);
      Result := True;
    end;
  end;
end;

class procedure TActivator.InjectFields(AProvider: IServiceProvider; AInstance: TObject; ATypeObj: TRttiType);
var
  Field: TRttiField;
  Prop: TRttiProperty;
  Attr: TCustomAttribute;
  InjectAttr: InjectAttribute;
  TargetType: PTypeInfo;
  ResolvedValue: TValue;
begin
  if (AProvider = nil) or (AInstance = nil) or (ATypeObj = nil) then Exit;

  // Process Fields
  for Field in ATypeObj.GetFields do
  begin
    InjectAttr := nil;
    for Attr in Field.GetAttributes do
      if Attr is InjectAttribute then
      begin
        InjectAttr := InjectAttribute(Attr);
        Break;
      end;
      
    if InjectAttr <> nil then
    begin
      TargetType := Field.FieldType.Handle;
      if InjectAttr.TargetTypeInfo <> nil then
        TargetType := PTypeInfo(InjectAttr.TargetTypeInfo);
        
      if TargetType <> nil then
      begin
        ResolvedValue := CreateInstance(AProvider, TargetType);
        if not ResolvedValue.IsEmpty then
          Field.SetValue(AInstance, ResolvedValue);
      end;
    end;
  end;

  // Process Properties
  for Prop in ATypeObj.GetProperties do
  begin
    if not Prop.IsWritable then Continue;
    
    InjectAttr := nil;
    for Attr in Prop.GetAttributes do
      if Attr is InjectAttribute then
      begin
        InjectAttr := InjectAttribute(Attr);
        Break;
      end;
      
    if InjectAttr <> nil then
    begin
      TargetType := Prop.PropertyType.Handle;
      if InjectAttr.TargetTypeInfo <> nil then
        TargetType := PTypeInfo(InjectAttr.TargetTypeInfo);
        
      if TargetType <> nil then
      begin
        ResolvedValue := CreateInstance(AProvider, TargetType);
        if not ResolvedValue.IsEmpty then
          Prop.SetValue(AInstance, ResolvedValue);
      end;
    end;
  end;
end;

// 1. Manual Instantiation with Hybrid DI Support
class function TActivator.CreateInstance(AClass: TClass; const AArgs: array of TValue): TObject;
var
  Context: TRttiContext;
  TypeObj: TRttiType;
  Method: TRttiMethod;
  Params: TArray<TRttiParameter>;
  Args: TArray<TValue>;
  I: Integer;
  Matched: Boolean;
  BestMethod: TRttiMethod;
  BestArgs: TArray<TValue>;
  TargetClass: TClass;
  Entry: TConstructorEntry;
begin
  TargetClass := ResolveImplementation(AClass);
  
  // 0. Check cache for parameterless constructor (read-only path)
  if Length(AArgs) = 0 then
  begin
    FLock.BeginRead;
    try
      if FConstructorCache.TryGetValue(TargetClass, Entry) then
      begin
        if Length(Entry.ParamTypes) = 0 then
        begin
          Result := Entry.Method.Invoke(TargetClass, []).AsObject;
          Exit;
        end;
      end;
    finally
      FLock.EndRead;
    end;
  end;

  BestMethod := nil;

  Context := GetRttiContext;
  try
    TypeObj := Context.GetType(TargetClass);
    if TypeObj = nil then
      raise EArgumentException.CreateFmt('RTTI information not found for class %s', [TargetClass.ClassName]);
    for Method in TypeObj.GetMethods do
    begin
      if Method.IsConstructor then
      begin
        Params := Method.GetParameters;
        
        if Length(Params) < Length(AArgs) then
          Continue; 
        
        Matched := True;
        SetLength(Args, Length(Params));
        
        for I := 0 to High(AArgs) do
        begin
          if AArgs[I].IsEmpty then Continue;

          if AArgs[I].Kind <> Params[I].ParamType.TypeKind then
          begin
            if (AArgs[I].Kind = tkInterface) and (Params[I].ParamType.TypeKind = tkInterface) then
            begin
              Args[I] := AArgs[I];
              Continue;
            end;
            
            if (AArgs[I].Kind = tkClass) and (Params[I].ParamType.TypeKind = tkClass) then
            begin
              Args[I] := AArgs[I];
              Continue;
            end;

            Matched := False;
            Break;
          end;
          
          if (AArgs[I].Kind = tkRecord) and (AArgs[I].TypeInfo <> Params[I].ParamType.Handle) then
          begin
             Matched := False;
             Break;
          end;
          
          Args[I] := AArgs[I];
        end;

        if not Matched then
          Continue;
        
        if Length(Params) = Length(AArgs) then
        begin
          // If we find a constructor, we prefer the one from the most derived class
          if BestMethod = nil then
          begin
            BestMethod := Method;
            BestArgs := Args;
          end
          else if Method.Parent.Handle = TypeObj.Handle then
          begin
            // Current class constructor ALWAYS wins over inherited ones
            BestMethod := Method;
            BestArgs := Args;
          end;
        end;
      end;
    end;

    if BestMethod <> nil then
    begin
       // Only cache if it is a parameterless constructor
       if Length(AArgs) = 0 then
       begin
       Entry.Method := BestMethod;
       Entry.ParamTypes := nil;
       FLock.BeginWrite;
       try
         FConstructorCache.AddOrSetValue(TargetClass, Entry);
       finally
         FLock.EndWrite;
       end;
       end;

       Result := BestMethod.Invoke(TargetClass, BestArgs).AsObject;
       Exit;
    end;

    raise EArgumentException.CreateFmt('No compatible constructor found for class %s', [AClass.ClassName]);
  finally
  ;
  end;
end;

// 2. Pure DI Instantiation (Greedy)
class function TActivator.CreateInstance(AProvider: IServiceProvider; AClass: TClass): TObject;
var
  Context: TRttiContext;
  TypeObj: TRttiType;
  Method: TRttiMethod;
  Params: TArray<TRttiParameter>;
  Args: TArray<TValue>;
  I: Integer;
  Matched: Boolean;
  ResolvedService: TValue;
  
  // Best match tracking
  BestMethod: TRttiMethod;
  BestArgs: TArray<TValue>;
  MaxParams: Integer;
  HasServiceConstructorAttr: Boolean;
  TargetClass: TClass;
  Entry: TConstructorEntry;
  Attr: TCustomAttribute;
  WinnerParams: TArray<TRttiParameter>;
begin
  TargetClass := ResolveImplementation(AClass);

  // 0. Check Cache (read path)
  FLock.BeginRead;
  try
    FConstructorCache.TryGetValue(TargetClass, Entry);
  finally
    FLock.EndRead;
  end;
  if Entry.Method <> nil then
  begin
    SetLength(Args, Length(Entry.ParamTypes));
    Matched := True;
    for I := 0 to High(Entry.ParamTypes) do
    begin
      if not TryResolveService(AProvider, TReflection.Context.GetType(Entry.ParamTypes[I]), ResolvedService) then
      begin
        Matched := False;
        Break;
      end;
      Args[I] := ResolvedService;
    end;

    if Matched then
    begin
      Result := Entry.Method.Invoke(TargetClass, Args).AsObject;
      InjectFields(AProvider, Result, TReflection.Context.GetType(TargetClass));
      Exit;
    end;
  end;

  Context := GetRttiContext;
  try
    TypeObj := Context.GetType(TargetClass);
    if TypeObj = nil then
      raise EArgumentException.CreateFmt('RTTI not found for %s', [TargetClass.ClassName]);

    BestMethod := nil;
    MaxParams := -1;

    // First pass: Look for [ServiceConstructor] attribute
    for Method in TypeObj.GetMethods do
    begin
      if Method.IsConstructor then
      begin
        HasServiceConstructorAttr := False;
        for Attr in Method.GetAttributes do
        begin
          if Attr is ServiceConstructorAttribute then
          begin
            HasServiceConstructorAttr := True;
            Break;
          end;
        end;
        
        if HasServiceConstructorAttr then
        begin
          // Try to resolve this constructor
          Params := Method.GetParameters;
          SetLength(Args, Length(Params));
          Matched := True;

          for I := 0 to High(Params) do
          begin
            if not TryResolveService(AProvider, Params[I].ParamType, ResolvedService) then
            begin
              Matched := False;
              Break;
            end;
            Args[I] := ResolvedService;
          end;

          if Matched then
          begin
            // Cache the result for next time
            Entry.Method := Method;
            SetLength(Entry.ParamTypes, Length(Params));
            for I := 0 to High(Params) do
              Entry.ParamTypes[I] := Params[I].ParamType.Handle;
            FLock.BeginWrite;
            try
              FConstructorCache.AddOrSetValue(TargetClass, Entry);
            finally
              FLock.EndWrite;
            end;

            // Use this constructor
            Result := Method.Invoke(TargetClass, Args).AsObject;
            InjectFields(AProvider, Result, TypeObj);
            Exit;
          end;
        end;
      end;
    end;

    // Second pass: Greedy strategy (no [ServiceConstructor] found or it failed)
    for Method in TypeObj.GetMethods do
    begin
      if Method.IsConstructor then
      begin
        Params := Method.GetParameters;
        SetLength(Args, Length(Params));
        Matched := True;
        for I := 0 to High(Params) do
        begin
          if not TryResolveService(AProvider, Params[I].ParamType, ResolvedService) then
          begin
            Matched := False;
            Break;
          end;
          Args[I] := ResolvedService;
        end;

        if Matched then
        begin
          // Greedy selection: prefer constructor with MORE parameters.
          // If parameters are equal, prefer the one from the most derived class (Target class).
          if (Length(Params) > MaxParams) or 
             ((Length(Params) = MaxParams) and (Method.Parent.Handle = TypeObj.Handle)) then
          begin
            MaxParams := Length(Params);
            BestMethod := Method;
            BestArgs := Args;
          end;
        end;
      end;
    end;

    if BestMethod <> nil then
    begin
      // Cache the winner
      Entry.Method := BestMethod;
      WinnerParams := BestMethod.GetParameters;
      SetLength(Entry.ParamTypes, Length(WinnerParams));
      for I := 0 to High(WinnerParams) do
        Entry.ParamTypes[I] := WinnerParams[I].ParamType.Handle;
      FLock.BeginWrite;
      try
        FConstructorCache.AddOrSetValue(TargetClass, Entry);
      finally
        FLock.EndWrite;
      end;

      Result := BestMethod.Invoke(AClass, BestArgs).AsObject;
      InjectFields(AProvider, Result, TypeObj);
    end
    else
    begin
      // ERROR: No suitable constructor found (or dependencies missing)
      // Do NOT fallback to TObject.Create arbitrarily.
      raise EArgumentException.CreateFmt('TActivator: No satisfiable constructor found for %s. Check if all dependencies are registered.', [AClass.ClassName]);
    end;
  finally
  ;
  end;
end;

// 3. Hybrid Instantiation (Manual Args + DI)
class function TActivator.CreateInstance(AProvider: IServiceProvider; AClass: TClass; const AArgs: array of TValue): TObject;
var
  TypeObj: TRttiType;
  Method: TRttiMethod;
  Params: TArray<TRttiParameter>;
  Args: TArray<TValue>;
  I: Integer;
  Matched: Boolean;
  ResolvedService: TValue;
  TargetClass: TClass;
  CacheKey: string;
  Entry: TConstructorEntry;
begin
  TargetClass := ResolveImplementation(AClass);
  // If no args provided, delegate to Pure DI overload
  if Length(AArgs) = 0 then
    Exit(CreateInstance(AProvider, TargetClass));

  // 0. Check Hybrid Cache (read path)
  CacheKey := TargetClass.ClassName + '-' + Length(AArgs).ToString;
  FLock.BeginRead;
  try
    FHybridConstructorCache.TryGetValue(CacheKey, Entry);
  finally
    FLock.EndRead;
  end;
  if Entry.Method <> nil then
  begin
    SetLength(Args, Length(Entry.ParamTypes));
    Matched := True;
    for I := 0 to High(Entry.ParamTypes) do
    begin
      // Initial params are manual (positional)
      if I < Length(AArgs) then
      begin
        Args[I] := AArgs[I];
        Continue;
      end;

      // Remaining are resolved from DI
      if not TryResolveService(AProvider, TReflection.Context.GetType(Entry.ParamTypes[I]), ResolvedService) then
      begin
        Matched := False;
        Break;
      end;
      Args[I] := ResolvedService;
    end;

    if Matched then
    begin
      Result := Entry.Method.Invoke(TargetClass, Args).AsObject;
      InjectFields(AProvider, Result, TReflection.Context.GetType(TargetClass));
      Exit;
    end;
  end;

  TypeObj := TReflection.Context.GetType(TargetClass);
  if TypeObj = nil then
    raise EArgumentException.CreateFmt('RTTI not found for %s', [TargetClass.ClassName]);

  for Method in TypeObj.GetMethods do
  begin
    if Method.IsConstructor then
    begin
      Params := Method.GetParameters;
      
      // Must have at least enough params for explicit args
      if Length(Params) < Length(AArgs) then
        Continue;
        
      SetLength(Args, Length(Params));
      Matched := True;

      for I := 0 to High(Params) do
      begin
        // 1. Check explicit args (positional)
        if I < Length(AArgs) then
        begin
           Args[I] := AArgs[I];
           Continue;
        end;

        // 2. Resolve remaining from DI
        if not TryResolveService(AProvider, Params[I].ParamType, ResolvedService) then
        begin
          Matched := False;
          Break;
        end;
        Args[I] := ResolvedService;
      end;

      if Matched then
      begin
        // Cache the found constructor for this Hybrid configuration
        Entry.Method := Method;
        SetLength(Entry.ParamTypes, Length(Params));
        for I := 0 to High(Params) do
          Entry.ParamTypes[I] := Params[I].ParamType.Handle;

        FLock.BeginWrite;
        try
          FHybridConstructorCache.AddOrSetValue(CacheKey, Entry);
        finally
          FLock.EndWrite;
        end;

        Result := Method.Invoke(TargetClass, Args).AsObject;
        InjectFields(AProvider, Result, TypeObj);
        Exit;
      end;
    end;
  end;

  raise EArgumentException.CreateFmt('No compatible constructor found for %s using Hybrid Injection', [AClass.ClassName]);
end;

class function TActivator.CreateInstance(AProvider: IServiceProvider; AType: PTypeInfo): TValue;
var
  Context: TRttiContext;
  RttiType: TRttiType;
  ServiceType: TServiceType;
  ElementType: PTypeInfo;
  KeyType, ValueType: PTypeInfo;
  RegisteredImpl: TClass;
  InstanceObj: TObject;
  Intf: IInterface;
  ImplRtti: TRttiType;
  TypeName, ElementTypeName, ImplName: string;
  TmpType: TRttiType;
  AddM: TRttiMethod;
  TargetClass: TClass;
  BestConstructor: TRttiMethod;
  Method: TRttiMethod;
  InstanceVal: TValue;
  KeyName, ValName: string;
  CtorArgs: TArray<TValue>;
  J: Integer;
  BaseIntf: IInterface;
  ElemSuffix: string;
  N: string;
begin
  if AType = nil then
    Exit(TValue.Empty);

  if AType.Kind = tkClass then
    Exit(TValue.From(CreateInstance(AProvider, AType.TypeData.ClassType)));

  if AType.Kind = tkInterface then
  begin
    Context := GetRttiContext;
    try
      RttiType := Context.GetType(AType);
      
      // 1. Try explicit mapping
      if (RttiType <> nil) and FInterfaceDefaultImpl.TryGetValue(AType, RegisteredImpl) then
      begin
        InstanceObj := CreateInstance(AProvider, RegisteredImpl);
        if Supports(InstanceObj, IInterface, BaseIntf) then
          Result := MakeTypedInterfaceValue(BaseIntf, AType)
        else
          Result := TValue.From(InstanceObj);
        Exit;
      end;

      // 2. Fallback for Collections (IList/IEnumerable)
      // IMPORTANT: generic interface specializations can collide in interface-cast
      // paths in some Delphi RTTI scenarios. Prioritize collection instantiation
      // before DI lookup to keep IList<T>/IEnumerable<T> deterministic.
      if IsListType(AType) then
      begin
        ElementType := GetListElementType(AType);
        if ElementType = nil then
          raise EArgumentException.CreateFmt('TActivator: Could not determine element type for %s', [string(AType^.Name)]);

        TypeName := string(AType^.Name);
        ElementTypeName := string(ElementType^.Name);
        
        // Create implementation name from interface name (e.g., IList<T> -> TList<T>)
        ImplName := TypeName.Replace('IList<', 'TList<').Replace('IEnumerable<', 'TList<');
        
        ImplRtti := Context.FindType(ImplName);
        if ImplRtti = nil then
          ImplRtti := Context.FindType('Dext.Collections.' + ImplName);

        // Strategy B: TList<T>.Add is `inline`, so GetMethod('Add') returns nil.
        // Delphi stores generic specialization names with fully-qualified element types
        // e.g. 'TList<Dext.Collections.TFoo>', so use EndsWith on the element name.
        if ImplRtti = nil then
        begin
          ElemSuffix := ElementTypeName + '>';
          for TmpType in Context.GetTypes do
          begin
            if TmpType.IsInstance then
            begin
              N := TmpType.Name;
              if (N.StartsWith('TList<') or N.StartsWith('TSmartList<')) and
                 N.EndsWith(ElemSuffix) then
              begin
                ImplRtti := TmpType;
                Break;
              end;
            end;
          end;
        end;

        if (ImplRtti = nil) and (AType.Kind = tkClass) then
          ImplRtti := RttiType;

        if (ImplRtti <> nil) and (ImplRtti is TRttiInstanceType) then
        begin
            TargetClass := TRttiInstanceType(ImplRtti).MetaclassType;
            BestConstructor := nil;
            // Prefer parameterless constructor for collections
            for Method in ImplRtti.GetMethods do
              if Method.IsConstructor then
              begin
                if (Length(Method.GetParameters) = 0) then 
                begin 
                  BestConstructor := Method; 
                  Break; 
                end;
                if (BestConstructor = nil) and (Length(Method.GetParameters) = 1) and 
                   (Method.GetParameters[0].ParamType.TypeKind = tkEnumeration) then
                  BestConstructor := Method;
              end;

            if BestConstructor <> nil then
            begin
              if Length(BestConstructor.GetParameters) = 0 then 
                InstanceVal := BestConstructor.Invoke(TargetClass, [])
              else 
                InstanceVal := BestConstructor.Invoke(TargetClass, [TValue.FromOrdinal(TypeInfo(Boolean), 0)]); // OwnsObjects = False
                 
              if AType.Kind = tkInterface then
              begin
                BaseIntf := nil;
                if Supports(InstanceVal.AsObject, IInterface, BaseIntf) then
                  Result := MakeTypedInterfaceValue(BaseIntf, AType)
                else
                  Result := InstanceVal; // last resort: return as class
              end
              else 
                Result := InstanceVal;
              Exit;
            end;
        end;
      end;

      // 3. Fallback for IDictionary
      if IsDictionaryType(AType) then
      begin
        KeyType := GetDictionaryKeyType(AType);
        ValueType := GetDictionaryValueType(AType);
        if (KeyType <> nil) and (ValueType <> nil) then
        begin
          ImplRtti := nil;
          KeyName := string(KeyType^.Name);
          ValName := string(ValueType^.Name);
          
          for TmpType in Context.GetTypes do
            if TmpType.IsInstance and TmpType.Name.StartsWith('TDictionary<') then
            begin
               AddM := TmpType.GetMethod('Add');
               if Assigned(AddM) and (Length(AddM.GetParameters) = 2) then
                 if (AddM.GetParameters[0].ParamType.Handle = KeyType) and 
                    (AddM.GetParameters[1].ParamType.Handle = ValueType) then
                  begin
                    ImplRtti := TmpType;
                    Break;
                  end;
            end;

          if (ImplRtti <> nil) and (ImplRtti is TRttiInstanceType) then
          begin
            TargetClass := TRttiInstanceType(ImplRtti).MetaclassType;
            BestConstructor := nil;
            for Method in ImplRtti.GetMethods do
              if Method.IsConstructor then
              begin
                if Length(Method.GetParameters) = 0 then begin BestConstructor := Method; Break; end;
                if (BestConstructor = nil) and (Length(Method.GetParameters) <= 3) then 
                  BestConstructor := Method;
              end;

            if BestConstructor <> nil then
            begin
              SetLength(CtorArgs, Length(BestConstructor.GetParameters));
              for J := 0 to High(CtorArgs) do CtorArgs[J] := TValue.Empty; 
              
              InstanceVal := BestConstructor.Invoke(TargetClass, CtorArgs);
              if AType.Kind = tkInterface then
              begin
                BaseIntf := nil;
                if Supports(InstanceVal.AsObject, IInterface, BaseIntf) then
                  Result := MakeTypedInterfaceValue(BaseIntf, AType)
                else 
                  Result := InstanceVal;
              end
              else 
                Result := InstanceVal;
              Exit;
            end;
          end;
        end;
      end;

      // 4. Try to resolve via DI (non-collection interfaces)
      if (AProvider <> nil) and (RttiType <> nil) then
      begin
        ServiceType := TServiceType.FromInterface(AType);
        Intf := AProvider.GetServiceAsInterface(ServiceType);
        if Intf <> nil then
        begin
          Result := MakeTypedInterfaceValue(Intf, AType);
          Exit;
        end;
      end;
      
      raise EArgumentException.CreateFmt('TActivator: Cannot find a suitable implementation for interface %s. ' +
        'Ensure the implementation is registered in DI or use TArray<T> for automatic RTTI support in DTOs.', [AType.NameFld.ToString]);
    finally
    ;
    end;
  end;

  raise EArgumentException.CreateFmt('TActivator: Unsupported type for instantiation: %s', [AType.NameFld.ToString]);
end;

class function TActivator.IsListType(AType: PTypeInfo): Boolean;
begin
  Result := TReflection.IsListType(AType);
end;

class function TActivator.IsDictionaryType(AType: PTypeInfo): Boolean;
begin
  Result := TReflection.IsDictionaryType(AType);
end;

class function TActivator.GetListElementType(AType: PTypeInfo): PTypeInfo;
begin
  Result := TReflection.GetListElementType(AType);
end;

class function TActivator.GetDictionaryKeyType(AType: PTypeInfo): PTypeInfo;
begin
  Result := TReflection.GetDictionaryKeyType(AType);
end;

class function TActivator.GetDictionaryValueType(AType: PTypeInfo): PTypeInfo;
begin
  Result := TReflection.GetDictionaryValueType(AType);
end;

class function TActivator.CreateInstance<T>: T;
begin
  Result := T(CreateInstance<T>([]));
end;

class function TActivator.CreateInstance<T>(const AArgs: array of TValue): T;
var
  TypeObj: TRttiType;
  TI: PTypeInfo;
begin
  TI := TypeInfo(T);
  if TI = nil then
    raise EArgumentException.Create('Type information not found for T');

  TypeObj := TReflection.Context.GetType(TI);
  if (TypeObj <> nil) and (TypeObj.IsInstance) then
    Result := T(CreateInstance(TypeObj.AsInstance.MetaclassType, AArgs))
  else
    raise EArgumentException.Create('Type parameter T must be a class type');
end;

end.
