program Orm.UniDACDemo;

// ---------------------------------------------------------------------------
// UniDAC Demo for Dext Framework (Community Driver)
// ---------------------------------------------------------------------------
// Demonstrates basic ORM operations using UniDAC as the database driver.
// ---------------------------------------------------------------------------

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Dext.Utils,
  Dext,
  UniDACDemo.Entities in 'UniDACDemo.Entities.pas',
  UniDACDemo.Tests.Base in 'UniDACDemo.Tests.Base.pas',
  UniDACDemo.Tests.CRUD in 'UniDACDemo.Tests.CRUD.pas',
  UniDACDemo.DbConfig in 'UniDACDemo.DbConfig.pas';

begin
  try
    WriteLn('Dext Framework - UniDAC Driver Demo');
    WriteLn('======================================');
    WriteLn;
    WriteLn('Driver: UniDAC (SQLite in-memory)');
    WriteLn;

    UniDACDemo.Tests.CRUD.RunCRUDTests;

  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('ERROR: ' + E.Message);
      WriteLn;
      WriteLn('Make sure UniDAC is installed and provider units are included.');
      ExitCode := 1;
    end;
  end;

  WriteLn;
  Write('Press Enter to exit...');
  ReadLn;
end.
