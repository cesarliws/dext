unit Dext.Entity.Drivers.Interfaces;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Rtti,
  System.Generics.Collections,
  Data.DB;

type
  IDbReader = interface;
  IDbTransaction = interface;

  /// <summary>
  ///   Represents a database connection.
  /// </summary>
  IDbConnection = interface
    ['{20000000-0000-0000-0000-000000000002}']
    procedure Connect;
    procedure Disconnect;
    function IsConnected: Boolean;
    
    function BeginTransaction: IDbTransaction;
    
    // Factory methods
    function CreateCommand(const ASQL: string): IInterface; // Returns IDbCommand (circular ref avoidance)
    
    function GetLastInsertId: Variant;
  end;

  /// <summary>
  ///   Represents a database transaction.
  /// </summary>
  IDbTransaction = interface
    ['{20000000-0000-0000-0000-000000000003}']
    procedure Commit;
    procedure Rollback;
  end;

  /// <summary>
  ///   Represents a command to execute against the database.
  /// </summary>
  IDbCommand = interface
    ['{20000000-0000-0000-0000-000000000004}']
    procedure SetSQL(const ASQL: string);
    procedure AddParam(const AName: string; const AValue: TValue);
    procedure ClearParams;
    
    procedure Execute;
    function ExecuteQuery: IDbReader;
    function ExecuteNonQuery: Integer;
    function ExecuteScalar: TValue;
  end;

  /// <summary>
  ///   Represents a forward-only stream of rows from a data source.
  /// </summary>
  IDbReader = interface
    ['{20000000-0000-0000-0000-000000000005}']
    function Next: Boolean;
    
    function GetValue(const AColumnName: string): TValue; overload;
    function GetValue(AColumnIndex: Integer): TValue; overload;
    
    function GetColumnCount: Integer;
    function GetColumnName(AIndex: Integer): string;
    
    procedure Close;
  end;

implementation

end.
