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
  System.SysUtils,
  System.TypInfo,
  Dext.DI.Interfaces;

type
  TActivator = class
  public
    // 1. Manual Instantiation (No DI)
    // Uses only provided arguments. Must match exactly.
    class function CreateInstance(AClass: TClass; const AArgs: array of TValue): TObject; overload;

    // 2. Pure DI Instantiation (No Manual Args)
    // Uses DI container to resolve all dependencies.
    // Uses "Greedy" strategy: prefers constructor with MOST resolvable parameters.
    class function CreateInstance(AProvider: IServiceProvider; AClass: TClass): TObject; overload;

    // 3. Hybrid Instantiation (Manual Args + DI)
    // Uses provided arguments for the first N parameters, then DI for the rest.
    class function CreateInstance(AProvider: IServiceProvider; AClass: TClass; const AArgs: array of TValue): TObject; overload;

    // Generic Helper
    class function CreateInstance<T: class>(const AArgs: array of TValue): T; overload;
    class function CreateInstance<T: class>: T; overload;
  end;

implementation

{ TActivator }

// 1. Manual Instantiation
class function TActivator.CreateInstance(AClass: TClass; const AArgs: array of TValue): TObject;
var
  Context: TRttiContext;
  TypeObj: TRttiType;
  Method: TRttiMethod;
  Params: TArray<TRttiParameter>;
  Args: TArray<TValue>;
  I: Integer;
  Matched: Boolean;
begin

  Context := TRttiContext.Create;
  try
    TypeObj := Context.GetType(AClass);
    if TypeObj = nil then
      raise EArgumentException.CreateFmt('RTTI information not found for class %s', [AClass.ClassName]);

    for Method in TypeObj.GetMethods do
    begin
      if Method.IsConstructor then
      begin
        Params := Method.GetParameters;
        if Length(Params) = Length(AArgs) then
        begin
          Matched := True;
          for I := 0 to High(Params) do
          begin
            // Skip check if argument is empty/nil (TValue.Empty)
            if AArgs[I].IsEmpty then Continue;

            // Check for type compatibility
            if AArgs[I].Kind <> Params[I].ParamType.TypeKind then
            begin
              // Allow Interface <-> Interface
              if (AArgs[I].Kind = tkInterface) and (Params[I].ParamType.TypeKind = tkInterface) then
                Continue;
              
              // Allow Class <-> Class
              if (AArgs[I].Kind = tkClass) and (Params[I].ParamType.TypeKind = tkClass) then
                Continue;

              Matched := False;
              Break;
            end;
            
            // For records and other exact types, check TypeInfo
            if (AArgs[I].Kind = tkRecord) and (AArgs[I].TypeInfo <> Params[I].ParamType.Handle) then
            begin
               Matched := False;
               Break;
            end;
          end;

          if Matched then
          begin
            SetLength(Args, Length(AArgs));
            for I := 0 to High(AArgs) do
              Args[I] := AArgs[I];

            // Invoke constructor on the class reference
            Result := Method.Invoke(AClass, Args).AsObject;
            Exit;
          end;
        end;
      end;
    end;

    raise EArgumentException.CreateFmt('No compatible constructor found for class %s', [AClass.ClassName]);
  finally
    Context.Free;
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
  ParamType: TRttiType;
  ServiceType: TServiceType;
  ResolvedService: TValue;
  
  // Best match tracking
  BestMethod: TRttiMethod;
  BestArgs: TArray<TValue>;
  MaxParams: Integer;
begin
  Context := TRttiContext.Create;
  try
    TypeObj := Context.GetType(AClass);
    if TypeObj = nil then
      raise EArgumentException.CreateFmt('RTTI not found for %s', [AClass.ClassName]);

    BestMethod := nil;
    MaxParams := -1;

    for Method in TypeObj.GetMethods do
    begin
      if Method.IsConstructor then
      begin
        Params := Method.GetParameters;
        SetLength(Args, Length(Params));
        Matched := True;

        for I := 0 to High(Params) do
        begin
          // Resolve from DI
          ParamType := Params[I].ParamType;
          ResolvedService := TValue.Empty;

          if ParamType.TypeKind = tkInterface then
          begin
             var Guid := TRttiInterfaceType(ParamType).GUID;
             ServiceType := TServiceType.FromInterface(Guid);
             var Intf := AProvider.GetServiceAsInterface(ServiceType);
             if Intf <> nil then
               TValue.Make(@Intf, ParamType.Handle, ResolvedService);
          end
          else if ParamType.TypeKind = tkClass then
          begin
             var Cls := TRttiInstanceType(ParamType).MetaclassType;
             ServiceType := TServiceType.FromClass(Cls);
             var Obj := AProvider.GetService(ServiceType);
             if Obj <> nil then
               ResolvedService := TValue.From(Obj);
          end;

          if not ResolvedService.IsEmpty then
            Args[I] := ResolvedService
          else
          begin
            // Dependency not found -> Match failed
            Matched := False;
            Break;
          end;
        end;

        if Matched then
        begin
          // Greedy selection: prefer constructor with MORE parameters
          if Length(Params) > MaxParams then
          begin
            MaxParams := Length(Params);
            BestMethod := Method;
            BestArgs := Args;
          end;
        end;
      end;
    end;

    if BestMethod <> nil then
      Result := BestMethod.Invoke(AClass, BestArgs).AsObject
    else
    begin
      // ERROR: No suitable constructor found (or dependencies missing)
      // Do NOT fallback to TObject.Create arbitrarily.
      raise EArgumentException.CreateFmt('TActivator: No satisfiable constructor found for %s. Check if all dependencies are registered.', [AClass.ClassName]);
    end;
  finally
    Context.Free;
  end;
end;

// 3. Hybrid Instantiation (Manual Args + DI)
class function TActivator.CreateInstance(AProvider: IServiceProvider; AClass: TClass; const AArgs: array of TValue): TObject;
var
  Context: TRttiContext;
  TypeObj: TRttiType;
  Method: TRttiMethod;
  Params: TArray<TRttiParameter>;
  Args: TArray<TValue>;
  I: Integer;
  Matched: Boolean;
  ParamType: TRttiType;
  ServiceType: TServiceType;
  ResolvedService: TValue;
begin
  // If no args provided, delegate to Pure DI overload
  if Length(AArgs) = 0 then
    Exit(CreateInstance(AProvider, AClass));

  Context := TRttiContext.Create;
  try
    TypeObj := Context.GetType(AClass);
    if TypeObj = nil then
      raise EArgumentException.CreateFmt('RTTI not found for %s', [AClass.ClassName]);

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
          ParamType := Params[I].ParamType;
          ResolvedService := TValue.Empty;

          if ParamType.TypeKind = tkInterface then
          begin
             var Guid := TRttiInterfaceType(ParamType).GUID;
             ServiceType := TServiceType.FromInterface(Guid);
             var Intf := AProvider.GetServiceAsInterface(ServiceType);
             if Intf <> nil then
               TValue.Make(@Intf, ParamType.Handle, ResolvedService);
          end
          else if ParamType.TypeKind = tkClass then
          begin
             var Cls := TRttiInstanceType(ParamType).MetaclassType;
             ServiceType := TServiceType.FromClass(Cls);
             var Obj := AProvider.GetService(ServiceType);
             if Obj <> nil then
               ResolvedService := TValue.From(Obj);
          end;

          if not ResolvedService.IsEmpty then
            Args[I] := ResolvedService
          else
          begin
            // Not found and not in AArgs -> Match failed
            Matched := False;
            Break;
          end;
        end;

        if Matched then
        begin
          Result := Method.Invoke(AClass, Args).AsObject;
          Exit;
        end;
      end;
    end;

    raise EArgumentException.CreateFmt('No compatible constructor found for %s using Hybrid Injection', [AClass.ClassName]);
  finally
    Context.Free;
  end;
end;

class function TActivator.CreateInstance<T>: T;
begin
  Result := T(CreateInstance<T>([]));
end;

class function TActivator.CreateInstance<T>(const AArgs: array of TValue): T;
var
  Ctx: TRttiContext;
  TypeObj: TRttiType;
begin
  Ctx := TRttiContext.Create;
  try
    TypeObj := Ctx.GetType(TypeInfo(T));
    if (TypeObj <> nil) and (TypeObj.IsInstance) then
      Result := T(CreateInstance(TypeObj.AsInstance.MetaclassType, AArgs))
    else
      raise EArgumentException.Create('Type parameter T must be a class type');
  finally
    Ctx.Free;
  end;
end;

end.

