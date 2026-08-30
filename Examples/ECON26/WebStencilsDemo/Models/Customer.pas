unit Customer;

interface

uses
  Dext.Entity,
  Dext.Core.SmartTypes;

type
  [Table('Customers')]
  TCustomer = class
  private
    FId: IntType;
    FName: StringType;
    FEmail: StringType;
  public
    [PK, AutoInc]
    property Id: IntType read FId write FId;
    property Name: StringType read FName write FName;
    property Email: StringType read FEmail write FEmail;
  end;

implementation

end.
