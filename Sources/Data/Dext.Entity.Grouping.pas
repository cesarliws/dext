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
unit Dext.Entity.Grouping;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Dext.Collections,
  Dext.Entity.Query;

type
  /// <summary>
  ///   Represents a collection of objects that have a common key.
  /// </summary>
  IGrouping<TKey, T> = interface
    ['{9A8B7C6D-5E4F-3A2B-1C0D-9E8F7A6B5C4D}']
    function GetKey: TKey;
    function GetEnumerator: TEnumerator<T>;
    property Key: TKey read GetKey;
  end;

  TGrouping<TKey, T> = class(TInterfacedObject, IGrouping<TKey, T>)
  private
    type
      TIListEnumeratorWrapper = class(TEnumerator<T>)
      private
        FEnumerator: IEnumerator<T>;
      protected
        function DoGetCurrent: T; override;
        function DoMoveNext: Boolean; override;
      public
        constructor Create(const AEnumerator: IEnumerator<T>);
      end;
  private
    FKey: TKey;
    FItems: IList<T>;  // Changed to IList<T>
  public
    constructor Create(const AKey: TKey);
    destructor Destroy; override;
    procedure Add(const AItem: T);
    function GetKey: TKey;
    function GetEnumerator: TEnumerator<T>;
    property Key: TKey read GetKey;
  end;

  /// <summary>
  ///   Iterator that groups elements.
  /// </summary>
  TGroupByIterator<TKey, T> = class(TQueryIterator<IGrouping<TKey, T>>)
  private
    FSource: TFluentQuery<T>;
    FKeySelector: TFunc<T, TKey>;
    FGroups: TList<IGrouping<TKey, T>>;
    FIndex: Integer;
    FExecuted: Boolean;
  protected
    function MoveNextCore: Boolean; override;
  public
    constructor Create(const ASource: TFluentQuery<T>; const AKeySelector: TFunc<T, TKey>);
    destructor Destroy; override;
  end;

  /// <summary>
  ///   Static class for query operations.
  /// </summary>
  TQuery = class
  public
    /// <summary>
    ///   Groups the elements of a sequence according to a specified key selector function.
    /// </summary>
    class function GroupBy<T, TKey>(const Source: TFluentQuery<T>; const KeySelector: TFunc<T, TKey>): TFluentQuery<IGrouping<TKey, T>>;
  end;

implementation

{ TGrouping<TKey, T> }

constructor TGrouping<TKey, T>.Create(const AKey: TKey);
begin
  inherited Create;
  FKey := AKey;
  // Objects are owned by IdentityMap, not by this list
  FItems := TCollections.CreateList<T>(False);
end;

destructor TGrouping<TKey, T>.Destroy;
begin
  // FItems is interface, no need to Free
  inherited;
end;

procedure TGrouping<TKey, T>.Add(const AItem: T);
begin
  FItems.Add(AItem);
end;

function TGrouping<TKey, T>.GetKey: TKey;
begin
  Result := FKey;
end;

function TGrouping<TKey, T>.GetEnumerator: TEnumerator<T>;
begin
  Result := TIListEnumeratorWrapper.Create(FItems.GetEnumerator);
end;

{ TGrouping<TKey, T>.TIListEnumeratorWrapper }

constructor TGrouping<TKey, T>.TIListEnumeratorWrapper.Create(const AEnumerator: IEnumerator<T>);
begin
  inherited Create;
  FEnumerator := AEnumerator;
end;

function TGrouping<TKey, T>.TIListEnumeratorWrapper.DoGetCurrent: T;
begin
  Result := FEnumerator.Current;
end;

function TGrouping<TKey, T>.TIListEnumeratorWrapper.DoMoveNext: Boolean;
begin
  Result := FEnumerator.MoveNext;
end;

{ TGroupByIterator<TKey, T> }

constructor TGroupByIterator<TKey, T>.Create(const ASource: TFluentQuery<T>; const AKeySelector: TFunc<T, TKey>);
begin
  inherited Create;
  FSource := ASource;
  FKeySelector := AKeySelector;
  FGroups := nil;
  FIndex := -1;
  FExecuted := False;
end;

destructor TGroupByIterator<TKey, T>.Destroy;
begin
  FGroups.Free;
  inherited;
end;

function TGroupByIterator<TKey, T>.MoveNextCore: Boolean;
var
  Dict: TDictionary<TKey, TGrouping<TKey, T>>;
  Item: T;
  Key: TKey;
  ConcreteGroup: TGrouping<TKey, T>;
  Enumerator: TEnumerator<T>;
begin
  if not FExecuted then
  begin
    FGroups := TList<IGrouping<TKey, T>>.Create; // Owns interfaces by ref counting
    Dict := TDictionary<TKey, TGrouping<TKey, T>>.Create;
    try
      Enumerator := FSource.GetEnumerator;
      try
        while Enumerator.MoveNext do
        begin
          Item := Enumerator.Current;
          Key := FKeySelector(Item);
          if not Dict.TryGetValue(Key, ConcreteGroup) then
          begin
            ConcreteGroup := TGrouping<TKey, T>.Create(Key);
            Dict.Add(Key, ConcreteGroup);
            FGroups.Add(ConcreteGroup);
          end;
          ConcreteGroup.Add(Item);
        end;
      finally
        Enumerator.Free;
      end;
    finally
      Dict.Free;
    end;
    FExecuted := True;
  end;
  
  Inc(FIndex);
  Result := (FGroups <> nil) and (FIndex < FGroups.Count);
  
  if Result then
    FCurrent := FGroups[FIndex]
  else
    FCurrent := nil;
end;

{ TQuery }

class function TQuery.GroupBy<T, TKey>(const Source: TFluentQuery<T>; const KeySelector: TFunc<T, TKey>): TFluentQuery<IGrouping<TKey, T>>;
var
  LSource: TFluentQuery<T>;
begin
  LSource := Source;
  Result := TFluentQuery<IGrouping<TKey, T>>.Create(
    function: TQueryIterator<IGrouping<TKey, T>>
    begin
      Result := TGroupByIterator<TKey, T>.Create(LSource, KeySelector);
    end);
end;

end.

