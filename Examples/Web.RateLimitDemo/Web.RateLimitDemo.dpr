program Web.RateLimitDemo;

{$APPTYPE CONSOLE}

uses
  FastMM5,
  System.SysUtils,
  Dext.Core.WebApplication,
  Dext,
  Dext.Core.ApplicationBuilder.Extensions,
  Dext.Web.Interfaces,
  Dext.Web.Results,
  Dext.RateLimiting,
  Dext.RateLimiting.Policy,
  Dext.Web.HandlerInvoker;

var
  App: IWebApplication;
begin
  ReportMemoryLeaksOnShutdown := True;

  try
    WriteLn('🚦 Dext Rate Limiting Demo');
    WriteLn('===========================');
    WriteLn;

    App := TDextApplication.Create;
    var Builder := App.GetApplicationBuilder;

    // ✅ Configurar Rate Limiting
    WriteLn('📦 Configuring Rate Limiting...');
    
    var Policy := TRateLimitPolicy.FixedWindow(10, 60)
      .WithRejectionMessage('{"error":"Too many requests! Please slow down."}')
      .WithRejectionStatusCode(429);
      
    TApplicationBuilderRateLimitExtensions.UseRateLimiting(Builder, Policy);

    WriteLn('   ✅ Rate limiting configured: 10 requests per minute');
    WriteLn;

    // ✅ Endpoint de teste
    TApplicationBuilderExtensions.MapGetR<IResult>(Builder, '/api/test',
      THandlerFunc<IResult>(function: IResult
      begin
        Result := Results.Ok('{"message":"Request successful!","timestamp":"' + 
          DateTimeToStr(Now) + '"}');
      end));

    TApplicationBuilderExtensions.MapGetR<IResult>(Builder, '/',
      THandlerFunc<IResult>(function: IResult
      begin
        Result := Results.Ok('{"message":"Rate Limiting Demo - Try /api/test"}');
      end));

    WriteLn('✅ Endpoints configured');
    WriteLn;
    WriteLn('═══════════════════════════════════════════');
    WriteLn('🌐 Server running on http://localhost:8080');
    WriteLn('═══════════════════════════════════════════');
    WriteLn;
    WriteLn('📝 Test Commands:');
    WriteLn;
    WriteLn('# Test single request');
    WriteLn('curl http://localhost:8080/api/test -v');
    WriteLn;
    WriteLn('# Test rate limiting (run this in a loop)');
    WriteLn('for /L %i in (1,1,15) do @(curl http://localhost:8080/api/test & echo.)');
    WriteLn;
    WriteLn('# PowerShell version');
    WriteLn('1..15 | ForEach-Object { curl http://localhost:8080/api/test; Write-Host "" }');
    WriteLn;
    WriteLn('Expected behavior:');
    WriteLn('  - First 10 requests: 200 OK');
    WriteLn('  - Requests 11-15: 429 Too Many Requests');
    WriteLn('  - After 60 seconds: Counter resets');
    WriteLn;
    WriteLn('Headers to watch:');
    WriteLn('  X-RateLimit-Limit: 10');
    WriteLn('  X-RateLimit-Remaining: 9, 8, 7...');
    WriteLn('  Retry-After: 60 (when rate limited)');
    WriteLn;
    WriteLn('═══════════════════════════════════════════');
    WriteLn('Press Enter to stop the server...');
    WriteLn;

    App.Run(8080);
    ReadLn;

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

