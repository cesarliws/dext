{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2026 Cesar Romero & Dext Contributors             }
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
{  Created: 2026-08-10                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.Bcd.Tests;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  Data.DB,
  Data.FmtBcd,
  System.Rtti,
  System.SysUtils,
  Dext.Assertions,
  Dext.Core.SmartTypes,
  Dext.Core.ValueConverters,
  Dext.Entity,
  Dext.Entity.Dialects,
  Dext.Entity.TypeSystem,
  Dext.Specifications.Interfaces,
  Dext.Testing.Attributes;

type
  /// <summary>
  ///   Sample entity for testing TBcd property mappings.
  /// </summary>
  [Table('FX_RATES')]
  TFxRateEntity = class
  private
    FId: Int64;
    FRate: TBcd;
  public
    [PK, AutoInc]
    property Id: Int64 read FId write FId;

    [DbType(ftFMTBcd), Precision(28, 10)]
    property Rate: TBcd read FRate write FRate;
  end;

  /// <summary>
  ///   Unit tests for TBcd and ftFMTBcd first-class support in Dext ORM.
  /// </summary>
  [TestFixture('TBcd and ftFMTBcd Support Tests')]
  TBcdSupportTests = class
  public
    [Test]
    procedure ShouldConvertBcdToStringAndBack;

    [Test]
    procedure ShouldConvertBcdToCurrencyAndDouble;

    [Test]
    procedure ShouldPreserveHighPrecisionDecimal;

    [Test]
    procedure ShouldSupportPropExpressionWithBcd;

    [Test]
    procedure ShouldHonorPrecisionAttributeInDialects;

    [Test]
    procedure ShouldRaiseExceptionOnBcdToCurrencyOverflow;
  end;

implementation

{ TBcdSupportTests }

procedure TBcdSupportTests.ShouldConvertBcdToStringAndBack;
var
  OriginalBcd: TBcd;
  ValBcd: TValue;
  ValStr: TValue;
  ConvertedBcd: TBcd;
  BcdStr: string;
  ResultStr: string;
begin
  BcdStr := '123456789012345678.123456789';
  OriginalBcd := StrToBcd(BcdStr, TFormatSettings.Invariant);
  ValBcd := TValue.From<TBcd>(OriginalBcd);

  ValStr := TValueConverter.Convert(ValBcd, TypeInfo(string));
  ResultStr := StringReplace(ValStr.AsString, ',', '.', [rfReplaceAll]);
  Should(ResultStr).Be(BcdStr);

  ConvertedBcd := TValueConverter.Convert(ValStr,
    TypeInfo(TBcd)).AsType<TBcd>;
  ResultStr := StringReplace(BcdToStr(ConvertedBcd,
    TFormatSettings.Invariant), ',', '.', [rfReplaceAll]);
  Should(ResultStr).Be(BcdStr);
end;

procedure TBcdSupportTests.ShouldConvertBcdToCurrencyAndDouble;
var
  OriginalBcd: TBcd;
  ValBcd: TValue;
  ValCurr: TValue;
  ValDbl: TValue;
  CurrVal: Currency;
  DblVal: Double;
begin
  OriginalBcd := StrToBcd('1234.5678', TFormatSettings.Invariant);
  ValBcd := TValue.From<TBcd>(OriginalBcd);

  ValCurr := TValueConverter.Convert(ValBcd, TypeInfo(Currency));
  CurrVal := ValCurr.AsType<Currency>;
  Should(Abs(CurrVal - 1234.5678) < 0.0001).BeTrue;

  ValDbl := TValueConverter.Convert(ValBcd, TypeInfo(Double));
  DblVal := ValDbl.AsExtended;
  Should(Abs(DblVal - 1234.5678) < 0.0001).BeTrue;
end;

procedure TBcdSupportTests.ShouldPreserveHighPrecisionDecimal;
var
  HighPrecStr: string;
  ValStr: TValue;
  ValBcd: TValue;
  BcdOut: TBcd;
  ResultStr: string;
begin
  HighPrecStr := '987654321012345678.1234567891';
  ValStr := TValue.From<string>(HighPrecStr);

  // Exercise String -> TBcd converter path
  ValBcd := TValueConverter.Convert(ValStr, TypeInfo(TBcd));
  BcdOut := ValBcd.AsType<TBcd>;

  // Exercise TBcd -> String converter path
  ValStr := TValueConverter.Convert(ValBcd, TypeInfo(string));
  ResultStr := StringReplace(ValStr.AsString, ',', '.', [rfReplaceAll]);

  Should(ResultStr).Be(HighPrecStr);
end;

procedure TBcdSupportTests.ShouldSupportPropExpressionWithBcd;
var
  RateProp: BcdType;
  BcdVal: TBcd;
  Expr: BooleanExpression;
begin
  RateProp := BcdType.FromInfo(TPropInfo.Create('Rate'));
  BcdVal := StrToBcd('1.2500', TFormatSettings.Invariant);

  Expr := (RateProp = BcdVal);
  Should(Expr.Expression <> nil).BeTrue;
end;

procedure TBcdSupportTests.ShouldHonorPrecisionAttributeInDialects;
var
  PgDialect: ISQLDialect;
  OraDialect: ISQLDialect;
  FbDialect: ISQLDialect;
  SqlType: string;
begin
  PgDialect := TDialectFactory.CreateDialect(ddPostgreSQL);
  SqlType := PgDialect.GetColumnType(TypeInfo(TBcd), False, 28, 10);
  Should(SqlType).Be('NUMERIC(28,10)');

  OraDialect := TDialectFactory.CreateDialect(ddOracle);
  SqlType := OraDialect.GetColumnType(TypeInfo(TBcd), False, 28, 10);
  Should(SqlType).Be('NUMBER(28,10)');

  FbDialect := TDialectFactory.CreateDialect(ddFirebird);
  SqlType := FbDialect.GetColumnType(TypeInfo(TBcd), False, 28, 10);
  Should(SqlType).Be('DECIMAL(28,10)');
end;

procedure TBcdSupportTests.ShouldRaiseExceptionOnBcdToCurrencyOverflow;
var
  HighPrecStr: string;
  BcdVal: TBcd;
  ValBcd: TValue;
  ExceptionThrown: Boolean;
begin
  HighPrecStr := '987654321012345678.1234567891';
  BcdVal := StrToBcd(HighPrecStr, TFormatSettings.Invariant);
  ValBcd := TValue.From<TBcd>(BcdVal);

  ExceptionThrown := False;
  try
    TValueConverter.Convert(ValBcd, TypeInfo(Currency));
  except
    on E: EConvertError do
      ExceptionThrown := True;
  end;

  Should(ExceptionThrown).BeTrue;
end;

end.
