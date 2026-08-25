unit Dext.Web.Validation.Tests;

interface

uses
  Dext.Testing,
  Dext.Validation,
  Dext.Web.HandlerInvoker,
  Dext.Web.ModelBinding,
  Dext.Web.Interfaces,
  Dext.Web.Mocks,
  Dext.DI.Interfaces,
  Dext.DI.Core,
  System.SysUtils,
  System.Rtti;

type
  TWebTestModel = class
  private
    FName: string;
    FEmail: string;
  published
    property Name: string read FName write FName;
    property Email: string read FEmail write FEmail;
  end;

  TWebTestModelValidator = class(TAbstractValidator<TWebTestModel>)
  public
    constructor Create; override;
  end;

  [TestFixture]
  TWebValidationTests = class
  public
    [Test]
    procedure Test_HandlerInvoker_AutoValidation_Fluent;
    [Test]
    procedure Test_HandlerInvoker_AutoValidation_ProblemJson;
    [Test]
    procedure Test_HandlerInvoker_BindingFailure_ProblemDetails;
  end;

implementation

uses
  Dext.Collections,
  Dext.Collections.Dict;

{ TWebTestModelValidator }

constructor TWebTestModelValidator.Create;
begin
  inherited Create;
  RuleFor('Name').Required.Length(3, 50);
  RuleFor('Email').EmailAddress;
end;

{ TWebValidationTests }

procedure TWebValidationTests.Test_HandlerInvoker_AutoValidation_Fluent;
var
  Services: TDextServices;
  Provider: IServiceProvider;
  Context: IHttpContext;
  Invoker: THandlerInvoker;
  Binder: IModelBinder;
begin
  Services := TDextServices.New;
  Services.AddTransient<IValidator<TWebTestModel>, TWebTestModelValidator>;
  Provider := Services.BuildServiceProvider;
  try
    Context := TMockFactory.CreateHttpContextWithServices('Name=Ab&Email=invalid-email', Provider);
    Binder := TModelBinder.Create;
    Invoker := THandlerInvoker.Create(Context, Binder);
    try
      Invoker.Invoke<TWebTestModel>(
        procedure(Arg: TWebTestModel)
        begin
          // This should NOT be executed because validation fails
        end
      );
      
      Should(Context.Response.StatusCode).Be(400);
    finally
      Invoker.Free;
    end;
  finally
    Provider := nil;
  end;
end;

procedure TWebValidationTests.Test_HandlerInvoker_AutoValidation_ProblemJson;
var
  Services: TDextServices;
  Provider: IServiceProvider;
  Context: IHttpContext;
  Invoker: THandlerInvoker;
  Binder: IModelBinder;
begin
  Services := TDextServices.New;
  Services.AddTransient<IValidator<TWebTestModel>, TWebTestModelValidator>;
  Provider := Services.BuildServiceProvider;
  try
    Context := TMockFactory.CreateHttpContextWithServices('Name=Ab&Email=invalid-email', Provider);
    Binder := TModelBinder.Create;
    Invoker := THandlerInvoker.Create(Context, Binder);
    try
      Invoker.Invoke<TWebTestModel>(
        procedure(Arg: TWebTestModel)
        begin
        end
      );

      Should(Context.Response.StatusCode).Be(400);
      Should(Context.Response.ContentType).Contain('application/problem+json');
    finally
      Invoker.Free;
    end;
  finally
    Provider := nil;
  end;
end;

procedure TWebValidationTests.Test_HandlerInvoker_BindingFailure_ProblemDetails;
var
  Context: IHttpContext;
  Invoker: THandlerInvoker;
  Binder: IModelBinder;
  RouteParams: IDictionary<string, string>;
begin
  RouteParams := TCollections.CreateDictionary<string, string>;
  RouteParams.Add('id', 'abc');
  Context := TMockFactory.CreateHttpContextWithRoute('', RouteParams);
  Binder := TModelBinder.Create;
  Invoker := THandlerInvoker.Create(Context, Binder);
  try
    Invoker.Invoke<Integer>(
      procedure(Arg: Integer)
      begin
        raise Exception.Create('Handler should not run on binding failure');
      end
    );

    Should(Context.Response.StatusCode).Be(400);
    Should(Context.Response.ContentType).Contain('application/problem+json');
  finally
    Invoker.Free;
  end;
end;

end.
