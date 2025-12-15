program Orm.SimpleTest;

{$APPTYPE CONSOLE}

uses
  Dext.MM,
  System.SysUtils,
  FireDAC.Comp.Client,
  FireDAC.Stan.Def,
  FireDAC.Stan.Async,
  FireDAC.Phys.SQLite,
  FireDAC.Stan.Param,
  FireDAC.Stan.Option,
  FireDAC.Stan.Error,
  FireDAC.DatS,
  FireDAC.Phys.Intf,
  FireDAC.DApt.Intf,
  FireDAC.DApt,
  Dext.Collections,
  Dext.Persistence,
  Dext.Entity.Drivers.Interfaces,
  Dext.Entity.Dialects,
  EntityDemo.Entities in 'EntityDemo.Entities.pas',
  EntityDemo.DbConfig in 'EntityDemo.DbConfig.pas';

var
  DbConnection: IDbConnection;
  Dialect: ISQLDialect;
  Ctx: TDbContext;
  U: TUser;
  Users: IList<TUser>;
begin
  try
    WriteLn('Simple IList Test');
    WriteLn('=================');
    WriteLn('');
    
    // Create connection using TDbConfig (same as tests)
    WriteLn('Creating connection...');
    DbConnection := TDbConfig.CreateConnection;
    Dialect := TDbConfig.CreateDialect;
    
    WriteLn('Creating context...');
    Ctx := TDbContext.Create(DbConnection, Dialect);
    try
      WriteLn('Registering entities...');
      Ctx.Entities<TUser>;
      Ctx.Entities<TAddress>;
      
      WriteLn('Creating schema...');
      Ctx.EnsureCreated;
      
      WriteLn('Creating user...');
      U := TUser.Create;
      U.Name := 'Test User';
      U.Age := 25;
      U.Email := 'test@test.com';
      
      Ctx.Entities<TUser>.Add(U);
      Ctx.SaveChanges;
      WriteLn('User saved with ID: ', U.Id);
      
      WriteLn('Fetching users...');
      Users := Ctx.Entities<TUser>.List;
      WriteLn('Found ', Users.Count, ' user(s)');
      
      if Users.Count > 0 then
        WriteLn('First user: ', Users[0].Name);
      
      WriteLn('');
      WriteLn('SUCCESS! No crashes, no manual .Free needed for IList!');
      WriteLn('');
    finally
      Users := nil;
      Ctx.Free;
    end;
    
  except
    on E: Exception do
    begin
      WriteLn('');
      WriteLn('ERROR: ', E.ClassName, ': ', E.Message);
      WriteLn('');
    end;
  end;
  
  WriteLn('Press ENTER to exit...');
  ReadLn;
end.
