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
unit Dext.Entity.Drivers.UniDAC;

interface

{$I Dext.inc}

uses
  System.SysUtils,
  System.Classes,
  Data.DB,
  Uni,           // UniDAC TUniConnection, TUniQuery
  UniProvider,
  Dext.Entity.Drivers.Interfaces;

type
  TDextUniDACConnection = class;
  TDextUniDACCommand = class;
  TDextUniDACReader = class;
  TDextUniDACTransaction = class;

  /// <summary>
  ///   Implementation of IDbConnection for UniDAC (TUniConnection).
  /// </summary>
  TDextUniDACConnection = class(TInterfacedObject, IDbConnection)
  private
    FUniConnection: TUniConnection;
    FOwnsConnection: Boolean;
    FInTransaction: Boolean;
  public
    constructor Create(AUniConnection: TUniConnection; AOwnsConnection: Boolean = True);
    destructor Destroy; override;

    procedure Connect;
    procedure Disconnect;
    function IsConnected: Boolean;
    function BeginTransaction: IDbTransaction;
    function CreateCommand(const ASQL: string = ''): IDbCommand;
    function NativeConnection: TObject;
  end;

  /// <summary>
  ///   Implementation of IDbCommand for UniDAC (TUniQuery).
  /// </summary>
  TDextUniDACCommand = class(TInterfacedObject, IDbCommand)
  private
    FUniQuery: TUniQuery;
    FUniConnection: TUniConnection;
  public
    constructor Create(AUniConnection: TUniConnection; const ASQL: string = '');
    destructor Destroy; override;

    procedure SetCommandText(const ASQL: string);
    function GetCommandText: string;
    procedure AddParam(const AName: string; const AValue: Variant; ADataType: TFieldType = ftUnknown);
    procedure ClearParams;
    function ExecuteNonQuery: Integer;
    function ExecuteReader: IDbReader;
    function ExecuteScalar: Variant;
    function NativeCommand: TObject;

    procedure SetArraySize(ASize: Integer);
    procedure SetParamArray(const AName: string; const AValues: array of Variant; ADataType: TFieldType = ftUnknown);
    function ExecuteBatch: Integer;
    function GetParamValue(const AName: string): Variant;
  end;

  /// <summary>
  ///   Implementation of IDbReader for UniDAC (TUniQuery Dataset).
  /// </summary>
  TDextUniDACReader = class(TInterfacedObject, IDbReader)
  private
    FUniQuery: TUniQuery;
    FOwnsQuery: Boolean;
  public
    constructor Create(AUniQuery: TUniQuery; AOwnsQuery: Boolean = True);
    destructor Destroy; override;

    function Next: Boolean;
    function GetValue(const AFieldName: string): Variant; overload;
    function GetValue(AFieldIndex: Integer): Variant; overload;
    function IsNull(const AFieldName: string): Boolean; overload;
    function IsNull(AFieldIndex: Integer): Boolean; overload;
    function GetFieldCount: Integer;
    function GetFieldName(AFieldIndex: Integer): string;
    function GetFieldType(AFieldIndex: Integer): TFieldType;
    function NativeReader: TObject;
  end;

  /// <summary>
  ///   Implementation of IDbTransaction for UniDAC.
  /// </summary>
  TDextUniDACTransaction = class(TInterfacedObject, IDbTransaction)
  private
    FUniConnection: TUniConnection;
    FActive: Boolean;
  public
    constructor Create(AUniConnection: TUniConnection);
    destructor Destroy; override;

    procedure Commit;
    procedure Rollback;
    function IsActive: Boolean;
  end;

implementation

uses
  Dext.Entity.Drivers.UniDAC.Manager;

{ TDextUniDACConnection }

constructor TDextUniDACConnection.Create(AUniConnection: TUniConnection; AOwnsConnection: Boolean);
begin
  inherited Create;
  FUniConnection := AUniConnection;
  FOwnsConnection := AOwnsConnection;
  FInTransaction := False;
end;

destructor TDextUniDACConnection.Destroy;
begin
  if FOwnsConnection then
    FreeAndNil(FUniConnection);
  inherited;
end;

procedure TDextUniDACConnection.Connect;
begin
  if (FUniConnection <> nil) and not FUniConnection.Connected then
    FUniConnection.Connect;
end;

procedure TDextUniDACConnection.Disconnect;
begin
  if (FUniConnection <> nil) and FUniConnection.Connected then
    FUniConnection.Disconnect;
end;

function TDextUniDACConnection.IsConnected: Boolean;
begin
  Result := (FUniConnection <> nil) and FUniConnection.Connected;
end;

function TDextUniDACConnection.BeginTransaction: IDbTransaction;
begin
  Result := TDextUniDACTransaction.Create(FUniConnection);
end;

function TDextUniDACConnection.CreateCommand(const ASQL: string): IDbCommand;
begin
  Result := TDextUniDACCommand.Create(FUniConnection, ASQL);
end;

function TDextUniDACConnection.NativeConnection: TObject;
begin
  Result := FUniConnection;
end;

{ TDextUniDACCommand }

constructor TDextUniDACCommand.Create(AUniConnection: TUniConnection; const ASQL: string);
begin
  inherited Create;
  FUniConnection := AUniConnection;
  FUniQuery := TUniQuery.Create(nil);
  FUniQuery.Connection := FUniConnection;
  if ASQL <> '' then
    FUniQuery.SQL.Text := ASQL;
end;

destructor TDextUniDACCommand.Destroy;
begin
  FreeAndNil(FUniQuery);
  inherited;
end;

procedure TDextUniDACCommand.SetCommandText(const ASQL: string);
begin
  FUniQuery.Close;
  FUniQuery.SQL.Text := ASQL;
end;

function TDextUniDACCommand.GetCommandText: string;
begin
  Result := FUniQuery.SQL.Text;
end;

procedure TDextUniDACCommand.AddParam(const AName: string; const AValue: Variant; ADataType: TFieldType);
var
  Param: TParam;
begin
  Param := FUniQuery.Params.FindParam(AName);
  if Param = nil then
    Param := FUniQuery.Params.AddParam(AName);

  if ADataType <> ftUnknown then
    Param.DataType := ADataType;

  Param.Value := AValue;
end;

procedure TDextUniDACCommand.ClearParams;
begin
  FUniQuery.Params.Clear;
end;

function TDextUniDACCommand.ExecuteNonQuery: Integer;
begin
  FUniQuery.Execute;
  Result := FUniQuery.RowsAffected;
end;

function TDextUniDACCommand.ExecuteReader: IDbReader;
var
  ReaderQuery: TUniQuery;
  i: Integer;
begin
  ReaderQuery := TUniQuery.Create(nil);
  try
    ReaderQuery.Connection := FUniConnection;
    ReaderQuery.SQL.Text := FUniQuery.SQL.Text;

    for i := 0 to FUniQuery.Params.Count - 1 do
    begin
      with ReaderQuery.Params.AddParam(FUniQuery.Params[i].Name) do
      begin
        DataType := FUniQuery.Params[i].DataType;
        Value := FUniQuery.Params[i].Value;
      end;
    end;

    ReaderQuery.Open;
    Result := TDextUniDACReader.Create(ReaderQuery, True);
  except
    ReaderQuery.Free;
    raise;
  end;
end;

function TDextUniDACCommand.ExecuteScalar: Variant;
begin
  FUniQuery.Open;
  try
    if not FUniQuery.IsEmpty then
      Result := FUniQuery.Fields[0].Value
    else
      Result := Null;
  finally
    FUniQuery.Close;
  end;
end;

function TDextUniDACCommand.NativeCommand: TObject;
begin
  Result := FUniQuery;
end;

procedure TDextUniDACCommand.SetArraySize(ASize: Integer);
begin
  // UniDAC batch array size placeholder
end;

procedure TDextUniDACCommand.SetParamArray(const AName: string; const AValues: array of Variant; ADataType: TFieldType);
begin
  // UniDAC batch param placeholder
end;

function TDextUniDACCommand.ExecuteBatch: Integer;
begin
  Result := ExecuteNonQuery;
end;

function TDextUniDACCommand.GetParamValue(const AName: string): Variant;
var
  Param: TParam;
begin
  Param := FUniQuery.Params.FindParam(AName);
  if Param <> nil then
    Result := Param.Value
  else
    Result := Null;
end;

{ TDextUniDACReader }

constructor TDextUniDACReader.Create(AUniQuery: TUniQuery; AOwnsQuery: Boolean);
begin
  inherited Create;
  FUniQuery := AUniQuery;
  FOwnsQuery := AOwnsQuery;
end;

destructor TDextUniDACReader.Destroy;
begin
  if FOwnsQuery then
    FreeAndNil(FUniQuery);
  inherited;
end;

function TDextUniDACReader.Next: Boolean;
begin
  if FUniQuery.Bof and FUniQuery.Eof then
    Exit(False);

  if FUniQuery.Bof then
    FUniQuery.First
  else
    FUniQuery.Next;

  Result := not FUniQuery.Eof;
end;

function TDextUniDACReader.GetValue(const AFieldName: string): Variant;
var
  Field: TField;
begin
  Field := FUniQuery.FindField(AFieldName);
  if Field <> nil then
    Result := Field.Value
  else
    Result := Null;
end;

function TDextUniDACReader.GetValue(AFieldIndex: Integer): Variant;
begin
  if (AFieldIndex >= 0) and (AFieldIndex < FUniQuery.FieldCount) then
    Result := FUniQuery.Fields[AFieldIndex].Value
  else
    Result := Null;
end;

function TDextUniDACReader.IsNull(const AFieldName: string): Boolean;
var
  Field: TField;
begin
  Field := FUniQuery.FindField(AFieldName);
  Result := (Field = nil) or Field.IsNull;
end;

function TDextUniDACReader.IsNull(AFieldIndex: Integer): Boolean;
begin
  Result := (AFieldIndex < 0) or (AFieldIndex >= FUniQuery.FieldCount) or FUniQuery.Fields[AFieldIndex].IsNull;
end;

function TDextUniDACReader.GetFieldCount: Integer;
begin
  Result := FUniQuery.FieldCount;
end;

function TDextUniDACReader.GetFieldName(AFieldIndex: Integer): string;
begin
  if (AFieldIndex >= 0) and (AFieldIndex < FUniQuery.FieldCount) then
    Result := FUniQuery.Fields[AFieldIndex].FieldName
  else
    Result := '';
end;

function TDextUniDACReader.GetFieldType(AFieldIndex: Integer): TFieldType;
begin
  if (AFieldIndex >= 0) and (AFieldIndex < FUniQuery.FieldCount) then
    Result := FUniQuery.Fields[AFieldIndex].DataType
  else
    Result := ftUnknown;
end;

function TDextUniDACReader.NativeReader: TObject;
begin
  Result := FUniQuery;
end;

{ TDextUniDACTransaction }

constructor TDextUniDACTransaction.Create(AUniConnection: TUniConnection);
begin
  inherited Create;
  FUniConnection := AUniConnection;
  if (FUniConnection <> nil) and not FUniConnection.InTransaction then
  begin
    FUniConnection.StartTransaction;
    FActive := True;
  end
  else
    FActive := False;
end;

destructor TDextUniDACTransaction.Destroy;
begin
  if FActive and (FUniConnection <> nil) and FUniConnection.InTransaction then
    FUniConnection.Rollback;
  inherited;
end;

procedure TDextUniDACTransaction.Commit;
begin
  if FActive and (FUniConnection <> nil) and FUniConnection.InTransaction then
  begin
    FUniConnection.Commit;
    FActive := False;
  end;
end;

procedure TDextUniDACTransaction.Rollback;
begin
  if FActive and (FUniConnection <> nil) and FUniConnection.InTransaction then
  begin
    FUniConnection.Rollback;
    FActive := False;
  end;
end;

function TDextUniDACTransaction.IsActive: Boolean;
begin
  Result := FActive and (FUniConnection <> nil) and FUniConnection.InTransaction;
end;

end.
