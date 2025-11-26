program Dext.MinimalAPITest;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.IOUtils,
  Dext.DI.Interfaces,
  Dext.DI.Extensions,
  Dext.Http.Interfaces,
  Dext.WebHost,
  Dext.Core.ApplicationBuilder.Extensions,
  Dext.Core.HandlerInvoker,
  Dext.Http.Results,
  Dext.Caching,
  Dext.Validation,
  Dext.Logging,
  Dext.Logging.Extensions,
  Dext.Http.Middleware,
  Dext.Http.Middleware.Extensions,
  Dext.RateLimiting,
  Dext.Http.StaticFiles,
  Dext.Swagger.Middleware,
  Dext.OpenAPI.Generator;

{$R *.res}

type
  IUserService = interface
    ['{8F3A2B1C-4D5E-6F7A-8B9C-0D1E2F3A4B5C}']
    function GetUserName(UserId: Integer): string;
    function DeleteUser(UserId: Integer): Boolean;
  end;

  TUserService = class(TInterfacedObject, IUserService)
  public
    function GetUserName(UserId: Integer): string;
    function DeleteUser(UserId: Integer): Boolean;
  end;

  TCreateUserRequest = record
    [Required]
    [StringLength(3, 50)]
    Name: string;
    
    [Required]
    [EmailAddress]
    Email: string;
    
    [Range(18, 120)]
    Age: Integer;
  end;

  TUpdateUserRequest = record
    Name: string;
    Email: string;
  end;

{ TUserService }

function TUserService.GetUserName(UserId: Integer): string;
begin
  Result := Format('User_%d', [UserId]);
end;

function TUserService.DeleteUser(UserId: Integer): Boolean;
begin
  WriteLn(Format('  Deleting user %d from database...', [UserId]));
  Result := True;
end;

begin
  try
    WriteLn('Dext Minimal API - Complete Feature Demo');
    WriteLn('============================================');
    WriteLn;

    // Setup Static Files for testing
    var WwwRoot := TPath.Combine(ExtractFilePath(ParamStr(0)), 'wwwroot');
    if not DirectoryExists(WwwRoot) then
      ForceDirectories(WwwRoot);
      
    var IndexHtml := TPath.Combine(WwwRoot, 'index.html');
    if not FileExists(IndexHtml) then
      TFile.WriteAllText(IndexHtml, '<html><body><h1>Hello from Static File!</h1></body></html>');
      
    WriteLn('Created static file at: ' + IndexHtml);
    WriteLn;

    var Host := TDextWebHost.CreateDefaultBuilder
      .ConfigureServices(procedure(Services: IServiceCollection)
      begin
        WriteLn('Registering services...');

        TServiceCollectionExtensions.AddSingleton<ILoggerFactory, TLoggerFactory>(Services);
        TServiceCollectionExtensions.AddSingleton<IUserService, TUserService>(Services);

        // Add Logging
        TServiceCollectionLoggingExtensions.AddLogging(Services,
          procedure(Builder: ILoggingBuilder)
          begin
            Builder.AddConsole;
            Builder.SetMinimumLevel(TLogLevel.Information);
          end);

        WriteLn('  IUserService registered');
        WriteLn('  Logging registered');
        WriteLn;
      end)
      .Configure(procedure(App: IApplicationBuilder)
      begin
        // 1. Exception Handler (First to catch everything)
        TApplicationBuilderMiddlewareExtensions.UseExceptionHandler(App);
        
        // 2. Rate Limiting (Protect resources)
        // Limit: 5 requests per 10 seconds
        TApplicationBuilderRateLimitExtensions.UseRateLimiting(App, 
          TRateLimitPolicy.Create(5, 10));
        
        // 3. HTTP Logging
        TApplicationBuilderMiddlewareExtensions.UseHttpLogging(App);
        
        // 4. Response Cache
        TApplicationBuilderCacheExtensions.UseResponseCache(App, 10);
        
        // 5. Static Files
        TApplicationBuilderStaticFilesExtensions.UseStaticFiles(App);
        
        // 6. Swagger / OpenAPI
        TSwaggerExtensions.UseSwagger(App, 
          TOpenAPIOptions.Default
            .WithServer('http://localhost:8080', 'Local Development Server'));
        
        WriteLn('Configuring routes...');
        WriteLn;

        WriteLn('1. GET /api/users/{id}');
        TApplicationBuilderExtensions.MapGetR<Integer, IResult>(
          App,
          '/api/users/{id}',
          function(UserId: Integer): IResult
          begin
            WriteLn(Format('  GET User: %d', [UserId]));
            Result := Results.Json(Format('{"userId":%d,"message":"User retrieved"}', [UserId]));
          end
        );

        WriteLn('2. GET /api/users/{id}/name');
        TApplicationBuilderExtensions.MapGet<Integer, IUserService, IHttpContext>(
          App,
          '/api/users/{id}/name',
          procedure(UserId: Integer; UserService: IUserService; Ctx: IHttpContext)
          begin
            var UserName := UserService.GetUserName(UserId);
            WriteLn(Format('  User %d name: %s', [UserId, UserName]));
            Ctx.Response.Json(Format('{"userId":%d,"name":"%s"}', [UserId, UserName]));
          end
        );

        WriteLn('3. POST /api/users (Automatic Validation)');
        TApplicationBuilderExtensions.MapPostR<TCreateUserRequest, IResult>(
          App,
          '/api/users',
          function(Request: TCreateUserRequest): IResult
          begin
            // Note: Validation is now handled automatically by the framework.
            // If we reach here, the Request is valid!
            
            WriteLn(Format('  Creating user: %s <%s>, Age: %d', 
              [Request.Name, Request.Email, Request.Age]));
            
            Result := Results.Created('/api/users/1', 
              Format('{"name":"%s","email":"%s","age":%d,"message":"User created"}', 
              [Request.Name, Request.Email, Request.Age]));
          end
        );

        WriteLn('4. PUT /api/users/{id}');
        TApplicationBuilderExtensions.MapPut<Integer, TUpdateUserRequest, IHttpContext>(
          App,
          '/api/users/{id}',
          procedure(UserId: Integer; Request: TUpdateUserRequest; Ctx: IHttpContext)
          begin
            WriteLn(Format('  Updating user %d: %s <%s>', 
              [UserId, Request.Name, Request.Email]));
            Ctx.Response.Json(Format('{"userId":%d,"name":"%s","email":"%s","message":"User updated"}', 
              [UserId, Request.Name, Request.Email]));
          end
        );

        WriteLn('5. DELETE /api/users/{id}');
        TApplicationBuilderExtensions.MapDelete<Integer, IUserService, IHttpContext>(
          App,
          '/api/users/{id}',
          procedure(UserId: Integer; UserService: IUserService; Ctx: IHttpContext)
          begin
            WriteLn(Format('  DELETE User: %d', [UserId]));
            var Success := UserService.DeleteUser(UserId);
            Ctx.Response.Json(Format('{"userId":%d,"deleted":%s}', 
              [UserId, BoolToStr(Success, True).ToLower]));
          end
        );

        WriteLn('6. GET /api/posts/{slug}');
        TApplicationBuilderExtensions.MapGet<string, IHttpContext>(
          App,
          '/api/posts/{slug}',
          procedure(Slug: string; Ctx: IHttpContext)
          begin
            WriteLn(Format('  GET Post: %s', [Slug]));
            Ctx.Response.Json(Format('{"slug":"%s","title":"Post about %s"}', [Slug, Slug]));
          end
        );

        WriteLn('7. GET /api/health');
        TApplicationBuilderExtensions.MapGetR<IResult>(
          App,
          '/api/health',
          function: IResult
          begin
            WriteLn('  Health check');
            Result := Results.Ok('{"status":"healthy","timestamp":"' + 
              DateTimeToStr(Now) + '"}');
          end
        );

        WriteLn('8. GET /api/cached');
        TApplicationBuilderExtensions.MapGetR<IResult>(
          App,
          '/api/cached',
          function: IResult
          begin
            WriteLn('  Generating fresh response for /api/cached');
            Result := Results.Ok(Format('{"time":"%s","message":"This response is cached for 10s"}', 
              [DateTimeToStr(Now)]));
          end
        );
        
        WriteLn('9. GET /api/error (Test Exception Handling)');
        TApplicationBuilderExtensions.MapGetR<IResult>(
          App,
          '/api/error',
          function: IResult
          begin
            raise Exception.Create('This is a test exception to verify the Exception Handler Middleware');
          end
        );
      end)
      .Build;

    WriteLn('===========================================');
    WriteLn('Server running on http://localhost:8080');
    WriteLn('===========================================');
    WriteLn;
    WriteLn('Test Commands:');
    WriteLn;
    WriteLn('curl http://localhost:8080/api/users/123');
    WriteLn('curl http://localhost:8080/api/users/456/name');
    WriteLn('curl -X POST http://localhost:8080/api/users -H "Content-Type: application/json" -d "{\"name\":\"John Doe\",\"email\":\"john@example.com\",\"age\":30}"');
    WriteLn('curl -X PUT http://localhost:8080/api/users/789 -H "Content-Type: application/json" -d "{\"name\":\"Jane Smith\",\"email\":\"jane@example.com\"}"');
    WriteLn('curl -X DELETE http://localhost:8080/api/users/999');
    WriteLn('curl http://localhost:8080/api/posts/hello-world');
    WriteLn('curl http://localhost:8080/api/health');
    WriteLn('curl -v http://localhost:8080/api/cached');
    WriteLn('curl -v http://localhost:8080/api/error');
    WriteLn('curl http://localhost:8080/index.html');
    WriteLn('curl http://localhost:8080/swagger');
    WriteLn;
    WriteLn('Press Enter to stop the server...');
    WriteLn;

    Host.Run;
    Readln;
    Host.Stop;

    WriteLn;
    WriteLn('Server stopped successfully');

  except
    on E: Exception do
    begin
      WriteLn('Error: ', E.Message);
      WriteLn('Press Enter to exit...');
      Readln;
    end;
  end;
end.