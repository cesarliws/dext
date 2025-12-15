unit Customer.Service;

interface

uses
  Dext.Collections,
  Customer,
  DbContext,
  System.SysUtils;

type
  ICustomerService = interface
    ['{A1B2C3D4-E5F6-47A8-9B0C-1D2E3F4A5B6C}']
    function GetAll: IList<TCustomer>;
    function GetById(const Id: Integer): TCustomer;
    procedure Add(const Customer: TCustomer);
    procedure Update(const Customer: TCustomer);
    procedure Delete(const Id: Integer);
  end;

  TCustomerService = class(TInterfacedObject, ICustomerService)
  private
    FDb: TAppDbContext;
  public
    constructor Create(Db: TAppDbContext);
    function GetAll: IList<TCustomer>;
    function GetById(const Id: Integer): TCustomer;
    procedure Add(const Customer: TCustomer);
    procedure Update(const Customer: TCustomer);
    procedure Delete(const Id: Integer);
  end;

implementation

{ TCustomerService }

constructor TCustomerService.Create(Db: TAppDbContext);
begin
  FDb := Db;
end;

function TCustomerService.GetAll: IList<TCustomer>;
begin
  Result := FDb.Entities<TCustomer>.List;
end;

function TCustomerService.GetById(const Id: Integer): TCustomer;
begin
  Result := FDb.Entities<TCustomer>.Find(Id);
end;

procedure TCustomerService.Add(const Customer: TCustomer);
begin
  if Customer = nil then Exit;
  FDb.Entities<TCustomer>.Add(Customer);
  FDb.SaveChanges;
end;

procedure TCustomerService.Update(const Customer: TCustomer);
begin
  // In a real tracked context, properties are updated on the managed entity.
  // If 'Customer' is already attached/tracked, we just save.
  // If it's Detached, we might need to Update.
  // Assuming the caller modified the tracked entity or passed a new one to update.
  FDb.SaveChanges;
end;

procedure TCustomerService.Delete(const Id: Integer);
var
  C: TCustomer;
begin
  C := GetById(Id);
  if C <> nil then
  begin
    FDb.Entities<TCustomer>.Remove(C);
    FDb.SaveChanges;
  end;
end;

end.
