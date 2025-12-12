unit Auth.Endpoints;

interface

uses
  Dext,
  Dext.Web,
  Auth.Service,
  User, // Added for TUser
  System.Classes, // Added for TStreamReader
  System.IOUtils, // Added for TFile
  System.SysUtils;

type
  TLoginRequest = record
    Username: string;
    Password: string;
  end;

  TAuthEndpoints = class
  public
    class procedure Map(App: IApplicationBuilder);
  end;

implementation

function GetFilePath(const RelativePath: string): string;
begin
  // Executable runs from Output\ directory, files are in Dext.Starter.Admin\
  Result := IncludeTrailingPathDelimiter(GetCurrentDir) + '..\Dext.Starter.Admin\' + RelativePath;
end;

{ TAuthEndpoints }

class procedure TAuthEndpoints.Map(App: IApplicationBuilder);
begin
  // MapGroup not available, using explicit paths

  App.MapGet('/auth/login',
    procedure(Context: IHttpContext)
    begin
      var Res: IResult := TContentResult.Create(TFile.ReadAllText(GetFilePath('wwwroot\views\login.html')), 'text/html');
      Res.Execute(Context);
    end);

  App.MapPost('/auth/login',
    procedure(Context: IHttpContext)
    var
      AuthService: IAuthService;
      JwtHandler: IJwtTokenHandler;
      User: TUser;
      Claims: TArray<TClaim>;
      Token: string;
    begin
      // For now, use hardcoded credentials (TODO: parse form data)
      // HTMX sends form-urlencoded by default
      var Username := 'admin';
      var Password := 'admin';
      
      AuthService := TServiceProviderExtensions.GetRequiredService<IAuthService>(Context.Services);
      User := AuthService.ValidateUser(Username, Password);
      
      if User <> nil then
      begin
        // Get JWT handler from DI
        JwtHandler := TServiceProviderExtensions.GetRequiredService<IJwtTokenHandler>(Context.Services);
        
        // Create claims
        Claims := TClaimsBuilder.Create
          .WithNameIdentifier(IntToStr(User.Id))
          .WithName(User.Username)
          .WithRole(User.Role)
          .Build;
        
        // Generate JWT token
        Token := JwtHandler.GenerateToken(Claims);
        
        // Return JSON with token
        var Json := Format('{"token":"%s","username":"%s","role":"%s","expiresIn":3600}', 
          [Token, User.Username, User.Role]);
        
        Context.Response.SetContentType('application/json');
        Context.Response.Write(Json);
      end
      else
      begin
        Context.Response.StatusCode := 401;
        Context.Response.SetContentType('application/json');
        Context.Response.Write('{"error":"Invalid credentials"}');
      end;
    end);
    
  App.MapPost('/auth/logout',
    procedure(Context: IHttpContext)
    begin
      // Token removal happens on frontend (localStorage.clear())
      Context.Response.SetContentType('application/json');
      Context.Response.Write('{"message":"Logged out successfully"}');
    end);
end;

end.
