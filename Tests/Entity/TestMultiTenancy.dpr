program TestMultiTenancy;

{$APPTYPE CONSOLE}

uses
  FireDAC.Comp.Client,
  FireDAC.DApt,
  FireDAC.Stan.Async,
  FireDAC.Stan.Def,
  System.Classes,
  System.SysUtils,
  Dext.Collections,
  Dext.Entity.Attributes,
  Dext.Entity.Context,
  Dext.Entity.Core,
  Dext.Entity.Dialects,
  Dext.Entity.Drivers.FireDAC,
  Dext.Entity.Drivers.FireDAC.Links,
  Dext.Entity.Drivers.Interfaces,
  Dext.Entity.Setup,
  Dext.Entity.Tenancy,
  Dext.MultiTenancy,
  Dext.Specifications.SQL.Generator,
  Dext.Utils;

type
  [Table('Products')]
  TProduct = class(TTenantEntity)
  private
    FId: Integer;
    FName: string;
  public
    [PK, AutoInc, Column('Id')]
    property Id: Integer read FId write FId;
    [Column('Name')]
    property Name: string read FName write FName;
    // TenantId is inherited from TTenantEntity
  end;

  TMyContext = class(TDbContext)
  public
    function Products: IDbSet<TProduct>;
  end;

{ TProduct }
// Inherited from TTenantEntity

function TMyContext.Products: IDbSet<TProduct>;
begin
  Result := Entities<TProduct>;
end;

procedure RunTest;
var
  Provider: ITenantProvider;
  Context: TMyContext;
  TenantA, TenantB: ITenant;
  P: TProduct;
  ProductList: Dext.Collections.IList<TProduct>;
  Connection: TFDConnection;
  DBConn: IDbConnection;
  PGDialect, SSDialect: ISQLDialect;
  SQL: string;
  Generator: TSqlGenerator<TProduct>;
begin
  WriteLn('Initializing Test... (Build Log 19)');

  // Let's manually create connection to ensure Memory DB persists for the test duration
  Connection := TFDConnection.Create(nil);
  Connection.DriverName := 'SQLite';
  Connection.Params.Add('Database=:memory:');
  Connection.LoginPrompt := False;
  Connection.Open; 
  
  // Wrap in Dext Connection
  DBConn := TFireDACConnection.Create(Connection, True); 
  
  Provider := TTenantProvider.Create;
  WriteLn('Provider created: ', NativeInt(Pointer(Provider)));

  // Test Provider Isolation
  TenantA := TTenant.Create('TENANT-A', 'Tenant A', '');
  WriteLn('TenantA created: ', NativeInt(Pointer(TenantA)));
  
  WriteLn('Setting Tenant A (Isolation Test)...');
  Provider.Tenant := TenantA;
  WriteLn('Tenant A Set (Isolation Test).');
  
  Context := TMyContext.Create(DBConn, TSQLiteDialect.Create, nil, Provider);
  try
    // Register Entity (Touch DbSet)
    Context.Products; 
    
    Context.EnsureCreated;
    WriteLn('EnsureCreated done.');
    
    // Define Tenants
    // TenantA (Created above)
    // TenantB := TTenant.Create('TENANT-B', 'Tenant B', '');
    
    // 1. Add with Tenant A
    WriteLn('Setting Tenant A on Provider...');
    Provider.Tenant := TenantA;
    WriteLn('Tenant A Set.');
    
    P := TProduct.Create;
    P.Name := 'Product A';
    Context.Products.Add(P);
    
    WriteLn('Saving Changes...');
    Context.SaveChanges;
    WriteLn('Changes Saved.');
    
    WriteLn('Checking Product A TenantId...');
    
    if P.TenantId <> 'TENANT-A' then
       raise Exception.Create('Error: TenantId not set to TENANT-A');
    WriteLn('Product A TenantId Verified: ', P.TenantId);
       
    // 2. Add with Tenant B
    WriteLn('--- Case 2: Add with Tenant B ---');
    TenantB := TTenant.Create('TENANT-B', 'Tenant B', '');
    Provider.Tenant := TenantB;
    
    P := TProduct.Create;
    P.Name := 'Product B';
    Context.Products.Add(P);
    Context.SaveChanges;
    
    WriteLn('Product B saved. TenantId: ', P.TenantId);
    if P.TenantId <> 'TENANT-B' then
       raise Exception.Create('Error: TenantId not set to TENANT-B');
    
    // 3. Query Tenant B (Current)
    WriteLn('--- Case 3: Query Tenant B (Current) ---');
    ProductList := Context.Products.ToList;
    WriteLn('Listing done. Count: ', ProductList.Count);
    
    if ProductList.Count <> 1 then
      raise Exception.CreateFmt('Error: Expected 1 product, got %d', [ProductList.Count]);
      
    if ProductList[0].Name <> 'Product B' then
      raise Exception.Create('Error: Incorrect product returned for Tenant B!');
      
    WriteLn('Tenant B isolation verified.');
    
    // 4. Query Tenant A
    WriteLn('--- Case 4: Query Tenant A ---');
    Provider.Tenant := TenantA;
    Context.Clear; 
    
    ProductList := Context.Products.ToList;
    if ProductList.Count <> 1 then
      raise Exception.CreateFmt('Error: Expected 1 product for Tenant A, got %d', [ProductList.Count]);
      
    if ProductList[0].Name <> 'Product A' then
      raise Exception.Create('Error: Incorrect product returned for Tenant A!');
      
    WriteLn('Tenant A isolation verified.');
    
    // 5. Ignore Query Filters
    WriteLn('--- Case 5: Ignore Query Filters ---');
    ProductList := Context.Products.IgnoreQueryFilters.ToList;
    WriteLn('Global listing done. Count: ', ProductList.Count);
    
    if ProductList.Count <> 2 then
      raise Exception.CreateFmt('Error: Expected 2 products (A and B), got %d', [ProductList.Count]);
      
    WriteLn('IgnoreQueryFilters verified.');
    
    // 6. Schema Tenancy Test
    WriteLn('--- Case 6: Schema Tenancy (PostgreSQL Mock) ---');
    Provider.Tenant := TTenant.Create('TENANT-S', 'Tenant S', 'schema_s');
    
    // We can't easily test Postgres logic with SQLite connection,
    // but we can test if ApplyTenantConfig generates the right SQL.
    // Let's use a mock Dialect and check the ExecuteSchemaSetup.
    
    PGDialect := TPostgreSQLDialect.Create;
    SQL := PGDialect.GetSetSchemaSQL('schema_s');
    WriteLn('Postgres SetSchema SQL: ', SQL);
    if SQL <> 'SET search_path TO "schema_s", public;' then
      raise Exception.Create('Unexpected Postgres SetSchema SQL!');
      
    SQL := PGDialect.GetCreateSchemaSQL('schema_s');
    WriteLn('Postgres CreateSchema SQL: ', SQL);
    if SQL <> 'CREATE SCHEMA IF NOT EXISTS "schema_s";' then
      raise Exception.Create('Unexpected Postgres CreateSchema SQL!');
    
    WriteLn('--- Case 7: Schema Tenancy (SQL Server Mock) ---');
    SSDialect := TSQLServerDialect.Create;
    SQL := SSDialect.GetCreateSchemaSQL('schema_s');
    WriteLn('SQL Server CreateSchema SQL: ', SQL);
    if not SQL.Contains('CREATE SCHEMA [schema_s]') then
      raise Exception.Create('Unexpected SQL Server CreateSchema SQL!');
      
    // Test prefixing in Generator
    Generator := TSqlGenerator<TProduct>.Create(SSDialect);
    try
      Generator.Schema := 'schema_s';
      SQL := Generator.GenerateSelect;
      WriteLn('SQL Server Select with Schema: ', SQL);
      if not SQL.Contains('FROM [schema_s].[Products]') then
        raise Exception.Create('SQL Server table prefixing failed!');
    finally
      Generator.Free;
    end;

    WriteLn('--- Case 8: UPDATE/DELETE include TenantId (S68) ---');
    Provider.Tenant := TenantA;
    Generator := TSqlGenerator<TProduct>.Create(TSQLiteDialect.Create, nil, Provider);
    try
      P := TProduct.Create;
      try
        P.Id := 1;
        P.Name := 'Product A';
        P.TenantId := 'TENANT-A';
        SQL := Generator.GenerateUpdate(P);
        WriteLn('UPDATE SQL: ', SQL);
        if Pos('TenantId', SQL) = 0 then
          raise Exception.Create('UPDATE must include TenantId filter');
        SQL := Generator.GenerateDelete(P);
        WriteLn('DELETE SQL: ', SQL);
        if Pos('TenantId', SQL) = 0 then
          raise Exception.Create('DELETE must include TenantId filter');
      finally
        P.Free;
      end;
    finally
      Generator.Free;
    end;

    WriteLn('SUCCESS: All Multi-Tenancy tests (including Schema-based) passed.');
    
  finally
    Context.Free;
  end;
end;

begin
  try
    RunTest;
  except
    on E: Exception do
      WriteLn(E.ClassName, ': ', E.Message);
  end;
  ConsolePause;
end.
