{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2026 Cesar Romero & Dext Contributors             }
{                                                                           }
{           Licensed under the Apache License, Version 2.0 (the "License"); }
{           you may not use this file except in compliance with the License. }
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
unit Dext.Core.DirectAccess;

interface

uses
  System.SysUtils,
  Dext.Types.UUID;

type
  PObject = ^TObject;
  PIInterface = ^IInterface;

  TDextDirectAccess = record
  public
    /// <summary>Calculates the raw pointer to the field at the given offset.</summary>
    class function Ptr(Instance: TObject; Offset: NativeInt): Pointer; static; inline;
    /// <summary>Reads an Integer value directly from the field offset.</summary>
    class function ReadInt32(Instance: TObject; Offset: NativeInt): Integer; static; inline;
    /// <summary>Writes an Integer value directly to the field offset.</summary>
    class procedure WriteInt32(Instance: TObject; Offset: NativeInt; Value: Integer); static; inline;
    /// <summary>Reads an Int64 value directly from the field offset.</summary>
    class function ReadInt64(Instance: TObject; Offset: NativeInt): Int64; static; inline;
    /// <summary>Writes an Int64 value directly to the field offset.</summary>
    class procedure WriteInt64(Instance: TObject; Offset: NativeInt; Value: Int64); static; inline;
    /// <summary>Reads a Boolean value directly from the field offset.</summary>
    class function ReadBoolean(Instance: TObject; Offset: NativeInt): Boolean; static; inline;
    /// <summary>Writes a Boolean value directly to the field offset.</summary>
    class procedure WriteBoolean(Instance: TObject; Offset: NativeInt; Value: Boolean); static; inline;
    /// <summary>Reads a Single value directly from the field offset.</summary>
    class function ReadSingle(Instance: TObject; Offset: NativeInt): Single; static; inline;
    /// <summary>Writes a Single value directly to the field offset.</summary>
    class procedure WriteSingle(Instance: TObject; Offset: NativeInt; Value: Single); static; inline;
    /// <summary>Reads a Double value directly from the field offset.</summary>
    class function ReadDouble(Instance: TObject; Offset: NativeInt): Double; static; inline;
    /// <summary>Writes a Double value directly to the field offset.</summary>
    class procedure WriteDouble(Instance: TObject; Offset: NativeInt; Value: Double); static; inline;
    /// <summary>Reads a Currency value directly from the field offset.</summary>
    class function ReadCurrency(Instance: TObject; Offset: NativeInt): Currency; static; inline;
    /// <summary>Writes a Currency value directly to the field offset.</summary>
    class procedure WriteCurrency(Instance: TObject; Offset: NativeInt; Value: Currency); static; inline;
    /// <summary>Reads a managed string directly from the field offset.</summary>
    class function ReadString(Instance: TObject; Offset: NativeInt): string; static; inline;
    /// <summary>Writes a managed string directly to the field offset.</summary>
    class procedure WriteString(Instance: TObject; Offset: NativeInt; const Value: string); static; inline;
    /// <summary>Reads an object reference directly from the field offset.</summary>
    class function ReadObject(Instance: TObject; Offset: NativeInt): TObject; static; inline;
    /// <summary>Writes an object reference directly to the field offset.</summary>
    class procedure WriteObject(Instance: TObject; Offset: NativeInt; Value: TObject); static; inline;
    /// <summary>Reads an interface reference directly from the field offset.</summary>
    class function ReadInterface(Instance: TObject; Offset: NativeInt): IInterface; static; inline;
    /// <summary>Writes an interface reference directly to the field offset.</summary>

    /// <summary>Reads a GUID value directly from the field offset.</summary>
    class function ReadGUID(Instance: TObject; Offset: NativeInt): TGUID; static; inline;
    /// <summary>Writes a GUID value directly to the field offset.</summary>
    class procedure WriteGUID(Instance: TObject; Offset: NativeInt; const Value: TGUID); static; inline;
    /// <summary>Reads a UUID value directly from the field offset.</summary>
    class function ReadUUID(Instance: TObject; Offset: NativeInt): TUUID; static; inline;
    /// <summary>Writes a UUID value directly to the field offset.</summary>
    class procedure WriteUUID(Instance: TObject; Offset: NativeInt; const Value: TUUID); static; inline;
    class procedure WriteInterface(Instance: TObject; Offset: NativeInt; const Value: IInterface); static; inline;
  end;

implementation

class function TDextDirectAccess.Ptr(Instance: TObject; Offset: NativeInt): Pointer;
begin
  Result := PByte(Instance) + Offset;
end;

class function TDextDirectAccess.ReadInt32(Instance: TObject; Offset: NativeInt): Integer;
begin
  Result := PInteger(Ptr(Instance, Offset))^;
end;

class procedure TDextDirectAccess.WriteInt32(Instance: TObject; Offset: NativeInt; Value: Integer);
begin
  PInteger(Ptr(Instance, Offset))^ := Value;
end;

class function TDextDirectAccess.ReadInt64(Instance: TObject; Offset: NativeInt): Int64;
begin
  Result := PInt64(Ptr(Instance, Offset))^;
end;

class procedure TDextDirectAccess.WriteInt64(Instance: TObject; Offset: NativeInt; Value: Int64);
begin
  PInt64(Ptr(Instance, Offset))^ := Value;
end;

class function TDextDirectAccess.ReadBoolean(Instance: TObject; Offset: NativeInt): Boolean;
begin
  Result := PBoolean(Ptr(Instance, Offset))^;
end;

class procedure TDextDirectAccess.WriteBoolean(Instance: TObject; Offset: NativeInt; Value: Boolean);
begin
  PBoolean(Ptr(Instance, Offset))^ := Value;
end;

class function TDextDirectAccess.ReadSingle(Instance: TObject; Offset: NativeInt): Single;
begin
  Result := PSingle(Ptr(Instance, Offset))^;
end;

class procedure TDextDirectAccess.WriteSingle(Instance: TObject; Offset: NativeInt; Value: Single);
begin
  PSingle(Ptr(Instance, Offset))^ := Value;
end;

class function TDextDirectAccess.ReadDouble(Instance: TObject; Offset: NativeInt): Double;
begin
  Result := PDouble(Ptr(Instance, Offset))^;
end;

class procedure TDextDirectAccess.WriteDouble(Instance: TObject; Offset: NativeInt; Value: Double);
begin
  PDouble(Ptr(Instance, Offset))^ := Value;
end;

class function TDextDirectAccess.ReadCurrency(Instance: TObject; Offset: NativeInt): Currency;
begin
  Result := PCurrency(Ptr(Instance, Offset))^;
end;

class procedure TDextDirectAccess.WriteCurrency(Instance: TObject; Offset: NativeInt; Value: Currency);
begin
  PCurrency(Ptr(Instance, Offset))^ := Value;
end;

class function TDextDirectAccess.ReadString(Instance: TObject; Offset: NativeInt): string;
begin
  Result := PString(Ptr(Instance, Offset))^;
end;

class procedure TDextDirectAccess.WriteString(Instance: TObject; Offset: NativeInt; const Value: string);
begin
  PString(Ptr(Instance, Offset))^ := Value;
end;

class function TDextDirectAccess.ReadObject(Instance: TObject; Offset: NativeInt): TObject;
begin
  Result := PObject(Ptr(Instance, Offset))^;
end;

class procedure TDextDirectAccess.WriteObject(Instance: TObject; Offset: NativeInt; Value: TObject);
begin
  PObject(Ptr(Instance, Offset))^ := Value;
end;

class function TDextDirectAccess.ReadInterface(Instance: TObject; Offset: NativeInt): IInterface;
begin
  Result := PIInterface(Ptr(Instance, Offset))^;
end;

class procedure TDextDirectAccess.WriteInterface(Instance: TObject; Offset: NativeInt; const Value: IInterface);
begin
  PIInterface(Ptr(Instance, Offset))^ := Value;
end;

class function TDextDirectAccess.ReadGUID(Instance: TObject; Offset: NativeInt): TGUID;
begin
  Result := PGUID(Ptr(Instance, Offset))^;
end;

class procedure TDextDirectAccess.WriteGUID(Instance: TObject; Offset: NativeInt; const Value: TGUID);
begin
  PGUID(Ptr(Instance, Offset))^ := Value;
end;

class function TDextDirectAccess.ReadUUID(Instance: TObject; Offset: NativeInt): TUUID;
begin
  Move(Ptr(Instance, Offset)^, Result, SizeOf(TUUID));
end;

class procedure TDextDirectAccess.WriteUUID(Instance: TObject; Offset: NativeInt; const Value: TUUID);
begin
  Move(Value, Ptr(Instance, Offset)^, SizeOf(TUUID));
end;

end.

