{***************************************************************************}
{                                                                           }
{           Dext Framework - Collections Unit Tests                         }
{                                                                           }
{           Tests for IOrderedDictionary<K,V>, TOrderedDictionary<K,V>,     }
{           TCollections.CreateOrderedDictionary<K,V>                       }
{                                                                           }
{***************************************************************************}
unit TestCollections.OrderedDictionaries;

interface

uses
  System.SysUtils,
  Dext.Testing,
  Dext.Collections,
  Dext.Collections.Comparers,
  Dext.Collections.Dict,
  Dext.Collections.OrderedDict;

type
  TOrdDummyValue = class
  private
    FName: string;
    class var InstanceCount: Integer;
  public
    constructor Create(const AName: string);
    destructor Destroy; override;
    property Name: string read FName;
  end;

  IOrdHolder = interface
    ['{2C8E1D7A-9B04-4C6E-8F31-5A7B0C2D9E14}']
    function GetValue: Integer;
    property Value: Integer read GetValue;
  end;

  TOrdHolder = class(TInterfacedObject, IOrdHolder)
  private
    FValue: Integer;
    class var InstanceCount: Integer;
    function GetValue: Integer;
  public
    constructor Create(AValue: Integer);
    destructor Destroy; override;
  end;

  TOrdManagedRec = record
    S: string;
    I: Integer;
  end;

  /// <summary>Custom comparer: strings compared/hashed after trimming.</summary>
  TTrimStringComparer = class(TInterfacedObject, IEqualityComparer<string>)
  public
    function Equals(const Left, Right: string): Boolean; reintroduce;
    function GetHashCode(const Value: string): Integer; reintroduce;
  end;

  /// <summary>Basic ordered dictionary operations</summary>
  [TestFixture('OrderedDictionary - Basic Operations')]
  TOrderedDictBasicTests = class
  public
    [Test] procedure Add_ShouldIncreaseCount;
    [Test] procedure Lookup_ShouldReturnValue;
    [Test] procedure TryGetValue_ShouldReturnTrue_WhenKeyExists;
    [Test] procedure TryGetValue_ShouldReturnFalse_WhenKeyMissing;
    [Test] procedure ContainsKey_ShouldReflectPresence;
    [Test] procedure Remove_ShouldDecreaseCount;
    [Test] procedure Remove_Missing_ShouldReturnFalse;
    [Test] procedure Add_DuplicateKey_ShouldRaise;
    [Test] procedure Items_MissingKey_ShouldRaise;
    [Test] procedure Extract_ShouldReturnAndRemove;
    [Test] procedure IgnoreCase_ShouldMatchAnyCase;
    [Test] procedure IgnoreCase_ShouldKeepOriginalKeyCasing;
  end;

  /// <summary>Insertion-order guarantees</summary>
  [TestFixture('OrderedDictionary - Ordering')]
  TOrderedDictOrderTests = class
  public
    [Test] procedure Keys_ShouldFollowInsertionOrder;
    [Test] procedure Values_ShouldFollowInsertionOrder;
    [Test] procedure ToArray_ShouldFollowInsertionOrder;
    [Test] procedure Enumerator_ShouldFollowInsertionOrder;
    [Test] procedure KeyAt_ValueAt_ShouldReturnPositional;
    [Test] procedure IndexOf_ShouldReturnPosition;
    [Test] procedure IndexOf_Missing_ShouldReturnMinusOne;
    [Test] procedure Update_ShouldKeepPosition;
    [Test] procedure RemoveMiddle_ShouldReindexTail;
    [Test] procedure RemoveFirst_ShouldShiftAll;
    [Test] procedure RemoveLast_ShouldNotReindex;
    [Test] procedure IntegerKeys_ShouldPreserveOrder;
  end;

  /// <summary>Edge cases</summary>
  [TestFixture('OrderedDictionary - Edge Cases')]
  TOrderedDictEdgeTests = class
  public
    [Test] procedure Empty_Enumerate_NoIteration;
    [Test] procedure Empty_KeysValuesToArray_AreEmpty;
    [Test] procedure Empty_KeyAt_ShouldRaise;
    [Test] procedure KeyAt_Negative_ShouldRaise;
    [Test] procedure KeyAt_Overflow_ShouldRaise;
    [Test] procedure PairAt_ShouldReturnBoth;
    [Test] procedure Single_AllAccessors;
    [Test] procedure ReAddAfterRemove_AppendsAtEnd;
    [Test] procedure ClearThenReuse;
    [Test] procedure SetItem_InsertsWhenNew_UpdatesWhenExisting;
    [Test] procedure AddOrSetValue_NewKey_AppendsAtEnd;
    [Test] procedure RemoveAll_FromFront_LeavesEmpty;
    [Test] procedure RemoveAll_FromBack_LeavesEmpty;
  end;

  /// <summary>Value / key type behaviour (managed records, interfaces, custom comparer)</summary>
  [TestFixture('OrderedDictionary - Types')]
  TOrderedDictTypeTests = class
  public
    [Setup] procedure Setup;
    [Test] procedure ManagedRecordValues_RoundTrip;
    [Test] procedure ManagedRecordValues_UpdateAndRemove;
    [Test] procedure InterfaceValues_ReleasedOnRemoveClear;
    [Test] procedure InterfaceValues_ReleasedOnDestroy;
    [Test] procedure CustomComparer_ShouldBeUsed;
  end;

  /// <summary>Ownership of class values</summary>
  [TestFixture('OrderedDictionary - Ownership')]
  TOrderedDictOwnershipTests = class
  public
    [Setup] procedure Setup;
    [Test] procedure OwnsValues_ShouldFreeOnRemove;
    [Test] procedure OwnsValues_ShouldFreeOnClear;
    [Test] procedure OwnsValues_ShouldFreeOnOverwrite;
    [Test] procedure OwnsValues_ShouldFreeOnDestroy;
    [Test] procedure OwnsValues_Extract_ShouldNotFree;
    [Test] procedure NoOwnership_ShouldNotFreeOnClear;
  end;

  /// <summary>Larger workloads and randomized differential test</summary>
  [TestFixture('OrderedDictionary - Stress')]
  TOrderedDictStressTests = class
  public
    [Test] procedure ManyKeys_ShouldKeepOrderAndLookup;
    [Test] procedure GrowthAcrossRehash_PreservesOrder;
    [Test] procedure RemoveEveryOther_ShouldKeepSurvivorOrder;
    [Test] procedure RandomizedOperations_MatchReferenceModel;
  end;

implementation

{ TOrdDummyValue }

constructor TOrdDummyValue.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
  Inc(InstanceCount);
end;

destructor TOrdDummyValue.Destroy;
begin
  Dec(InstanceCount);
  inherited;
end;

{ TOrdHolder }

constructor TOrdHolder.Create(AValue: Integer);
begin
  inherited Create;
  FValue := AValue;
  Inc(InstanceCount);
end;

destructor TOrdHolder.Destroy;
begin
  Dec(InstanceCount);
  inherited;
end;

function TOrdHolder.GetValue: Integer;
begin
  Result := FValue;
end;

{ TTrimStringComparer }

function TTrimStringComparer.Equals(const Left, Right: string): Boolean;
begin
  Result := Trim(Left) = Trim(Right);
end;

function TTrimStringComparer.GetHashCode(const Value: string): Integer;
var
  S: string;
  I: Integer;
begin
  S := Trim(Value);
  Result := 0;
  for I := 1 to Length(S) do
    Result := (Result * 31) + Ord(S[I]);
end;

{ TOrderedDictBasicTests }

procedure TOrderedDictBasicTests.Add_ShouldIncreaseCount;
var
  D: IOrderedDictionary<Integer, Integer>;
begin
  D := TCollections.CreateOrderedDictionary<Integer, Integer>;
  Should(D.Count).Be(0);
  D.Add(1, 100);
  D.Add(2, 200);
  Should(D.Count).Be(2);
end;

procedure TOrderedDictBasicTests.Lookup_ShouldReturnValue;
var
  D: IOrderedDictionary<string, Integer>;
begin
  D := TCollections.CreateOrderedDictionary<string, Integer>;
  D.Add('a', 10);
  D.Add('b', 20);
  Should(D['a']).Be(10);
  Should(D['b']).Be(20);
end;

procedure TOrderedDictBasicTests.TryGetValue_ShouldReturnTrue_WhenKeyExists;
var
  D: IOrderedDictionary<Integer, string>;
  V: string;
begin
  D := TCollections.CreateOrderedDictionary<Integer, string>;
  D.Add(5, 'five');
  Should(D.TryGetValue(5, V)).BeTrue;
  Should(V).Be('five');
end;

procedure TOrderedDictBasicTests.TryGetValue_ShouldReturnFalse_WhenKeyMissing;
var
  D: IOrderedDictionary<Integer, string>;
  V: string;
begin
  D := TCollections.CreateOrderedDictionary<Integer, string>;
  Should(D.TryGetValue(99, V)).BeFalse;
end;

procedure TOrderedDictBasicTests.ContainsKey_ShouldReflectPresence;
var
  D: IOrderedDictionary<Integer, Integer>;
begin
  D := TCollections.CreateOrderedDictionary<Integer, Integer>;
  D.Add(5, 50);
  Should(D.ContainsKey(5)).BeTrue;
  Should(D.ContainsKey(99)).BeFalse;
end;

procedure TOrderedDictBasicTests.Remove_ShouldDecreaseCount;
var
  D: IOrderedDictionary<Integer, Integer>;
begin
  D := TCollections.CreateOrderedDictionary<Integer, Integer>;
  D.Add(1, 100);
  D.Add(2, 200);
  Should(D.Remove(1)).BeTrue;
  Should(D.Count).Be(1);
  Should(D.ContainsKey(1)).BeFalse;
end;

procedure TOrderedDictBasicTests.Remove_Missing_ShouldReturnFalse;
var
  D: IOrderedDictionary<Integer, Integer>;
begin
  D := TCollections.CreateOrderedDictionary<Integer, Integer>;
  Should(D.Remove(42)).BeFalse;
end;

procedure TOrderedDictBasicTests.Add_DuplicateKey_ShouldRaise;
var
  D: IOrderedDictionary<Integer, Integer>;
begin
  D := TCollections.CreateOrderedDictionary<Integer, Integer>;
  D.Add(1, 100);
  Should(
    procedure
    begin
      D.Add(1, 200);
    end
  ).Throw<Exception>;
end;

procedure TOrderedDictBasicTests.Items_MissingKey_ShouldRaise;
var
  D: IOrderedDictionary<Integer, Integer>;
begin
  D := TCollections.CreateOrderedDictionary<Integer, Integer>;
  Should(
    procedure
    var V: Integer;
    begin
      V := D[42];
      Should(V).Be(0);
    end
  ).Throw<Exception>;
end;

procedure TOrderedDictBasicTests.Extract_ShouldReturnAndRemove;
var
  D: IOrderedDictionary<Integer, string>;
begin
  D := TCollections.CreateOrderedDictionary<Integer, string>;
  D.Add(1, 'one');
  D.Add(2, 'two');
  Should(D.Extract(1)).Be('one');
  Should(D.Count).Be(1);
  Should(D.ContainsKey(1)).BeFalse;
end;

procedure TOrderedDictBasicTests.IgnoreCase_ShouldMatchAnyCase;
var
  D: IOrderedDictionary<string, Integer>;
begin
  D := TCollections.CreateOrderedDictionaryIgnoreCase<string, Integer>;
  D.Add('Hello', 1);
  Should(D.ContainsKey('HELLO')).BeTrue;
  Should(D['hello']).Be(1);
  D['hELLo'] := 99;
  Should(D.Count).Be(1);
  Should(D['Hello']).Be(99);
end;

procedure TOrderedDictBasicTests.IgnoreCase_ShouldKeepOriginalKeyCasing;
var
  D: IOrderedDictionary<string, Integer>;
begin
  D := TCollections.CreateOrderedDictionaryIgnoreCase<string, Integer>;
  D.Add('Hello', 1);
  D['HELLO'] := 2; // update value, must not change stored key
  Should(D.KeyAt[0]).Be('Hello');
end;

{ TOrderedDictOrderTests }

procedure TOrderedDictOrderTests.Keys_ShouldFollowInsertionOrder;
var
  D: IOrderedDictionary<string, Integer>;
  K: TArray<string>;
begin
  D := TCollections.CreateOrderedDictionary<string, Integer>;
  D.Add('zebra', 1); D.Add('apple', 2); D.Add('mango', 3);
  K := D.Keys;
  Should(K[0]).Be('zebra');
  Should(K[1]).Be('apple');
  Should(K[2]).Be('mango');
end;

procedure TOrderedDictOrderTests.Values_ShouldFollowInsertionOrder;
var
  D: IOrderedDictionary<string, Integer>;
  V: TArray<Integer>;
begin
  D := TCollections.CreateOrderedDictionary<string, Integer>;
  D.Add('zebra', 10); D.Add('apple', 20); D.Add('mango', 30);
  V := D.Values;
  Should(V[0]).Be(10);
  Should(V[1]).Be(20);
  Should(V[2]).Be(30);
end;

procedure TOrderedDictOrderTests.ToArray_ShouldFollowInsertionOrder;
var
  D: IOrderedDictionary<string, Integer>;
  A: TArray<TPair<string, Integer>>;
begin
  D := TCollections.CreateOrderedDictionary<string, Integer>;
  D.Add('b', 2); D.Add('a', 1); D.Add('c', 3);
  A := D.ToArray;
  Should(A[0].Key).Be('b');
  Should(A[1].Key).Be('a');
  Should(A[2].Key).Be('c');
  Should(A[2].Value).Be(3);
end;

procedure TOrderedDictOrderTests.Enumerator_ShouldFollowInsertionOrder;
var
  D: IOrderedDictionary<string, Integer>;
  P: TPair<string, Integer>;
  S: string;
begin
  D := TCollections.CreateOrderedDictionary<string, Integer>;
  D.Add('b', 2); D.Add('a', 1); D.Add('c', 3);
  S := '';
  for P in D do
    S := S + P.Key + IntToStr(P.Value);
  Should(S).Be('b2a1c3');
end;

procedure TOrderedDictOrderTests.KeyAt_ValueAt_ShouldReturnPositional;
var
  D: IOrderedDictionary<string, Integer>;
begin
  D := TCollections.CreateOrderedDictionary<string, Integer>;
  D.Add('x', 100); D.Add('y', 200);
  Should(D.KeyAt[0]).Be('x');
  Should(D.KeyAt[1]).Be('y');
  Should(D.ValueAt[0]).Be(100);
  Should(D.ValueAt[1]).Be(200);
end;

procedure TOrderedDictOrderTests.IndexOf_ShouldReturnPosition;
var
  D: IOrderedDictionary<string, Integer>;
begin
  D := TCollections.CreateOrderedDictionary<string, Integer>;
  D.Add('x', 1); D.Add('y', 2); D.Add('z', 3);
  Should(D.IndexOf('x')).Be(0);
  Should(D.IndexOf('z')).Be(2);
end;

procedure TOrderedDictOrderTests.IndexOf_Missing_ShouldReturnMinusOne;
var
  D: IOrderedDictionary<string, Integer>;
begin
  D := TCollections.CreateOrderedDictionary<string, Integer>;
  D.Add('x', 1);
  Should(D.IndexOf('nope')).Be(-1);
end;

procedure TOrderedDictOrderTests.Update_ShouldKeepPosition;
var
  D: IOrderedDictionary<string, Integer>;
begin
  D := TCollections.CreateOrderedDictionary<string, Integer>;
  D.Add('a', 1); D.Add('b', 2); D.Add('c', 3);
  D['b'] := 20;
  D.AddOrSetValue('a', 10);
  Should(D.Count).Be(3);
  Should(D['b']).Be(20);
  Should(D.KeyAt[0]).Be('a');
  Should(D.KeyAt[1]).Be('b');
  Should(D.KeyAt[2]).Be('c');
end;

procedure TOrderedDictOrderTests.RemoveMiddle_ShouldReindexTail;
var
  D: IOrderedDictionary<string, Integer>;
begin
  D := TCollections.CreateOrderedDictionary<string, Integer>;
  D.Add('a', 1); D.Add('b', 2); D.Add('c', 3); D.Add('d', 4); D.Add('e', 5);
  Should(D.Remove('c')).BeTrue;
  Should(D.Count).Be(4);
  Should(D.KeyAt[2]).Be('d');
  Should(D.KeyAt[3]).Be('e');
  Should(D.IndexOf('d')).Be(2);
  Should(D.IndexOf('e')).Be(3);
  Should(D['d']).Be(4);
  Should(D['e']).Be(5);
end;

procedure TOrderedDictOrderTests.RemoveFirst_ShouldShiftAll;
var
  D: IOrderedDictionary<string, Integer>;
begin
  D := TCollections.CreateOrderedDictionary<string, Integer>;
  D.Add('a', 1); D.Add('b', 2); D.Add('c', 3);
  Should(D.Remove('a')).BeTrue;
  Should(D.KeyAt[0]).Be('b');
  Should(D.KeyAt[1]).Be('c');
  Should(D.IndexOf('b')).Be(0);
  Should(D.IndexOf('c')).Be(1);
end;

procedure TOrderedDictOrderTests.RemoveLast_ShouldNotReindex;
var
  D: IOrderedDictionary<string, Integer>;
begin
  D := TCollections.CreateOrderedDictionary<string, Integer>;
  D.Add('a', 1); D.Add('b', 2); D.Add('c', 3);
  Should(D.Remove('c')).BeTrue;
  Should(D.Count).Be(2);
  Should(D.KeyAt[0]).Be('a');
  Should(D.KeyAt[1]).Be('b');
  Should(D.IndexOf('a')).Be(0);
  Should(D.IndexOf('b')).Be(1);
end;

procedure TOrderedDictOrderTests.IntegerKeys_ShouldPreserveOrder;
var
  D: IOrderedDictionary<Integer, string>;
begin
  D := TCollections.CreateOrderedDictionary<Integer, string>;
  D.Add(100, 'a'); D.Add(5, 'b'); D.Add(42, 'c');
  Should(D.KeyAt[0]).Be(100);
  Should(D.KeyAt[1]).Be(5);
  Should(D.KeyAt[2]).Be(42);
end;

{ TOrderedDictEdgeTests }

procedure TOrderedDictEdgeTests.Empty_Enumerate_NoIteration;
var
  D: IOrderedDictionary<Integer, Integer>;
  P: TPair<Integer, Integer>;
  N: Integer;
begin
  D := TCollections.CreateOrderedDictionary<Integer, Integer>;
  N := 0;
  for P in D do
    Inc(N);
  Should(N).Be(0);
end;

procedure TOrderedDictEdgeTests.Empty_KeysValuesToArray_AreEmpty;
var
  D: IOrderedDictionary<Integer, Integer>;
begin
  D := TCollections.CreateOrderedDictionary<Integer, Integer>;
  Should(Length(D.Keys)).Be(0);
  Should(Length(D.Values)).Be(0);
  Should(Length(D.ToArray)).Be(0);
end;

procedure TOrderedDictEdgeTests.Empty_KeyAt_ShouldRaise;
var
  D: IOrderedDictionary<Integer, Integer>;
begin
  D := TCollections.CreateOrderedDictionary<Integer, Integer>;
  Should(
    procedure
    begin
      D.KeyAt[0];
    end
  ).Throw<Exception>;
end;

procedure TOrderedDictEdgeTests.KeyAt_Negative_ShouldRaise;
var
  D: IOrderedDictionary<Integer, Integer>;
begin
  D := TCollections.CreateOrderedDictionary<Integer, Integer>;
  D.Add(1, 1);
  Should(
    procedure
    begin
      D.KeyAt[-1];
    end
  ).Throw<Exception>;
end;

procedure TOrderedDictEdgeTests.KeyAt_Overflow_ShouldRaise;
var
  D: IOrderedDictionary<Integer, Integer>;
begin
  D := TCollections.CreateOrderedDictionary<Integer, Integer>;
  D.Add(1, 1);
  Should(
    procedure
    begin
      D.KeyAt[1];
    end
  ).Throw<Exception>;
end;

procedure TOrderedDictEdgeTests.PairAt_ShouldReturnBoth;
var
  D: IOrderedDictionary<string, Integer>;
  P: TPair<string, Integer>;
begin
  D := TCollections.CreateOrderedDictionary<string, Integer>;
  D.Add('k', 7);
  P := D.PairAt(0);
  Should(P.Key).Be('k');
  Should(P.Value).Be(7);
end;

procedure TOrderedDictEdgeTests.Single_AllAccessors;
var
  D: IOrderedDictionary<string, Integer>;
begin
  D := TCollections.CreateOrderedDictionary<string, Integer>;
  D.Add('only', 42);
  Should(D.Count).Be(1);
  Should(D['only']).Be(42);
  Should(D.KeyAt[0]).Be('only');
  Should(D.ValueAt[0]).Be(42);
  Should(D.IndexOf('only')).Be(0);
  Should(D.Keys[0]).Be('only');
  Should(D.Values[0]).Be(42);
end;

procedure TOrderedDictEdgeTests.ReAddAfterRemove_AppendsAtEnd;
var
  D: IOrderedDictionary<string, Integer>;
begin
  D := TCollections.CreateOrderedDictionary<string, Integer>;
  D.Add('a', 1); D.Add('b', 2); D.Add('c', 3);
  D.Remove('a');            // b,c
  D.Add('a', 10);           // b,c,a
  Should(D.KeyAt[0]).Be('b');
  Should(D.KeyAt[1]).Be('c');
  Should(D.KeyAt[2]).Be('a');
  Should(D['a']).Be(10);
  Should(D.IndexOf('a')).Be(2);
end;

procedure TOrderedDictEdgeTests.ClearThenReuse;
var
  D: IOrderedDictionary<string, Integer>;
begin
  D := TCollections.CreateOrderedDictionary<string, Integer>;
  D.Add('a', 1); D.Add('b', 2);
  D.Clear;
  Should(D.Count).Be(0);
  Should(D.ContainsKey('a')).BeFalse;
  D.Add('x', 9);
  Should(D.Count).Be(1);
  Should(D.KeyAt[0]).Be('x');
  Should(D['x']).Be(9);
end;

procedure TOrderedDictEdgeTests.SetItem_InsertsWhenNew_UpdatesWhenExisting;
var
  D: IOrderedDictionary<string, Integer>;
begin
  D := TCollections.CreateOrderedDictionary<string, Integer>;
  D['a'] := 1;   // insert
  D['b'] := 2;   // insert
  D['a'] := 10;  // update in place
  Should(D.Count).Be(2);
  Should(D.KeyAt[0]).Be('a');
  Should(D.KeyAt[1]).Be('b');
  Should(D['a']).Be(10);
end;

procedure TOrderedDictEdgeTests.AddOrSetValue_NewKey_AppendsAtEnd;
var
  D: IOrderedDictionary<string, Integer>;
begin
  D := TCollections.CreateOrderedDictionary<string, Integer>;
  D.Add('a', 1);
  D.AddOrSetValue('b', 2);
  D.AddOrSetValue('c', 3);
  Should(D.KeyAt[1]).Be('b');
  Should(D.KeyAt[2]).Be('c');
end;

procedure TOrderedDictEdgeTests.RemoveAll_FromFront_LeavesEmpty;
var
  D: IOrderedDictionary<Integer, Integer>;
  I: Integer;
begin
  D := TCollections.CreateOrderedDictionary<Integer, Integer>;
  for I := 0 to 9 do D.Add(I, I * 10);
  for I := 0 to 9 do
    Should(D.Remove(I)).BeTrue; // always removes current front
  Should(D.Count).Be(0);
end;

procedure TOrderedDictEdgeTests.RemoveAll_FromBack_LeavesEmpty;
var
  D: IOrderedDictionary<Integer, Integer>;
  I: Integer;
begin
  D := TCollections.CreateOrderedDictionary<Integer, Integer>;
  for I := 0 to 9 do D.Add(I, I * 10);
  for I := 9 downto 0 do
    Should(D.Remove(I)).BeTrue; // always removes current back
  Should(D.Count).Be(0);
end;

{ TOrderedDictTypeTests }

procedure TOrderedDictTypeTests.Setup;
begin
  TOrdHolder.InstanceCount := 0;
end;

procedure TOrderedDictTypeTests.ManagedRecordValues_RoundTrip;
var
  D: IOrderedDictionary<Integer, TOrdManagedRec>;
  R: TOrdManagedRec;
begin
  D := TCollections.CreateOrderedDictionary<Integer, TOrdManagedRec>;
  R.S := 'first-long-string-value'; R.I := 1; D.Add(10, R);
  R.S := 'second-long-string-value'; R.I := 2; D.Add(20, R);
  Should(D[10].S).Be('first-long-string-value');
  Should(D[20].I).Be(2);
  Should(D.ValueAt[0].S).Be('first-long-string-value');
  Should(D.KeyAt[1]).Be(20);
end;

procedure TOrderedDictTypeTests.ManagedRecordValues_UpdateAndRemove;
var
  D: IOrderedDictionary<Integer, TOrdManagedRec>;
  R: TOrdManagedRec;
begin
  D := TCollections.CreateOrderedDictionary<Integer, TOrdManagedRec>;
  R.S := 'aaaaaaaaaaaaaaaaaaaa'; R.I := 1; D.Add(1, R);
  R.S := 'bbbbbbbbbbbbbbbbbbbb'; R.I := 2; D.AddOrSetValue(1, R); // replace managed value
  Should(D[1].S).Be('bbbbbbbbbbbbbbbbbbbb');
  D.Remove(1);
  Should(D.Count).Be(0);
end;

procedure TOrderedDictTypeTests.InterfaceValues_ReleasedOnRemoveClear;
var
  D: IOrderedDictionary<Integer, IOrdHolder>;
begin
  D := TCollections.CreateOrderedDictionary<Integer, IOrdHolder>;
  D.Add(1, TOrdHolder.Create(10));
  D.Add(2, TOrdHolder.Create(20));
  Should(TOrdHolder.InstanceCount).Be(2);
  D.Remove(1);
  Should(TOrdHolder.InstanceCount).Be(1);
  D.Clear;
  Should(TOrdHolder.InstanceCount).Be(0);
end;

procedure TOrderedDictTypeTests.InterfaceValues_ReleasedOnDestroy;
var
  D: IOrderedDictionary<Integer, IOrdHolder>;
begin
  D := TCollections.CreateOrderedDictionary<Integer, IOrdHolder>;
  D.Add(1, TOrdHolder.Create(10));
  D.Add(2, TOrdHolder.Create(20));
  Should(TOrdHolder.InstanceCount).Be(2);
  D := nil; // release container -> stored interface refs released
  Should(TOrdHolder.InstanceCount).Be(0);
end;

procedure TOrderedDictTypeTests.CustomComparer_ShouldBeUsed;
var
  D: IOrderedDictionary<string, Integer>;
begin
  D := TOrderedDictionary<string, Integer>.Create(
    TTrimStringComparer.Create as IEqualityComparer<string>);
  D.Add('  key  ', 1);
  Should(D.ContainsKey('key')).BeTrue;   // matched after trim
  Should(D['key']).Be(1);
  D.AddOrSetValue('key', 2);             // same logical key
  Should(D.Count).Be(1);
  Should(D['   key']).Be(2);
end;

{ TOrderedDictOwnershipTests }

procedure TOrderedDictOwnershipTests.Setup;
begin
  TOrdDummyValue.InstanceCount := 0;
end;

procedure TOrderedDictOwnershipTests.OwnsValues_ShouldFreeOnRemove;
var
  D: IOrderedDictionary<Integer, TOrdDummyValue>;
begin
  D := TCollections.CreateOrderedDictionary<Integer, TOrdDummyValue>(True);
  D.Add(1, TOrdDummyValue.Create('A'));
  Should(TOrdDummyValue.InstanceCount).Be(1);
  D.Remove(1);
  Should(TOrdDummyValue.InstanceCount).Be(0);
end;

procedure TOrderedDictOwnershipTests.OwnsValues_ShouldFreeOnClear;
var
  D: IOrderedDictionary<Integer, TOrdDummyValue>;
begin
  D := TCollections.CreateOrderedDictionary<Integer, TOrdDummyValue>(True);
  D.Add(1, TOrdDummyValue.Create('A'));
  D.Add(2, TOrdDummyValue.Create('B'));
  D.Add(3, TOrdDummyValue.Create('C'));
  Should(TOrdDummyValue.InstanceCount).Be(3);
  D.Clear;
  Should(TOrdDummyValue.InstanceCount).Be(0);
end;

procedure TOrderedDictOwnershipTests.OwnsValues_ShouldFreeOnOverwrite;
var
  D: IOrderedDictionary<Integer, TOrdDummyValue>;
begin
  D := TCollections.CreateOrderedDictionary<Integer, TOrdDummyValue>(True);
  D.Add(1, TOrdDummyValue.Create('Old'));
  Should(TOrdDummyValue.InstanceCount).Be(1);
  D.AddOrSetValue(1, TOrdDummyValue.Create('New'));
  Should(TOrdDummyValue.InstanceCount).Be(1);
  Should(D[1].Name).Be('New');
end;

procedure TOrderedDictOwnershipTests.OwnsValues_ShouldFreeOnDestroy;
var
  D: IOrderedDictionary<Integer, TOrdDummyValue>;
begin
  D := TCollections.CreateOrderedDictionary<Integer, TOrdDummyValue>(True);
  D.Add(1, TOrdDummyValue.Create('A'));
  D.Add(2, TOrdDummyValue.Create('B'));
  Should(TOrdDummyValue.InstanceCount).Be(2);
  D := nil;
  Should(TOrdDummyValue.InstanceCount).Be(0);
end;

procedure TOrderedDictOwnershipTests.OwnsValues_Extract_ShouldNotFree;
var
  D: IOrderedDictionary<Integer, TOrdDummyValue>;
  Obj: TOrdDummyValue;
begin
  D := TCollections.CreateOrderedDictionary<Integer, TOrdDummyValue>(True);
  D.Add(1, TOrdDummyValue.Create('A'));
  Obj := D.Extract(1);           // ownership handed out, must NOT free
  Should(TOrdDummyValue.InstanceCount).Be(1);
  Should(Obj.Name).Be('A');
  Obj.Free;
  Should(TOrdDummyValue.InstanceCount).Be(0);
end;

procedure TOrderedDictOwnershipTests.NoOwnership_ShouldNotFreeOnClear;
var
  D: IOrderedDictionary<Integer, TOrdDummyValue>;
  Obj: TOrdDummyValue;
begin
  D := TCollections.CreateOrderedDictionary<Integer, TOrdDummyValue>(False);
  Obj := TOrdDummyValue.Create('A');
  D.Add(1, Obj);
  D.Clear;
  Should(TOrdDummyValue.InstanceCount).Be(1);
  Obj.Free;
  Should(TOrdDummyValue.InstanceCount).Be(0);
end;

{ TOrderedDictStressTests }

procedure TOrderedDictStressTests.ManyKeys_ShouldKeepOrderAndLookup;
var
  D: IOrderedDictionary<Integer, Integer>;
  I: Integer;
  Ok: Boolean;
begin
  D := TCollections.CreateOrderedDictionary<Integer, Integer>;
  for I := 0 to 4999 do
    D.Add(I * 7, I);
  Should(D.Count).Be(5000);
  Ok := True;
  for I := 0 to 4999 do
  begin
    if D.KeyAt[I] <> I * 7 then Ok := False;
    if D[I * 7] <> I then Ok := False;
  end;
  Should(Ok).BeTrue;
end;

procedure TOrderedDictStressTests.GrowthAcrossRehash_PreservesOrder;
var
  D: IOrderedDictionary<Integer, Integer>;
  I: Integer;
  Ok: Boolean;
begin
  // Start tiny so the backend index rehashes many times while we add.
  D := TCollections.CreateOrderedDictionary<Integer, Integer>(0);
  for I := 0 to 2999 do
    D.AddOrSetValue(I, I + 1);
  Ok := True;
  for I := 0 to 2999 do
  begin
    if D.KeyAt[I] <> I then Ok := False;
    if D.IndexOf(I) <> I then Ok := False;
    if D[I] <> I + 1 then Ok := False;
  end;
  Should(Ok).BeTrue;
end;

procedure TOrderedDictStressTests.RemoveEveryOther_ShouldKeepSurvivorOrder;
var
  D: IOrderedDictionary<Integer, Integer>;
  I: Integer;
  Ok: Boolean;
  Expected: Integer;
begin
  D := TCollections.CreateOrderedDictionary<Integer, Integer>;
  for I := 0 to 999 do
    D.Add(I, I);
  for I := 0 to 999 do
    if Odd(I) then
      D.Remove(I);
  Should(D.Count).Be(500);
  Ok := True;
  for I := 0 to 499 do
  begin
    Expected := I * 2;
    if D.KeyAt[I] <> Expected then Ok := False;
    if D.IndexOf(Expected) <> I then Ok := False;
  end;
  Should(Ok).BeTrue;
end;

procedure TOrderedDictStressTests.RandomizedOperations_MatchReferenceModel;
const
  DOMAIN = 60;
  ITERATIONS = 8000;
var
  D: IOrderedDictionary<Integer, Integer>;
  ModelKeys, ModelVals: TArray<Integer>;
  Iter, K, V, Op, Pos, I: Integer;
  Mismatch: Boolean;

  function ModelIndexOf(AKey: Integer): Integer;
  var J: Integer;
  begin
    for J := 0 to High(ModelKeys) do
      if ModelKeys[J] = AKey then Exit(J);
    Result := -1;
  end;

  procedure ModelDelete(AIdx: Integer);
  var J: Integer;
  begin
    for J := AIdx to High(ModelKeys) - 1 do
    begin
      ModelKeys[J] := ModelKeys[J + 1];
      ModelVals[J] := ModelVals[J + 1];
    end;
    SetLength(ModelKeys, Length(ModelKeys) - 1);
    SetLength(ModelVals, Length(ModelVals) - 1);
  end;

begin
  RandSeed := 20260721; // deterministic
  D := TCollections.CreateOrderedDictionary<Integer, Integer>;
  SetLength(ModelKeys, 0);
  SetLength(ModelVals, 0);

  for Iter := 0 to ITERATIONS - 1 do
  begin
    K := Random(DOMAIN);
    V := Random(1000000);
    Op := Random(10);
    Pos := ModelIndexOf(K);

    if Op < 6 then
    begin
      // add-or-set
      D.AddOrSetValue(K, V);
      if Pos >= 0 then
        ModelVals[Pos] := V
      else
      begin
        SetLength(ModelKeys, Length(ModelKeys) + 1);
        SetLength(ModelVals, Length(ModelVals) + 1);
        ModelKeys[High(ModelKeys)] := K;
        ModelVals[High(ModelVals)] := V;
      end;
    end
    else if Op < 9 then
    begin
      // remove
      D.Remove(K);
      if Pos >= 0 then
        ModelDelete(Pos);
    end;
    // Op = 9: pure lookup, no mutation

    // membership check every iteration (cheap)
    if (D.ContainsKey(K)) <> (ModelIndexOf(K) >= 0) then
    begin
      Should(False).BeTrue; // fail with context
      Exit;
    end;
  end;

  // Final full equivalence check
  Should(D.Count).Be(Length(ModelKeys));
  Mismatch := False;
  for I := 0 to High(ModelKeys) do
  begin
    if D.KeyAt[I] <> ModelKeys[I] then Mismatch := True;
    if D.ValueAt[I] <> ModelVals[I] then Mismatch := True;
    if D.IndexOf(ModelKeys[I]) <> I then Mismatch := True;
    if D[ModelKeys[I]] <> ModelVals[I] then Mismatch := True;
  end;
  Should(Mismatch).BeFalse;
end;

end.
