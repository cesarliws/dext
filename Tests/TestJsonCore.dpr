program TestJsonCore;

{$APPTYPE CONSOLE}

uses
  Dext.MM,
  System.SysUtils,
  System.Generics.Collections,
  Dext.Json;

type
  TPost = class
  private
    FId: Integer;
    FContent: string;
  public
    property Id: Integer read FId write FId;
    property Content: string read FContent write FContent;
  end;

  TThread = class
  private
    FId: Integer;
    FName: string;
    FPosts: TObjectList<TPost>;
  public
    constructor Create;
    destructor Destroy; override;
    property Id: Integer read FId write FId;
    property Name: string read FName write FName;
    property Posts: TObjectList<TPost> read FPosts write FPosts;
  end;

  TEntityWithGuid = class
  private
    FId: TGUID;
    FName: string;
  public
    property Id: TGUID read FId write FId;
    property Name: string read FName write FName;
  end;

constructor TThread.Create;
begin
  FPosts := TObjectList<TPost>.Create;
end;

destructor TThread.Destroy;
begin
  FPosts.Free;
  inherited;
end;

procedure TestDeserialization;
var
  Json: string;
  Thread: TThread;
  Post: TPost;
begin
  Writeln('Testing JSON Deserialization...');

  Json := '{' +
          '  "id": 1,' +
          '  "name": "Dext Thread",' +
          '  "posts": [' +
          '    { "id": 101, "content": "First Post" },' +
          '    { "id": 102, "content": "Second Post" }' +
          '  ]' +
          '}';

  try
    // Use CaseInsensitive because JSON keys are lowercase (id, name) and properties are PascalCase (Id, Name)
    Thread := TDextJson.Deserialize<TThread>(Json, TDextSettings.Default.WithCaseInsensitive);
    try
      Writeln('Thread ID: ' + Thread.Id.ToString);
      Writeln('Thread Name: ' + Thread.Name);
      Writeln('Posts Count: ' + Thread.Posts.Count.ToString);

      if Thread.Posts.Count > 0 then
      begin
        for Post in Thread.Posts do
        begin
          Writeln('  - Post ID: ' + Post.Id.ToString + ', Content: ' + Post.Content);
        end;
      end
      else
      begin
        Writeln('  [FAIL] No posts deserialized (List support missing?)');
      end;

    finally
      Thread.Free;
    end;
  except
    on E: Exception do
      Writeln('Exception: ' + E.Message);
  end;
end;

procedure TestGuidSerialization;
var
  Entity, Deserialized: TEntityWithGuid;
  Json: string;
  NewGuid: TGUID;
begin
  Writeln('----------------------------------------');
  Writeln('Testing TGUID Serialization...');
  
  NewGuid := TGuid.Create('{6A7B8C9D-0E1F-2A3B-4C5D-6E7F8A9B0C1D}');
  
  Entity := TEntityWithGuid.Create;
  try
    Entity.Id := NewGuid;
    Entity.Name := 'Test Entity with GUID';
    
    Json := TDextJson.Serialize(Entity);
    Writeln('Serialized JSON: ' + Json);
    
    if not Json.Contains(GuidToString(NewGuid)) then
      Writeln('[FAIL] JSON does not contain the expected GUID string')
    else
      Writeln('[PASS] GUID serialized as string');
      
    Writeln('Testing TGUID Deserialization...');
    Deserialized := TDextJson.Deserialize<TEntityWithGuid>(Json);
    try
      if IsEqualGUID(Deserialized.Id, NewGuid) then
        Writeln('[PASS] GUID deserialized correctly: ' + GuidToString(Deserialized.Id))
      else
        Writeln('[FAIL] GUID mismatch. Expected: ' + GuidToString(NewGuid) + ' but got: ' + GuidToString(Deserialized.Id));
        
      if Deserialized.Name = Entity.Name then
        Writeln('[PASS] Name deserialized correctly: ' + Deserialized.Name)
      else
        Writeln('[FAIL] Name mismatch.');
        
    finally
      Deserialized.Free;
    end;
    
  finally
    Entity.Free;
  end;
  
  Writeln('Testing Raw TGUID Serialization...');
  Json := TDextJson.Serialize(NewGuid);
  Writeln('Raw GUID JSON: ' + Json);
  if Json.Contains(GuidToString(NewGuid)) then
    Writeln('[PASS] Raw GUID serialized correctly')
  else
    Writeln('[FAIL] Raw GUID serialization failed');
    
  Writeln('Testing Raw TGUID Deserialization...');
  var RawDeserialized := TDextJson.Deserialize<TGUID>(Json);
  if IsEqualGUID(RawDeserialized, NewGuid) then
    Writeln('[PASS] Raw GUID deserialized correctly')
  else
    Writeln('[FAIL] Raw GUID deserialization failed');
end;

begin
  try
    TestDeserialization;
    TestGuidSerialization;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
  ReadLn;
end.
