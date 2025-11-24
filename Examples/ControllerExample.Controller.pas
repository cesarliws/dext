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
  Dext.Core.Routing,
  Dext.Http.Interfaces,
  Dext.Core.Controllers,
  Dext.Core.ModelBinding, // Added for attributes
  Dext.OpenAPI.Attributes, // Added for SwaggerAuthorize
  Dext.Validation, // Added for Validation attributes
  Dext.Auth.JWT, // Added for Token generation
  Dext.Auth.Attributes; // Added for AllowAnonymous

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
  [SwaggerAuthorize('Bearer')] // ✅ Protect entire controller
  TGreetingController = class
  private
    FService: IGreetingService;
  public
    // Constructor Injection!
    constructor Create(AService: IGreetingService);

    [DextGet('/{name}')]
    procedure GetGreeting(Ctx: IHttpContext; [FromRoute] const Name: string); virtual;

    [DextPost('/')]
    procedure CreateGreeting(Ctx: IHttpContext; const Request: TGreetingRequest); virtual;

    [DextGet('/search')]
    procedure SearchGreeting(Ctx: IHttpContext; const Filter: TGreetingFilter); virtual;
  end;

  [DextController('/api/auth')]
  TAuthController = class
  public
    [DextPost('/login')]
    [SwaggerAuthorize('Bearer')] // Just to show it appears in Swagger, but AllowAnonymous overrides
    [AllowAnonymous]
    procedure Login(Ctx: IHttpContext; const Request: TLoginRequest);
  end;

implementation

{ TGreetingService }

function TGreetingService.GetGreeting(const Name: string): string;
begin
  Result := Format('Hello, %s! Welcome to Dext Controllers.', [Name]);
end;

{ TGreetingController }

constructor TGreetingController.Create(AService: IGreetingService);
begin
  FService := AService;
end;

procedure TGreetingController.GetGreeting(Ctx: IHttpContext; const Name: string);
begin
  var Message := FService.GetGreeting(Name);
  Ctx.Response.Json(
    Format('{"message": "%s" - %s}',
    [Message, FormatDateTime('hh:nn:ss.zzz', Now)]));
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

initialization
  // Force linker to include this class
  TGreetingController.ClassName;
  TAuthController.ClassName;

end.
