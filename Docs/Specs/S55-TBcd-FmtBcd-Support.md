# 📑 Spec S55: First-Class TBcd & ftFMTBcd High-Precision Decimal Support

## 1. Summary

This specification defines the architecture, type converter integration, FireDAC reader/writer driver logic, dialect column mapping, and query expression support for native `TBcd` and `ftFMTBcd` values throughout the Dext ORM pipeline.

---

## 2. Problem Statement

Financial and accounting applications require high-precision decimal representation (e.g. `NUMERIC(28,10)` or `DECIMAL(28,10)` in Firebird, PostgreSQL, Oracle, SQL Server, and MySQL).

* `Currency` in Delphi is fixed-point with max 4 decimal places.
* `Double` introduces binary floating-point precision loss.
* Prior to S55, Dext converted `ftFMTBcd` values to `Currency` or `Double`, losing precision and causing RTTI casting errors when parameterizing `TBcd` record values.

---

## 3. Architecture & Implementation

### 3.1 Type Converter Engine (`Dext.Core.ValueConverters.pas`)
Registered bidirectional zero-allocation converters in `TValueConverterRegistry`:
* `TBcd` <-> `Currency` (`BcdToCurr` / `CurrToBcd`)
* `TBcd` <-> `Double` / `Single` / `Extended` (`BcdToDouble` / `DoubleToBcd`)
* `TBcd` <-> `string` (`BcdToStr` / `StrToBcd` using `TFormatSettings.Invariant`)
* `TBcd` <-> `Integer` / `Int64` (`IntegerToBcd`)
* `Variant` <-> `TBcd` (`VarIsFMTBcd` / `VarToBcd`)

### 3.2 FireDAC Drivers (`Dext.Entity.Drivers.FireDAC.pas` & `FireDAC.Phys.pas`)
* **Reader:** `FireDACFieldToTValue` reads `ftBCD` and `ftFMTBcd` as `TValue.From<TBcd>(Field.AsBcd)` preserving complete scale and precision.
* **Writer:** `SetParamValueWithType` and `SetParamValue` check `TypeInfo(TBcd)` / `tkRecord` and assign `Param.AsFMTBCD := V.AsType<TBcd>`.

### 3.3 Database Dialects (`Dext.Entity.Dialects.pas`)
`GetColumnType` maps `TypeInfo(TBcd)` to native SQL column types:
* SQLite: `NUMERIC`
* PostgreSQL: `NUMERIC`
* Firebird / InterBase / SQL Server / MySQL: `DECIMAL(18,4)`
* Oracle: `NUMBER(28,10)`

### 3.4 Smart Property Aliases (`Dext.Core.SmartTypes.pas` & `Dext.Entity.pas`)
Added aliases:
* `BcdType = Prop<TBcd>;`
* `FmtBcdType = Prop<TBcd>;`

---

## 4. Verification

* Unit tests in `Dext.Bcd.Tests.pas` covering round-trip conversions, 10-decimal precision preservation, and `BcdType` query expressions.
