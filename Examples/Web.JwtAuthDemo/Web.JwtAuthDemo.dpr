program Web.JwtAuthDemo;

{$APPTYPE CONSOLE}

uses
  FastMM5,
  System.SysUtils,
  System.DateUtils,
  System.Rtti,
  Dext.Core.WebApplication,
  Dext.DI.Extensions,
  Dext.Web.Interfaces,
  Dext.Core.ApplicationBuilder.Extensions,
  Dext.Web.Results,
  Dext.Auth.JWT,
  Dext.Auth.Identity,
  Dext.Auth.Middleware,
  Dext.Auth.Attributes,
  Dext.Web.HandlerInvoker;

type
  // DTO para login
  TLoginRequest = record
    Username: string;
    Password: string;
  end;

  // DTO para dados protegidos
  TProtectedData = record
    Message: string;
    UserId: string;
    Timestamp: string;
  end;

var
  App: IWebApplication;
  JwtHandler: TJwtTokenHandler;
  SecretKey: string;

begin
  ReportMemoryLeaksOnShutdown := True;

  try
    WriteLn('🔐 Dext JWT Authentication Demo');
    WriteLn('================================');
    WriteLn;

    // Secret key para assinar tokens (em produção, use uma chave forte e armazene com segurança)
    SecretKey := 'my-super-secret-key-change-this-in-production';

    // Criar handler JWT global (reutilizável)
    JwtHandler := TJwtTokenHandler.Create(SecretKey, 'DextAuthDemo', 'DextAPI', 60);

    App := TDextApplication.Create;
    var Builder := App.GetApplicationBuilder;

    // ✅ 1. Middleware de Autenticação JWT
    // ✅ 1. Middleware de Autenticação JWT
    WriteLn('📦 Configuring JWT Authentication Middleware...');
    TApplicationBuilderJwtExtensions.UseJwtAuthentication(Builder, TJwtOptions.Create(SecretKey));
    WriteLn('   ✅ JWT middleware registered');
    WriteLn;

    // ✅ 2. Endpoint de Login (público - gera token)
    WriteLn('🔓 Registering public endpoints...');
    TApplicationBuilderExtensions.MapPostR<TLoginRequest, IResult>(Builder, '/api/auth/login',
      THandlerFunc<TLoginRequest, IResult>(function(Request: TLoginRequest): IResult
      var
        Claims: TArray<TClaim>;
        Token: string;
      begin
        WriteLn(Format('🔑 Login attempt: %s', [Request.Username]));

        // Validação simples (em produção, valide contra banco de dados)
        if (Request.Username = 'admin') and (Request.Password = 'password') then
        begin
          // ✅ Criar claims usando fluent builder
          Claims := TClaimsBuilder.Create
            .WithNameIdentifier('123')
            .WithName(Request.Username)
            .WithRole('Admin')
            .WithEmail('admin@example.com')
            .Build;

          // Gerar token
          Token := JwtHandler.GenerateToken(Claims);

          WriteLn('   ✅ Login successful');
          Result := Results.Ok(Format('{"token":"%s","expiresIn":3600}', [Token]));
        end
        else
        begin
          WriteLn('   ❌ Invalid credentials');
          Result := Results.BadRequest('{"error":"Invalid username or password"}');
        end;
      end));

    // ✅ 3. Endpoint Protegido (requer autenticação)
    WriteLn('🔒 Registering protected endpoints...');
    TApplicationBuilderExtensions.MapGetR<IHttpContext, IResult>(Builder, '/api/protected',
      THandlerFunc<IHttpContext, IResult>(function(Context: IHttpContext): IResult
      var
        User: IClaimsPrincipal;
        UserName: string;
        UserId: string;
      begin
        User := Context.User;

        // Verificar se está autenticado
        if (User = nil) or not User.Identity.IsAuthenticated then
        begin
          WriteLn('   ❌ Unauthorized access attempt');
          Result := Results.StatusCode(401, '{"error":"Unauthorized"}');
          Exit;
        end;

        // Extrair informações do usuário
        UserName := User.Identity.Name;
        UserId := User.FindClaim(TClaimTypes.NameIdentifier).Value;

        WriteLn(Format('   ✅ Authorized access: %s (ID: %s)', [UserName, UserId]));

        Result := Results.Ok(Format(
          '{"message":"This is protected data","userId":"%s","username":"%s","timestamp":"%s"}',
          [UserId, UserName, DateTimeToStr(Now)]
        ));
      end));

    // ✅ 4. Endpoint Admin (requer role específica)
    TApplicationBuilderExtensions.MapGetR<IHttpContext, IResult>(Builder, '/api/admin',
      THandlerFunc<IHttpContext, IResult>(function(Context: IHttpContext): IResult
      var
        User: IClaimsPrincipal;
      begin
        User := Context.User;

        // Verificar autenticação
        if (User = nil) or not User.Identity.IsAuthenticated then
        begin
          Result := Results.StatusCode(401, '{"error":"Unauthorized"}');
          Exit;
        end;

        // Verificar role
        if not User.IsInRole('Admin') then
        begin
          WriteLn(Format('   ❌ Forbidden: %s is not an Admin', [User.Identity.Name]));
          Result := Results.StatusCode(403, '{"error":"Forbidden - Admin role required"}');
          Exit;
        end;

        WriteLn(Format('   ✅ Admin access granted: %s', [User.Identity.Name]));
        Result := Results.Ok('{"message":"Welcome, Admin!"}');
      end));

    // ✅ 5. Endpoint Público (sem autenticação)
    TApplicationBuilderExtensions.MapGetR<IResult>(Builder, '/api/public',
      THandlerFunc<IResult>(function: IResult
      begin
        WriteLn('   📖 Public endpoint accessed');
        Result := Results.Ok('{"message":"This is public data, no authentication required"}');
      end));

    WriteLn;
    WriteLn('✅ All endpoints configured');
    WriteLn;
    WriteLn('═══════════════════════════════════════════');
    WriteLn('🌐 Server running on http://localhost:8080');
    WriteLn('═══════════════════════════════════════════');
    WriteLn;
    WriteLn('📝 Test Commands:');
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
    WriteLn('═══════════════════════════════════════════');
    WriteLn('Press Enter to stop the server...');
    WriteLn;

    App.Run(8080);
    ReadLn;

    JwtHandler.Free;

    WriteLn;
    WriteLn('✅ Server stopped successfully');

  except
    on E: Exception do
    begin
      WriteLn('❌ Error: ', E.Message);
      WriteLn('Press Enter to exit...');
      ReadLn;
    end;
  end;
end.

