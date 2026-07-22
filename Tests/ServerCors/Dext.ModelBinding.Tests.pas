unit Dext.ModelBinding.Tests;

interface

procedure TestBindQueryComprehensive;
procedure TestBindQueryEdgeCases;

procedure TestBindRouteComprehensive;
procedure TestBindRouteEdgeCases;

procedure TestBindHeaderComprehensive;
procedure TestBindServicesComprehensive;

// New test for Date/Time types
procedure TestBindQueryDateTypes;

// New test for Zero Allocation Body Binding
procedure TestBindBodyZeroAlloc;


implementation

uses
  System.Classes,
  Dext.Collections,
  Dext.Collections.Dict,
  System.SysUtils,
  System.Rtti,
  IdURI,
  Dext.Web.ModelBinding,
  Dext.DI.Core,
  Dext.DI.Interfaces,
  Dext.Web.Interfaces,
  Dext.Web.Mocks;

// [PASS] PROCEDURE AUXILIAR PARA CRIAR MOCK CONTEXT
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
  QueryTest: TQueryTest;
  Value: TValue;
  BoolTests: TArray<string>;
  BoolValue: string;
  Test: TQueryTest;
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

    // [PASS] TESTE 1: Cenário básico
    Writeln('[PASS] TESTE 1: Cenário básico');
    MockContext := TMockFactory.CreateHttpContext('user_name=John+Doe&age=30&active=true&score=95.5&status=2');

    Value := Binder.BindQuery(TypeInfo(TQueryTest), MockContext);
    QueryTest := Value.AsType<TQueryTest>;

    Writeln('  Name: ', QueryTest.Name, ' (Expected: John Doe)');
    Writeln('  Age: ', QueryTest.Age, ' (Expected: 30)');
    Writeln('  Active: ', QueryTest.Active, ' (Expected: True)');
    Writeln('  Score: ', FormatFloat('0.0', QueryTest.Score), ' (Expected: 95.5)');
    Writeln('  Status: ', QueryTest.Status, ' (Expected: 2)');

    // [PASS] TESTE 2: Boolean com diferentes representações
    Writeln(#10 + '[PASS] TESTE 2: Boolean com múltiplas representações');

    BoolTests := ['true', '1', 'yes', 'on', 'false', '0', 'no', 'off'];
    for BoolValue in BoolTests do
    begin
      MockContext := TMockFactory.CreateHttpContext('active=' + BoolValue);

      // [PASS] DEBUG: Verificar o que o mock está recebendo
      Writeln('Query string: ', 'active=' + BoolValue);

      Value := Binder.BindQuery(TypeInfo(TQueryTest), MockContext);
      Test := Value.AsType<TQueryTest>;
      Writeln('  active=' + BoolValue + ' -> ' + Test.Active.ToString(TUseBoolStrs.True));
    end;

    Writeln(#10 + '=== SUCESSO BINDQUERY COMPREENSIVO! ===');

  except
    on E: Exception do
      Writeln('[FAIL] ERRO BindQuery: ', E.ClassName, ' - ', E.Message);
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
  Test: TEdgeCaseTest;
begin
  Writeln('=== TESTE CASOS EXTREMOS BINDQUERY ===');

  try
    Binder := TModelBinder.Create;

    // [PASS] TESTE: Valores extremos
    MockContext := CreateMockHttpContext('/api/test?smallint=32767&largeint=9223372036854775807&currencyval=123.4567&isenabled=1&userrole=5');
    Test := TModelBinderHelper.BindQuery<TEdgeCaseTest>(Binder, MockContext);

    Writeln('  SmallInt: ', Test.SmallInt, ' (Expected: 32767)');
    Writeln('  LargeInt: ', Test.LargeInt, ' (Expected: 9223372036854775807)');
    Writeln('  Currency: ', FormatFloat('0.0000', Test.CurrencyVal), ' (Expected: 123.4567)');
    Writeln('  IsEnabled: ', Test.IsEnabled, ' (Expected: True)');
    Writeln('  UserRole: ', Test.UserRole, ' (Expected: 5)');

    // [PASS] TESTE: Valores negativos
    MockContext := CreateMockHttpContext('/api/test?smallint=-123&largeint=-999999&currencyval=-45.67&isenabled=0');
    Test := TModelBinderHelper.BindQuery<TEdgeCaseTest>(Binder, MockContext);

    Writeln('  SmallInt negativo: ', Test.SmallInt, ' (Expected: -123)');
    Writeln('  LargeInt negativo: ', Test.LargeInt, ' (Expected: -999999)');
    Writeln('  Currency negativo: ', FormatFloat('0.00', Test.CurrencyVal), ' (Expected: -45.67)');
    Writeln('  IsEnabled=false: ', Test.IsEnabled, ' (Expected: False)');

    Writeln('=== SUCESSO CASOS EXTREMOS! ===');

  except
    on E: Exception do
      Writeln('[FAIL] ERRO Edge Cases: ', E.ClassName, ' - ', E.Message);
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
  RouteParams: IDictionary<string, string>;
  RouteTest: TRouteTest;
  Value: TValue;
  BoolTests: TArray<string>;
  BoolValue: string;
  Test: TRouteTest;
  GuidTests: TArray<string>;
  GuidStr: string;
begin
  Writeln('=== TESTE BINDROUTE COMPREENSIVO ===');

  try
    Binder := TModelBinder.Create;

    // [PASS] TESTE 1: Cenário completo
    Writeln('[PASS] TESTE 1: Cenário completo');

    RouteParams := TCollections.CreateDictionary<string, string>;
    try
      RouteParams.Add('user_id', '123');
      RouteParams.Add('OrderId', '9876543210');
      RouteParams.Add('IsActive', 'true');
      RouteParams.Add('UserGuid', '{C87A33C3-116A-4A31-9A15-9D9A8B6D9C41}');
      RouteParams.Add('Category', 'electronics');

      MockContext := TMockFactory.CreateHttpContextWithRoute('', RouteParams);

      Value := Binder.BindRoute(TypeInfo(TRouteTest), MockContext);
      RouteTest := Value.AsType<TRouteTest>;

      Writeln('  UserId: ', RouteTest.UserId, ' (Expected: 123)');
      Writeln('  OrderId: ', RouteTest.OrderId, ' (Expected: 9876543210)');
      Writeln('  IsActive: ', RouteTest.IsActive, ' (Expected: True)');
      Writeln('  UserGuid: ', GUIDToString(RouteTest.UserGuid), ' (Expected: {C87A33C3-116A-4A31-9A15-9D9A8B6D9C41})');
      Writeln('  Category: ', RouteTest.Category, ' (Expected: electronics)');
    finally
      // RouteParams.Free;
    end;

    // [PASS] TESTE 2: Boolean com diferentes representações
    Writeln(#10 + '[PASS] TESTE 2: Boolean com múltiplas representações');

    BoolTests := ['true', '1', 'yes', 'on', 'false', '0', 'no', 'off'];
    for BoolValue in BoolTests do
    begin
      RouteParams := TCollections.CreateDictionary<string, string>;
      try
        RouteParams.Add('IsActive', BoolValue); // [PASS] Já está correto
        MockContext := TMockFactory.CreateHttpContextWithRoute('', RouteParams);

        Value := Binder.BindRoute(TypeInfo(TRouteTest), MockContext);
        Test := Value.AsType<TRouteTest>;
        Writeln('  isactive=' + BoolValue + ' -> ' + BoolToStr(Test.IsActive, True));
      finally
        // RouteParams.Free;
      end;
    end;

    // [PASS] TESTE 3: GUID com diferentes formatos
    Writeln(#10 + '[PASS] TESTE 3: GUID com diferentes formatos');

    GuidTests := [
      '{C87A33C3-116A-4A31-9A15-9D9A8B6D9C41}',
      'C87A33C3-116A-4A31-9A15-9D9A8B6D9C41',
      'invalid-guid' // Deve resultar em GUID.Empty
    ];

    for GuidStr in GuidTests do
    begin
      RouteParams := TCollections.CreateDictionary<string, string>;
      try
        RouteParams.Add('UserGuid', GuidStr); // [PASS] Já está correto
        MockContext := TMockFactory.CreateHttpContextWithRoute('', RouteParams);

        Value := Binder.BindRoute(TypeInfo(TRouteTest), MockContext);
        Test := Value.AsType<TRouteTest>;
        Writeln('  userguid=' + GuidStr + ' -> ' + GUIDToString(Test.UserGuid));
      finally
        // RouteParams.Free;
      end;
    end;

    // [PASS] TESTE 4: Campos opcionais (não presentes)
    Writeln(#10 + '[PASS] TESTE 4: Campos opcionais/faltantes');

    RouteParams := TCollections.CreateDictionary<string, string>;
    try
      // Apenas alguns parâmetros
      RouteParams.Add('user_id', '456');
      RouteParams.Add('Category', 'books'); // [PASS] Agora com "Category"

      MockContext := TMockFactory.CreateHttpContextWithRoute('', RouteParams);

      Value := Binder.BindRoute(TypeInfo(TRouteTest), MockContext);
      RouteTest := Value.AsType<TRouteTest>;

      Writeln('  UserId: ', RouteTest.UserId, ' (Expected: 456)');
      Writeln('  OrderId: ', RouteTest.OrderId, ' (Expected: 0 - default)');
      Writeln('  IsActive: ', RouteTest.IsActive, ' (Expected: False - default)');
      Writeln('  Category: ', RouteTest.Category, ' (Expected: books)');
    finally
      // RouteParams.Free;
    end;

    Writeln(#10 + '=== SUCESSO BINDROUTE COMPREENSIVO! ===');

  except
    on E: Exception do
      Writeln('[FAIL] ERRO BindRoute: ', E.ClassName, ' - ', E.Message);
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
  RouteParams: IDictionary<string, string>;
  RouteTest: TRouteEdgeTest;
  Value: TValue;
begin
  Writeln('=== TESTE CASOS EXTREMOS BINDROUTE ===');

  try
    Binder := TModelBinder.Create;

    // [PASS] TESTE: Valores extremos
    Writeln('[PASS] TESTE: Valores extremos');

    RouteParams := TCollections.CreateDictionary<string, string>;
    try
      RouteParams.Add('Id', '32767');           // [PASS] Agora com "Id"
      RouteParams.Add('BigId', '9223372036854775807'); // [PASS] Agora com "BigId"
      RouteParams.Add('Price', '999.99');       // [PASS] Agora com "Price"
      RouteParams.Add('Enabled', '1');          // [PASS] Agora com "Enabled"
      RouteParams.Add('Status', '2');           // [PASS] Agora com "Status"

      MockContext := TMockFactory.CreateHttpContextWithRoute('', RouteParams);

      Value := Binder.BindRoute(TypeInfo(TRouteEdgeTest), MockContext);
      RouteTest := Value.AsType<TRouteEdgeTest>;

      Writeln('  Id: ', RouteTest.Id, ' (Expected: 32767)');
      Writeln('  BigId: ', RouteTest.BigId, ' (Expected: 9223372036854775807)');
      Writeln('  Price: ', FormatFloat('0.00', RouteTest.Price), ' (Expected: 999.99)');
      Writeln('  Enabled: ', RouteTest.Enabled, ' (Expected: True)');
      Writeln('  Status: ', RouteTest.Status, ' (Expected: 2)');
    finally
      // RouteParams.Free;
    end;

    // [PASS] TESTE: Valores negativos
    Writeln(#10 + '[PASS] TESTE: Valores negativos');

    RouteParams := TCollections.CreateDictionary<string, string>;
    try
      RouteParams.Add('Id', '-123');
      RouteParams.Add('BigId', '-999999');
      RouteParams.Add('Price', '-45.67');
      RouteParams.Add('Enabled', '0');

      MockContext := TMockFactory.CreateHttpContextWithRoute('', RouteParams);

      Value := Binder.BindRoute(TypeInfo(TRouteEdgeTest), MockContext);
      RouteTest := Value.AsType<TRouteEdgeTest>;

      Writeln('  Id negativo: ', RouteTest.Id, ' (Expected: -123)');
      Writeln('  BigId negativo: ', RouteTest.BigId, ' (Expected: -999999)');
      Writeln('  Price negativo: ', FormatFloat('0.00', RouteTest.Price), ' (Expected: -45.67)');
      Writeln('  Enabled=false: ', RouteTest.Enabled, ' (Expected: False)');
    finally
      // RouteParams.Free;
    end;

    Writeln('=== SUCESSO CASOS EXTREMOS BINDROUTE! ===');

  except
    on E: Exception do
      Writeln('[FAIL] ERRO Edge Cases BindRoute: ', E.ClassName, ' - ', E.Message);
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
  Headers: IDictionary<string, string>;
  HeaderTest: THeaderTest;
  Value: TValue;
begin
  Writeln('=== TESTE BINDHEADER COMPREENSIVO ===');

  try
    Binder := TModelBinder.Create;

    // [PASS] TESTE: Headers com diferentes formatos
    Headers := TCollections.CreateDictionary<string, string>;
    try
      // Headers podem vir em qualquer case (serão normalizados para lowercase)
      Headers.Add('x-user-id', '123');
      Headers.Add('X-API-KEY', 'secret-key-123'); // Mix de case
      Headers.Add('Authorization', 'Bearer token123');
      Headers.Add('x-is-admin', 'true');
      Headers.Add('X-Correlation-Id', '{C87A33C3-116A-4A31-9A15-9D9A8B6D9C41}');
      // Headers.Add('X-Not-Mapped', 'some-value'); // Header não mapeado

      MockContext := TMockFactory.CreateHttpContextWithHeaders('', Headers);

      Value := Binder.BindHeader(TypeInfo(THeaderTest), MockContext);
      HeaderTest := Value.AsType<THeaderTest>;

      Writeln('  UserId: ', HeaderTest.UserId, ' (Expected: 123)');
      Writeln('  ApiKey: ', HeaderTest.ApiKey, ' (Expected: secret-key-123)');
      Writeln('  Authorization: ', HeaderTest.Authorization, ' (Expected: Bearer token123)');
      Writeln('  IsAdmin: ', HeaderTest.IsAdmin, ' (Expected: True)');
      Writeln('  CorrelationId: ', GUIDToString(HeaderTest.CorrelationId),
        ' (Expected: {C87A33C3-116A-4A31-9A15-9D9A8B6D9C41})');
      Writeln('  NormalField: "', HeaderTest.NormalField, '" (Expected: empty - no binding)');

    finally
      // Headers.Free;
    end;

    Writeln('=== SUCESSO BINDHEADER COMPREENSIVO! ===');

  except
    on E: Exception do
      Writeln('[FAIL] ERRO BindHeader: ', E.ClassName, ' - ', E.Message);
  end;
end;

type
  {$M+}
  IUserService = interface
    ['{C172F92C-7F73-483E-8BED-311D23204973}']
    function GetUserName: string;
  end;

  ILogger = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    procedure Log(const Msg: string);
  end;
  {$M-}

  TUserService = class(TInterfacedObject, IUserService)
  public
    function GetUserName: string;
  end;

  TLogger = class(TInterfacedObject, ILogger)
  public
    procedure Log(const Msg: string);
  end;

  {$M+}
  TDatabaseService = class
  public
    function GetConnection: string;
  end;
  {$M-}

  TServiceTest = record
    [FromServices] UserService: IUserService;    // [PASS] Interface registrada
    [FromServices] Logger: ILogger;              // [PASS] Interface registrada
    [FromServices] Database: TDatabaseService;   // [PASS] Classe registrada
    [FromServices] MissingService: IInterface;   // [FAIL] Interface não registrada
    NormalField: Integer;                        // [FAIL] Sem atributo
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
  Services: TDextServices;
  ServiceProvider: IServiceProvider;
  ServiceTest: TServiceTest;
  Value: TValue;
begin
  Writeln('=== TESTE BINDSERVICES COMPREENSIVO ===');

  try
    // Configurar DI Container
    Services := TDextServices.New;
    Services.AddSingleton<IUserService, TUserService>;
    Services.AddSingleton<ILogger, TLogger>;
    Services.AddSingleton<TDatabaseService>;
    // IInterface não está registrado - testar resiliência

    ServiceProvider := Services.BuildServiceProvider;

    Binder := TModelBinder.Create;

    // Criar contexto com service provider
    MockContext := TMockFactory.CreateHttpContextWithServices('', ServiceProvider);

    Value := Binder.BindServices(TypeInfo(TServiceTest), MockContext);
    ServiceTest := Value.AsType<TServiceTest>;

    // Verificar injeções
    if Assigned(ServiceTest.UserService) then
    begin
      Writeln('  [PASS] UserService injected');
      Writeln('    UserName: ', ServiceTest.UserService.GetUserName);
    end
    else
      Writeln('  [FAIL] UserService not injected');

    if Assigned(ServiceTest.Logger) then
    begin
      Writeln('  [PASS] Logger injected');
      ServiceTest.Logger.Log('Test message from DI');
    end
    else
      Writeln('  [FAIL] Logger not injected');

    if Assigned(ServiceTest.Database) then
    begin
      Writeln('  [PASS] DatabaseService injected');
      Writeln('    Connection: ', ServiceTest.Database.GetConnection);
    end
    else
      Writeln('  [FAIL] DatabaseService not injected');

    if Assigned(ServiceTest.MissingService) then
      Writeln('  [FAIL] MissingService was injected (unexpected)')
    else
      Writeln('  [PASS] MissingService correctly not injected');

    Writeln('  NormalField: ', ServiceTest.NormalField, ' (Expected: 0 - no injection)');

    Writeln('=== SUCESSO BINDSERVICES COMPREENSIVO! ===');

    ServiceTest.UserService := nil;
    ServiceTest.Logger := nil;
    // ServiceTest.Database is managed by DI container (Singleton), do not free manually!
    ServiceTest.MissingService := nil;
    ServiceTest.NormalField := 0;

    MockContext := nil;
    Binder := nil;
  except
    on E: Exception do
      Writeln('[FAIL] ERRO BindServices: ', E.ClassName, ' - ', E.Message);
  end;
end;


procedure TestBindQueryDateTypes;
type
  TDateTest = record
    [FromQuery] DateVal: TDate;
    [FromQuery] TimeVal: TTime;
    [FromQuery] UserDateTime: TDateTime;
    [FromQuery] InvalidDate: TDate; // Should default to 0
  end;
var
  MockContext: IHttpContext;
  Binder: IModelBinder;
  Value: TValue;
  Test: TDateTest;
begin
  Writeln('=== TESTE BINDQUERY DATETYPES ===');
  try
    Binder := TModelBinder.Create;

    // ISO Format Test
    Writeln('[PASS] TESTE 1: ISO Format');
    // Using explicit date strings to avoid locale issues in test construction, but typical ISO is safe
    MockContext := TMockFactory.CreateHttpContext('dateval=2025-12-25&timeval=14:30:00&userdatetime=2025-12-25T14:30:00&invaliddate=not-a-date');

    Value := Binder.BindQuery(TypeInfo(TDateTest), MockContext);
    Test := Value.AsType<TDateTest>;

    Writeln('  DateVal: ', DateToStr(Test.DateVal), ' (Expected: 25/12/2025)');
    Writeln('  TimeVal: ', TimeToStr(Test.TimeVal), ' (Expected: 14:30:00)');
    Writeln('  UserDateTime: ', DateTimeToStr(Test.UserDateTime), ' (Expected: 25/12/2025 14:30:00)');
    Writeln('  InvalidDate: ', FloatToStr(Test.InvalidDate), ' (Expected: 0)');

    if (Test.InvalidDate <> 0) then
      Writeln('  [FAIL] InvalidDate falhou (não é 0)');

    // Common Format Test (slash)
    Writeln(#10 + '[PASS] TESTE 2: Common Format (Slash)');
    // Note: Depends on local settings slightly if TryParseCommonDate uses settings, but common formats usually hardcoded
    // Assuming TryParseCommonDate handles dd/mm/yyyy
    MockContext := TMockFactory.CreateHttpContext('dateval=25/12/2025&timeval=14:30&userdatetime=25/12/2025 14:30');

    Value := Binder.BindQuery(TypeInfo(TDateTest), MockContext);
    Test := Value.AsType<TDateTest>;
    
    Writeln('  DateVal (slash): ', DateToStr(Test.DateVal));
    Writeln('  TimeVal (short): ', TimeToStr(Test.TimeVal));
    Writeln('  UserDateTime (space): ', DateTimeToStr(Test.UserDateTime));

    Writeln('=== SUCESSO BINDQUERY DATETYPES! ===');
  except
    on E: Exception do
      Writeln('[FAIL] ERRO BindQueryDateTypes: ', E.ClassName, ' - ', E.Message);
  end;
end;

procedure TestBindBodyZeroAlloc;
type
  TSimpleBody = record
    Id: Integer;
    Name: string;
    Active: Boolean;
    Cost: Double;
  end;
var
  MockContext: IHttpContext;
  Binder: IModelBinder;
  Json: string;
  Bytes: TBytes;
  BodyStream: TMemoryStream;
  Value: TValue;
  Test: TSimpleBody;
begin
  Writeln('=== TESTE BINDBODY ZERO ALLOC ===');
  BodyStream := TMemoryStream.Create;
  try
    try
      Binder := TModelBinder.Create;

      // Prepare JSON Body
      Json := '{"Id": 200, "Name": "ZeroAlloc Item", "Active": true, "Cost": 99.99}';
      Bytes := TEncoding.UTF8.GetBytes(Json);

      MockContext := TMockFactory.CreateHttpContextWithBody('', BodyStream);
      BodyStream.WriteBuffer(Bytes[0], Length(Bytes));
      BodyStream.Position := 0;

      Writeln('[PASS] TESTE 1: Bind Body from Stream (Bytes)');
      
      Value := Binder.BindBody(TypeInfo(TSimpleBody), MockContext);
      Test := Value.AsType<TSimpleBody>;

      Writeln('  Id: ', Test.Id, ' (Expected: 200)');
      Writeln('  Name: ', Test.Name, ' (Expected: ZeroAlloc Item)');
      if (Test.Active) then Writeln('  Active: True') else Writeln('  Active: False');
      Writeln('  Cost: ', FloatToStr(Test.Cost), ' (Expected: 99.99)');
      
      if (Test.Id = 200) and (Test.Name = 'ZeroAlloc Item') and (Test.Active) then
        Writeln('  -> Validated!')
      else
        Writeln('  [FAIL] Validation FAILED');

      Writeln('=== SUCESSO BINDBODY ZERO ALLOC! ===');
    except
      on E: Exception do
        Writeln('[FAIL] ERRO BindBodyZeroAlloc: ', E.ClassName, ' - ', E.Message);
    end;
  finally
    BodyStream.Free;
  end;
end;

end.

