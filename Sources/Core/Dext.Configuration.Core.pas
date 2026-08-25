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
unit Dext.Configuration.Core;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.Collections.RawDict,
  Dext.Collections.Comparers,
  Dext.Collections.Algorithms,
  Dext.Configuration.Interfaces;

type
  /// <summary>
  ///   Callback function type for validating a configuration section.
  /// </summary>
  TConfigurationValidator = reference to function(const Section: IConfigurationSection): string;

  /// <summary>
  ///   Base for the implementation of configuration providers (JSON, Env, CLI, etc.).
  /// </summary>
  TConfigurationProvider = class(TInterfacedObject, IConfigurationProvider)
  protected
    FData: IDictionary<string, string>;
    procedure ClearData;
  public
    constructor Create;
    destructor Destroy; override;
    
    function TryGet(const Key: string; out Value: string): Boolean; virtual;
    procedure Set_(const Key, Value: string); virtual;
    procedure Load; virtual;
    function GetChildKeys(const EarlierKeys: TArray<string>; const ParentPath: string): TArray<string>; virtual;
  end;

  /// <summary>
  ///   Represents a section of application configuration values.
  /// </summary>
  TConfigurationSection = class(TInterfacedObject, IConfigurationSection, IConfiguration)
  private
    FRoot: IConfigurationRoot;
    FPath: string;
    FKey: string;
  public
    constructor Create(const Root: IConfigurationRoot; const Path: string);
    
    // IConfigurationSection
    function GetKey: string;
    function GetPath: string;
    function GetValue: string;
    procedure SetValue(const Value: string);
    
    // IConfiguration
    function GetItem(const Key: string): string;
    procedure SetItem(const Key, Value: string);
    function GetSection(const Key: string): IConfigurationSection;
    function GetChildren: TArray<IConfigurationSection>;
  end;

  /// <summary>
  ///   The root of the configuration that aggregates multiple providers. The last provider added takes precedence when resolving repeated keys (Last-In-First-Out).
  /// </summary>
  TConfigurationRoot = class(TInterfacedObject, IConfigurationRoot, IConfiguration)
  private
    FProviders: IList<IConfigurationProvider>;
    FLock: TCriticalSection;
    FReloadOnChange: Boolean;
    FReloadIntervalMs: Integer;
    FReloadThread: TThread;
    FKeyCache: IDictionary<Cardinal, string>;
    FCacheDirty: Boolean;
    
    function GetConfiguration(const Key: string): string;
    procedure SetConfiguration(const Key, Value: string);
    procedure StartWatcher;
    procedure StopWatcher;
    procedure CheckForChanges;
    procedure RebuildCache;

  public
    constructor Create(const Providers: IList<IConfigurationProvider>;
      AReloadOnChange: Boolean = False; AReloadIntervalMs: Integer = 1000);
    destructor Destroy; override;
    
    /// <summary>Forces a reload of all providers (e.g., re-reading JSON files or OS environment variables).</summary>
    procedure Reload;
    function GetSectionChildren(const Path: string): TArray<IConfigurationSection>;
    
    // IConfiguration
    /// <summary>Gets or sets the value of a configuration by its absolute key (e.g., "Database:Default:Host").</summary>
    function GetItem(const Key: string): string;
    procedure SetItem(const Key, Value: string);
    /// <summary>Gets a specific configuration sub-section as a navigable object.</summary>
    function GetSection(const Key: string): IConfigurationSection;
    /// <summary>Returns all immediate sub-sections of the current level.</summary>
    function GetChildren: TArray<IConfigurationSection>;
  end;

  /// <summary>
  ///   Builder for constructing the configuration system. Allows registering data sources before processing and generating the consolidated root.
  /// </summary>
  TConfigurationBuilder = class(TInterfacedObject, IConfigurationBuilder)
  private
    FSources: IList<IConfigurationSource>;
    FProperties: IDictionary<string, TObject>;
  public
    constructor Create;
    destructor Destroy; override;
    
    function GetSources: IList<IConfigurationSource>;
    function GetProperties: IDictionary<string, TObject>;
    
    /// <summary>Adds a data source (JSON, YAML, Env, etc.) to the construction pipeline.</summary>
    function Add(Source: IConfigurationSource): IConfigurationBuilder;
    /// <summary>Enables change polling for file providers with ReloadOnChange.</summary>
    function ReloadOnChange(AEnabled: Boolean = True; AIntervalMs: Integer = 1000): IConfigurationBuilder;
    /// <summary>Consolidates all sources and generates the root provider for consumption by the application.</summary>
    function Build: IConfigurationRoot;
  end;

  /// <summary>
  ///   An in-memory implementation of IConfigurationProvider.
  /// </summary>
  TMemoryConfigurationProvider = class(TConfigurationProvider)
  public
    constructor Create(Data: IDictionary<string, string>);
    procedure Load; override;
  end;

  /// <summary>
  ///   Represents an in-memory configuration source.
  /// </summary>
  TMemoryConfigurationSource = class(TInterfacedObject, IConfigurationSource)
  private
    FData: IDictionary<string, string>;
  public
    constructor Create(Data: IEnumerable<TPair<string, string>>); overload;
    constructor Create(const Data: array of TPair<string, string>); overload;
    destructor Destroy; override;
    function Build(Builder: IConfigurationBuilder): IConfigurationProvider;
  end;

  /// <summary>
  ///   Fluent facade for simplified creation of configurations.
  /// </summary>
  TDextConfiguration = record
  private
    FBuilder: IConfigurationBuilder;
  public
    constructor Create(const ABuilder: IConfigurationBuilder);
    /// <summary>Initiates the creation of a new fluent configuration.</summary>
    class function New: TDextConfiguration; static;

    /// <summary>Adds a custom source to the builder.</summary>
    function Add(const ASource: IConfigurationSource): TDextConfiguration;
    /// <summary>Adds static in-memory values to the configuration.</summary>
    function AddValues(const AValues: array of TPair<string, string>): TDextConfiguration;
    /// <summary>Enables or disables validation execution during Build.</summary>
    function ValidateOnBuild(AEnabled: Boolean = True): TDextConfiguration;
    /// <summary>Adds a validator for a specific configuration section.</summary>
    function AddSectionValidator(const ASectionPath: string;
      const AValidator: TConfigurationValidator): TDextConfiguration;
    /// <summary>
    ///   Enables/disables automatic reload when change-trackable providers detect source changes.
    /// </summary>
    function ReloadOnChange(AEnabled: Boolean = True; AIntervalMs: Integer = 1000): TDextConfiguration;
    /// <summary>Builds and returns the finalized configuration root.</summary>
    function Build: IConfigurationRoot;
    /// <summary>Returns the underlying builder for advanced manual configurations.</summary>
    function Unwrap: IConfigurationBuilder;
  end;

  /// <summary>
  ///   Static helper for configuration paths
  /// </summary>
  TConfigurationPath = class
  public
    const KeyDelimiter = ':';
    class function Combine(const Path, Key: string): string;
    class function GetSectionKey(const Path: string): string;
    class function GetParentPath(const Path: string): string;
  end;

implementation

const
  CConfigValidateOnBuildKey = 'dext:config:validate_on_build';
  CConfigValidatorRegistryKey = 'dext:config:validator_registry';
  CConfigReloadOnChangeKey = 'dext:config:reload_on_change';
  CConfigReloadIntervalKey = 'dext:config:reload_interval_ms';

type
  TBooleanBox = class
  public
    Value: Boolean;
  end;

  TIntBox = class
  public
    Value: Integer;
  end;

  TConfigurationReloadThread = class(TThread)
  private
    FRoot: TConfigurationRoot;
    FIntervalMs: Integer;
  protected
    procedure Execute; override;
  public
    constructor Create(ARoot: TConfigurationRoot; AIntervalMs: Integer);
  end;

  TConfigurationValidationRule = class
  public
    SectionPath: string;
    Validator: TConfigurationValidator;
  end;

  TConfigurationValidationRegistry = class
  private
    FRules: IList<TConfigurationValidationRule>;
  public
    constructor Create;
    function GetRules: IList<TConfigurationValidationRule>;
    procedure Add(const ASectionPath: string; const AValidator: TConfigurationValidator);
  end;

{ TConfigurationProvider }

procedure TConfigurationProvider.ClearData;
begin
  if Assigned(FData) then
    FData.Clear;
end;

constructor TConfigurationProvider.Create;
begin
  inherited;
  FData := TCollections.CreateDictionaryIgnoreCase<string, string>;
end;

destructor TConfigurationProvider.Destroy;
begin
  FData := nil;
  inherited;
end;

function TConfigurationProvider.TryGet(const Key: string; out Value: string): Boolean;
begin
  if FData = nil then
  begin
    Value := '';
    Exit(False);
  end;
  Result := FData.TryGetValue(Key, Value);
end;

procedure TConfigurationProvider.Set_(const Key, Value: string);
begin
  if FData = nil then
    FData := TCollections.CreateDictionaryIgnoreCase<string, string>;
  FData.AddOrSetValue(Key, Value);
end;

procedure TConfigurationProvider.Load;
begin
  // Base implementation does nothing
end;

function TConfigurationProvider.GetChildKeys(const EarlierKeys: TArray<string>; const ParentPath: string): TArray<string>;
var
  Results: IList<string>;
  Key: string;
  Segment: string;
  Prefix: string;
  Len: Integer;
  Pair: TPair<string, string>;
  DelimiterIndex: Integer;
begin
  Results := TCollections.CreateList<string>;
  try
    Results.AddRange(EarlierKeys);
    
    if ParentPath = '' then
      Prefix := ''
    else
      Prefix := ParentPath + TConfigurationPath.KeyDelimiter;
      
    Len := Length(Prefix);
    
    if FData <> nil then
    begin
      for Pair in FData do
      begin
        Key := Pair.Key;
        if (Len = 0) or (Key.StartsWith(Prefix, True)) then
        begin
          Segment := Key.Substring(Len);
          DelimiterIndex := Segment.IndexOf(TConfigurationPath.KeyDelimiter);
          if DelimiterIndex >= 0 then
            Segment := Segment.Substring(0, DelimiterIndex);
            
          if not Results.Contains(Segment) then
            Results.Add(Segment);
        end;
      end;
    end;
    
    Result := Results.ToArray;
    TDextSort.Sort<string>(Result, TComparer<string>.Default);
  finally
    Results := nil;
  end;
end;

{ TConfigurationValidationRegistry }

constructor TConfigurationValidationRegistry.Create;
begin
  inherited Create;
  FRules := TCollections.CreateList<TConfigurationValidationRule>(True);
end;

function TConfigurationValidationRegistry.GetRules: IList<TConfigurationValidationRule>;
begin
  Result := FRules;
end;

procedure TConfigurationValidationRegistry.Add(const ASectionPath: string;
  const AValidator: TConfigurationValidator);
var
  Rule: TConfigurationValidationRule;
begin
  if not Assigned(AValidator) then
    Exit;
  Rule := TConfigurationValidationRule.Create;
  Rule.SectionPath := ASectionPath;
  Rule.Validator := AValidator;
  FRules.Add(Rule);
end;

{ TConfigurationReloadThread }

constructor TConfigurationReloadThread.Create(ARoot: TConfigurationRoot; AIntervalMs: Integer);
begin
  inherited Create(False);
  FreeOnTerminate := False;
  FRoot := ARoot;
  FIntervalMs := AIntervalMs;
end;

procedure TConfigurationReloadThread.Execute;
begin
  while not Terminated do
  begin
    Sleep(FIntervalMs);
    if Terminated then
      Break;
    if Assigned(FRoot) then
      FRoot.CheckForChanges;
  end;
end;

{ TConfigurationSection }

constructor TConfigurationSection.Create(const Root: IConfigurationRoot; const Path: string);
begin
  inherited Create;
  FRoot := Root;
  FPath := Path;
  FKey := TConfigurationPath.GetSectionKey(Path);
end;

function TConfigurationSection.GetKey: string;
begin
  Result := FKey;
end;

function TConfigurationSection.GetPath: string;
begin
  Result := FPath;
end;

function TConfigurationSection.GetValue: string;
begin
  Result := FRoot[FPath];
end;

procedure TConfigurationSection.SetValue(const Value: string);
begin
  FRoot[FPath] := Value;
end;

function TConfigurationSection.GetItem(const Key: string): string;
begin
  Result := FRoot[TConfigurationPath.Combine(FPath, Key)];
end;

procedure TConfigurationSection.SetItem(const Key, Value: string);
begin
  FRoot[TConfigurationPath.Combine(FPath, Key)] := Value;
end;

function TConfigurationSection.GetSection(const Key: string): IConfigurationSection;
begin
  Result := FRoot.GetSection(TConfigurationPath.Combine(FPath, Key));
end;

function TConfigurationSection.GetChildren: TArray<IConfigurationSection>;
begin
  Result := FRoot.GetSectionChildren(FPath);
end;

{ TConfigurationRoot }

constructor TConfigurationRoot.Create(const Providers: IList<IConfigurationProvider>;
  AReloadOnChange: Boolean; AReloadIntervalMs: Integer);
var
  Provider: IConfigurationProvider;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FReloadOnChange := AReloadOnChange;
  FReloadIntervalMs := AReloadIntervalMs;
  if FReloadIntervalMs <= 0 then
    FReloadIntervalMs := 1000;
  FKeyCache := TCollections.CreateDictionary<Cardinal, string>;
  FCacheDirty := True;

  FProviders := TCollections.CreateList<IConfigurationProvider>;
  for Provider in Providers do
    FProviders.Add(Provider);
  
  for Provider in FProviders do
    Provider.Load;

  RebuildCache;
  StartWatcher;
end;

destructor TConfigurationRoot.Destroy;
begin
  StopWatcher;
  FKeyCache := nil;
  FProviders := nil;
  FLock.Free;
  inherited;
end;

procedure TConfigurationRoot.Reload;
var
  Provider: IConfigurationProvider;
begin
  FLock.Enter;
  try
    for Provider in FProviders do
      Provider.Load;
    RebuildCache;
  finally
    FLock.Leave;
  end;
end;

procedure TConfigurationRoot.RebuildCache;
var
  Value: string;
  Provider: IConfigurationProvider;
  Keys: TArray<string>;
  Key: string;
begin
  // Called inside FLock.Enter
  FKeyCache.Clear;
  // Iterate providers in order: last provider wins (overwrite earlier values)
  for Provider in FProviders do
  begin
    Keys := Provider.GetChildKeys([], '');
    for Key in Keys do
    begin
      if Provider.TryGet(Key, Value) then
        FKeyCache.AddOrSetValue(StringRawHashIgnoreCase(@Key, 0), Value);
    end;
  end;
  FCacheDirty := False;
end;

function TConfigurationRoot.GetConfiguration(const Key: string): string;
var
  Value: string;
  KeyHash: Cardinal;
  I: Integer;
begin
  FLock.Enter;
  try
    // Try cache first (O(1) lookup with hash)
    KeyHash := StringRawHashIgnoreCase(@Key, 0);
    if (not FCacheDirty) and FKeyCache.TryGetValue(KeyHash, Value) then
      Exit(Value);

    // Cache miss or dirty - fall back to provider scan
    Result := '';
    // Reverse order: last provider wins
    for I := FProviders.Count - 1 downto 0 do
    begin
      if FProviders[I].TryGet(Key, Value) then
        Exit(Value);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TConfigurationRoot.SetConfiguration(const Key, Value: string);
var
  Provider: IConfigurationProvider;
begin
  FLock.Enter;
  try
    // Set in all providers
    for Provider in FProviders do
      Provider.Set_(Key, Value);
    // Invalidate cache
    FCacheDirty := True;
  finally
    FLock.Leave;
  end;
end;

function TConfigurationRoot.GetItem(const Key: string): string;
begin
  Result := GetConfiguration(Key);
end;

procedure TConfigurationRoot.SetItem(const Key, Value: string);
begin
  SetConfiguration(Key, Value);
end;

function TConfigurationRoot.GetSection(const Key: string): IConfigurationSection;
begin
  Result := TConfigurationSection.Create(Self, Key);
end;

// Helper for internal use
function TConfigurationRoot.GetSectionChildren(const Path: string): TArray<IConfigurationSection>;
var
  Keys: TArray<string>;
  Provider: IConfigurationProvider;
  ChildPath: string;
  I: Integer;
begin
  FLock.Enter;
  try
  Keys := [];
  for Provider in FProviders do
  begin
    Keys := Provider.GetChildKeys(Keys, Path);
  end;
  
    // Keys are already distinct per provider logic usually, but we merge them.
    // Provider.GetChildKeys usually adds to existing.
    
    SetLength(Result, Length(Keys));
    for I := 0 to High(Keys) do
    begin
      ChildPath := TConfigurationPath.Combine(Path, Keys[I]);
      Result[I] := TConfigurationSection.Create(Self, ChildPath);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TConfigurationRoot.StartWatcher;
begin
  if not FReloadOnChange then
    Exit;
  if FReloadThread <> nil then
    Exit;
  FReloadThread := TConfigurationReloadThread.Create(Self, FReloadIntervalMs);
end;

procedure TConfigurationRoot.StopWatcher;
begin
  if FReloadThread = nil then
    Exit;
  FReloadThread.Terminate;
  FReloadThread.WaitFor;
  FreeAndNil(FReloadThread);
end;

procedure TConfigurationRoot.CheckForChanges;
var
  AnyChanged: Boolean;
  Provider: IConfigurationProvider;
  Tracker: IConfigurationChangeTracker;
begin
  FLock.Enter;
  try
    AnyChanged := False;
    for Provider in FProviders do
    begin
      if Supports(Provider, IConfigurationChangeTracker) then
      begin
        Tracker := Provider as IConfigurationChangeTracker;
        if Tracker.HasChanged then
        begin
          Provider.Load;
          AnyChanged := True;
        end;
      end;
    end;
    if AnyChanged then
      RebuildCache;
  finally
    FLock.Leave;
  end;
end;

function TConfigurationRoot.GetChildren: TArray<IConfigurationSection>;
begin
  Result := GetSectionChildren('');
end;

{ TConfigurationBuilder }

constructor TConfigurationBuilder.Create;
begin
  inherited;
  FSources := TCollections.CreateList<IConfigurationSource>;
  FProperties := TCollections.CreateDictionary<string, TObject>(True);
end;

destructor TConfigurationBuilder.Destroy;
begin
  FSources := nil;
  FProperties := nil;
  inherited;
end;

function TConfigurationBuilder.GetSources: IList<IConfigurationSource>;
begin
  Result := FSources;
end;

function TConfigurationBuilder.GetProperties: IDictionary<string, TObject>;
begin
  Result := FProperties;
end;

function TConfigurationBuilder.Add(Source: IConfigurationSource): IConfigurationBuilder;
begin
  FSources.Add(Source);
  Result := Self;
end;

function TConfigurationBuilder.ReloadOnChange(AEnabled: Boolean; AIntervalMs: Integer): IConfigurationBuilder;
var
  ReloadObj: TObject;
  ReloadBox: TBooleanBox;
  IntervalObj: TObject;
  IntervalBox: TIntBox;
begin
  if not FProperties.TryGetValue(CConfigReloadOnChangeKey, ReloadObj) or
     not (ReloadObj is TBooleanBox) then
  begin
    ReloadBox := TBooleanBox.Create;
    FProperties.AddOrSetValue(CConfigReloadOnChangeKey, ReloadBox);
  end
  else
    ReloadBox := TBooleanBox(ReloadObj);
  ReloadBox.Value := AEnabled;

  if not FProperties.TryGetValue(CConfigReloadIntervalKey, IntervalObj) or
     not (IntervalObj is TIntBox) then
  begin
    IntervalBox := TIntBox.Create;
    FProperties.AddOrSetValue(CConfigReloadIntervalKey, IntervalBox);
  end
  else
    IntervalBox := TIntBox(IntervalObj);

  if AIntervalMs <= 0 then
    AIntervalMs := 1000;
  IntervalBox.Value := AIntervalMs;

  Result := Self;
end;

function TConfigurationBuilder.Build: IConfigurationRoot;
var
  Providers: IList<IConfigurationProvider>;
  Source: IConfigurationSource;
  Provider: IConfigurationProvider;
  ReloadFlagObj: TObject;
  ReloadEnabled: Boolean;
  ReloadIntervalObj: TObject;
  ReloadIntervalMs: Integer;
begin
  Providers := TCollections.CreateList<IConfigurationProvider>;
  try
    for Source in FSources do
    begin
      Provider := Source.Build(Self);
      if Assigned(Provider) then
        Providers.Add(Provider);
    end;
    
    ReloadEnabled := False;
    if FProperties.TryGetValue(CConfigReloadOnChangeKey, ReloadFlagObj) and
       (ReloadFlagObj is TBooleanBox) then
      ReloadEnabled := TBooleanBox(ReloadFlagObj).Value;

    ReloadIntervalMs := 1000;
    if FProperties.TryGetValue(CConfigReloadIntervalKey, ReloadIntervalObj) and
       (ReloadIntervalObj is TIntBox) then
      ReloadIntervalMs := TIntBox(ReloadIntervalObj).Value;

    Result := TConfigurationRoot.Create(Providers, ReloadEnabled, ReloadIntervalMs);
  finally
    Providers := nil;
  end;
end;

{ TDextConfiguration }

constructor TDextConfiguration.Create(const ABuilder: IConfigurationBuilder);
begin
  FBuilder := ABuilder;
end;

class function TDextConfiguration.New: TDextConfiguration;
begin
  Result := TDextConfiguration.Create(TConfigurationBuilder.Create);
end;

function TDextConfiguration.Add(const ASource: IConfigurationSource): TDextConfiguration;
begin
  FBuilder.Add(ASource);
  Result := Self;
end;

function TDextConfiguration.AddValues(const AValues: array of TPair<string, string>): TDextConfiguration;
begin
  Result := Add(TMemoryConfigurationSource.Create(AValues));
end;

function TDextConfiguration.Build: IConfigurationRoot;
var
  ValidateFlagObj: TObject;
  ShouldValidate: Boolean;
  RegistryObj: TObject;
  Registry: TConfigurationValidationRegistry;
  Errors: IList<string>;
  Rule: TConfigurationValidationRule;
  Section: IConfigurationSection;
  Msg: string;
  FullMessage: string;
  I: Integer;
begin
  Result := FBuilder.Build;

  ShouldValidate := False;
  if FBuilder.Properties.TryGetValue(CConfigValidateOnBuildKey, ValidateFlagObj) and
     (ValidateFlagObj is TBooleanBox) then
    ShouldValidate := TBooleanBox(ValidateFlagObj).Value;

  if ShouldValidate then
  begin
    if FBuilder.Properties.TryGetValue(CConfigValidatorRegistryKey, RegistryObj) and
       (RegistryObj is TConfigurationValidationRegistry) then
    begin
      Registry := TConfigurationValidationRegistry(RegistryObj);
      Errors := TCollections.CreateList<string>;
      try
        for Rule in Registry.GetRules do
        begin
          Section := Result.GetSection(Rule.SectionPath);
          Msg := Rule.Validator(Section).Trim;
          if Msg <> '' then
            Errors.Add(Format('[%s] %s', [Rule.SectionPath, Msg]));
        end;

        if Errors.Count > 0 then
        begin
          FullMessage := 'Configuration validation failed:' + sLineBreak;
          for I := 0 to Errors.Count - 1 do
            FullMessage := FullMessage + Format('  %d) %s%s', [I + 1, Errors[I], sLineBreak]);
          raise EConfigurationException.Create(FullMessage);
        end;
      finally
        Errors := nil;
      end;
    end;
  end;
end;

function TDextConfiguration.Unwrap: IConfigurationBuilder;
begin
  Result := FBuilder;
end;

function TDextConfiguration.ValidateOnBuild(AEnabled: Boolean): TDextConfiguration;
var
  FlagObj: TObject;
  BoxObj: TBooleanBox;
begin
  if not FBuilder.Properties.TryGetValue(CConfigValidateOnBuildKey, FlagObj) or
     not (FlagObj is TBooleanBox) then
  begin
    BoxObj := TBooleanBox.Create;
    FBuilder.Properties.AddOrSetValue(CConfigValidateOnBuildKey, BoxObj);
  end
  else
    BoxObj := TBooleanBox(FlagObj);

  BoxObj.Value := AEnabled;
  Result := Self;
end;

function TDextConfiguration.AddSectionValidator(const ASectionPath: string;
  const AValidator: TConfigurationValidator): TDextConfiguration;
var
  RegistryObj: TObject;
  Registry: TConfigurationValidationRegistry;
begin
  if not FBuilder.Properties.TryGetValue(CConfigValidatorRegistryKey, RegistryObj) or
     not (RegistryObj is TConfigurationValidationRegistry) then
  begin
    Registry := TConfigurationValidationRegistry.Create;
    FBuilder.Properties.AddOrSetValue(CConfigValidatorRegistryKey, Registry);
  end
  else
    Registry := TConfigurationValidationRegistry(RegistryObj);

  Registry.Add(ASectionPath, AValidator);
  Result := Self;
end;

function TDextConfiguration.ReloadOnChange(AEnabled: Boolean; AIntervalMs: Integer): TDextConfiguration;
var
  ReloadObj: TObject;
  ReloadBox: TBooleanBox;
  IntervalObj: TObject;
  IntervalBox: TIntBox;
begin
  if not FBuilder.Properties.TryGetValue(CConfigReloadOnChangeKey, ReloadObj) or
     not (ReloadObj is TBooleanBox) then
  begin
    ReloadBox := TBooleanBox.Create;
    FBuilder.Properties.AddOrSetValue(CConfigReloadOnChangeKey, ReloadBox);
  end
  else
    ReloadBox := TBooleanBox(ReloadObj);
  ReloadBox.Value := AEnabled;

  if not FBuilder.Properties.TryGetValue(CConfigReloadIntervalKey, IntervalObj) or
     not (IntervalObj is TIntBox) then
  begin
    IntervalBox := TIntBox.Create;
    FBuilder.Properties.AddOrSetValue(CConfigReloadIntervalKey, IntervalBox);
  end
  else
    IntervalBox := TIntBox(IntervalObj);

  if AIntervalMs <= 0 then
    AIntervalMs := 1000;
  IntervalBox.Value := AIntervalMs;

  Result := Self;
end;

{ TMemoryConfigurationProvider }

constructor TMemoryConfigurationProvider.Create(Data: IDictionary<string, string>);
begin
  inherited Create;
  FData := Data;
end;

procedure TMemoryConfigurationProvider.Load;
begin
  // Already loaded in constructor
end;

{ TMemoryConfigurationSource }

constructor TMemoryConfigurationSource.Create(Data: IEnumerable<TPair<string, string>>);
var
  Pair: TPair<string, string>;
begin
  inherited Create;
  FData := TCollections.CreateDictionary<string, string>;
  if Data <> nil then
  begin
    for Pair in Data do
      FData.Add(Pair.Key, Pair.Value);
  end;
end;

constructor TMemoryConfigurationSource.Create(const Data: array of TPair<string, string>);
var
  Pair: TPair<string, string>;
begin
  inherited Create;
  FData := TCollections.CreateDictionary<string, string>;
  for Pair in Data do
    FData.Add(Pair.Key, Pair.Value);
end;

destructor TMemoryConfigurationSource.Destroy;
begin
  FData := nil;
  inherited;
end;

function TMemoryConfigurationSource.Build(Builder: IConfigurationBuilder): IConfigurationProvider;
begin
  Result := TMemoryConfigurationProvider.Create(FData);
end;

{ TConfigurationPath }

class function TConfigurationPath.Combine(const Path, Key: string): string;
begin
  if Path = '' then
    Result := Key
  else
    Result := Path + KeyDelimiter + Key;
end;

class function TConfigurationPath.GetSectionKey(const Path: string): string;
var
  LastDelimiter: Integer;
begin
  if Path = '' then
    Exit('');
    
  LastDelimiter := Path.LastIndexOf(KeyDelimiter);
  if LastDelimiter < 0 then
    Result := Path
  else
    Result := Path.Substring(LastDelimiter + 1);
end;

class function TConfigurationPath.GetParentPath(const Path: string): string;
var
  LastDelimiter: Integer;
begin
  if Path = '' then
    Exit('');
    
  LastDelimiter := Path.LastIndexOf(KeyDelimiter);
  if LastDelimiter < 0 then
    Result := ''
  else
    Result := Path.Substring(0, LastDelimiter);
end;

end.

