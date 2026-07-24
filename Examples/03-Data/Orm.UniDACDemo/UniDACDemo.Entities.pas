unit UniDACDemo.Entities;

interface

uses
  Dext.Entity,              // Attributes facade
  Dext.Entity.Collections,  // IEntityCollection<T>
  Dext.Types.Lazy;          // ILazy<T>

type
  TCustomer = class
  private
    FId: Integer;
    FName: string;
    FEmail: string;
    FBalance: Currency;
    FCreatedAt: TDateTime;
    FOrders: ILazy<IEntityCollection<TOrder>>;
    function GetOrders: IEntityCollection<TOrder>;
  public
    [PK, AutoInc]
    property Id: Integer read FId write FId;

    [Required, MaxLength(100)]
    property Name: string read FName write FName;

    [Required, MaxLength(255)]
    property Email: string read FEmail write FEmail;

    property Balance: Currency read FBalance write FBalance;

    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;

    [InverseProperty('Customer'), HasMany]
    property Orders: IEntityCollection<TOrder> read GetOrders;
  end;

  TOrder = class
  private
    FId: Integer;
    FCustomerId: Integer;
    FTotalAmount: Currency;
    FOrderDate: TDateTime;
    FStatus: string;
    FCustomer: ILazy<TCustomer>;
    function GetCustomer: TCustomer;
    procedure SetCustomer(const Value: TCustomer);
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

    property Customer: TCustomer read GetCustomer write SetCustomer;
  end;

implementation

{ TCustomer }

function TCustomer.GetOrders: IEntityCollection<TOrder>;
begin
  if FOrders = nil then
    FOrders := TLazy<IEntityCollection<TOrder>>.Create;
  Result := FOrders.Value;
end;

{ TOrder }

function TOrder.GetCustomer: TCustomer;
begin
  if FCustomer <> nil then
    Result := FCustomer.Value
  else
    Result := nil;
end;

procedure TOrder.SetCustomer(const Value: TCustomer);
begin
  if FCustomer = nil then
    FCustomer := TLazy<TCustomer>.Create;
  FCustomer.Value := Value;
  if Value <> nil then
    FCustomerId := Value.Id;
end;

end.