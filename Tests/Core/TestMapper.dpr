program TestMapper;

{$APPTYPE CONSOLE}

uses
  Dext.MM,
  System.Rtti,
  System.SysUtils,
  System.Generics.Collections,
  Dext.Mapper;

type
  // Domain Entity
  TUser = class
  private
    FId: Integer;
    FFirstName: string;
    FLastName: string;
    FEmail: string;
    FPasswordHash: string;
    FAge: Integer;
  public
    property Id: Integer read FId write FId;
    property FirstName: string read FFirstName write FFirstName;
    property LastName: string read FLastName write FLastName;
    property Email: string read FEmail write FEmail;
    property PasswordHash: string read FPasswordHash write FPasswordHash;
    property Age: Integer read FAge write FAge;
  end;

  // DTO
  TUserDTO = class
  private
    FId: Integer;
    FFullName: string;
    FEmail: string;
    FAge: Integer;
  public
    property Id: Integer read FId write FId;
    property FullName: string read FFullName write FFullName;
    property Email: string read FEmail write FEmail;
    property Age: Integer read FAge write FAge;
  end;

procedure TestBasicMapping;
var
  User: TUser;
  DTO: TUserDTO;
begin
  WriteLn('=== Test 1: Basic Mapping ===');
  
  User := TUser.Create;
  try
    User.Id := 1;
    User.FirstName := 'John';
    User.LastName := 'Doe';
    User.Email := 'john@example.com';
    User.Age := 30;
    
    DTO := TMapper.Map<TUser, TUserDTO>(User);
    try
      WriteLn('ID: ', DTO.Id);
      WriteLn('Email: ', DTO.Email);
      WriteLn('Age: ', DTO.Age);
      WriteLn('FullName (should be empty): ', DTO.FullName);
      WriteLn('✓ Basic mapping OK');
    finally
      DTO.Free;
    end;
  finally
    User.Free;
  end;
  WriteLn;
end;

procedure TestCustomMapping;
var
  User: TUser;
  DTO: TUserDTO;
begin
  WriteLn('=== Test 2: Custom Mapping ===');
  
  // Configure custom mapping
  TMapper.CreateMap<TUser, TUserDTO>
    .ForMember('FullName', 
      function(const Src: TUser): TValue
      begin
        Result := Src.FirstName + ' ' + Src.LastName;
      end);
  
  User := TUser.Create;
  try
    User.Id := 2;
    User.FirstName := 'Jane';
    User.LastName := 'Smith';
    User.Email := 'jane@example.com';
    User.Age := 25;
    
    DTO := TMapper.Map<TUser, TUserDTO>(User);
    try
      WriteLn('ID: ', DTO.Id);
      WriteLn('FullName: ', DTO.FullName);
      WriteLn('Email: ', DTO.Email);
      WriteLn('Age: ', DTO.Age);
      WriteLn('✓ Custom mapping OK');
    finally
      DTO.Free;
    end;
  finally
    User.Free;
  end;
  WriteLn;
end;

procedure TestListMapping;
var
  Users: TList<TUser>;
  DTOs: TList<TUserDTO>;
  User: TUser;
  DTO: TUserDTO;
begin
  WriteLn('=== Test 3: List Mapping ===');
  
  Users := TList<TUser>.Create;
  try
    // Create 3 users
    for var I := 1 to 3 do
    begin
      User := TUser.Create;
      User.Id := I;
      User.FirstName := 'User' + I.ToString;
      User.LastName := 'Test';
      User.Email := 'user' + I.ToString + '@test.com';
      User.Age := 20 + I;
      Users.Add(User);
    end;
    
    DTOs := TMapper.MapList<TUser, TUserDTO>(Users);
    try
      WriteLn('Mapped ', DTOs.Count, ' users:');
      for DTO in DTOs do
        WriteLn('  - ', DTO.FullName, ' (', DTO.Email, ')');
      WriteLn('✓ List mapping OK');
    finally
      for DTO in DTOs do
        DTO.Free;
      DTOs.Free;
    end;
  finally
    for User in Users do
      User.Free;
    Users.Free;
  end;
  WriteLn;
end;

begin
  try
    WriteLn('Dext AutoMapper Tests');
    WriteLn('=====================');
    WriteLn;
    
    TestBasicMapping;
    TestCustomMapping;
    TestListMapping;
    
    WriteLn('=====================');
    WriteLn('All tests passed!');
  except
    on E: Exception do
    begin
      WriteLn('ERROR: ', E.Message);
      ExitCode := 1;
    end;
  end;
  
  WriteLn;
  WriteLn('Press ENTER to exit...');
  ReadLn;
end.
