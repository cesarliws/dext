program Web.TaskFlowAPI;

uses
  Dext.MM,
  Dext.Web.WebApplication,
  Dext.DI.Extensions,
  Dext.Web.Routing.Attributes,
  Dext.Web.ModelBinding,
  Dext.Web.Interfaces,
  TaskFlow.Domain,
  TaskFlow.Repository.Interfaces,
  TaskFlow.Repository.Mock,
  TaskFlow.Handlers.Tasks,
  Dext.Web.HandlerInvoker,
  Dext.Web.ApplicationBuilder.Extensions,
  Dext.Web.Results,
  System.SysUtils;

type
  // Model for testing
  TUser = record
    Name: string;
    Email: string;
  end;

  // Service for testing
  IUserService = interface
    ['{A1B2C3D4-E5F6-7890-1234-567890ABCDEF}']
    function CreateUser(const User: TUser): TUser;
  end;

  TUserService = class(TInterfacedObject, IUserService)
  public
    function CreateUser(const User: TUser): TUser;
  end;

{ TUserService }

function TUserService.CreateUser(const User: TUser): TUser;
begin
  // Simulate creation (returns same user)
  Result := User;
  WriteLn(Format('User Service: Creating user "%s" (%s)', [User.Name, User.Email]));
end;

var
  App: IWebApplication;

begin

  try
    WriteLn('Starting TaskFlow API...');
    WriteLn('Dext Framework v0.2.0');
    WriteLn(FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
    WriteLn('');

    // 1. Create Dext Application
    App := TDextApplication.Create;

    // 2. Configure DI Container
    TServiceCollectionExtensions.AddSingleton<ITaskRepository, TTaskRepositoryMock>(App.GetServices);
    TServiceCollectionExtensions.AddSingleton<IUserService, TUserService>(App.GetServices);

    // 3. Map Controller Routes (auto-discovery)
    App.MapControllers;

    WriteLn('[OK] Auto-mapped routes registered');
    WriteLn('');

    // 4. Manual Route Mapping with API
    var AppBuilder := App.GetApplicationBuilder;

    // Functional Middleware: Simple Logging
    AppBuilder.Use(
      procedure(Context: IHttpContext; Next: TRequestDelegate)
      begin
        WriteLn(Format('[LOG] Request: %s %s', [Context.Request.Method, Context.Request.Path]));
        Next(Context);
        WriteLn('[LOG] Response sent');
      end);

    // Root route - Simple handler
    AppBuilder.MapGet('/',
      procedure(Context: IHttpContext)
      begin
        Context.Response.Json('{"message": "Dext Framework API", "status": "running", "version": "0.2.0"}');
      end);

    // GET /api/tasks - List all tasks (Simple)
    AppBuilder.MapGet('/api/tasks',
      procedure(Context: IHttpContext)
      begin
        Context.Response.Json('{"message": "Tasks endpoint", "count": 5}');
      end);

    // GET /api/tasks/{id} - Route Param Binding + IResult
    TApplicationBuilderExtensions.MapGetR<Integer, IResult>(AppBuilder, '/api/tasks/{id}',
      function(Id: Integer): IResult
      begin
        WriteLn(Format('[HANDLER] GetTaskById (%d)', [Id]));
        Result := Results.Json(Format('{"id": %d, "title": "Sample Task", "status": "pending"}', [Id]));
      end);

    // GET /api/tasks/stats - Simple handler
    AppBuilder.MapGet('/api/tasks/stats',
      procedure(Context: IHttpContext)
      begin
        Context.Response.Json('{"total": 10, "completed": 3, "pending": 7}');
      end);

    // DELETE /api/tasks/{id} - Route Param + Context
    TApplicationBuilderExtensions.MapDelete<Integer, IHttpContext>(AppBuilder, '/api/tasks/{id}',
      procedure(Id: Integer; Context: IHttpContext)
      begin
        WriteLn(Format('[HANDLER] DeleteTask (%d)', [Id]));
        Context.Response.StatusCode := 204; // No Content
      end);

    // POST /api/users - Body Binding + Service Injection + IResult
    TApplicationBuilderExtensions.MapPostR<TUser, IUserService, IResult>(AppBuilder, '/api/users',
      function(User: TUser; UserService: IUserService): IResult
      var
        CreatedUser: TUser;
      begin
        WriteLn('[HANDLER] CreateUser via Handler Injection');
        
        // Business logic using injected service
        CreatedUser := UserService.CreateUser(User);
        
        // Response using Results helper
        Result := Results.Created('/api/users/1', 
          Format('{"message": "User created", "name": "%s", "email": "%s"}', 
          [CreatedUser.Name, CreatedUser.Email]));
          
        WriteLn('[OK] Handler completed');
      end);

    WriteLn('[OK] Manual routes mapped:');
    WriteLn('   GET /');
    WriteLn('   GET /api/tasks');
    WriteLn('   GET /api/tasks/{id}');
    WriteLn('   GET /api/tasks/stats');
    WriteLn('   DELETE /api/tasks/{id}');
    WriteLn('   POST /api/users');
    WriteLn('');
    WriteLn('Server running on: http://localhost:8080');
    WriteLn('');
    WriteLn('Test with:');
    WriteLn('   curl http://localhost:8080/');
    WriteLn('   curl http://localhost:8080/api/tasks');
    WriteLn('   curl http://localhost:8080/api/tasks/1');
    WriteLn('   curl -X POST -H "Content-Type: application/json" -d ''{"name":"John","email":"john@test.com"}'' http://localhost:8080/api/users');
    WriteLn('');
    WriteLn('Press Enter to stop');
    WriteLn('');

    // 5. Start Server!
    App.Run(8080);
    ReadLn;

  except
    on E: Exception do
    begin
      WriteLn('[ERROR] Startup error: ', E.Message);
      WriteLn('Application terminated');
      ReadLn;
    end;
  end;
end.
