unit EventHub.Data.Seeder;

{***************************************************************************}
{                                                                           }
{           Web.EventHub - Database Seeder                                  }
{                                                                           }
{           Seeds the database with realistic sample data                   }
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
  EventHub.Data.Context,
  EventHub.Domain.Entities,
  EventHub.Domain.Enums;

{ TDbSeeder }

class procedure TDbSeeder.Seed(const Provider: IServiceProvider);
var
  Scope: IServiceScope;
  Db: TEventHubDbContext;
  V1, V2, V3: TVenue;
  E1, E2, E3, E4: TEvent;
  S1, S2, S3, S4: TSpeaker;
  A1, A2, A3, A4, A5: TAttendee;
begin
  Scope := Provider.CreateScope;
  try
    Db := Scope.ServiceProvider.GetService(TEventHubDbContext) as TEventHubDbContext;

    // Create schema if needed
    if Db.EnsureCreated then
      WriteLn('  Database schema created.');

    // Check if already seeded
    if Db.Venues.QueryAll.Any then
    begin
      WriteLn('  Database already seeded.');
      Exit;
    end;

    WriteLn('  Seeding database...');

    // ========================================================================
    // Venues
    // ========================================================================
    V1 := TVenue.Create;
    V1.Name := 'Centro de Convenções Rebouças';
    V1.Address := 'Av. Rebouças, 600';
    V1.City := 'São Paulo';
    V1.Capacity := 2000;
    Db.Venues.Add(V1);

    V2 := TVenue.Create;
    V2.Name := 'Riocentro';
    V2.Address := 'Av. Salvador Allende, 6555';
    V2.City := 'Rio de Janeiro';
    V2.Capacity := 10000;
    Db.Venues.Add(V2);

    V3 := TVenue.Create;
    V3.Name := 'Cubo Itaú Coworking';
    V3.Address := 'Rua Hungria, 574';
    V3.City := 'São Paulo';
    V3.Capacity := 150;
    Db.Venues.Add(V3);

    Db.SaveChanges;
    WriteLn('    3 Venues created');

    // Refresh IDs
    V1 := Db.Venues.Where(TVenue.Props.Name = 'Centro de Convenções Rebouças').FirstOrDefault;
    V2 := Db.Venues.Where(TVenue.Props.Name = 'Riocentro').FirstOrDefault;
    V3 := Db.Venues.Where(TVenue.Props.Name = 'Cubo Itaú Coworking').FirstOrDefault;

    // ========================================================================
    // Events
    // ========================================================================
    E1 := TEvent.Create;
    E1.VenueId := V1.Id;
    E1.Title := 'Delphi Conference Brasil 2026';
    E1.Description := 'A maior conferência de Delphi da América Latina. Palestras, workshops e networking.';
    E1.StartDate := EncodeDate(2026, 11, 5) + EncodeTime(9, 0, 0, 0);
    E1.EndDate := EncodeDate(2026, 11, 7) + EncodeTime(18, 0, 0, 0);
    E1.MaxCapacity := 500;
    E1.Status := esPublished;
    Db.Events.Add(E1);

    E2 := TEvent.Create;
    E2.VenueId := V2.Id;
    E2.Title := 'DevOps Summit Rio 2026';
    E2.Description := 'Evento focado em DevOps, CI/CD, Kubernetes e Cloud Native.';
    E2.StartDate := EncodeDate(2026, 8, 20) + EncodeTime(8, 0, 0, 0);
    E2.EndDate := EncodeDate(2026, 8, 21) + EncodeTime(18, 0, 0, 0);
    E2.MaxCapacity := 3000;
    E2.Status := esPublished;
    Db.Events.Add(E2);

    E3 := TEvent.Create;
    E3.VenueId := V3.Id;
    E3.Title := 'Meetup: APIs Modernas com Dext Framework';
    E3.Description := 'Hands-on meetup sobre como construir APIs REST modernas com o Dext Framework.';
    E3.StartDate := EncodeDate(2026, 4, 15) + EncodeTime(19, 0, 0, 0);
    E3.EndDate := EncodeDate(2026, 4, 15) + EncodeTime(22, 0, 0, 0);
    E3.MaxCapacity := 3;  // Small capacity to test WaitList feature!
    E3.Status := esPublished;
    Db.Events.Add(E3);

    E4 := TEvent.Create;
    E4.VenueId := V1.Id;
    E4.Title := 'Workshop: Delphi para Iniciantes';
    E4.Description := 'Workshop introdutório de 2 dias sobre desenvolvimento com Delphi.';
    E4.StartDate := EncodeDate(2026, 12, 10) + EncodeTime(9, 0, 0, 0);
    E4.EndDate := EncodeDate(2026, 12, 11) + EncodeTime(17, 0, 0, 0);
    E4.MaxCapacity := 30;
    E4.Status := esDraft;  // Not published yet
    Db.Events.Add(E4);

    Db.SaveChanges;
    WriteLn('    4 Events created');

    // Refresh IDs
    E1 := Db.Events.Where(TEvent.Props.Title = 'Delphi Conference Brasil 2026').FirstOrDefault;
    E2 := Db.Events.Where(TEvent.Props.Title = 'DevOps Summit Rio 2026').FirstOrDefault;
    E3 := Db.Events.Where(TEvent.Props.Title = 'Meetup: APIs Modernas com Dext Framework').FirstOrDefault;

    // ========================================================================
    // Speakers
    // ========================================================================
    S1 := TSpeaker.Create;
    S1.EventId := E1.Id;
    S1.Name := 'Marco Cantù';
    S1.Bio := 'Delphi Product Manager at Embarcadero and renowned author.';
    S1.Email := 'marco@example.com';
    Db.Speakers.Add(S1);

    S2 := TSpeaker.Create;
    S2.EventId := E1.Id;
    S2.Name := 'Landerson Gomes';
    S2.Bio := 'Embarcadero Education Program Manager.';
    S2.Email := 'landerson@example.com';
    Db.Speakers.Add(S2);

    S3 := TSpeaker.Create;
    S3.EventId := E2.Id;
    S3.Name := 'Ana Costa';
    S3.Bio := 'DevOps Lead at CloudBR, Kubernetes specialist.';
    S3.Email := 'ana.costa@example.com';
    Db.Speakers.Add(S3);

    S4 := TSpeaker.Create;
    S4.EventId := E3.Id;
    S4.Name := 'Pedro Lima';
    S4.Bio := 'Full-stack Delphi developer and Dext Framework contributor.';
    S4.Email := 'pedro@example.com';
    Db.Speakers.Add(S4);

    Db.SaveChanges;
    WriteLn('    4 Speakers created');

    // ========================================================================
    // Attendees
    // ========================================================================
    A1 := TAttendee.Create;
    A1.Name := 'Carlos Oliveira';
    A1.Email := 'carlos@gmail.com';
    A1.Phone := '(11) 99999-1111';
    Db.Attendees.Add(A1);

    A2 := TAttendee.Create;
    A2.Name := 'Julia Martins';
    A2.Email := 'julia.martins@outlook.com';
    A2.Phone := '(21) 98888-2222';
    Db.Attendees.Add(A2);

    A3 := TAttendee.Create;
    A3.Name := 'Roberto Santos';
    A3.Email := 'roberto.santos@empresa.com.br';
    A3.Phone := '(11) 97777-3333';
    Db.Attendees.Add(A3);

    A4 := TAttendee.Create;
    A4.Name := 'Fernanda Silva';
    A4.Email := 'fernanda@dev.io';
    A4.Phone := '(31) 96666-4444';
    Db.Attendees.Add(A4);

    A5 := TAttendee.Create;
    A5.Name := 'Lucas Pereira';
    A5.Email := 'lucas.pereira@university.edu.br';
    A5.Phone := '(41) 95555-5555';
    Db.Attendees.Add(A5);

    Db.SaveChanges;
    WriteLn('    5 Attendees created');

    WriteLn('  Database seeding completed!');
    WriteLn('');
  finally
    Scope := nil;
  end;
end;

end.
