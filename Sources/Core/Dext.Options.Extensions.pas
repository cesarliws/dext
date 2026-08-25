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
unit Dext.Options.Extensions;

interface

uses
  System.SysUtils,
  System.TypInfo,
  Dext.DI.Interfaces,
  Dext.Configuration.Interfaces,
  Dext.Options;

type
  /// <summary>
  ///   Extension methods for IServiceCollection to register and configure strongly-typed options.
  /// </summary>
  TOptionsServiceCollectionExtensions = class
  public
    /// <summary>Registers the options infrastructure (reserved for future shared services).</summary>
    class procedure AddOptions(Services: IServiceCollection);

    /// <summary>Binds <typeparamref name="T"/> from the root configuration.</summary>
    class procedure Configure<T: class, constructor>(Services: IServiceCollection;
      Configuration: IConfiguration); overload;

    /// <summary>
    ///   Binds <typeparamref name="T"/> from the root configuration with a validator.
    ///   When <paramref name="AValidateOnStart"/> is True, validation runs during host
    ///   service-provider build (before listening), raising <see cref="EConfigurationException"/> on failure.
    /// </summary>
    class procedure Configure<T: class, constructor>(Services: IServiceCollection;
      Configuration: IConfiguration; const Validator: TFunc<T, string>;
      AValidateOnStart: Boolean = False); overload;

    /// <summary>Binds <typeparamref name="T"/> from a configuration section.</summary>
    class procedure Configure<T: class, constructor>(Services: IServiceCollection;
      Section: IConfigurationSection); overload;

    /// <summary>
    ///   Binds <typeparamref name="T"/> from a section with a validator.
    ///   When <paramref name="AValidateOnStart"/> is True, validation runs at host build time.
    /// </summary>
    class procedure Configure<T: class, constructor>(Services: IServiceCollection;
      Section: IConfigurationSection; const Validator: TFunc<T, string>;
      AValidateOnStart: Boolean = False); overload;

    /// <summary>
    ///   Resolves every options registration marked with ValidateOnStart.
    ///   Called automatically by <c>TWebApplication.BuildServices</c>.
    /// </summary>
    class procedure ValidateOptionsOnStart(const AProvider: IServiceProvider);
  end;

/// <summary>
///   Registers an action to resolve options eagerly at host build time.
///   Declared in the interface so generic Configure&lt;T&gt; methods may call it (E2506).
/// </summary>
procedure RegisterOptionsValidateOnStart(const AAction: TProc<IServiceProvider>);

implementation

uses
  Dext.Collections,
  Dext.Configuration.Binder;

type
  TOptionsValidateOnStartRegistry = class
  private
    class var FActions: IList<TProc<IServiceProvider>>;
    class constructor Create;
  public
    class procedure Register(const AAction: TProc<IServiceProvider>);
    class procedure Run(const AProvider: IServiceProvider);
  end;

{ TOptionsValidateOnStartRegistry }

class constructor TOptionsValidateOnStartRegistry.Create;
begin
  FActions := TCollections.CreateList<TProc<IServiceProvider>>;
end;

class procedure TOptionsValidateOnStartRegistry.Register(
  const AAction: TProc<IServiceProvider>);
begin
  if Assigned(AAction) then
    FActions.Add(AAction);
end;

class procedure TOptionsValidateOnStartRegistry.Run(const AProvider: IServiceProvider);
var
  Action: TProc<IServiceProvider>;
begin
  if AProvider = nil then
    Exit;
  for Action in FActions do
    Action(AProvider);
end;

procedure RegisterOptionsValidateOnStart(const AAction: TProc<IServiceProvider>);
begin
  TOptionsValidateOnStartRegistry.Register(AAction);
end;

{ TOptionsServiceCollectionExtensions }

class procedure TOptionsServiceCollectionExtensions.AddOptions(Services: IServiceCollection);
begin
end;

class procedure TOptionsServiceCollectionExtensions.Configure<T>(Services: IServiceCollection;
  Configuration: IConfiguration);
begin
  Services.AddSingleton(
    TServiceType.FromInterface(TypeInfo(IOptions<T>)),
    TClass(TOptions<T>),
    function(Provider: IServiceProvider): TObject
    var
      Value: T;
    begin
      Value := TConfigurationBinder.Bind<T>(Configuration);
      Result := TOptions<T>.Create(Value);
    end
  );
end;

class procedure TOptionsServiceCollectionExtensions.Configure<T>(Services: IServiceCollection;
  Configuration: IConfiguration; const Validator: TFunc<T, string>;
  AValidateOnStart: Boolean);
begin
  Services.AddSingleton(
    TServiceType.FromInterface(TypeInfo(IOptions<T>)),
    TClass(TOptions<T>),
    function(Provider: IServiceProvider): TObject
    var
      Value: T;
      Error: string;
    begin
      Value := TConfigurationBinder.Bind<T>(Configuration);
      if Assigned(Validator) then
      begin
        Error := Validator(Value);
        if Error.Trim <> '' then
        begin
          Value.Free;
          raise EConfigurationException.CreateFmt(
            'Options validation failed for %s: %s',
            [String(PTypeInfo(TypeInfo(T)).Name), Error]);
        end;
      end;
      Result := TOptions<T>.Create(Value);
    end
  );

  if AValidateOnStart then
  begin
    RegisterOptionsValidateOnStart(
      procedure(Provider: IServiceProvider)
      var
        Options: IInterface;
      begin
        Options := Provider.GetServiceAsInterface(
          TServiceType.FromInterface(TypeInfo(IOptions<T>)));
      end);
  end;
end;

class procedure TOptionsServiceCollectionExtensions.Configure<T>(Services: IServiceCollection;
  Section: IConfigurationSection);
begin
  Services.AddSingleton(
    TServiceType.FromInterface(TypeInfo(IOptions<T>)),
    TClass(TOptions<T>),
    function(Provider: IServiceProvider): TObject
    var
      Value: T;
    begin
      Value := TConfigurationBinder.Bind<T>(Section);
      Result := TOptions<T>.Create(Value);
    end
  );
end;

class procedure TOptionsServiceCollectionExtensions.Configure<T>(Services: IServiceCollection;
  Section: IConfigurationSection; const Validator: TFunc<T, string>;
  AValidateOnStart: Boolean);
begin
  Services.AddSingleton(
    TServiceType.FromInterface(TypeInfo(IOptions<T>)),
    TClass(TOptions<T>),
    function(Provider: IServiceProvider): TObject
    var
      Value: T;
      Error: string;
    begin
      Value := TConfigurationBinder.Bind<T>(Section);
      if Assigned(Validator) then
      begin
        Error := Validator(Value);
        if Error.Trim <> '' then
        begin
          Value.Free;
          raise EConfigurationException.CreateFmt(
            'Options validation failed for %s: %s',
            [String(PTypeInfo(TypeInfo(T)).Name), Error]);
        end;
      end;
      Result := TOptions<T>.Create(Value);
    end
  );

  if AValidateOnStart then
  begin
    RegisterOptionsValidateOnStart(
      procedure(Provider: IServiceProvider)
      var
        Options: IInterface;
      begin
        Options := Provider.GetServiceAsInterface(
          TServiceType.FromInterface(TypeInfo(IOptions<T>)));
      end);
  end;
end;

class procedure TOptionsServiceCollectionExtensions.ValidateOptionsOnStart(
  const AProvider: IServiceProvider);
begin
  TOptionsValidateOnStartRegistry.Run(AProvider);
end;

end.
