{***************************************************************************}
{                                                                           }
{           Dext Framework - Collections Unit Tests                         }
{                                                                           }
{           Tests for IDictionary<K,V>, TDictionary<K,V>,           }
{           TCollections.CreateDictionary<K,V>                              }
{                                                                           }
{***************************************************************************}
unit TestCollections.Dictionaries;

interface

uses
  System.SysUtils,
  Dext.Testing,
  Dext.Collections,
  Dext.Collections.Dict;

type
  TDummyValue = class
  private
    FName: string;
    class var InstanceCount: Integer;
  public
    constructor Create(const AName: string);
    destructor Destroy; override;
    property Name: string read FName;
  end;

  IValueHolder = interface
    ['{B1A2C3D4-E5F6-7890-ABCD-EF1234567890}']
    function GetValue: Integer;
    property Value: Integer read GetValue;
  end;

  TValueHolder = class(TInterfacedObject, IValueHolder)
  private
    FValue: Integer;
    function GetValue: Integer;
  public
    constructor Create(AValue: Integer);
  end;

  TManagedRecord = record
    S: string;
    I: Integer;
  end;

  /// <summary>Basic dictionary operations with Integer keys</summary>
  [TestFixture('Dictionary - Basic Operations')]
  TDictionaryBasicTests = class
  public
    [Test]
    procedure Add_ShouldIncreaseCount;

    [Test]
    procedure TryGetValue_ShouldReturnTrue_WhenKeyExists;

    [Test]
    procedure TryGetValue_ShouldReturnFalse_WhenKeyMissing;

    [Test]
    procedure ContainsKey_ShouldReturnTrue_WhenExists;

    [Test]
    procedure ContainsKey_ShouldReturnFalse_WhenMissing;

    [Test]
    procedure Remove_ShouldDecreaseCount;

    [Test]
    procedure Remove_ShouldReturnFalse_WhenMissing;

    [Test]
    procedure Clear_ShouldResetCount;

    [Test]
    procedure Items_ShouldReadAndWrite;

    [Test]
    procedure AddOrSetValue_ShouldUpdateExisting;

    [Test]
    procedure Add_DuplicateKey_ShouldRaise;

    [Test]
    procedure Items_MissingKey_ShouldRaise;

    [Test]
    procedure Keys_ShouldReturnAllKeys;

    [Test]
    procedure Values_ShouldReturnAllValues;

    [Test]
    procedure ToArray_ShouldReturnAllPairs;
  end;

  /// <summary>Dictionary with string keys (managed type, FNV hash)</summary>
  [TestFixture('Dictionary - String Keys')]
  TDictionaryStringKeyTests = class
  public
    [Test]
    procedure Add_StringKeyShouldWork;

    [Test]
    procedure TryGetValue_StringKeyShouldWork;

    [Test]
    procedure Remove_StringKeyShouldWork;

    [Test]
    procedure ContainsKey_StringKeyShouldWork;

    [Test]
    procedure LargeStringKeys_ShouldNotCollide;

    [Test]
    procedure EmptyStringKey_ShouldWork;
  end;

  /// <summary>Dictionary with OwnsValues for object cleanup</summary>
  [TestFixture('Dictionary - Ownership')]
  TDictionaryOwnershipTests = class
  public
    [Setup]
    procedure Setup;

    [Test]
    procedure OwnsValues_ShouldFreeOnRemove;

    [Test]
    procedure OwnsValues_ShouldFreeOnClear;

    [Test]
    procedure OwnsValues_ShouldFreeOnOverwrite;

    [Test]
    procedure NoOwnership_ShouldNotFreeOnClear;
  end;

  /// <summary>Stress tests: large insert, rehashing, collisions</summary>
  [TestFixture('Dictionary - Stress')]
  TDictionaryStressTests = class
  public
    [Test]
    procedure Insert1000_ShouldWork;

    [Test]
    procedure InsertAndRemoveAll_ShouldBeEmpty;

    [Test]
    procedure Rehash_ShouldPreserveAllEntries;

    /// <summary>
    ///   Regression: a plain add/remove/add cycle used to saturate the table with
    ///   occupied+tombstone slots (tombstones were not counted by the load factor,
    ///   so the rehash that clears them never happened). FindSlot only stops on
    ///   SLOT_EMPTY, so the next lookup for an absent key never returned.
    /// </summary>
    [Test]
    procedure AddRemoveAdd_LookupOfRemovedKey_ShouldNotHang;

    /// <summary>
    ///   Regression: a long-lived dictionary under a remove/insert cycle must stay
    ///   correct -- tombstones must not accumulate until the table is exhausted.
    /// </summary>
    [Test]
    procedure LongAddRemoveCycle_ShouldStayConsistent;
  end;

  /// <summary>TCollections factory method tests</summary>
  [TestFixture('Collections - Factory')]
  TCollectionsFactoryTests = class
  public
    [Test]
    procedure CreateList_ShouldReturnEmptyList;

    [Test]
    procedure CreateObjectList_ShouldOwnObjects;

    [Test]
    procedure CreateDictionary_ShouldReturnEmptyDict;

    [Test]
    procedure CreateDictionary_WithOwnership_ShouldWork;
  end;

  /// <summary>Dictionary - Enumerator (for..in)</summary>
  [TestFixture('Dictionary - Enumerator')]
  TDictionaryEnumeratorTests = class
  public
    [Test]
    procedure ForIn_ShouldIterateAllPairs;

    [Test]
    procedure ForIn_EmptyDictionary_ShouldNotIterate;
  end;

  /// <summary>Dictionary with Interface keys and values</summary>
  [TestFixture('Dictionary - Interface Elements')]
  TDictionaryInterfaceTests = class
  public
    [Test]
    procedure InterfaceValues_ShouldBeRefCounted;

    [Test]
    procedure InterfaceKeys_ShouldWork;
  end;

  /// <summary>Dictionary with managed records</summary>
  [TestFixture('Dictionary - Managed Records')]
  TDictionaryManagedRecordTests = class
  public
    [Test]
    procedure ManagedRecord_ShouldWork;
  end;

  /// <summary>
  ///   Floating-point keys: Equals compares by VALUE, so GetHashCode must
  ///   agree. +0.0 and -0.0 are numerically equal with different bit patterns;
  ///   hashing raw bytes would break the Equals/GetHashCode contract and the
  ///   dictionary would silently lose the key.
  /// </summary>
  [TestFixture('Dictionary - Float Keys')]
  TDictionaryFloatKeyTests = class
  public
    [Test]
    procedure NegativeZero_ShouldFindTheSameKey;

    [Test]
    procedure NegativeZero_ShouldNotAddASecondKey;

    [Test]
    procedure SingleKey_NegativeZero_ShouldFindTheSameKey;

    [Test]
    procedure Currency_ShouldStillWork;

    [Test]
    procedure NonZeroFloats_ShouldStillWork;
  end;

implementation

{ TDummyValue }

constructor TDummyValue.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
  Inc(InstanceCount);
end;

destructor TDummyValue.Destroy;
begin
  Dec(InstanceCount);
  inherited;
end;

{ TValueHolder }

constructor TValueHolder.Create(AValue: Integer);
begin
  inherited Create;
  FValue := AValue;
end;

function TValueHolder.GetValue: Integer;
begin
  Result := FValue;
end;

{ TDictionaryBasicTests }

procedure TDictionaryBasicTests.Add_ShouldIncreaseCount;
var
  D: IDictionary<Integer, Integer>;
begin
  D := TCollections.CreateDictionary<Integer, Integer>;
  Should(D.Count).Be(0);
  D.Add(1, 100);
  Should(D.Count).Be(1);
  D.Add(2, 200);
  Should(D.Count).Be(2);
end;

procedure TDictionaryBasicTests.TryGetValue_ShouldReturnTrue_WhenKeyExists;
var
  D: IDictionary<Integer, Integer>;
  V: Integer;
begin
  D := TCollections.CreateDictionary<Integer, Integer>;
  D.Add(42, 999);
  Should(D.TryGetValue(42, V)).BeTrue;
  Should(V).Be(999);
end;

procedure TDictionaryBasicTests.TryGetValue_ShouldReturnFalse_WhenKeyMissing;
var
  D: IDictionary<Integer, Integer>;
  V: Integer;
begin
  D := TCollections.CreateDictionary<Integer, Integer>;
  D.Add(1, 100);
  Should(D.TryGetValue(99, V)).BeFalse;
end;

procedure TDictionaryBasicTests.ContainsKey_ShouldReturnTrue_WhenExists;
var
  D: IDictionary<Integer, Integer>;
begin
  D := TCollections.CreateDictionary<Integer, Integer>;
  D.Add(5, 50);
  Should(D.ContainsKey(5)).BeTrue;
end;

procedure TDictionaryBasicTests.ContainsKey_ShouldReturnFalse_WhenMissing;
var
  D: IDictionary<Integer, Integer>;
begin
  D := TCollections.CreateDictionary<Integer, Integer>;
  D.Add(5, 50);
  Should(D.ContainsKey(99)).BeFalse;
end;

procedure TDictionaryBasicTests.Remove_ShouldDecreaseCount;
var
  D: IDictionary<Integer, Integer>;
begin
  D := TCollections.CreateDictionary<Integer, Integer>;
  D.Add(1, 10);
  D.Add(2, 20);
  Should(D.Remove(1)).BeTrue;
  Should(D.Count).Be(1);
  Should(D.ContainsKey(1)).BeFalse;
end;

procedure TDictionaryBasicTests.Remove_ShouldReturnFalse_WhenMissing;
var
  D: IDictionary<Integer, Integer>;
begin
  D := TCollections.CreateDictionary<Integer, Integer>;
  Should(D.Remove(42)).BeFalse;
end;

procedure TDictionaryBasicTests.Clear_ShouldResetCount;
var
  D: IDictionary<Integer, Integer>;
begin
  D := TCollections.CreateDictionary<Integer, Integer>;
  D.Add(1, 10);
  D.Add(2, 20);
  D.Add(3, 30);
  D.Clear;
  Should(D.Count).Be(0);
end;

procedure TDictionaryBasicTests.Items_ShouldReadAndWrite;
var
  D: IDictionary<Integer, Integer>;
begin
  D := TCollections.CreateDictionary<Integer, Integer>;
  D.Add(1, 100);
  Should(D[1]).Be(100);
  D[1] := 999;
  Should(D[1]).Be(999);
end;

procedure TDictionaryBasicTests.AddOrSetValue_ShouldUpdateExisting;
var
  D: IDictionary<Integer, Integer>;
begin
  D := TCollections.CreateDictionary<Integer, Integer>;
  D.AddOrSetValue(1, 100);
  D.AddOrSetValue(1, 200);
  Should(D.Count).Be(1);
  Should(D[1]).Be(200);
end;

procedure TDictionaryBasicTests.Add_DuplicateKey_ShouldRaise;
var
  D: IDictionary<Integer, Integer>;
begin
  D := TCollections.CreateDictionary<Integer, Integer>;
  D.Add(1, 100);
  Should(
    procedure
    begin
      D.Add(1, 200);
    end
  ).Throw<Exception>;
end;

procedure TDictionaryBasicTests.Items_MissingKey_ShouldRaise;
var
  D: IDictionary<Integer, Integer>;
begin
  D := TCollections.CreateDictionary<Integer, Integer>;
  Should(
    procedure
    var V: Integer;
    begin
      V := D[42];
      Should(V).Be(0); // never executed, exception raised before
    end
  ).Throw<Exception>;
end;

procedure TDictionaryBasicTests.Keys_ShouldReturnAllKeys;
var
  D: IDictionary<Integer, string>;
  K: TArray<Integer>;
begin
  D := TCollections.CreateDictionary<Integer, string>;
  D.Add(1, 'A');
  D.Add(2, 'B');
  D.Add(3, 'C');
  K := D.Keys;
  Should(Length(K)).Be(3);
end;

procedure TDictionaryBasicTests.Values_ShouldReturnAllValues;
var
  D: IDictionary<Integer, string>;
  V: TArray<string>;
begin
  D := TCollections.CreateDictionary<Integer, string>;
  D.Add(1, 'A');
  D.Add(2, 'B');
  V := D.Values;
  Should(Length(V)).Be(2);
end;

procedure TDictionaryBasicTests.ToArray_ShouldReturnAllPairs;
var
  D: IDictionary<Integer, string>;
  Pairs: TArray<TPair<Integer, string>>;
begin
  D := TCollections.CreateDictionary<Integer, string>;
  D.Add(1, 'X');
  D.Add(2, 'Y');
  Pairs := D.ToArray;
  Should(Length(Pairs)).Be(2);
end;

{ TDictionaryStringKeyTests }

procedure TDictionaryStringKeyTests.Add_StringKeyShouldWork;
var
  D: IDictionary<string, Integer>;
begin
  D := TCollections.CreateDictionary<string, Integer>;
  D.Add('hello', 1);
  D.Add('world', 2);
  Should(D.Count).Be(2);
  Should(D['hello']).Be(1);
  Should(D['world']).Be(2);
end;

procedure TDictionaryStringKeyTests.TryGetValue_StringKeyShouldWork;
var
  D: IDictionary<string, Integer>;
  V: Integer;
begin
  D := TCollections.CreateDictionary<string, Integer>;
  D.Add('key1', 42);
  Should(D.TryGetValue('key1', V)).BeTrue;
  Should(V).Be(42);
  Should(D.TryGetValue('missing', V)).BeFalse;
end;

procedure TDictionaryStringKeyTests.Remove_StringKeyShouldWork;
var
  D: IDictionary<string, Integer>;
begin
  D := TCollections.CreateDictionary<string, Integer>;
  D.Add('remove-me', 1);
  Should(D.Remove('remove-me')).BeTrue;
  Should(D.Count).Be(0);
end;

procedure TDictionaryStringKeyTests.ContainsKey_StringKeyShouldWork;
var
  D: IDictionary<string, Integer>;
begin
  D := TCollections.CreateDictionary<string, Integer>;
  D.Add('exists', 1);
  Should(D.ContainsKey('exists')).BeTrue;
  Should(D.ContainsKey('nope')).BeFalse;
end;

procedure TDictionaryStringKeyTests.LargeStringKeys_ShouldNotCollide;
var
  D: IDictionary<string, Integer>;
  I: Integer;
  Key: string;
begin
  D := TCollections.CreateDictionary<string, Integer>;
  // Insert 100 keys with similar prefixes
  for I := 0 to 99 do
  begin
    Key := 'key_prefix_' + IntToStr(I);
    D.Add(Key, I);
  end;
  Should(D.Count).Be(100);

  // Verify all retrievable
  for I := 0 to 99 do
  begin
    Key := 'key_prefix_' + IntToStr(I);
    Should(D[Key]).Be(I);
  end;
end;

procedure TDictionaryStringKeyTests.EmptyStringKey_ShouldWork;
var
  D: IDictionary<string, Integer>;
begin
  D := TCollections.CreateDictionary<string, Integer>;
  D.Add('', 42);
  Should(D['']).Be(42);
  Should(D.ContainsKey('')).BeTrue;
end;

{ TDictionaryOwnershipTests }

procedure TDictionaryOwnershipTests.Setup;
begin
  TDummyValue.InstanceCount := 0;
end;

procedure TDictionaryOwnershipTests.OwnsValues_ShouldFreeOnRemove;
var
  D: IDictionary<Integer, TDummyValue>;
begin
  D := TCollections.CreateDictionary<Integer, TDummyValue>(True);
  D.Add(1, TDummyValue.Create('A'));
  Should(TDummyValue.InstanceCount).Be(1);
  D.Remove(1);
  Should(TDummyValue.InstanceCount).Be(0);
end;

procedure TDictionaryOwnershipTests.OwnsValues_ShouldFreeOnClear;
var
  D: IDictionary<Integer, TDummyValue>;
begin
  D := TCollections.CreateDictionary<Integer, TDummyValue>(True);
  D.Add(1, TDummyValue.Create('A'));
  D.Add(2, TDummyValue.Create('B'));
  D.Add(3, TDummyValue.Create('C'));
  Should(TDummyValue.InstanceCount).Be(3);
  D.Clear;
  Should(TDummyValue.InstanceCount).Be(0);
end;

procedure TDictionaryOwnershipTests.OwnsValues_ShouldFreeOnOverwrite;
var
  D: IDictionary<Integer, TDummyValue>;
begin
  D := TCollections.CreateDictionary<Integer, TDummyValue>(True);
  D.Add(1, TDummyValue.Create('Old'));
  Should(TDummyValue.InstanceCount).Be(1);
  D.AddOrSetValue(1, TDummyValue.Create('New'));
  // Old should have been freed, New is still alive
  Should(TDummyValue.InstanceCount).Be(1);
  Should(D[1].Name).Be('New');
end;

procedure TDictionaryOwnershipTests.NoOwnership_ShouldNotFreeOnClear;
var
  D: IDictionary<Integer, TDummyValue>;
  V1, V2: TDummyValue;
begin
  D := TCollections.CreateDictionary<Integer, TDummyValue>;
  V1 := TDummyValue.Create('V1');
  V2 := TDummyValue.Create('V2');
  try
    D.Add(1, V1);
    D.Add(2, V2);
    D.Clear;
    Should(TDummyValue.InstanceCount).Be(2); // Still alive
  finally
    V1.Free;
    V2.Free;
  end;
end;

{ TDictionaryStressTests }

procedure TDictionaryStressTests.Insert1000_ShouldWork;
var
  D: IDictionary<Integer, Integer>;
  I: Integer;
  V: Integer;
begin
  D := TCollections.CreateDictionary<Integer, Integer>;
  for I := 0 to 999 do
    D.Add(I, I * 10);
  Should(D.Count).Be(1000);

  // Verify a sample
  Should(D.TryGetValue(500, V)).BeTrue;
  Should(V).Be(5000);
end;

procedure TDictionaryStressTests.InsertAndRemoveAll_ShouldBeEmpty;
var
  D: IDictionary<Integer, Integer>;
  I: Integer;
begin
  D := TCollections.CreateDictionary<Integer, Integer>;
  for I := 0 to 99 do
    D.Add(I, I);

  for I := 0 to 99 do
    D.Remove(I);

  Should(D.Count).Be(0);
end;

procedure TDictionaryStressTests.AddRemoveAdd_LookupOfRemovedKey_ShouldNotHang;
var
  D: IDictionary<Int64, Integer>;
  V: Integer;
begin
  // Five operations are enough with DEFAULT_CAPACITY = 4.
  D := TCollections.CreateDictionary<Int64, Integer>;
  D.Add(100, 1);
  D.Add(200, 2);
  D.Add(300, 3); // 3 occupied, load 75% -> no grow
  D.Remove(100); // 2 occupied + 1 tombstone
  D.Add(900, 4); // 3 occupied + 1 tombstone -> table used to be saturated here

  Should(D.TryGetValue(100, V)).BeFalse; // used to spin forever
  Should(D.ContainsKey(900)).BeTrue;
  Should(D.ContainsKey(200)).BeTrue;
  Should(D.ContainsKey(300)).BeTrue;
  Should(D.Count).Be(3);
end;

procedure TDictionaryStressTests.LongAddRemoveCycle_ShouldStayConsistent;
var
  D: IDictionary<Integer, Integer>;
  I, V: Integer;
begin
  // Keeps a handful of live entries while churning thousands of insert/remove:
  // without counting tombstones the table fills up and never grows.
  D := TCollections.CreateDictionary<Integer, Integer>;
  for I := 0 to 9 do
    D.Add(I, I);

  for I := 10 to 5000 do
  begin
    D.Add(I, I);
    D.Remove(I - 10); // steady state: 10 live entries, one tombstone per round
    Should(D.Count).Be(10);
  end;

  // The live window is intact and absent keys are reported as absent.
  for I := 4991 to 5000 do
    Should(D.ContainsKey(I)).BeTrue;
  Should(D.TryGetValue(0, V)).BeFalse;
  Should(D.TryGetValue(4990, V)).BeFalse;
end;

procedure TDictionaryStressTests.Rehash_ShouldPreserveAllEntries;
var
  D: IDictionary<Integer, Integer>;
  I, V: Integer;
begin
  // Start with small capacity (4), insert enough to trigger multiple rehashes
  D := TCollections.CreateDictionary<Integer, Integer>;
  for I := 1 to 50 do
    D.Add(I, I * 100);

  Should(D.Count).Be(50);

  // Verify all values survived rehashing
  for I := 1 to 50 do
  begin
    Should(D.TryGetValue(I, V)).BeTrue;
    Should(V).Be(I * 100);
  end;
end;

{ TCollectionsFactoryTests }

procedure TCollectionsFactoryTests.CreateList_ShouldReturnEmptyList;
var
  L: IList<Integer>;
begin
  L := TCollections.CreateList<Integer>;
  Should(L).NotBeNil;
  Should(L.Count).Be(0);
end;

procedure TCollectionsFactoryTests.CreateObjectList_ShouldOwnObjects;
var
  L: IList<TObject>;
begin
  L := TCollections.CreateObjectList<TObject>(True);
  Should(L).NotBeNil;
  Should(L.Count).Be(0);
end;

procedure TCollectionsFactoryTests.CreateDictionary_ShouldReturnEmptyDict;
var
  D: IDictionary<string, Integer>;
begin
  D := TCollections.CreateDictionary<string, Integer>;
  Should(D).NotBeNil;
  Should(D.Count).Be(0);
end;

procedure TCollectionsFactoryTests.CreateDictionary_WithOwnership_ShouldWork;
var
  D: IDictionary<Integer, TObject>;
begin
  D := TCollections.CreateDictionary<Integer, TObject>(True);
  Should(D).NotBeNil;
  Should(D.Count).Be(0);
end;

{ TDictionaryEnumeratorTests }

procedure TDictionaryEnumeratorTests.ForIn_ShouldIterateAllPairs;
var
  D: IDictionary<Integer, string>;
  Pair: TPair<Integer, string>;
  KeysSum: Integer;
  ValuesConcat: string;
begin
  D := TCollections.CreateDictionary<Integer, string>;
  D.Add(1, 'A');
  D.Add(2, 'B');
  D.Add(3, 'C');

  KeysSum := 0;
  ValuesConcat := '';
  for Pair in D do
  begin
    Inc(KeysSum, Pair.Key);
    ValuesConcat := ValuesConcat + Pair.Value;
  end;

  Should(KeysSum).Be(6);
  // Order might not be guaranteed in hash map, but content should match
  Should(Length(ValuesConcat)).Be(3);
  Should(ValuesConcat).Contain('A').AndAlso.Contain('B').AndAlso.Contain('C');
end;

procedure TDictionaryEnumeratorTests.ForIn_EmptyDictionary_ShouldNotIterate;
var
  D: IDictionary<Integer, string>;
  Pair: TPair<Integer, string>;
  Count: Integer;
begin
  D := TCollections.CreateDictionary<Integer, string>;
  Count := 0;
  for Pair in D do
    Inc(Count);
  Should(Count).Be(0);
end;

{ TDictionaryInterfaceTests }

procedure TDictionaryInterfaceTests.InterfaceValues_ShouldBeRefCounted;
var
  D: IDictionary<Integer, IValueHolder>;
begin
  D := TCollections.CreateDictionary<Integer, IValueHolder>;
  D.Add(1, TValueHolder.Create(100));
  Should(D[1].Value).Be(100);
  D.Clear;
  Should(D.Count).Be(0);
end;

procedure TDictionaryInterfaceTests.InterfaceKeys_ShouldWork;
var
  D: IDictionary<IValueHolder, string>;
  K1, K2: IValueHolder;
begin
  D := TCollections.CreateDictionary<IValueHolder, string>;
  K1 := TValueHolder.Create(1);
  K2 := TValueHolder.Create(2);
  D.Add(K1, 'Key1');
  D.Add(K2, 'Key2');
  Should(D[K1]).Be('Key1');
  Should(D[K2]).Be('Key2');
  Should(D.Count).Be(2);
end;

{ TDictionaryManagedRecordTests }

procedure TDictionaryManagedRecordTests.ManagedRecord_ShouldWork;
var
  D: IDictionary<string, TManagedRecord>;
  R: TManagedRecord;
begin
  D := TCollections.CreateDictionary<string, TManagedRecord>;
  R.S := 'RecordData';
  R.I := 123;
  D.Add('Key', R);
  Should(D['Key'].S).Be('RecordData');
  Should(D['Key'].I).Be(123);
  D.Clear;
  Should(D.Count).Be(0);
end;

{ TDictionaryFloatKeyTests }

procedure TDictionaryFloatKeyTests.NegativeZero_ShouldFindTheSameKey;
var
  D: IDictionary<Double, string>;
  Zero, NegZero: Double;
  V: string;
begin
  Zero := 0.0;
  NegZero := -0.0;
  // Same number as far as arithmetic is concerned...
  Should(Zero = NegZero).BeTrue;

  D := TCollections.CreateDictionary<Double, string>;
  D.Add(Zero, 'value');
  // ...so looking it up with the other spelling must find it.
  Should(D.ContainsKey(NegZero)).BeTrue;
  Should(D.TryGetValue(NegZero, V)).BeTrue;
  Should(V).Be('value');
end;

procedure TDictionaryFloatKeyTests.NegativeZero_ShouldNotAddASecondKey;
var
  D: IDictionary<Double, string>;
  Zero, NegZero: Double;
begin
  Zero := 0.0;
  NegZero := -0.0;
  D := TCollections.CreateDictionary<Double, string>;
  D.Add(Zero, 'first');
  D.AddOrSetValue(NegZero, 'second');
  // One number, one entry: the second call overwrites, it does not insert.
  Should(D.Count).Be(1);
  Should(D[Zero]).Be('second');
end;

procedure TDictionaryFloatKeyTests.SingleKey_NegativeZero_ShouldFindTheSameKey;
var
  D: IDictionary<Single, string>;
  Zero, NegZero: Single;
begin
  Zero := 0.0;
  NegZero := -0.0;
  D := TCollections.CreateDictionary<Single, string>;
  D.Add(Zero, 'value');
  Should(D.ContainsKey(NegZero)).BeTrue;
end;

procedure TDictionaryFloatKeyTests.Currency_ShouldStillWork;
var
  D: IDictionary<Currency, string>;
  A, B: Currency;
begin
  // Currency is a scaled 64-bit integer: equal values already have equal bits,
  // so it takes the plain byte-hash path. Guard against regressions there.
  A := 0.1;
  B := 0.2;
  D := TCollections.CreateDictionary<Currency, string>;
  D.Add(0.3, 'sum');
  Should(D.ContainsKey(A + B)).BeTrue;
  Should(D[A + B]).Be('sum');
  Should(D.ContainsKey(0.31)).BeFalse;
end;

procedure TDictionaryFloatKeyTests.NonZeroFloats_ShouldStillWork;
var
  D: IDictionary<Double, Integer>;
begin
  // The zero normalization must not disturb ordinary values.
  D := TCollections.CreateDictionary<Double, Integer>;
  D.Add(1.5, 1);
  D.Add(-1.5, 2);
  D.Add(2.25, 3);
  Should(D.Count).Be(3);
  Should(D[1.5]).Be(1);
  Should(D[-1.5]).Be(2);
  Should(D[2.25]).Be(3);
  Should(D.ContainsKey(3.75)).BeFalse;
end;

end.
