unit Order;

interface

uses
  Dext.Persistence; // Correct unit

type
  [Table('Orders')]
  TOrder = class
  private
    FId: Integer;
    FCustomerId: Integer;
    FTotal: Currency;
    FOrderDate: TDateTime;
  public
    [PK, AutoInc]
    property Id: Integer read FId write FId;
    
    [Column('customer_id')]
    property CustomerId: Integer read FCustomerId write FCustomerId;
    
    [Column('total')]
    property Total: Currency read FTotal write FTotal;
    
    [Column('order_date')]
    property OrderDate: TDateTime read FOrderDate write FOrderDate;
  end;

implementation

end.
