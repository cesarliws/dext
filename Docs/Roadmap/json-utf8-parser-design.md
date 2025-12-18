# 🚀 UTF-8 JSON Parser - Design Document

## Executive Summary

This document outlines the design for a **zero-allocation UTF-8 JSON parser** for the Dext framework. This parser will eliminate the UTF-8 ↔ UTF-16 transcoding overhead that currently exists in JSON processing, resulting in 30-50% performance improvement and 40-60% reduction in memory allocations.

---

## Problem Statement

### Current Architecture (UTF-16 Based)

```
HTTP Request (UTF-8 bytes)
    ↓ TEncoding.UTF8.GetString()  ← ALLOCATION + TRANSCODING
UnicodeString (UTF-16)
    ↓ TDextJson.Deserialize()
JsonDataObjects Parser
    ↓ Multiple string allocations
Object/Record
```

**Costs:**
1. **Memory**: Double allocation (bytes + string)
2. **CPU**: UTF-8 → UTF-16 conversion for every character
3. **GC Pressure**: Temporary strings during parsing
4. **Cache Misses**: UTF-16 is 2x larger than UTF-8

### Real-World Impact

For a typical API endpoint receiving JSON:
- **Request**: 1KB JSON payload (UTF-8)
- **Current Process**:
  - Allocate 2KB for UTF-16 string
  - Convert 1000 bytes → 1000 chars
  - Parse and allocate intermediate strings
  - **Total**: ~4-6KB allocated, ~2000 CPU cycles for conversion

---

## Solution: UTF-8 Native Parser

### Design Goals

1. **Zero String Allocation**: Parse directly from `TByteSpan`
2. **Zero Transcoding**: Keep data in UTF-8 throughout
3. **Backward Compatible**: Existing `TDextJson` API unchanged
4. **Pluggable**: New parser as optional provider
5. **Streaming Ready**: Foundation for streaming JSON

---

## Architecture

### Component Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Dext.Json.pas                           │
│              (Public API - No Changes)                      │
│  TDextJson.Deserialize<T>(json: string): T                 │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                  Dext.Json.Types.pas                        │
│              IDextJsonProvider Interface                    │
└─────────────────────────────────────────────────────────────┘
                            ↓
        ┌───────────────────┴───────────────────┐
        ↓                                       ↓
┌──────────────────────┐          ┌──────────────────────────┐
│ JsonDataObjects      │          │   UTF8 Parser (NEW)      │
│ (Current - UTF-16)   │          │   (Zero-Allocation)      │
└──────────────────────┘          └──────────────────────────┘
                                              ↓
                        ┌─────────────────────┴─────────────────────┐
                        ↓                                           ↓
            ┌──────────────────────┐              ┌──────────────────────┐
            │ UTF8.Tokenizer.pas   │              │  UTF8.Parser.pas     │
            │ (Token Scanner)      │              │  (Object Builder)    │
            └──────────────────────┘              └──────────────────────┘
```

---

## Detailed Design

### 1. Token Scanner (`Dext.Json.UTF8.Tokenizer.pas`)

**Purpose**: Forward-only scanner that identifies JSON tokens without allocation.

```pascal
type
  TJsonTokenType = (
    jtNone,
    jtObjectStart,    // {
    jtObjectEnd,      // }
    jtArrayStart,     // [
    jtArrayEnd,       // ]
    jtString,         // "..."
    jtNumber,         // 123, 45.67
    jtTrue,           // true
    jtFalse,          // false
    jtNull,           // null
    jtColon,          // :
    jtComma           // ,
  );

  TJsonToken = record
    TokenType: TJsonTokenType;
    Value: TByteSpan;           // Points to token in original buffer
    Line: Integer;              // For error reporting
    Column: Integer;
  end;

  TJsonTokenizer = record
  private
    FSource: TByteSpan;
    FPosition: Integer;
    FLine: Integer;
    FColumn: Integer;
    
    procedure SkipWhitespace;
    function ScanString: TByteSpan;
    function ScanNumber: TByteSpan;
    function IsDigit(B: Byte): Boolean; inline;
    function IsWhitespace(B: Byte): Boolean; inline;
  public
    constructor Create(const ASource: TByteSpan);
    
    /// <summary>Advances to next token. Returns false at EOF.</summary>
    function NextToken(out AToken: TJsonToken): Boolean;
    
    /// <summary>Peeks at next token without advancing.</summary>
    function PeekToken: TJsonTokenType;
    
    /// <summary>Current position in source.</summary>
    property Position: Integer read FPosition;
  end;
```

**Key Features:**
- **No Allocations**: `TByteSpan` points to original buffer
- **Single Pass**: Forward-only scanning
- **Error Context**: Line/column tracking for diagnostics

---

### 2. Parser (`Dext.Json.UTF8.Parser.pas`)

**Purpose**: Builds objects/records from token stream.

```pascal
type
  TUTF8JsonParser = class
  private
    FTokenizer: TJsonTokenizer;
    FSettings: TDextSettings;
    
    function ParseValue(AType: PTypeInfo): TValue;
    function ParseObject(AType: PTypeInfo): TValue;
    function ParseArray(AType: PTypeInfo): TValue;
    function ParseString(const ASpan: TByteSpan): string;
    function ParseNumber(const ASpan: TByteSpan; AType: PTypeInfo): TValue;
    
    procedure ExpectToken(AExpected: TJsonTokenType);
    procedure RaiseError(const AMessage: string);
  public
    constructor Create(const ASource: TByteSpan; const ASettings: TDextSettings);
    
    function Parse<T>: T;
    function ParseValue(AType: PTypeInfo): TValue;
  end;
```

**Parsing Strategy:**

```pascal
function TUTF8JsonParser.ParseObject(AType: PTypeInfo): TValue;
var
  Token: TJsonToken;
  RttiType: TRttiType;
  Field: TRttiField;
  FieldName: string;
  FieldValue: TValue;
begin
  ExpectToken(jtObjectStart);  // {
  
  RttiType := TRttiContext.Create.GetType(AType);
  TValue.Make(nil, AType, Result);
  
  while FTokenizer.NextToken(Token) do
  begin
    case Token.TokenType of
      jtObjectEnd: Exit;  // }
      
      jtString:
      begin
        // Field name (zero-copy until we need to match)
        FieldName := ParseString(Token.Value);
        ExpectToken(jtColon);
        
        Field := RttiType.GetField(FieldName);
        if Field <> nil then
        begin
          FieldValue := ParseValue(Field.FieldType.Handle);
          Field.SetValue(Result.GetReferenceToRawData, FieldValue);
        end
        else
          SkipValue;  // Unknown field
      end;
      
      jtComma: Continue;
    end;
  end;
end;
```

---

### 3. Provider Implementation (`Dext.Json.Driver.UTF8.pas`)

**Purpose**: Implements `IDextJsonProvider` using UTF-8 parser.

```pascal
type
  TUTF8JsonProvider = class(TInterfacedObject, IDextJsonProvider)
  private
    FSettings: TDextSettings;
  public
    constructor Create(const ASettings: TDextSettings);
    
    function CreateObject: IDextJsonObject;
    function CreateArray: IDextJsonArray;
    function Parse(const Json: string): IDextJsonNode;
    
    // UTF-8 specific overloads
    function ParseUTF8(const ABytes: TBytes): IDextJsonNode; overload;
    function ParseUTF8(const ASpan: TByteSpan): IDextJsonNode; overload;
  end;
```

---

## String Handling Strategy

### Challenge: When to Convert UTF-8 → UTF-16?

**Principle**: Convert only when absolutely necessary.

#### Scenario 1: Property Names (Field Matching)

```pascal
// Option A: Convert every property name (SLOW)
FieldName := ParseString(Token.Value);  // UTF-8 → UTF-16
Field := RttiType.GetField(FieldName);

// Option B: Compare as UTF-8 (FAST)
for Field in RttiType.GetFields do
begin
  if Token.Value.EqualsString(Field.Name) then  // UTF-8 comparison
  begin
    // Found! Now parse value
  end;
end;
```

**Decision**: Use **Option B** with caching:
- First access: Build UTF-8 lookup table for field names
- Subsequent: Direct UTF-8 comparison (no conversion)

#### Scenario 2: String Values

```pascal
// User's record field is `string` (UTF-16)
type
  TUser = record
    Name: string;  // Must be UTF-16 eventually
  end;
```

**Decision**: Convert only final string values:
- Parse token as `TByteSpan`
- When assigning to `string` field: `Token.Value.ToString` (UTF-8 → UTF-16)
- **Savings**: Intermediate strings during parsing remain as spans

---

## Performance Analysis

### Benchmark Scenario

**Input**: 1KB JSON with 10 fields
```json
{
  "id": 123,
  "name": "John Doe",
  "email": "john@example.com",
  "age": 30,
  "active": true,
  ...
}
```

### Current (UTF-16) Parser

| Operation | Allocations | CPU Cycles |
|-----------|-------------|------------|
| UTF-8 → UTF-16 conversion | 2KB string | ~2000 |
| Parse field names | 10 strings (~200 bytes) | ~500 |
| Parse string values | 3 strings (~100 bytes) | ~300 |
| Intermediate objects | ~500 bytes | ~200 |
| **Total** | **~2.8KB** | **~3000** |

### UTF-8 Parser (Proposed)

| Operation | Allocations | CPU Cycles |
|-----------|-------------|------------|
| UTF-8 → UTF-16 conversion | 0 (direct bytes) | 0 |
| Parse field names | 0 (TByteSpan) | ~100 |
| Parse string values | 3 strings (~100 bytes) | ~300 |
| Intermediate objects | ~500 bytes | ~200 |
| **Total** | **~600 bytes** | **~600** |

**Improvement:**
- **Memory**: 78% reduction (2.8KB → 0.6KB)
- **CPU**: 80% reduction (3000 → 600 cycles)

---

## Integration Strategy

### Phase 1: Opt-In (Safe Introduction)

```pascal
// Existing code (no change)
var User := TDextJson.Deserialize<TUser>(jsonString);

// New opt-in API
var User := TDextJson.DeserializeUTF8<TUser>(jsonBytes);
```

### Phase 2: Auto-Detection

```pascal
// TDextJson automatically uses UTF-8 parser if input is TBytes
var User := TDextJson.Deserialize<TUser>(jsonBytes);  // UTF-8 parser
var User := TDextJson.Deserialize<TUser>(jsonString); // UTF-16 parser (compat)
```

### Phase 3: Default (After Validation)

```pascal
// Switch default provider
TDextJson.Provider := TUTF8JsonProvider.Create(TDextSettings.Default);
```

---

## Error Handling

### Token-Level Errors

```pascal
procedure TJsonTokenizer.RaiseError(const AMessage: string);
begin
  raise EDextJsonException.CreateFmt(
    '%s at line %d, column %d',
    [AMessage, FLine, FColumn]
  );
end;
```

### Parser-Level Errors

```pascal
// Example: Expected object, got array
ExpectToken(jtObjectStart);  // Raises if next token is not {
```

**Error Messages:**
- "Unexpected token ']' at line 5, column 12"
- "Invalid number format '12.34.56' at line 3, column 8"
- "Unterminated string at line 10, column 15"

---

## Testing Strategy

### Unit Tests

1. **Tokenizer Tests**
   - [ ] Scan simple object `{}`
   - [ ] Scan nested objects
   - [ ] Scan arrays
   - [ ] Scan all primitive types
   - [ ] Handle whitespace correctly
   - [ ] Report errors with line/column

2. **Parser Tests**
   - [ ] Parse to simple record
   - [ ] Parse to nested record
   - [ ] Parse to class
   - [ ] Parse arrays
   - [ ] Handle null values
   - [ ] Handle missing fields
   - [ ] Handle extra fields (ignore)

3. **Integration Tests**
   - [ ] Deserialize existing test cases
   - [ ] Compare output with JsonDataObjects
   - [ ] Verify no regressions

### Performance Benchmarks

```pascal
procedure BenchmarkJSONParsing;
const
  JSON_SAMPLE = '{"id":123,"name":"John","email":"john@example.com"}';
  ITERATIONS = 100000;
var
  StartTime: TDateTime;
  UTF16Time, UTF8Time: Double;
begin
  // Benchmark UTF-16 parser
  StartTime := Now;
  for var i := 1 to ITERATIONS do
    TDextJson.Deserialize<TUser>(JSON_SAMPLE);
  UTF16Time := MilliSecondsBetween(Now, StartTime);
  
  // Benchmark UTF-8 parser
  var Bytes := TEncoding.UTF8.GetBytes(JSON_SAMPLE);
  StartTime := Now;
  for var i := 1 to ITERATIONS do
    TDextJson.DeserializeUTF8<TUser>(Bytes);
  UTF8Time := MilliSecondsBetween(Now, StartTime);
  
  WriteLn(Format('UTF-16: %.2f ms', [UTF16Time]));
  WriteLn(Format('UTF-8:  %.2f ms', [UTF8Time]));
  WriteLn(Format('Speedup: %.1fx', [UTF16Time / UTF8Time]));
end;
```

**Expected Results:**
- Speedup: 1.3x - 1.5x
- Memory: 40-60% reduction

---

## Implementation Roadmap

### Milestone 1: Tokenizer (Week 1)
- [ ] Implement `TJsonTokenizer` record
- [ ] Scan all token types
- [ ] Unit tests for tokenizer
- [ ] Error reporting with line/column

### Milestone 2: Parser (Week 2)
- [ ] Implement `TUTF8JsonParser` class
- [ ] Parse primitives (string, number, bool, null)
- [ ] Parse objects (records/classes)
- [ ] Parse arrays
- [ ] Unit tests for parser

### Milestone 3: Provider Integration (Week 3)
- [ ] Implement `TUTF8JsonProvider`
- [ ] Integrate with `TDextJson`
- [ ] Add `DeserializeUTF8` overloads
- [ ] Integration tests

### Milestone 4: Optimization & Validation (Week 4)
- [ ] Performance benchmarks
- [ ] Memory profiling
- [ ] Stress testing (large JSON files)
- [ ] Documentation updates

---

## Future Enhancements

### Streaming JSON Parser

Once the tokenizer is stable:

```pascal
type
  TJsonStreamReader = class
    function ReadNext: TJsonToken;
    property IsEOF: Boolean;
  end;
```

**Use Case**: Parse multi-GB JSON files without loading into memory.

### JSON Writer (Serialization)

```pascal
type
  TJsonUTF8Writer = record
    procedure WriteObjectStart;
    procedure WriteField(const AName: string; const AValue: TByteSpan);
    procedure WriteObjectEnd;
    function ToBytes: TBytes;
  end;
```

**Benefit**: Serialize directly to UTF-8 bytes for network transmission.

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Performance not as expected | Low | Medium | Benchmark early, iterate |
| Compatibility issues | Medium | High | Extensive testing, opt-in first |
| UTF-8 edge cases (emoji, etc) | Medium | Low | Comprehensive test suite |
| Increased code complexity | High | Low | Good documentation, clean design |

---

## Success Criteria

1. ✅ **Performance**: 30%+ faster than current parser
2. ✅ **Memory**: 40%+ reduction in allocations
3. ✅ **Compatibility**: 100% of existing tests pass
4. ✅ **Reliability**: No regressions in production
5. ✅ **Maintainability**: Code is well-documented and testable

---

## Conclusion

The UTF-8 JSON parser is a critical component of Dext's performance strategy. By eliminating UTF-8 ↔ UTF-16 transcoding and leveraging `TByteSpan` for zero-copy parsing, we can achieve significant performance gains while maintaining full backward compatibility.

This parser, combined with the HTTP lazy loading (Phase 2) and future FireDAC Phys API integration (Phase 4), will position Dext as one of the fastest web frameworks in the Delphi ecosystem.

---

**Status**: 📋 Design Phase  
**Next**: Implementation (Milestone 1 - Tokenizer)  
**Version**: Dext v1.0 (Performance Track)  
**Author**: Cesar Romero  
**Date**: 2025-12-18
