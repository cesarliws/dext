unit Sales.Auth;

{***************************************************************************}
{                                                                           }
{           Sales System - Authentication Module                            }
{                                                                           }
{           Provides JWT authentication services and DTOs                   }
{                                                                           }
{***************************************************************************}

interface

uses
  System.SysUtils,
  Dext.Auth.JWT,
  Dext, Dext.DI.Interfaces,
  Dext.Web;

type
  { Authentication DTOs }
  TLoginRequest = record
    username: string;
    password: string;
  end;

  TLoginResponse = record
    token: string;
  end;

  { Authentication Service Interface }

  IAuthService = interface
    ['{6FAF8D72-1234-4567-8901-ABCDEF123456}']
    function Login(const User, Pass: string): string;
  end;

  { Authentication Service Implementation }
  TAuthService = class(TInterfacedObject, IAuthService)
  private
    FJwtHandler: TJwtTokenHandler;
  public
    constructor Create(const Secret: string);
    destructor Destroy; override;
    function Login(const User, Pass: string): string;
  end;

  { Authentication Configuration Helper }
  TAuthConfig = class
  public
    const JWT_SECRET = 'my-super-secret-key-for-sales-system-minimum-32-chars';
    
    /// <summary>
    ///   Registers authentication services in the DI container.
    /// </summary>
    class procedure AddServices(const Services: TDextServices); static;
  end;

implementation

{ TAuthService }

constructor TAuthService.Create(const Secret: string);
begin
  FJwtHandler := TJwtTokenHandler.Create(Secret, 'SalesApi', 'SalesClient', 60);
end;

destructor TAuthService.Destroy;
begin
  FJwtHandler.Free;
  inherited;
end;

function TAuthService.Login(const User, Pass: string): string;
var
  Claims: TArray<TClaim>;
begin
  if (User = 'admin') and (Pass = 'admin') then
  begin
    Claims := TClaimsBuilder.Create
      .WithName(User)
      .WithRole('Admin')
      .Build;
    Result := FJwtHandler.GenerateToken(Claims);
  end
  else
    Result := '';
end;

{ TAuthConfig }

class procedure TAuthConfig.AddServices(const Services: TDextServices);
begin
  Services.AddSingleton<IAuthService, TAuthService>(
    function(P: IServiceProvider): TObject
    begin
      Result := TAuthService.Create(JWT_SECRET);
    end);
end;

end.
