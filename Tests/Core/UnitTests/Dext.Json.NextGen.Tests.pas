unit Dext.Json.NextGen.Tests;

interface

uses
  System.SysUtils,
  System.Classes,
  Dext.Testing.Attributes,
  Dext.Assertions,
  Dext.Core.Span,
  Dext.Json.Types,
  Dext.Core.Json.NextGen;

type
  [TestFixture('JSON NextGen Parser Tests')]
  TJsonNextGenTests = class
  public
    [Test('Should parse primitives correctly (int, double, bool, null)')]
    procedure TestParsePrimitives;

    [Test('Should parse object navigation and property lookups')]
    procedure TestParseObject;

    [Test('Should parse arrays and indexing')]
    procedure TestParseArray;

    [Test('Should reuse object pools correctly')]
    procedure TestPoolRentReturn;

    [Test('Should scan structural chars via SSE42/Pascal fallback')]
    procedure TestScanStructural;

    [Test('Should write and escape JSON correctly')]
    procedure TestWriter;

    [Test('Should raise exceptions on invalid JSON syntax')]
    procedure TestValidationExceptions;
  end;

implementation

{ TJsonNextGenTests }

procedure TJsonNextGenTests.TestParsePrimitives;
var
  Json: string;
  Bytes: TBytes;
  Node: IDextJsonNode;
  Arr: IDextJsonArray;
begin
  Json := '[123, -456.78, true, false, null]';
  Bytes := TEncoding.UTF8.GetBytes(Json);
  Node := TNextGenJsonParser.Parse(TByteSpan.FromBytes(Bytes));

  Should(Node <> nil).BeTrue;
  Should(Node.NodeType = TDextJsonNodeType.jntArray).BeTrue;

  Arr := Node as IDextJsonArray;
  Should(Arr.GetCount).Be(5);
  Should(Arr.GetInteger(0)).Be(123);
  Should(Abs(Arr.GetDouble(1) + 456.78) < 0.001).BeTrue;
  Should(Arr.GetBoolean(2)).BeTrue;
  Should(Arr.GetBoolean(3)).BeFalse;
  Should(Arr.GetNode(4).IsNull).BeTrue;
end;

procedure TJsonNextGenTests.TestParseObject;
var
  Json: string;
  Bytes: TBytes;
  Node: IDextJsonNode;
  Obj: IDextJsonObject;
begin
  Json := '{"name": "NextGen", "ver": 2, "active": true}';
  Bytes := TEncoding.UTF8.GetBytes(Json);
  Node := TNextGenJsonParser.Parse(TByteSpan.FromBytes(Bytes));

  Should(Node <> nil).BeTrue;
  Should(Node.NodeType = TDextJsonNodeType.jntObject).BeTrue;

  Obj := Node as IDextJsonObject;
  Should(Obj.Contains('name')).BeTrue;
  Should(Obj.GetString('name')).Be('NextGen');
  Should(Obj.GetInteger('ver')).Be(2);
  Should(Obj.GetBoolean('active')).BeTrue;
end;

procedure TJsonNextGenTests.TestParseArray;
var
  Json: string;
  Bytes: TBytes;
  Node: IDextJsonNode;
  Arr: IDextJsonArray;
begin
  Json := '["item1", "item2"]';
  Bytes := TEncoding.UTF8.GetBytes(Json);
  Node := TNextGenJsonParser.Parse(TByteSpan.FromBytes(Bytes));

  Should(Node <> nil).BeTrue;
  Arr := Node as IDextJsonArray;
  Should(Arr.GetString(0)).Be('item1');
  Should(Arr.GetString(1)).Be('item2');
end;

procedure TJsonNextGenTests.TestPoolRentReturn;
var
  Obj: TNextGenJsonObject;
  Arr: TNextGenJsonArray;
begin
  Obj := TNextGenJsonPool.RentObject;
  Should(Obj <> nil).BeTrue;
  TNextGenJsonPool.ReturnObject(Obj);

  Arr := TNextGenJsonPool.RentArray;
  Should(Arr <> nil).BeTrue;
  TNextGenJsonPool.ReturnArray(Arr);
end;

procedure TJsonNextGenTests.TestScanStructural;
var
  Json: string;
  Bytes: TBytes;
  Idx: Integer;
begin
  Json := '   { "test": 1 }';
  Bytes := TEncoding.UTF8.GetBytes(Json);
  Idx := TNextGenJsonParser.ScanStructural_SSE42(PByte(Bytes), Length(Bytes));
  Should(Idx >= 0).BeTrue;
  Should(Bytes[Idx]).Be(Ord('{'));
end;

procedure TJsonNextGenTests.TestWriter;
var
  Writer: TNextGenJsonWriter;
  S: string;
begin
  Writer.Init(1024);
  Writer.StartObject;
  Writer.WritePropertyName('name');
  Writer.WriteStringValue('NextGen \ " Test');
  Writer.WritePropertyName('version');
  Writer.WriteNumber(2);
  Writer.WritePropertyName('active');
  Writer.WriteBoolean(True);
  Writer.WritePropertyName('nullval');
  Writer.WriteNull;
  Writer.EndObject;

  S := Writer.ToString;
  Should(S).Be(
    '{"name":"NextGen \\ \" Test",' +
    '"version":2,"active":true,"nullval":null}'
  );
end;

procedure TJsonNextGenTests.TestValidationExceptions;
var
  Bytes: TBytes;
  Pass: Boolean;
  procedure AssertFail(const AJson: string);
  begin
    Pass := False;
    try
      Bytes := TEncoding.UTF8.GetBytes(AJson);
      TNextGenJsonParser.Parse(TByteSpan.FromBytes(Bytes));
    except
      on E: EJsonException do
        Pass := True;
    end;
    Should(Pass).BeTrue;
  end;
begin
  // fail01: \x invalid escape
  AssertFail('["\x"]');
  // fail02: Objects require colon
  AssertFail('{"a" 1}');
  // fail03: Objects require colon, not comma
  AssertFail('{"a", 1}');
  // fail04: Arrays require comma, not colon
  AssertFail('[1 : 2]');
  // fail05: Invalid literal
  AssertFail('[truth]');
  // fail06: Single quotes not allowed
  AssertFail('[''test'']');
  // fail07: Raw newline in string
  AssertFail('["line'#10'break"]');
  // fail09: Unclosed array
  AssertFail('[1, 2');
  // fail10: Numbers require exponent value
  AssertFail('[1e]');
  // fail11: Single sign allowed
  AssertFail('[+-1]');
  // fail12: Trailing comma in object
  AssertFail('{"a": 1,}');
  // fail15: Key string must be quoted
  AssertFail('{a: 1}');
  // fail16: Trailing comma in array
  AssertFail('[1, 2,]');
  // fail17: Double comma in array
  AssertFail('[1,,2]');
  // fail18: Extra trailing data
  AssertFail('{} {}');
  // fail21: Leading zeros not allowed
  AssertFail('[01]');
  // fail22: Hex numbers not allowed
  AssertFail('[0x1]');
  // fail23: Decimal needs digit before dot
  AssertFail('[.1]');
end;

end.
