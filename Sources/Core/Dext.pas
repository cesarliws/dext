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
unit Dext;

interface

uses
  System.SysUtils,
  System.Classes,
  System.TypInfo,
  System.Generics.Collections,
  Dext.Configuration.Interfaces,
  Dext.Core.Activator,
  Dext.Core.CancellationToken,
  Dext.Core.Memory,
  Dext.DI.Interfaces,
  Dext.Options,
  Dext.Options.Extensions,
  Dext.Threading.Async,
  Dext.Hosting.BackgroundService,
  Dext.Validation,
  // Specifications
  Dext.Specifications.Interfaces,
  Dext.Specifications.Expression,
  Dext.Specifications.Fluent,
  Dext.Specifications.Types;

type
  // ===========================================================================
  // 🏷️ Aliases for Common Types (Core Facade)
  // ===========================================================================
  
  // DI
  IServiceCollection = Dext.DI.Interfaces.IServiceCollection;
  IServiceProvider = Dext.DI.Interfaces.IServiceProvider;
  TServiceType = Dext.DI.Interfaces.TServiceType;
  
  // Configuration
  IConfiguration = Dext.Configuration.Interfaces.IConfiguration;
  IConfigurationSection = Dext.Configuration.Interfaces.IConfigurationSection;
 
  // Validation
  RequiredAttribute = Dext.Validation.RequiredAttribute;
  StringLengthAttribute = Dext.Validation.StringLengthAttribute;
  
  // Specifications / Expressions
  IExpression = Dext.Specifications.Interfaces.IExpression;
  TBinaryOperator = Dext.Specifications.Types.TBinaryOperator;
  TLogicalOperator = Dext.Specifications.Types.TLogicalOperator;
  
  // No need to alias Prop/Asc/Desc as they are functions, but we can re-export them if needed.
  // Delphi doesn't support "function alias" easily in type section, 
  // but we can rely on the uses clause if the user uses Dext.
  // Actually, Dext.pas users will not see functions from Implementation uses.
  // We should add them to Interface uses? 
  // The units above ARE in Interface uses. So `Prop` is available if `Dext.Specifications.Expression` is in Interface uses.
  // It is there now.
  
  // Async
  TAsyncTask = Dext.Threading.Async.TAsyncTask;
  IAsyncTask = Dext.Threading.Async.IAsyncTask;

  // Memory Management
  IDeferred = Dext.Core.Memory.IDeferred;

  ICancellationToken = Dext.Core.CancellationToken.ICancellationToken;
  
  TBackgroundService = Dext.Hosting.BackgroundService.TBackgroundService;

  /// <summary>
  ///   Smart pointer record that automatically frees the object when it goes out of scope.
  ///   Uses an internal interface to support ARC (Automatic Reference Counting).
  /// </summary>
  Auto<T: class> = record
  private
    FLifetime: Dext.Core.Memory.ILifetime<T>;
    function GetInstance: T;
  public
    constructor Create(AValue: T);
    
    /// <summary>
    ///   Access the underlying object.
    /// </summary>
    property Instance: T read GetInstance;

    /// <summary>
    ///   Implicitly converts the object to Auto&lt;T&gt;.
    /// </summary>
    class operator Implicit(const AValue: T): Auto<T>;
    
    /// <summary>
    ///   Implicitly converts Auto&lt;T&gt; to the object.
    /// </summary>
    class operator Implicit(const AAuto: Auto<T>): T;
  end;

  Auto = class abstract
  public
    class function Create<T: class>: Auto<T>;
  end;

  /// <summary>
  ///   Factory for creating interface-based objects with automatic reference counting (ARC).
  /// </summary>
  Factory = class abstract
  public
    /// <summary>
    ///   Creates an instance of T using its parameterless constructor and returns as interface I.
    /// </summary>
    class function Create<T: class, constructor; I: IInterface>: I; overload;
    
    /// <summary>
    ///   Wraps an existing instance and returns as interface I.
    /// </summary>
    class function Create<I: IInterface>(Instance: TInterfacedObject): I; overload;
  end;

  TActivator = Dext.Core.Activator.TActivator;

  // ===========================================================================
  // 🛠️ Fluent Helpers & Wrappers
  // ===========================================================================

  /// <summary>
  ///   Helper for TDextServices to add framework features.
  /// </summary>
  TDextServicesHelper = record helper for TDextServices
  public
    /// <summary>
    ///   Configures a settings class (IOptions&lt;T&gt;) from the root configuration.
    /// </summary>
    function Configure<T: class, constructor>(Configuration: IConfiguration): TDextServices; overload;
    
    /// <summary>
    ///   Configures a settings class (IOptions&lt;T&gt;) from a specific configuration section.
    /// </summary>
    function Configure<T: class, constructor>(Section: IConfigurationSection): TDextServices; overload;
  end;

/// <summary>
///   Schedules an action to be executed when the returned interface goes out of scope.
/// </summary>
function Defer(AAction: TProc): IDeferred; overload;
function Defer(const AActions: array of TProc): TArray<IDeferred>; overload;

implementation

{ Auto<T> }

constructor Auto<T>.Create(AValue: T);
begin
  if AValue <> nil then
    FLifetime := Dext.Core.Memory.TLifetime<T>.Create(AValue)
  else
    FLifetime := nil;
end;

function Auto<T>.GetInstance: T;
begin
  if FLifetime <> nil then
    Result := FLifetime.GetValue
  else
    Result := nil;
end;

class operator Auto<T>.Implicit(const AValue: T): Auto<T>;
begin
  Result := Auto<T>.Create(AValue);
end;

class operator Auto<T>.Implicit(const AAuto: Auto<T>): T;
begin
  Result := AAuto.Instance;
end;

{ TDextServicesHelper }

function TDextServicesHelper.Configure<T>(Configuration: IConfiguration): TDextServices;
begin
  TOptionsServiceCollectionExtensions.Configure<T>(Self.Unwrap, Configuration);
  Result := Self;
end;

function TDextServicesHelper.Configure<T>(Section: IConfigurationSection): TDextServices;
begin
  TOptionsServiceCollectionExtensions.Configure<T>(Self.Unwrap, Section);
  Result := Self;
end;

function Defer(AAction: TProc): IDeferred;
begin
  Result := Dext.Core.Memory.TDeferredAction.Create(AAction);
end;

function Defer(const AActions: array of TProc): TArray<IDeferred>;
begin
  SetLength(Result, Length(AActions));
  for var i := Low(AActions) to High(AActions) do
    Result[i] := Dext.Core.Memory.TDeferredAction.Create(AActions[i]);
end;

{ Auto }

class function Auto.Create<T>: Auto<T>;
begin
  Result := TActivator.CreateInstance<T>([]);
end;

{ Factory }

class function Factory.Create<T, I>: I;
var
  Instance: TObject;
begin
  Instance := TActivator.CreateInstance<T>([]);
  if not Supports(Instance, GetTypeData(TypeInfo(I))^.Guid, Result) then
  begin
    Instance.Free;
    raise Exception.CreateFmt('Class %s does not implement interface %s', 
      [T.ClassName, GetTypeName(TypeInfo(I))]);
  end;
end;

class function Factory.Create<I>(Instance: TInterfacedObject): I;
begin
  if not Supports(Instance, GetTypeData(TypeInfo(I))^.Guid, Result) then
  begin
    Instance.Free;
    raise Exception.CreateFmt('Instance does not implement interface %s', 
      [GetTypeName(TypeInfo(I))]);
  end;
end;

end.
