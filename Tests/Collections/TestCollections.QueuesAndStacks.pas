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

unit TestCollections.QueuesAndStacks;

interface

uses
  Dext.Testing,
  System.SysUtils,
  Dext.Collections;

type
  [TestFixture('Collections - Queues and Stacks')]
  TTestQueuesAndStacks = class
  public
    [Test]
    procedure TestStack_Basic;
    [Test]
    procedure TestStack_ManagedTypes;
    
    [Test]
    procedure TestQueue_Basic;
    [Test]
    procedure TestQueue_ManagedTypes;
    [Test]
    procedure TestQueue_CircularGrowth;
    
    [Test]
    procedure TestHashSet_ManagedTypes;
  end;

implementation

{ TTestQueuesAndStacks }

procedure TTestQueuesAndStacks.TestHashSet_ManagedTypes;
var
  S: IHashSet<string>;
begin
  S := TCollections.CreateHashSet<string>;
  Should(S.Add('A')).BeTrue;
  Should(S.Add('B')).BeTrue;
  Should(S.Add('a')).BeTrue; // HashSet is case-sensitive by default
  Should(S.Contains('A')).BeTrue;
  Should(S.Count).Be(3); // A, B, a
end;

procedure TTestQueuesAndStacks.TestQueue_Basic;
var
  Q: IQueue<Integer>;
begin
  Q := TCollections.CreateQueue<Integer>;
  Q.Enqueue(1);
  Q.Enqueue(2);
  Q.Enqueue(3);
  
  Should(Q.Count).Be(3);
  Should(Q.Peek).Be(1);
  Should(Q.Dequeue).Be(1);
  Should(Q.Dequeue).Be(2);
  Should(Q.Count).Be(1); // 3 items - 2 dequeues = 1
end;

procedure TTestQueuesAndStacks.TestQueue_CircularGrowth;
var
  Q: IQueue<Integer>;
  I: Integer;
begin
  Q := TCollections.CreateQueue<Integer>;
  // INITIAL_CAPACITY is 4. Let's force circular wrap.
  for I := 1 to 3 do Q.Enqueue(I);
  Should(Q.Dequeue).Be(1); // Head=1, Tail=3, Count=2
  Should(Q.Dequeue).Be(2); // Head=2, Tail=3, Count=1
  
  Q.Enqueue(4); // Head=2, Tail=0, Count=2 (wraps)
  Q.Enqueue(5); // Head=2, Tail=1, Count=3
  Q.Enqueue(6); // Head=2, Tail=2, Count=4 (Full)
  
  Q.Enqueue(7); // Must trigger Grow and linearize
  Should(Q.Count).Be(5);
  
  Should(Q.Dequeue).Be(3);
  Should(Q.Dequeue).Be(4);
  Should(Q.Dequeue).Be(5);
  Should(Q.Dequeue).Be(6);
  Should(Q.Dequeue).Be(7);
  Should(Q.Count).Be(0);
end;

procedure TTestQueuesAndStacks.TestQueue_ManagedTypes;
var
  Q: IQueue<string>;
begin
  Q := TCollections.CreateQueue<string>;
  Q.Enqueue('Hello');
  Q.Enqueue('World');
  Should(Q.Dequeue).Be('Hello');
  Should(Q.Count).Be(1);
  Q.Clear;
  Should(Q.Count).Be(0);
end;

procedure TTestQueuesAndStacks.TestStack_Basic;
var
  S: IStack<Integer>;
begin
  S := TCollections.CreateStack<Integer>;
  S.Push(10);
  S.Push(20);
  Should(S.Count).Be(2);
  Should(S.Peek).Be(20);
  Should(S.Pop).Be(20);
  Should(S.Pop).Be(10);
  Should(S.Count).Be(0);
end;

procedure TTestQueuesAndStacks.TestStack_ManagedTypes;
var
  S: IStack<string>;
begin
  S := TCollections.CreateStack<string>;
  S.Push('Bot');
  S.Push('Dext');
  Should(S.Pop).Be('Dext');
  Should(S.Pop).Be('Bot'); // Was Peek, better use Pop to verify order
  Should(S.Count).Be(0);
end;

end.
