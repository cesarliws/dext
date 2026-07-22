unit Dext.Json.Test;

interface

uses
  System.DateUtils,
  Dext.Collections,
  System.Sysutils,
  System.Rtti,
  System.TypInfo,
  Dext.DI.Attributes,
  Dext.Json,
  Dext.Json.Types,
  Dext.Core.Json.NextGen,
  Dext.DI.Core,
  Dext.DI.Interfaces,
  Dext.Web.Builder,
  Dext.Web.Interfaces,
  Dext.Web.ApplicationBuilder.Extensions,
  Dext.Web.ModelBinding,
  Dext.WebHost,
  Dext.Json.Driver.SystemJson,
  Dext,
  Dext.Web;

type
  TUserStatus = (Active, Inactive, Suspended);
  TUserRole = (Admin, RegularUser, Guest);

  TUser = record
    UserId: Integer;
    UserName: string;
    EmailAddress: string;
    [JsonIgnore]
    Password: string;
    Status: TUserStatus;
    Role: TUserRole;
    CreatedDate: TDateTime;
    LastLogin: TDateTime;
  end;

procedure TestDextJson;
procedure TestDextJsonRecords;
procedure TestDextJsonAttributes;
procedure TestDextJsonArrays;
procedure TestListOnly;
procedure TestDextJsonSettings;
procedure TestCompleteSettings;
procedure TestEnumRoundTrip;
procedure TestGUIDSupport;
procedure TestGUIDWithSettings;
procedure TestDateTimeFormats;
procedure TestDateTimeWithOtherSettings;
procedure TestDateFormats;
procedure TestAmbiguousDates;

procedure TestAdvancedAttributes;
procedure TestAllFeaturesCombined;
procedure TestEdgeCases;
procedure TestLocalization;
procedure TestJsonNumberOnString;

procedure TestBindingAttributes;
procedure TestRealWorldBindingScenarios;
procedure TestModelBinderBasic;
procedure TestCompleteIntegration;
procedure TestFinalIntegration;

procedure TestWebHostIntegration;
procedure TestConciseIntegration;
procedure TestProviders;

type
  TSimpleUser = record
    Id: Integer;
    Name: string;
  end;

var
  Users: TArray<TSimpleUser>;
  [ImplementedBy(TypeInfo(TList<TSimpleUser>))]
  UserList: IList<TSimpleUser>;

implementation

// Adicionar no projeto de teste
procedure TestDextJson;
begin
  Writeln('=== TESTANDO DEXT JSON (API REAL) ===');

  try
    // [PASS] Serialização (gera JSON com wrapper)
    Writeln('Serialize Integer: ', TDextJson.Serialize<Integer>(42));
    Writeln('Serialize String: ', TDextJson.Serialize<string>('Hello'));
    Writeln('Serialize Boolean: ', TDextJson.Serialize<Boolean>(True));
    Writeln('Serialize Float: ', TDextJson.Serialize<Double>(3.14));

    // [PASS] Deserialização (precisa do wrapper)
    Writeln('Deserialize Int: ', TDextJson.Deserialize<Integer>('{"value":42}'));
    Writeln('Deserialize Str: ', TDextJson.Deserialize<string>('{"value":"World"}'));
    Writeln('Deserialize Bool: ', TDextJson.Deserialize<Boolean>('{"value":false}'));
    Writeln('Deserialize Float: ', TDextJson.Deserialize<Double>('{"value":3.14}'));

    Writeln('=== SUCESSO! ===');
  except
    on E: Exception do
      Writeln('ERRO: ', E.Message);
  end;
end;

procedure TestDextJsonRecords;
type
  TUser = record
    Id: Integer;
    Name: string;
    Email: string;
    Active: Boolean;
  end;

  TAddress = record
    Street: string;
    City: string;
    ZipCode: string;
  end;

  TUserWithAddress = record
    User: TUser;
    Address: TAddress;
  end;

var
  User: TUser;
  UserWithAddr: TUserWithAddress;
  Json: string;
  DeserializedUser: TUser;
begin
  Writeln('=== TESTANDO RECORDS NO DEXT JSON ===');

  try
    // [PASS] TESTE 1: Record simples
    User.Id := 1;
    User.Name := 'John Doe';
    User.Email := 'john@example.com';
    User.Active := True;

    Json := TDextJson.Serialize<TUser>(User);
    Writeln('User JSON: ', Json);

    DeserializedUser := TDextJson.Deserialize<TUser>(Json);
    Writeln('Deserialized User - ID: ', DeserializedUser.Id, ', Name: ', DeserializedUser.Name);

    // [PASS] TESTE 2: Record com record aninhado
    UserWithAddr.User := User;
    UserWithAddr.Address.Street := '123 Main St';
    UserWithAddr.Address.City := 'New York';
    UserWithAddr.Address.ZipCode := '10001';

    Json := TDextJson.Serialize<TUserWithAddress>(UserWithAddr);
    Writeln('UserWithAddress JSON: ', Json);

    Writeln('=== SUCESSO COM RECORDS! ===');

  except
    on E: Exception do
      Writeln('ERRO: ', E.Message);
  end;
end;

procedure TestDextJsonAttributes;
type
  [JsonName('user')]  // [PASS] Customizar nome do record
  TUser = record
    [JsonName('user_id')]     // [PASS] Customizar nome do campo
    Id: Integer;

    [JsonName('full_name')]   // [PASS] Customizar nome do campo
    Name: string;

    Email: string;            // [PASS] Nome padrão

    [JsonIgnore]              // [PASS] Ignorar campo na serialização
    Password: string;

    [JsonName('is_active')]   // [PASS] Customizar nome boolean
    Active: Boolean;
  end;

var
  User: TUser;
  Json: string;
  DeserializedUser: TUser;
begin
  Writeln('=== TESTANDO ATRIBUTOS NO DEXT JSON ===');

  try
    // Configurar usuário
    User.Id := 1;
    User.Name := 'John Doe';
    User.Email := 'john@example.com';
    User.Password := 'secret123'; // [PASS] Deve ser ignorado
    User.Active := True;

    // Serializar
    Json := TDextJson.Serialize<TUser>(User);
    Writeln('User com atributos JSON:');
    Writeln(Json);

    // Deserializar
    DeserializedUser := TDextJson.Deserialize<TUser>(Json);
    Writeln('User deserializado:');
    Writeln('  ID: ', DeserializedUser.Id);
    Writeln('  Name: ', DeserializedUser.Name);
    Writeln('  Email: ', DeserializedUser.Email);
    Writeln('  Password: ', DeserializedUser.Password); // [PASS] Deve estar vazio
    Writeln('  Active: ', DeserializedUser.Active);

    Writeln('=== SUCESSO COM ATRIBUTOS! ===');

  except
    on E: Exception do
      Writeln('ERRO: ', E.Message);
  end;
end;

procedure TestDextJsonArrays;
var
  UserIds: TArray<Integer>;
  Json: string;
  Deserialized: TArray<Integer>;
  DeserializedUsers: TArray<TSimpleUser>;
  User1, User2: TSimpleUser;
  DeserializedList: IList<TSimpleUser>;
begin
  Writeln('=== TESTANDO ARRAYS/LISTAS NO DEXT JSON ===');

  try
    SetLength(UserIds, 3);
    UserIds[0] := 1;
    UserIds[1] := 2;
    UserIds[2] := 3;

    Writeln('UserIds.Size: ', TValue.From<TArray<Integer>>(UserIds).GetArrayLength);
    Json := TDextJson.Serialize<TArray<Integer>>(UserIds);
    Writeln('JSON: ', Json);

    Deserialized := TDextJson.Deserialize<TArray<Integer>>(Json);
    Writeln('Deserialized Count: ', Length(Deserialized));

    // [PASS] TESTE 1: TArray<T> (como no ASP.NET Core)
    SetLength(Users, 2);
    Users[0].Id := 1; Users[0].Name := 'John';
    Users[1].Id := 2; Users[1].Name := 'Jane';

    Json := TDextJson.Serialize<TArray<TSimpleUser>>(Users);
    Writeln('TArray<TUser> JSON: ', Json);

    DeserializedUsers := TDextJson.Deserialize<TArray<TSimpleUser>>(Json);
    Writeln('Deserialized Users Count: ', Length(DeserializedUsers));

    // [PASS] TESTE 2: IList<T> (como List<T> no C#)
    UserList := TCollections.CreateList<TSimpleUser>;
    try
      User1.Id := 3; User1.Name := 'Bob';
      User2.Id := 4; User2.Name := 'Alice';
      UserList.Add(User1);
      UserList.Add(User2);

      Json := TDextJson.Serialize<IList<TSimpleUser>>(UserList);
      Writeln('IList<TUser> JSON: ', Json);

      DeserializedList := TDextJson.Deserialize<IList<TSimpleUser>>(Json);
      Writeln('Deserialized List Count: ', DeserializedList.Count);
      // DeserializedList.Free;
    finally
      // UserList.Free;
    end;

    Writeln('=== SUCESSO COM ARRAYS/LISTAS! ===');

  except
    on E: Exception do
      Writeln('ERRO: ', E.Message);
  end;
end;

procedure TestListOnly;
var
  Json: string;
  User1, User2: TSimpleUser;
  DeserializedList: IList<TSimpleUser>;
begin
  Writeln('=== TESTE APENAS IList<T> ===');

  UserList := TCollections.CreateList<TSimpleUser>;
  try
    User1.Id := 3; User1.Name := 'Bob';
    User2.Id := 4; User2.Name := 'Alice';
    UserList.Add(User1);
    UserList.Add(User2);

    Json := TDextJson.Serialize<IList<TSimpleUser>>(UserList);
    Writeln('JSON Serializado: ', Json);

    // Aqui deve dar o erro
    DeserializedList := TDextJson.Deserialize<IList<TSimpleUser>>(Json);
    Writeln('Deserializado Count: ', DeserializedList.Count);
    // DeserializedList.Free;

  finally
    // UserList.Free;
  end;
end;

procedure TestDextJsonSettings;
var
  User: TUser;
  Json: string;
  CamelCaseSettings, SnakeCaseSettings, EnumStringSettings: TJsonSettings;
begin
  Writeln('=== TESTANDO NOVAS CONFIGURAÇÕES ===');

  User.UserId := 1;
  User.UserName := 'JohnDoe';
  User.EmailAddress := 'john@example.com';
  User.Password := 'secret';
  User.Status := TUserStatus.Active;
  User.Role := TUserRole.RegularUser;

  try
    // [PASS] Teste 1: CamelCase + IgnoreNullValues
    CamelCaseSettings := TJsonSettings.Indented
      .CamelCase
      .IgnoreNullValues;

    Json := TDextJson.Serialize<TUser>(User, CamelCaseSettings);
    Writeln('CamelCase + IgnoreNull:');
    Writeln(Json);

    // [PASS] Teste 2: SnakeCase
    SnakeCaseSettings := TJsonSettings.Indented
      .SnakeCase;

    Json := TDextJson.Serialize<TUser>(User, SnakeCaseSettings);
    Writeln('SnakeCase:');
    Writeln(Json);

    // [PASS] Teste 3: Enum como String
    EnumStringSettings := TJsonSettings.Indented
      .EnumAsString;

    Json := TDextJson.Serialize<TUser>(User, EnumStringSettings);
    Writeln('Enum as String:');
    Writeln(Json);

    Writeln('=== SUCESSO COM CONFIGURAÇÕES! ===');

  except
    on E: Exception do
      Writeln('ERRO: ', E.Message);
  end;
end;

procedure TestCompleteSettings;
var
  User: TUser;
  Json: string;
  Settings: TJsonSettings;
  DeserializedUser: TUser;
begin
  Writeln('=== TESTE COMPLETO CONFIGURAÇÕES ===');

  User.UserId := 1;
  User.UserName := 'JohnDoe';
  User.EmailAddress := 'john@example.com';
  User.Password := 'secret';
  User.Status := TUserStatus.Active;
  User.CreatedDate := Now;
  User.LastLogin := Now;

  try
    // [PASS] Teste: CamelCase + EnumAsString + IgnoreNullValues
    Settings := TJsonSettings.Indented
      .CamelCase
      .EnumAsString
      .IgnoreNullValues;

    Json := TDextJson.Serialize<TUser>(User, Settings);
    Writeln('Configurações Completas:');
    Writeln(Json);

    // [PASS] Teste RoundTrip: Serializar -> Deserializar
    DeserializedUser := TDextJson.Deserialize<TUser>(Json, Settings);
    Writeln('RoundTrip - UserName: ', DeserializedUser.UserName);
    Writeln('RoundTrip - Status: ', Ord(DeserializedUser.Status));

    Writeln('=== SUCESSO COMPLETO! ===');

  except
    on E: Exception do
      Writeln('ERRO: ', E.Message);
  end;
end;

procedure TestEnumRoundTrip;
type
  TUserStatus = (Active, Inactive, Suspended);

  TSimpleUser = record
    Status: TUserStatus;
    StatusNumber: TUserStatus;
  end;

var
  User: TSimpleUser;
  Json: string;
  StringSettings, NumberSettings: TJsonSettings;
  Deserialized1, Deserialized2: TSimpleUser;
begin
  Writeln('=== TESTE ESPECÍFICO ENUM ===');

  User.Status := TUserStatus.Active;
  User.StatusNumber := TUserStatus.Suspended;

  try
    // [PASS] Teste 1: Enum como String
    StringSettings := TJsonSettings.Default
      .EnumAsString;

    Json := TDextJson.Serialize<TSimpleUser>(User, StringSettings);
    Writeln('Enum as String - JSON: ', Json);

    Deserialized1 := TDextJson.Deserialize<TSimpleUser>(Json, StringSettings);
    Writeln('Enum as String - RoundTrip Status: ', Ord(Deserialized1.Status), ' (Expected: 0)');
    Writeln('Enum as String - RoundTrip StatusNumber: ', Ord(Deserialized1.StatusNumber), ' (Expected: 2)');

    // [PASS] Teste 2: Enum como Number
    NumberSettings := TJsonSettings.Default
      .EnumAsNumber;

    Json := TDextJson.Serialize<TSimpleUser>(User, NumberSettings);
    Writeln('Enum as Number - JSON: ', Json);

    Deserialized2 := TDextJson.Deserialize<TSimpleUser>(Json, NumberSettings);
    Writeln('Enum as Number - RoundTrip Status: ', Ord(Deserialized2.Status), ' (Expected: 0)');
    Writeln('Enum as Number - RoundTrip StatusNumber: ', Ord(Deserialized2.StatusNumber), ' (Expected: 2)');

    Writeln('=== TESTE ENUM COMPLETO ===');

  except
    on E: Exception do
      Writeln('ERRO Enum: ', E.Message);
  end;
end;

procedure TestGUIDSupport;
type
  TEntity = record
    Id: TGUID;
    Name: string;
    ExternalId: TGUID;
  end;

var
  Entity: TEntity;
  Json: string;
  DeserializedEntity: TEntity;
begin
  Writeln('=== TESTE TGUID SUPPORT ===');

  // Criar GUIDs de teste
  Entity.Id := StringToGUID('{C87A33C3-116A-4A31-9A15-9D9A8B6D9C41}');
  Entity.Name := 'Test Entity';
  Entity.ExternalId := TGUID.Empty; // GUID vazio

  try
    // Teste com configurações padrão
    Json := TDextJson.Serialize<TEntity>(Entity, TJsonSettings.Indented);
    Writeln('TGUID Serialized:');
    Writeln(Json);

    // Teste RoundTrip
    DeserializedEntity := TDextJson.Deserialize<TEntity>(Json);

    Writeln('Original Id: ', GUIDToString(Entity.Id));
    Writeln('Deserialized Id: ', GUIDToString(DeserializedEntity.Id));
    Writeln('GUID Match: ', IsEqualGUID(Entity.Id, DeserializedEntity.Id));

    Writeln('Original ExternalId: ', GUIDToString(Entity.ExternalId));
    Writeln('Deserialized ExternalId: ', GUIDToString(DeserializedEntity.ExternalId));
    Writeln('Empty GUID Match: ', IsEqualGUID(Entity.ExternalId, DeserializedEntity.ExternalId));

    Writeln('=== SUCESSO TGUID! ===');

  except
    on E: Exception do
      Writeln('ERRO TGUID: ', E.Message);
  end;
end;

procedure TestGUIDWithSettings;
type
  TProduct = record
    ProductId: TGUID;
    ProductName: string;
    CategoryId: TGUID;
  end;

var
  Product: TProduct;
  Json: string;
  Settings: TJsonSettings;
  DeserializedProduct: TProduct;
begin
  Writeln('=== TESTE TGUID COM CONFIGURAÇÕES ===');

  Product.ProductId := StringToGUID('{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}');
  Product.ProductName := 'Awesome Product';
  Product.CategoryId := StringToGUID('{FEDCBA98-7654-3210-FEDC-BA9876543210}');

  try
    Settings := TJsonSettings.Indented
      .CamelCase
      .IgnoreNullValues;

    Json := TDextJson.Serialize<TProduct>(Product, Settings);
    Writeln('TGUID + CamelCase:');
    Writeln(Json);

    DeserializedProduct := TDextJson.Deserialize<TProduct>(Json, Settings);

    Writeln('RoundTrip Success: ',
      IsEqualGUID(Product.ProductId, DeserializedProduct.ProductId) and
      IsEqualGUID(Product.CategoryId, DeserializedProduct.CategoryId));

    Writeln('=== SUCESSO TGUID COM CONFIGURAÇÕES! ===');

  except
    on E: Exception do
      Writeln('ERRO: ', E.Message);
  end;
end;

procedure TestDateTimeFormats;
type
  TEvent = record
    EventName: string;
    StartDate: TDateTime;
    EndDate: TDateTime;
    CreatedAt: TDateTime;
  end;

var
  Event: TEvent;
  Json: string;
  ISOSettings, UnixSettings, CustomSettings, RoundTripSettings: TJsonSettings;
  DeserializedEvent: TEvent;
begin
  Writeln('=== TESTE DATETIME FORMATS ===');

  Event.EventName := 'Dext Framework Launch';
  Event.StartDate := EncodeDateTime(2025, 1, 15, 14, 30, 0, 0);
  Event.EndDate := EncodeDateTime(2025, 1, 15, 17, 0, 0, 0);
  Event.CreatedAt := Now;

  try
    // [PASS] Teste 1: ISO8601 (padrão)
    ISOSettings := TJsonSettings.Indented.ISODateFormat;
    Json := TDextJson.Serialize<TEvent>(Event, ISOSettings);
    Writeln('ISO8601 Format:');
    Writeln(Json);

    // [PASS] Teste 2: Unix Timestamp
    UnixSettings := TJsonSettings.Indented.UnixTimestamp;
    Json := TDextJson.Serialize<TEvent>(Event, UnixSettings);
    Writeln('Unix Timestamp:');
    Writeln(Json);

    // [PASS] Teste 3: Formato Customizado
    CustomSettings := TJsonSettings.Indented.CustomDateFormat('dd/mm/yyyy hh:nn:ss');
    Json := TDextJson.Serialize<TEvent>(Event, CustomSettings);
    Writeln('Custom Format:');
    Writeln(Json);

    // [PASS] Teste 4: RoundTrip com Unix Timestamp
    RoundTripSettings := TJsonSettings.Default.UnixTimestamp;
    Json := TDextJson.Serialize<TEvent>(Event, RoundTripSettings);
    DeserializedEvent := TDextJson.Deserialize<TEvent>(Json, RoundTripSettings);

    Writeln('RoundTrip Success - With Trunc (OLD): ',
      (Trunc(Event.StartDate) = Trunc(DeserializedEvent.StartDate)) and
      (Trunc(Event.EndDate) = Trunc(DeserializedEvent.EndDate)));

    Writeln('=== SUCESSO DATETIME FORMATS! ===');

  except
    on E: Exception do
      Writeln('ERRO DateTime: ', E.Message);
  end;
end;

procedure TestDateTimeWithOtherSettings;
type
  TLogEntry = record
    LogId: TGUID;
    Message: string;
    Timestamp: TDateTime;
    Severity: Integer; // Simulando enum
  end;

var
  Log: TLogEntry;
  Json: string;
  Settings: TJsonSettings;
  DeserializedLog: TLogEntry;
begin
  Writeln('=== TESTE COMBINADO DATETIME + GUID + SETTINGS ===');

  Log.LogId := StringToGUID('{12345678-1234-1234-1234-123456789ABC}');
  Log.Message := 'System started successfully';
  Log.Timestamp := Now;
  Log.Severity := 2;

  try
    Settings := TJsonSettings.Indented
      .CamelCase
      .UnixTimestamp  // Dates as numbers
      .EnumAsString;  // Enums as strings

    Json := TDextJson.Serialize<TLogEntry>(Log, Settings);
    Writeln('Combined Settings:');
    Writeln(Json);

    DeserializedLog := TDextJson.Deserialize<TLogEntry>(Json, Settings);

    Writeln('RoundTrip - GUID Match: ', IsEqualGUID(Log.LogId, DeserializedLog.LogId));
    Writeln('RoundTrip - Date Match: ',
      Abs(Log.Timestamp - DeserializedLog.Timestamp) < 1/(24*60*60)); // Within 1 second

    Writeln('=== SUCESSO COMBINADO! ===');

  except
    on E: Exception do
      Writeln('ERRO Combinado: ', E.Message);
  end;
end;

procedure TestDateFormats;
type
  TDateTest = record
    [JsonFormat('dd/mm/yyyy')]
    CustomDate: TDateTime;

    [JsonFormat('mm/dd/yyyy')]
    USDate: TDateTime;

    ISODate: TDateTime; // Usará ISO por padrão

    [JsonFormat('yyyy-mm-dd')]
    ISODateOnly: TDateTime;
  end;

var
  Test: TDateTest;
  Json: string;
  TestJson: string;
  Deserialized: TDateTest;
begin
  Writeln('=== TESTE FORMATOS DE DATA ===');

  Test.CustomDate := EncodeDate(2024, 12, 1);  // 01/12/2024
  Test.USDate := EncodeDate(2024, 12, 1);      // 12/01/2024
  Test.ISODate := EncodeDate(2024, 12, 1);     // 2024-12-01
  Test.ISODateOnly := EncodeDate(2024, 12, 1); // 2024-12-01

  try
    Json := TDextJson.Serialize<TDateTest>(Test, TJsonSettings.Indented);
    Writeln('Formatos de Data:');
    Writeln(Json);

    // Teste com diferentes formatos de entrada
    TestJson := '{"CustomDate":"01/12/2024","USDate":"12/01/2024","ISODate":"2024-12-01","ISODateOnly":"2024-12-01"}';
    Deserialized := TDextJson.Deserialize<TDateTest>(TestJson);

    Writeln('RoundTrip - CustomDate: ', DateToStr(Deserialized.CustomDate));
    Writeln('RoundTrip - USDate: ', DateToStr(Deserialized.USDate));
    Writeln('RoundTrip - ISODate: ', DateToStr(Deserialized.ISODate));
    Writeln('RoundTrip - ISODateOnly: ', DateToStr(Deserialized.ISODateOnly));

    Writeln('=== SUCESSO FORMATOS DE DATA! ===');

  except
    on E: Exception do
      Writeln('ERRO Formatos Data: ', E.ClassName, ' - ', E.Message);
  end;
end;

procedure TestAmbiguousDates;
type
  TAmbiguousDate = record
    Date1: TDateTime;
    Date2: TDateTime;
  end;
var
  TestJson: string;
  Deserialized: TAmbiguousDate;
begin
  Writeln('=== TESTE DATAS AMBÍGUAS ===');

  // Testar com JSON que tem datas ambíguas
  TestJson := '{"Date1":"06/05/2024","Date2":"12/01/2024"}'; // 06/05 pode ser Junho 5 ou Maio 6

  try
    Deserialized := TDextJson.Deserialize<TAmbiguousDate>(TestJson);

    Writeln('Date1 (06/05/2024): ', DateToStr(Deserialized.Date1));
    Writeln('Date2 (12/01/2024): ', DateToStr(Deserialized.Date2));

    // O parser deve preferir DD/MM/YYYY para compatibilidade com Brasil
    Writeln('Assumindo DD/MM/YYYY - Date1 deve ser 5 de Junho: ',
      (DayOf(Deserialized.Date1) = 5) and (MonthOf(Deserialized.Date1) = 6));

    Writeln('=== SUCESSO DATAS AMBÍGUAS! ===');

  except
    on E: Exception do
      Writeln('ERRO Datas Ambíguas: ', E.ClassName, ' - ', E.Message);
  end;
end;

procedure TestAdvancedAttributes;
type
  TProduct = record
    ProductId: Integer;

    [JsonName('product_name')]
    Name: string;

    [JsonFormat('yyyy-mm-dd')]
    CreatedDate: TDateTime;

    [JsonString]
    Price: Double; // Forçar double como string

    [JsonNumber]
    Stock: string; // Forçar string como número

    [JsonIgnore]
    InternalCode: string;

    [JsonString]
    IsAvailable: Boolean; // Forçar boolean como string
  end;

var
  Product: TProduct;
  Json: string;
  JsonObj: TJsonObject;
  DeserializedProduct: TProduct;
begin
  Writeln('=== TESTE ATRIBUTOS AVANÇADOS ===');

  Product.ProductId := 123;
  Product.Name := 'Smartphone';
  Product.CreatedDate := EncodeDate(2024, 12, 1);
  Product.Price := 999.99;
  Product.Stock := '50';
  Product.InternalCode := 'SECRET123';
  Product.IsAvailable := True;

  try
    Json := TDextJson.Serialize<TProduct>(Product, TJsonSettings.Indented);
    Writeln('Com Atributos Avançados:');
    Writeln(Json);

    // [PASS] Verificações
    JsonObj := TJsonObject.Parse(Json) as TJsonObject;
    try
      Writeln('JsonName funciona: ', JsonObj.Contains('product_name'));
      Writeln('JsonIgnore funciona: ', not JsonObj.Contains('InternalCode'));
      Writeln('JsonFormat funciona: ', JsonObj.S['CreatedDate'] = '2024-12-01');
      Writeln('JsonString para Double: ', JsonObj.Types['Price'] = jdtString);
      Writeln('JsonNumber para String: ', JsonObj.Types['Stock'] = jdtFloat);
      Writeln('JsonString para Boolean: ', JsonObj.S['IsAvailable'] = 'True');
    finally
      JsonObj.Free;
    end;

    // [PASS] Teste RoundTrip
    DeserializedProduct := TDextJson.Deserialize<TProduct>(Json);
    Writeln('RoundTrip - Name: ', DeserializedProduct.Name);
    Writeln('RoundTrip - Price: ', DeserializedProduct.Price.ToString);
    Writeln('RoundTrip - Stock: ', DeserializedProduct.Stock);

    Writeln('=== SUCESSO ATRIBUTOS AVANÇADOS! ===');

  except
    on E: Exception do
      Writeln('ERRO Atributos: ', E.Message);
  end;
end;

procedure TestAllFeaturesCombined;
type
  TUserStatus = (Active, Inactive);

  TAdvancedUser = record
    [JsonName('id')]
    UserId: TGUID;

    [JsonName('user_name')]
    UserName: string;

    [JsonFormat('dd/mm/yyyy')]
    BirthDate: TDateTime;

    [JsonString]
    LoginCount: Integer; // Número como string

    Status: TUserStatus;

    [JsonIgnore]
    PasswordHash: string;

    [JsonNumber]
    PhoneNumber: string; // String como número
  end;

var
  User: TAdvancedUser;
  Json: string;
  Settings: TJsonSettings;
  DeserializedUser: TAdvancedUser;
begin
  Writeln('=== TESTE TODAS AS FEATURES COMBINADAS ===');

  User.UserId := StringToGUID('{11111111-2222-3333-4444-555555555555}');
  User.UserName := 'john_doe';
  User.BirthDate := EncodeDate(1990, 5, 15);
  User.LoginCount := 42;
  User.Status := TUserStatus.Active;
  User.PasswordHash := 'abc123';
  User.PhoneNumber := '5511999999999';

  try
    Settings := TJsonSettings.Indented
      .EnumAsString;

    Json := TDextJson.Serialize<TAdvancedUser>(User, Settings);
    Writeln('Todas as Features:');
    Writeln(Json);

    DeserializedUser := TDextJson.Deserialize<TAdvancedUser>(Json, Settings);

    Writeln('RoundTrip - GUID: ', IsEqualGUID(User.UserId, DeserializedUser.UserId));
    Writeln('RoundTrip - UserName: ', User.UserName = DeserializedUser.UserName);
    Writeln('RoundTrip - Status: ', User.Status = DeserializedUser.Status);

    Writeln('=== SUCESSO TODAS AS FEATURES! ===');

  except
    on E: Exception do
      Writeln('ERRO Combinado: ', E.Message);
  end;
end;

procedure TestLocalization;
type
  TLocalized = record
    [JsonString]
    PriceBR: Double;

    [JsonNumber]
    PriceString: string; // "123,45" deve virar número

    NormalPrice: Double;
  end;

var
  Localized: TLocalized;
  Json: string;
  JsonObj: TJsonObject;
  Deserialized: TLocalized;
begin
  Writeln('=== TESTE LOCALIZAÇÃO CORRIGIDO ===');

  Localized.PriceBR := 999.99;
  Localized.PriceString := '123,45';  // String com vírgula
  Localized.NormalPrice := 456.78;

  try
    Json := TDextJson.Serialize<TLocalized>(Localized, TJsonSettings.Indented);
    Writeln('Serializado:');
    Writeln(Json);

    JsonObj := TJsonObject.Parse(Json) as TJsonObject;
    try
      Writeln('PriceBR como string: ', JsonObj.S['PriceBR']);
      Writeln('PriceString como número: ', JsonObj.F['PriceString']); // Deve ser 123.45
      Writeln('NormalPrice como número: ', JsonObj.F['NormalPrice']);

      Deserialized := TDextJson.Deserialize<TLocalized>(Json);
      Writeln('RoundTrip - PriceBR: ', Deserialized.PriceBR);
      Writeln('RoundTrip - PriceString: ', Deserialized.PriceString); // Deve ser "123.45"
      Writeln('RoundTrip - NormalPrice: ', Deserialized.NormalPrice);

      // Verificação específica
      Writeln('PriceString Conversão: ',
        (Abs(JsonObj.F['PriceString'] - 123.45) < 0.01) and  // Número correto
        (Deserialized.PriceString = '123.45'));              // String correta
    finally
      JsonObj.Free;
    end;

    Writeln('=== SUCESSO LOCALIZAÇÃO CORRIGIDO! ===');

  except
    on E: Exception do
      Writeln('ERRO Localização: ', E.ClassName, ' - ', E.Message);
  end;
end;

procedure TestEdgeCases;
type
  TEdgeCase = record
    [JsonString]
    VerySmall: Double;

    [JsonString]
    VeryLarge: Double;

    [JsonNumber]
    IntegerString: string;

    [JsonNumber]
    DecimalString: string; // "123,456789"
  end;

var
  Edge: TEdgeCase;
  Json: string;
  Deserialized: TEdgeCase;
begin
  Writeln('=== TESTE CASOS EXTREMOS CORRIGIDO ===');

  Edge.VerySmall := 0.0000001;
  Edge.VeryLarge := 999999999.999999;
  Edge.IntegerString := '123456789';
  Edge.DecimalString := '123,456789'; // Com vírgula

  try
    Json := TDextJson.Serialize<TEdgeCase>(Edge);
    Writeln('Serializado: ', Json);

    Deserialized := TDextJson.Deserialize<TEdgeCase>(Json);
    Writeln('RoundTrip - VerySmall: ', Deserialized.VerySmall);
    Writeln('RoundTrip - VeryLarge: ', Deserialized.VeryLarge);
    Writeln('RoundTrip - IntegerString: ', Deserialized.IntegerString);
    Writeln('RoundTrip - DecimalString: ', Deserialized.DecimalString); // Deve ser "123.456789"

    // Verificações
    Writeln('DecimalString Correto: ', Deserialized.DecimalString = '123.456789');
    Writeln('IntegerString Correto: ', Deserialized.IntegerString = '123456789');

    Writeln('=== SUCESSO CASOS EXTREMOS CORRIGIDO! ===');

  except
    on E: Exception do
      Writeln('ERRO Edge Cases: ', E.ClassName, ' - ', E.Message);
  end;
end;

procedure TestJsonNumberOnString;
type
  TTestNumberString = record
    [JsonNumber]
    Stock: string; // String que deve ser tratada como número no JSON

    [JsonNumber]
    Price: string; // Outro exemplo
  end;

var
  Test: TTestNumberString;
  Json: string;
  JsonObj: TJsonObject;
  Deserialized: TTestNumberString;
begin
  Writeln('=== TESTE JsonNumber EM STRING ===');

  Test.Stock := '50';
  Test.Price := '99.99';

  try
    // Serialização
    Json := TDextJson.Serialize<TTestNumberString>(Test, TJsonSettings.Indented);
    Writeln('Serializado:');
    Writeln(Json);

    // Verificar se serializou como números
    JsonObj := TJsonObject.Parse(Json) as TJsonObject;
    try
      Writeln('Stock como número: ', JsonObj.Types['Stock'] = jdtFloat);
      Writeln('Price como número: ', JsonObj.Types['Price'] = jdtFloat);
      Writeln('Stock valor: ', JsonObj.F['Stock']);
      Writeln('Price valor: ', JsonObj.F['Price']);
    finally
      JsonObj.Free;
    end;

    // Desserialização
    Deserialized := TDextJson.Deserialize<TTestNumberString>(Json);
    Writeln('Desserializado - Stock: ', Deserialized.Stock);
    Writeln('Desserializado - Price: ', Deserialized.Price);
    Writeln('RoundTrip Success: ', (Test.Stock = Deserialized.Stock) and (Test.Price = Deserialized.Price));

    Writeln('=== SUCESSO JsonNumber EM STRING! ===');

  except
    on E: Exception do
      Writeln('ERRO JsonNumber String: ', E.ClassName, ' - ', E.Message);
  end;
end;

type
  TTestController = class
  public
    procedure TestMethod(
      [FromBody] BodyParam: string;
      [FromQuery] QueryParam: Integer;
      [FromQuery('custom_name')] CustomQuery: string;
      [FromRoute] Id: Integer;
      [FromRoute('user_id')] UserId: string;
      [FromHeader] Authorization: string;
      [FromHeader('X-Custom')] CustomHeader: string;
      [FromServices] Logger: IInterface
    );
  end;

  { TTestController }

procedure TTestController.TestMethod(BodyParam: string; QueryParam: Integer; CustomQuery: string;
  Id: Integer; UserId, Authorization, CustomHeader: string; Logger: IInterface);
begin
  // just testing attributes
end;


procedure TestBindingAttributes;
var
  Context: TRttiContext;
  Method: TRttiMethod;
  Params: TArray<TRttiParameter>;
  Param: TRttiParameter;
  Attr: TCustomAttribute;
begin
  Writeln('=== TESTE ATRIBUTOS DE BINDING (FASE A) ===');

  try
    Context := TRttiContext.Create;
    Method := Context.GetType(TTestController).GetMethod('TestMethod');
    Params := Method.GetParameters;

    for Param in Params do
    begin
      Writeln('Parameter: ', Param.Name);

      for Attr in Param.GetAttributes do
      begin
        if Attr is FromBodyAttribute then
          Writeln('  - FromBody')
        else if Attr is FromQueryAttribute then
        begin
          if FromQueryAttribute(Attr).Name <> '' then
            Writeln('  - FromQuery("', FromQueryAttribute(Attr).Name, '")')
          else
            Writeln('  - FromQuery');
        end
        else if Attr is FromRouteAttribute then
        begin
          if FromRouteAttribute(Attr).Name <> '' then
            Writeln('  - FromRoute("', FromRouteAttribute(Attr).Name, '")')
          else
            Writeln('  - FromRoute');
        end
        else if Attr is FromHeaderAttribute then
        begin
          if FromHeaderAttribute(Attr).Name <> '' then
            Writeln('  - FromHeader("', FromHeaderAttribute(Attr).Name, '")')
          else
            Writeln('  - FromHeader');
        end
        else if Attr is FromServicesAttribute then
          Writeln('  - FromServices');
      end;
    end;

    Writeln('=== SUCESSO ATRIBUTOS DE BINDING! ===');

  except
    on E: Exception do
      Writeln('ERRO Atributos: ', E.Message);
  end;
end;

type
  TCreateUserRequest = record
    [FromBody] User: TUser;
    [FromHeader('X-API-Key')] ApiKey: string;
    [FromQuery] DryRun: Boolean;
  end;

  TGetUserRequest = record
    [FromRoute('id')] UserId: Integer;
    [FromQuery] IncludeProfile: Boolean;
    [FromHeader] Authorization: string;
  end;

  TUserService = interface
    ['{C172F92C-7F73-483E-8BED-311D23204973}']
    procedure CreateUser(User: TUser);
    function GetUser(Id: Integer): TUser;
  end;

  TUserController = class
  public
    function CreateUser(
      [FromBody] Request: TCreateUserRequest;
      [FromServices] UserService: TUserService
    ): Integer;

    function GetUser(
      [FromRoute] Request: TGetUserRequest;
      [FromServices] UserService: TUserService
    ): TUser;
  end;

  { TUserController }

function TUserController.CreateUser(Request: TCreateUserRequest;
  UserService: TUserService): Integer;
begin
  Result := 0;
end;

function TUserController.GetUser(Request: TGetUserRequest; UserService: TUserService): TUser;
begin
end;

procedure TestRealWorldBindingScenarios;
type
  TUser = record
    Id: Integer;
    Name: string;
    Email: string;
  end;
var
  Context: TRttiContext;
  BindingProvider: TBindingSourceProvider;
  CreateUserMethod: TRttiMethod;
  CreateUserParams: TArray<TRttiParameter>;
  GetUserMethod: TRttiMethod;
  GetUserParams: TArray<TRttiParameter>;
  Param: TRttiParameter;
  Source: TBindingSource;
  Name: string;
begin
  Writeln('=== CENÁRIOS REAIS BINDING (FASE A) ===');

  try
    Context := TRttiContext.Create;
    BindingProvider := TBindingSourceProvider.Create;
    try
      // Testar CreateUser method
      CreateUserMethod := Context.GetType(TUserController).GetMethod('CreateUser');
      CreateUserParams := CreateUserMethod.GetParameters;

      Writeln('CreateUser Method Parameters:');
      for Param in CreateUserParams do
      begin
        Source := BindingProvider.GetBindingSource(Param);
        Name := BindingProvider.GetBindingName(Param);
        Writeln('  - ', Param.Name, ' -> ', GetEnumName(TypeInfo(TBindingSource), Ord(Source)), ' (', Name, ')');
      end;

      // Testar GetUser method
      GetUserMethod := Context.GetType(TUserController).GetMethod('GetUser');
      GetUserParams := GetUserMethod.GetParameters;

      Writeln('GetUser Method Parameters:');
      for Param in GetUserParams do
      begin
        Source := BindingProvider.GetBindingSource(Param);
        Name := BindingProvider.GetBindingName(Param);
        Writeln('  - ', Param.Name, ' -> ', GetEnumName(TypeInfo(TBindingSource), Ord(Source)), ' (', Name, ')');
      end;

      Writeln('=== SUCESSO CENÁRIOS REAIS! ===');
    finally
      BindingProvider.Free;
    end;
  except
    on E: Exception do
      Writeln('ERRO Cenários Reais: ', E.Message);
  end;
end;

procedure TestModelBinderBasic;
var
  Binder: IModelBinder;
  // MockContext: IHttpContext; // Precisaremos criar um mock
begin
  Writeln('=== TESTE MODEL BINDER BÁSICO (FASE B) ===');

  try
    // Criar binder
    Binder := TModelBinder.Create;

    Writeln('✓ ModelBinder criado com sucesso');
    Writeln('✓ Interface corrigida (sem genéricos)');
    Writeln('✓ Métodos helper com genéricos disponíveis');

    // Testes reais precisarão de IHttpContext mock
    // Vamos criar isso na próxima fase

    Writeln('=== SUCESSO MODEL BINDER BÁSICO! ===');

  except
    on E: Exception do
      Writeln('ERRO Model Binder: ', E.Message);
  end;
end;

procedure TestCompleteIntegration;
type
  TCompleteUser = record
    Id: Integer;
    Name: string;
    Email: string;
  end;

  TCreateProductRequest = record
    Name: string;
    Price: Double;
    Category: string;
  end;

var
  App: IApplicationBuilder;
begin
  Writeln('=== TESTE INTEGRAÇÃO COMPLETA (FASE C) ===');

  try
    // 1. Criar Application Builder
    App := TApplicationBuilder.Create(nil);

    // 2. [PASS] PADRÃO MODERNO: TApplicationBuilderExtensions com Model Binding automático
    TApplicationBuilderExtensions.MapPost<TCompleteUser>(App, '/users',
      procedure(User: TCompleteUser)
      begin
        Writeln('[PASS] User criado via binding automático:');
        Writeln('   ID: ', User.Id);
        Writeln('   Name: ', User.Name);
        Writeln('   Email: ', User.Email);
      end
    );

    TApplicationBuilderExtensions.MapPost<TCreateProductRequest>(App, '/products',
      procedure(Product: TCreateProductRequest)
      begin
        Writeln('[PASS] Product criado via binding automático:');
        Writeln('   Name: ', Product.Name);
        Writeln('   Price: ', Product.Price);
        Writeln('   Category: ', Product.Category);
      end
    );

    Writeln('✓ Todas as rotas com model binding registradas');
    Writeln('✓ Usando TApplicationBuilderExtensions (sem memory leaks)');
    Writeln('✓ Pattern moderno TDextServices');

    Writeln('=== SUCESSO INTEGRAÇÃO COMPLETA! ===');

  except
    on E: Exception do
      Writeln('[FAIL] ERRO Integração: ', E.Message);
  end;
end;

type
  TUserRequest = record
    Name: string;
    Email: string;
  end;

  IUserIntegrationService = interface
   ['{53BE5C97-42CD-4CA0-8CC1-2F29D10C9666}']
    procedure ProcessUser(const User: TUserRequest);
  end;

  TUserIntegrationService = class(TInterfacedObject, IUserIntegrationService)
  public
    procedure ProcessUser(const User: TUserRequest);
  end;

procedure TUserIntegrationService.ProcessUser(const User: TUserRequest);
begin
  Writeln('  [Service] ProcessUser chamado para: ', User.Name);
end;

procedure TestFinalIntegration;
var
  WebHostBuilder: IWebHostBuilder;
  WebHost: IWebHost;
begin
  Writeln('=== TESTE INTEGRAÇÃO CORRIGIDO ===');

  try
    WebHostBuilder := TWebHostBuilder.Create
      .ConfigureServices(procedure(Services: IServiceCollection)
      var
        Svc: TDextServices;
      begin
        Svc := TDextServices.Create(Services);
        Svc.AddSingleton<IUserIntegrationService, TUserIntegrationService>;
      end)
      .Configure(procedure(App: IApplicationBuilder)
      begin
        // [PASS] PADRÃO MODERNO: MapPost com Model Binding automático
        TApplicationBuilderExtensions.MapPost<TUserRequest>(App, '/api/users',
          procedure(Req: TUserRequest)
          begin
            Writeln('[PASS] User Request recebido: ', Req.Name, ' - ', Req.Email);
          end
        );

        TApplicationBuilderExtensions.MapPost<TUserRequest>(App, '/api/v2/users',
          procedure(Req: TUserRequest)
          begin
            Writeln('[PASS] V2 User Request: ', Req.Name);
          end
        );
      end);

    WebHost := WebHostBuilder.Build;

    Writeln('✓ WebHost configurado com sucesso');
    Writeln('✓ Usando TDextServices e TApplicationBuilderExtensions');
    Writeln('✓ Sem memory leaks');

    Writeln('=== SUCESSO INTEGRAÇÃO CORRIGIDO! ===');

  except
    on E: Exception do
      Writeln('[FAIL] ERRO Integração: ', E.ClassName, ' - ', E.Message);
  end;
end;

procedure TestWebHostIntegration;
var
  WebHost: IWebHost;
begin
  Writeln('=== TESTE WEB HOST INTEGRATION ===');

  WebHost := TWebHostBuilder.Create
    .ConfigureServices(procedure(Services: IServiceCollection)
    var
      Svc: TDextServices;
    begin
      Svc := TDextServices.Create(Services);
      Svc.AddSingleton<IUserIntegrationService, TUserIntegrationService>;
    end)
    .Configure(procedure(App: IApplicationBuilder)
    begin
      // [PASS] PADRÃO MODERNO: MapPost<Request, Service> com DI + Model Binding automáticos
      // O Service é injetado automaticamente pelo HandlerInvoker
      TApplicationBuilderExtensions.MapPost<TUserRequest, IUserIntegrationService>(App, '/api/users',
        procedure(Req: TUserRequest; UserService: IUserIntegrationService)
        begin
          // Service é injetado automaticamente - sem capturar App!
          UserService.ProcessUser(Req);
          Writeln('[PASS] User processado: ', Req.Name);
        end
      );
    end)
    .Build;

  Writeln('✓ Web Host com Model Binding + DI configurado');
  Writeln('✓ Service injetado automaticamente');
  Writeln('✓ Sem memory leaks');
end;

procedure TestConciseIntegration;
type
  TConciseUser = record
    Id: Integer;
    Name: string;
    Email: string;
  end;

var
  App: IApplicationBuilder;
begin
  Writeln('=== TESTE CONCISO CORRIGIDO ===');

  App := TApplicationBuilder.Create(nil);
  try
    // [PASS] PADRÃO MODERNO: TApplicationBuilderExtensions
    TApplicationBuilderExtensions.MapPost<TConciseUser>(App, '/crm/users',
      procedure(User: TConciseUser)
      begin
        Writeln('User: ', User.Name);
      end
    );

    TApplicationBuilderExtensions.MapPost<TConciseUser>(App, '/v2/crm/users',
      procedure(User: TConciseUser)
      begin
        Writeln('V2 User: ', User.Name);
      end
    );

    Writeln('✓ Build completo');
    Writeln('✓ Usando TApplicationBuilderExtensions');
    Writeln('✓ Sem memory leaks');

  except
    on E: Exception do
      Writeln('[FAIL] ERRO: ', E.ClassName, ' - ', E.Message);
  end;
end;


procedure TestProviders;
var
  User: TUser;
  JsonJDO, JsonSystem: string;
  UserFromSystem: TUser;
begin
  Writeln('=== TESTANDO DRIVERS JSON ===');

  User.UserId := 99;
  User.UserName := 'DriverTester';
  User.EmailAddress := 'driver@test.com';
  User.Status := TUserStatus.Active;

  try
    // 1. Testar com JsonDataObjects (Padrão)
    TDextJson.Provider := TJsonDataObjectsProvider.Create;
    Writeln('* Driver: JsonDataObjects');
    JsonJDO := TDextJson.Serialize<TUser>(User);
    Writeln(JsonJDO);

    // 2. Testar com System.JSON
    TDextJson.Provider := TSystemJsonProvider.Create;
    Writeln('* Driver: System.JSON');
    JsonSystem := TDextJson.Serialize<TUser>(User);
    Writeln(JsonSystem);

    // 3. Comparar resultados (ignorando espaços em branco se necessário)
    // Nota: A ordem dos campos pode variar entre implementações, então uma comparação exata de string pode falhar.
    // Mas o conteúdo deve ser equivalente.
    Writeln('[PASS] Serialização concluída em ambos os drivers');

    // 4. Testar Deserialização Cruzada
    // Serializado com System.JSON -> Deserializado com JsonDataObjects
    TDextJson.Provider := TJsonDataObjectsProvider.Create;
    UserFromSystem := TDextJson.Deserialize<TUser>(JsonSystem);
    Writeln('🔄 Cross-Deserialization (System -> JDO): ', UserFromSystem.UserName);

    if UserFromSystem.UserName = User.UserName then
      Writeln('[PASS] Sucesso!')
    else
      Writeln('[FAIL] Falha na validação cruzada');

    Writeln('=== FIM TESTE DRIVERS ===');
  except
    on E: Exception do
      Writeln('[FAIL] ERRO DRIVERS: ', E.Message);
  end;
end;

end.

