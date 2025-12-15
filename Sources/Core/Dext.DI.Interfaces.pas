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
unit Dext.DI.Interfaces;

interface

uses
  System.SysUtils,
  System.TypInfo;

type
  IServiceCollection = interface;
  IServiceProvider = interface;

  TServiceLifetime = (Singleton, Transient, Scoped);

  EDextDIException = class(Exception);

  // Type to identify services (can be TClass or TGUID for interfaces)
  TServiceType = record
  private
    FTypeInfo: Pointer; // Used for Interface TypeInfo (or legacy)
    FClass: TClass;     // Explicitly store class reference
    FGuid: TGUID;       // Used for Interface GUID
    FIsInterface: Boolean;
  public
    // Constructors
    class function FromClass(AClass: TClass): TServiceType; overload; static;
    class function FromClass(ATypeInfo: PTypeInfo): TServiceType; overload; static;
    class function FromInterface(const AGuid: TGUID): TServiceType; overload; static;
    class function FromInterface(ATypeInfo: PTypeInfo): TServiceType; overload; static;

    // Checks
    function IsClass: Boolean;
    function IsInterface: Boolean;
    
    // Accessors
    function AsClass: TClass;
    function AsInterface: TGUID;
    function ToString: string;

    // Equality
    class operator Equal(const A, B: TServiceType): Boolean;
    
    // Implicit Conversion
    class operator Implicit(A: TClass): TServiceType;
    class operator Implicit(A: PTypeInfo): TServiceType;
  end;

  IServiceScope = interface
    ['{F2E7D3F4-9C6E-4B8A-8D2C-7F5A1B3E8D9F}']
    function GetServiceProvider: IServiceProvider;
    property ServiceProvider: IServiceProvider read GetServiceProvider;
  end;

  IServiceCollection = interface
    ['{A1F8C5D2-8B4E-4A7D-9C3B-6E8F4A2D1C7A}']

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

  IServiceProvider = interface
    ['{B2E7D3F4-9C6E-4B8A-8D2C-7F5A1B3E8D9F}']
    function GetService(const AServiceType: TServiceType): TObject;
    function GetServiceAsInterface(const AServiceType: TServiceType): IInterface;
    function GetRequiredService(const AServiceType: TServiceType): TObject;
    function CreateScope: IServiceScope;
  end;

  /// <summary>
  ///   Wrapper for IServiceCollection to provide Generic Extensions and Fluent API.
  /// </summary>
  TDextServices = record
  private
    FServices: IServiceCollection;
  public
    constructor Create(AServices: IServiceCollection);
    function Unwrap: IServiceCollection;
    class operator Implicit(const A: TDextServices): IServiceCollection;

    // Generic Overloads
    function AddSingleton<TService: IInterface; TImplementation: class>(const AFactory: TFunc<IServiceProvider, TObject> = nil): TDextServices; overload;
    function AddTransient<TService: IInterface; TImplementation: class>(const AFactory: TFunc<IServiceProvider, TObject> = nil): TDextServices; overload;
    function AddScoped<TService: IInterface; TImplementation: class>(const AFactory: TFunc<IServiceProvider, TObject> = nil): TDextServices; overload;

    // Non-generic forwarding
    function AddSingleton(const AServiceType: TServiceType; const AImplementationClass: TClass; const AFactory: TFunc<IServiceProvider, TObject> = nil): TDextServices; overload;
    function AddTransient(const AServiceType: TServiceType; const AImplementationClass: TClass; const AFactory: TFunc<IServiceProvider, TObject> = nil): TDextServices; overload;
    function AddScoped(const AServiceType: TServiceType; const AImplementationClass: TClass; const AFactory: TFunc<IServiceProvider, TObject> = nil): TDextServices; overload;

    function BuildServiceProvider: IServiceProvider;
  end;

  TDextDIFactory = class
  public
    class function CreateServiceCollection: IServiceCollection;
  end;

implementation

{ TServiceType }

{ TServiceType }

class function TServiceType.FromClass(AClass: TClass): TServiceType;
begin
  Result.FIsInterface := False;
  Result.FClass := AClass;
  Result.FTypeInfo := AClass.ClassInfo; // Keep it if available, but optional
end;

class function TServiceType.FromClass(ATypeInfo: PTypeInfo): TServiceType;
begin
  if (ATypeInfo = nil) or (ATypeInfo.Kind <> tkClass) then
    raise EDextDIException.Create('TypeInfo must be for a class');

  Result.FIsInterface := False;
  Result.FClass := GetTypeData(ATypeInfo)^.ClassType;
  Result.FTypeInfo := ATypeInfo;
end;

class function TServiceType.FromInterface(const AGuid: TGUID): TServiceType;
begin
  Result.FGuid := AGuid;
  Result.FTypeInfo := nil;
  Result.FClass := nil;
  Result.FIsInterface := True;
end;

class function TServiceType.FromInterface(ATypeInfo: PTypeInfo): TServiceType;
var
  LTypeData: PTypeData;
begin
  if (ATypeInfo = nil) or (ATypeInfo.Kind <> tkInterface) then
    raise EDextDIException.Create('TypeInfo must be for an interface');

  LTypeData := GetTypeData(ATypeInfo);
  Result.FGuid := LTypeData.Guid;
  Result.FTypeInfo := ATypeInfo;
  Result.FClass := nil;
  Result.FIsInterface := True;
end;

function TServiceType.IsClass: Boolean;
begin
  Result := not FIsInterface;
end;

function TServiceType.IsInterface: Boolean;
begin
  Result := FIsInterface;
end;

function TServiceType.AsClass: TClass;
begin
  if not FIsInterface then
  begin
    if FClass <> nil then
      Result := FClass
    else if FTypeInfo <> nil then
    begin
       // Fallback if FClass was somehow not set but TypeInfo was
       var LTypeData := GetTypeData(FTypeInfo);
       if Assigned(LTypeData) then
         Result := LTypeData^.ClassType
       else
         raise EDextDIException.Create('Invalid class type info');
    end
    else
       raise EDextDIException.Create('Class TypeInfo is nil and FClass is nil');
  end
  else
    raise EDextDIException.Create('Service type is an interface, not a class');
end;

function TServiceType.AsInterface: TGUID;
begin
  if FIsInterface then
    Result := FGuid
  else
    raise EDextDIException.Create('Service type is a class, not an interface');
end;

function TServiceType.ToString: string;
begin
  if FIsInterface then
    Result := 'I:' + GUIDToString(FGuid)
  else
    Result := 'C:' + AsClass.ClassName;
end;

class operator TServiceType.Equal(const A, B: TServiceType): Boolean;
begin
  if A.FIsInterface <> B.FIsInterface then
    Exit(False);

  if A.FIsInterface then
    Result := IsEqualGUID(A.FGuid, B.FGuid)
  else
    Result := A.AsClass = B.AsClass;
end;

class operator TServiceType.Implicit(A: TClass): TServiceType;
begin
  Result := TServiceType.FromClass(A);
end;

class operator TServiceType.Implicit(A: PTypeInfo): TServiceType;
begin
  if A.Kind = tkInterface then
    Result := TServiceType.FromInterface(A)
  else
    Result := TServiceType.FromClass(A);
end;

{ TDextServices }

constructor TDextServices.Create(AServices: IServiceCollection);
begin
  FServices := AServices;
end;

function TDextServices.Unwrap: IServiceCollection;
begin
  Result := FServices;
end;

class operator TDextServices.Implicit(const A: TDextServices): IServiceCollection;
begin
  Result := A.FServices;
end;

function TDextServices.AddSingleton<TService, TImplementation>(const AFactory: TFunc<IServiceProvider, TObject>): TDextServices;
var
  Guid: TGUID;
begin
  Guid := GetTypeData(TypeInfo(TService))^.Guid;
  FServices.AddSingleton(TServiceType.FromInterface(Guid), TImplementation, AFactory);
  Result := Self;
end;

function TDextServices.AddTransient<TService, TImplementation>(const AFactory: TFunc<IServiceProvider, TObject>): TDextServices;
var
  Guid: TGUID;
begin
  Guid := GetTypeData(TypeInfo(TService))^.Guid;
  FServices.AddTransient(TServiceType.FromInterface(Guid), TImplementation, AFactory);
  Result := Self;
end;

function TDextServices.AddScoped<TService, TImplementation>(const AFactory: TFunc<IServiceProvider, TObject>): TDextServices;
var
  Guid: TGUID;
begin
  Guid := GetTypeData(TypeInfo(TService))^.Guid;
  FServices.AddScoped(TServiceType.FromInterface(Guid), TImplementation, AFactory);
  Result := Self;
end;

function TDextServices.AddSingleton(const AServiceType: TServiceType; const AImplementationClass: TClass; const AFactory: TFunc<IServiceProvider, TObject>): TDextServices;
begin
  FServices.AddSingleton(AServiceType, AImplementationClass, AFactory);
  Result := Self;
end;

function TDextServices.AddTransient(const AServiceType: TServiceType; const AImplementationClass: TClass; const AFactory: TFunc<IServiceProvider, TObject>): TDextServices;
begin
  FServices.AddTransient(AServiceType, AImplementationClass, AFactory);
  Result := Self;
end;

function TDextServices.AddScoped(const AServiceType: TServiceType; const AImplementationClass: TClass; const AFactory: TFunc<IServiceProvider, TObject>): TDextServices;
begin
  FServices.AddScoped(AServiceType, AImplementationClass, AFactory);
  Result := Self;
end;

function TDextServices.BuildServiceProvider: IServiceProvider;
begin
  Result := FServices.BuildServiceProvider;
end;

{ TDextDIFactory }

class function TDextDIFactory.CreateServiceCollection: IServiceCollection;
begin
  Result := nil;
end;

end.

