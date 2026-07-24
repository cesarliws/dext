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
{  Author:  Dext Contributors                                               }
{  Created: 2026-07-24                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.Entity.Drivers.UniDAC.Links;

/// <summary>
///   Links UniDAC providers by referencing their units, controlled by the
///   same {$DEFINE} flags as Dext.Entity.Drivers.FireDAC.Links.
///   Only include DEXT_USE_UNIDAC in your project when UniDAC is installed.
/// </summary>

interface

{$I Dext.inc}

uses
  // UniDAC Standard Providers — mirror of FireDAC.Links flags
  {$IFDEF DEXT_ENABLE_DB_SQLITE}   SQLiteUniProvider,     {$ENDIF}
  {$IFDEF DEXT_ENABLE_DB_POSTGRES} PostgreSQLUniProvider, {$ENDIF}
  {$IFDEF DEXT_ENABLE_DB_MYSQL}    MySQLUniProvider,      {$ENDIF}
  {$IFDEF DEXT_ENABLE_DB_MSSQL}    SQLServerUniProvider,  {$ENDIF}
  {$IFDEF DEXT_ENABLE_DB_ORACLE}   OracleUniProvider,     {$ENDIF}
  // UniDAC uses "InterBase" provider for both Firebird and InterBase
  {$IFDEF DEXT_ENABLE_DB_FIREBIRD} InterBaseUniProvider,  {$ENDIF}
  {$IFDEF DEXT_ENABLE_DB_IB}       InterBaseUniProvider,  {$ENDIF}
  {$IFDEF DEXT_ENABLE_DB_DB2}      DB2UniProvider,        {$ENDIF}
  {$IFDEF DEXT_ENABLE_DB_ODBC}     ODBCUniProvider,       {$ENDIF}
  System.SysUtils;

implementation

end.

