unit Dext.Entity.Naming.Test;

interface

uses
  System.SysUtils,
  System.Rtti,
  Dext.Entity.Naming;

type
  // Mock classes for testing
  TUser = class
  end;

  TUserAccount = class
  end;

  THTTPLogEntry = class
  end;

  TNamingStrategyTest = class
  private
    FCtx: TRttiContext;
    procedure AssertEqual(const Expected, Actual, Msg: string);
    procedure Log(const Msg: string);
  protected
    function GetProp(AClass: TClass; const APropName: string): TRttiProperty;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Run;
  end;

implementation

{ TNamingStrategyTest }

constructor TNamingStrategyTest.Create;
begin
  FCtx := TRttiContext.Create;
end;

destructor TNamingStrategyTest.Destroy;
begin
  FCtx.Free;
  inherited;
end;

procedure TNamingStrategyTest.Log(const Msg: string);
begin
  WriteLn(Msg);
end;

procedure TNamingStrategyTest.AssertEqual(const Expected, Actual, Msg: string);
begin
  if Expected = Actual then
    WriteLn('   ✅ ', Msg)
  else
  begin
    WriteLn('   ❌ ', Msg);
    WriteLn('      Expected: ', Expected);
    WriteLn('      Actual:   ', Actual);
  end;
end;

function TNamingStrategyTest.GetProp(AClass: TClass; const APropName: string): TRttiProperty;
begin
  // We don't have real properties on mock classes, so we mock the expectation or use a real class with props.
  // For simplicity, we will test the strategy methods directly with strings if possible, 
  // but the interface requires TRttiProperty.
  // Let's create a dummy class with properties.
  Result := nil; 
end;

type
  TDummyEntity = class
  private
    FId: Integer;
    FUserName: string;
    FEmailAddress: string;
    FIsActive: Boolean;
  public
    property Id: Integer read FId;
    property UserName: string read FUserName;
    property EmailAddress: string read FEmailAddress;
    property IsActive: Boolean read FIsActive;
  end;

procedure TNamingStrategyTest.Run;
var
  Strategy: INamingStrategy;
  Typ: TRttiType;
  P_UserName, P_EmailAddress, P_IsActive: TRttiProperty;
begin
  Log('🏷️ Testing Naming Strategies');
  Log('===========================');

  Typ := FCtx.GetType(TDummyEntity);
  P_UserName := Typ.GetProperty('UserName');
  P_EmailAddress := Typ.GetProperty('EmailAddress');
  P_IsActive := Typ.GetProperty('IsActive');

  // 1. Default Strategy
  Log('🔹 Default Strategy');
  Strategy := TDefaultNamingStrategy.Create;
  AssertEqual('User', Strategy.GetTableName(TUser), 'TUser -> User');
  AssertEqual('UserAccount', Strategy.GetTableName(TUserAccount), 'TUserAccount -> UserAccount');
  AssertEqual('UserName', Strategy.GetColumnName(P_UserName), 'UserName -> UserName');
  
  // 2. Snake Case Strategy
  Log('🔹 Snake Case Strategy');
  Strategy := TSnakeCaseNamingStrategy.Create;
  AssertEqual('user', Strategy.GetTableName(TUser), 'TUser -> user');
  AssertEqual('user_account', Strategy.GetTableName(TUserAccount), 'TUserAccount -> user_account');
  AssertEqual('http_log_entry', Strategy.GetTableName(THTTPLogEntry), 'THTTPLogEntry -> http_log_entry');
  
  AssertEqual('user_name', Strategy.GetColumnName(P_UserName), 'UserName -> user_name');
  AssertEqual('email_address', Strategy.GetColumnName(P_EmailAddress), 'EmailAddress -> email_address');
  AssertEqual('is_active', Strategy.GetColumnName(P_IsActive), 'IsActive -> is_active');

  // 3. Lower Case Strategy
  Log('🔹 Lower Case Strategy');
  Strategy := TLowerCaseNamingStrategy.Create;
  AssertEqual('user', Strategy.GetTableName(TUser), 'TUser -> user');
  AssertEqual('useraccount', Strategy.GetTableName(TUserAccount), 'TUserAccount -> useraccount');
  AssertEqual('username', Strategy.GetColumnName(P_UserName), 'UserName -> username');

  // 4. Upper Case Strategy
  Log('🔹 Upper Case Strategy');
  Strategy := TUppercaseNamingStrategy.Create;
  AssertEqual('USER', Strategy.GetTableName(TUser), 'TUser -> USER');
  AssertEqual('USERACCOUNT', Strategy.GetTableName(TUserAccount), 'TUserAccount -> USERACCOUNT');
  AssertEqual('USERNAME', Strategy.GetColumnName(P_UserName), 'UserName -> USERNAME');
end;

end.
