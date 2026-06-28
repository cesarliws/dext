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
unit Dext.Specifications.Fluent;

interface

uses
  Dext.Specifications.Base,
  Dext.Specifications.Interfaces,
  Dext.Specifications.OrderBy,
  Dext.Specifications.Types;

type
  /// <summary>
  ///   Managed record for fluent specification building with automatic cleanup.
  ///   Usage: Specification.Where<TUser>(UserEntity.Age >= 18)
  /// </summary>
  TSpecificationBuilder<T: class> = record
  private
    FSpec: ISpecification<T>;
    function GetSpec: ISpecification<T>;
    function GetExpression: IExpression;
    function SpecObj: TSpecification<T>; inline;
  public
    class operator Implicit(const Value: TSpecificationBuilder<T>): ISpecification<T>; inline;

    // Fluent methods
    function Where(const AExpression: IExpression): TSpecificationBuilder<T>; inline;
    function OrderBy(const AProp: TPropExpression; AAscending: Boolean = True): TSpecificationBuilder<T>; overload; inline;
    function OrderBy(const AOrderBy: IOrderBy): TSpecificationBuilder<T>; overload; inline;
    function Skip(ACount: Integer): TSpecificationBuilder<T>; inline;
    function Take(ACount: Integer): TSpecificationBuilder<T>; inline;
    function Include(const AProp: TPropExpression): TSpecificationBuilder<T>; overload; inline;
    function Include(const AProps: array of TPropExpression): TSpecificationBuilder<T>; overload;
    function Select(const AProp: TPropExpression): TSpecificationBuilder<T>; overload; inline;
    function Select(const AProps: array of TPropExpression): TSpecificationBuilder<T>; overload;
    function Select(const AColumns: TArray<string>): TSpecificationBuilder<T>; overload;
    
    property Spec: ISpecification<T> read GetSpec;
    property Expression: IExpression read GetExpression;
  end;

  /// <summary>
  ///   Static factory for creating specification builders
  /// </summary>
  Specification = record
    class function Where<T: class>(const AExpression: IExpression): TSpecificationBuilder<T>; static; inline;
    class function OrderBy<T: class>(const APropertyName: string; AAscending: Boolean = True): TSpecificationBuilder<T>; static; inline;
    class function All<T: class>: TSpecificationBuilder<T>; static; inline;
  end;

implementation

{ TSpecificationBuilder<T> }

function TSpecificationBuilder<T>.GetSpec: ISpecification<T>;
begin
  if FSpec = nil then
    FSpec := TSpecification<T>.Create;
  Result := FSpec;
end;

function TSpecificationBuilder<T>.GetExpression: IExpression;
begin
  Result := GetSpec.GetExpression;
end;

class operator TSpecificationBuilder<T>.Implicit(const Value: TSpecificationBuilder<T>): ISpecification<T>;
begin
  Result := Value.GetSpec;
end;

function TSpecificationBuilder<T>.Where(const AExpression: IExpression): TSpecificationBuilder<T>;
begin
  SpecObj.Where(AExpression);
  Result := Self;
end;



function TSpecificationBuilder<T>.OrderBy(const AProp: TPropExpression; AAscending: Boolean): TSpecificationBuilder<T>;
begin
  SpecObj.OrderBy(TOrderBy.Create(AProp.Name, AAscending));
  Result := Self;
end;

// Overload accepting IOrderBy directly
function TSpecificationBuilder<T>.OrderBy(const AOrderBy: IOrderBy): TSpecificationBuilder<T>;
begin
  SpecObj.OrderBy(AOrderBy);
  Result := Self;
end;

function TSpecificationBuilder<T>.Skip(ACount: Integer): TSpecificationBuilder<T>;
begin
  SpecObj.ApplyPaging(ACount, FSpec.GetTake);
  Result := Self;
end;

function TSpecificationBuilder<T>.SpecObj: TSpecification<T>;
begin
  Result := GetSpec as TSpecification<T>;
end;

function TSpecificationBuilder<T>.Take(ACount: Integer): TSpecificationBuilder<T>;
begin
  SpecObj.ApplyPaging(FSpec.GetSkip, ACount);
  Result := Self;
end;

function TSpecificationBuilder<T>.Include(const AProp: TPropExpression): TSpecificationBuilder<T>;
begin
  SpecObj.Include(AProp.Name);
  Result := Self;
end;

function TSpecificationBuilder<T>.Include(const AProps: array of TPropExpression): TSpecificationBuilder<T>;
var
  Prop: TPropExpression;
begin
  for Prop in AProps do
    SpecObj.Include(Prop.Name);
  Result := Self;
end;

function TSpecificationBuilder<T>.Select(const AProp: TPropExpression): TSpecificationBuilder<T>;
begin
  SpecObj.Select(AProp.Name);
  Result := Self;
end;

function TSpecificationBuilder<T>.Select(const AProps: array of TPropExpression): TSpecificationBuilder<T>;
var
  Prop: TPropExpression;
begin
  for Prop in AProps do
    SpecObj.Select(Prop.Name);
  Result := Self;
end;

function TSpecificationBuilder<T>.Select(const AColumns: TArray<string>): TSpecificationBuilder<T>;
var
  Col: string;
begin
  for Col in AColumns do
    SpecObj.Select(Col);
  Result := Self;
end;

{ Specification }

class function Specification.Where<T>(const AExpression: IExpression): TSpecificationBuilder<T>;
begin
  Result := Result.Where(AExpression);
end;



class function Specification.OrderBy<T>(const APropertyName: string; AAscending: Boolean): TSpecificationBuilder<T>;
begin
  Result.OrderBy(APropertyName, AAscending);
end;

class function Specification.All<T>: TSpecificationBuilder<T>;
begin
  // Initialize FSpec explicitly to avoid lazy init in Implicit operator (const record)
  Result.FSpec := TSpecification<T>.Create;
end;

end.

