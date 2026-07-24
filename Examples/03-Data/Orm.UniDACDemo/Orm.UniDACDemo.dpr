program Orm.UniDACDemo;

// ---------------------------------------------------------------------------
// UniDAC Demo for Dext Framework
// ---------------------------------------------------------------------------
// Demonstrates basic ORM operations using UniDAC as the database driver.
//
// IMPORTANT: This project requires DEXT_USE_UNIDAC to be defined in the
// project options (or in Dext.inc). Without it, the default FireDAC driver
// will be used instead.
//
// To enable UniDAC, add to Project Options > Delphi Compiler > Conditional
// defines:  DEXT_USE_UNIDAC
// ---------------------------------------------------------------------------

{$APPTYPE CONSOLE}
{$DEFINE DEXT_USE_UNIDAC}

uses
  System.SysUtils,
  //Dext.MM,
  Dext.Utils,
  Dext,
  UniDACDemo.DbConfig in 'UniDACDemo.DbConfig.pas',
  UniDACDemo.Entities in 'UniDACDemo.Entities.pas',
  UniDACDemo.Tests.Base in 'UniDACDemo.Tests.Base.pas',
  UniDACDemo.Tests.CRUD in 'UniDACDemo.Tests.CRUD.pas';

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
      WriteLn('Make sure UniDAC is installed and DEXT_USE_UNIDAC is defined.');
      ExitCode := 1;
    end;
  end;

  WriteLn;
  Write('Press Enter to exit...');
  ReadLn;
end.