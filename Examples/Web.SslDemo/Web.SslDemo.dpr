program Web.SslDemo;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Dext.Web,
  Dext.Web.Interfaces;

begin
  try
    Writeln('Dext SSL/HTTPS Demo');
    Writeln('-------------------');
    Writeln('This example demonstrates how to configure SSL using OpenSSL or TaurusTLS.');
    Writeln('Check appsettings.json for configuration options.');
    Writeln('');

    var App := TDextApplication.Create;

    App.GetBuilder
      .MapGet('/', function(Context: IHttpContext)
      begin
        Context.Response.Send('<h1>Dext SSL Demo</h1>' +
          '<p>If you see this, the server is running!</p>' +
          '<p>Protocol: ' + Context.Request.Scheme + '</p>' +
          '<p>Check the console for HTTPS enabling messages.</p>');
      end);

    App.Run;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
