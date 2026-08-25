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
unit Dext.Configuration.Interfaces;

interface

uses
  System.SysUtils,
  System.Classes,
  Dext.Collections,
  Dext.Collections.Dict;

type
  EConfigurationException = class(Exception);
  IConfigurationSection = interface;
  IConfigurationBuilder = interface;

  /// <summary>
  ///   Represents a set of key/value application configuration properties.
  /// </summary>
  IConfiguration = interface
    ['{A1B2C3D4-E5F6-4789-A1B2-C3D4E5F67890}']
    function GetItem(const Key: string): string;
    procedure SetItem(const Key, Value: string);
    function GetSection(const Key: string): IConfigurationSection;
    function GetChildren: TArray<IConfigurationSection>;
    
    property Item[const Key: string]: string read GetItem write SetItem; default;
  end;

  /// <summary>
  ///   Represents a section of application configuration values.
  /// </summary>
  IConfigurationSection = interface(IConfiguration)
    ['{B2C3D4E5-F6A7-4890-B2C3-D4E5F6789012}']
    function GetKey: string;
    function GetPath: string;
    function GetValue: string;
    procedure SetValue(const Value: string);
    
    property Key: string read GetKey;
    property Path: string read GetPath;
    property Value: string read GetValue write SetValue;
  end;

  /// <summary>
  ///   Represents the root of an IConfiguration hierarchy.
  /// </summary>
  IConfigurationRoot = interface(IConfiguration)
    ['{C3D4E5F6-A7B8-4901-C3D4-E5F678901234}']
    procedure Reload;
    function GetSectionChildren(const Path: string): TArray<IConfigurationSection>;
  end;

  /// <summary>
  ///   Provides configuration key/values for an application.
  /// </summary>
  IConfigurationProvider = interface
    ['{D4E5F6A7-B8C9-4012-D4E5-F67890123456}']
    function TryGet(const Key: string; out Value: string): Boolean;
    procedure Set_ (const Key, Value: string); // "Set" is a reserved word
    procedure Load;
    function GetChildKeys(const EarlierKeys: TArray<string>; const ParentPath: string): TArray<string>;
  end;

  /// <summary>
  ///   Optional capability for providers that can detect source changes.
  /// </summary>
  IConfigurationChangeTracker = interface
    ['{8E0D2D9B-6F57-4F2C-8F4A-0FD0F3B0E9E1}']
    function HasChanged: Boolean;
  end;

  /// <summary>
  ///   Represents a source of configuration key/values for an application.
  /// </summary>
  IConfigurationSource = interface
    ['{E5F6A7B8-C9D0-4123-E5F6-789012345678}']
    function Build(Builder: IConfigurationBuilder): IConfigurationProvider;
  end;

  /// <summary>
  ///   Represents a type used to build application configuration.
  /// </summary>
  IConfigurationBuilder = interface
    ['{F6A7B8C9-D0E1-4234-F6A7-890123456789}']
    function GetSources: IList<IConfigurationSource>;
    function GetProperties: IDictionary<string, TObject>;
    
    function Add(Source: IConfigurationSource): IConfigurationBuilder;
    /// <summary>
    ///   Enables polling of file providers marked ReloadOnChange and rebuilds
    ///   the configuration cache when files change (used by FeatureManagement hot-reload).
    /// </summary>
    function ReloadOnChange(AEnabled: Boolean = True; AIntervalMs: Integer = 1000): IConfigurationBuilder;
    function Build: IConfigurationRoot;
    
    property Sources: IList<IConfigurationSource> read GetSources;
    property Properties: IDictionary<string, TObject> read GetProperties;
  end;

implementation

end.

