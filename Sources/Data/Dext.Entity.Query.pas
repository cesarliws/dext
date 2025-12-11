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
unit Dext.Entity.Query;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.Generics.Defaults,
  Dext.Collections,
  Dext.Specifications.Base, // Added for TSpecification cast
  Dext.Specifications.Interfaces;

type
  IPagedResult<T> = interface
    ['{6A8B9C0D-1E2F-3A4B-5C6D-7E8F9A0B1C2D}']
    function GetItems: IList<T>;
    function GetTotalCount: Integer;
    function GetPageNumber: Integer;
    function GetPageSize: Integer;
    function GetPageCount: Integer;
    function GetHasNextPage: Boolean;
    function GetHasPreviousPage: Boolean;
    
    property Items: IList<T> read GetItems;
    property TotalCount: Integer read GetTotalCount;
    property PageNumber: Integer read GetPageNumber;
    property PageSize: Integer read GetPageSize;
    property PageCount: Integer read GetPageCount;
    property HasNextPage: Boolean read GetHasNextPage;
    property HasPreviousPage: Boolean read GetHasPreviousPage;
  end;

  TPagedResult<T> = class(TInterfacedObject, IPagedResult<T>)
  private
    FItems: IList<T>;
    FTotalCount: Integer;
    FPageNumber: Integer;
    FPageSize: Integer;
  public
    constructor Create(AItems: IList<T>; ATotalCount, APageNumber, APageSize: Integer);
    destructor Destroy; override;
    function GetItems: IList<T>;
    function GetTotalCount: Integer;
    function GetPageNumber: Integer;
    function GetPageSize: Integer;
    function GetPageCount: Integer;
    function GetHasNextPage: Boolean;
    function GetHasPreviousPage: Boolean;
  end;

  /// <summary>
  ///   Base iterator for lazy query execution.
  ///   Inherits from TEnumerator<T> to integrate with Delphi's collection system.
  /// </summary>
  TQueryIterator<T> = class(TEnumerator<T>)
  protected
    FCurrent: T;
    function DoGetCurrent: T; override;
    function DoMoveNext: Boolean; override;
    function MoveNextCore: Boolean; virtual; abstract;
  public
    constructor Create;
  end;

  /// <summary>
  ///   Concrete type for fluent queries.
  ///   Implemented as a record for automatic lifecycle management.
  /// </summary>
  TFluentQuery<T> = record
  private
    FIteratorFactory: TFunc<TQueryIterator<T>>;
    FSpecification: ISpecification<T>; // Optional reference to the underlying spec
    procedure AssignSpecTracking(const AEnable: Boolean);
  public
    /// <summary>
    ///   Creates a new fluent query.
    /// </summary>
    constructor Create(const AIteratorFactory: TFunc<TQueryIterator<T>>); overload;
    constructor Create(const AIteratorFactory: TFunc<TQueryIterator<T>>; const ASpec: ISpecification<T>); overload;
    
    function GetEnumerator: TEnumerator<T>;
    
    /// <summary>
    ///   Projects each element of a sequence into a new form.
    /// </summary>
    function Select<TResult>(const ASelector: TFunc<T, TResult>): TFluentQuery<TResult>; overload;
    function Select<TResult>(const APropertyName: string): TFluentQuery<TResult>; overload;
    function Select(const AProperties: array of string): TFluentQuery<T>; overload;

    /// <summary>
    ///   Filters a sequence of values based on a predicate.
    /// </summary>
    function Where(const APredicate: TPredicate<T>): TFluentQuery<T>; overload;
    function Where(const AExpression: IExpression): TFluentQuery<T>; overload;

    /// <summary>
    ///   Bypasses a specified number of elements in a sequence and then returns the remaining elements.
    /// </summary>
    function Skip(const ACount: Integer): TFluentQuery<T>;

    /// <summary>
    ///   Returns a specified number of contiguous elements from the start of a sequence.
    /// </summary>
    function Take(const ACount: Integer): TFluentQuery<T>;

    /// <summary>
    ///   Force execution and return materialized list.
    /// </summary>
    function ToList: IList<T>;

    /// <summary>
    ///   Returns distinct elements from a sequence.
    /// </summary>
    function Distinct: TFluentQuery<T>;

    /// <summary>
    ///   Configures the query to not track entities in the IdentityMap.
    ///   Useful for read-only scenarios to improve performance and avoid memory overhead.
    /// </summary>
    function AsNoTracking: TFluentQuery<T>;

    // Join
    function Join<TInner, TKey, TResult>(
      const AInner: TFluentQuery<TInner>;
      const AOuterKeyProp: string;
      const AInnerKeyProp: string;
      const AResultSelector: TFunc<T, TInner, TResult>
    ): TFluentQuery<TResult>; overload;
    
    // Aggregations
    function Count: Integer; overload;
    function Count(const APredicate: TPredicate<T>): Integer; overload;
    function Any: Boolean; overload;
    function Any(const APredicate: TPredicate<T>): Boolean; overload;
    function First: T; overload;
    function First(const APredicate: TPredicate<T>): T; overload;
    function FirstOrDefault: T; overload;
    function FirstOrDefault(const APredicate: TPredicate<T>): T; overload;
    
    function Sum(const ASelector: TFunc<T, Double>): Double; overload;
    function Sum(const APropertyName: string): Double; overload;

    function Average(const ASelector: TFunc<T, Double>): Double; overload;
    function Average(const APropertyName: string): Double; overload;
    
    function Min(const ASelector: TFunc<T, Double>): Double; overload;
    function Min(const APropertyName: string): Double; overload;
    
    function Max(const ASelector: TFunc<T, Double>): Double; overload;
    function Max(const APropertyName: string): Double; overload;

    /// <summary>
    /// </summary>
    function Paginate(const APageNumber, APageSize: Integer): IPagedResult<T>;
  end;

  /// <summary>
  ///   Iterator that executes a specification-based query.
  /// </summary>
  TSpecificationQueryIterator<T> = class(TQueryIterator<T>)
  private
    FGetList: TFunc<IList<T>>;
    FList: IList<T>;
    FIndex: Integer;
    FExecuted: Boolean;
  protected
    function MoveNextCore: Boolean; override;
  public
    constructor Create(const AGetList: TFunc<IList<T>>);
    destructor Destroy; override;
    function Clone: TQueryIterator<T>;
    
    // Allows TFluentQuery to grab the underlying list for optimization
    function GetList: IList<T>;
  end;

  TProjectingIterator<TSource, TResult> = class(TQueryIterator<TResult>)
  private
    FSource: TFluentQuery<TSource>;
    FSelector: TFunc<TSource, TResult>;
    FEnumerator: TEnumerator<TSource>;
  protected
    function MoveNextCore: Boolean; override;
  public
    constructor Create(const ASource: TFluentQuery<TSource>; const ASelector: TFunc<TSource, TResult>);
    destructor Destroy; override;
  end;

  /// <summary>
  ///   Iterator that filters elements based on a predicate.
  /// </summary>
  TFilteringIterator<T> = class(TQueryIterator<T>)
  private
    FSource: TFluentQuery<T>;
    FPredicate: TPredicate<T>;
    FEnumerator: TEnumerator<T>;
  protected
    function MoveNextCore: Boolean; override;
  public
    constructor Create(const ASource: TFluentQuery<T>; const APredicate: TPredicate<T>);
    destructor Destroy; override;
  end;

  /// <summary>
  ///   Iterator that skips a specified number of elements.
  /// </summary>
  TSkipIterator<T> = class(TQueryIterator<T>)
  private
    FSource: TFluentQuery<T>;
    FCount: Integer;
    FEnumerator: TEnumerator<T>;
    FIndex: Integer;
  protected
    function MoveNextCore: Boolean; override;
  public
    constructor Create(const ASource: TFluentQuery<T>; const ACount: Integer);
    destructor Destroy; override;
  end;

  /// <summary>
  ///   Iterator that takes a specified number of elements.
  /// </summary>
  TTakeIterator<T> = class(TQueryIterator<T>)
  private
    FSource: TFluentQuery<T>;
    FCount: Integer;
    FEnumerator: TEnumerator<T>;
    FIndex: Integer;
  protected
    function MoveNextCore: Boolean; override;
  public
    constructor Create(const ASource: TFluentQuery<T>; const ACount: Integer);
    destructor Destroy; override;
  end;

  /// <summary>
  ///   Iterator that returns distinct elements.
  /// </summary>
  TDistinctIterator<T> = class(TQueryIterator<T>)
  private
    FSource: TFluentQuery<T>;
    FEnumerator: TEnumerator<T>;
    FSeen: TDictionary<T, Byte>;
  protected
    function MoveNextCore: Boolean; override;
  public
    constructor Create(const ASource: TFluentQuery<T>);
    destructor Destroy; override;
  end;

  TEmptyIterator<T> = class(TQueryIterator<T>)
  protected
    function MoveNextCore: Boolean; override;
  end;

implementation

uses
  System.Rtti,
  System.TypInfo,
  System.Variants,
  Dext.Specifications.Evaluator,
  Dext.Entity.Joining;

{ TEmptyIterator<T> }

function TEmptyIterator<T>.MoveNextCore: Boolean;
begin
  Result := False;
end;

{ TPagedResult<T> }

constructor TPagedResult<T>.Create(AItems: IList<T>; ATotalCount, APageNumber, APageSize: Integer);
begin
  inherited Create;
  FItems := AItems;
  FTotalCount := ATotalCount;
  FPageNumber := APageNumber;
  FPageSize := APageSize;
end;

destructor TPagedResult<T>.Destroy;
begin
  inherited;
end;

function TPagedResult<T>.GetItems: IList<T>;
begin
  Result := FItems;
end;

function TPagedResult<T>.GetTotalCount: Integer;
begin
  Result := FTotalCount;
end;

function TPagedResult<T>.GetPageNumber: Integer;
begin
  Result := FPageNumber;
end;

function TPagedResult<T>.GetPageSize: Integer;
begin
  Result := FPageSize;
end;

function TPagedResult<T>.GetPageCount: Integer;
begin
  if FPageSize <= 0 then Exit(0);
  Result := (FTotalCount + FPageSize - 1) div FPageSize;
end;

function TPagedResult<T>.GetHasNextPage: Boolean;
begin
  Result := FPageNumber < GetPageCount;
end;

function TPagedResult<T>.GetHasPreviousPage: Boolean;
begin
  Result := FPageNumber > 1;
end;

{ TQueryIterator<T> }

constructor TQueryIterator<T>.Create;
begin
  inherited Create;
end;

function TQueryIterator<T>.DoGetCurrent: T;
begin
  Result := FCurrent;
end;

function TQueryIterator<T>.DoMoveNext: Boolean;
begin
  Result := MoveNextCore;
end;

{ TFluentQuery<T> }

constructor TFluentQuery<T>.Create(const AIteratorFactory: TFunc<TQueryIterator<T>>);
begin
  FIteratorFactory := AIteratorFactory;
  FSpecification := nil;
end;

constructor TFluentQuery<T>.Create(const AIteratorFactory: TFunc<TQueryIterator<T>>; const ASpec: ISpecification<T>);
begin
  FIteratorFactory := AIteratorFactory;
  FSpecification := ASpec;
end;

function TFluentQuery<T>.GetEnumerator: TEnumerator<T>;
begin
  if Assigned(FIteratorFactory) then
     Result := FIteratorFactory()
  else
     Result := TEmptyIterator<T>.Create;
end;

procedure TFluentQuery<T>.AssignSpecTracking(const AEnable: Boolean);
begin
  if FSpecification <> nil then
  begin
    if AEnable then 
      FSpecification.EnableTracking(True)
    else 
      FSpecification.AsNoTracking;
  end;
end;

function TFluentQuery<T>.AsNoTracking: TFluentQuery<T>;
begin
  // Set the flag on the specification if available
  AssignSpecTracking(False);
  
  // Return self (record copy) with the modified state
  // Since Specification is a reference type (interface/object), the change persists
  Result := Self;
end;

function TFluentQuery<T>.Select<TResult>(const ASelector: TFunc<T, TResult>): TFluentQuery<TResult>;
var
  LSource: TFluentQuery<T>;
begin
  LSource := Self;
  Result := TFluentQuery<TResult>.Create(
    function: TQueryIterator<TResult>
    begin
      Result := TProjectingIterator<T, TResult>.Create(LSource, ASelector);
    end);
end;

function TFluentQuery<T>.Select<TResult>(const APropertyName: string): TFluentQuery<TResult>;
var
  LSource: TFluentQuery<T>;
  Selector: TFunc<T, TResult>;
begin
  LSource := Self;
  Selector := TFunc<T, TResult>(function(const Item: T): TResult
    var
      Ctx: TRttiContext;
      Typ: TRttiType;
      Prop: TRttiProperty;
      Val: TValue;
      Obj: TObject;
    begin
      Obj := TValue.From<T>(Item).AsObject;
      if Obj = nil then raise Exception.Create('Item is not an object');
      
      Ctx := TRttiContext.Create;
      Typ := Ctx.GetType(Obj.ClassType);
      Prop := Typ.GetProperty(APropertyName);
      if Prop = nil then
        raise Exception.CreateFmt('Property "%s" not found on class "%s"', [APropertyName, Obj.ClassName]);
      Val := Prop.GetValue(Obj);
      Result := Val.AsType<TResult>;
    end);

  Result := TFluentQuery<TResult>.Create(
    function: TQueryIterator<TResult>
    begin
      Result := TProjectingIterator<T, TResult>.Create(LSource, Selector);
    end);
end;

function TFluentQuery<T>.Select(const AProperties: array of string): TFluentQuery<T>;
var
  LProperties: TArray<string>;
  LSource: TFluentQuery<T>;
begin
  SetLength(LProperties, Length(AProperties));
  if Length(AProperties) > 0 then
    Move(AProperties[0], LProperties[0], Length(AProperties) * SizeOf(string));

  LSource := Self;
  Result := TFluentQuery<T>.Create(
    function: TQueryIterator<T>
    begin
      Result := TProjectingIterator<T, T>.Create(LSource, 
        TFunc<T, T>(function(const Source: T): T
        var
          Ctx: TRttiContext;
          Typ: TRttiType;
          Prop: TRttiProperty;
          Val: TValue;
          ObjSource, ObjDest: TObject;
          PropName: string;
        begin
          Ctx := TRttiContext.Create;
          Typ := Ctx.GetType(TypeInfo(T));
          
          if Typ.TypeKind = tkClass then
          begin
             ObjDest := Typ.AsInstance.MetaclassType.Create;
             ObjSource := TValue.From<T>(Source).AsObject;
             
             for PropName in LProperties do
             begin
               Prop := Typ.GetProperty(PropName);
               if Prop <> nil then
               begin
                 Val := Prop.GetValue(ObjSource);
                 if Prop.IsWritable then
                   Prop.SetValue(ObjDest, Val);
               end;
             end;
             
             Result := Default(T);
             Move(ObjDest, Result, SizeOf(Pointer));
          end
          else
            raise Exception.Create('Select with properties only supports classes');
        end));
    end);
end;

function TFluentQuery<T>.Where(const APredicate: TPredicate<T>): TFluentQuery<T>;
var
  LSource: TFluentQuery<T>;
begin
  LSource := Self;
  Result := TFluentQuery<T>.Create(
    function: TQueryIterator<T>
    begin
      Result := TFilteringIterator<T>.Create(LSource, APredicate);
    end);
end;

function TFluentQuery<T>.Where(const AExpression: IExpression): TFluentQuery<T>;
begin
  Result := Where(AExpression);
end;

function TFluentQuery<T>.Skip(const ACount: Integer): TFluentQuery<T>;
var
  LSource: TFluentQuery<T>;
begin
  LSource := Self;
  Result := TFluentQuery<T>.Create(
    function: TQueryIterator<T>
    begin
      Result := TSkipIterator<T>.Create(LSource, ACount);
    end);
end;

function TFluentQuery<T>.Take(const ACount: Integer): TFluentQuery<T>;
var
  LSource: TFluentQuery<T>;
begin
  LSource := Self;
  Result := TFluentQuery<T>.Create(
    function: TQueryIterator<T>
    begin
      Result := TTakeIterator<T>.Create(LSource, ACount);
    end);
end;

function TFluentQuery<T>.ToList: IList<T>;
var
  Enumerator: TEnumerator<T>;
  OwnsObjects: Boolean;
begin
  // DEFAULT BEHAVIOR:
  // Usually, objects are owned by IdentityMap (Tracking=True), so List should NOT own them (OwnsObjects=False).
  // IF AsNoTracking is enabled, entities are NOT in IdentityMap.
  // Therefore, the List MUST own them to avoid memory leaks.
  
  // Checking implicit ownership requirement
  OwnsObjects := False;
  if (FSpecification <> nil) and (not FSpecification.IsTrackingEnabled) then
    OwnsObjects := True;

  // Optimization: If the iterator is a TSpecificationQueryIterator, 
  // we can just steal the list it produced (which already has correct ownership settings).
  // This avoids a copy AND solves the double-free issue where iterator frees the list which frees objects.
  Enumerator := GetEnumerator;
  try
    if Enumerator is TSpecificationQueryIterator<T> then
    begin
      Result := TSpecificationQueryIterator<T>(Enumerator).GetList;
      Exit;
    end;
    
    // Fallback for filtered/projected queries
    Result := TCollections.CreateList<T>(OwnsObjects);
    try
      while Enumerator.MoveNext do
        Result.Add(Enumerator.Current);
    except
      // If exception happens, result list is freed. 
      // If OwnsObjects=True, it frees *its copy* of references. 
      // The Enumerator also holds references. Lifecycle is complex here but standard exception handling applies.
      Result := nil;
      raise;
    end;
  finally
    Enumerator.Free;
  end;
end;

function TFluentQuery<T>.Distinct: TFluentQuery<T>;
var
  LSource: TFluentQuery<T>;
begin
  LSource := Self;
  Result := TFluentQuery<T>.Create(
    function: TQueryIterator<T>
    begin
      Result := TDistinctIterator<T>.Create(LSource);
    end);
end;

function TFluentQuery<T>.Join<TInner, TKey, TResult>(
  const AInner: TFluentQuery<TInner>;
  const AOuterKeyProp: string;
  const AInnerKeyProp: string;
  const AResultSelector: TFunc<T, TInner, TResult>): TFluentQuery<TResult>;
var
  OuterSelector: TFunc<T, TKey>;
  InnerSelector: TFunc<TInner, TKey>;
begin
  OuterSelector := TFunc<T, TKey>(function(const Item: T): TKey
    var
      Ctx: TRttiContext;
      Obj: TObject;
      Prop: TRttiProperty;
    begin
      Obj := TValue.From<T>(Item).AsObject;
      Ctx := TRttiContext.Create;
      Prop := Ctx.GetType(Obj.ClassType).GetProperty(AOuterKeyProp);
      if Prop = nil then
        raise Exception.CreateFmt('Property "%s" not found on outer type', [AOuterKeyProp]);
      Result := Prop.GetValue(Obj).AsType<TKey>;
    end);
    
  InnerSelector := TFunc<TInner, TKey>(function(const Item: TInner): TKey
    var
      Ctx: TRttiContext;
      Obj: TObject;
      Prop: TRttiProperty;
    begin
      Obj := TValue.From<TInner>(Item).AsObject;
      Ctx := TRttiContext.Create;
      Prop := Ctx.GetType(Obj.ClassType).GetProperty(AInnerKeyProp);
      if Prop = nil then
        raise Exception.CreateFmt('Property "%s" not found on inner type', [AInnerKeyProp]);
      Result := Prop.GetValue(Obj).AsType<TKey>;
    end);

  Result := TJoining.Join<T, TInner, TKey, TResult>(
    Self, AInner, OuterSelector, InnerSelector, AResultSelector);
end;

function TFluentQuery<T>.Count: Integer;
var
  Enumerator: TEnumerator<T>;
begin
  Result := 0;
  Enumerator := GetEnumerator;
  try
    while Enumerator.MoveNext do
      Inc(Result);
  finally
    Enumerator.Free;
  end;
end;

function TFluentQuery<T>.Count(const APredicate: TPredicate<T>): Integer;
var
  Enumerator: TEnumerator<T>;
begin
  Result := 0;
  Enumerator := GetEnumerator;
  try
    while Enumerator.MoveNext do
      if APredicate(Enumerator.Current) then
        Inc(Result);
  finally
    Enumerator.Free;
  end;
end;

function TFluentQuery<T>.Any: Boolean;
var
  Enumerator: TEnumerator<T>;
begin
  Enumerator := GetEnumerator;
  try
    Result := Enumerator.MoveNext;
  finally
    Enumerator.Free;
  end;
end;

function TFluentQuery<T>.Any(const APredicate: TPredicate<T>): Boolean;
var
  Enumerator: TEnumerator<T>;
begin
  Result := False;
  Enumerator := GetEnumerator;
  try
    while Enumerator.MoveNext do
      if APredicate(Enumerator.Current) then
      begin
        Result := True;
        Break;
      end;
  finally
    Enumerator.Free;
  end;
end;

function TFluentQuery<T>.First: T;
var
  Enumerator: TEnumerator<T>;
begin
  Enumerator := GetEnumerator;
  try
    if Enumerator.MoveNext then
      Result := Enumerator.Current
    else
      raise Exception.Create('Sequence contains no elements');
  finally
    Enumerator.Free;
  end;
end;

function TFluentQuery<T>.First(const APredicate: TPredicate<T>): T;
var
  Enumerator: TEnumerator<T>;
begin
  Enumerator := GetEnumerator;
  try
    while Enumerator.MoveNext do
      if APredicate(Enumerator.Current) then
        Exit(Enumerator.Current);
  finally
    Enumerator.Free;
  end;
  raise Exception.Create('Sequence contains no matching element');
end;

function TFluentQuery<T>.FirstOrDefault: T;
var
  Enumerator: TEnumerator<T>;
begin
  Enumerator := GetEnumerator;
  try
    if Enumerator.MoveNext then
      Result := Enumerator.Current
    else
      Result := Default(T);
  finally
    Enumerator.Free;
  end;
end;

function TFluentQuery<T>.FirstOrDefault(const APredicate: TPredicate<T>): T;
var
  Enumerator: TEnumerator<T>;
begin
  Enumerator := GetEnumerator;
  try
    while Enumerator.MoveNext do
      if APredicate(Enumerator.Current) then
        Exit(Enumerator.Current);
  finally
    Enumerator.Free;
  end;
  Result := Default(T);
end;

function TFluentQuery<T>.Sum(const ASelector: TFunc<T, Double>): Double;
var
  Enumerator: TEnumerator<T>;
begin
  Result := 0;
  Enumerator := GetEnumerator;
  try
    while Enumerator.MoveNext do
      Result := Result + ASelector(Enumerator.Current);
  finally
    Enumerator.Free;
  end;
end;

function TFluentQuery<T>.Sum(const APropertyName: string): Double;
var
  Enumerator: TEnumerator<T>;
  Val: Double;
  Ctx: TRttiContext;
  Obj: TObject;
  Prop: TRttiProperty;
begin
  Result := 0;
  Ctx := TRttiContext.Create;
  Enumerator := GetEnumerator;
  try
    while Enumerator.MoveNext do
    begin
      Obj := TValue.From<T>(Enumerator.Current).AsObject;
      if Obj = nil then raise Exception.Create('Item is not an object');
      
      Prop := Ctx.GetType(Obj.ClassType).GetProperty(APropertyName);
      if Prop = nil then
        raise Exception.CreateFmt('Property "%s" not found on class "%s"', [APropertyName, Obj.ClassName]);
        
      Val := Prop.GetValue(Obj).AsType<Double>;
      Result := Result + Val;
    end;
  finally
    Enumerator.Free;
  end;
end;

function TFluentQuery<T>.Average(const ASelector: TFunc<T, Double>): Double;
var
  Enumerator: TEnumerator<T>;
  SumVal: Double;
  CountVal: Integer;
begin
  SumVal := 0;
  CountVal := 0;
  Enumerator := GetEnumerator;
  try
    while Enumerator.MoveNext do
    begin
      SumVal := SumVal + ASelector(Enumerator.Current);
      Inc(CountVal);
    end;
  finally
    Enumerator.Free;
  end;
  
  if CountVal = 0 then
    raise Exception.Create('Sequence contains no elements');
    
  Result := SumVal / CountVal;
end;

function TFluentQuery<T>.Average(const APropertyName: string): Double;
var
  Enumerator: TEnumerator<T>;
  Val: Double;
  SumVal: Double;
  CountVal: Integer;
  Ctx: TRttiContext;
  Obj: TObject;
  Prop: TRttiProperty;
begin
  SumVal := 0;
  CountVal := 0;
  Ctx := TRttiContext.Create;
  Enumerator := GetEnumerator;
  try
    while Enumerator.MoveNext do
    begin
      Obj := TValue.From<T>(Enumerator.Current).AsObject;
      if Obj = nil then raise Exception.Create('Item is not an object');
      
      Prop := Ctx.GetType(Obj.ClassType).GetProperty(APropertyName);
      if Prop = nil then
        raise Exception.CreateFmt('Property "%s" not found on class "%s"', [APropertyName, Obj.ClassName]);
        
      Val := Prop.GetValue(Obj).AsType<Double>;
      SumVal := SumVal + Val;
      Inc(CountVal);
    end;
  finally
    Enumerator.Free;
  end;
  
  if CountVal = 0 then
    raise Exception.Create('Sequence contains no elements');
    
  Result := SumVal / CountVal;
end;

function TFluentQuery<T>.Min(const ASelector: TFunc<T, Double>): Double;
var
  Enumerator: TEnumerator<T>;
  Val: Double;
  HasValue: Boolean;
begin
  HasValue := False;
  Result := 0;
  Enumerator := GetEnumerator;
  try
    if Enumerator.MoveNext then
    begin
      Result := ASelector(Enumerator.Current);
      HasValue := True;
      
      while Enumerator.MoveNext do
      begin
        Val := ASelector(Enumerator.Current);
        if Val < Result then Result := Val;
      end;
    end;
  finally
    Enumerator.Free;
  end;
  
  if not HasValue then
    raise Exception.Create('Sequence contains no elements');
end;

function TFluentQuery<T>.Min(const APropertyName: string): Double;
var
  Enumerator: TEnumerator<T>;
  Val: Double;
  HasValue: Boolean;
  Ctx: TRttiContext;
  Obj: TObject;
  Prop: TRttiProperty;
begin
  HasValue := False;
  Result := 0;
  Ctx := TRttiContext.Create;
  Enumerator := GetEnumerator;
  try
    if Enumerator.MoveNext then
    begin
      Obj := TValue.From<T>(Enumerator.Current).AsObject;
      if Obj = nil then raise Exception.Create('Item is not an object');
      Prop := Ctx.GetType(Obj.ClassType).GetProperty(APropertyName);
      
      Val := Prop.GetValue(Obj).AsType<Double>;
      Result := Val;
      HasValue := True;
      
      while Enumerator.MoveNext do
      begin
        Obj := TValue.From<T>(Enumerator.Current).AsObject;
        Val := Prop.GetValue(Obj).AsType<Double>;
        if Val < Result then Result := Val;
      end;
    end;
  finally
    Enumerator.Free;
  end;
  
  if not HasValue then
    raise Exception.Create('Sequence contains no elements');
end;

function TFluentQuery<T>.Max(const ASelector: TFunc<T, Double>): Double;
var
  Enumerator: TEnumerator<T>;
  Val: Double;
  HasValue: Boolean;
begin
  HasValue := False;
  Result := 0;
  Enumerator := GetEnumerator;
  try
    if Enumerator.MoveNext then
    begin
      Result := ASelector(Enumerator.Current);
      HasValue := True;
      
      while Enumerator.MoveNext do
      begin
        Val := ASelector(Enumerator.Current);
        if Val > Result then Result := Val;
      end;
    end;
  finally
    Enumerator.Free;
  end;
  
  if not HasValue then
    raise Exception.Create('Sequence contains no elements');
end;

function TFluentQuery<T>.Max(const APropertyName: string): Double;
var
  Enumerator: TEnumerator<T>;
  Val: Double;
  HasValue: Boolean;
  Ctx: TRttiContext;
  Obj: TObject;
  Prop: TRttiProperty;
begin
  HasValue := False;
  Result := 0;
  Ctx := TRttiContext.Create;
  Enumerator := GetEnumerator;
  try
    if Enumerator.MoveNext then
    begin
      Obj := TValue.From<T>(Enumerator.Current).AsObject;
      if Obj = nil then raise Exception.Create('Item is not an object');
      Prop := Ctx.GetType(Obj.ClassType).GetProperty(APropertyName);
      
      Val := Prop.GetValue(Obj).AsType<Double>;
      Result := Val;
      HasValue := True;
      
      while Enumerator.MoveNext do
      begin
        Obj := TValue.From<T>(Enumerator.Current).AsObject;
        Val := Prop.GetValue(Obj).AsType<Double>;
        if Val > Result then Result := Val;
      end;
    end;
  finally
    Enumerator.Free;
  end;
  
  if not HasValue then
    raise Exception.Create('Sequence contains no elements');
end;

function TFluentQuery<T>.Paginate(const APageNumber, APageSize: Integer): IPagedResult<T>;
var
  SkipCount: Integer;
  Total: Integer;
  Items: IList<T>;
begin
  if APageNumber < 1 then raise Exception.Create('PageNumber must be >= 1');
  if APageSize < 1 then raise Exception.Create('PageSize must be >= 1');
  
  Total := Self.Count;
  SkipCount := (APageNumber - 1) * APageSize;
  
  Items := Self.Skip(SkipCount).Take(APageSize).ToList;
  
  Result := TPagedResult<T>.Create(Items, Total, APageNumber, APageSize);
end;

{ TSpecificationQueryIterator<T> }

constructor TSpecificationQueryIterator<T>.Create(const AGetList: TFunc<IList<T>>);
begin
  inherited Create;
  FGetList := AGetList;
  FIndex := -1;
  FExecuted := False;
  FList := nil; 
end;

destructor TSpecificationQueryIterator<T>.Destroy;
begin
  inherited;
end;

function TSpecificationQueryIterator<T>.Clone: TQueryIterator<T>;
begin
  Result := TSpecificationQueryIterator<T>.Create(FGetList);
end;

function TSpecificationQueryIterator<T>.GetList: IList<T>;
begin
  if not FExecuted then
  begin
    FList := FGetList();
    FExecuted := True;
    FIndex := -1;
  end;
  Result := FList;
end;

function TSpecificationQueryIterator<T>.MoveNextCore: Boolean;
begin
  if not FExecuted then
  begin
    // Trigger execution
    GetList;
  end;
  
  Inc(FIndex);
  if (FList <> nil) and (FIndex < FList.Count) then
  begin
    FCurrent := FList[FIndex];
    Result := True;
  end
  else
    Result := False;
end;

{ TProjectingIterator<TSource, TResult> }

constructor TProjectingIterator<TSource, TResult>.Create(const ASource: TFluentQuery<TSource>;
  const ASelector: TFunc<TSource, TResult>);
begin
  inherited Create;
  FSource := ASource;
  FSelector := ASelector;
  FEnumerator := FSource.GetEnumerator;
end;

destructor TProjectingIterator<TSource, TResult>.Destroy;
begin
  FEnumerator.Free;
  inherited;
end;

function TProjectingIterator<TSource, TResult>.MoveNextCore: Boolean;
begin
  if FEnumerator.MoveNext then
  begin
    FCurrent := FSelector(FEnumerator.Current);
    Result := True;
  end
  else
    Result := False;
end;

{ TFilteringIterator<T> }

constructor TFilteringIterator<T>.Create(const ASource: TFluentQuery<T>;
  const APredicate: TPredicate<T>);
begin
  inherited Create;
  FSource := ASource;
  FPredicate := APredicate;
  FEnumerator := FSource.GetEnumerator;
end;

destructor TFilteringIterator<T>.Destroy;
begin
  FEnumerator.Free;
  inherited;
end;

function TFilteringIterator<T>.MoveNextCore: Boolean;
begin
  while FEnumerator.MoveNext do
  begin
    if FPredicate(FEnumerator.Current) then
    begin
      FCurrent := FEnumerator.Current;
      Exit(True);
    end;
  end;
  Result := False;
end;

{ TSkipIterator<T> }

constructor TSkipIterator<T>.Create(const ASource: TFluentQuery<T>; const ACount: Integer);
begin
  inherited Create;
  FSource := ASource;
  FCount := ACount;
  FEnumerator := FSource.GetEnumerator;
  FIndex := 0;
end;

destructor TSkipIterator<T>.Destroy;
begin
  FEnumerator.Free;
  inherited;
end;

function TSkipIterator<T>.MoveNextCore: Boolean;
begin
  // First time filtering
  while FIndex < FCount do
  begin
    if not FEnumerator.MoveNext then Exit(False);
    Inc(FIndex);
  end;
  
  if FEnumerator.MoveNext then
  begin
    FCurrent := FEnumerator.Current;
    Result := True;
  end
  else
    Result := False;
end;

{ TTakeIterator<T> }

constructor TTakeIterator<T>.Create(const ASource: TFluentQuery<T>; const ACount: Integer);
begin
  inherited Create;
  FSource := ASource;
  FCount := ACount;
  FEnumerator := FSource.GetEnumerator;
  FIndex := 0;
end;

destructor TTakeIterator<T>.Destroy;
begin
  FEnumerator.Free;
  inherited;
end;

function TTakeIterator<T>.MoveNextCore: Boolean;
begin
  if FIndex >= FCount then Exit(False);
  
  if FEnumerator.MoveNext then
  begin
    FCurrent := FEnumerator.Current;
    Inc(FIndex);
    Result := True;
  end
  else
    Result := False;
end;

{ TDistinctIterator<T> }

constructor TDistinctIterator<T>.Create(const ASource: TFluentQuery<T>);
begin
  inherited Create;
  FSource := ASource;
  FEnumerator := FSource.GetEnumerator;
  FSeen := TDictionary<T, Byte>.Create; 
end;

destructor TDistinctIterator<T>.Destroy;
begin
  FSeen.Free;
  FEnumerator.Free;
  inherited;
end;

function TDistinctIterator<T>.MoveNextCore: Boolean;
begin
  while FEnumerator.MoveNext do
  begin
    if not FSeen.ContainsKey(FEnumerator.Current) then
    begin
      FSeen.Add(FEnumerator.Current, 0);
      FCurrent := FEnumerator.Current;
      Exit(True);
    end;
  end;
  Result := False;
end;

end.

