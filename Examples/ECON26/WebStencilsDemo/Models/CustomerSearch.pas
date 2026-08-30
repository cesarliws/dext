unit CustomerSearch;

interface

uses
  System.SysUtils,
  Dext.Entity,
  Dext.Entity.Query,
  Customer,
  AppDbContext;

type
  TSearchDTO = record
    SearchTerm: string;
  end;

  ICustomerSearch = interface
    ['{B2C3D4E5-F6A7-8901-BCDE-F12345678901}']
    function ByTerm(const Term: string): TFluentQuery<TCustomer>;
  end;

  TCustomerSearch = class(TInterfacedObject, ICustomerSearch)
  private
    FDb: TAppDbContext;
  public
    constructor Create(Db: TAppDbContext);
    function ByTerm(const Term: string): TFluentQuery<TCustomer>;
  end;

implementation

{ TCustomerSearch }

constructor TCustomerSearch.Create(Db: TAppDbContext);
begin
  inherited Create;
  FDb := Db;
end;

function TCustomerSearch.ByTerm(const Term: string): TFluentQuery<TCustomer>;
var
  C: TCustomer;
begin
  C := Prototype.Entity<TCustomer>;
  if Term.Trim.IsEmpty then
    Exit(FDb.Customers.QueryAll);
  Result := FDb.Customers.Where(
    C.Name.Contains(Term) or C.Email.Contains(Term));
end;

end.
