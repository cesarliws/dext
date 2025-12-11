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
unit Dext.Specifications.Base;

interface

uses
  System.Generics.Collections,
  Dext.Specifications.Interfaces,
  Dext.Specifications.Types;

type
  /// <summary>
  ///   Base class for Specifications.
  ///   Inherit from this class to define reusable query logic.
  /// </summary>
  TSpecification<T> = class(TInterfacedObject, ISpecification<T>)
  protected
    FExpression: IExpression;
    FIncludes: TList<string>;
    FOrderBy: TList<IOrderBy>;
    FSkip: Integer;
    FTake: Integer;
    FIsPagingEnabled: Boolean;
    FIsTracking: Boolean;
    
    FSelectedColumns: TList<string>;
    
    // Implementation of ISpecification<T>
    function GetExpression: IExpression;
    function GetIncludes: TArray<string>;
    function GetOrderBy: TArray<IOrderBy>;
    function GetSkip: Integer;
    function GetTake: Integer;
    function IsPagingEnabled: Boolean;
    function IsTrackingEnabled: Boolean;
    function GetSelectedColumns: TArray<string>;
  public
    constructor Create; overload; virtual;
    constructor Create(const AExpression: IExpression); overload; virtual;
    destructor Destroy; override;
    
    // Fluent Builders (public for TSpecificationBuilder)
    procedure Where(const AExpression: IExpression); overload;
    procedure Where(const AExpr: Dext.Specifications.Types.TPropExpression.TExpression); overload;
    procedure AddInclude(const APath: string);
    procedure AddOrderBy(const AOrderBy: IOrderBy);
    procedure ApplyPaging(ASkip, ATake: Integer);
    procedure AddSelect(const AColumn: string);
    
    // Fluent Helpers
    procedure Take(const ACount: Integer);
    procedure Skip(const ACount: Integer);
    
    procedure EnableTracking(const AValue: Boolean);
    procedure AsNoTracking;
  end;

implementation

{ TSpecification<T> }

constructor TSpecification<T>.Create;
begin
  inherited;
  FIncludes := TList<string>.Create;
  FSelectedColumns := TList<string>.Create;
  FOrderBy := TList<IOrderBy>.Create;
  FExpression := nil; // Empty expression matches all
  FIsTracking := True; // Tracking enabled by default
end;

constructor TSpecification<T>.Create(const AExpression: IExpression);
begin
  Create;
  FExpression := AExpression;
end;

destructor TSpecification<T>.Destroy;
begin
  FIncludes.Free;
  FSelectedColumns.Free;
  FOrderBy.Free;
  inherited;
end;

procedure TSpecification<T>.Where(const AExpression: IExpression);
begin
  if FExpression = nil then
    FExpression := AExpression
  else
    // Combine with AND
    FExpression := TLogicalExpression.Create(FExpression, AExpression, loAnd);
end;

procedure TSpecification<T>.Where(const AExpr: Dext.Specifications.Types.TPropExpression.TExpression);
begin
  Where(IExpression(AExpr));
end;

procedure TSpecification<T>.AddInclude(const APath: string);
begin
  FIncludes.Add(APath);
end;

procedure TSpecification<T>.ApplyPaging(ASkip, ATake: Integer);
begin
  FSkip := ASkip;
  FTake := ATake;
  FIsPagingEnabled := True;
end;

function TSpecification<T>.GetExpression: IExpression;
begin
  Result := FExpression;
end;

function TSpecification<T>.GetIncludes: TArray<string>;
begin
  Result := FIncludes.ToArray;
end;

function TSpecification<T>.GetOrderBy: TArray<IOrderBy>;
begin
  Result := FOrderBy.ToArray;
end;

function TSpecification<T>.GetSkip: Integer;
begin
  Result := FSkip;
end;

function TSpecification<T>.GetTake: Integer;
begin
  Result := FTake;
end;

function TSpecification<T>.IsPagingEnabled: Boolean;
begin
  Result := FIsPagingEnabled;
end;

procedure TSpecification<T>.AddOrderBy(const AOrderBy: IOrderBy);
begin
  FOrderBy.Add(AOrderBy);
end;

function TSpecification<T>.GetSelectedColumns: TArray<string>;
begin
  Result := FSelectedColumns.ToArray;
end;

procedure TSpecification<T>.AddSelect(const AColumn: string);
begin
  FSelectedColumns.Add(AColumn);
end;

procedure TSpecification<T>.Take(const ACount: Integer);
begin
  FTake := ACount;
  FIsPagingEnabled := True;
end;

procedure TSpecification<T>.Skip(const ACount: Integer);
begin
  FSkip := ACount;
  FIsPagingEnabled := True;
end;

function TSpecification<T>.IsTrackingEnabled: Boolean;
begin
  Result := FIsTracking;
end;

procedure TSpecification<T>.EnableTracking(const AValue: Boolean);
begin
  FIsTracking := AValue;
end;

procedure TSpecification<T>.AsNoTracking;
begin
  FIsTracking := False;
end;

end.

