unit ControllerExample.Controller;

{
1. Binding: Body, Query, Route, Header, Services.
2. Auto-Serialização: Retorno direto de objetos/records.
3. Validação: Atributos [Required], [StringLength].
4. Autorização: Atributo [SwaggerAuthorize].
5. Controllers Funcionais: Records com métodos estáticos.
}

interface

uses
  System.Classes,
  System.SysUtils,
  Dext, // ? All-in-one framework unit
  Dext.Web,
  Dext.Web.Results,
  ControllerExample.Services, // For TMySettings
  Dext.Collections,
  Dext.Options;

{.$RTTI EXPLICIT METHODS([vcPublic, vcPublished])}

type
  // DTOs
  TGreetingRequest = record
    [Required]
    [StringLength(3, 50)]
    Name: string;
    [Required]
    Title: string;
  end;

  TGreetingFilter = record
    [FromQuery('q')]
    Query: string;
    [FromQuery('limit')]
    Limit: Integer;
  end;

  TLoginRequest = record
    [Required]
    username: string;
    [Required]
    password: string;
  end;

  TPerson = record
    Id: Integer;
    Name: string;
    Email: string;
  end;

  // Class-based DTOs for object serialization testing
  TAddress = class
  private
    FCity: string;
    FStreet: string;
    FZipCode: string;
  public
    property Street: string read FStreet write FStreet;
    property City: string read FCity write FCity;
    property ZipCode: string read FZipCode write FZipCode;
  end;

  TPersonWithAddress = class
  private
    FAddress: TAddress;
    FEmail: string;
    FId: Integer;
    FName: string;
  public
    property Id: Integer read FId write FId;
    property Name: string read FName write FName;
    property Email: string read FEmail write FEmail;
    property Address: TAddress read FAddress write FAddress;
    destructor Destroy; override;
  end;

  // Service Interface
  IGreetingService = interface
    ['{A1B2C3D4-E5F6-7890-1234-567890ABCDEF}']
    function GetGreeting(const Name: string): string;
  end;

  // Service Implementation
  TGreetingService = class(TInterfacedObject, IGreetingService)
  public
    function GetGreeting(const Name: string): string;
  end;

  // Controller Class (Instance-based with DI)
  [DextController('/api/greet')]
  // TODO : Rename Attribute
  [SwaggerAuthorize('Bearer')] // ? Protect entire controller
  TGreetingController = class
  private
    FService: IGreetingService;
    FSettings: IOptions<TMySettings>;
  public
    // Constructor Injection!
    constructor Create(AService: IGreetingService; Settings: IOptions<TMySettings>);

    [DextGet('/{name}')]
    procedure GetGreeting(Ctx: IHttpContext; [FromRoute] const Name: string); virtual;

    [DextGet('/negotiated')]
    [AllowAnonymous]
    procedure GetNegotiated(Ctx: IHttpContext); virtual;

    [DextPost('')]
    procedure CreateGreeting(Ctx: IHttpContext; const Request: TGreetingRequest); virtual;

    [DextGet('/search')]
    procedure SearchGreeting(Ctx: IHttpContext; const Filter: TGreetingFilter); virtual;

    [DextGet('/config')]
    procedure GetConfig(Ctx: IHttpContext); virtual;
  end;

  [DextController('/api/auth')]
  TAuthController = class
  public
    [DextPost('/login')]
    [SwaggerAuthorize('Bearer')] // Just to show it appears in Swagger, but AllowAnonymous overrides
    [AllowAnonymous]
    procedure Login(Ctx: IHttpContext; const Request: TLoginRequest);
  end;

  // ============================================================================
  // ?? ACTION FILTERS DEMONSTRATION
  // ============================================================================

  /// <summary>
  ///   Custom filter that validates admin role
  /// </summary>
  RequireAdminRoleAttribute = class(ActionFilterAttribute)
  public
    procedure OnActionExecuting(AContext: IActionExecutingContext); override;
  end;

  /// <summary>
  ///   Custom filter that adds execution timing to response
  /// </summary>
  TimingFilterAttribute = class(ActionFilterAttribute)
  private
    FStartTime: TDateTime;
  public
    procedure OnActionExecuting(AContext: IActionExecutingContext); override;
    procedure OnActionExecuted(AContext: IActionExecutedContext); override;
  end;

  /// <summary>
  ///   Controller demonstrating all Action Filter features
  /// </summary>
  [DextController('/api/filters')]
  [LogAction] // ? Controller-level filter: logs ALL methods
  TFiltersController = class
  public
    // Example 1: Built-in LogAction filter
    [DextGet('/simple')]
    procedure SimpleEndpoint(Ctx: IHttpContext);

    // Example 2: Multiple filters
    [DextGet('/cached')]
    [ResponseCache(60, 'public')] // Cache for 60 seconds
    [AddHeader('X-Custom-Header', 'Dext-Rocks')]
    procedure CachedEndpoint(Ctx: IHttpContext);

    // Example 3: Header validation
    [DextPost('/secure')]
    [RequireHeader('X-API-Key', 'API Key is required')]
    procedure SecureEndpoint(Ctx: IHttpContext);

    // Example 4: Custom filters
    [DextGet('/admin')]
    [RequireAdminRole]
    [TimingFilter]
    procedure AdminEndpoint(Ctx: IHttpContext);

    // Example 5: Short-circuit demonstration
    [DextGet('/protected')]
    [RequireHeader('Authorization', 'Authorization header required')]
    procedure ProtectedEndpoint(Ctx: IHttpContext);
  end;

  [DextController('/api/list')]
  TListTestController = class
  public
    [DextGet('')]
    [AllowAnonymous]
    procedure GetPeople(Ctx: IHttpContext);
  end;

  [DextController('/api/object')]
  TObjectTestController = class
  public
    [DextGet('')]
    [AllowAnonymous]
    procedure GetPerson(Ctx: IHttpContext);

    [DextGet('/nested')]
    [AllowAnonymous]
    procedure GetPersonWithAddress(Ctx: IHttpContext);
    
    [DextGet('/list')]
    [AllowAnonymous]
    procedure GetPeopleList(Ctx: IHttpContext);
  end;

implementation

uses
  System.DateUtils;

{ TPersonClass }

destructor TPersonWithAddress.Destroy;
begin
  if Assigned(Address) then
    Address.Free;
  inherited;
end;

{ TGreetingService }

function TGreetingService.GetGreeting(const Name: string): string;
begin
  Result := Format('Hello, %s! Welcome to Dext Controllers.', [Name]);
end;

{ TGreetingController }

constructor TGreetingController.Create(AService: IGreetingService; Settings: IOptions<TMySettings>);
begin
  FService := AService;
  FSettings := Settings;
end;

procedure TGreetingController.GetGreeting(Ctx: IHttpContext; const Name: string);
begin
  var Message := FService.GetGreeting(Name);
  Ctx.Response.Json(
    Format('{"message": "%s" - %s}',
    [Message, FormatDateTime('hh:nn:ss.zzz', Now)]));
end;

procedure TGreetingController.GetNegotiated(Ctx: IHttpContext);
var
  Data: TGreetingRequest;
begin
  Data.Name := 'Dext User';
  Data.Title := 'Developer';

  // This will use the registered IOutputFormatterSelector to choose between JSON (default)
  // or others if Accept header dictates and more formatters are registered.
  Results.Ok<TGreetingRequest>(Data).Execute(Ctx);
end;

procedure TGreetingController.CreateGreeting(Ctx: IHttpContext; const Request: TGreetingRequest);
begin
  // Demonstrates Body Binding
  Ctx.Response.Status(201).Json(
    Format('{"status": "created", "name": "%s", "title": "%s"}',
    [Request.Name, Request.Title]));
end;

procedure TGreetingController.SearchGreeting(Ctx: IHttpContext; const Filter: TGreetingFilter);
begin
  // Demonstrates Query Binding
  Ctx.Response.Json(
    Format('{"results": [], "query": "%s", "limit": %d}',
    [Filter.Query, Filter.Limit]));
end;

procedure TGreetingController.GetConfig(Ctx: IHttpContext);
var
  Msg: string;
  Secret: string;
  Retries: Integer;
begin
  Msg := FSettings.Value.Message;
  Secret := FSettings.Value.SecretKey;
  Retries := FSettings.Value.MaxRetries;

  Ctx.Response.Json(Format('{"message": "%s", "secret": "%s", "retries": %d}', [Msg, Secret, Retries]));
end;

{ TAuthController }

procedure TAuthController.Login(Ctx: IHttpContext; const Request: TLoginRequest);
var
  TokenHandler: TJwtTokenHandler;
  Claims: TArray<TClaim>;
  Token: string;
begin
  if (Request.Username = 'admin') and (Request.Password = 'admin') then
  begin
    // Create token handler
    TokenHandler := TJwtTokenHandler.Create(
      'dext-secret-key-must-be-very-long-and-secure-at-least-32-chars',
      'dext-issuer',
      'dext-audience',
      60 // 60 minutes
    );
    try
      // Build claims array
      SetLength(Claims, 3);
      Claims[0] := TClaim.Create('sub', Request.Username);
      Claims[1] := TClaim.Create('name', Request.Username);
      Claims[2] := TClaim.Create('role', 'admin');

      // Generate token
      Token := TokenHandler.GenerateToken(Claims);

      Ctx.Response.Json(Format('{"token": "%s", "username": "%s"}', [Token, Request.Username]));
    finally
      TokenHandler.Free;
    end;
  end
  else
  begin
    Ctx.Response.Status(401).Json('{"error": "Invalid credentials"}');
  end;
end;

{ RequireAdminRoleAttribute }

procedure RequireAdminRoleAttribute.OnActionExecuting(AContext: IActionExecutingContext);
begin
  // Check if context is valid
  if (AContext = nil) or (AContext.HttpContext = nil) then
  begin
    WriteLn('? RequireAdminRole: Invalid context');
    Exit;
  end;

  // Check if user is authenticated and has admin role
  if (AContext.HttpContext.User = nil) or
     (AContext.HttpContext.User.Identity = nil) or
     (not AContext.HttpContext.User.Identity.IsAuthenticated) then
  begin
    WriteLn('? RequireAdminRole: User not authenticated');
    AContext.Result := Results.StatusCode(401, '{"error":"Authentication required"}');
    Exit;
  end;

  if not AContext.HttpContext.User.IsInRole('admin') then
  begin
    WriteLn('? RequireAdminRole: User is not admin');
    AContext.Result := Results.StatusCode(403, '{"error":"Admin role required"}');
  end;
end;


{ TimingFilterAttribute }

procedure TimingFilterAttribute.OnActionExecuting(AContext: IActionExecutingContext);
begin
  FStartTime := Now;
  WriteLn(Format('??  TimingFilter: Starting %s.%s',
    [AContext.ActionDescriptor.ControllerName, AContext.ActionDescriptor.ActionName]));
end;

procedure TimingFilterAttribute.OnActionExecuted(AContext: IActionExecutedContext);
var
  ElapsedMs: Int64;
begin
  ElapsedMs := MilliSecondsBetween(Now, FStartTime);
  WriteLn(Format('??  TimingFilter: Completed in %d ms', [ElapsedMs]));

  // Add timing header to response
  AContext.HttpContext.Response.AddHeader('X-Execution-Time-Ms', IntToStr(ElapsedMs));
end;

{ TFiltersController }

procedure TFiltersController.SimpleEndpoint(Ctx: IHttpContext);
begin
  // This endpoint is logged by the controller-level [LogAction] filter
  Ctx.Response.Json('{"message":"Simple endpoint - check console for log"}');
end;

procedure TFiltersController.CachedEndpoint(Ctx: IHttpContext);
begin
  // This response will be cached for 60 seconds
  // Check response headers for Cache-Control and X-Custom-Header
  Ctx.Response.Json(Format('{"message":"Cached response","timestamp":"%s"}',
    [DateTimeToStr(Now)]));
end;

procedure TFiltersController.SecureEndpoint(Ctx: IHttpContext);
var
  ApiKey: string;
begin
  // If we reach here, the X-API-Key header was present
  if not Ctx.Request.Headers.TryGetValue('X-API-Key', ApiKey) then
    ApiKey := 'not-found';
  Ctx.Response.Json(Format('{"message":"Secure endpoint accessed","apiKey":"%s"}', [ApiKey]));
end;

procedure TFiltersController.AdminEndpoint(Ctx: IHttpContext);
begin
  // If we reach here:
  // 1. User is authenticated (RequireAdminRole)
  // 2. User has admin role (RequireAdminRole)
  // 3. Execution time is being tracked (TimingFilter)
  Ctx.Response.Json('{"message":"Admin endpoint","user":"' +
    Ctx.User.Identity.Name + '"}');
end;

procedure TFiltersController.ProtectedEndpoint(Ctx: IHttpContext);
begin
  // If we reach here, Authorization header was present
  Ctx.Response.Json('{"message":"Protected endpoint accessed"}');
end;

{ TListTestController }

procedure TListTestController.GetPeople(Ctx: IHttpContext);
var
  People: IList<TPerson>;
  Person: TPerson;
begin
  People := TCollections.CreateList<TPerson>;

  Person.Id := 1;
  Person.Name := 'Cesar Romero';
  Person.Email := 'cesar@dext.com';
  People.Add(Person);

  Person.Id := 2;
  Person.Name := 'Dext User';
  Person.Email := 'user@dext.com';
  People.Add(Person);

  // Reported issue: This generates empty JSON if IList is not understood
  Results.Ok<IList<TPerson>>(People).Execute(Ctx);
end;

{ TObjectTestController }

procedure TObjectTestController.GetPerson(Ctx: IHttpContext);
var
  Person: TPersonWithAddress;
  Json: string;
begin
  Person := TPersonWithAddress.Create;
  try
    Person.Id := 1;
    Person.Name := 'John Doe';
    Person.Email := 'john@example.com';
    Person.Address := nil; // Test null object
    
    // Serialize to JSON before freeing
    Json := TDextJson.Serialize(Person);
  finally
    Person.Free;
  end;
  
  // Return JSON string
  Ctx.Response.Json(Json);
end;

procedure TObjectTestController.GetPersonWithAddress(Ctx: IHttpContext);
var
  Person: TPersonWithAddress;
begin
  Person := TPersonWithAddress.Create;
  try
    Person.Id := 2;
    Person.Name := 'Jane Smith';
    Person.Email := 'jane@example.com';
    
    Person.Address := TAddress.Create;
    Person.Address.Street := '123 Main St';
    Person.Address.City := 'New York';
    Person.Address.ZipCode := '10001';
    
    // Use Results.Ok for automatic serialization
    Results.Ok<TPersonWithAddress>(Person).Execute(Ctx);
  finally
    Person.Free;
  end;
end;

procedure TObjectTestController.GetPeopleList(Ctx: IHttpContext);
var
  People: IList<TPersonWithAddress>;
  Person: TPersonWithAddress;
begin
  People := TCollections.CreateList<TPersonWithAddress>(True);
  // Person 1 - with address
  Person := TPersonWithAddress.Create;
  Person.Id := 1;
  Person.Name := 'John Doe';
  Person.Email := 'john@example.com';
  Person.Address := TAddress.Create;
  Person.Address.Street := '456 Oak Ave';
  Person.Address.City := 'Los Angeles';
  Person.Address.ZipCode := '90001';
  People.Add(Person);
    
  // Person 2 - with address
  Person := TPersonWithAddress.Create;
  Person.Id := 2;
  Person.Name := 'Jane Smith';
  Person.Email := 'jane@example.com';
  Person.Address := TAddress.Create;
  Person.Address.Street := '123 Main St';
  Person.Address.City := 'New York';
  Person.Address.ZipCode := '10001';
  People.Add(Person);
    
  // Person 3 - without address (null)
  Person := TPersonWithAddress.Create;
  Person.Id := 3;
  Person.Name := 'Bob Johnson';
  Person.Email := 'bob@example.com';
  Person.Address := nil;
  People.Add(Person);
    
  // Use Results.Ok for automatic serialization
  Results.Ok<IList<TPersonWithAddress>>(People).Execute(Ctx);
end;


initialization
  // Force linker to include this class
  TGreetingController.ClassName;
  TAuthController.ClassName;
  TFiltersController.ClassName;
  TListTestController.ClassName;
  TObjectTestController.ClassName;

end.
