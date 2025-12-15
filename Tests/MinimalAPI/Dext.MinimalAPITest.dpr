program Dext.MinimalAPITest;

{$APPTYPE CONSOLE}

uses
  Dext.MM,
  System.SysUtils,
  System.IOUtils,
  Dext.Caching,
  Dext.Web.ApplicationBuilder.Extensions,
  Dext.Web.HandlerInvoker,
  Dext.DI.Extensions,
  Dext.DI.Interfaces,
  Dext.DI.Middleware,
  Dext.Web.Interfaces,
  Dext.Web.Middleware,
  Dext.Web.Middleware.Extensions,
  Dext.Web.Results,
  Dext.Web.StaticFiles,
  Dext.Logging,
  Dext.Logging.Extensions,
  Dext.OpenAPI.Generator,
  Dext.RateLimiting,
  Dext.RateLimiting.Policy,
  Dext.Swagger.Middleware,
  Dext.Validation,
  Dext.WebHost;

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

type
  // Scoped service example
  IRequestContext = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    function GetRequestId: string;
    property RequestId: string read GetRequestId;
  end;

  TRequestContext = class(TInterfacedObject, IRequestContext)
  private
    FRequestId: string;
  public
    constructor Create;
    function GetRequestId: string;
  end;

constructor TRequestContext.Create;
begin
  inherited;
  FRequestId := TGUID.NewGuid.ToString;
  WriteLn('[Scoped] New RequestContext: ' + FRequestId);
end;

function TRequestContext.GetRequestId: string;
begin
  Result := FRequestId;
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
        TServiceCollectionExtensions.AddScoped<IRequestContext, TRequestContext>(Services);

        // Add Logging
        TServiceCollectionLoggingExtensions.AddLogging(Services,
          procedure(Builder: ILoggingBuilder)
          begin
            Builder.AddConsole;
            Builder.SetMinimumLevel(TLogLevel.Information);
          end);

        WriteLn('  IUserService registered as Singleton');
        WriteLn('  Logging registered as Singleton');
        WriteLn('  IRequestContext registered as SCOPED');
        WriteLn;
      end)
      .Configure(procedure(App: IApplicationBuilder)
      begin
        // 1. Exception Handler (First to catch everything)
        TApplicationBuilderMiddlewareExtensions.UseExceptionHandler(App);

        TApplicationBuilderScopeExtensions.UseServiceScope(App);
        WriteLn('  Service Scope middleware added');
        
        // 2. Rate Limiting (NEW: Advanced rate limiting)
        WriteLn('Configuring Rate Limiting:');
        WriteLn('  - Fixed Window: 100 req/min per IP');
        WriteLn('  - Global Limit: 1000 concurrent requests');
        WriteLn;
        
        TApplicationBuilderRateLimitExtensions.UseRateLimiting(App, 
          TRateLimitPolicy.FixedWindow(100, 60)
            .WithPartitionByIp
            .WithGlobalLimit(1000));
        
        // Alternative examples (commented):
        
        // Sliding Window (more precise):
        // TApplicationBuilderRateLimitExtensions.UseRateLimiting(App, 
        //   TRateLimitPolicy.SlidingWindow(50, 60)
        //     .WithPartitionByIp);
        
        // Token Bucket (allows bursts):
        // TApplicationBuilderRateLimitExtensions.UseRateLimiting(App, 
        //   TRateLimitPolicy.TokenBucket(50, 10)  // 50 tokens, refill 10/sec
        //     .WithPartitionByHeader('X-API-Key'));
        
        // Concurrency Limit:
        // TApplicationBuilderRateLimitExtensions.UseRateLimiting(App, 
        //   TRateLimitPolicy.Concurrency(100)
        //     .WithPartitionByRoute);
        
        // Custom Partition:
        // TApplicationBuilderRateLimitExtensions.UseRateLimiting(App, 
        //   TRateLimitPolicy.FixedWindow(10, 60)
        //     .WithPartitionKey(function(Ctx: IHttpContext): string
        //       begin
        //         Result := Ctx.Request.RemoteIpAddress + '_' + 
        //                   Ctx.Request.Headers.Values['User-Agent'];
        //       end));
        
        // 3. HTTP Logging
        TApplicationBuilderMiddlewareExtensions.UseHttpLogging(App);
        
        // 4. Response Cache
        TApplicationBuilderCacheExtensions.UseResponseCache(App, 10);
        
        // 5. Static Files
        TApplicationBuilderStaticFilesExtensions.UseStaticFiles(App);
        
        // 6. Swagger / OpenAPI
        TSwaggerExtensions.UseSwagger(App, 
          TOpenAPIOptions.Default
            .WithServer('http://localhost:8080', 'Local Development Server')
            .WithGlobalResponse(429, 'Too Many Requests (Rate Limit Exceeded)')
            .WithGlobalResponse(500, 'Internal Server Error'));
        
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

        WriteLn('10. GET /api/request-context (Test Scoped Services)');
        TApplicationBuilderExtensions.MapGetR<IRequestContext, IResult>(
          App,
          '/api/request-context',
          function(Ctx: IRequestContext): IResult
          begin
            WriteLn('  Request ID: ' + Ctx.RequestId);
            Result := Results.Json(Format('{"requestId":"%s","message":"Each request gets a unique ID"}',
              [Ctx.RequestId]));
          end
        );
      end)
      .Build;

    WriteLn('===========================================');
    WriteLn('Server running on http://localhost:8080');
    WriteLn('===========================================');
    WriteLn;
    WriteLn('Rate Limiting Examples:');
    WriteLn('  Fixed Window: 100 req/min per IP + 1000 global concurrent');
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
    WriteLn('curl http://localhost:8080/api/request-context');
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