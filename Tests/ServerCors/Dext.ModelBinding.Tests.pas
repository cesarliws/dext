unit Dext.ModelBinding.Tests;

interface

procedure TestBindQueryComprehensive;
procedure TestBindQueryEdgeCases;

procedure TestBindRouteComprehensive;
procedure TestBindRouteEdgeCases;

procedure TestBindHeaderComprehensive;
procedure TestBindServicesComprehensive;


implementation

uses
  System.Classes,
  System.Generics.Collections,
  System.SysUtils,
  IdURI,
  Dext.Web.ModelBinding,
  Dext.DI.Core,
  Dext.DI.Extensions,
  Dext.DI.Interfaces,
  Dext.Web.Interfaces,
  Dext.Web.Mocks;

// ✅ PROCEDURE AUXILIAR PARA CRIAR MOCK CONTEXT
function CreateMockHttpContext(const AQueryString: string): IHttpContext;
var
  MockRequest: IHttpRequest;
  MockResponse: IHttpResponse;
//  QueryParams: TStrings;
begin
  // Criar mock básico - em produção usaríamos um mock real
  MockRequest := TMockHttpRequest.Create(AQueryString);
  MockResponse := TMockHttpResponse.Create;
  Result := TMockHttpContext.Create(MockRequest, MockResponse, nil);
end;

// Nos testes, usar assim:
procedure TestBindQueryComprehensive;
type
  TQueryTest = record
    [FromQuery('user_name')] Name: string;
    [FromQuery] Age: Integer;
    [FromQuery] Active: Boolean;
    [FromQuery] Score: Double;
    Status: Integer;
  end;

var
  MockContext: IHttpContext;
  Binder: IModelBinder;
begin
  Writeln('=== TESTE BINDQUERY COMPREENSIVO ===');

// Adicionar no início dos testes:
  Writeln('=== VERIFICAÇÃO DE PROBLEMAS CONHECIDOS ===');
  Writeln('1. URL Decoding - John+Doe deve virar John Doe');
  Writeln('2. Float Conversion - 95.5 deve manter o valor');
  Writeln('3. GUID Conversion - Deve converter corretamente');
  Writeln('4. Boolean deve funcionar com todos os formatos');

  try
    Binder := TModelBinder.Create;

    // ✅ TESTE 1: Cenário básico
    Writeln('✅ TESTE 1: Cenário básico');
    MockContext := TMockFactory.CreateHttpContext('user_name=John+Doe&age=30&active=true&score=95.5&status=2');

    var QueryTest: TQueryTest;
    var Value := Binder.BindQuery(TypeInfo(TQueryTest), MockContext);
    QueryTest := Value.AsType<TQueryTest>;

    Writeln('  Name: ', QueryTest.Name, ' (Expected: John Doe)');
    Writeln('  Age: ', QueryTest.Age, ' (Expected: 30)');
    Writeln('  Active: ', QueryTest.Active, ' (Expected: True)');
    Writeln('  Score: ', FormatFloat('0.0', QueryTest.Score), ' (Expected: 95.5)');
    Writeln('  Status: ', QueryTest.Status, ' (Expected: 2)');

    // ✅ TESTE 2: Boolean com diferentes representações
    Writeln(#10 + '✅ TESTE 2: Boolean com múltiplas representações');

    var BoolTests: TArray<string> := ['true', '1', 'yes', 'on', 'false', '0', 'no', 'off'];
    for var BoolValue in BoolTests do
    begin
      MockContext := TMockFactory.CreateHttpContext('active=' + BoolValue);

      // ✅ DEBUG: Verificar o que o mock está recebendo
      Writeln('Query string: ', 'active=' + BoolValue);
      Writeln('Query params count: ', MockContext.Request.Query.Count);
      for var I := 0 to MockContext.Request.Query.Count - 1 do
        Writeln('  Param[', I, ']: ', MockContext.Request.Query[I]);

      Value := Binder.BindQuery(TypeInfo(TQueryTest), MockContext);
      var Test := Value.AsType<TQueryTest>;
      Writeln('  active=' + BoolValue + ' -> ' + Test.Active.ToString(TUseBoolStrs.True));
    end;

    Writeln(#10 + '=== SUCESSO BINDQUERY COMPREENSIVO! ===');

  except
    on E: Exception do
      Writeln('❌ ERRO BindQuery: ', E.ClassName, ' - ', E.Message);
  end;
end;


procedure TestBindQueryEdgeCases;
type
  TEdgeCaseTest = record
    [FromQuery] SmallInt: SmallInt;
    [FromQuery] LargeInt: Int64;
    [FromQuery] CurrencyVal: Currency;
    [FromQuery] IsEnabled: Boolean;
    [FromQuery] UserRole: Integer; // Simulando enum
  end;

var
  MockContext: IHttpContext;
  Binder: IModelBinder;
begin
  Writeln('=== TESTE CASOS EXTREMOS BINDQUERY ===');

  try
    Binder := TModelBinder.Create;

    // ✅ TESTE: Valores extremos
    MockContext := CreateMockHttpContext('/api/test?smallint=32767&largeint=9223372036854775807&currencyval=123.4567&isenabled=1&userrole=5');
    var Test := TModelBinderHelper.BindQuery<TEdgeCaseTest>(Binder, MockContext);

    Writeln('  SmallInt: ', Test.SmallInt, ' (Expected: 32767)');
    Writeln('  LargeInt: ', Test.LargeInt, ' (Expected: 9223372036854775807)');
    Writeln('  Currency: ', FormatFloat('0.0000', Test.CurrencyVal), ' (Expected: 123.4567)');
    Writeln('  IsEnabled: ', Test.IsEnabled, ' (Expected: True)');
    Writeln('  UserRole: ', Test.UserRole, ' (Expected: 5)');

    // ✅ TESTE: Valores negativos
    MockContext := CreateMockHttpContext('/api/test?smallint=-123&largeint=-999999&currencyval=-45.67&isenabled=0');
    Test := TModelBinderHelper.BindQuery<TEdgeCaseTest>(Binder, MockContext);

    Writeln('  SmallInt negativo: ', Test.SmallInt, ' (Expected: -123)');
    Writeln('  LargeInt negativo: ', Test.LargeInt, ' (Expected: -999999)');
    Writeln('  Currency negativo: ', FormatFloat('0.00', Test.CurrencyVal), ' (Expected: -45.67)');
    Writeln('  IsEnabled=false: ', Test.IsEnabled, ' (Expected: False)');

    Writeln('=== SUCESSO CASOS EXTREMOS! ===');

  except
    on E: Exception do
      Writeln('❌ ERRO Edge Cases: ', E.ClassName, ' - ', E.Message);
  end;
end;

procedure TestBindRouteComprehensive;
type
  TRouteTest = record
    [FromRoute('user_id')] UserId: Integer;
    [FromRoute] OrderId: Int64;
    [FromRoute] IsActive: Boolean;
    [FromRoute] UserGuid: TGUID;
    [FromRoute] Category: string;
  end;

var
  MockContext: IHttpContext;
  Binder: IModelBinder;
  RouteParams: TDictionary<string, string>;
begin
  Writeln('=== TESTE BINDROUTE COMPREENSIVO ===');

  try
    Binder := TModelBinder.Create;

    // ✅ TESTE 1: Cenário completo
    Writeln('✅ TESTE 1: Cenário completo');

    RouteParams := TDictionary<string, string>.Create;
    try
      RouteParams.Add('user_id', '123');
      RouteParams.Add('OrderId', '9876543210');
      RouteParams.Add('IsActive', 'true');
      RouteParams.Add('UserGuid', '{C87A33C3-116A-4A31-9A15-9D9A8B6D9C41}');
      RouteParams.Add('Category', 'electronics');

      MockContext := TMockFactory.CreateHttpContextWithRoute('', RouteParams);

      var RouteTest: TRouteTest;
      var Value := Binder.BindRoute(TypeInfo(TRouteTest), MockContext);
      RouteTest := Value.AsType<TRouteTest>;

      Writeln('  UserId: ', RouteTest.UserId, ' (Expected: 123)');
      Writeln('  OrderId: ', RouteTest.OrderId, ' (Expected: 9876543210)');
      Writeln('  IsActive: ', RouteTest.IsActive, ' (Expected: True)');
      Writeln('  UserGuid: ', GUIDToString(RouteTest.UserGuid), ' (Expected: {C87A33C3-116A-4A31-9A15-9D9A8B6D9C41})');
      Writeln('  Category: ', RouteTest.Category, ' (Expected: electronics)');
    finally
      RouteParams.Free;
    end;

    // ✅ TESTE 2: Boolean com diferentes representações
    Writeln(#10 + '✅ TESTE 2: Boolean com múltiplas representações');

    var BoolTests: TArray<string> := ['true', '1', 'yes', 'on', 'false', '0', 'no', 'off'];
    for var BoolValue in BoolTests do
    begin
      RouteParams := TDictionary<string, string>.Create;
      try
        RouteParams.Add('IsActive', BoolValue); // ✅ Já está correto
        MockContext := TMockFactory.CreateHttpContextWithRoute('', RouteParams);

        var Value := Binder.BindRoute(TypeInfo(TRouteTest), MockContext);
        var Test := Value.AsType<TRouteTest>;
        Writeln('  isactive=' + BoolValue + ' -> ' + Test.IsActive.ToString(TUseBoolStrs.True));
      finally
        RouteParams.Free;
      end;
    end;

    // ✅ TESTE 3: GUID com diferentes formatos
    Writeln(#10 + '✅ TESTE 3: GUID com diferentes formatos');

    var GuidTests: TArray<string> := [
      '{C87A33C3-116A-4A31-9A15-9D9A8B6D9C41}',
      'C87A33C3-116A-4A31-9A15-9D9A8B6D9C41',
      'invalid-guid' // Deve resultar em GUID.Empty
    ];

    for var GuidStr in GuidTests do
    begin
      RouteParams := TDictionary<string, string>.Create;
      try
        RouteParams.Add('UserGuid', GuidStr); // ✅ Já está correto
        MockContext := TMockFactory.CreateHttpContextWithRoute('', RouteParams);

        var Value := Binder.BindRoute(TypeInfo(TRouteTest), MockContext);
        var Test := Value.AsType<TRouteTest>;
        Writeln('  userguid=' + GuidStr + ' -> ' + GUIDToString(Test.UserGuid));
      finally
        RouteParams.Free;
      end;
    end;

    // ✅ TESTE 4: Campos opcionais (não presentes)
    Writeln(#10 + '✅ TESTE 4: Campos opcionais/faltantes');

    RouteParams := TDictionary<string, string>.Create;
    try
      // Apenas alguns parâmetros
      RouteParams.Add('user_id', '456');
      RouteParams.Add('Category', 'books'); // ✅ Agora com "Category"

      MockContext := TMockFactory.CreateHttpContextWithRoute('', RouteParams);

      var Value := Binder.BindRoute(TypeInfo(TRouteTest), MockContext);
      var RouteTest := Value.AsType<TRouteTest>;

      Writeln('  UserId: ', RouteTest.UserId, ' (Expected: 456)');
      Writeln('  OrderId: ', RouteTest.OrderId, ' (Expected: 0 - default)');
      Writeln('  IsActive: ', RouteTest.IsActive, ' (Expected: False - default)');
      Writeln('  Category: ', RouteTest.Category, ' (Expected: books)');
    finally
      RouteParams.Free;
    end;

    Writeln(#10 + '=== SUCESSO BINDROUTE COMPREENSIVO! ===');

  except
    on E: Exception do
      Writeln('❌ ERRO BindRoute: ', E.ClassName, ' - ', E.Message);
  end;
end;

procedure TestBindRouteEdgeCases;
type
  TRouteEdgeTest = record
    [FromRoute] Id: SmallInt;
    [FromRoute] BigId: Int64;
    [FromRoute] Price: Double;
    [FromRoute] Enabled: Boolean;
    [FromRoute] Status: Integer;
  end;

var
  MockContext: IHttpContext;
  Binder: IModelBinder;
  RouteParams: TDictionary<string, string>;
begin
  Writeln('=== TESTE CASOS EXTREMOS BINDROUTE ===');

  try
    Binder := TModelBinder.Create;

    // ✅ TESTE: Valores extremos
    Writeln('✅ TESTE: Valores extremos');

    RouteParams := TDictionary<string, string>.Create;
    try
      RouteParams.Add('Id', '32767');           // ✅ Agora com "Id"
      RouteParams.Add('BigId', '9223372036854775807'); // ✅ Agora com "BigId"
      RouteParams.Add('Price', '999.99');       // ✅ Agora com "Price"
      RouteParams.Add('Enabled', '1');          // ✅ Agora com "Enabled"
      RouteParams.Add('Status', '2');           // ✅ Agora com "Status"

      MockContext := TMockFactory.CreateHttpContextWithRoute('', RouteParams);

      var RouteTest: TRouteEdgeTest;
      var Value := Binder.BindRoute(TypeInfo(TRouteEdgeTest), MockContext);
      RouteTest := Value.AsType<TRouteEdgeTest>;

      Writeln('  Id: ', RouteTest.Id, ' (Expected: 32767)');
      Writeln('  BigId: ', RouteTest.BigId, ' (Expected: 9223372036854775807)');
      Writeln('  Price: ', FormatFloat('0.00', RouteTest.Price), ' (Expected: 999.99)');
      Writeln('  Enabled: ', RouteTest.Enabled, ' (Expected: True)');
      Writeln('  Status: ', RouteTest.Status, ' (Expected: 2)');
    finally
      RouteParams.Free;
    end;

    // ✅ TESTE: Valores negativos
    Writeln(#10 + '✅ TESTE: Valores negativos');

    RouteParams := TDictionary<string, string>.Create;
    try
      RouteParams.Add('Id', '-123');
      RouteParams.Add('BigId', '-999999');
      RouteParams.Add('Price', '-45.67');
      RouteParams.Add('Enabled', '0');

      MockContext := TMockFactory.CreateHttpContextWithRoute('', RouteParams);

      var Value := Binder.BindRoute(TypeInfo(TRouteEdgeTest), MockContext);
      var RouteTest := Value.AsType<TRouteEdgeTest>;

      Writeln('  Id negativo: ', RouteTest.Id, ' (Expected: -123)');
      Writeln('  BigId negativo: ', RouteTest.BigId, ' (Expected: -999999)');
      Writeln('  Price negativo: ', FormatFloat('0.00', RouteTest.Price), ' (Expected: -45.67)');
      Writeln('  Enabled=false: ', RouteTest.Enabled, ' (Expected: False)');
    finally
      RouteParams.Free;
    end;

    Writeln('=== SUCESSO CASOS EXTREMOS BINDROUTE! ===');

  except
    on E: Exception do
      Writeln('❌ ERRO Edge Cases BindRoute: ', E.ClassName, ' - ', E.Message);
  end;
end;


procedure TestBindHeaderComprehensive;
type
  THeaderTest = record
    [FromHeader('X-User-Id')] UserId: Integer;
    [FromHeader('X-Api-Key')] ApiKey: string;
    [FromHeader] Authorization: string;
    [FromHeader('X-Is-Admin')] IsAdmin: Boolean;
    [FromHeader('X-Correlation-Id')] CorrelationId: TGUID;
    NormalField: string; // Sem atributo
  end;

var
  MockContext: IHttpContext;
  Binder: IModelBinder;
  Headers: TDictionary<string, string>;
begin
  Writeln('=== TESTE BINDHEADER COMPREENSIVO ===');

  try
    Binder := TModelBinder.Create;

    // ✅ TESTE: Headers com diferentes formatos
    Headers := TDictionary<string, string>.Create;
    try
      // Headers podem vir em qualquer case (serão normalizados para lowercase)
      Headers.Add('x-user-id', '123');
      Headers.Add('X-API-KEY', 'secret-key-123'); // Mix de case
      Headers.Add('Authorization', 'Bearer token123');
      Headers.Add('x-is-admin', 'true');
      Headers.Add('X-Correlation-Id', '{C87A33C3-116A-4A31-9A15-9D9A8B6D9C41}');
      // Headers.Add('X-Not-Mapped', 'some-value'); // Header não mapeado

      MockContext := TMockFactory.CreateHttpContextWithHeaders('', Headers);

      var HeaderTest: THeaderTest;
      var Value := Binder.BindHeader(TypeInfo(THeaderTest), MockContext);
      HeaderTest := Value.AsType<THeaderTest>;

      Writeln('  UserId: ', HeaderTest.UserId, ' (Expected: 123)');
      Writeln('  ApiKey: ', HeaderTest.ApiKey, ' (Expected: secret-key-123)');
      Writeln('  Authorization: ', HeaderTest.Authorization, ' (Expected: Bearer token123)');
      Writeln('  IsAdmin: ', HeaderTest.IsAdmin, ' (Expected: True)');
      Writeln('  CorrelationId: ', GUIDToString(HeaderTest.CorrelationId),
        ' (Expected: {C87A33C3-116A-4A31-9A15-9D9A8B6D9C41})');
      Writeln('  NormalField: "', HeaderTest.NormalField, '" (Expected: empty - no binding)');

    finally
      Headers.Free;
    end;

    Writeln('=== SUCESSO BINDHEADER COMPREENSIVO! ===');

  except
    on E: Exception do
      Writeln('❌ ERRO BindHeader: ', E.ClassName, ' - ', E.Message);
  end;
end;

type
  IUserService = interface
    ['{C172F92C-7F73-483E-8BED-311D23204973}']
    function GetUserName: string;
  end;

  ILogger = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    procedure Log(const Msg: string);
  end;

  TUserService = class(TInterfacedObject, IUserService)
  public
    function GetUserName: string;
  end;

  TLogger = class(TInterfacedObject, ILogger)
  public
    procedure Log(const Msg: string);
  end;

  TDatabaseService = class
  public
    function GetConnection: string;
  end;

  TServiceTest = record
    [FromServices] UserService: IUserService;    // ✅ Interface registrada
    [FromServices] Logger: ILogger;              // ✅ Interface registrada
    [FromServices] Database: TDatabaseService;   // ✅ Classe registrada
    [FromServices] MissingService: IInterface;   // ❌ Interface não registrada
    NormalField: Integer;                        // ❌ Sem atributo
  end;

{ TUserService }

function TUserService.GetUserName: string;
begin
  Result := 'John Doe (from DI container)';
end;

{ TLogger }

procedure TLogger.Log(const Msg: string);
begin
  Writeln('    [LOG] ', Msg);
end;

{ TDatabaseService }

function TDatabaseService.GetConnection: string;
begin
  Result := 'Connected to database';
end;

procedure TestBindServicesComprehensive;
var
  MockContext: IHttpContext;
  Binder: IModelBinder;
  Services: IServiceCollection;
begin
  Writeln('=== TESTE BINDSERVICES COMPREENSIVO ===');

  try
    // Configurar DI Container
    Services := TDextServiceCollection.Create;
    TServiceCollectionExtensions.AddSingleton<IUserService, TUserService>(Services);
    TServiceCollectionExtensions.AddSingleton<ILogger, TLogger>(Services);
    TServiceCollectionExtensions.AddSingleton<TDatabaseService>(Services);
    // IInterface não está registrado - testar resiliência

    var ServiceProvider := Services.BuildServiceProvider;

    Binder := TModelBinder.Create;

    // Criar contexto com service provider
    MockContext := TMockFactory.CreateHttpContextWithServices('', ServiceProvider);

    var ServiceTest: TServiceTest;
    var Value := Binder.BindServices(TypeInfo(TServiceTest), MockContext);
    ServiceTest := Value.AsType<TServiceTest>;

    // Verificar injeções
    if Assigned(ServiceTest.UserService) then
    begin
      Writeln('  ✅ UserService injected');
      Writeln('    UserName: ', ServiceTest.UserService.GetUserName);
    end
    else
      Writeln('  ❌ UserService not injected');

    if Assigned(ServiceTest.Logger) then
    begin
      Writeln('  ✅ Logger injected');
      ServiceTest.Logger.Log('Test message from DI');
    end
    else
      Writeln('  ❌ Logger not injected');

    if Assigned(ServiceTest.Database) then
    begin
      Writeln('  ✅ DatabaseService injected');
      Writeln('    Connection: ', ServiceTest.Database.GetConnection);
    end
    else
      Writeln('  ❌ DatabaseService not injected');

    if Assigned(ServiceTest.MissingService) then
      Writeln('  ❌ MissingService was injected (unexpected)')
    else
      Writeln('  ✅ MissingService correctly not injected');

    Writeln('  NormalField: ', ServiceTest.NormalField, ' (Expected: 0 - no injection)');

    Writeln('=== SUCESSO BINDSERVICES COMPREENSIVO! ===');

    ServiceTest.UserService := nil;
    ServiceTest.Logger := nil;
    ServiceTest.Database.Free;
    ServiceTest.MissingService := nil;
    ServiceTest.NormalField := 0;

    MockContext := nil;
    Binder := nil;
    Services := nil;
  except
    on E: Exception do
      Writeln('❌ ERRO BindServices: ', E.ClassName, ' - ', E.Message);
  end;
end;

end.
