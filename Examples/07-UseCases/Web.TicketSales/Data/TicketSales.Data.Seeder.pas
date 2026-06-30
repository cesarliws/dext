unit TicketSales.Data.Seeder;

{***************************************************************************}
{                                                                           }
{           Web.TicketSales - Database Seeder                               }
{                                                                           }
{           Seeds the database with sample data for testing                 }
{                                                                           }
{***************************************************************************}

interface

uses
  Dext, Dext.DI.Interfaces;

type
  /// <summary>
  ///   Seeds the database with initial test data.
  ///   Pattern: Call from .dpr before App.Run
  /// </summary>
  TDbSeeder = class
  public
    class procedure Seed(const Provider: IServiceProvider); static;
  end;

implementation

uses
  System.SysUtils,
  System.DateUtils,
  Dext.Entity,
  TicketSales.Data.Context,
  TicketSales.Domain.Entities,
  TicketSales.Domain.Enums;

{ TDbSeeder }

class procedure TDbSeeder.Seed(const Provider: IServiceProvider);
var
  Scope: IServiceScope;
  Db: TTicketSalesDbContext;
  Event1, Event2, Event3: TEvent;
  TT1, TT2, TT3, TT4, TT5: TTicketType;
  Cust1, Cust2, Cust3: TCustomer;
begin
  Scope := Provider.CreateScope;
  try
    Db := Scope.ServiceProvider.GetService(TTicketSalesDbContext) as TTicketSalesDbContext;

    // Create schema if needed
    if Db.EnsureCreated then
      WriteLn('📦 Database schema created.');

    // Check if already seeded
    if Db.Events.QueryAll.Any then
    begin
      WriteLn('✅ Database already seeded.');
      Exit;
    end;

    WriteLn('🌱 Seeding database...');

    // ==========================================================================
    // Events
    // ==========================================================================
    Event1 := TEvent.Create;
    Event1.Name := 'Rock in Rio 2026';
    Event1.Description := 'The biggest rock festival in Latin America returns with amazing headliners!';
    Event1.Venue := 'Parque Olímpico, Rio de Janeiro';
    Event1.EventDate := EncodeDate(2026, 9, 15) + EncodeTime(18, 0, 0, 0);
    Event1.Capacity := 100000;
    Event1.SoldCount := 0;
    Event1.Status := esOnSale;
    Db.Events.Add(Event1);

    Event2 := TEvent.Create;
    Event2.Name := 'Hamilton - O Musical';
    Event2.Description := 'Award-winning Broadway musical about Alexander Hamilton.';
    Event2.Venue := 'Teatro Renault, São Paulo';
    Event2.EventDate := EncodeDate(2026, 4, 20) + EncodeTime(20, 0, 0, 0);
    Event2.Capacity := 1200;
    Event2.SoldCount := 0;
    Event2.Status := esOnSale;
    Db.Events.Add(Event2);

    Event3 := TEvent.Create;
    Event3.Name := 'Delphi Conference Brasil 2026';
    Event3.Description := 'Annual conference for Delphi developers featuring workshops and talks.';
    Event3.Venue := 'Centro de Convenções Rebouças, São Paulo';
    Event3.EventDate := EncodeDate(2026, 11, 5) + EncodeTime(9, 0, 0, 0);
    Event3.Capacity := 500;
    Event3.SoldCount := 0;
    Event3.Status := esScheduled;
    Db.Events.Add(Event3);

    Db.SaveChanges;
    WriteLn('  ✔ 3 Events created');

    // Refresh IDs
    Event1 := Db.Events.Where(TEvent.Props.Name = 'Rock in Rio 2026').FirstOrDefault;
    Event2 := Db.Events.Where(TEvent.Props.Name = 'Hamilton - O Musical').FirstOrDefault;
    Event3 := Db.Events.Where(TEvent.Props.Name = 'Delphi Conference Brasil 2026').FirstOrDefault;

    // ==========================================================================
    // Ticket Types
    // ==========================================================================
    TT1 := TTicketType.Create;
    TT1.EventId := Event1.Id;
    TT1.Name := 'Pista Premium';
    TT1.Description := 'Access to premium area with better view';
    TT1.Price := 890.00;
    TT1.Quantity := 10000;
    TT1.SoldCount := 0;
    TT1.IsHalfPrice := True;
    Db.TicketTypes.Add(TT1);

    TT2 := TTicketType.Create;
    TT2.EventId := Event1.Id;
    TT2.Name := 'Pista Comum';
    TT2.Description := 'General admission standing area';
    TT2.Price := 450.00;
    TT2.Quantity := 80000;
    TT2.SoldCount := 0;
    TT2.IsHalfPrice := True;
    Db.TicketTypes.Add(TT2);

    TT3 := TTicketType.Create;
    TT3.EventId := Event2.Id;
    TT3.Name := 'Plateia VIP';
    TT3.Description := 'Best seats in the house, front rows';
    TT3.Price := 650.00;
    TT3.Quantity := 200;
    TT3.SoldCount := 0;
    TT3.IsHalfPrice := True;
    Db.TicketTypes.Add(TT3);

    TT4 := TTicketType.Create;
    TT4.EventId := Event2.Id;
    TT4.Name := 'Mezanino';
    TT4.Description := 'Upper level with panoramic view';
    TT4.Price := 350.00;
    TT4.Quantity := 500;
    TT4.SoldCount := 0;
    TT4.IsHalfPrice := True;
    Db.TicketTypes.Add(TT4);

    TT5 := TTicketType.Create;
    TT5.EventId := Event3.Id;
    TT5.Name := 'Full Conference';
    TT5.Description := 'Access to all talks and workshops';
    TT5.Price := 1200.00;
    TT5.Quantity := 400;
    TT5.SoldCount := 0;
    TT5.IsHalfPrice := False;  // Conference tickets don't have half-price
    Db.TicketTypes.Add(TT5);

    Db.SaveChanges;
    WriteLn('  ✔ 5 Ticket Types created');

    // ==========================================================================
    // Customers
    // ==========================================================================
    Cust1 := TCustomer.Create;
    Cust1.Name := 'João Silva';
    Cust1.Email := 'joao.silva@email.com';
    Cust1.CPF := '123.456.789-00';
    Cust1.CustomerType := ctRegular;
    Db.Customers.Add(Cust1);

    Cust2 := TCustomer.Create;
    Cust2.Name := 'Maria Santos';
    Cust2.Email := 'maria.santos@university.edu.br';
    Cust2.CPF := '987.654.321-00';
    Cust2.CustomerType := ctStudent;
    Db.Customers.Add(Cust2);

    Cust3 := TCustomer.Create;
    Cust3.Name := 'Carlos Oliveira';
    Cust3.Email := 'carlos.oliveira@email.com';
    Cust3.CPF := '456.789.123-00';
    Cust3.CustomerType := ctSenior;
    Db.Customers.Add(Cust3);

    Db.SaveChanges;
    WriteLn('  ✔ 3 Customers created');

    WriteLn('✅ Database seeding completed!');
    WriteLn('');
  finally
    Scope := nil;
  end;
end;

end.
