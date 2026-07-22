program TestTypeConvertersSimple;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Rtti,
  Dext.Entity.TypeConverters,
  Dext.Entity.Dialects,
  Dext.Utils;

type
  TUserRole = (urGuest, urUser, urAdmin, urSuperAdmin);

procedure TestGuidConverter;
var
  Converter: TGuidConverter;
  Guid: TGUID;
  Value, DbValue, Restored: TValue;
begin
  WriteLn('► Testing GUID Converter...');
  Converter := TGuidConverter.Create;
  try
    CreateGUID(Guid);
    Value := TValue.From<TGUID>(Guid);

    // To Database (PostgreSQL expects string UUID)
    DbValue := Converter.ToDatabase(Value, ddPostgreSQL);
    WriteLn('  Original: ', GUIDToString(Guid));
    WriteLn('  To DB:    ', DbValue.AsString);

    // From Database
    Restored := Converter.FromDatabase(DbValue, TypeInfo(TGUID));
    if not IsEqualGUID(Guid, Restored.AsType<TGUID>) then
      raise Exception.Create('GUID Round-trip failed');

    WriteLn('  ✓ GUID Success');
  finally
    Converter.Free;
  end;
end;

procedure TestEnumConverter;
var
  Converter: TEnumConverter;
  Role: TUserRole;
  Value, DbValue, Restored: TValue;
begin
  WriteLn('► Testing Enum Converter...');

  // Test String Mode
  Converter := TEnumConverter.Create(True);
  try
    Role := urSuperAdmin;
    Value := TValue.From<TUserRole>(Role);

    DbValue := Converter.ToDatabase(Value, ddPostgreSQL);
    WriteLn('  Enum:  urSuperAdmin');
    WriteLn('  To DB: ', DbValue.AsString);

    Restored := Converter.FromDatabase(DbValue, TypeInfo(TUserRole));
    if Restored.AsType<TUserRole> <> Role then
      raise Exception.Create('Enum String Round-trip failed');

    WriteLn('  ✓ Enum String Success');
  finally
    Converter.Free;
  end;

  // Test Integer Mode
  Converter := TEnumConverter.Create(False);
  try
    Role := urAdmin;
    Value := TValue.From<TUserRole>(Role);

    DbValue := Converter.ToDatabase(Value, ddPostgreSQL);
    WriteLn('  Enum:  urAdmin');
    WriteLn('  To DB: ', DbValue.AsInteger);

    Restored := Converter.FromDatabase(DbValue, TypeInfo(TUserRole));
    if Restored.AsType<TUserRole> <> Role then
      raise Exception.Create('Enum Integer Round-trip failed');

    WriteLn('  ✓ Enum Integer Success');
  finally
    Converter.Free;
  end;
end;

begin
  SetConsoleCharSet(65001);
  try
    WriteLn('📊 Dext Type Converters Simple Validation');
    WriteLn('=========================================');
    WriteLn;

    TestGuidConverter;
    WriteLn;
    TestEnumConverter;

    WriteLn;
    WriteLn('✅ All simple validations passed!');
  except
    on E: Exception do
    begin
      WriteLn('❌ FAILED: ' + E.Message);
      ExitCode := 1;
    end;
  end;

  WriteLn;
  WriteLn('Press ENTER to exit...');
  ConsolePause;
end.
