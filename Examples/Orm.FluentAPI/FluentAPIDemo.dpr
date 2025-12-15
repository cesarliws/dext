program FluentAPIDemo;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Rtti,
  Dext.Web.Cors in '..\Sources\Core\Dext.Web.Cors.pas',
  Dext.Auth.JWT in '..\Sources\Core\Dext.Auth.JWT.pas',
  Dext.Auth.Middleware in '..\Sources\Core\Dext.Auth.Middleware.pas';

procedure DemoCorsBuilder;
var
  Builder: TCorsBuilder;
  Options: TCorsOptions;
begin
  WriteLn('=== CORS Builder Demo ===');
  WriteLn;
  
  Builder := TCorsBuilder.Create;
  try
    Options := Builder
      .WithOrigins(['http://localhost:5173', 'https://myapp.com'])
      .WithMethods(['GET', 'POST', 'PUT', 'DELETE'])
      .WithHeaders(['Content-Type', 'Authorization'])
      .AllowCredentials
      .WithMaxAge(3600)
      .Build;
    
    WriteLn('✅ CORS Options Created:');
    WriteLn('   Origins: ', string.Join(', ', Options.AllowedOrigins));
    WriteLn('   Methods: ', string.Join(', ', Options.AllowedMethods));
    WriteLn('   Headers: ', string.Join(', ', Options.AllowedHeaders));
    WriteLn('   Allow Credentials: ', BoolToStr(Options.AllowCredentials, True));
    WriteLn('   Max Age: ', Options.MaxAge, ' seconds');
  finally
    Builder.Free;
  end;
  
  WriteLn;
end;

procedure DemoJwtBuilder;
var
  Builder: TJwtOptionsBuilder;
  Options: TJwtOptions;
begin
  WriteLn('=== JWT Builder Demo ===');
  WriteLn;
  
  Builder := TJwtOptionsBuilder.Create('my-super-secret-key-at-least-32-chars-long');
  try
    Options := Builder
      .WithIssuer('dext-store')
      .WithAudience('dext-users')
      .WithExpirationMinutes(120)
      .Build;
    
    WriteLn('✅ JWT Options Created:');
    WriteLn('   Secret Key: ', Copy(Options.SecretKey, 1, 20), '...');
    WriteLn('   Issuer: ', Options.Issuer);
    WriteLn('   Audience: ', Options.Audience);
    WriteLn('   Expiration: ', Options.ExpirationMinutes, ' minutes');
  finally
    Builder.Free;
  end;
  
  WriteLn;
end;

procedure DemoJwtTokenGeneration;
var
  Handler: IJwtTokenHandler;
  Claims: TArray<TClaim>;
  Token: string;
  ValidationResult: TJwtValidationResult;
begin
  WriteLn('=== JWT Token Generation Demo ===');
  WriteLn;
  
  Handler := TJwtTokenHandler.Create(
    'my-super-secret-key-at-least-32-chars-long',
    'dext-store',
    'dext-users',
    60
  );
  
  // Create claims
  SetLength(Claims, 3);
  Claims[0] := TClaim.Create('sub', 'user123');
  Claims[1] := TClaim.Create('name', 'John Doe');
  Claims[2] := TClaim.Create('role', 'admin');
  
  // Generate token
  Token := Handler.GenerateToken(Claims);
  WriteLn('✅ Token Generated:');
  WriteLn('   ', Copy(Token, 1, 80), '...');
  WriteLn;
  
  // Validate token
  ValidationResult := Handler.ValidateToken(Token);
  WriteLn('✅ Token Validation:');
  WriteLn('   Valid: ', BoolToStr(ValidationResult.IsValid, True));
  if ValidationResult.IsValid then
  begin
    WriteLn('   Claims Count: ', Length(ValidationResult.Claims));
    var I: Integer;
    for I := 0 to High(ValidationResult.Claims) do
      WriteLn('     - ', ValidationResult.Claims[I].ClaimType, ': ', ValidationResult.Claims[I].Value);
  end
  else
    WriteLn('   Error: ', ValidationResult.ErrorMessage);
  
  WriteLn;
end;

begin
  try
    WriteLn('🚀 Dext Fluent API Demo');
    WriteLn('========================');
    WriteLn;
    
    DemoCorsBuilder;
    DemoJwtBuilder;
    DemoJwtTokenGeneration;
    
    WriteLn('✨ All demos completed successfully!');
    WriteLn;
    WriteLn('Press ENTER to exit...');
    ReadLn;
  except
    on E: Exception do
    begin
      WriteLn('❌ Error: ', E.ClassName, ': ', E.Message);
      ReadLn;
    end;
  end;
end.
