program Web.RateLimitDemo;

{$APPTYPE CONSOLE}

uses
  Dext.MM,
  System.SysUtils,
  Dext.Web.WebApplication,
  Dext,
  Dext.Web.ApplicationBuilder.Extensions,
  Dext.Web.Interfaces,
  Dext.Web.Results,
  Dext.RateLimiting,
  Dext.RateLimiting.Policy,
  Dext.Web.HandlerInvoker;

var
  App: IWebApplication;
begin

  try
    WriteLn('Dext Rate Limiting Demo');
    WriteLn('===========================');
    WriteLn;

    App := TDextApplication.Create;
    var Builder := App.GetApplicationBuilder;

    // Configure Rate Limiting
    WriteLn('[*] Configuring Rate Limiting...');
    
    var Policy := TRateLimitPolicy.FixedWindow(10, 60)
      .WithRejectionMessage('{"error":"Too many requests! Please slow down."}')
      .WithRejectionStatusCode(429);
      
    TApplicationBuilderRateLimitExtensions.UseRateLimiting(Builder, Policy);

    WriteLn('   [OK] Rate limiting configured: 10 requests per minute');
    WriteLn;

    // Test endpoint using MapGetR
    TApplicationBuilderExtensions.MapGetR<IResult>(Builder, '/api/test',
      function: IResult
      begin
        Result := Results.Ok('{"message":"Request successful!","timestamp":"' + 
          DateTimeToStr(Now) + '"}');
      end);

    TApplicationBuilderExtensions.MapGetR<IResult>(Builder, '/',
      function: IResult
      begin
        Result := Results.Ok('{"message":"Rate Limiting Demo - Try /api/test"}');
      end);

    WriteLn('[OK] Endpoints configured');
    WriteLn;
    WriteLn('=========================================');
    WriteLn('Server running on http://localhost:8080');
    WriteLn('=========================================');
    WriteLn;
    WriteLn('Test Commands:');
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
    WriteLn('=========================================');
    WriteLn('Press Enter to stop the server...');
    WriteLn;

    App.Run(8080);
    ReadLn;

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
