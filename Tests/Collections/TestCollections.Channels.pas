unit TestCollections.Channels;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Threading,
  Dext.Testing,
  Dext.Collections.Channels;

type
  [TestFixture('Collections - Channels')]
  TChannelTests = class
  public
    [Test]
    procedure TryWrite_ShouldSucceedForUnbounded;
    [Test]
    procedure TryRead_ShouldReturnFalseIfEmpty;
    [Test]
    procedure Bounded_TryWrite_ShouldFailWhenFull;
    [Test]
    procedure Concurrent_WriteAndRead_ShouldPassMessages;
  end;

implementation

{ TChannelTests }

procedure TChannelTests.TryWrite_ShouldSucceedForUnbounded;
var
  Chan: IChannel<string>;
begin
  Chan := TChannel<string>.CreateUnbounded;
  Should(Chan.TryWrite('msg1')).BeTrue;
  Should(Chan.TryWrite('msg2')).BeTrue;
  
  Chan.Close;
end;

procedure TChannelTests.TryRead_ShouldReturnFalseIfEmpty;
var
  Chan: IChannel<string>;
  Val: string;
begin
  Chan := TChannel<string>.CreateUnbounded;
  Should(Chan.TryRead(Val)).BeFalse;
  Chan.Close;
end;

procedure TChannelTests.Bounded_TryWrite_ShouldFailWhenFull;
var
  Chan: IChannel<Integer>;
begin
  Chan := TChannel<Integer>.CreateBounded(2);
  Should(Chan.TryWrite(1)).BeTrue;
  Should(Chan.TryWrite(2)).BeTrue;
  Should(Chan.TryWrite(3)).BeFalse; // Should be full
  
  Chan.Close;
end;

procedure TChannelTests.Concurrent_WriteAndRead_ShouldPassMessages;
var
  Chan: IChannel<Integer>;
  Sum: Integer;
  Tasks: TArray<ITask>;
begin
  Chan := TChannel<Integer>.CreateBounded(10);
  Sum := 0;
  
  SetLength(Tasks, 2);
  
  Tasks[0] := TTask.Run(
    procedure
    var
      I, Val: Integer;
    begin
      for I := 1 to 50 do
      begin
        Val := Chan.Read;
        TInterlocked.Add(Sum, Val);
      end;
    end
  );
  
  Tasks[1] := TTask.Run(
    procedure
    var
      I: Integer;
    begin
      for I := 1 to 50 do
      begin
        Chan.Write(I);
      end;
    end
  );
  
  TTask.WaitForAll(Tasks);
  Chan.Close;
  
  // Sum of 1..50 = 1275
  Should(Sum).Be(1275);
end;

end.
