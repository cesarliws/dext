program EntityDemo;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Generics.Collections,
  Data.DB,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Error,
  FireDAC.UI.Intf,
  FireDAC.Phys.Intf,
  FireDAC.Stan.Def,
  FireDAC.Stan.Pool,
  FireDAC.Stan.Async,
  FireDAC.Phys,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
  FireDAC.Stan.ExprFuncs,
  FireDAC.Phys.SQLiteWrapper.Stat,
  FireDAC.ConsoleUI.Wait,
  FireDAC.Comp.Client,
  FireDAC.DApt, // Required for FireDAC data adapters
  
  Dext.Entity,
  Dext.Entity.Core,
  Dext.Entity.Attributes,
  Dext.Entity.Drivers.FireDAC,
  Dext.Entity.Dialects,
  Dext.Specifications.Interfaces,
  Dext.Specifications.Criteria,
  Dext.Specifications.Base;

type
  [Table('users')]
  TUser = class
  private
    FId: Integer;
    FName: string;
    FAge: Integer;
    FEmail: string;
  public
    [PK, AutoInc]
    property Id: Integer read FId write FId;
    
    [Column('full_name')]
    property Name: string read FName write FName;
    
    property Age: Integer read FAge write FAge;
    property Email: string read FEmail write FEmail;
  end;

  // 🧬 Metadata Prototype (TypeOf)
  UserEntity = class
  public
    class function Age: TProp;
    class function Name: TProp;
  end;

  // Specification using Metadata
  TAdultUsersSpec = class(TSpecification<TUser>)
  public
    constructor Create; override;
  end;

{ UserEntity }

class function UserEntity.Age: TProp;
begin
  Result := Prop('Age');
end;

class function UserEntity.Name: TProp;
begin
  Result := Prop('full_name');
end;

{ TAdultUsersSpec }

constructor TAdultUsersSpec.Create;
begin
  inherited Create;
  Where(UserEntity.Age >= 18);
end;

procedure RunDemo;
var
  FDConn: TFDConnection;
  Context: TDbContext; // Using concrete class to access Entities<T>
  User: TUser;
  Users: TList<TUser>;
begin
  WriteLn('🚀 Dext Entity ORM Demo');
  WriteLn('=======================');

  // 1. Setup FireDAC Connection (SQLite In-Memory)
  FDConn := TFDConnection.Create(nil);
  try
    FDConn.DriverName := 'SQLite';
    FDConn.Params.Database := ':memory:'; 
    FDConn.LoginPrompt := False;
    FDConn.Connected := True;
    
    // 2. Create Table
    WriteLn('🛠️  Creating table "users"...');
    FDConn.ExecSQL('CREATE TABLE users (Id INTEGER PRIMARY KEY AUTOINCREMENT, full_name TEXT, Age INTEGER, Email TEXT)');
    
    // 3. Initialize Context
    Context := TDbContext.Create(
      TFireDACConnection.Create(FDConn, False), // Don't own FDConn
      TSQLiteDialect.Create
    );
    try
      // 4. Insert Data
      WriteLn('📝 Inserting sample users...');
      
      User := TUser.Create;
      User.Name := 'Alice';
      User.Age := 25;
      User.Email := 'alice@dext.com';
      Context.Entities<TUser>.Add(User);
      
      User := TUser.Create;
      User.Name := 'Bob';
      User.Age := 17; // Minor
      User.Email := 'bob@dext.com';
      Context.Entities<TUser>.Add(User);
      
      User := TUser.Create;
      User.Name := 'Charlie';
      User.Age := 30;
      User.Email := 'charlie@dext.com';
      Context.Entities<TUser>.Add(User);
      
      WriteLn('   Users inserted successfully.');
      WriteLn;
      
      // 5. Query using Specification
      WriteLn('🔍 Querying Adult Users (Age >= 18) using Specification...');
      
      Users := Context.Entities<TUser>.List(TAdultUsersSpec.Create);
      try
        for User in Users do
        begin
          WriteLn(Format('   - [%d] %s (Age: %d)', [User.Id, User.Name, User.Age]));
        end;
        
        WriteLn;
        if Users.Count = 2 then
          WriteLn('   ✅ Success! Found exactly 2 adult users.')
        else
          WriteLn('   ❌ Error! Expected 2 users, found ' + IntToStr(Users.Count));
          
      finally
        Users.Free;
      end;
      
    finally
      Context.Free; // Manual lifecycle management
    end;
    
  finally
    FDConn.Free;
  end;
end;

begin
  try
    RunDemo;
    ReadLn;
  except
    on E: Exception do
      Writeln('❌ Error: ', E.ClassName, ': ', E.Message);
  end;
end.
