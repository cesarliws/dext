program Web.TaskFlowAPI;

uses
  FastMM5,
  Dext.Core.WebApplication,
  Dext.DI.Extensions,
  Dext.Core.Routing,
  Dext.Core.ModelBinding,
  Dext.Http.Interfaces,
  TaskFlow.Domain,
  TaskFlow.Repository.Interfaces,
  TaskFlow.Repository.Mock,
  TaskFlow.Handlers.Tasks,
  Dext.Core.HandlerInvoker,
  Dext.Core.ApplicationBuilder.Extensions, // ✅ Extensões genéricas
  Dext.Http.Results, // ✅ Helpers de Resultado
  System.SysUtils;

type
  // ✅ Modelo para teste
  TUser = record
    Name: string;
    Email: string;
  end;

  // ✅ Serviço para teste
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
  // Simula criação (retorna o mesmo usuário)
  Result := User;
  WriteLn(Format('👤 UserService: Creating user "%s" (%s)', [User.Name, User.Email]));
end;

var
  App: IWebApplication;

begin
  ReportMemoryLeaksOnShutdown := True;

  try
    WriteLn('🚀 Starting TaskFlow API...');
    WriteLn('📦 Dext Framework v0.1.0');
    WriteLn('⏰ ', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
    WriteLn('');

    // 1. Criar aplicação Dext
    App := TDextApplication.Create;

    // 2. Configurar DI Container
    TServiceCollectionExtensions.AddSingleton<ITaskRepository, TTaskRepositoryMock>(App.GetServices);
    TServiceCollectionExtensions.AddSingleton<IUserService, TUserService>(App.GetServices); // ✅ Registrar UserService

    // 3. Mapear Handlers
    App.MapControllers;

    WriteLn('✅ Auto-mapped routes registered');
    WriteLn('');

    // 4. ✅ MAPEAMENTO COM SMART BINDING (FASE 2)
    var AppBuilder := App.GetApplicationBuilder;

    // ✅ Functional Middleware: Logging Simples
    AppBuilder.Use(
      procedure(Context: IHttpContext; Next: TRequestDelegate)
      begin
        WriteLn(Format('📝 [LOG] Request: %s %s', [Context.Request.Method, Context.Request.Path]));
        
        // Chama o próximo middleware
        Next(Context);
        
        WriteLn('📝 [LOG] Response sent');
      end);

    // Rota raiz
    AppBuilder.MapGet('/',
      procedure(Context: IHttpContext)
      begin
        Context.Response.Json('{"message": "Dext Framework API", "status": "running", "version": "0.2.0"}');
      end);

    // GET /api/tasks - Lista todas as tarefas (Simples)
    AppBuilder.MapGet('/api/tasks',
      procedure(Context: IHttpContext)
      begin
        Context.Response.Json('{"message": "Tasks endpoint", "count": 5}');
      end);

    // GET /api/tasks/{id} - Smart Binding de Inteiro (Route Param) + Results
    TApplicationBuilderExtensions.MapGetR<Integer, IResult>(AppBuilder, '/api/tasks/{id}',
      function(Id: Integer): IResult
      begin
        WriteLn(Format('🎯 HANDLER: GetTaskById (%d)', [Id]));
        Result := Results.Json(Format('{"id": %d, "title": "Sample Task", "status": "pending"}', [Id]));
      end);

    // GET /api/tasks/stats - Mantido simples
    AppBuilder.MapGet('/api/tasks/stats',
      procedure(Context: IHttpContext)
      begin
        Context.Response.Json('{"total": 10, "completed": 3, "pending": 7}');
      end);

    // DELETE /api/tasks/{id} - Smart Binding + Service Injection (Simulado)
    TApplicationBuilderExtensions.MapDelete<Integer, IHttpContext>(AppBuilder, '/api/tasks/{id}',
      procedure(Id: Integer; Context: IHttpContext)
      begin
        WriteLn(Format('🎯 HANDLER: DeleteTask (%d)', [Id]));
        // Aqui poderíamos injetar um ITaskService
        Context.Response.StatusCode := 204; // No Content
      end);

    // ✅ NOVO: Endpoint com Handler Injection (Minimal API Style) + Results
    // Recebe: Body (TUser), Serviço (IUserService) -> Retorna IResult
    TApplicationBuilderExtensions.MapPostR<TUser, IUserService, IResult>(AppBuilder, '/api/users',
      function(User: TUser; UserService: IUserService): IResult
      var
        CreatedUser: TUser;
      begin
        WriteLn('🎯 HANDLER: CreateUser executing via Handler Injection');
        
        // Lógica de negócio usando o serviço injetado
        CreatedUser := UserService.CreateUser(User);
        
        // Resposta usando Results helper
        Result := Results.Created('/api/users/1', 
          Format('{"message": "User created", "name": "%s", "email": "%s"}', 
          [CreatedUser.Name, CreatedUser.Email]));
          
        WriteLn('✅ Handler completed');
      end);

    WriteLn('✅ Manual routes mapped:');
    WriteLn('   GET /');
    WriteLn('   GET /api/tasks');
    WriteLn('   GET /api/tasks/1');
    WriteLn('   GET /api/tasks/stats');
    WriteLn('   GET /api/tasks/error');
    WriteLn('   POST /api/users (New!)'); // ✅ Novo endpoint
    WriteLn('');
    WriteLn('🌐 Server running on: http://localhost:8080');
    WriteLn('');
    WriteLn('🎯 Test with:');
    WriteLn('   curl http://localhost:8080/');
    WriteLn('   curl http://localhost:8080/api/tasks');
    WriteLn('   curl http://localhost:8080/api/tasks/error');
    WriteLn('');
    WriteLn('⏹️  Press Enter to stop');
    WriteLn('');

    // 5. 🚀 INICIAR SERVIDOR!
    App.Run(8080);
    ReadLn;

  except
    on E: Exception do
    begin
      WriteLn('❌ Startup error: ', E.Message);
      WriteLn('💀 Application terminated');
      ReadLn;
    end;
  end;
end.
