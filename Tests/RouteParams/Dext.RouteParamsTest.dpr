program Dext.RouteParamsTest;

{$OVERFLOWCHECKS OFF}
{$RANGECHECKS OFF}

{$APPTYPE CONSOLE}

uses
  Dext.MM,
  System.SysUtils,
  Dext.Utils,
  Dext.DI.Interfaces,
  Dext.Web.Interfaces,
  Dext.WebHost,
  Dext.Web.ApplicationBuilder.Extensions,
  Dext.Web.HandlerInvoker;

{$R *.res}

type
  TUserData = record
    Name: string;
    Email: string;
  end;

var
  Host: IWebHost;
begin
  SetConsoleCharSet(65001);
  try
    WriteLn('🧪 Testing Route Parameters Support');
    WriteLn('=====================================');
    WriteLn;

    Host := TDextWebHost.CreateDefaultBuilder
      .UseUrls('http://127.0.0.1:0')
      .ConfigureServices(procedure(Services: IServiceCollection)
      begin
        // Nenhum serviço necessário para este teste
      end)
      .Configure(procedure(App: IApplicationBuilder)
      begin
        WriteLn('📝 Registering routes with parameter binding...');
        WriteLn;

        // Test 1: Single primitive parameter (Integer)
        WriteLn('  ✅ GET /users/{id} - Integer binding');
        TApplicationBuilderExtensions.MapGet<Integer>(
          App,
          '/users/{id}',
          procedure(UserId: Integer)
          begin
            WriteLn(Format('    → Received UserId: %d', [UserId]));
          end
        );

        // Test 2: Single primitive parameter (String)
        WriteLn('  ✅ GET /posts/{slug} - String binding');
        TApplicationBuilderExtensions.MapGet<string>(
          App,
          '/posts/{slug}',
          procedure(Slug: string)
          begin
            WriteLn(Format('    → Received Slug: %s', [Slug]));
          end
        );

        // Test 3: PUT with route param
        WriteLn('  ✅ PUT /users/{id} - Integer binding');
        TApplicationBuilderExtensions.MapPut<Integer>(
          App,
          '/users/{id}',
          procedure(UserId: Integer)
          begin
            WriteLn(Format('    → PUT UserId: %d', [UserId]));
          end
        );

        // Test 4: DELETE with route param
        WriteLn('  ✅ DELETE /users/{id} - Integer binding');
        TApplicationBuilderExtensions.MapDelete<Integer>(
          App,
          '/users/{id}',
          procedure(UserId: Integer)
          begin
            WriteLn(Format('    → DELETE UserId: %d', [UserId]));
          end
        );

        // Test 5: POST with body binding
        WriteLn('  ✅ POST /users - Record (Body) binding');
        TApplicationBuilderExtensions.MapPost<TUserData>(
          App,
          '/users',
          procedure(User: TUserData)
          begin
            WriteLn(Format('    → POST User: %s <%s>', [User.Name, User.Email]));
          end
        );

        WriteLn;
        WriteLn('✅ All routes registered successfully!');
      end)
      .Build;

    WriteLn;
    WriteLn('🚀 Starting server on http://localhost:5000');
    WriteLn;
    WriteLn('Test with:');
    WriteLn('  curl http://localhost:5000/users/123');
    WriteLn('  curl http://localhost:5000/posts/hello-world');
    WriteLn('  curl -X PUT http://localhost:5000/users/456');
    WriteLn('  curl -X DELETE http://localhost:5000/users/789');
    WriteLn('  curl -X POST http://localhost:5000/users -H "Content-Type: application/json" -d "{\"name\":\"John\",\"email\":\"john@example.com\"}"');
    WriteLn;
    WriteLn('Press Enter to stop...');
    WriteLn;

    Host.Start;
    try
      WriteLn('Server started successfully.');
    finally
      Host.Stop;
    end;
  except
    on E: Exception do
    begin
      Writeln('ERROR: ', E.ClassName, ': ', E.Message);
      Writeln('ExceptAddr RVA: ', Format('%p', [Pointer(NativeUInt(ExceptAddr) - HInstance)]));
      Writeln('StackTrace: ', E.StackTrace);
      ExitCode := 1;
    end;
  end;
end.
