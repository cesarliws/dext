{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2025 Cesar Romero & Dext Contributors             }
{                                                                           }
{           Licensed under the Apache License, Version 2.0 (the "License"); }
{           you may not use this file except in compliance with the License.}
{           You may obtain a copy of the License at                         }
{                                                                           }
{               http://www.apache.org/licenses/LICENSE-2.0                  }
{                                                                           }
{           Unless required by applicable law or agreed to in writing,      }
{           software distributed under the License is distributed on an     }
{           "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,    }
{           either express or implied. See the License for the specific     }
{           language governing permissions and limitations under the        }
{           License.                                                        }
{                                                                           }
{***************************************************************************}
{                                                                           }
{  Author:  Cesar Romero                                                    }
{  Created: 2025-12-08                                                      }
{                                                                           }
{***************************************************************************}
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
    
    function TableExists(const ATableName: string): Boolean;
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
    
    // Array DML Support
    procedure SetArraySize(const ASize: Integer);
    procedure SetParamArray(const AName: string; const AValues: TArray<TValue>);
    procedure ExecuteBatch(const ATimes: Integer; const AOffset: Integer = 0);
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

