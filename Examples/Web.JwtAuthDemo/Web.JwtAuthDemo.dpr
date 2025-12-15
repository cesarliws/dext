program Web.JwtAuthDemo;

{$APPTYPE CONSOLE}

uses
  Dext.MM,
  System.SysUtils,
  System.DateUtils,
  System.Rtti,
  Dext.Web.WebApplication,
  Dext.DI.Extensions,
  Dext.Web.Interfaces,
  Dext.Web.ApplicationBuilder.Extensions,
  Dext.Web.Results,
  Dext.Auth.JWT,
  Dext.Auth.Identity,
  Dext.Auth.Middleware,
  Dext.Auth.Attributes,
  Dext.Web.HandlerInvoker;

type
  // DTO for login
  TLoginRequest = record
    Username: string;
    Password: string;
  end;

var
  App: IWebApplication;
  JwtHandler: TJwtTokenHandler;
  SecretKey: string;

begin

  try
    WriteLn('Dext JWT Authentication Demo');
    WriteLn('================================');
    WriteLn;

    // Secret key for signing tokens (in production, use a strong key and store securely)
    SecretKey := 'my-super-secret-key-change-this-in-production';

    // Create global JWT handler (reusable)
    JwtHandler := TJwtTokenHandler.Create(SecretKey, 'DextAuthDemo', 'DextAPI', 60);

    App := TDextApplication.Create;
    var Builder := App.GetApplicationBuilder;

    // 1. JWT Authentication Middleware
    WriteLn('[*] Configuring JWT Authentication Middleware...');
    TApplicationBuilderJwtExtensions.UseJwtAuthentication(Builder, TJwtOptions.Create(SecretKey));
    WriteLn('   [OK] JWT middleware registered');
    WriteLn;

    // 2. Login Endpoint (public - generates token)
    WriteLn('[*] Registering public endpoints...');
    TApplicationBuilderExtensions.MapPostR<TLoginRequest, IResult>(Builder, '/api/auth/login',
      function(Request: TLoginRequest): IResult
      var
        Claims: TArray<TClaim>;
        Token: string;
      begin
        WriteLn(Format('[*] Login attempt: %s', [Request.Username]));

        // Simple validation (in production, validate against database)
        if (Request.Username = 'admin') and (Request.Password = 'password') then
        begin
          // Create claims using fluent builder
          Claims := TClaimsBuilder.Create
            .WithNameIdentifier('123')
            .WithName(Request.Username)
            .WithRole('Admin')
            .WithEmail('admin@example.com')
            .Build;

          // Generate token
          Token := JwtHandler.GenerateToken(Claims);

          WriteLn('   [OK] Login successful');
          Result := Results.Ok(Format('{"token":"%s","expiresIn":3600}', [Token]));
        end
        else
        begin
          WriteLn('   [ERROR] Invalid credentials');
          Result := Results.BadRequest('{"error":"Invalid username or password"}');
        end;
      end);

    // 3. Protected Endpoint (requires authentication)
    WriteLn('[*] Registering protected endpoints...');
    TApplicationBuilderExtensions.MapGetR<IHttpContext, IResult>(Builder, '/api/protected',
      function(Context: IHttpContext): IResult
      var
        User: IClaimsPrincipal;
        UserName: string;
        UserId: string;
      begin
        User := Context.User;

        // Check if authenticated
        if (User = nil) or not User.Identity.IsAuthenticated then
        begin
          WriteLn('   [ERROR] Unauthorized access attempt');
          Result := Results.StatusCode(401, '{"error":"Unauthorized"}');
          Exit;
        end;

        // Extract user information
        UserName := User.Identity.Name;
        UserId := User.FindClaim(TClaimTypes.NameIdentifier).Value;

        WriteLn(Format('   [OK] Authorized access: %s (ID: %s)', [UserName, UserId]));

        Result := Results.Ok(Format(
          '{"message":"This is protected data","userId":"%s","username":"%s","timestamp":"%s"}',
          [UserId, UserName, DateTimeToStr(Now)]
        ));
      end);

    // 4. Admin Endpoint (requires specific role)
    TApplicationBuilderExtensions.MapGetR<IHttpContext, IResult>(Builder, '/api/admin',
      function(Context: IHttpContext): IResult
      var
        User: IClaimsPrincipal;
      begin
        User := Context.User;

        // Check authentication
        if (User = nil) or not User.Identity.IsAuthenticated then
        begin
          Result := Results.StatusCode(401, '{"error":"Unauthorized"}');
          Exit;
        end;

        // Check role
        if not User.IsInRole('Admin') then
        begin
          WriteLn(Format('   [ERROR] Forbidden: %s is not an Admin', [User.Identity.Name]));
          Result := Results.StatusCode(403, '{"error":"Forbidden - Admin role required"}');
          Exit;
        end;

        WriteLn(Format('   [OK] Admin access granted: %s', [User.Identity.Name]));
        Result := Results.Ok('{"message":"Welcome, Admin!"}');
      end);

    // 5. Public Endpoint (no authentication)
    TApplicationBuilderExtensions.MapGetR<IResult>(Builder, '/api/public',
      function: IResult
      begin
        WriteLn('   [*] Public endpoint accessed');
        Result := Results.Ok('{"message":"This is public data, no authentication required"}');
      end);

    WriteLn;
    WriteLn('[OK] All endpoints configured');
    WriteLn;
    WriteLn('=========================================');
    WriteLn('Server running on http://localhost:8080');
    WriteLn('=========================================');
    WriteLn;
    WriteLn('Test Commands:');
    WriteLn;
    WriteLn('# 1. Login (get JWT token)');
    WriteLn('curl -X POST http://localhost:8080/api/auth/login ^');
    WriteLn('  -H "Content-Type: application/json" ^');
    WriteLn('  -d "{\"username\":\"admin\",\"password\":\"password\"}"');
    WriteLn;
    WriteLn('# 2. Access public endpoint (no auth required)');
    WriteLn('curl http://localhost:8080/api/public');
    WriteLn;
    WriteLn('# 3. Access protected endpoint (requires token)');
    WriteLn('# Replace YOUR_TOKEN with the token from step 1');
    WriteLn('curl http://localhost:8080/api/protected ^');
    WriteLn('  -H "Authorization: Bearer YOUR_TOKEN"');
    WriteLn;
    WriteLn('# 4. Access admin endpoint (requires Admin role)');
    WriteLn('curl http://localhost:8080/api/admin ^');
    WriteLn('  -H "Authorization: Bearer YOUR_TOKEN"');
    WriteLn;
    WriteLn('# 5. Try accessing protected without token (should fail)');
    WriteLn('curl http://localhost:8080/api/protected');
    WriteLn;
    WriteLn('=========================================');
    WriteLn('Press Enter to stop the server...');
    WriteLn;

    App.Run(8080);
    ReadLn;

    JwtHandler.Free;

    WriteLn;
    WriteLn('[OK] Server stopped successfully');

  except
    on E: Exception do
    begin
      WriteLn('[ERROR] ', E.Message);
      WriteLn('Press Enter to exit...');
      ReadLn;
    end;
  end;
end.
