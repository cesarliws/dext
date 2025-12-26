program TestMapper;

{$APPTYPE CONSOLE}

uses
  Dext.MM,
  System.Rtti,
  System.SysUtils,
  System.Generics.Collections,
  Dext.Mapper,
  DUnitX.TestFramework;

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

  // DTO - Record
  TUserDTORec = record
    Id: Integer;
    FirstName: string;
    LastName: string;
    Email: string;
    PasswordHash: string;
    Age: Integer;
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

procedure TestRecordToModelPartialUpdate;
var
  UserDTO: TUserDTORec;
  User: TUser;
begin
  WriteLn('=== Test 4: Record To Model Partial Update ===');

  User := TUser.Create;
  try
    User.Id := 1;
    User.FirstName := 'User';
    User.LastName := 'Test';
    User.Email := 'user@test.com';
    User.Age := 20;

    // Request with ONLY name changed
    FillChar(UserDTO, SizeOf(UserDTO), 0);
    UserDTO.LastName := 'Updated LastName';

    TMapper.Map<TUserDTORec, TUser>(UserDTO, User, True);

    Assert.AreEqual('Updated LastName', User.LastName);

    Assert.AreEqual('User', User.FirstName); // Should not change
    Assert.AreEqual('user@test.com', User.Email); // Should not change
    Assert.AreEqual(20, User.Age); // Should not change

    WriteLn('✓ Record To Model Partial Update OK');
  finally
    User.Free;
  end;
  WriteLn;
end;

procedure TestModelToRecordPartialUpdate;
var
  UserDTO: TUserDTORec;
  User: TUser;
begin
  WriteLn('=== Test 5: Model To Record Partial Update ===');

  User := TUser.Create;
  try
    FillChar(UserDTO, SizeOf(UserDTO), 0);
    UserDTO.Id := 1;
    UserDTO.FirstName := 'User';
    UserDTO.LastName := 'Test';
    UserDTO.Email := 'user@test.com';
    UserDTO.Age := 20;

    // Request with ONLY name changed
    User.LastName := 'Updated LastName';

    TMapper.Map<TUser, TUserDTORec>(User, UserDTO, True);

    Assert.AreEqual('Updated LastName', UserDTO.LastName);

    Assert.AreEqual('User', UserDTO.FirstName); // Should not change
    Assert.AreEqual('user@test.com', UserDTO.Email); // Should not change
    Assert.AreEqual(20, UserDTO.Age); // Should not change

    WriteLn('✓ Model To Record Partial Update OK');
  finally
    User.Free;
  end;
  WriteLn;
end;

procedure TestRecordToModelFullUpdate;
var
  Request: TUserDTORec;
  User: TUser;
begin
  WriteLn('=== Test 6: Record To Model Full Update ===');

  Request.FirstName := 'User';
  Request.LastName := 'Test';
  Request.Email := 'user@test.com';
  Request.PasswordHash := '123';
  Request.Age := 20;

  User := TUser.Create;
  try
    TMapper.Map<TUserDTORec, TUser>(Request, User);

    Assert.AreEqual(Request.FirstName, User.FirstName);
    Assert.AreEqual(Request.LastName, User.LastName);
    Assert.AreEqual(Request.Email, User.Email);
    Assert.AreEqual(Request.PasswordHash, User.PasswordHash);
    Assert.AreEqual(Request.Age, User.Age);

    WriteLn('✓ Record To Model Full Update OK');
  finally
    User.Free;
  end;
  WriteLn;
end;

procedure TestModelToRecordFullUpdate;
var
  DTO: TUserDTORec;
  User: TUser;
begin
  WriteLn('=== Test 7: Model To Record FullUpdate ===');

  User := TUser.Create;
  try
    User.FirstName := 'User';
    User.LastName := 'Test';
    User.Email := 'user@test.com';
    User.PasswordHash := '123';
    User.Age := 20;

    TMapper.Map<TUser, TUserDTORec>(User, DTO);

    Assert.AreEqual(User.FirstName, DTO.FirstName);
    Assert.AreEqual(User.LastName, DTO.LastName);
    Assert.AreEqual(User.Email, DTO.Email);
    Assert.AreEqual(User.PasswordHash, DTO.PasswordHash);
    Assert.AreEqual(User.Age, DTO.Age);

    WriteLn('✓ Model To Record Full Update OK');
  finally
    User.Free;
  end;
  WriteLn;
end;

procedure TestListRecordToModelMapping;
var
  Users: TList<TUser>;
  DTOs: TList<TUserDTORec>;
  User: TUser;
  DTO: TUserDTORec;
begin
  WriteLn('=== Test 8: List Record To Model Mapping ===');

  DTOs := TList<TUserDTORec>.Create;
  try
    // Create 3 users
    for var I := 1 to 3 do
    begin
      FillChar(DTO, SizeOf(DTO), 0);
      DTO.Id := I;
      DTO.FirstName := 'User' + I.ToString;
      DTO.LastName := 'Test';
      DTO.Email := 'user' + I.ToString + '@test.com';
      DTO.Age := 20 + I;
      DTOs.Add(DTO);
    end;

    Users := TMapper.MapList<TUserDTORec, TUser>(DTOs);
    try
      WriteLn('Mapped ', Users.Count, ' users:');
      for User in Users do
        WriteLn('  - ', User.FirstName, ' (', User.Email, ')');
      WriteLn('✓ List Record To Model Mapping OK');
    finally
      for User in Users do
        User.Free;
      Users.Free;
    end;
  finally
  end;
  WriteLn;
end;

procedure TestListModelToRecordMapping;
var
  Users: TList<TUser>;
  DTOs: TList<TUserDTORec>;
  User: TUser;
  DTO: TUserDTORec;
begin
  WriteLn('=== Test 9: List Model To Record Mapping ===');

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

    DTOs := TMapper.MapList<TUser, TUserDTORec>(Users);
    try
      WriteLn('Mapped ', DTOs.Count, ' users:');
      for DTO in DTOs do
        WriteLn('  - ', DTO.FirstName, ' (', DTO.Email, ')');
      WriteLn('✓ List Model To Record Mapping OK');
    finally
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
    TestRecordToModelPartialUpdate;
    TestModelToRecordPartialUpdate;
    TestRecordToModelFullUpdate;
    TestModelToRecordFullUpdate;
    TestListRecordToModelMapping;
    TestListModelToRecordMapping;
    
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
