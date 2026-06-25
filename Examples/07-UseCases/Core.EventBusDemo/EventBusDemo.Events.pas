unit EventBusDemo.Events;

/// <summary>
///   Event record definitions for the EventBusDemo.
///   All events are plain records - stack-allocated, zero heap pressure.
/// </summary>

interface

type
  // --------------------------------------------------------------------------
  // Order processing events
  // --------------------------------------------------------------------------

  TOrderPlacedEvent = record
    OrderId: Integer;
    CustomerId: Integer;
    TotalAmount: Currency;
    ItemCount: Integer;
  end;

  TPaymentProcessedEvent = record
    OrderId: Integer;
    Amount: Currency;
    PaymentMethod: string; // 'CreditCard', 'DebitCard', 'Pix'
  end;

  // --------------------------------------------------------------------------
  // Inventory event
  // --------------------------------------------------------------------------

  TInventoryLowEvent = record
    ProductId: Integer;
    ProductName: string;
    CurrentStock: Integer;
    MinimumStock: Integer;
  end;

implementation

end.
