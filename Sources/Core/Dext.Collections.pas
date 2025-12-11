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
{                                                                           }
{  Author:  Cesar Romero                                                    }
{  Created: 2025-12-08                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.Collections;

interface

uses
  System.Generics.Collections,
  System.Generics.Defaults,
  System.SysUtils,
  System.TypInfo,
  System.Rtti,
  Dext.Specifications.Interfaces,
  Dext.Specifications.Evaluator;

type
  // Clean definition of IEnumerator<T> avoiding inheritance from System.Generics.Collections.IEnumerator
  IEnumerator<T> = interface
    function GetCurrent: T;
    function MoveNext: Boolean;
    property Current: T read GetCurrent;
  end;

  // Clean definition of IEnumerable<T>
  IEnumerable<T> = interface
    function GetEnumerator: IEnumerator<T>;
  end;

  // IList<T> inherits from our clean IEnumerable<T>
  {$M+}
  IList<T> = interface(IEnumerable<T>)
    ['{8877539D-3522-488B-933B-8C4581177699}']
    function GetCount: Integer;
    function GetItem(Index: Integer): T;
    procedure SetItem(Index: Integer; const Value: T);

    procedure Add(const Value: T);
    procedure AddRange(const Values: IEnumerable<T>); overload;
    procedure AddRange(const Values: array of T); overload;
    procedure Insert(Index: Integer; const Value: T);
    function Remove(const Value: T): Boolean;
    function Extract(const Value: T): T;  // Remove without freeing (for OwnsObjects lists)
    procedure RemoveAt(Index: Integer);
    procedure Clear();
    function Contains(const Value: T): Boolean;
    function IndexOf(const Value: T): Integer;

    property Count: Integer read GetCount;
    property Items[Index: Integer]: T read GetItem write SetItem; default;

    // Functional Methods (LINQ-like) - Predicate based only
    function Where(const Predicate: TFunc<T, Boolean>): IList<T>; overload;
    function Where(const Expression: IExpression): IList<T>; overload;

    function First: T; overload;
    function First(const Expression: IExpression): T; overload;
    
    function FirstOrDefault: T; overload;
    function FirstOrDefault(const DefaultValue: T): T; overload;
    function FirstOrDefault(const Expression: IExpression): T; overload;

    function Any(const Predicate: TFunc<T, Boolean>): Boolean; overload;
    function Any(const Expression: IExpression): Boolean; overload;
    function Any: Boolean; overload;

    function All(const Predicate: TFunc<T, Boolean>): Boolean; overload;
    function All(const Expression: IExpression): Boolean; overload;

    procedure ForEach(const Action: TProc<T>);
  end;

  TSmartEnumerator<T> = class(TInterfacedObject, IEnumerator<T>)
  private
    FList: System.Generics.Collections.TList<T>;
    FIndex: Integer;
    FCurrent: T;
  public
    constructor Create(AList: System.Generics.Collections.TList<T>);
    function GetCurrent: T;
    function MoveNext: Boolean;
    property Current: T read GetCurrent;
  end;

  TSmartList<T> = class(TInterfacedObject, IList<T>, IEnumerable<T>)
  private
    FList: System.Generics.Collections.TList<T>;
    FOwnsObjects: Boolean;
    procedure Notify(Sender: TObject; const Item: T; Action: TCollectionNotification);
  protected
    function GetCount: Integer;
    function GetItem(Index: Integer): T;
    procedure SetItem(Index: Integer; const Value: T);
    function GetEnumerator: IEnumerator<T>;
  public
    constructor Create(OwnsObjects: Boolean = True);
    destructor Destroy; override;

    procedure Add(const Value: T);
    procedure AddRange(const Values: IEnumerable<T>); overload;
    procedure AddRange(const Values: array of T); overload;
    procedure Insert(Index: Integer; const Value: T);
    function Remove(const Value: T): Boolean;
    function Extract(const Value: T): T;
    procedure RemoveAt(Index: Integer);
    procedure Clear;
    function Contains(const Value: T): Boolean;
    function IndexOf(const Value: T): Integer;

    function Where(const Predicate: TFunc<T, Boolean>): IList<T>; overload;
    function Where(const Expression: IExpression): IList<T>; overload;

    function First: T; overload;
    function First(const Expression: IExpression): T; overload;

    function FirstOrDefault: T; overload;
    function FirstOrDefault(const DefaultValue: T): T; overload;
    function FirstOrDefault(const Expression: IExpression): T; overload;

    function Any(const Predicate: TFunc<T, Boolean>): Boolean; overload;
    function Any(const Expression: IExpression): Boolean; overload;
    function Any: Boolean; overload;

    function All(const Predicate: TFunc<T, Boolean>): Boolean; overload;
    function All(const Expression: IExpression): Boolean; overload;

    procedure ForEach(const Action: TProc<T>);
  end;

  /// <summary>
  ///   Factory for creating lists.
  /// </summary>
  TCollections = class
  public
    class function CreateList<T>(OwnsObjects: Boolean = False): IList<T>;
    class function CreateObjectList<T: class>(OwnsObjects: Boolean = False): IList<T>;
  end;

implementation

{ TSmartEnumerator<T> }

constructor TSmartEnumerator<T>.Create(AList: System.Generics.Collections.TList<T>);
begin
  inherited Create;
  FList := AList;
  FIndex := -1;
  FCurrent := Default(T);
end;

function TSmartEnumerator<T>.GetCurrent: T;
begin
  Result := FCurrent;
end;

function TSmartEnumerator<T>.MoveNext: Boolean;
begin
  if FList = nil then Exit(False);
  Inc(FIndex);
  Result := FIndex < FList.Count;
  if Result then
    FCurrent := FList[FIndex]
  else
    FCurrent := Default(T);
end;

{ TSmartList<T> }

constructor TSmartList<T>.Create(OwnsObjects: Boolean);
begin
  inherited Create;
  FOwnsObjects := OwnsObjects;
  FList := System.Generics.Collections.TList<T>.Create;
  if FOwnsObjects and (PTypeInfo(TypeInfo(T)).Kind = tkClass) then
    FList.OnNotify := Notify;
end;

destructor TSmartList<T>.Destroy;
begin
  FList.Free;
  inherited;
end;

procedure TSmartList<T>.Notify(Sender: TObject; const Item: T; Action: TCollectionNotification);
begin
  if Action = cnRemoved then
  begin
    PObject(@Item).Free;
  end;
end;

function TSmartList<T>.GetCount: Integer;
begin
  Result := FList.Count;
end;

function TSmartList<T>.GetEnumerator: IEnumerator<T>;
begin
  Result := TSmartEnumerator<T>.Create(FList);
end;

function TSmartList<T>.GetItem(Index: Integer): T;
begin
  Result := FList[Index];
end;

procedure TSmartList<T>.SetItem(Index: Integer; const Value: T);
begin
  FList[Index] := Value;
end;

procedure TSmartList<T>.Add(const Value: T);
begin
  FList.Add(Value);
end;

procedure TSmartList<T>.AddRange(const Values: IEnumerable<T>);
var
  Item: T;
begin
  // Manual iteration to support our custom IEnumerable<T>
  for Item in Values do
    FList.Add(Item);
end;

procedure TSmartList<T>.AddRange(const Values: array of T);
begin
  FList.AddRange(Values);
end;

procedure TSmartList<T>.Insert(Index: Integer; const Value: T);
begin
  FList.Insert(Index, Value);
end;

function TSmartList<T>.Remove(const Value: T): Boolean;
begin
  Result := FList.Remove(Value) >= 0;
end;

function TSmartList<T>.Extract(const Value: T): T;
var
  SavedNotify: TCollectionNotifyEvent<T>;
begin
  // Temporarily disable OnNotify to prevent freeing the object
  SavedNotify := FList.OnNotify;
  try
    FList.OnNotify := nil;
    if FList.Remove(Value) >= 0 then
      Result := Value
    else
      Result := Default(T);
  finally
    FList.OnNotify := SavedNotify;
  end;
end;

procedure TSmartList<T>.RemoveAt(Index: Integer);
begin
  FList.Delete(Index);
end;

procedure TSmartList<T>.Clear;
begin
  FList.Clear;
end;

function TSmartList<T>.Contains(const Value: T): Boolean;
begin
  Result := FList.Contains(Value);
end;

function TSmartList<T>.IndexOf(const Value: T): Integer;
begin
  Result := FList.IndexOf(Value);
end;

// LINQ-like Implementation

function TSmartList<T>.Where(const Predicate: TFunc<T, Boolean>): IList<T>;
var
  Item: T;
  NewList: TSmartList<T>;
begin
  NewList := TSmartList<T>.Create(False); 
  Result := NewList;
  
  for Item in FList do
  begin
    if Predicate(Item) then
      NewList.Add(Item);
  end;
end;

function TSmartList<T>.Where(const Expression: IExpression): IList<T>;
var
  Item: T;
  NewList: TSmartList<T>;
begin
  NewList := TSmartList<T>.Create(False);
  Result := NewList;
  
  if PTypeInfo(TypeInfo(T)).Kind <> tkClass then
    raise Exception.Create('Expression evaluation is only supported for class types.');

  for Item in FList do
  begin
    if TExpressionEvaluator.Evaluate(Expression, TObject(PPointer(@Item)^)) then
      NewList.Add(Item);
  end;
end;

function TSmartList<T>.First: T;
begin
  if FList.Count = 0 then
    raise Exception.Create('List is empty');
  Result := FList[0];
end;

function TSmartList<T>.First(const Expression: IExpression): T;
var
  Item: T;
begin
  if PTypeInfo(TypeInfo(T)).Kind <> tkClass then
    raise Exception.Create('Expression evaluation is only supported for class types.');

  for Item in FList do
  begin
    if TExpressionEvaluator.Evaluate(Expression, TObject(PPointer(@Item)^)) then
      Exit(Item);
  end;
  raise Exception.Create('Sequence contains no matching element');
end;

function TSmartList<T>.FirstOrDefault: T;
begin
  if FList.Count = 0 then
    Result := Default(T)
  else
    Result := FList[0];
end;

function TSmartList<T>.FirstOrDefault(const DefaultValue: T): T;
begin
  if FList.Count = 0 then
    Result := DefaultValue
  else
    Result := FList[0];
end;

function TSmartList<T>.FirstOrDefault(const Expression: IExpression): T;
var
  Item: T;
begin
  if PTypeInfo(TypeInfo(T)).Kind <> tkClass then
    raise Exception.Create('Expression evaluation is only supported for class types.');

  for Item in FList do
  begin
    if TExpressionEvaluator.Evaluate(Expression, TObject(PPointer(@Item)^)) then
      Exit(Item);
  end;
  Result := Default(T);
end;

function TSmartList<T>.Any(const Predicate: TFunc<T, Boolean>): Boolean;
var
  Item: T;
begin
  Result := False;
  for Item in FList do
  begin
    if Predicate(Item) then
    Exit(True);
  end;
end;

function TSmartList<T>.Any(const Expression: IExpression): Boolean;
var
  Item: T;
begin
  if PTypeInfo(TypeInfo(T)).Kind <> tkClass then
    raise Exception.Create('Expression evaluation is only supported for class types.');

  Result := False;
  for Item in FList do
  begin
    if TExpressionEvaluator.Evaluate(Expression, TObject(PPointer(@Item)^)) then
      Exit(True);
  end;
end;

function TSmartList<T>.Any: Boolean;
begin
  Result := FList.Count > 0;
end;

function TSmartList<T>.All(const Predicate: TFunc<T, Boolean>): Boolean;
var
  Item: T;
begin
  Result := True;
  for Item in FList do
  begin
    if not Predicate(Item) then
      Exit(False);
  end;
end;

function TSmartList<T>.All(const Expression: IExpression): Boolean;
var
  Item: T;
begin
  if PTypeInfo(TypeInfo(T)).Kind <> tkClass then
    raise Exception.Create('Expression evaluation is only supported for class types.');

  Result := True;
  for Item in FList do
  begin
    if not TExpressionEvaluator.Evaluate(Expression, TObject(PPointer(@Item)^)) then
      Exit(False);
  end;
end;

procedure TSmartList<T>.ForEach(const Action: TProc<T>);
var
  Item: T;
begin
  for Item in FList do
    Action(Item);
end;

{ TCollections }

class function TCollections.CreateList<T>(OwnsObjects: Boolean): IList<T>;
begin
  Result := TSmartList<T>.Create(OwnsObjects);
end;

class function TCollections.CreateObjectList<T>(OwnsObjects: Boolean): IList<T>;
begin
  Result := TSmartList<T>.Create(OwnsObjects);
end;

end.
