unit Auth.Service;

interface

uses
  Dext,
  Dext.Persistence,
  DbContext,
  User,
  System.SysUtils,
  System.Hash;

type
  IAuthService = interface
    ['{6962A5FC-1175-4F8A-850E-123456789ABC}']
    function ValidateUser(const Username, Password: string): TUser;
  end;

  TAuthService = class(TInterfacedObject, IAuthService)
  private
    FDbContext: TAppDbContext;
  public
    constructor Create(DbContext: TAppDbContext);
    function ValidateUser(const Username, Password: string): TUser;
  end;

implementation

uses
  Dext.Specifications.Interfaces; // Correct unit

{ TAuthService }

constructor TAuthService.Create(DbContext: TAppDbContext);
begin
  FDbContext := DbContext;
end;

function TAuthService.ValidateUser(const Username, Password: string): TUser;
var
  PasswordHash: string;
begin
  // Hash the password for comparison
  PasswordHash := THashSHA2.GetHashString(Password);
  
  // Using Entities<TUser> with Expression for SQL translation
  Result := FDbContext.Entities<TUser>.FirstOrDefault(
    (Prop('Username') = Username) and (Prop('PasswordHash') = PasswordHash)
  );
end;

end.
