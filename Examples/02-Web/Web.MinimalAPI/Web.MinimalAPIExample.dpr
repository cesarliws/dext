// Examples/MinimalAPI/MinimalAPIExample.pas
program Web.MinimalAPIExample;

{$APPTYPE CONSOLE}

{
  Dext Minimal API Example
  ========================
  This is the simplest way to create HTTP endpoints with Dext.

  Demonstrates:
  - Direct route mapping (no Controllers needed)
  - Dependency Injection in handlers
  - Query parameter handling
  - JSON responses
}

uses
  Dext.MM,
  Dext.Utils,
  System.Classes,
  System.DateUtils,
  System.SysUtils,
  Dext.WebHost,
  Dext.DI.Interfaces,
  Dext.Web.Interfaces,
  Dext.Web.Results,
  Dext.Web.StaticFiles,
  Dext.Web;

type
  // Simple service interface for DI demonstration
  IGreetingService = interface
    ['{89A82D2C-D213-4629-A77E-F6C7D8A1B2C3}']
    function GetGreeting(const Name: string): string;
  end;

  TGreetingService = class(TInterfacedObject, IGreetingService)
  public
    function GetGreeting(const Name: string): string;
  end;

function TGreetingService.GetGreeting(const Name: string): string;
begin
  if Name <> '' then
    Result := Format('Hello, %s! Welcome to Dext.', [Name])
  else
    Result := 'Hello from Dext!';
end;

var
  Builder: IWebHostBuilder;
  Host: IWebHost;

begin
  try
    SetConsoleCharSet(65001);
    WriteLn('🚀 Dext Minimal API Example');
    WriteLn('============================');
    WriteLn;

    Builder := TDextWebHost.CreateDefaultBuilder;

    // Register services for Dependency Injection
    Builder.ConfigureServices(
      procedure(Services: IServiceCollection)
      begin
        TDextServices.Create(Services)
          .AddSingleton<IGreetingService, TGreetingService>;
        WriteLn('✅ Services registered');
      end);

    Builder.Configure(
      procedure(App: IApplicationBuilder)
      begin
        App.UseMiddleware(TRequestLoggingMiddleware);
        TApplicationBuilderStaticFilesExtensions.UseStaticFiles(App);

        // GET /hello - Uses DI to resolve service
        App.MapGet('/hello',
          procedure(Context: IHttpContext)
          var
            Svc: IGreetingService;
            Name: string;
          begin
            Context.Request.Query.TryGetValue('name', Name);
            // Resolve service from request context using Supports
            if Supports(Context.Services.GetService(TypeInfo(IGreetingService)), IGreetingService, Svc) then
              Context.Response.Write(Svc.GetGreeting(Name))
            else
              Context.Response.Write('Hello! (Service not resolved)');
          end);

        // GET /echo?text=abc - Query parameter example
        App.MapGet('/echo',
          procedure(Context: IHttpContext)
          var
            Text: string;
          begin
            Context.Request.Query.TryGetValue('text', Text);
            if Text = '' then Text := 'No text provided';
            Context.Response.Write('Echo: ' + Text);
          end);

        // GET /time - Server time
        App.MapGet('/time',
          procedure(Context: IHttpContext)
          begin
            Context.Response.Write(Format('Server time: %s', [DateTimeToStr(Now)]));
          end);

        // GET /json - JSON response
        App.MapGet('/json',
          procedure(Context: IHttpContext)
          begin
            Context.Response.Json(
              '{"message": "Hello JSON!", "timestamp": "' + DateTimeToStr(Now) + '"}'
            );
          end);

        // GET /health - Health check endpoint
        App.MapGet('/health',
          procedure(Context: IHttpContext)
          begin
            Context.Response.Json('{"status": "healthy"}');
          end);

        // GET /test.wav - Binary stream response reproduction
        App.MapGet('/test.wav',
          procedure(Context: IHttpContext)
          var
            Stream: TMemoryStream;
            BinaryData: TBytes;
            I: Integer;
          begin
            SetLength(BinaryData, 32044);
            for I := 0 to High(BinaryData) do
              BinaryData[I] := I mod 256;
            Stream := TMemoryStream.Create;
            try
              Stream.WriteBuffer(BinaryData[0], Length(BinaryData));
              Stream.Position := 0;
              Context.Response.SetContentType('audio/wav');
              Context.Response.SetContentLength(Length(BinaryData));
              Context.Response.Write(Stream);
            finally
              Stream.Free;
            end;
          end);

        WriteLn;
        WriteLn('📍 Routes registered:');
        WriteLn('  GET /hello?name=World  - Greeting with DI');
        WriteLn('  GET /echo?text=abc     - Echo query param');
        WriteLn('  GET /time              - Current server time');
        WriteLn('  GET /json              - JSON response');
        WriteLn('  GET /health            - Health check');
        WriteLn;
        WriteLn('═══════════════════════════════════════════');
        WriteLn('🌐 Server running on http://localhost:5000');
        WriteLn('═══════════════════════════════════════════');
        WriteLn;
        WriteLn('Press Enter to stop the server...');
      end);

    Host := Builder.Build;
    Host.Run;

    ConsolePause;
    Host.Stop;

  except
    on E: Exception do
      WriteLn('❌ Error: ', E.Message);
  end;
end.
