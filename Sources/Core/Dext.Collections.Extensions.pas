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
{  Created: 2025-12-10                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.Collections.Extensions;

interface

uses
  System.SysUtils,
  System.TypInfo,
  Dext.Collections,
  Dext.Specifications.Interfaces,
  Dext.Specifications.Evaluator;

type
  TListExtensions = class
  public
    class function Where<T>(const List: IList<T>; const Expression: IExpression): IList<T>; static;
    class function First<T>(const List: IList<T>; const Expression: IExpression): T; static;
    class function FirstOrDefault<T>(const List: IList<T>; const Expression: IExpression): T; static;
    class function Any<T>(const List: IList<T>; const Expression: IExpression): Boolean; static;
    class function All<T>(const List: IList<T>; const Expression: IExpression): Boolean; static;
  end;

implementation

{ TListExtensions }

class function TListExtensions.Where<T>(const List: IList<T>; const Expression: IExpression): IList<T>;
var
  Item: T;
  Obj: TObject;
begin
  Result := TCollections.CreateList<T>(False);
  
  // Evaluator only supports classes
  if PTypeInfo(TypeInfo(T)).Kind <> tkClass then
    raise Exception.Create('Expression evaluation is only supported for class types.');

  for Item in List do
  begin
    Obj := TObject(PPointer(@Item)^);
    if TExpressionEvaluator.Evaluate(Expression, Obj) then
      Result.Add(Item);
  end;
end;

class function TListExtensions.First<T>(const List: IList<T>; const Expression: IExpression): T;
var
  Item: T;
  Obj: TObject;
begin
  if PTypeInfo(TypeInfo(T)).Kind <> tkClass then
    raise Exception.Create('Expression evaluation is only supported for class types.');

  for Item in List do
  begin
    Obj := TObject(PPointer(@Item)^);
    if TExpressionEvaluator.Evaluate(Expression, Obj) then
      Exit(Item);
  end;
  raise Exception.Create('Sequence contains no matching element');
end;

class function TListExtensions.FirstOrDefault<T>(const List: IList<T>; const Expression: IExpression): T;
var
  Item: T;
  Obj: TObject;
begin
  if PTypeInfo(TypeInfo(T)).Kind <> tkClass then
    raise Exception.Create('Expression evaluation is only supported for class types.');

  for Item in List do
  begin
    Obj := TObject(PPointer(@Item)^);
    if TExpressionEvaluator.Evaluate(Expression, Obj) then
      Exit(Item);
  end;
  Result := Default(T);
end;

class function TListExtensions.Any<T>(const List: IList<T>; const Expression: IExpression): Boolean;
var
  Item: T;
  Obj: TObject;
begin
  if PTypeInfo(TypeInfo(T)).Kind <> tkClass then
    raise Exception.Create('Expression evaluation is only supported for class types.');

  Result := False;
  for Item in List do
  begin
    Obj := TObject(PPointer(@Item)^);
    if TExpressionEvaluator.Evaluate(Expression, Obj) then
      Exit(True);
  end;
end;

class function TListExtensions.All<T>(const List: IList<T>; const Expression: IExpression): Boolean;
var
  Item: T;
  Obj: TObject;
begin
  if PTypeInfo(TypeInfo(T)).Kind <> tkClass then
    raise Exception.Create('Expression evaluation is only supported for class types.');

  Result := True;
  for Item in List do
  begin
    Obj := TObject(PPointer(@Item)^);
    if not TExpressionEvaluator.Evaluate(Expression, Obj) then
      Exit(False);
  end;
end;

end.
