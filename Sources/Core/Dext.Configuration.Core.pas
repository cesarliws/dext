unit Dext.Configuration.Core;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.Generics.Defaults,
  Dext.Configuration.Interfaces;

type
  /// <summary>
  ///   Base helper class for implementing IConfigurationProvider
  /// </summary>
  TConfigurationProvider = class(TInterfacedObject, IConfigurationProvider)
  protected
    FData: TDictionary<string, string>;
  public
    constructor Create;
    destructor Destroy; override;
    
    function TryGet(const Key: string; out Value: string): Boolean; virtual;
    procedure Set_(const Key, Value: string); virtual;
    procedure Load; virtual;
    function GetChildKeys(const EarlierKeys: TArray<string>; const ParentPath: string): TArray<string>; virtual;
  end;

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

  TConfigurationRoot = class(TInterfacedObject, IConfigurationRoot, IConfiguration)
  private
    FProviders: TList<IConfigurationProvider>;
    
    function GetConfiguration(const Key: string): string;
    procedure SetConfiguration(const Key, Value: string);
    function GetChildrenInternal(const Path: string): TArray<IConfigurationSection>;
  protected
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;
  public
    constructor Create(const Providers: TList<IConfigurationProvider>);
    destructor Destroy; override;
    
    procedure Reload;
    
    // IConfiguration
    function GetItem(const Key: string): string;
    procedure SetItem(const Key, Value: string);
    function GetSection(const Key: string): IConfigurationSection;
    function GetChildren: TArray<IConfigurationSection>;
  end;

  TConfigurationBuilder = class(TInterfacedObject, IConfigurationBuilder)
  private
    FSources: TList<IConfigurationSource>;
    FProperties: TDictionary<string, TObject>;
  public
    constructor Create;
    destructor Destroy; override;
    
    function GetSources: TList<IConfigurationSource>;
    function GetProperties: TDictionary<string, TObject>;
    
    function Add(Source: IConfigurationSource): IConfigurationBuilder;
    function Build: IConfigurationRoot;
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

{ TConfigurationProvider }

constructor TConfigurationProvider.Create;
begin
  inherited;
  FData := TDictionary<string, string>.Create(TStringComparer.Ordinal);
end;

destructor TConfigurationProvider.Destroy;
begin
  FData.Free;
  inherited;
end;

function TConfigurationProvider.TryGet(const Key: string; out Value: string): Boolean;
begin
  Result := FData.TryGetValue(Key, Value);
end;

procedure TConfigurationProvider.Set_(const Key, Value: string);
begin
  FData.AddOrSetValue(Key, Value);
end;

procedure TConfigurationProvider.Load;
begin
  // Base implementation does nothing
end;

function TConfigurationProvider.GetChildKeys(const EarlierKeys: TArray<string>; const ParentPath: string): TArray<string>;
var
  Results: TList<string>;
  Key: string;
  Segment: string;
  Prefix: string;
  Len: Integer;
begin
  Results := TList<string>.Create;
  try
    Results.AddRange(EarlierKeys);
    
    if ParentPath = '' then
      Prefix := ''
    else
      Prefix := ParentPath + TConfigurationPath.KeyDelimiter;
      
    Len := Length(Prefix);
    
    for Key in FData.Keys do
    begin
      if (Len = 0) or (Key.StartsWith(Prefix, True)) then
      begin
        Segment := Key.Substring(Len);
        var DelimiterIndex := Segment.IndexOf(TConfigurationPath.KeyDelimiter);
        if DelimiterIndex >= 0 then
          Segment := Segment.Substring(0, DelimiterIndex);
          
        if not Results.Contains(Segment) then
          Results.Add(Segment);
      end;
    end;
    
    Result := Results.ToArray;
    TArray.Sort<string>(Result);
  finally
    Results.Free;
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
var
  Children: TArray<IConfigurationSection>;
begin
  Children := FRoot.GetChildren;
  // This is actually tricky on the root implementation, 
  // usually GetChildren calls providers.
  // For a section, we need to filter children that start with our path.
  // But FRoot.GetChildren returns top level.
  // We should probably expose a method on Root to get children of a path.
  
  // Let's defer to Root implementation logic if possible, but Root interface doesn't have GetChildren(Path).
  // We can cast Root to TConfigurationRoot or just implement logic here using providers?
  // No, we only have IConfigurationRoot.
  
  // Actually, standard .NET implementation:
  // IConfiguration.GetChildren() returns the immediate children subsections.
  
  // So if we are at "Logging", children might be "LogLevel".
  // We need to ask providers for child keys given our path.
  
  // Since we don't have direct access to providers here, we rely on Root.
  // Wait, IConfiguration interface has GetChildren.
  // The Root implementation of GetChildren returns root children.
  // The Section implementation of GetChildren should return its children.
  
  // We need a way to get child keys from root given a path.
  // But IConfigurationRoot doesn't expose that.
  // In .NET, IConfigurationSection implements IConfiguration, so it has GetChildren.
  // The logic usually resides in the Root or is delegated.
  
  // Let's implement it by casting Root to TConfigurationRoot for now or assume we can't easily without extending interface.
  // For simplicity in this iteration, let's assume we can cast or we just return empty.
  // Ideally, we should add GetChildKeys to IConfigurationRoot or similar.
  // But we want to stick to standard interfaces.
  
  // Let's implement GetChildren in TConfigurationRoot properly, and here we might need a hack or helper.
  // Actually, TConfigurationRoot can have a helper method that takes a path.
  
  if FRoot is TConfigurationRoot then
    Result := TConfigurationRoot(FRoot).GetChildrenInternal(FPath)
  else
    Result := [];
end;

{ TConfigurationRoot }

constructor TConfigurationRoot.Create(const Providers: TList<IConfigurationProvider>);
begin
  inherited Create;
  FProviders := TList<IConfigurationProvider>.Create;
  FProviders.AddRange(Providers);
  
  for var Provider in FProviders do
    Provider.Load;
end;

destructor TConfigurationRoot.Destroy;
begin
  FProviders.Free;
  inherited;
end;

procedure TConfigurationRoot.Reload;
begin
  for var Provider in FProviders do
    Provider.Load;
end;

function TConfigurationRoot._AddRef: Integer;
begin
  Result := -1;
end;

function TConfigurationRoot._Release: Integer;
begin
  Result := -1;
end;

function TConfigurationRoot.GetConfiguration(const Key: string): string;
var
  Value: string;
begin
  Result := '';
  // Reverse order: last provider wins
  for var I := FProviders.Count - 1 downto 0 do
  begin
    if FProviders[I].TryGet(Key, Value) then
      Exit(Value);
  end;
end;

procedure TConfigurationRoot.SetConfiguration(const Key, Value: string);
begin
  // Set in all providers? Or just the first one that supports it?
  // Usually configuration is read-only from file sources, but memory source is writable.
  // .NET sets it in all providers.
  for var Provider in FProviders do
    Provider.Set_(Key, Value);
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
function TConfigurationRoot.GetChildrenInternal(const Path: string): TArray<IConfigurationSection>;
var
  Keys: TArray<string>;
  Provider: IConfigurationProvider;
  DistinctKeys: TList<string>;
  ChildPath: string;
begin
  Keys := [];
  for Provider in FProviders do
  begin
    Keys := Provider.GetChildKeys(Keys, Path);
  end;
  
  DistinctKeys := TList<string>.Create;
  try
    // Keys are already distinct per provider logic usually, but we merge them.
    // Provider.GetChildKeys usually adds to existing.
    
    SetLength(Result, Length(Keys));
    for var I := 0 to High(Keys) do
    begin
      ChildPath := TConfigurationPath.Combine(Path, Keys[I]);
      Result[I] := TConfigurationSection.Create(Self, ChildPath);
    end;
  finally
    DistinctKeys.Free;
  end;
end;

function TConfigurationRoot.GetChildren: TArray<IConfigurationSection>;
begin
  Result := GetChildrenInternal('');
end;

{ TConfigurationBuilder }

constructor TConfigurationBuilder.Create;
begin
  inherited;
  FSources := TList<IConfigurationSource>.Create;
  FProperties := TDictionary<string, TObject>.Create;
end;

destructor TConfigurationBuilder.Destroy;
begin
  FSources.Free;
  FProperties.Free;
  inherited;
end;

function TConfigurationBuilder.GetSources: TList<IConfigurationSource>;
begin
  Result := FSources;
end;

function TConfigurationBuilder.GetProperties: TDictionary<string, TObject>;
begin
  Result := FProperties;
end;

function TConfigurationBuilder.Add(Source: IConfigurationSource): IConfigurationBuilder;
begin
  FSources.Add(Source);
  Result := Self;
end;

function TConfigurationBuilder.Build: IConfigurationRoot;
var
  Providers: TList<IConfigurationProvider>;
begin
  Providers := TList<IConfigurationProvider>.Create;
  try
    for var Source in FSources do
    begin
      var Provider := Source.Build(Self);
      if Assigned(Provider) then
        Providers.Add(Provider);
    end;
    
    Result := TConfigurationRoot.Create(Providers);
  finally
    Providers.Free;
  end;
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
