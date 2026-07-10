program Web.TaskFlowAPI;

uses
  Dext.MM,
  Dext.Utils,
  System.SysUtils,
  Dext.Web.Interfaces,
  Dext.Web.ApplicationBuilder.Extensions,
  Dext.Web.Results,
  Dext.Web,
  TaskFlow.Domain,
  TaskFlow.Repository.Interfaces,
  TaskFlow.Repository.Mock,
  TaskFlow.Handlers.Tasks,
  Dext.DI.Interfaces;

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
  AppBuilder: TAppBuilder;

begin
  SetConsoleCharSet(65001);
  try
    WriteLn('Starting TaskFlow API...');
    WriteLn('Dext Framework v0.1.0');
    WriteLn('Time: ', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
    WriteLn('');

    // 1. Criar aplicação Dext
    App := TDextApplication.Create;

    // 2. Configurar DI Container
    // Usando sintaxe simplificada (App.Services)
    App.Services.AddSingleton<ITaskRepository, TTaskRepositoryMock>;
    App.Services.AddSingleton<IUserService, TUserService>; // ✅ Registrar UserService

    // 3. Mapear Handlers
    App.MapControllers;

    WriteLn('Auto-mapped routes registered');
    WriteLn('');

    // 4. ✅ MAPEAMENTO COM SMART BINDING (FASE 2)
    AppBuilder := App.Builder;

    // ✅ Response Compression (gzip/deflate)
    AppBuilder.UseMiddleware(TCompressionMiddleware);

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

    // GET /api/tasks/{id}
    AppBuilder.MapGet('/api/tasks/{id}',
      procedure(Context: IHttpContext)
      var
        Id: Integer;
        IdStr: string;
      begin
        if not Context.Request.RouteParams.TryGetValue('id', IdStr) then
        begin
          Context.Response.StatusCode := 400;
          Context.Response.Json('{"error":"missing id"}');
          Exit;
        end;
        Id := StrToIntDef(IdStr, 0);
        WriteLn(Format('🎯 HANDLER: GetTaskById (%d)', [Id]));
        Context.Response.Json(Format('{"id": %d, "title": "Sample Task", "status": "pending"}', [Id]));
      end);

    // GET /api/tasks/stats - Mantido simples
    AppBuilder.MapGet('/api/tasks/stats',
      procedure(Context: IHttpContext)
      begin
        Context.Response.Json('{"total": 10, "completed": 3, "pending": 7}');
      end);

    // DELETE /api/tasks/{id}
    AppBuilder.MapDelete('/api/tasks/{id}',
      procedure(Context: IHttpContext)
      var
        Id: Integer;
        IdStr: string;
      begin
        if not Context.Request.RouteParams.TryGetValue('id', IdStr) then
        begin
          Context.Response.StatusCode := 400;
          Context.Response.Json('{"error":"missing id"}');
          Exit;
        end;
        Id := StrToIntDef(IdStr, 0);
        WriteLn(Format('🎯 HANDLER: DeleteTask (%d)', [Id]));
        Context.Response.StatusCode := 204; // No Content
      end);

    // POST /api/users
    AppBuilder.MapPost<IHttpContext, TUser>('/api/users',
      procedure(Context: IHttpContext; User: TUser)
      var
        UserService: IUserService;
        Created: TUser;
      begin
        WriteLn('HANDLER: CreateUser executing');

        // Resolve service from context
        UserService := Context.Services.GetServiceAsInterface(TServiceType.FromInterface(IUserService)) as IUserService;
        if Assigned(UserService) then
        begin
          Created := UserService.CreateUser(User);
          Context.Response.StatusCode := 201;
          Context.Response.Json(Format('{"message":"User created", "name":"%s"}', [Created.Name]));
        end
        else
        begin
          Context.Response.StatusCode := 500;
          Context.Response.Json('{"error":"UserService not available"}');
        end;
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

    // 5. 🚀 INICIAR SERVIDOR!
    App.Run(8080);

    // Only pause if not running in automated mode
    ConsolePause;

  except
    on E: Exception do
    begin
      WriteLn('❌ Startup error: ', E.Message);
      WriteLn('💀 Application terminated');

      // Only pause if not running in automated mode
      ConsolePause;
    end;
  end;
end.
