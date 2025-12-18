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
  TOptionsServiceCollectionExtensions = class
  public
    class procedure AddOptions(Services: IServiceCollection);
    class procedure Configure<T: class, constructor>(Services: IServiceCollection; Configuration: IConfiguration); overload;
    class procedure Configure<T: class, constructor>(Services: IServiceCollection; Section: IConfigurationSection); overload;
  end;

implementation

uses
  Dext.Configuration.Binder;

{ TOptionsServiceCollectionExtensions }

class procedure TOptionsServiceCollectionExtensions.AddOptions(Services: IServiceCollection);
begin
end;

class procedure TOptionsServiceCollectionExtensions.Configure<T>(Services: IServiceCollection; Configuration: IConfiguration);
begin
  Services.AddSingleton(
    TServiceType.FromInterface(GetTypeData(TypeInfo(IOptions<T>))^.Guid),
    TClass(TOptions<T>),
    function(Provider: IServiceProvider): TObject
    begin
      var Value: T := TConfigurationBinder.Bind<T>(Configuration);
      Result := TOptions<T>.Create(Value);
    end
  );
end;

class procedure TOptionsServiceCollectionExtensions.Configure<T>(Services: IServiceCollection; Section: IConfigurationSection);
begin
  Services.AddSingleton(
    TServiceType.FromInterface(GetTypeData(TypeInfo(IOptions<T>))^.Guid),
    TClass(TOptions<T>),
    function(Provider: IServiceProvider): TObject
    begin
      var Value: T := TConfigurationBinder.Bind<T>(Section);
      Result := TOptions<T>.Create(Value);
    end
  );
end;

end.

