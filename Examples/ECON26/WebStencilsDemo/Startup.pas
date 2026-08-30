unit Startup;

interface

{$I Dext.inc}

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  Dext.Collections,
  Dext.Configuration.Interfaces,
  Dext.Core.SmartTypes,
  Dext.DI.Interfaces,
  Dext.Entity.Core,
  Dext.Entity.Query,
  Dext.Specifications.Types,
  Dext.Web.Interfaces,
  Dext.Web.Results,
  Dext.Web.View,
  {$IFDEF DEXT_ENABLE_WEB_STENCILS}
  Web.Stencils,
  {$ELSE}
  {$MESSAGE FATAL 'Ligue DEXT_ENABLE_WEB_STENCILS em Dext.inc e recompile o Dext.Web. Sem isso este demo cai no motor nativo e o @LayoutPage vira texto.'}
  {$ENDIF}
  Dext.Web.View.WebStencils,
  Dext.Web.StaticFiles,
  Dext,
  Dext.Entity,
  Dext.Web,
  Customer,
  AppDbContext,
  CustomerSearch;

type
  TStartup = class(TInterfacedObject, IStartup)
  public
    class procedure SeedData(const Services: IServiceProvider);
    procedure ConfigureServices(const Services: TDextServices; const Configuration: IConfiguration);
    procedure Configure(const App: IWebApplication);
  end;

implementation

{ TStartup }

procedure TStartup.ConfigureServices(const Services: TDextServices; const Configuration: IConfiguration);
begin
  Services
    .AddDbContext<TAppDbContext>(
      procedure(Opts: TDbContextOptions)
      begin
        Opts.UseSqlite('webstencils-customers.db');
      end)
    .AddScoped<ICustomerSearch, TCustomerSearch>
    .AddWebStencils;
//     .AddDextTemplating(ViewOptions.TemplateRoot(TPath.GetFullPath('wwwroot/views-native')));
end;

procedure TStartup.Configure(const App: IWebApplication);
begin
  JsonDefaultSettings(JsonSettings.CamelCase.CaseInsensitive.ISODateFormat);

  App.Builder
    .UseDeveloperExceptionPage
    .UseHttpLogging
    .UseViewEngine
    { Sem DefaultFile: o / e a view index, nao o index.html que sobrou no Output. }
    .UseStaticFiles(TStaticFileBuilder.Create.RootPath('wwwroot').DefaultFile(''))
    .MapGetResult<IResult>('/',
      function: IResult
      begin
        Result := Results.View('index');
      end)
    .MapGetResult<TAppDbContext, IResult>('/customers',
      function(Db: TAppDbContext): IResult
      begin
        Result := Results.View<TCustomer>('customers', Db.Customers.QueryAll);
      end)
    .MapGetResult<ICustomerSearch, TSearchDTO, IResult>('/customers/search',
      function(Search: ICustomerSearch; Query: TSearchDTO): IResult
      begin
        Result := Results.View<TCustomer>('customers_list', Search.ByTerm(Query.SearchTerm));
      end);
end;

class procedure TStartup.SeedData(const Services: IServiceProvider);
var
  DB: TAppDbContext;

  procedure AddCustomer(const Name, Email: string);
  var
    C: TCustomer;
  begin
    C := TCustomer.Create;
    C.Name := Name;
    C.Email := Email;
    DB.Customers.Add(C);
  end;

begin
  DB := Services.GetService(TAppDbContext) as TAppDbContext;
  if DB = nil then Exit;

  DB.EnsureCreated;

  if DB.Customers.QueryAll.Count = 0 then
  begin
    AddCustomer('Cesar Romero', 'cesar@dotpas.dev');
    AddCustomer('Jaques Nascimento', 'jaques@neoui.com');
    AddCustomer('Armando Neto', 'armandinho@dext.dev');
    AddCustomer('John Doe', 'john@example.com');
    AddCustomer('Jane Smith', 'jane.smith@test.com');
    AddCustomer('Bob Anderson', 'bob@anderson.io');
    AddCustomer('Alice Cooper', 'alice.c@music.com');
    AddCustomer('Charlie Brown', 'charlie@peanuts.com');
    AddCustomer('David Bowie', 'david@stardust.io');
    AddCustomer('Grace Hopper', 'grace@cobol.dev');
    AddCustomer('Ada Lovelace', 'ada@first-dev.org');
    AddCustomer('Alan Turing', 'alan@enigma.com');

    DB.SaveChanges;
  end;
end;

end.
