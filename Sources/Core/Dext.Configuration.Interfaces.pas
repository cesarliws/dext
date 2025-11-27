unit Dext.Configuration.Interfaces;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections;

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
    function GetSources: TList<IConfigurationSource>;
    function GetProperties: TDictionary<string, TObject>;
    
    function Add(Source: IConfigurationSource): IConfigurationBuilder;
    function Build: IConfigurationRoot;
    
    property Sources: TList<IConfigurationSource> read GetSources;
    property Properties: TDictionary<string, TObject> read GetProperties;
  end;

implementation

end.
