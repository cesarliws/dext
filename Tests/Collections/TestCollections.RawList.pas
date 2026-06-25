unit TestCollections.RawList;

interface

uses
  System.SysUtils,
  System.TypInfo,
  Dext.Testing,
  Dext.Collections.Raw;

type
  [TestFixture('Raw - TRawList Operations')]
  TRawListTests = class
  public
    [Test]
    procedure AddRaw_ShouldIncreaseCount;

    [Test]
    procedure InsertRaw_AtBeginning_ShouldShiftItems;

    [Test]
    procedure InsertRaw_AtMiddle_ShouldShiftItems;

    [Test]
    procedure InsertRaw_AtEnd_ShouldWork;

    [Test]
    procedure InsertRaw_In_The_Middle_ShouldHaveRightPosition;

    [Test]
    procedure DeleteRaw_ShouldShiftItems;

    [Test]
    procedure ExchangeRaw_ShouldSwapItems;

    [Test]
    procedure SetRawItem_ShouldUpdateItem;

    [Test]
    procedure Clear_ShouldResetCount;

    [Test]
    procedure Realloc_ShouldPreserveItems;
  end;

implementation

{ TRawListTests }

procedure TRawListTests.AddRaw_ShouldIncreaseCount;
var
  List: TRawList;
  Value: Integer;
begin
  List := TRawList.Create(SizeOf(Integer), nil, False);
  try
    Value := 10;
    List.AddRaw(@Value);
    Value := 20;
    List.AddRaw(@Value);

    Should(List.Count).Be(2);
    
    List.GetRawItem(0, @Value);
    Should(Value).Be(10);
    
    List.GetRawItem(1, @Value);
    Should(Value).Be(20);
  finally
    List.Free;
  end;
end;

procedure TRawListTests.InsertRaw_AtBeginning_ShouldShiftItems;
var
  List: TRawList;
  Value: Integer;
begin
  List := TRawList.Create(SizeOf(Integer), nil, False);
  try
    Value := 10;
    List.AddRaw(@Value);
    Value := 20;
    List.AddRaw(@Value);

    Value := 5;
    List.InsertRaw(0, @Value);

    Should(List.Count).Be(3);
    
    List.GetRawItem(0, @Value);
    Should(Value).Be(5);
    
    List.GetRawItem(1, @Value);
    Should(Value).Be(10);
    
    List.GetRawItem(2, @Value);
    Should(Value).Be(20);
  finally
    List.Free;
  end;
end;

procedure TRawListTests.InsertRaw_AtMiddle_ShouldShiftItems;
var
  List: TRawList;
  Value: Integer;
begin
  List := TRawList.Create(SizeOf(Integer), nil, False);
  try
    Value := 10;
    List.AddRaw(@Value);
    Value := 20;
    List.AddRaw(@Value);

    Value := 15;
    List.InsertRaw(1, @Value);

    Should(List.Count).Be(3);
    
    List.GetRawItem(0, @Value);
    Should(Value).Be(10);
    
    List.GetRawItem(1, @Value);
    Should(Value).Be(15);
    
    List.GetRawItem(2, @Value);
    Should(Value).Be(20);
  finally
    List.Free;
  end;
end;

procedure TRawListTests.InsertRaw_In_The_Middle_ShouldHaveRightPosition;
var
  List: TRawList;
  Value: Integer;
begin
  List := TRawList.Create(SizeOf(Integer), nil, False);
  try
    Value := 1; List.AddRaw(@Value);
    Value := 3; List.AddRaw(@Value);

    Value := 2;
    List.InsertRaw(1, @Value); // Insert 2 between 1 and 3

    Should(List.Count).Be(3);
    
    List.GetRawItem(0, @Value); Should(Value).Be(1);
    List.GetRawItem(1, @Value); Should(Value).Be(2);
    List.GetRawItem(2, @Value); Should(Value).Be(3);
  finally
    List.Free;
  end;
end;

procedure TRawListTests.InsertRaw_AtEnd_ShouldWork;
var
  List: TRawList;
  Value: Integer;
begin
  List := TRawList.Create(SizeOf(Integer), nil, False);
  try
    Value := 10;
    List.AddRaw(@Value);

    Value := 15;
    List.InsertRaw(1, @Value);

    Should(List.Count).Be(2);
    
    List.GetRawItem(0, @Value);
    Should(Value).Be(10);
    
    List.GetRawItem(1, @Value);
    Should(Value).Be(15);
  finally
    List.Free;
  end;
end;

procedure TRawListTests.DeleteRaw_ShouldShiftItems;
var
  List: TRawList;
  Value: Integer;
begin
  List := TRawList.Create(SizeOf(Integer), nil, False);
  try
    Value := 10; List.AddRaw(@Value);
    Value := 20; List.AddRaw(@Value);
    Value := 30; List.AddRaw(@Value);

    List.DeleteRaw(1); // Remove 20

    Should(List.Count).Be(2);
    
    List.GetRawItem(0, @Value);
    Should(Value).Be(10);
    
    List.GetRawItem(1, @Value);
    Should(Value).Be(30);
  finally
    List.Free;
  end;
end;

procedure TRawListTests.ExchangeRaw_ShouldSwapItems;
var
  List: TRawList;
  Value: Integer;
begin
  List := TRawList.Create(SizeOf(Integer), nil, False);
  try
    Value := 10; List.AddRaw(@Value);
    Value := 20; List.AddRaw(@Value);
    
    List.ExchangeRaw(0, 1);
    
    List.GetRawItem(0, @Value);
    Should(Value).Be(20);
    
    List.GetRawItem(1, @Value);
    Should(Value).Be(10);
  finally
    List.Free;
  end;
end;

procedure TRawListTests.SetRawItem_ShouldUpdateItem;
var
  List: TRawList;
  Value: Integer;
begin
  List := TRawList.Create(SizeOf(Integer), nil, False);
  try
    Value := 10; List.AddRaw(@Value);
    
    Value := 50;
    List.SetRawItem(0, @Value);
    
    List.GetRawItem(0, @Value);
    Should(Value).Be(50);
  finally
    List.Free;
  end;
end;

procedure TRawListTests.Clear_ShouldResetCount;
var
  List: TRawList;
  Value: Integer;
begin
  List := TRawList.Create(SizeOf(Integer), nil, False);
  try
    Value := 10; List.AddRaw(@Value);
    Value := 20; List.AddRaw(@Value);
    
    List.Clear;
    Should(List.Count).Be(0);
  finally
    List.Free;
  end;
end;

procedure TRawListTests.Realloc_ShouldPreserveItems;
var
  List: TRawList;
  Value, I: Integer;
begin
  List := TRawList.Create(SizeOf(Integer), nil, False);
  try
    // Add many items to trigger realloc
    for I := 1 to 100 do
    begin
      Value := I;
      List.AddRaw(@Value);
    end;

    Should(List.Count).Be(100);
    Should(List.Capacity).BeGreaterOrEqualTo(100);
    
    for I := 1 to 100 do
    begin
      List.GetRawItem(I - 1, @Value);
      Should(Value).Be(I);
    end;
  finally
    List.Free;
  end;
end;

end.
