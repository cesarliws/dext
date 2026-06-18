program Dext.Web.UnitTests;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  Dext.MM,
  System.SysUtils,
  Dext.Testing.Runner,
  Dext.Testing.Attributes,
  Dext.Testing.Fluent,
  Dext.Testing,
  Dext.Utils,
  Dext.Web.DataApi.Resolver.Tests in 'Dext.Web.DataApi.Resolver.Tests.pas',
  Dext.Web.DataApi.Tests in 'Dext.Web.DataApi.Tests.pas',
  Dext.Web.Json.Tests in 'Dext.Web.Json.Tests.pas',
  Dext.Web.Binding.Tests in 'Dext.Web.Binding.Tests.pas',
  Dext.Web.Features.Tests in 'Dext.Web.Features.Tests.pas',
  Dext.Web.DataApi.Utils.Tests in 'Dext.Web.DataApi.Utils.Tests.pas',
  Dext.Web.Hosting.Tests in 'Dext.Web.Hosting.Tests.pas',
  Dext.Web.Htmx.Tests in 'Dext.Web.Htmx.Tests.pas',
  Dext.Logging.Sinks.APM.Tests in 'Dext.Logging.Sinks.APM.Tests.pas',
  Dext.WebSocket.Tests in 'Dext.WebSocket.Tests.pas',
  Dext.Web.Mocks in '..\Common\Dext.Web.Mocks.pas',
  Test_Dext.Http2.Connection in 'Test_Dext.Http2.Connection.pas',
  Test_Dext.Http2.Framing in 'Test_Dext.Http2.Framing.pas',
  Test_Dext.Http2.Hpack in 'Test_Dext.Http2.Hpack.pas',
  Test_Dext.Http2.Stream in 'Test_Dext.Http2.Stream.pas';

begin
  SetConsoleCharSet();
  try
    SafeWriteLn;
    SafeWriteLn('🧪 Dext Web Unit Tests');
    SafeWriteLn('======================');
    SafeWriteLn;

    RunTests(TTest
      .Configure
      .Verbose
      .RegisterFixtures([
        TWebBindingTests,
        TEntityIdResolverTests,
        TJsonNullableTests,
        TWebFeaturesTests,
        TDataApiNamingTests,
        TWebHostingTests,
        TDataApiConventionTests,
        TDataApiSerializationTests,
        THtmxResponseTests,
        TAPMSinksTests,
        TWebSocketTests,
        // HTTP/2 and HPACK Tests
        THpackStaticTableTests,
        THpackDynTableTests,
        THpackHuffmanTests,
        THpackDecoderTests,
        THpackEncoderTests,
        TFrameReadTests,
        TFrameSettingsTests,
        TFramePingTests,
        TFrameControlTests,
        TFrameDataHeadersTests,
        TStreamStateTests,
        TStreamAccumulationTests,
        TStreamFlowControlTests,
        TStreamMapTests,
        TConnectionPrefaceTests,
        TConnectionSettingsTests,
        TConnectionPingTests,
        TConnectionRequestTests
      ]));
  except
    on E: Exception do
    begin
      SafeWriteLn('FATAL ERROR: ' + E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
