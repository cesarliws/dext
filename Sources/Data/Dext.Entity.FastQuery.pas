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
  Dext.Entity.Drivers.Interfaces;

type
  /// <summary>
  /// Interface para execução de consultas de alta performance com serialização direta em UTF-8.
  /// </summary>
  IDextFastQuery = interface
    ['{7C1A8B9D-3E2F-4F5A-9C8B-1A2B3C4D5E6F}']
    /// <summary>
    /// Executa a consulta e grava o resultado serializado em JSON UTF-8 diretamente no Stream fornecido.
    /// </summary>
    procedure ExecuteToUtf8Stream(AStream: TStream);
    /// <summary>
    /// Executa a consulta e retorna o resultado em um array de bytes UTF-8.
    /// </summary>
    function ExecuteToUtf8Bytes: TBytes;
    /// <summary>
    /// Executa a consulta e retorna a string bruta formatada em JSON UTF-8.
    /// </summary>
    function ExecuteToUtf8String: RawByteString;
  end;

  /// <summary>
  /// Classe responsável pela execução e serialização de consultas SQL brutas em formato JSON UTF-8 sem alocação de AST.
  /// </summary>
  TDextFastQuery = class(TInterfacedObject, IDextFastQuery)
  private
    FConnection: IDbConnection;
    FSql: string;
  public
    /// <summary>
    /// Cria uma nova instância de TDextFastQuery com a conexão ativa e a instrução SQL fornecida.
    /// </summary>
    constructor Create(AConnection: IDbConnection; const ASql: string);
    /// <summary>
    /// Executa a consulta e grava os registros diretamente no stream no formato JSON.
    /// </summary>
    procedure ExecuteToUtf8Stream(AStream: TStream);
    /// <summary>
    /// Executa a consulta e retorna os bytes em UTF-8.
    /// </summary>
    function ExecuteToUtf8Bytes: TBytes;
    /// <summary>
    /// Executa a consulta e retorna o valor serializado como RawByteString.
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
  i, ColCount: Integer;
  ColNames: array of RawByteString;
  ColTypes: array of TFieldType;
  FirstRow, FirstCol: Boolean;

  procedure WriteStr(const S: RawByteString);
  begin
    if Length(S) > 0 then
      AStream.WriteBuffer(S[1], Length(S));
  end;

  function EscapeJsonStr(const S: string): RawByteString;
  var
    U: RawByteString;
  begin
    U := UTF8Encode(S);
    Result := '"' + U + '"';
  end;

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
      ColNames[i] := UTF8Encode('"' + Reader.GetColumnName(i) + '":');
      ColTypes[i] := Reader.GetColumnType(i);
    end;

    WriteStr('[');
    FirstRow := True;

    while Reader.Next do
    begin
      if not FirstRow then
        WriteStr(',')
      else
        FirstRow := False;

      WriteStr('{');
      FirstCol := True;

      for i := 0 to ColCount - 1 do
      begin
        if not FirstCol then
          WriteStr(',')
        else
          FirstCol := False;

        WriteStr(ColNames[i]);

        if Reader.IsNull(i) then
        begin
          WriteStr('null');
          Continue;
        end;

        case ColTypes[i] of
          ftSmallint, ftInteger, ftWord, ftAutoInc, ftLargeint:
            WriteStr(RawByteString(IntToStr(Reader.GetInt64(i))));

          ftFloat, ftCurrency, ftBCD, ftFMTBcd:
            WriteStr(RawByteString(FloatToStrF(Reader.GetDouble(i), ffGeneral, 15, 0, TFormatSettings.Invariant)));

          ftBoolean:
            if Reader.GetBoolean(i) then
              WriteStr('true')
            else
              WriteStr('false');

        else
          WriteStr(EscapeJsonStr(Reader.GetString(i)));
        end;
      end;
      WriteStr('}');
    end;

    WriteStr(']');
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
