unit HelpDesk.Data.Seeder;

{***************************************************************************}
{                                                                           }
{           Web.HelpDesk - Database Seeder                                  }
{                                                                           }
{           Initializes the helpdesk with system users and sample data      }
{                                                                           }
{***************************************************************************}

interface

uses
  System.SysUtils,
  Dext, Dext.DI.Interfaces; // Facade: IServiceProvider, IServiceScope

type
  TDbSeeder = class
  public
    class procedure Seed(const Provider: IServiceProvider); static;
  end;

implementation

uses
  System.DateUtils,
  Dext.Core.SmartTypes, // Smart Props for Where queries
  Dext.Entity,         // Facade: SaveChanges, EnsureCreated
  HelpDesk.Data.Context,
  HelpDesk.Domain.Entities,
  HelpDesk.Domain.Enums;

class procedure TDbSeeder.Seed(const Provider: IServiceProvider);
  var
    Scope: IServiceScope;
    Db: THelpDeskContext;
    Agent, Customer, Admin: TUser;
    Ticket1, Ticket2: TTicket;
    Comment: TComment;
  begin
    Scope := Provider.CreateScope;
    try
      Db := Scope.ServiceProvider.GetService(THelpDeskContext) as THelpDeskContext;

      // Create Schema
      if Db.EnsureCreated then
        WriteLn('Database created successfully.');

      // Check if seeded
      if Db.Users.QueryAll.Any then
      begin
        WriteLn('Database already seeded.');
        Exit;
      end;

      WriteLn('Seeding HelpDesk data...');

      // 1. Users
      Admin := TUser.Create;
    Admin.Name := 'System Administrator';
    Admin.Email := 'admin@helpdesk.com';
    Admin.PasswordHash := 'hash_1234';
    Admin.Role := urAdmin;
    Admin.IsActive := True;
    Admin.Metadata := '{"department": "IT", "level": "L3"}';
    Db.Users.Add(Admin);

    Agent := TUser.Create;
    Agent.Name := 'Support Agent';
    Agent.Email := 'agent@helpdesk.com';
    Agent.PasswordHash := 'hash_1234';
    Agent.Role := urAgent;
    Agent.IsActive := True;

    Customer := TUser.Create;
    Customer.Name := 'John Doe';
    Customer.Email := 'john@company.com';
    Customer.PasswordHash := 'hash_1234';
    Customer.Role := urCustomer;
    Customer.IsActive := True;

    Db.Users.Add(Agent);
    Db.Users.Add(Customer);
    Db.SaveChanges;

    // Reload to get auto-increment IDs
    Agent := Db.Users.Where(TUser.Props.Email = 'agent@helpdesk.com').First;
    Customer := Db.Users.Where(TUser.Props.Email = 'john@company.com').First;

    // 2. Tickets
    Ticket1 := TTicket.Create;
    Ticket1.Subject := 'Server Down - Production';
    Ticket1.Description := 'Unable to access main application server. Error 500.';
    Ticket1.Status := tsOpen;
    Ticket1.Priority := tpCritical;
    Ticket1.Channel := tcPhone;
    Ticket1.RequesterId := Customer.Id;
    Ticket1.AssigneeId := Agent.Id;
    Ticket1.Tags := '["incident", "critical", "server"]';
    Ticket1.CustomFields := '{"server": "SRV-01", "impact": "High"}';
    Ticket1.CreatedAt := Now;
    Ticket1.DueDate := IncHour(Now, 4);
    Db.Tickets.Add(Ticket1);

    Ticket2 := TTicket.Create;
    Ticket2.Subject := 'Typo in login page';
    Ticket2.Description := 'The word "Password" is spelled "Pasword".';
    Ticket2.Status := tsNew;
    Ticket2.Priority := tpLow;
    Ticket2.Channel := tcWeb;
    Ticket2.RequesterId := Customer.Id;
    Ticket2.Tags := '["ui", "bug"]';
    Ticket2.CreatedAt := IncDay(Now, -1);
    Ticket2.DueDate := IncDay(Now, 2);
    Db.Tickets.Add(Ticket2);
    Db.SaveChanges;

    // 3. Comments
    Ticket1 := Db.Tickets.Where(TTicket.Props.Subject = 'Server Down - Production').First;

    Comment := TComment.Create;
    Comment.TicketId := Ticket1.Id;
    Comment.AuthorId := Agent.Id;
    Comment.Text := 'Investigating logs now. Rebooting services...';
    Comment.IsInternal := True;
    Comment.CreatedAt := IncMinute(Now, 10);
    Db.Comments.Add(Comment);
    Db.SaveChanges;

    WriteLn('Seeding completed!');
  finally
    Scope := nil;
  end;
end;

end.
