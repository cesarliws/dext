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
unit Dext.Entity.Joining;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Dext.Entity.Query,
  Dext.Specifications.Interfaces;

type
  /// <summary>
  ///   Iterator that performs an inner join on two sequences.
  /// </summary>
  TJoinIterator<TOuter, TInner, TKey, TResult> = class(TQueryIterator<TResult>)
  private
    FOuter: TFluentQuery<TOuter>;
    FInner: TFluentQuery<TInner>;
    FOuterKeySelector: TFunc<TOuter, TKey>;
    FInnerKeySelector: TFunc<TInner, TKey>;
    FResultSelector: TFunc<TOuter, TInner, TResult>;
    
    // State
    FExecuted: Boolean;
    FOuterEnumerator: TEnumerator<TOuter>;
    FInnerLookup: TDictionary<TKey, TList<TInner>>;
    FCurrentInnerList: TList<TInner>;
    FCurrentInnerIndex: Integer;
    
    procedure BuildLookup;
  protected
    function MoveNextCore: Boolean; override;
  public
    constructor Create(
      const AOuter: TFluentQuery<TOuter>;
      const AInner: TFluentQuery<TInner>;
      const AOuterKeySelector: TFunc<TOuter, TKey>;
      const AInnerKeySelector: TFunc<TInner, TKey>;
      const AResultSelector: TFunc<TOuter, TInner, TResult>);
    destructor Destroy; override;
  end;

  /// <summary>
  ///   Static class for join operations.
  /// </summary>
  TJoining = class
  public
    /// <summary>
    ///   Correlates the elements of two sequences based on matching keys.
    /// </summary>
    class function Join<TOuter, TInner, TKey, TResult>(
      const Outer: TFluentQuery<TOuter>;
      const Inner: TFluentQuery<TInner>;
      const OuterKeySelector: TFunc<TOuter, TKey>;
      const InnerKeySelector: TFunc<TInner, TKey>;
      const ResultSelector: TFunc<TOuter, TInner, TResult>
    ): TFluentQuery<TResult>;
  end;

implementation

{ TJoinIterator<TOuter, TInner, TKey, TResult> }

constructor TJoinIterator<TOuter, TInner, TKey, TResult>.Create(
  const AOuter: TFluentQuery<TOuter>;
  const AInner: TFluentQuery<TInner>;
  const AOuterKeySelector: TFunc<TOuter, TKey>;
  const AInnerKeySelector: TFunc<TInner, TKey>;
  const AResultSelector: TFunc<TOuter, TInner, TResult>);
begin
  inherited Create;
  FOuter := AOuter;
  FInner := AInner;
  FOuterKeySelector := AOuterKeySelector;
  FInnerKeySelector := AInnerKeySelector;
  FResultSelector := AResultSelector;
  
  FExecuted := False;
  FOuterEnumerator := nil;
  FInnerLookup := nil;
  FCurrentInnerList := nil;
  FCurrentInnerIndex := -1;
end;

destructor TJoinIterator<TOuter, TInner, TKey, TResult>.Destroy;
var
  List: TList<TInner>;
begin
  if FInnerLookup <> nil then
  begin
    for List in FInnerLookup.Values do
      List.Free;
    FInnerLookup.Free;
  end;
  FOuterEnumerator.Free;
  inherited;
end;

procedure TJoinIterator<TOuter, TInner, TKey, TResult>.BuildLookup;
var
  Item: TInner;
  Key: TKey;
  List: TList<TInner>;
begin
  FInnerLookup := TDictionary<TKey, TList<TInner>>.Create;
  for Item in FInner do
  begin
    Key := FInnerKeySelector(Item);
    if not FInnerLookup.TryGetValue(Key, List) then
    begin
      List := TList<TInner>.Create;
      FInnerLookup.Add(Key, List);
    end;
    List.Add(Item);
  end;
end;

function TJoinIterator<TOuter, TInner, TKey, TResult>.MoveNextCore: Boolean;
var
  OuterItem: TOuter;
  Key: TKey;
begin
  if not FExecuted then
  begin
    BuildLookup;
    FOuterEnumerator := FOuter.GetEnumerator;
    FExecuted := True;
  end;

  // Loop until we find a match or run out of outer items
  while True do
  begin
    // If we are currently iterating a matching inner list
    if (FCurrentInnerList <> nil) and (FCurrentInnerIndex < FCurrentInnerList.Count - 1) then
    begin
      Inc(FCurrentInnerIndex);
      FCurrent := FResultSelector(FOuterEnumerator.Current, FCurrentInnerList[FCurrentInnerIndex]);
      Exit(True);
    end;

    // Need to move to next outer item
    FCurrentInnerList := nil;
    FCurrentInnerIndex := -1;

    if not FOuterEnumerator.MoveNext then
      Exit(False); // No more outer items

    OuterItem := FOuterEnumerator.Current;
    Key := FOuterKeySelector(OuterItem);

    // Check if there are matches in inner
    if FInnerLookup.TryGetValue(Key, FCurrentInnerList) then
    begin
      // Found matches, loop will continue and pick first item in inner list
      // But we need to verify list is not empty (it shouldn't be based on BuildLookup)
      if FCurrentInnerList.Count = 0 then
        FCurrentInnerList := nil;
    end;
  end;
end;

{ TJoining }

class function TJoining.Join<TOuter, TInner, TKey, TResult>(
  const Outer: TFluentQuery<TOuter>;
  const Inner: TFluentQuery<TInner>;
  const OuterKeySelector: TFunc<TOuter, TKey>;
  const InnerKeySelector: TFunc<TInner, TKey>;
  const ResultSelector: TFunc<TOuter, TInner, TResult>): TFluentQuery<TResult>;
var
  LOuter: TFluentQuery<TOuter>;
  LInner: TFluentQuery<TInner>;
begin
  LOuter := Outer;
  LInner := Inner;
  
  Result := TFluentQuery<TResult>.Create(
    function: TQueryIterator<TResult>
    begin
      Result := TJoinIterator<TOuter, TInner, TKey, TResult>.Create(
        LOuter, LInner, OuterKeySelector, InnerKeySelector, ResultSelector);
    end); 
    // If we pass Outer, it might manage lifetime. 
    // But Join depends on both. 
    // Usually TFluentQuery takes ownership of parent to keep chain alive.
    // Here we have two parents.
    // We pass Outer as parent, but we must ensure Inner is also kept alive?
    // TFluentQuery only supports one parent.
    // However, TJoinIterator holds references to both TFluentQuery objects (LOuter, LInner).
    // If LInner is a local variable in the caller, it might be freed?
    // TFluentQuery is reference counted? No, it's a class.
    // The caller usually does: Users.Join(Addresses...).
    // Users is Outer. Addresses is Inner.
    // If Addresses is created inline `Context.Entities<TAddress>.Query`, who owns it?
    // The caller owns it.
    // If we return a new Query, and the caller frees Addresses immediately...
    // We might need to clone or handle ownership.
    // For now, let's assume caller manages lifetimes or we rely on TJoinIterator keeping a reference.
    // But TJoinIterator just holds the reference.
end;

end.

