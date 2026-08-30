unit CustomerSearchTests;

interface

uses
  Dext.Testing,
  Dext.Testing.Attributes,
  AppDbContext,
  CustomerSearch;

type
  [Fixture]
  TCustomerSearchTests = class
  private
    FDb: TAppDbContext;
    FSearch: ICustomerSearch;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Encontra_por_pedaco_do_nome;

    [Test]
    procedure Termo_vazio_devolve_todos;
  end;

implementation

uses
  System.SysUtils,
  Dext.Collections,
  Dext.Entity.Query,
  Customer;

{ TCustomerSearchTests }

procedure TCustomerSearchTests.Setup;
var
  C: TCustomer;
begin
  FDb := TAppDbContext.Create;
  FDb.EnsureCreated;

  C := TCustomer.Create;
  C.Name := 'Ada Lovelace';
  C.Email := 'ada@first-dev.org';
  FDb.Customers.Add(C);

  C := TCustomer.Create;
  C.Name := 'Alan Turing';
  C.Email := 'alan@enigma.com';
  FDb.Customers.Add(C);

  FDb.SaveChanges;
  FSearch := TCustomerSearch.Create(FDb);
end;

procedure TCustomerSearchTests.TearDown;
begin
  FSearch := nil;
  FreeAndNil(FDb);
end;

procedure TCustomerSearchTests.Encontra_por_pedaco_do_nome;
var
  Lista: IList<TCustomer>;
begin
  Lista := FSearch.ByTerm('Love').ToList;
  Should.List<TCustomer>(Lista).HaveCount(1);
  Should(string(Lista[0].Name)).Contain('Lovelace');
end;

procedure TCustomerSearchTests.Termo_vazio_devolve_todos;
begin
  Should.List<TCustomer>(FSearch.ByTerm('').ToList).HaveCount(2);
end;

end.
