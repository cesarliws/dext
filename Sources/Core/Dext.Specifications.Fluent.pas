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
  Dext.Specifications.OrderBy;

type
  /// <summary>
  ///   Managed record for fluent specification building with automatic cleanup.
  ///   Usage: Specification.Where<TUser>(UserEntity.Age >= 18)
  /// </summary>
  TSpecificationBuilder<T: class> = record
  private
    FSpec: ISpecification<T>;
    function GetSpec: ISpecification<T>;
    function SpecObj: TSpecification<T>; inline;
  public
    class operator Implicit(const Value: TSpecificationBuilder<T>): ISpecification<T>;

    // Fluent methods
    function Where(const AExpression: IExpression): TSpecificationBuilder<T>;
    function OrderBy(const APropertyName: string; AAscending: Boolean = True): TSpecificationBuilder<T>; overload;
    function OrderBy(const AOrderBy: IOrderBy): TSpecificationBuilder<T>; overload;
    function Skip(ACount: Integer): TSpecificationBuilder<T>;
    function Take(ACount: Integer): TSpecificationBuilder<T>;
    function Include(const APath: string): TSpecificationBuilder<T>;
    function Select(const AColumn: string): TSpecificationBuilder<T>; overload;
    function Select(const AColumns: TArray<string>): TSpecificationBuilder<T>; overload;
    
    property Spec: ISpecification<T> read GetSpec;
  end;

  /// <summary>
  ///   Static factory for creating specification builders
  /// </summary>
  Specification = record
    class function Where<T: class>(const AExpression: IExpression): TSpecificationBuilder<T>; static;
    class function OrderBy<T: class>(const APropertyName: string; AAscending: Boolean = True): TSpecificationBuilder<T>; static;
    class function All<T: class>: TSpecificationBuilder<T>; static;
  end;

implementation

{ TSpecificationBuilder<T> }

function TSpecificationBuilder<T>.GetSpec: ISpecification<T>;
begin
  if FSpec = nil then
    FSpec := TSpecification<T>.Create;
  Result := FSpec;
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

function TSpecificationBuilder<T>.OrderBy(const APropertyName: string; AAscending: Boolean): TSpecificationBuilder<T>;
begin
  SpecObj.AddOrderBy(TOrderBy.Create(APropertyName, AAscending));
  Result := Self;
end;

// Overload accepting IOrderBy directly
function TSpecificationBuilder<T>.OrderBy(const AOrderBy: IOrderBy): TSpecificationBuilder<T>;
begin
  SpecObj.AddOrderBy(AOrderBy);
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

function TSpecificationBuilder<T>.Include(const APath: string): TSpecificationBuilder<T>;
begin
  SpecObj.AddInclude(APath);
  Result := Self;
end;

function TSpecificationBuilder<T>.Select(const AColumn: string): TSpecificationBuilder<T>;
begin
  SpecObj.AddSelect(AColumn);
  Result := Self;
end;

function TSpecificationBuilder<T>.Select(const AColumns: TArray<string>): TSpecificationBuilder<T>;
var
  Col: string;
begin
  for Col in AColumns do
    SpecObj.AddSelect(Col);
  Result := Self;
end;

{ Specification }

class function Specification.Where<T>(const AExpression: IExpression): TSpecificationBuilder<T>;
begin
  Result.Where(AExpression);
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

