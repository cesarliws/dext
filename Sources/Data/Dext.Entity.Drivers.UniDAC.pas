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
{  Notes:                                                                   }
{    - Mirrors Dext.Entity.Drivers.FireDAC.pas but uses UniDAC components.  }
{    - Batch DML (SetArraySize / SetParamArray / ExecuteBatch) is           }
{      simulated via a serial loop because UniDAC lacks native ArrayDML.    }
{    - GetLastInsertId uses a dialect-specific SQL query.                   }
{    - UniDAC uses standard Data.DB.TParam (not TFDParam).                  }
{                                                                           }
{***************************************************************************}
unit Dext.Entity.Drivers.UniDAC;

interface

{$I Dext.inc}

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
  Uni,          // TUniConnection, TUniQuery (UniDAC core)
  UniScript,    // for TUniScript (optional, if needed)
  Dext.Entity.Drivers.UniDAC.Links,
  Dext.Entity.Drivers.Interfaces,
  Dext.Entity.TypeConverters,
  Dext.Entity.Dialects,
  Dext.Types.Nullable,
  Dext.Types.UUID;

type
  TUniDACConnection = class;

  // -------------------------------------------------------------------------
  // TUniDACTransaction
  // -------------------------------------------------------------------------

  /// <summary>
  ///   UniDAC transaction manager. Wraps TUniConnection StartTransaction/Commit/Rollback.
  ///   UniDAC manages transactions directly on TUniConnection (no separate transaction object).
  /// </summary>
  TUniDACTransaction = class(TInterfacedObject, IDbTransaction)
  private
    FConnection: TUniConnection;
  public
    constructor Create(AConnection: TUniConnection);
    procedure Commit;
    procedure Rollback;
  end;

  // -------------------------------------------------------------------------
  // TUniDACReader
  // -------------------------------------------------------------------------

  /// <summary>
  ///   Implementation of IDbReader using a TUniQuery for forward-only row reading.
  /// </summary>
  TUniDACReader = class(TInterfacedObject, IDbReader)
  private
    FQuery: TUniQuery;
    FOwnsQuery: Boolean;
    FIsFirstMove: Boolean;
  public
    constructor Create(AQuery: TUniQuery; AOwnsQuery: Boolean);
    destructor Destroy; override;

    function Next: Boolean;
    function GetValue(const AColumnName: string): TValue; overload;
    function GetValue(AColumnIndex: Integer): TValue; overload;
    function GetColumnCount: Integer;
    function GetColumnName(AIndex: Integer): string;
    procedure Close;
  end;

  // -------------------------------------------------------------------------
  // TUniDACCommand
  // -------------------------------------------------------------------------

  /// <summary>
  ///   UniDAC SQL command. Supports query, non-query, scalar, and batch execution.
  ///   Batch execution is simulated via a serial loop (UniDAC has no native ArrayDML).
  /// </summary>
  TUniDACCommand = class(TInterfacedObject, IDbCommand)
  private
    FQuery: TUniQuery;
    FConnection: TUniConnection;
    FDialect: TDatabaseDialect;
    FOnLog: TProc<string>;
    // Batch DML simulation storage: param_name → array of values
    FBatchParams: TArray<TPair<string, TArray<TValue>>>;
    FArraySize: Integer;

    procedure LogSqlCommand(const ASQL: string);
    procedure SetParamValue(Param: TParam; const AValue: TValue);
    procedure SetParamValueWithType(Param: TParam; const AValue: TValue;
      ADataType: TFieldType);
    function GetDialect: TDatabaseDialect;
    function FindOrCreateBatchParam(const AName: string): Integer;
  public
    constructor Create(AConnection: TUniConnection; ADialect: TDatabaseDialect);
    destructor Destroy; override;

    procedure SetSQL(const ASQL: string);
    procedure AddParam(const AName: string; const AValue: TValue); overload;
    procedure AddParam(const AName: string; const AValue: TValue;
      ADataType: TFieldType); overload;
    procedure BindSequentialParams(const AValues: TArray<TValue>);
    procedure SetParamType(const AName: string; AType: TParamType);
    function GetParamValue(const AName: string): TValue;
    procedure ClearParams;

    procedure Execute;
    function ExecuteQuery: IDbReader;
    function ExecuteNonQuery: Integer;
    function ExecuteScalar: TValue;

    // Batch DML — simulated via serial loop
    procedure SetArraySize(const ASize: Integer);
    procedure SetParamArray(const AName: string; const AValues: TArray<TValue>);
    procedure ExecuteBatch(const ATimes: Integer; const AOffset: Integer = 0);
  end;

  // -------------------------------------------------------------------------
  // TUniDACConnection
  // -------------------------------------------------------------------------

  /// <summary>
  ///   Physical UniDAC connection wrapping TUniConnection.
  ///   Supports pooling, dialect auto-detection, and schema switching.
  /// </summary>
  TUniDACConnection = class(TInterfacedObject, IDbConnection)
  private
    FConnection: TUniConnection;
    FOwnsConnection: Boolean;
    FOnLog: TProc<string>;
    FDialect: TDatabaseDialect;
    procedure DetectDialect;
    procedure DoAfterConnect(Sender: TObject);
  public
    constructor Create(AConnection: TUniConnection; AOwnsConnection: Boolean = True);
    destructor Destroy; override;

    procedure Connect;
    procedure Disconnect;
    function IsConnected: Boolean;

    function BeginTransaction: IDbTransaction;
    function CreateCommand(const ASQL: string): IDbCommand;
    function GetLastInsertId: Variant;
    function TableExists(const ATableName: string): Boolean;
    function IsPooled: Boolean;

    function GetConnectionString: string;
    procedure SetConnectionString(const AValue: string);
    property ConnectionString: string read GetConnectionString write SetConnectionString;

    function GetDialect: TDatabaseDialect;
    property Dialect: TDatabaseDialect read GetDialect;

    procedure SetOnLog(AValue: TProc<string>);
    function GetOnLog: TProc<string>;
    property OnLog: TProc<string> read GetOnLog write SetOnLog;

    property Connection: TUniConnection read FConnection;
  end;

implementation

uses
  Dext.Core.Reflection;

// ---------------------------------------------------------------------------
// UniDACFieldToTValue — converts a TField to TValue
// Since UniDAC fields inherit from Data.DB.TField exactly like FireDAC,
// this function is structurally identical to FireDACFieldToTValue.
// ---------------------------------------------------------------------------
function UniDACFieldToTValue(Field: TField): TValue;
begin
  if (Field = nil) or Field.IsNull then
    Exit(TValue.Empty);
  try
    case Field.DataType of
      ftUnknown:
        Result := TValue.FromVariant(Field.Value);
      ftString, ftWideString, ftMemo, ftWideMemo, ftFixedChar, ftFixedWideChar:
        Result := TValue.From<string>(Field.AsWideString);
      ftSmallint, ftShortint:
        Result := TValue.From<Integer>(Field.AsInteger);
      ftInteger, ftAutoInc, ftWord:
        Result := TValue.From<Integer>(Field.AsInteger);
      ftLongWord:
        Result := TValue.From<Int64>(Field.AsLargeInt);
      ftLargeint:
        Result := TValue.From<Int64>(Field.AsLargeInt);
      ftFloat, ftSingle:
        Result := TValue.From<Double>(Field.AsFloat);
      ftExtended:
        Result := TValue.From<Double>(Field.AsFloat);
      ftCurrency, ftBCD:
        Result := TValue.From<Currency>(Field.AsCurrency);
      ftFMTBcd:
        try
          Result := TValue.From<Currency>(Field.AsCurrency);
        except
          Result := TValue.From<Double>(Field.AsFloat);
        end;
      ftBoolean:
        Result := TValue.From<Boolean>(Field.AsBoolean);
      ftDate:
        Result := TValue.From<TDate>(DateOf(Field.AsDateTime));
      ftTime:
        Result := TValue.From<TTime>(TimeOf(Field.AsDateTime));
      ftDateTime, ftTimeStamp, ftOraTimeStamp, ftTimeStampOffset:
        Result := TValue.From<TDateTime>(Field.AsDateTime);
      ftBlob, ftOraBlob, ftGraphic, ftTypedBinary, ftParadoxOle,
      ftDBaseOle, ftVarBytes, ftBytes:
        try
          Result := TValue.From<TBytes>(Field.AsBytes);
        except
          Result := TValue.FromVariant(Field.Value);
        end;
      ftGuid:
        Result := TValue.From<TGUID>(StringToGUID(Field.AsString));
    else
      Result := TValue.FromVariant(Field.Value);
    end;
  except
    on E: EVariantTypeCastError do
      Result := TValue.FromVariant(Field.Value);
  end;
end;

// ---------------------------------------------------------------------------
// TUniDACTransaction
// ---------------------------------------------------------------------------

constructor TUniDACTransaction.Create(AConnection: TUniConnection);
begin
  inherited Create;
  FConnection := AConnection;
  FConnection.StartTransaction;
end;

procedure TUniDACTransaction.Commit;
begin
  FConnection.Commit;
end;

procedure TUniDACTransaction.Rollback;
begin
  FConnection.Rollback;
end;

// ---------------------------------------------------------------------------
// TUniDACReader
// ---------------------------------------------------------------------------

constructor TUniDACReader.Create(AQuery: TUniQuery; AOwnsQuery: Boolean);
begin
  inherited Create;
  FQuery := AQuery;
  FOwnsQuery := AOwnsQuery;
  FIsFirstMove := True;
end;

destructor TUniDACReader.Destroy;
begin
  if FOwnsQuery then
    FQuery.Free;
  inherited;
end;

procedure TUniDACReader.Close;
begin
  FQuery.Close;
end;

function TUniDACReader.GetColumnCount: Integer;
begin
  Result := FQuery.FieldCount;
end;

function TUniDACReader.GetColumnName(AIndex: Integer): string;
begin
  Result := FQuery.Fields[AIndex].FieldName;
end;

function TUniDACReader.GetValue(AColumnIndex: Integer): TValue;
begin
  Result := UniDACFieldToTValue(FQuery.Fields[AColumnIndex]);
end;

function TUniDACReader.GetValue(const AColumnName: string): TValue;
begin
  Result := GetValue(FQuery.FieldByName(AColumnName).Index);
end;

function TUniDACReader.Next: Boolean;
begin
  if not FQuery.Active then
    Exit(False);

  if FIsFirstMove then
  begin
    FIsFirstMove := False;
    // TDataSet is already at First after Open; Eof=True when empty.
    Result := not FQuery.Eof;
  end
  else
  begin
    FQuery.Next;
    Result := not FQuery.Eof;
  end;
end;

// ---------------------------------------------------------------------------
// TUniDACCommand
// ---------------------------------------------------------------------------

constructor TUniDACCommand.Create(AConnection: TUniConnection;
  ADialect: TDatabaseDialect);
begin
  inherited Create;
  FConnection := AConnection;
  FDialect := ADialect;
  FArraySize := 0;
  FQuery := TUniQuery.Create(nil);
  FQuery.Connection := FConnection;
end;

destructor TUniDACCommand.Destroy;
begin
  FQuery.Free;
  inherited;
end;

function TUniDACCommand.GetDialect: TDatabaseDialect;
begin
  Result := FDialect;
end;

procedure TUniDACCommand.LogSqlCommand(const ASQL: string);
var
  i: Integer;
begin
  if not Assigned(FOnLog) then Exit;

  FOnLog('SQL: ' + ASQL);
  if (FQuery.Params <> nil) and (FQuery.Params.Count > 0) then
  begin
    for i := 0 to FQuery.Params.Count - 1 do
      FOnLog(Format('  Param[%s]: Type=%s, Value=%s',
        [FQuery.Params[i].Name,
         GetEnumName(TypeInfo(TFieldType), Integer(FQuery.Params[i].DataType)),
         VarToStr(FQuery.Params[i].Value)]));
  end;
end;

procedure TUniDACCommand.SetSQL(const ASQL: string);
begin
  FQuery.Params.Clear;
  FQuery.SQL.Text := ASQL;
  SetLength(FBatchParams, 0);
  FArraySize := 0;
end;

procedure TUniDACCommand.ClearParams;
begin
  FQuery.Params.Clear;
  SetLength(FBatchParams, 0);
end;

procedure TUniDACCommand.AddParam(const AName: string; const AValue: TValue);
var
  Param: TParam;
begin
  Param := FQuery.ParamByName(AName);
  SetParamValue(Param, AValue);
end;

procedure TUniDACCommand.AddParam(const AName: string; const AValue: TValue;
  ADataType: TFieldType);
var
  Param: TParam;
begin
  Param := FQuery.ParamByName(AName);
  SetParamValueWithType(Param, AValue, ADataType);
end;

procedure TUniDACCommand.BindSequentialParams(const AValues: TArray<TValue>);
var
  i: Integer;
begin
  if Length(AValues) = 0 then
    Exit;

  if FQuery.Params.Count <> Length(AValues) then
    raise Exception.CreateFmt(
      'FromSql parameter count mismatch: SQL has %d parameter(s) but %d value(s) were supplied.',
      [FQuery.Params.Count, Length(AValues)]);

  for i := 0 to High(AValues) do
    SetParamValue(FQuery.Params[i], AValues[i]);

  FQuery.Prepare;
end;

procedure TUniDACCommand.SetParamType(const AName: string; AType: TParamType);
begin
  FQuery.ParamByName(AName).ParamType := AType;
end;

function TUniDACCommand.GetParamValue(const AName: string): TValue;
begin
  Result := TValue.FromVariant(FQuery.ParamByName(AName).Value);
end;

procedure TUniDACCommand.Execute;
begin
  ExecuteNonQuery;
end;

function TUniDACCommand.ExecuteNonQuery: Integer;
begin
  LogSqlCommand(FQuery.SQL.Text);
  try
    FQuery.ExecSQL;
    Result := FQuery.RowsAffected;
  except
    on E: Exception do
    begin
      if Assigned(FOnLog) then
        FOnLog('  ❌ Error: ' + E.Message);
      raise;
    end;
  end;
end;

function TUniDACCommand.ExecuteQuery: IDbReader;
var
  Q: TUniQuery;
  i: Integer;
  Src, Dest: TParam;
begin
  Q := TUniQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text := FQuery.SQL.Text;

    LogSqlCommand(Q.SQL.Text);

    // Copy params
    for i := 0 to FQuery.Params.Count - 1 do
    begin
      Src := FQuery.Params[i];
      Dest := Q.Params.FindParam(Src.Name);
      if Dest <> nil then
      begin
        Dest.DataType := Src.DataType;
        Dest.Value := Src.Value;
      end;
    end;

    Q.Open;
    Result := TUniDACReader.Create(Q, True); // Reader owns the new query
  except
    on E: Exception do
    begin
      if Assigned(FOnLog) then
        FOnLog(Format('ERROR executing SQL: %s', [E.Message]));
      Q.Free;
      raise;
    end;
  end;
end;

function TUniDACCommand.ExecuteScalar: TValue;
begin
  LogSqlCommand(FQuery.SQL.Text);
  try
    FQuery.Open;
    try
      if not FQuery.Eof then
        Result := UniDACFieldToTValue(FQuery.Fields[0])
      else
        Result := TValue.Empty;
    finally
      FQuery.Close;
    end;
  except
    on E: Exception do
    begin
      if Assigned(FOnLog) then
        FOnLog('  ❌ Error: ' + E.Message);
      raise;
    end;
  end;
end;

// ---------------------------------------------------------------------------
// Batch DML simulation
// UniDAC has no native ArrayDML equivalent to FireDAC's Params.ArraySize +
// TFDQuery.Execute(N). We simulate it by storing arrays of values and
// executing the query once per row in ExecuteBatch.
// ---------------------------------------------------------------------------

function TUniDACCommand.FindOrCreateBatchParam(const AName: string): Integer;
var
  i: Integer;
begin
  for i := 0 to High(FBatchParams) do
    if SameText(FBatchParams[i].Key, AName) then
      Exit(i);
  // Not found → append
  i := Length(FBatchParams);
  SetLength(FBatchParams, i + 1);
  FBatchParams[i].Key := AName;
  SetLength(FBatchParams[i].Value, 0);
  Result := i;
end;

procedure TUniDACCommand.SetArraySize(const ASize: Integer);
begin
  FArraySize := ASize;
  // Pre-size all existing batch param arrays
  var i: Integer;
  for i := 0 to High(FBatchParams) do
    SetLength(FBatchParams[i].Value, ASize);
end;

procedure TUniDACCommand.SetParamArray(const AName: string;
  const AValues: TArray<TValue>);
var
  Idx: Integer;
begin
  Idx := FindOrCreateBatchParam(AName);
  FBatchParams[Idx].Value := Copy(AValues, 0, Length(AValues));
  if FArraySize < Length(AValues) then
    FArraySize := Length(AValues);
end;

procedure TUniDACCommand.ExecuteBatch(const ATimes: Integer;
  const AOffset: Integer);
var
  Row, ParamIdx: Integer;
  Pair: TPair<string, TArray<TValue>>;
  Param: TParam;
  RowOffset: Integer;
begin
  LogSqlCommand(FQuery.SQL.Text +
    Format(' (Batch simulation: %d rows, offset %d)', [ATimes, AOffset]));
  try
    for Row := AOffset to AOffset + ATimes - 1 do
    begin
      // Set param values for this row from the stored arrays
      for ParamIdx := 0 to High(FBatchParams) do
      begin
        Pair := FBatchParams[ParamIdx];
        Param := FQuery.Params.FindParam(Pair.Key);
        if (Param <> nil) and (Row < Length(Pair.Value)) then
          SetParamValue(Param, Pair.Value[Row]);
      end;
      FQuery.ExecSQL;
    end;
  except
    on E: Exception do
    begin
      if Assigned(FOnLog) then
        FOnLog('  ❌ Error in batch execution: ' + E.Message);
      raise;
    end;
  end;
end;

// ---------------------------------------------------------------------------
// SetParamValue — mirrors FireDAC's SetParamValue using standard TParam
// ---------------------------------------------------------------------------

procedure TUniDACCommand.SetParamValueWithType(Param: TParam;
  const AValue: TValue; ADataType: TFieldType);
var
  V: TValue;
  Bytes: TBytes;
begin
  V := AValue;
  TReflection.TryUnwrapProp(V, V);

  Param.DataType := ADataType;

  if V.IsEmpty then
  begin
    Param.Clear;
    Exit;
  end;

  case ADataType of
    ftString, ftWideString, ftMemo, ftWideMemo:
      Param.AsWideString := V.AsString;
    ftSmallint, ftInteger, ftWord, ftShortint:
      if V.Kind = tkEnumeration then
        Param.AsInteger := V.AsOrdinal
      else
        Param.AsInteger := V.AsInteger;
    ftLargeint:
      Param.AsLargeInt := V.AsInt64;
    ftFloat, ftCurrency, ftExtended:
      Param.AsFloat := V.AsExtended;
    ftBCD:
      Param.AsCurrency := V.AsType<Currency>;
    ftFMTBcd:
      case V.Kind of
        tkFloat:   Param.AsFloat := V.AsExtended;
        tkInteger, tkInt64: Param.AsFloat := V.AsInt64;
        tkString, tkUString, tkWString, tkLString:
          Param.AsFloat := StrToFloat(V.AsString);
      else
        Param.AsFloat := V.AsExtended;
      end;
    ftDate:
      Param.AsDate := V.AsType<TDate>;
    ftTime:
      Param.AsTime := V.AsType<TTime>;
    ftDateTime, ftTimeStamp, ftOraTimeStamp, ftTimeStampOffset:
      Param.AsDateTime := V.AsType<TDateTime>;
    ftBoolean:
      Param.AsBoolean := V.AsBoolean;
    ftBlob, ftGraphic, ftParadoxOle, ftDBaseOle, ftTypedBinary, ftOraBlob:
    begin
      if V.TypeInfo = TypeInfo(TBytes) then
      begin
        Bytes := V.AsType<TBytes>;
        Param.SetBlobRawData(Length(Bytes), @Bytes[0]);
      end
      else
        Param.Value := V.AsVariant;
    end;
    ftGuid:
      Param.AsString := StringReplace(V.AsString, '{', '',
        [rfReplaceAll, rfIgnoreCase]).Replace('}', '');
  else
    Param.Value := V.AsVariant;
  end;
end;

procedure TUniDACCommand.SetParamValue(Param: TParam; const AValue: TValue);
var
  Converter: ITypeConverter;
  ConvertedValue: TValue;
  TypeName: string;
  IsByteArray: Boolean;
  Bytes: TBytes;
  Helper: TNullableHelper;
  InnerVal: TValue;
  Underlying: PTypeInfo;
begin
  if AValue.IsEmpty then
  begin
    Param.Clear;
    // Set a reasonable DataType for NULL values to avoid "unknown type" errors
    if AValue.TypeInfo <> nil then
    begin
      TypeName := string(AValue.TypeInfo.Name);
      if (TypeName = 'TBytes') or (TypeName = 'TArray<System.Byte>') or
         (TypeName = 'TArray<Byte>') then
        Param.DataType := ftBlob
      else if Param.DataType = ftUnknown then
      begin
        case AValue.TypeInfo.Kind of
          tkInteger, tkInt64:    Param.DataType := ftInteger;
          tkFloat:
            if AValue.TypeInfo = TypeInfo(TDateTime) then Param.DataType := ftDateTime
            else if AValue.TypeInfo = TypeInfo(TDate) then Param.DataType := ftDate
            else if AValue.TypeInfo = TypeInfo(TTime) then Param.DataType := ftTime
            else Param.DataType := ftFloat;
          tkString, tkUString, tkWString, tkChar, tkWChar:
            Param.DataType := ftWideString;
          tkEnumeration:
            if AValue.TypeInfo = TypeInfo(Boolean) then Param.DataType := ftBoolean
            else Param.DataType := ftInteger;
        else
          Param.DataType := ftWideString;
        end;
      end;
    end
    else if Param.DataType = ftUnknown then
      Param.DataType := ftWideString;
    Exit;
  end;

  // Try registered type converter first
  Converter := TTypeConverterRegistry.Instance.GetConverter(AValue.TypeInfo);

  if Converter <> nil then
  begin
    ConvertedValue := Converter.ToDatabase(AValue, GetDialect);

    // GUID handling — force ftGuid for UUID/TGUID types
    if (AValue.TypeInfo = TypeInfo(TGUID)) or (AValue.TypeInfo = TypeInfo(TUUID)) then
    begin
      Param.DataType := ftGuid;
      Param.AsString := ConvertedValue.AsString;
    end
    else if (ConvertedValue.Kind in [tkString, tkUString, tkWString]) and
            ((Length(ConvertedValue.AsString) = 36) or
             (Length(ConvertedValue.AsString) = 38)) and
            (ConvertedValue.AsString.IndexOf('-') > 0) then
    begin
      Param.DataType := ftGuid;
      Param.AsString := ConvertedValue.AsString;
    end
    else
    case ConvertedValue.Kind of
      tkInteger, tkInt64:
      begin
        Param.DataType := ftLargeint;
        Param.AsLargeInt := ConvertedValue.AsInt64;
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
        Param.DataType := ftWideString;
        Param.AsWideString := ConvertedValue.AsString;
      end;
      tkDynArray:
      begin
        IsByteArray := False;
        if ConvertedValue.TypeInfo <> nil then
        begin
          TypeName := string(ConvertedValue.TypeInfo.Name);
          IsByteArray := (TypeName = 'TBytes') or
                         (TypeName = 'TArray<System.Byte>') or
                         (TypeName = 'TArray<Byte>');
        end;
        if IsByteArray then
        begin
          Param.DataType := ftBlob;
          Bytes := ConvertedValue.AsType<TBytes>;
          if Length(Bytes) > 0 then
            Param.SetBlobRawData(Length(Bytes), @Bytes[0])
          else
            Param.Clear;
        end
        else
          Param.Value := ConvertedValue.AsVariant;
      end;
    else
      Param.Value := ConvertedValue.AsVariant;
    end;
  end  // end if Converter <> nil
  else
  begin
    case AValue.Kind of
      tkInteger, tkInt64:
      begin
        Param.DataType := ftLargeint;
        Param.AsLargeInt := AValue.AsInt64;
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
        // GUID heuristic
        if ((Length(AValue.AsString) = 36) or (Length(AValue.AsString) = 38)) and
           (AValue.AsString.IndexOf('-') > 0) then
        begin
          Param.DataType := ftGuid;
          Param.AsString := AValue.AsString;
        end
        else
        begin
          Param.DataType := ftWideString;
          Param.AsWideString := AValue.AsString;
        end;
      end;
      tkDynArray:
      begin
        IsByteArray := False;
        if AValue.TypeInfo <> nil then
        begin
          TypeName := string(AValue.TypeInfo.Name);
          IsByteArray := (TypeName = 'TBytes') or
                         (TypeName = 'TArray<System.Byte>') or
                         (TypeName = 'TArray<Byte>');
        end;
        if IsByteArray then
        begin
          Param.DataType := ftBlob;
          Bytes := AValue.AsType<TBytes>;
          if Length(Bytes) > 0 then
            Param.SetBlobRawData(Length(Bytes), @Bytes[0])
          else
            Param.Clear;
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
          Helper := TNullableHelper.Create(AValue.TypeInfo);
          if Helper.HasValue(AValue.GetReferenceToRawData) then
          begin
            InnerVal := Helper.GetValue(AValue.GetReferenceToRawData);
            SetParamValue(Param, InnerVal);
          end
          else
          begin
            Param.Clear;
            Underlying := GetUnderlyingType(AValue.TypeInfo);
            if Underlying <> nil then
            begin
              case Underlying.Kind of
                tkInteger, tkInt64:
                  Param.DataType := ftLargeint;
                tkFloat:
                  Param.DataType := ftFloat;
                tkString, tkUString, tkWString:
                  Param.DataType := ftWideString;
                tkEnumeration:
                  if Underlying = TypeInfo(Boolean) then
                    Param.DataType := ftBoolean
                  else
                    Param.DataType := ftInteger;
              end;
            end;
          end;
        end
        else
          Param.Value := AValue.AsVariant;
      end;
    else
      Param.Value := AValue.AsVariant;
      if (VarIsNull(Param.Value) or VarIsEmpty(Param.Value)) and
         (Param.DataType = ftUnknown) then
        Param.DataType := ftWideString;
    end;
  end;
end;

// ---------------------------------------------------------------------------
// TUniDACConnection
// ---------------------------------------------------------------------------

constructor TUniDACConnection.Create(AConnection: TUniConnection;
  AOwnsConnection: Boolean);
begin
  inherited Create;
  FConnection := AConnection;
  FOwnsConnection := AOwnsConnection;
  FConnection.AfterConnect := DoAfterConnect;
end;

destructor TUniDACConnection.Destroy;
begin
  if FOwnsConnection then
    FConnection.Free;
  inherited;
end;

procedure TUniDACConnection.Connect;
begin
  FConnection.Connected := True;
end;

procedure TUniDACConnection.Disconnect;
begin
  FConnection.Connected := False;
end;

function TUniDACConnection.IsConnected: Boolean;
begin
  Result := FConnection.Connected;
end;

function TUniDACConnection.BeginTransaction: IDbTransaction;
begin
  Result := TUniDACTransaction.Create(FConnection);
end;

function TUniDACConnection.CreateCommand(const ASQL: string): IDbCommand;
var
  LCmd: TUniDACCommand;
begin
  LCmd := TUniDACCommand.Create(FConnection, GetDialect);
  LCmd.FOnLog := FOnLog;
  if ASQL <> '' then
    LCmd.SetSQL(ASQL);
  Result := LCmd;
end;

procedure TUniDACConnection.DoAfterConnect(Sender: TObject);
var
  DatabaseSchema: string;
  SqlDialect: ISQLDialect;
  Sql: string;
begin
  // Apply schema/search_path session setting after connect
  DatabaseSchema := FConnection.SpecificOptions.Values['Schema'];

  if DatabaseSchema <> '' then
  begin
    SqlDialect := TDialectFactory.CreateDialect(GetDialect);
    if SqlDialect <> nil then
    begin
      Sql := SqlDialect.GetSetSchemaSQL(DatabaseSchema);
      if Sql <> '' then
      begin
        if Assigned(FOnLog) then
          FOnLog('Applying session schema: ' + Sql);
        try
          FConnection.ExecSQL(Sql);
        except
          on E: Exception do
            if Assigned(FOnLog) then
              FOnLog('Error applying schema: ' + E.Message);
        end;
      end;
    end;
  end;
end;

function TUniDACConnection.GetLastInsertId: Variant;
var
  Q: TUniQuery;
  SQL: string;
begin
  // -------------------------------------------------------------------------
  // UniDAC does NOT have a FireDAC-equivalent GetLastAutoGenValue().
  //
  // PREFERRED approach for UniDAC (any database):
  //   Append "RETURNING <pk_column>" to your INSERT statement. After Execute,
  //   UniDAC automatically creates an output param named "RET_<COLUMN>".
  //   Read it via: IDbCommand.GetParamValue('RET_ID')
  //
  //   Example:
  //     Cmd := Conn.CreateCommand(
  //       'INSERT INTO t (name) VALUES (:name) RETURNING id');
  //     Cmd.AddParam('name', TValue.From<string>('foo'));
  //     Cmd.Execute;
  //     NewID := Cmd.GetParamValue('RET_ID').AsInt64;
  //
  // This method provides a FALLBACK for MySQL and SQL Server which have their
  // own last-ID functions. For PostgreSQL, Oracle, Firebird/InterBase, and
  // SQLite >= 3.35 the RETURNING approach above is strongly preferred.
  // -------------------------------------------------------------------------
  Result := Null;
  case GetDialect of
    ddMySQL:
      SQL := 'SELECT LAST_INSERT_ID()';
    ddSQLServer:
      SQL := 'SELECT SCOPE_IDENTITY()';
    ddSQLite:
      // SQLite 3.35+ also supports RETURNING. Use last_insert_rowid() as fallback
      // only when the INSERT was executed without RETURNING.
      SQL := 'SELECT last_insert_rowid()';
    ddPostgreSQL:
    begin
      // PostgreSQL has no session-level last_id function.
      // ALWAYS use INSERT ... RETURNING id and read RET_ID param.
      Result := Null;
      Exit;
    end;
    ddOracle:
    begin
      // Oracle: use INSERT ... RETURNING id INTO :RET_ID.
      Result := Null;
      Exit;
    end;
    ddFirebird, ddInterbase:
    begin
      // Firebird 2.1+ supports RETURNING. Use INSERT ... RETURNING id.
      Result := Null;
      Exit;
    end;
  else
    Result := Null;
    Exit;
  end;

  Q := TUniQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text := SQL;
    Q.Open;
    try
      if not Q.Eof then
        Result := Q.Fields[0].Value;
    finally
      Q.Close;
    end;
  finally
    Q.Free;
  end;
end;


function TUniDACConnection.TableExists(const ATableName: string): Boolean;
var
  List: TStringList;
  Table: string;
begin
  List := TStringList.Create;
  try
    try
      FConnection.GetTableNames(List);

      // Exact match
      if List.IndexOf(ATableName) >= 0 then
        Exit(True);
      // Quoted match
      if List.IndexOf('"' + ATableName + '"') >= 0 then
        Exit(True);
      // Case-insensitive fallback
      for Table in List do
      begin
        if SameText(Table, ATableName) or
           SameText(Table, '"' + ATableName + '"') or
           SameText(Table, ATableName.Replace('"', '')) then
          Exit(True);
      end;
      Result := False;
    except
      Result := False;
    end;
  finally
    List.Free;
  end;
end;

function TUniDACConnection.IsPooled: Boolean;
begin
  Result := FConnection.Pooling;
end;

function TUniDACConnection.GetConnectionString: string;
begin
  Result := FConnection.ConnectionString;
end;

procedure TUniDACConnection.SetConnectionString(const AValue: string);
begin
  if FConnection.Connected then
    FConnection.Connected := False;
  FConnection.ConnectionString := AValue;
end;

procedure TUniDACConnection.DetectDialect;
var
  Provider: string;
begin
  if FDialect <> ddUnknown then Exit;

  Provider := LowerCase(FConnection.ProviderName);

  if Provider = 'sqlite'              then FDialect := ddSQLite
  else if Provider = 'postgresql'     then FDialect := ddPostgreSQL
  else if Provider = 'mysql'          then FDialect := ddMySQL
  else if Provider = 'sql server'     then FDialect := ddSQLServer
  else if Provider = 'oracle'         then FDialect := ddOracle
  else if Provider = 'interbase'      then FDialect := ddFirebird  // UniDAC InterBase covers Firebird too
  else if Provider = 'db2'            then FDialect := ddUnknown
  else                                     FDialect := ddUnknown;
end;

function TUniDACConnection.GetDialect: TDatabaseDialect;
begin
  if FDialect = ddUnknown then
    DetectDialect;
  Result := FDialect;
end;

procedure TUniDACConnection.SetOnLog(AValue: TProc<string>);
begin
  FOnLog := AValue;
end;

function TUniDACConnection.GetOnLog: TProc<string>;
begin
  Result := FOnLog;
end;

end.

