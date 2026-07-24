unit UniDACDemo.DbConfig;

/// <summary>
///   Database configuration for the UniDAC demo.
///   Uses SQLite in-memory via UniDAC provider.
///   To switch to PostgreSQL, MySQL, etc. change the provider
///   and connection string below.
/// </summary>

interface

uses
  Dext.Entity.Setup;

function CreateOptions: TDbContextOptions;

implementation

function CreateOptions: TDbContextOptions;
begin
  // SQLite in-memory via UniDAC — no external database needed
  Result := TDbContextOptions.Create;
  Result.UseSQLite(':memory:');
  // For PostgreSQL:
  //   Result.UsePostgreSQL('ProviderName=PostgreSQL;Host=localhost;Port=5432;Database=mydb;User ID=postgres;Password=postgres');
  // For MySQL:
  //   Result.UseMySQL('ProviderName=MySQL;Host=localhost;Port=3306;Database=mydb;User ID=root;Password=root');
end;

end.