unit UniDACDemo.Entities;

interface

uses
  Dext,
  Dext.Entity,
  Dext.Collections,
  Dext.Types.Lazy,
  Dext.Specifications.Base;

type
  [Table('customers')]
  TCustomer = class
  private
    FId: Integer;
    FName: string;
    FEmail: string;
    FBalance: Currency;
    FCreatedAt: TDateTime;
  public
    [PK, AutoInc]
    property Id: Integer read FId write FId;

    [Required, MaxLength(100)]
    property Name: string read FName write FName;

    [Required, MaxLength(255)]
    property Email: string read FEmail write FEmail;

    property Balance: Currency read FBalance write FBalance;

    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
  end;

  [Table('orders')]
  TOrder = class
  private
    FId: Integer;
    FCustomerId: Integer;
    FTotalAmount: Currency;
    FOrderDate: TDateTime;
    FStatus: string;
  public
    [PK, AutoInc]
    property Id: Integer read FId write FId;

    [Required, ForeignKey('customer_id'), BelongsTo]
    property CustomerId: Integer read FCustomerId write FCustomerId;

    [Required]
    property TotalAmount: Currency read FTotalAmount write FTotalAmount;

    property OrderDate: TDateTime read FOrderDate write FOrderDate;

    [MaxLength(50)]
    property Status: string read FStatus write FStatus;
  end;

implementation

end.