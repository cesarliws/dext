unit ModelBinding.Controller;

interface

uses
  System.SysUtils,
  Dext.Web,
  Dext.Web.Results,
  Dext.Validation;

type
  // -------------------------------------------------------------------------
  // CONTROLLER TEST TYPES
  // -------------------------------------------------------------------------
  
  // Controller Request with Header binding
  TControllerHeaderRequest = record
    [FromHeader('X-Tenant-Id')]
    TenantId: string;
  end;

  // Controller Request with Query binding
  TControllerQueryRequest = record
    [FromQuery('q')]
    Query: string;
    [FromQuery('page')]
    Page: Integer;
  end;
  
  // Controller Request with Body binding
  TControllerBodyRequest = record
    [Required]
    [StringLength(3, 50)]
    Name: string;
    Email: string;
  end;
  
  // Controller Request with Mixed binding (Header + Body)
  TControllerMixedRequest = record
    [FromHeader('X-Tenant-Id')]
    TenantId: string;
    // Body fields
    Name: string;
    Price: Currency;
  end;

  // -------------------------------------------------------------------------
  // CONTROLLER
  // -------------------------------------------------------------------------
  
  [ApiController('/api/controller')]
  TModelBindingController = class
  public
    // Test 1: Header binding in controller
    [HttpGet('/header')]
    [AllowAnonymous]
    procedure GetWithHeader(Ctx: IHttpContext; Request: TControllerHeaderRequest);
    
    // Test 2: Query binding in controller
    [HttpGet('/query')]
    [AllowAnonymous]
    procedure GetWithQuery(Ctx: IHttpContext; Request: TControllerQueryRequest);
    
    // Test 3: Body binding in controller
    [HttpPost('/body')]
    [AllowAnonymous]
    procedure PostWithBody(Ctx: IHttpContext; Request: TControllerBodyRequest);
    
    // Test 4: Mixed binding in controller (Header + Body)
    [HttpPost('/mixed')]
    [AllowAnonymous]
    procedure PostWithMixed(Ctx: IHttpContext; Request: TControllerMixedRequest);
    
    // Test 5: Route + Query parameters
    [HttpGet('/route/{id}')]
    [AllowAnonymous]
    procedure GetWithRoute(Ctx: IHttpContext; [FromRoute] Id: Integer; [FromQuery] Details: string);
    
    // Test 6: FromBody primitive parameter binding
    [HttpPost('/echo')]
    [AllowAnonymous]
    procedure Echo(Ctx: IHttpContext; [FromBody] const AMsg: string);
  end;

implementation

var
  JsonFormat: TFormatSettings;

{ TModelBindingController }

procedure TModelBindingController.GetWithHeader(Ctx: IHttpContext; Request: TControllerHeaderRequest);
begin
  WriteLn(Format('[ApiController] GetWithHeader -> TenantId=%s', [Request.TenantId]));
  Ctx.Response.Json(Format('{"source":"controller-header","tenantId":"%s"}', 
    [Request.TenantId]));
end;

procedure TModelBindingController.GetWithQuery(Ctx: IHttpContext; Request: TControllerQueryRequest);
begin
  WriteLn(Format('[ApiController] GetWithQuery -> Query=%s, Page=%d', [Request.Query, Request.Page]));
  Ctx.Response.Json(Format('{"source":"controller-query","query":"%s","page":%d}', 
    [Request.Query, Request.Page]));
end;

procedure TModelBindingController.PostWithBody(Ctx: IHttpContext; Request: TControllerBodyRequest);
begin
  WriteLn(Format('[ApiController] PostWithBody -> Name=%s, Email=%s', [Request.Name, Request.Email]));
  Ctx.Response.Status(201).Json(Format('{"source":"controller-body","name":"%s","email":"%s"}', 
    [Request.Name, Request.Email]));
end;

procedure TModelBindingController.PostWithMixed(Ctx: IHttpContext; Request: TControllerMixedRequest);
begin
  WriteLn(Format('[ApiController] PostWithMixed -> TenantId=%s, Name=%s, Price=%.2f', 
    [Request.TenantId, Request.Name, Double(Request.Price)], JsonFormat));
    
  if Request.TenantId = '' then
  begin
    Results.BadRequest('X-Tenant-Id header is required').Execute(Ctx);
    Exit;
  end;
  
  Ctx.Response.Status(201).Json(Format(
    '{"source":"controller-mixed","tenantId":"%s","name":"%s","price":%.2f}', 
    [Request.TenantId, Request.Name, Double(Request.Price)], JsonFormat));
end;

procedure TModelBindingController.GetWithRoute(Ctx: IHttpContext; Id: Integer; Details: string);
begin
  WriteLn(Format('[ApiController] GetWithRoute -> Id=%d, Details=%s', [Id, Details]));
  Ctx.Response.Json(Format('{"source":"controller-route","id":%d,"details":"%s"}', 
    [Id, Details]));
end;

procedure TModelBindingController.Echo(Ctx: IHttpContext; const AMsg: string);
begin
  WriteLn(Format('[ApiController] Echo -> AMsg=%s', [AMsg]));
  Ctx.Response.Json(Format('{"source":"controller-echo","message":"%s"}', [AMsg]));
end;

initialization
  // Force linker to include this controller
  TModelBindingController.ClassName;
  
  JsonFormat := TFormatSettings.Create('en-US');
  JsonFormat.DecimalSeparator := '.';

end.

