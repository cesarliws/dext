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
{  Created: 2025-12-19                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.Entity.Drivers.FireDAC.Phys;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Variants,
  System.Rtti,
  System.TypInfo,
  Dext.Collections,
  System.DateUtils,
  Data.DB,
  Data.FmtBcd,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Error,
  FireDAC.Stan.Def,
  FireDAC.Stan.Pool,
  FireDAC.Stan.Async,
  FireDAC.Stan.Param,
  FireDAC.DatS,
  FireDAC.Phys.Intf,
  Dext.Entity.Drivers.Interfaces,
  Dext.Entity.TypeConverters,
  Dext.Entity.Dialects,
  Dext.Types.Nullable;

type
  /// <summary>
  ///   Implementation of IDbTransaction using FireDAC Phys Interface (IFDPhysTransaction).
  /// </summary>
  TFireDACPhysTransaction = class(TInterfacedObject, IDbTransaction)
  private
    FTransaction: IFDPhysTransaction;
  public
    constructor Create(ATransaction: IFDPhysTransaction);
    procedure Commit;
    procedure Rollback;
  end;

  /// <summary>
  ///   Implementation of IDbReader using FireDAC DatS (TFDDatSTable) and Phys Interface.
  ///   Bypasses TDataSet completely for high performance.
  /// </summary>
  TFireDACPhysReader = class(TInterfacedObject, IDbReader)
  private
    FCommand: IFDPhysCommand;
    FTable: TFDDatSTable;
    FDatSManager: TFDDatSManager;
    FOwnsDatSManager: Boolean;
    FCurrentRowIndex: Integer;
    FCurrentRow: TFDDatSRow;
    FRowCount: Integer;
  public
    constructor Create(ACommand: IFDPhysCommand; ATable: TFDDatSTable; ADatSManager: TFDDatSManager = nil; AOwnsManager: Boolean = False);
    destructor Destroy; override;
    
    function Next: Boolean;
    function GetValue(const AColumnName: string): TValue; overload;
    function GetValue(AColumnIndex: Integer): TValue; overload;
    function GetColumnCount: Integer;
    function GetColumnName(AIndex: Integer): string;
    procedure Close;
  end;

  /// <summary>
  ///   Implementation of IDbCommand using FireDAC Phys Interface (IFDPhysCommand).
  /// </summary>
  TFireDACPhysCommand = class(TInterfacedObject, IDbCommand)
  private
    FConnection: IFDPhysConnection;
    FCommand: IFDPhysCommand;
    FOnLog: TProc<string>;

    FDialect: TDatabaseDialect;
    
    procedure SetParamValue(Param: TFDParam; const AValue: TValue);
    procedure SetParamValueWithType(Param: TFDParam; const AValue: TValue; ADataType: TFieldType);
    function GetDialect: TDatabaseDialect;
  public
    constructor Create(AConnection: IFDPhysConnection; ADialect: TDatabaseDialect);
    destructor Destroy; override;
    
    procedure SetSQL(const ASQL: string);
    procedure AddParam(const AName: string; const AValue: TValue); overload;
    procedure AddParam(const AName: string; const AValue: TValue; ADataType: TFieldType); overload;
    procedure BindSequentialParams(const AValues: TArray<TValue>);
    procedure SetParamType(const AName: string; AType: TParamType);
    function GetParamValue(const AName: string): TValue;
    procedure ClearParams;
    
    procedure Execute;
    function ExecuteQuery: IDbReader;
    function ExecuteNonQuery: Integer;
    function ExecuteScalar: TValue;
    
    procedure SetArraySize(const ASize: Integer);
    procedure SetParamArray(const AName: string; const AValues: TArray<TValue>);
    procedure ExecuteBatch(const ATimes: Integer; const AOffset: Integer = 0);
  end;

  /// <summary>
  ///   Implementation of IDbConnection using FireDAC Phys Interface (IFDPhysConnection).
  ///   Provides "bare metal" access to the database driver.
  /// </summary>
  TFireDACPhysConnection = class(TInterfacedObject, IDbConnection)
  private
    FConnection: IFDPhysConnection;
    FDatSManager: TFDDatSManager;
    FOnLog: TProc<string>;
    FDialect: TDatabaseDialect;
    procedure DetectDialect;
  public
    constructor Create(AConnection: IFDPhysConnection);
    destructor Destroy; override;
    
    procedure Connect;
    procedure Disconnect;
    function IsConnected: Boolean;
    
    function BeginTransaction: IDbTransaction;
    function CreateCommand(const ASQL: string): IDbCommand;
    function GetLastInsertId: Variant;
    function TableExists(const ATableName: string): Boolean;
    
    function GetConnectionString: string;
    procedure SetConnectionString(const AValue: string);
    property ConnectionString: string read GetConnectionString write SetConnectionString;
    
    procedure SetOnLog(AValue: TProc<string>);
    function GetOnLog: TProc<string>;
    property OnLog: TProc<string> read GetOnLog write SetOnLog;
    
    function GetDialect: TDatabaseDialect;
    property Dialect: TDatabaseDialect read GetDialect;
    
    function IsPooled: Boolean;
    
    property PhysConnection: IFDPhysConnection read FConnection;
  end;

implementation

function PhysFDResolveParamsCollection(AParams: TFDParams; const AName: string): TFDParam;
var
  Idx: Integer;
  S: string;
begin
  Result := AParams.FindParam(AName);
  if Result <> nil then
    Exit;
  if (Length(AName) >= 2) and ((AName[1] = 'p') or (AName[1] = 'P')) then
  begin
    S := Copy(AName, 2, MaxInt);
    if TryStrToInt(S, Idx) and (Idx >= 0) and (Idx < AParams.Count) then
      Exit(AParams[Idx]);
  end;
  raise EDatabaseError.CreateFmt('Parameter ''%s'' not found', [AName]);
end;

{ TFireDACPhysTransaction }

constructor TFireDACPhysTransaction.Create(ATransaction: IFDPhysTransaction);
begin
  inherited Create;
  FTransaction := ATransaction;
  // Auto start is usually handled by the command execution or explicit start
  if FTransaction.State = tsInactive then
    FTransaction.StartTransaction;
end;

procedure TFireDACPhysTransaction.Commit;
begin
  FTransaction.Commit;
end;

procedure TFireDACPhysTransaction.Rollback;
begin
  FTransaction.Rollback;
end;

{ TFireDACPhysReader }

constructor TFireDACPhysReader.Create(ACommand: IFDPhysCommand; ATable: TFDDatSTable; ADatSManager: TFDDatSManager; AOwnsManager: Boolean);
begin
  inherited Create;
  FCommand := ACommand;
  FTable := ATable;
  FDatSManager := ADatSManager;
  FOwnsDatSManager := AOwnsManager;
  FCurrentRowIndex := -1;
  FRowCount := FTable.Rows.Count;
  FCurrentRow := nil;
end;

destructor TFireDACPhysReader.Destroy;
begin
  if FOwnsDatSManager then
    FDatSManager.Free;
  inherited;
end;

procedure TFireDACPhysReader.Close;
begin
  // Closing the command cursor
  FCommand.Close;
end;

function TFireDACPhysReader.GetColumnCount: Integer;
begin
  Result := FTable.Columns.Count;
end;

function TFireDACPhysReader.GetColumnName(AIndex: Integer): string;
begin
  Result := FTable.Columns[AIndex].Name;
end;

function TFireDACPhysReader.GetValue(AColumnIndex: Integer): TValue;
var
  Col: TFDDatSColumn;
  Val: Variant;
begin
  if FCurrentRow = nil then
    Exit(TValue.Empty);
    
  Col := FTable.Columns[AColumnIndex];
  // Direct access via Row
  if VarIsNull(FCurrentRow.GetData(AColumnIndex)) then
    Exit(TValue.Empty);

  // We can optimize this using FCurrentRow.GetData directly for native types
  // But Variant is the safest universal bridge for now inside TFDDatSRow.
  // TFDDatSRow also has GetValue, GetInt64, GetDouble...
  
  case Col.DataType of
    dtInt32, dtInt16, dtByte, dtUInt16, dtSByte: Result := TValue.From<Integer>(Integer(FCurrentRow.GetData(AColumnIndex)));
    dtInt64, dtUInt32, dtUInt64: Result := TValue.From<Int64>(Int64(FCurrentRow.GetData(AColumnIndex)));
    dtDouble, dtSingle, dtCurrency, dtBCD, dtFmtBCD: Result := TValue.From<Double>(Double(FCurrentRow.GetData(AColumnIndex)));
    dtDateTime, dtDate, dtTime, dtDateTimeStamp: Result := TValue.From<TDateTime>(TDateTime(FCurrentRow.GetData(AColumnIndex)));
    dtAnsiString, dtWideString, dtByteString, dtMemo, dtWideMemo, dtXML: Result := TValue.From<string>(string(FCurrentRow.GetData(AColumnIndex)));
    dtBlob, dtHBlob, dtHBFile: 
    begin
       // Binary data handling
       // Need to get stream or bytes
       // TFDDatSRow.GetData might return variant array for blobs
        Val := FCurrentRow.GetData(AColumnIndex);
        Result := TValue.FromVariant(Val); 
    end;
    dtBoolean: Result := TValue.From<Boolean>(Boolean(FCurrentRow.GetData(AColumnIndex)));
    dtGUID: 
      begin
         // DatS stores GUID as string or binary? Depends on mapping.
         // Assuming string for now or variant
         Val := FCurrentRow.GetData(AColumnIndex);
         Result := TValue.FromVariant(Val);
      end;
  else
    Val := FCurrentRow.GetData(AColumnIndex);
    Result := TValue.FromVariant(Val);
  end;
end;

function TFireDACPhysReader.GetValue(const AColumnName: string): TValue;
var
  ColIndex: Integer;
begin
  ColIndex := FTable.Columns.IndexOfName(AColumnName);
  if ColIndex < 0 then
    Exit(TValue.Empty);
  Result := GetValue(ColIndex);
end;

function TFireDACPhysReader.Next: Boolean;
begin
  Inc(FCurrentRowIndex);
  if FCurrentRowIndex < FRowCount then
  begin
    FCurrentRow := FTable.Rows[FCurrentRowIndex];
    Result := True;
  end
  else
  begin
    FCurrentRow := nil;
    Result := False;
  end;
end;

{ TFireDACPhysCommand }

constructor TFireDACPhysCommand.Create(AConnection: IFDPhysConnection; ADialect: TDatabaseDialect);
begin
  inherited Create;
  FConnection := AConnection;
  FConnection.CreateCommand(FCommand);
  // Params are managed by the command interface usually, 
  // explicitly creating TFDParams might be needed if the interface doesn't expose them directly conveniently
  // But IFDPhysCommand doesn't expose Params property directly in some versions?
  // Actually, standard usage involves creating a TFDParams collection and assigning it?
  // Let's check typical usage.
  // IFDPhysCommand has "Dictionary"? No.
  // Usually parameters are passed via "Params" property if it's a higher level wrapper.
  // In pure Phys: 
  // FCommand.Prepare(SQL)
  // FCommand.Params (TFDParams)
  
  // Wait, IFDPhysCommand inherits from IUnknown.
  // It should probably expose Params: TFDParams.
  // Investigating: IFDPhysCommand has 'Params' property of type TFDParams in most versions.
  // If not, we cast FCommand to TFDPhysCommand? No, that's implementation.
  
  // Check typical code:
  // FCmd.Prepare(SQL);
  // FCmd.Params[0].AsInteger := ...
  // So yes, Params should be available.
  
  FDialect := ADialect;
end;

destructor TFireDACPhysCommand.Destroy;
begin
  FCommand := nil; // Interface released
  inherited;
end;

procedure TFireDACPhysCommand.SetSQL(const ASQL: string);
begin
  // We should unprepare if already prepared
  if FCommand.State <> csInactive then
    FCommand.Close;
    
  FCommand.CommandText := ASQL;
  // Prepare is often needed to populate params collection from SQL
  // Or we add params manually.
  // FireDAC parses SQL to find params automatically on Prepare.
  FCommand.Prepare; 
end;

procedure TFireDACPhysCommand.AddParam(const AName: string; const AValue: TValue);
var
  Param: TFDParam;
begin
  Param := PhysFDResolveParamsCollection(FCommand.Params, AName);
  SetParamValue(Param, AValue);
end;

procedure TFireDACPhysCommand.AddParam(const AName: string; const AValue: TValue; ADataType: TFieldType);
var
  Param: TFDParam;
begin
  Param := PhysFDResolveParamsCollection(FCommand.Params, AName);
  SetParamValueWithType(Param, AValue, ADataType);
end;

procedure TFireDACPhysCommand.BindSequentialParams(const AValues: TArray<TValue>);
var
  I: Integer;
  Names: string;
begin
  if Length(AValues) <> FCommand.Params.Count then
  begin
    Names := '';
    for I := 0 to FCommand.Params.Count - 1 do
    begin
      if I > 0 then
        Names := Names + ', ';
      Names := Names + FCommand.Params[I].Name;
    end;
    raise EDatabaseError.Create(Format(
      'BindSequentialParams: %d value(s) provided but SQL has %d parameter(s) in order [%s]. ' +
      'FromSql passes an array by position; use one value per :placeholder in the SQL text.',
      [Length(AValues), FCommand.Params.Count, Names]));
  end;
  for I := 0 to High(AValues) do
    SetParamValue(FCommand.Params[I], AValues[I]);
end;

procedure TFireDACPhysCommand.SetParamValueWithType(Param: TFDParam; const AValue: TValue; ADataType: TFieldType);
begin
  // Force the explicit data type first
  Param.DataType := ADataType;
  
  if AValue.IsEmpty then
  begin
    Param.Clear;
    Exit;
  end;
  
  // Set value based on the explicit type
  case ADataType of
    ftString, ftWideString, ftMemo, ftWideMemo:
      Param.AsWideString := AValue.AsString;
    ftSmallint, ftInteger, ftWord, ftShortint:
      Param.AsInteger := AValue.AsInteger;
    ftLargeint:
      Param.AsLargeInt := AValue.AsInt64;
    ftFloat, ftCurrency, ftExtended:
      Param.AsFloat := AValue.AsExtended;
    ftBCD:
      Param.AsBCD := AValue.AsType<Currency>;
    ftFMTBcd:
      Param.AsFMTBCD := StrToBcd(AValue.AsString);
    ftDate:
      Param.AsDate := AValue.AsType<TDate>;
    ftTime:
      Param.AsTime := AValue.AsType<TTime>;
    ftDateTime, ftTimeStamp:
      Param.AsDateTime := AValue.AsType<TDateTime>;
    ftBoolean:
      Param.AsBoolean := AValue.AsBoolean;
    ftBlob, ftGraphic, ftParadoxOle, ftDBaseOle, ftTypedBinary, ftOraBlob:
    begin
      if AValue.TypeInfo = TypeInfo(TBytes) then
      begin
        var Bytes := AValue.AsType<TBytes>;
        var RawStr: RawByteString;
        SetLength(RawStr, Length(Bytes));
        if Length(Bytes) > 0 then
          Move(Bytes[0], RawStr[1], Length(Bytes));
        Param.AsBlob := RawStr;
      end
      else
        Param.Value := AValue.AsVariant;
    end;
    ftGuid:
      Param.AsGUID := StringToGUID(AValue.AsString);
  else
    // Fallback: use variant conversion
    Param.Value := AValue.AsVariant;
  end;
end;

procedure TFireDACPhysCommand.SetParamType(const AName: string; AType: TParamType);
var
  Param: TFDParam;
begin
  Param := FCommand.Params.FindParam(AName);
  if Param <> nil then
    Param.ParamType := AType;
end;

function TFireDACPhysCommand.GetParamValue(const AName: string): TValue;
var
  Param: TFDParam;
begin
  Param := FCommand.Params.FindParam(AName);
  if Param <> nil then
    Result := TValue.FromVariant(Param.Value)
  else
    Result := TValue.Empty;
end;

procedure TFireDACPhysCommand.ClearParams;
begin
  // Clearing values, not removing params (structure depends on SQL)
  var I: Integer;
  for I := 0 to FCommand.Params.Count - 1 do
    FCommand.Params[I].Clear;
end;

function TFireDACPhysCommand.GetDialect: TDatabaseDialect;
begin
  Result := FDialect;
end;



procedure TFireDACPhysCommand.Execute;
begin
  if Assigned(FOnLog) then FOnLog(FCommand.CommandText);
  FCommand.Execute;
end;

function TFireDACPhysCommand.ExecuteNonQuery: Integer;
begin
  if Assigned(FOnLog) then FOnLog(FCommand.CommandText);
  FCommand.Execute;
  Result := FCommand.RowsAffected;
end;

function TFireDACPhysCommand.ExecuteQuery: IDbReader;
var
  DatSManager: TFDDatSManager;
  Table: TFDDatSTable;
begin
  if Assigned(FOnLog) then FOnLog(FCommand.CommandText);
  // We need a DatS Manager for the results
  // We can use a local one or share.
  // For Phys command, we often need to Fetch.
  
  DatSManager := TFDDatSManager.Create;
  Table := DatSManager.Tables.Add;
  
  // Define structure from command?
  // FCommand.Define(Table); // Fills column defs
  
  FCommand.Define(Table);
  FCommand.Open; // Open cursor
  FCommand.Fetch(Table); // Fetch all rows into DatS Table
  
  // We pass ownership of DatSManager to the Reader, so it will be freed when Reader is destroyed.
  Result := TFireDACPhysReader.Create(FCommand, Table, DatSManager, True);
end;

function TFireDACPhysCommand.ExecuteScalar: TValue;
begin
  if Assigned(FOnLog) then FOnLog(FCommand.CommandText);
  // Execute and fetch 1 row
  var DatS := TFDDatSManager.Create;
  try
    var Table := DatS.Tables.Add;
    FCommand.Define(Table);
    FCommand.Open;
    FCommand.Fetch(Table, False); // Fetch next batch (AAll = False)
    
    if Table.Rows.Count > 0 then
    begin
       var Val := Table.Rows[0].GetData(0);
       Result := TValue.FromVariant(Val);
    end
    else
      Result := TValue.Empty;
  finally
    DatS.Free;
  end;
end;

procedure TFireDACPhysCommand.SetArraySize(const ASize: Integer);
begin
  FCommand.Params.ArraySize := ASize;
end;

procedure TFireDACPhysCommand.SetParamArray(const AName: string; const AValues: TArray<TValue>);
begin
  // Similar to standard driver
  var Param := FCommand.Params.FindParam(AName);
  if Param <> nil then
  begin
    for var I := 0 to High(AValues) do
    begin
       // Param.AsIntegers[I] := ...
       // ... logic same as standard driver
       Param.Values[I] := AValues[I].AsVariant; // Simplified fallback
    end;
  end;
end;

procedure TFireDACPhysCommand.ExecuteBatch(const ATimes: Integer; const AOffset: Integer);
begin
  FCommand.Execute(ATimes, AOffset);
end;

{ TFireDACPhysConnection }

constructor TFireDACPhysConnection.Create(AConnection: IFDPhysConnection);
begin
  inherited Create;
  FConnection := AConnection;
  FDatSManager := TFDDatSManager.Create;
end;

destructor TFireDACPhysConnection.Destroy;
begin
  FDatSManager.Free;
  inherited;
end;

procedure TFireDACPhysConnection.Connect;
begin
  FConnection.Open;
end;

procedure TFireDACPhysConnection.Disconnect;
begin
  FConnection.Close;
end;

function TFireDACPhysConnection.IsConnected: Boolean;
begin
  Result := FConnection.State = csConnected;
end;

procedure TFireDACPhysConnection.SetOnLog(AValue: TProc<string>);
begin
  FOnLog := AValue;
end;

function TFireDACPhysConnection.GetOnLog: TProc<string>;
begin
  Result := FOnLog;
end;

function TFireDACPhysConnection.BeginTransaction: IDbTransaction;
var
  Tx: IFDPhysTransaction;
begin
  FConnection.CreateTransaction(Tx);
  Result := TFireDACPhysTransaction.Create(Tx);
end;

function TFireDACPhysConnection.CreateCommand(const ASQL: string): IDbCommand;
var
  LCmd: TFireDACPhysCommand;
begin
  LCmd := TFireDACPhysCommand.Create(FConnection, GetDialect);
  LCmd.FOnLog := FOnLog;
  if ASQL <> '' then
    LCmd.SetSQL(ASQL);
  Result := LCmd;
end;

function TFireDACPhysConnection.GetLastInsertId: Variant;
begin
   Result := FConnection.GetLastAutoGenValue('');
end;

function TFireDACPhysConnection.TableExists(const ATableName: string): Boolean;
var
  MetaCmd: IFDPhysMetaInfoCommand;
  DatS: TFDDatSManager;
  Table: TFDDatSTable;
begin
  FConnection.CreateMetaInfoCommand(MetaCmd);
  
  MetaCmd.MetaInfoKind := mkTables;
  MetaCmd.ObjectScopes := [osMy, osOther, osSystem];
  MetaCmd.Wildcard := ATableName;
  
  DatS := TFDDatSManager.Create;
  try
    Table := DatS.Tables.Add;
    MetaCmd.Define(Table);
    MetaCmd.Open;
    MetaCmd.Fetch(Table);
    
    Result := Table.Rows.Count > 0;
  finally
    DatS.Free;
  end;
end;

procedure TFireDACPhysCommand.SetParamValue(Param: TFDParam; const AValue: TValue);
var
  Converter: ITypeConverter;
  ConvertedValue: TValue;
begin
  if AValue.IsEmpty then
  begin
    Param.Clear;
    if Param.DataType = ftUnknown then
      Param.DataType := ftString; 
    Exit;
  end;

  // Try to find a type converter
  Converter := TTypeConverterRegistry.Instance.GetConverter(AValue.TypeInfo);
  if Converter <> nil then
  begin
    ConvertedValue := Converter.ToDatabase(AValue, GetDialect);
    
    case ConvertedValue.Kind of
      tkInteger, tkInt64:
      begin
        Param.DataType := ftInteger;
        Param.AsInteger := ConvertedValue.AsInteger;
      end;
      tkFloat:
      begin
        if ConvertedValue.TypeInfo = TypeInfo(TDateTime) then
        begin
          Param.DataType := ftDateTime;
          Param.AsDateTime := ConvertedValue.AsType<TDateTime>;
        end
        else if ConvertedValue.TypeInfo = TypeInfo(TDate) then
        begin
          Param.DataType := ftDate;
          Param.AsDate := ConvertedValue.AsType<TDate>;
        end
        else if ConvertedValue.TypeInfo = TypeInfo(TTime) then
        begin
          Param.DataType := ftTime;
          Param.AsTime := ConvertedValue.AsType<TTime>;
        end
        else
        begin
          Param.DataType := ftFloat;
          Param.AsFloat := ConvertedValue.AsExtended;
        end;
      end;
      tkString, tkUString, tkWString, tkChar, tkWChar:
      begin
        Param.AsWideString := ConvertedValue.AsString;
      end;
      tkDynArray:
      begin
        if ConvertedValue.TypeInfo = TypeInfo(TBytes) then
        begin
           var Bytes := ConvertedValue.AsType<TBytes>;
           var RawStr: RawByteString;
           SetLength(RawStr, Length(Bytes));
           if Length(Bytes) > 0 then
             Move(Bytes[0], RawStr[1], Length(Bytes));
           Param.AsBlob := RawStr;
        end
        else
          Param.Value := ConvertedValue.AsVariant;
      end;
      else
        Param.Value := ConvertedValue.AsVariant;
    end;
  end
  else
  begin
    // Direct assignment logic
    case AValue.Kind of
      tkInteger, tkInt64: 
      begin
        Param.DataType := ftInteger;
        Param.AsInteger := AValue.AsInteger;
      end;
      tkFloat:
      begin
        if AValue.TypeInfo = TypeInfo(TDateTime) then
        begin
          Param.DataType := ftDateTime;
          Param.AsDateTime := AValue.AsType<TDateTime>;
        end
        else if AValue.TypeInfo = TypeInfo(TDate) then
        begin
          Param.DataType := ftDate;
          Param.AsDate := AValue.AsType<TDate>;
        end
        else if AValue.TypeInfo = TypeInfo(TTime) then
        begin
          Param.DataType := ftTime;
          Param.AsTime := AValue.AsType<TTime>;
        end
        else
        begin
          Param.DataType := ftFloat;
          Param.AsFloat := AValue.AsExtended;
        end;
      end;
      tkString, tkUString, tkWString, tkChar, tkWChar:
      begin
        Param.AsWideString := AValue.AsString;
      end;
      tkDynArray:
      begin
        if AValue.TypeInfo = TypeInfo(TBytes) then
        begin
           var Bytes := AValue.AsType<TBytes>;
           var RawStr: RawByteString;
           SetLength(RawStr, Length(Bytes));
           if Length(Bytes) > 0 then
             Move(Bytes[0], RawStr[1], Length(Bytes));
           Param.AsBlob := RawStr;
        end
        else
          Param.Value := AValue.AsVariant;
      end;
      tkEnumeration:
      begin
        if AValue.TypeInfo = TypeInfo(Boolean) then
        begin
          Param.DataType := ftBoolean;
          Param.AsBoolean := AValue.AsBoolean;
        end
        else
        begin
          Param.DataType := ftInteger;
          Param.AsInteger := AValue.AsOrdinal;
        end;
      end;
      tkRecord:
      begin
        if IsNullable(AValue.TypeInfo) then
        begin
           var Helper := TNullableHelper.Create(AValue.TypeInfo);
           if Helper.HasValue(AValue.GetReferenceToRawData) then
           begin
             var InnerVal := Helper.GetValue(AValue.GetReferenceToRawData);
             SetParamValue(Param, InnerVal);
           end
           else
           begin
             Param.Clear;
           end;
        end
        else
           Param.Value := AValue.AsVariant;
      end;
    else
      Param.Value := AValue.AsVariant;
    end;
  end;
end;
function TFireDACPhysConnection.GetConnectionString: string;
begin
  Result := ''; // Not easily supported via Phys interface directly without re-creating connection
end;

procedure TFireDACPhysConnection.SetConnectionString(const AValue: string);
begin
  // We don't support late-binding connection strings here yet.
end;

procedure TFireDACPhysConnection.DetectDialect;
var
  DriverID: string;
begin
  if FDialect <> ddUnknown then Exit;

  // IFDPhysConnection doesn't expose DriverName directly as property, checking...
  // Usually we can get it from Driver
  if FConnection.Driver <> nil then
    DriverID := FConnection.Driver.DriverID.ToLower
  else
    DriverID := ''; // Should not happen if connected

  FDialect := TDialectFactory.DetectDialect(DriverID);
end;

function TFireDACPhysConnection.GetDialect: TDatabaseDialect;
begin
  if FDialect = ddUnknown then
    DetectDialect;
  Result := FDialect;
end;

function TFireDACPhysConnection.IsPooled: Boolean;
begin
  Result := False; // Phys connections are not pooled
end;

end.
