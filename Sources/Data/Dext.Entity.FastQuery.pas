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
{  Created: 2026-08-03                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.Entity.FastQuery;

interface

uses
  System.SysUtils,
  System.Classes,
  Data.DB,
  Dext.Entity.Drivers.Interfaces,
  Dext.Json.Utf8;

type
  /// <summary>
  /// Interface for high-performance raw SQL query execution with direct UTF-8 JSON streaming.
  /// </summary>
  IDextFastQuery = interface
    ['{7C1A8B9D-3E2F-4F5A-9C8B-1A2B3C4D5E6F}']
    /// <summary>
    /// Executes the query and streams UTF-8 encoded JSON results directly into the provided Stream.
    /// </summary>
    procedure ExecuteToUtf8Stream(AStream: TStream);
    /// <summary>
    /// Executes the query and emits UTF-8 encoded JSON memory chunks via a callback procedure.
    /// </summary>
    procedure ExecuteToUtf8Proc(AWriteProc: TProc<Pointer, Integer>);
    /// <summary>
    /// Executes the query and returns the UTF-8 JSON result as a byte array.
    /// </summary>
    function ExecuteToUtf8Bytes: TBytes;
    /// <summary>
    /// Executes the query and returns the raw UTF-8 JSON string.
    /// </summary>
    function ExecuteToUtf8String: RawByteString;
  end;

  /// <summary>
  /// Executes raw SQL queries and serializes dataset rows to UTF-8 JSON using TUtf8JsonWriter.
  /// </summary>
  TDextFastQuery = class(TInterfacedObject, IDextFastQuery)
  private
    FConnection: IDbConnection;
    FSql: string;
  public
    /// <summary>
    /// Initializes a new instance of TDextFastQuery with active connection and SQL statement.
    /// </summary>
    constructor Create(AConnection: IDbConnection; const ASql: string);
    /// <summary>
    /// Executes the query and writes JSON records directly to a Stream.
    /// </summary>
    procedure ExecuteToUtf8Stream(AStream: TStream);
    /// <summary>
    /// Executes the query and streams JSON records via UTF-8 write callback.
    /// </summary>
    procedure ExecuteToUtf8Proc(AWriteProc: TProc<Pointer, Integer>);
    /// <summary>
    /// Executes the query and returns UTF-8 byte payload.
    /// </summary>
    function ExecuteToUtf8Bytes: TBytes;
    /// <summary>
    /// Executes the query and returns RawByteString UTF-8 payload.
    /// </summary>
    function ExecuteToUtf8String: RawByteString;
  end;

implementation

constructor TDextFastQuery.Create(AConnection: IDbConnection; const ASql: string);
begin
  inherited Create;
  FConnection := AConnection;
  FSql := ASql;
end;

procedure TDextFastQuery.ExecuteToUtf8Stream(AStream: TStream);
var
  Cmd: IDbCommand;
  Reader: IDbReader;
  Writer: TUtf8JsonWriter;
  i, ColCount: Integer;
  ColNames: array of string;
  ColTypes: array of TFieldType;
begin
  if (FConnection = nil) or (not FConnection.IsConnected) then
    raise Exception.Create('Database connection is not active');

  Cmd := FConnection.CreateCommand(FSql);
  Reader := Cmd.ExecuteQuery;
  try
    ColCount := Reader.GetColumnCount;
    SetLength(ColNames, ColCount);
    SetLength(ColTypes, ColCount);
    for i := 0 to ColCount - 1 do
    begin
      ColNames[i] := Reader.GetColumnName(i);
      ColTypes[i] := Reader.GetColumnType(i);
    end;

    Writer := TUtf8JsonWriter.Create(AStream);
    Writer.WriteStartArray;
    while Reader.Next do
    begin
      Writer.WriteStartObject;
      for i := 0 to ColCount - 1 do
      begin
        Writer.WritePropertyName(ColNames[i]);
        if Reader.IsNull(i) then
        begin
          Writer.WriteNull;
          Continue;
        end;

        case ColTypes[i] of
          ftSmallint, ftInteger, ftWord, ftAutoInc, ftLargeint:
            Writer.WriteNumber(Reader.GetInt64(i));
          ftFloat, ftCurrency, ftBCD, ftFMTBcd:
            Writer.WriteNumber(Reader.GetDouble(i));
          ftBoolean:
            Writer.WriteBoolean(Reader.GetBoolean(i));
        else
          Writer.WriteString(Reader.GetString(i));
        end;
      end;
      Writer.WriteEndObject;
    end;
    Writer.WriteEndArray;
  finally
    Reader.Close;
  end;
end;

type
  TUtf8ProcCallback = TProc<Pointer, Integer>;
  PUtf8ProcCallback = ^TUtf8ProcCallback;

procedure FastQuerySinkWrite(AContext, AData: Pointer; ALength: Integer);
begin
  if (ALength > 0) and (AContext <> nil) then
    PUtf8ProcCallback(AContext)^(AData, ALength);
end;

procedure TDextFastQuery.ExecuteToUtf8Proc(AWriteProc: TProc<Pointer, Integer>);
var
  Cmd: IDbCommand;
  Reader: IDbReader;
  Writer: TUtf8JsonWriter;
  i, ColCount: Integer;
  ColNames: array of string;
  ColTypes: array of TFieldType;
begin
  if (FConnection = nil) or (not FConnection.IsConnected) then
    raise Exception.Create('Database connection is not active');

  Cmd := FConnection.CreateCommand(FSql);
  Reader := Cmd.ExecuteQuery;
  try
    ColCount := Reader.GetColumnCount;
    SetLength(ColNames, ColCount);
    SetLength(ColTypes, ColCount);
    for i := 0 to ColCount - 1 do
    begin
      ColNames[i] := Reader.GetColumnName(i);
      ColTypes[i] := Reader.GetColumnType(i);
    end;

    Writer := TUtf8JsonWriter.Create(@AWriteProc, FastQuerySinkWrite);
    Writer.WriteStartArray;
    while Reader.Next do
    begin
      Writer.WriteStartObject;
      for i := 0 to ColCount - 1 do
      begin
        Writer.WritePropertyName(ColNames[i]);
        if Reader.IsNull(i) then
        begin
          Writer.WriteNull;
          Continue;
        end;

        case ColTypes[i] of
          ftSmallint, ftInteger, ftWord, ftAutoInc, ftLargeint:
            Writer.WriteNumber(Reader.GetInt64(i));
          ftFloat, ftCurrency, ftBCD, ftFMTBcd:
            Writer.WriteNumber(Reader.GetDouble(i));
          ftBoolean:
            Writer.WriteBoolean(Reader.GetBoolean(i));
        else
          Writer.WriteString(Reader.GetString(i));
        end;
      end;
      Writer.WriteEndObject;
    end;
    Writer.WriteEndArray;
  finally
    Reader.Close;
  end;
end;

function TDextFastQuery.ExecuteToUtf8Bytes: TBytes;
var
  Stream: TMemoryStream;
begin
  Stream := TMemoryStream.Create;
  try
    ExecuteToUtf8Stream(Stream);
    SetLength(Result, Stream.Size);
    if Stream.Size > 0 then
    begin
      Stream.Position := 0;
      Stream.ReadBuffer(Result[0], Stream.Size);
    end;
  finally
    Stream.Free;
  end;
end;

function TDextFastQuery.ExecuteToUtf8String: RawByteString;
var
  Bytes: TBytes;
begin
  Bytes := ExecuteToUtf8Bytes;
  if Length(Bytes) > 0 then
  begin
    SetLength(Result, Length(Bytes));
    Move(Bytes[0], Result[1], Length(Bytes));
  end
  else
    Result := '';
end;

end.
