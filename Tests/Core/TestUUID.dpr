program TestUUID;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Dext.Types.UUID in '..\..\Sources\Core\Dext.Types.UUID.pas';

procedure TestBasicConversion;
var
  U: TUUID;
  S: string;
begin
  WriteLn('► Testing Basic String Conversion...');
  
  // Test canonical format (no braces)
  S := 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';
  U := TUUID.FromString(S);
  
  if U.ToString <> S then
    raise Exception.CreateFmt('String roundtrip failed: expected %s, got %s', [S, U.ToString]);
  
  WriteLn('  ✓ Canonical format OK');
  
  // Test with braces
  S := '{a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11}';
  U := TUUID.FromString(S);
  
  if U.ToString <> 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11' then
    raise Exception.Create('Braces removal failed');
  
  WriteLn('  ✓ Braces format OK');
end;

procedure TestGUIDConversion;
var
  G: TGUID;
  U: TUUID;
  G2: TGUID;
begin
  WriteLn('► Testing TGUID Conversion...');
  
  CreateGUID(G);
  WriteLn('  Original GUID: ', GUIDToString(G));
  
  // Convert to TUUID
  U := TUUID.FromGUID(G);
  WriteLn('  As TUUID:      ', U.ToString);
  
  // Convert back
  G2 := U.ToGUID;
  WriteLn('  Back to GUID:  ', GUIDToString(G2));
  
  if not IsEqualGUID(G, G2) then
    raise Exception.Create('GUID roundtrip failed!');
  
  WriteLn('  ✓ GUID roundtrip OK');
end;

procedure TestImplicitOperators;
var
  U: TUUID;
  S: string;
  G: TGUID;
begin
  WriteLn('► Testing Implicit Operators...');
  
  // String to TUUID
  U := 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';
  WriteLn('  String → TUUID: ', U.ToString);
  
  // TUUID to String
  S := U;
  WriteLn('  TUUID → String: ', S);
  
  // TGUID to TUUID
  CreateGUID(G);
  U := G;
  WriteLn('  TGUID → TUUID:  ', U.ToString);
  
  // TUUID to TGUID
  G := U;
  WriteLn('  TUUID → TGUID:  ', GUIDToString(G));
  
  WriteLn('  ✓ Implicit operators OK');
end;

procedure TestUUIDv7;
var
  U1, U2: TUUID;
  S1, S2: string;
begin
  WriteLn('► Testing UUID v7 (Time-Ordered)...');
  
  U1 := TUUID.NewV7;
  Sleep(10); // Small delay
  U2 := TUUID.NewV7;
  
  S1 := U1.ToString;
  S2 := U2.ToString;
  
  WriteLn('  UUID v7 #1: ', S1);
  WriteLn('  UUID v7 #2: ', S2);
  
  // v7 UUIDs should be lexicographically ordered by time
  if S1 >= S2 then
    raise Exception.Create('UUID v7 not time-ordered!');
  
  // Check version bits (should be 7)
  var Bytes := U1.ToBytes;
  var Version := (Bytes[6] shr 4) and $0F;
  if Version <> 7 then
    raise Exception.CreateFmt('Invalid version: expected 7, got %d', [Version]);
  
  WriteLn('  ✓ UUID v7 time-ordering OK');
  WriteLn('  ✓ Version bits correct');
end;

procedure TestComparison;
var
  U1, U2, U3: TUUID;
begin
  WriteLn('► Testing Comparison Operators...');
  
  U1 := 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';
  U2 := 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';
  U3 := 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';
  
  if not (U1 = U2) then
    raise Exception.Create('Equality failed');
  
  if not (U1 <> U3) then
    raise Exception.Create('Inequality failed');
  
  WriteLn('  ✓ Equality OK');
  WriteLn('  ✓ Inequality OK');
end;

procedure TestNullUUID;
var
  U: TUUID;
begin
  WriteLn('► Testing Null UUID...');
  
  U := TUUID.Null;
  
  if not U.IsNull then
    raise Exception.Create('Null check failed');
  
  if U.ToString <> '00000000-0000-0000-0000-000000000000' then
    raise Exception.Create('Null string representation wrong');
  
  WriteLn('  ✓ Null UUID OK');
end;

begin
  try
    WriteLn('═══════════════════════════════════════════════════════════');
    WriteLn('  Dext.Types.UUID - Test Suite');
    WriteLn('═══════════════════════════════════════════════════════════');
    WriteLn;
    
    TestBasicConversion;
    WriteLn;
    
    TestGUIDConversion;
    WriteLn;
    
    TestImplicitOperators;
    WriteLn;
    
    TestUUIDv7;
    WriteLn;
    
    TestComparison;
    WriteLn;
    
    TestNullUUID;
    WriteLn;
    
    WriteLn('═══════════════════════════════════════════════════════════');
    WriteLn('🎉 ALL TESTS PASSED!');
    WriteLn('═══════════════════════════════════════════════════════════');
  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('═══════════════════════════════════════════════════════════');
      WriteLn('❌ TEST FAILED: ', E.Message);
      WriteLn('═══════════════════════════════════════════════════════════');
    end;
  end;
  
  WriteLn;
  WriteLn('Press ENTER to exit...');
  ReadLn;
end.
