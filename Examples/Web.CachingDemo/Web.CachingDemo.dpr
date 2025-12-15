program Web.CachingDemo;

{$APPTYPE CONSOLE}

uses
  Dext.MM,
  System.SysUtils,
  Dext.Web.WebApplication,
  Dext.Web.ApplicationBuilder.Extensions,
  Dext.Web.Interfaces,
  Dext.Web.Results,
  Dext.Caching;

var
  App: IWebApplication;
  RequestCount: Integer = 0;
begin

  try
    WriteLn('?? Dext Response Caching Demo');
    WriteLn('==============================');
    WriteLn;

    App := TDextApplication.Create;
    var Builder := App.GetApplicationBuilder;

    // ? Configurar Response Caching
    WriteLn('?? Configuring Response Caching...');
    TApplicationBuilderCacheExtensions.UseResponseCache(Builder,
      procedure(Cache: TResponseCacheBuilder)
      begin
        Cache
          .WithDefaultDuration(30)       // Cache por 30 segundos
          .WithMaxSize(100)               // Máximo 100 entradas
          .VaryByQueryString              // Considerar query params
          .ForMethods(['GET', 'HEAD']);   // Apenas GET e HEAD
      end);
    WriteLn('   ? Response caching configured: 30 seconds TTL');
    WriteLn;

    // ? Endpoint que retorna timestamp (para ver o cache funcionando)
    TApplicationBuilderExtensions.MapGetR<IResult>(Builder, '/api/time',
      function: IResult
      begin
        Inc(RequestCount);
        WriteLn(Format('[%d] Generating fresh response at %s', 
          [RequestCount, FormatDateTime('hh:nn:ss', Now)]));
        
        Result := Results.Ok(Format(
          '{"timestamp":"%s","request_count":%d,"message":"This response is cached for 30 seconds"}',
          [FormatDateTime('yyyy-mm-dd hh:nn:ss', Now), RequestCount]
        ));
      end);

    // ? Endpoint com query params (vary by query)
    TApplicationBuilderExtensions.MapGetR<IResult>(Builder, '/api/data',
      function: IResult
      begin
        Result := Results.Ok(Format(
          '{"data":"Sample data","generated_at":"%s"}',
          [FormatDateTime('hh:nn:ss', Now)]
        ));
      end);

    TApplicationBuilderExtensions.MapGetR<IResult>(Builder, '/',
      function: IResult
      begin
        Result := Results.Ok('{"message":"Caching Demo - Try /api/time or /api/data"}');
      end);

    WriteLn('? Endpoints configured');
    WriteLn;
    WriteLn('-------------------------------------------');
    WriteLn('?? Server running on http://localhost:8080');
    WriteLn('-------------------------------------------');
    WriteLn;
    WriteLn('?? Test Commands:');
    WriteLn;
    WriteLn('# Test caching (run multiple times within 30 seconds)');
    WriteLn('curl http://localhost:8080/api/time');
    WriteLn;
    WriteLn('# First request: X-Cache: MISS (generates response)');
    WriteLn('# Subsequent requests: X-Cache: HIT (from cache)');
    WriteLn('# After 30 seconds: X-Cache: MISS (cache expired)');
    WriteLn;
    WriteLn('# Test vary by query');
    WriteLn('curl http://localhost:8080/api/data');
    WriteLn('curl http://localhost:8080/api/data?page=1');
    WriteLn('curl http://localhost:8080/api/data?page=2');
    WriteLn('# Each different query string gets its own cache entry');
    WriteLn;
    WriteLn('Headers to watch:');
    WriteLn('  X-Cache: HIT | MISS');
    WriteLn('  Cache-Control: public, max-age=30');
    WriteLn;
    WriteLn('-------------------------------------------');
    WriteLn('Press Enter to stop the server...');
    WriteLn;

    App.Run(8080);
    ReadLn;

    WriteLn;
    WriteLn('? Server stopped successfully');

  except
    on E: Exception do
    begin
      WriteLn('? Error: ', E.Message);
      WriteLn('Press Enter to exit...');
      ReadLn;
    end;
  end;
end.
