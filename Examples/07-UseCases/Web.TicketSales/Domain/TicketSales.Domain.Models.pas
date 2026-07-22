unit TicketSales.Domain.Models;

{***************************************************************************}
{                                                                           }
{           Web.TicketSales - Domain Models (DTOs)                          }
{                                                                           }
{           Data Transfer Objects for API requests and responses            }
{                                                                           }
{***************************************************************************}

interface

uses
  System.SysUtils,
  Dext,
  Dext.Entity,
  Dext.Json,
  TicketSales.Domain.Enums;

type
  // ===========================================================================
  // 📝 Event DTOs
  // ===========================================================================

  TCreateEventRequest = record
    [Required, MaxLength(200), MinLength(3), JSONName('name')]
    Name: string;

    [JSONName('description')]
    Description: string;

    [Required, MaxLength(300), MinLength(3), JSONName('venue')]
    Venue: string;

    [Required, JSONName('eventDate')]
    EventDate: TDateTime;

    [Required, JSONName('capacity')]
    Capacity: Integer;
  end;

  TUpdateEventRequest = record
    [MaxLength(200), MinLength(3), JSONName('name')]
    Name: string;

    [JSONName('description')]
    Description: string;

    [MaxLength(300), MinLength(3), JSONName('venue')]
    Venue: string;

    [JSONName('eventDate')]
    EventDate: TDateTime;

    [JSONName('status')]
    Status: TEventStatus;
  end;

  TEventResponse = record
    [JSONName('id')]
    Id: Integer;

    [JSONName('name')]
    Name: string;

    [JSONName('description')]
    Description: string;

    [JSONName('venue')]
    Venue: string;

    [JSONName('eventDate')]
    EventDate: TDateTime;

    [JSONName('capacity')]
    Capacity: Integer;

    [JSONName('soldCount')]
    SoldCount: Integer;

    [JSONName('availableTickets')]
    AvailableTickets: Integer;

    [JSONName('status')]
    Status: string;
  end;

  // ===========================================================================
  // 🎫 TicketType DTOs
  // ===========================================================================

  TCreateTicketTypeRequest = record
    [Required, JSONName('eventId')]
    EventId: Integer;

    [Required, MaxLength(100), MinLength(2), JSONName('name')]
    Name: string;

    [JSONName('description')]
    Description: string;

    [Required, JSONName('price')]
    Price: Currency;

    [Required, JSONName('quantity')]
    Quantity: Integer;

    [JSONName('isHalfPrice')]
    IsHalfPrice: Boolean;
  end;

  TTicketTypeResponse = record
    [JSONName('id')]
    Id: Integer;

    [JSONName('eventId')]
    EventId: Integer;

    [JSONName('name')]
    Name: string;

    [JSONName('description')]
    Description: string;

    [JSONName('price')]
    Price: Currency;

    [JSONName('quantity')]
    Quantity: Integer;

    [JSONName('soldCount')]
    SoldCount: Integer;

    [JSONName('availableQuantity')]
    AvailableQuantity: Integer;

    [JSONName('isHalfPrice')]
    IsHalfPrice: Boolean;
  end;

  // ===========================================================================
  // 👤 Customer DTOs
  // ===========================================================================

  TCreateCustomerRequest = record
    [Required, MaxLength(200), MinLength(2), JSONName('name')]
    Name: string;

    [Required, JSONName('email')]
    Email: string;

    [Required, MaxLength(14), MinLength(11), JSONName('cpf')]
    CPF: string;

    [JSONName('customerType')]
    CustomerType: TCustomerType;
  end;

  TCustomerResponse = record
    [JSONName('id')]
    Id: Integer;

    [JSONName('name')]
    Name: string;

    [JSONName('email')]
    Email: string;

    [JSONName('cpf')]
    CPF: string;

    [JSONName('customerType')]
    CustomerType: string;

    [JSONName('isHalfPriceEligible')]
    IsHalfPriceEligible: Boolean;
  end;

  // ===========================================================================
  // 🛒 Order DTOs
  // ===========================================================================

  TOrderItemRequest = record
    [Required, JSONName('ticketTypeId')]
    TicketTypeId: Integer;

    [Required, JSONName('quantity')]
    Quantity: Integer;
  end;

  TCreateOrderRequest = record
    [Required, JSONName('customerId')]
    CustomerId: Integer;

    [Required, JSONName('items')]
    Items: TArray<TOrderItemRequest>;
  end;

  TOrderItemResponse = record
    [JSONName('id')]
    Id: Integer;

    [JSONName('ticketTypeName')]
    TicketTypeName: string;

    [JSONName('quantity')]
    Quantity: Integer;

    [JSONName('unitPrice')]
    UnitPrice: Currency;

    [JSONName('isHalfPrice')]
    IsHalfPrice: Boolean;

    [JSONName('total')]
    Total: Currency;
  end;

  TOrderResponse = record
    [JSONName('id')]
    Id: Integer;

    [JSONName('customerId')]
    CustomerId: Integer;

    [JSONName('customerName')]
    CustomerName: string;

    [JSONName('status')]
    Status: string;

    [JSONName('total')]
    Total: Currency;

    [JSONName('createdAt')]
    CreatedAt: TDateTime;

    [JSONName('items')]
    Items: TArray<TOrderItemResponse>;
  end;

  TPayOrderRequest = record
    [Required, JSONName('orderId')]
    OrderId: Integer;

    [JSONName('paymentMethod')]
    PaymentMethod: string;
  end;

  // ===========================================================================
  // 🎟️ Ticket DTOs
  // ===========================================================================

  TTicketResponse = record
    [JSONName('id')]
    Id: Integer;

    [JSONName('code')]
    Code: string;

    [JSONName('eventName')]
    EventName: string;

    [JSONName('ticketTypeName')]
    TicketTypeName: string;

    [JSONName('status')]
    Status: string;

    [JSONName('customerName')]
    CustomerName: string;

    [JSONName('eventDate')]
    EventDate: TDateTime;
  end;

  TValidateTicketRequest = record
    [Required, JSONName('code')]
    Code: string;
  end;

  TValidateTicketResponse = record
    [JSONName('valid')]
    Valid: Boolean;

    [JSONName('message')]
    Message: string;

    [JSONName('ticket')]
    Ticket: TTicketResponse;
  end;

  // ===========================================================================
  // Auth DTOs
  // ===========================================================================

  TLoginRequest = record
    [Required, JSONName('username')]
    Username: string;

    [Required, JSONName('password')]
    Password: string;
  end;

  TLoginResponse = record
    [JSONName('token')]
    Token: string;

    [JSONName('expiresIn')]
    ExpiresIn: Integer;

    [JSONName('username')]
    Username: string;
  end;

  // ===========================================================================
  // ⚠️ Error DTOs
  // ===========================================================================

  TErrorResponse = record
    [JSONName('error')]
    Error: string;

    [JSONName('code')]
    Code: string;

    [JSONName('details')]
    Details: string;
  end;

implementation

end.
