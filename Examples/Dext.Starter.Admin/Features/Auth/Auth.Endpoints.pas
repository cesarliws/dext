unit Auth.Endpoints;

interface

uses
  Dext,
  Dext.Web,
  Auth.Service,
  User, 
  Admin.Utils,
  System.Classes, 
  System.IOUtils, 
  System.SysUtils;

type
  TAuthEndpoints = class
  public
    class procedure Map(App: TDextAppBuilder);
  end;

implementation

uses
  Dext.Web.Interfaces, 
  Dext.Web.HandlerInvoker,
  Dext.Web.Results, // Added
  Auth.Dto;

{ TAuthEndpoints }

class procedure TAuthEndpoints.Map(App: TDextAppBuilder);
begin
  App.MapGet('/auth/login',
    procedure(Context: IHttpContext)
    begin
      Results.HtmlFromFile('login.html').Execute(Context);
    end);

  // POST /auth/login - Handle login
  // Fully injected services + DTO + Standardized IResult return
  App.MapPost<IAuthService, IJwtTokenHandler, TLoginDto, IResult>('/auth/login',
    function(AuthService: IAuthService; JwtHandler: IJwtTokenHandler; Dto: TLoginDto): IResult
    var
      Claims: TArray<TClaim>;
      Token: string;
      User: TUser;
    begin
      User := AuthService.ValidateUser(Dto.Username, Dto.Password);
      
      if User <> nil then
      begin
        // Create claims
        Claims := TClaimsBuilder.Create
          .WithNameIdentifier(IntToStr(User.Id))
          .WithName(User.Username)
          .WithRole(User.Role)
          .Build;
        
        // Generate JWT token
        Token := JwtHandler.GenerateToken(Claims);
        
        // Return JSON with token
        Result := Results.Json(Format('{"token":"%s","username":"%s","role":"%s","expiresIn":3600}', 
          [Token, User.Username, User.Role]));
      end
      else
      begin
        Result := Results.Json('{"error":"Invalid credentials"}', 401);
      end;
    end);
    
  App.MapPost<IResult>('/auth/logout',
    function: IResult
    begin
      // Token removal happens on frontend (localStorage.clear())
      Result := Results.Json('{"message":"Logged out successfully"}');
    end);
end;

end.
