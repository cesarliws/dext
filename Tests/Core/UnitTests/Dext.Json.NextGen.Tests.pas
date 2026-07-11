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

end.
