unit Dext.Configuration.Json;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  Dext.Configuration.Interfaces,
  Dext.Configuration.Core,
  Dext.Json,
  Dext.Json.Types;

type
  TJsonConfigurationProvider = class(TConfigurationProvider)
  private
    FPath: string;
    FOptional: Boolean;
    
    procedure ProcessNode(const Prefix: string; Node: IDextJsonNode);
    procedure ProcessObject(const Prefix: string; Obj: IDextJsonObject);
    procedure ProcessArray(const Prefix: string; Arr: IDextJsonArray);
  public
    constructor Create(const Path: string; Optional: Boolean);
    procedure Load; override;
  end;

  TJsonConfigurationSource = class(TInterfacedObject, IConfigurationSource)
  private
    FPath: string;
    FOptional: Boolean;
  public
    constructor Create(const Path: string; Optional: Boolean = False);
    function Build(Builder: IConfigurationBuilder): IConfigurationProvider;
  end;

implementation

{ TJsonConfigurationSource }

constructor TJsonConfigurationSource.Create(const Path: string; Optional: Boolean);
begin
  inherited Create;
  FPath := Path;
  FOptional := Optional;
end;

function TJsonConfigurationSource.Build(Builder: IConfigurationBuilder): IConfigurationProvider;
begin
  Result := TJsonConfigurationProvider.Create(FPath, FOptional);
end;

{ TJsonConfigurationProvider }

constructor TJsonConfigurationProvider.Create(const Path: string; Optional: Boolean);
begin
  inherited Create;
  FPath := Path;
  FOptional := Optional;
end;

procedure TJsonConfigurationProvider.Load;
var
  JsonContent: string;
  RootNode: IDextJsonNode;
begin
  if not FileExists(FPath) then
  begin
    if FOptional then
      Exit;
    raise EFileNotFoundException.CreateFmt('Configuration file not found: %s', [FPath]);
  end;

  try
    JsonContent := TFile.ReadAllText(FPath, TEncoding.UTF8);
    if JsonContent.Trim = '' then
      Exit;

    RootNode := TDextJson.Provider.Parse(JsonContent);
    
    FData.Clear;
    ProcessNode('', RootNode);
  except
    on E: Exception do
      raise EConfigurationException.CreateFmt('Error loading JSON configuration from %s: %s', [FPath, E.Message]);
  end;
end;

procedure TJsonConfigurationProvider.ProcessNode(const Prefix: string; Node: IDextJsonNode);
begin
  case Node.GetNodeType of
    jntObject:
      ProcessObject(Prefix, Node as IDextJsonObject);
      
    jntArray:
      ProcessArray(Prefix, Node as IDextJsonArray);
      
    jntString, jntNumber, jntBoolean:
      begin
        // Leaf node
        if Prefix <> '' then
          Set_(Prefix, Node.AsString);
      end;
      
    jntNull:
      begin
        if Prefix <> '' then
          Set_(Prefix, ''); // Treat null as empty string? Or skip? .NET treats as empty usually.
      end;
  end;
end;

procedure TJsonConfigurationProvider.ProcessObject(const Prefix: string; Obj: IDextJsonObject);
var
  I: Integer;
  Key: string;
  ChildPrefix: string;
  ChildNode: IDextJsonNode;
begin
  for I := 0 to Obj.GetCount - 1 do
  begin
    Key := Obj.GetName(I);
    ChildNode := Obj.GetNode(Key);
    
    if Prefix = '' then
      ChildPrefix := Key
    else
      ChildPrefix := Prefix + TConfigurationPath.KeyDelimiter + Key;
      
    ProcessNode(ChildPrefix, ChildNode);
  end;
end;

procedure TJsonConfigurationProvider.ProcessArray(const Prefix: string; Arr: IDextJsonArray);
var
  I: Integer;
  ChildPrefix: string;
  ChildNode: IDextJsonNode;
begin
  for I := 0 to Arr.GetCount - 1 do
  begin
    ChildNode := Arr.GetNode(I);
    
    if Prefix = '' then
      ChildPrefix := IntToStr(I) // Should not happen for root array usually
    else
      ChildPrefix := Prefix + TConfigurationPath.KeyDelimiter + IntToStr(I);
      
    ProcessNode(ChildPrefix, ChildNode);
  end;
end;

end.
