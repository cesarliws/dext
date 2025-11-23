unit ControllerExample.Controller;

interface

uses
  System.Classes,
  System.SysUtils,
  Dext.Core.Routing,
  Dext.Http.Interfaces,
  Dext.Core.Controllers;

{$RTTI EXPLICIT METHODS([vcPublic, vcPublished])}

type
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
  {$METHODINFO ON}
  TGreetingController = class(TPersistent)
  private
    FService: IGreetingService;
  public
    // Constructor Injection!
    constructor Create(AService: IGreetingService);
  published
    [DextGet('/{name}')]
    procedure GetGreeting(Ctx: IHttpContext; const Name: string); virtual;
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
  Ctx.Response.Json(Format('{"message": "%s" - %s}', [Message, FormatDateTime('hh:nn:ss.zzz', Now)]));
end;

initialization
  // Force linker to include this class
  TGreetingController.ClassName;

end.
