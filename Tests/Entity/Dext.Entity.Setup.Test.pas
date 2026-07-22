unit Dext.Entity.Setup.Test;

interface

uses
  System.SysUtils,
  System.Classes,
  Dext.Collections.Base,
  Dext.Collections.Dict,
  Dext.Collections,
  Dext.Entity,
  Dext.Entity.Drivers.Interfaces,
  Dext.Entity.Setup,
  Dext.Entity.Drivers.FireDAC,
  Dext.Entity.Dialects,
  FireDAC.Comp.Client;

type
  TSetupTest = class
  public
    procedure Run;
  end;

implementation

{ TSetupTest }

procedure TSetupTest.Run;
var
  Options: TDbContextOptions;
  Conn: IDbConnection;
  FDConn: TFDConnection;
  Pair: TPair<string, string>;
begin
  WriteLn('[TEST] Running Setup & ConnectionString Tests...');

  // Test 1: FireDAC connection string propagation (non-pooled)
  try
    WriteLn(' -> Starting Test 1 (Non-pooled connection string)...');
    Options := TDbContextOptions.Create;
    try
      Options.ConnectionString := 'Server=localhost;Port=5432;Database=postgres;User_Name=postgres;Password=123456';

      Conn := Options.BuildConnection;
      if Conn is TFireDACConnection then
      begin
        FDConn := TFireDACConnection(Conn).Connection;

        // Check if connection string or params are set correctly
        if (FDConn.ConnectionString <> '') and (FDConn.Params.Database = 'postgres') then
          WriteLn('   [PASS] ConnectionString/Params propagated correctly.')
        else
        begin
          WriteLn('   [FAIL] ConnectionString NOT propagated correctly.');
          WriteLn('      Expected DB: postgres, Got: ' + FDConn.Params.Database);
          WriteLn('      FDConn.ConnectionString: ' + FDConn.ConnectionString);
        end;

        // Check if FireDAC parsed the password (even if not connected)
        if FDConn.Params.Password = '123456' then
          WriteLn('   [PASS] Password correctly parsed by FireDAC.')
        else
          WriteLn('   [FAIL] Password NOT parsed: ' + FDConn.Params.Password);

        if FDConn.Params.UserName = 'postgres' then
          WriteLn('   [PASS] UserName correctly parsed.')
        else
          WriteLn('   [FAIL] UserName NOT parsed: ' + FDConn.Params.UserName);
      end
      else
        WriteLn('   [FAIL] Connection is not a TFireDACConnection.');
    finally
      Options.Free;
    end;
  except
    on E: Exception do
      WriteLn('   [FAIL] Test 1 failed with ' + E.ClassName + ': ' + E.Message);
  end;

  // Test 2: Fluent Firebird UseFirebird with pooling
  try
    WriteLn(' -> Starting Test 2 (Fluent Firebird with pooling)...');
    Options := TDbContextOptions.Create;
    try
      Options.UseFirebird('Database=c:\temp\db.fdb;User_Name=SYSDBA;Password=masterkey')
             .WithPooling(True, 10);

      // Print what is inside Options.Params
      WriteLn('   Options.Params keys:');
      for Pair in Options.Params do
        WriteLn('     - Key: "' + Pair.Key + '", Value: "' + Pair.Value + '"');

      // Check if parameters are correctly parsed into FParams
      if Options.Params.ContainsKey('Database') then
        WriteLn('   [PASS] UseFirebird Database key exists.')
      else
        WriteLn('   [FAIL] UseFirebird Database key DOES NOT exist.');

      if Options.Params['Database'] = 'c:\temp\db.fdb' then
        WriteLn('   [PASS] UseFirebird Database parsed correctly.')
      else
        WriteLn('   [FAIL] UseFirebird Database NOT parsed.');

      if Options.Params['User_Name'] = 'SYSDBA' then
        WriteLn('   [PASS] UseFirebird User_Name parsed correctly.')
      else
        WriteLn('   [FAIL] UseFirebird User_Name NOT parsed.');

      Conn := Options.BuildConnection;
      try
        if Conn is TFireDACConnection then
        begin
          FDConn := TFireDACConnection(Conn).Connection;
          // Since pooling is enabled, it should use a ConnectionDefName starting with 'DextPool_'
          if FDConn.ConnectionDefName.StartsWith('DextPool_') then
            WriteLn('   [PASS] UseFirebird with pooling registered ConnectionDefName: ' + FDConn.ConnectionDefName)
          else
            WriteLn('   [FAIL] UseFirebird with pooling DID NOT register ConnectionDefName.');
        end
        else
          WriteLn('   [FAIL] UseFirebird with pooling: Connection is not a TFireDACConnection.');
      finally
        Conn := nil;
      end;
    finally
      Options.Free;
    end;
  except
    on E: Exception do
      WriteLn('   [FAIL] Test 2 failed with ' + E.ClassName + ': ' + E.Message);
  end;

  // Test 3: UseConnectionDef with dialect detection
  try
    WriteLn(' -> Starting Test 3 (UseConnectionDef dialect detection)...');
    // Ensure the FDManager is active
    FDManager.SilentMode := True;
    FDManager.Active := True;

    // Register a mock Firebird connection definition
    if not FDManager.IsConnectionDef('TestFBDef') then
    begin
      FDManager.AddConnectionDef('TestFBDef', 'FB', nil);
    end;

    Options := TDbContextOptions.Create;
    try
      Options.UseConnectionDef('TestFBDef');
      Conn := Options.BuildConnection;
      try
        if Conn.Dialect = ddFirebird then
          WriteLn('   [PASS] UseConnectionDef dialect detected correctly: ddFirebird')
        else
          WriteLn('   [FAIL] UseConnectionDef dialect NOT detected correctly: ' + IntToStr(Ord(Conn.Dialect)));
      finally
        Conn := nil;
      end;
    finally
      Options.Free;
    end;
  except
    on E: Exception do
      WriteLn('   [FAIL] Test 3 failed with ' + E.ClassName + ': ' + E.Message);
  end;

  WriteLn('');
end;

end.
