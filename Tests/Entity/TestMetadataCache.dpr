program TestMetadataCache;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.TypInfo,
  Dext.Utils,
  Dext.Entity.Mapping,
  Dext.Entity.Attributes;

type
  [Table('CachedUsers')]
  TUser = class
    FId: Integer;
    FName: string;
    [PK, AutoInc]
    property Id: Integer read FId write FId;
    property Name: string read FName write FName;
  end;

procedure TestCache;
var
  Map1, Map2: TEntityMap;
  Prop: TPropertyMap;
begin
  WriteLn('Testing Metadata Cache...');

  // 1. First Access: Should create and cache
  Map1 := TModelBuilder.Instance.GetMap(TypeInfo(TUser));
  if Map1 = nil then
    raise Exception.Create('Map1 is nil');

  if Map1.TableName <> 'CachedUsers' then
    raise Exception.Create('Map1 TableName incorrect: ' + Map1.TableName);

  // 2. Second Access: Should return same instance
  Map2 := TModelBuilder.Instance.GetMap(TypeInfo(TUser));
  if Map2 = nil then
    raise Exception.Create('Map2 is nil');

  if Map1 <> Map2 then
    raise Exception.Create('Cache failed! Different instances returned.');

  WriteLn('  ✓ Cache hit works (Same Instance)');
  WriteLn('  ✓ Table Name: ', Map1.TableName);

  // 3. Verify Properties are cached
  Prop := Map1.Properties['Name'];
  if Prop = nil then
    raise Exception.Create('Property Name not cached');

  WriteLn('  ✓ Property Map cached');
end;

begin
  SetConsoleCharSet(65001);
  try
    TestCache;
    WriteLn;
    WriteLn('PASS: Metadata Cache Verified.');
  except
    on E: Exception do
    begin
      WriteLn('FAIL: ', E.Message);
      ExitCode := 1;
    end;
  end;
  ConsolePause;
end.
