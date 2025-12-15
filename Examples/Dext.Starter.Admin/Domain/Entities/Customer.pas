unit Customer;

interface

uses
  Dext.Persistence; // Correct unit

type
  TCustomerStatus = (Active, Inactive, Blocked);

  [Table('Customers')]
  TCustomer = class
  private
    FId: Integer;
    FName: string;
    FEmail: string;
    FStatus: TCustomerStatus;
    FTotalSpent: Double;
  public
    [PK, AutoInc]
    property Id: Integer read FId write FId;
    
    [Column('name')]
    property Name: string read FName write FName;
    
    [Column('email')]
    property Email: string read FEmail write FEmail;
    
    [Column('status')]
    property Status: TCustomerStatus read FStatus write FStatus;
    
    [Column('total_spent')]
    property TotalSpent: Double read FTotalSpent write FTotalSpent;
  end;

implementation

end.
