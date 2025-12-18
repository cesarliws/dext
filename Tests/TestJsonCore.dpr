program TestJsonCore;

{$APPTYPE CONSOLE}

uses
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

begin
  try
    TestDeserialization;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
  ReadLn;
end.
