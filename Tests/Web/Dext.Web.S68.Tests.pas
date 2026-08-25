{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2026 Cesar Romero & Dext Contributors             }
{                                                                           }
{***************************************************************************}
unit Dext.Web.S68.Tests;

interface

uses
  Dext.Testing;

type
  [TestFixture]
  TS68FrameworkGapTests = class
  public
    [Test]
    procedure Results_Accepted_Sets_202_And_Location;
    [Test]
    procedure Results_UnsupportedMediaType_Sets_415;
    [Test]
    procedure DataApi_MaxPageSize_Defaults_To_100;
    [Test]
    procedure HealthCheckOptions_Default_Live_And_Ready_Paths;
    [Test]
    procedure DomainException_Maps_To_Http_422;
    [Test]
    procedure Options_ValidateOnStart_Fails_Fast_At_Build;
    [Test]
    procedure ValidateModel_Filter_Sets_ValidationProblem_On_Invalid_Arg;
  end;

implementation

uses
  System.SysUtils,
  System.Rtti,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.Configuration.Core,
  Dext.Configuration.Interfaces,
  Dext.DI.Interfaces,
  Dext.Filters,
  Dext.Filters.BuiltIn,
  Dext.HealthChecks,
  Dext.Options,
  Dext.Options.Extensions,
  Dext.Validation,
  Dext.Web.DataApi,
  Dext.Web.Interfaces,
  Dext.Web.Middleware,
  Dext.Web.Mocks,
  Dext.Web.Results;

type
  TBadOptions = class
  private
    FName: string;
  public
    property Name: string read FName write FName;
  end;

  TValidateModelDto = class
  private
    FName: string;
  published
    [Required]
    property Name: string read FName write FName;
  end;

procedure TS68FrameworkGapTests.Results_Accepted_Sets_202_And_Location;
var
  Context: IHttpContext;
  ResultObj: IResult;
  Location: string;
begin
  Context := TMockFactory.CreateHttpContext('');
  ResultObj := Results.Accepted('/jobs/42');
  ResultObj.Execute(Context);
  Should(Context.Response.StatusCode).Be(202);
  if not Context.Response.Headers.TryGetValue('Location', Location) then
    Location := '';
  Should(Location).Be('/jobs/42');
end;

procedure TS68FrameworkGapTests.Results_UnsupportedMediaType_Sets_415;
var
  Context: IHttpContext;
begin
  Context := TMockFactory.CreateHttpContext('');
  Results.UnsupportedMediaType('Only PDF/PNG allowed').Execute(Context);
  Should(Context.Response.StatusCode).Be(415);
end;

procedure TS68FrameworkGapTests.DataApi_MaxPageSize_Defaults_To_100;
var
  Options: TDataApiOptions;
begin
  Options := TDataApiOptions.Create;
  try
    Should(Options.MaxPageSizeValue).Be(100);
    Options.MaxPageSize(50);
    Should(Options.MaxPageSizeValue).Be(50);
    Options.MaxPageSize(0);
    Should(Options.MaxPageSizeValue).Be(0);
  finally
    Options.Free;
  end;
end;

procedure TS68FrameworkGapTests.HealthCheckOptions_Default_Live_And_Ready_Paths;
var
  Options: THealthCheckOptions;
begin
  Options := THealthCheckOptions.Default;
  Should(Options.HealthPath).Be('/health');
  Should(Options.LivePath).Be('/health/live');
  Should(Options.ReadyPath).Be('/health/ready');
end;

procedure TS68FrameworkGapTests.DomainException_Maps_To_Http_422;
var
  Ex: EDomainException;
begin
  Ex := EDomainException.Create('Saldo insuficiente');
  try
    Should(Ex.StatusCode).Be(422);
    Should(Ex.Message).Contain('Saldo');
  finally
    Ex.Free;
  end;
end;

procedure TS68FrameworkGapTests.Options_ValidateOnStart_Fails_Fast_At_Build;
var
  Services: TDextServices;
  Provider: IServiceProvider;
  Config: IConfiguration;
  Raised: Boolean;
begin
  Config := TDextConfiguration.New
    .AddValues([TPair<string, string>.Create('Name', '')])
    .Build;

  Services := TDextServices.New;
  TOptionsServiceCollectionExtensions.Configure<TBadOptions>(
    Services.Collection,
    Config,
    function(Value: TBadOptions): string
    begin
      if Value.Name.Trim = '' then
        Result := 'Name is required'
      else
        Result := '';
    end,
    True);

  Raised := False;
  try
    Provider := Services.BuildServiceProvider;
    try
      TOptionsServiceCollectionExtensions.ValidateOptionsOnStart(Provider);
    finally
      Provider := nil;
    end;
  except
    on E: EConfigurationException do
      Raised := True;
  end;
  Should(Raised).BeTrue;
end;

procedure TS68FrameworkGapTests.ValidateModel_Filter_Sets_ValidationProblem_On_Invalid_Arg;
var
  Context: IHttpContext;
  Executing: IActionExecutingContext;
  Filter: ValidateModelAttribute;
  Dto: TValidateModelDto;
  Args: TArray<TValue>;
  Descriptor: TActionDescriptor;
begin
  Context := TMockFactory.CreateHttpContext('');
  Descriptor := Default(TActionDescriptor);
  Executing := TActionExecutingContext.Create(Context, Descriptor);
  Dto := TValidateModelDto.Create;
  try
    Dto.Name := '';
    SetLength(Args, 1);
    Args[0] := TValue.From<TValidateModelDto>(Dto);
    Executing.ActionArguments := Args;

    Filter := ValidateModelAttribute.Create;
    try
      Filter.OnActionExecuting(Executing);
      Should(Executing.Result <> nil).BeTrue;
      Executing.Result.Execute(Context);
      Should(Context.Response.StatusCode).Be(400);
      Should(Context.Response.ContentType).Contain('application/problem+json');
    finally
      Filter.Free;
    end;
  finally
    Dto.Free;
  end;
end;

end.
