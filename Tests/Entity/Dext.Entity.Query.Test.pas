unit Dext.Entity.Query.Test;

interface

uses
  System.SysUtils,
  Dext.Assertions,
  Dext.Collections,
  Dext.Core.SmartTypes,
  Dext.Specifications.Interfaces,
  Dext.Entity.Query,
  Dext.Entity.Core,
  Dext.Entity.Mapping,
  Dext.Entity.Attributes;

type
  [Table('users')]
  TUser = class
  private
    FId: Prop<Integer>;
    FName: Prop<string>;
    FEmail: Prop<string>;
  public
    [PK, AutoInc] property Id: Prop<Integer> read FId write FId;
    property Name: Prop<string> read FName write FName;
    property Email: Prop<string> read FEmail write FEmail;
  end;

  TQueryParityTest = class
  public
    procedure Run;
    procedure TestTypedOrderBy;
    procedure TestTypedSelect;
    procedure TestSkipTakeOptimization;
    procedure TestScalarOptimization;
    procedure TestThenBy;
    procedure TestEntityTrackingLifetime;
  end;

implementation

uses
  Dext.Specifications.Base,
  Dext.Entity.Prototype;

{ TQueryParityTest }

procedure TQueryParityTest.Run;
begin
  WriteLn('Testing TFluentQuery Parity and Optimizations...');
  TestTypedOrderBy;
  TestTypedSelect;
  TestSkipTakeOptimization;
  TestScalarOptimization;
  TestThenBy;
  TestEntityTrackingLifetime;
end;

procedure TQueryParityTest.TestTypedOrderBy;
var
  U: TUser;
  Query: TFluentQuery<TUser>;
  Spec: ISpecification<TUser>;
begin
  Write('  - Typed OrderBy: ');
  U := Prototype.Entity<TUser>;
  Spec := TSpecification<TUser>.Create;
  Query := TFluentQuery<TUser>.Create(nil, Spec);
  
  Query.OrderBy(U.Name.Asc);
    
  Should(Length(Spec.GetOrderBy)).Be(1);
  Should(Spec.GetOrderBy[0].GetPropertyName).Be('Name');
  Should(Spec.GetOrderBy[0].GetAscending).BeTrue;
  WriteLn('[PASS]');

  Query := Default(TFluentQuery<TUser>);
  Spec := nil;
end;

procedure TQueryParityTest.TestThenBy;
var
  U: TUser;
  Query: TFluentQuery<TUser>;
  Spec: ISpecification<TUser>;
begin
  Write('  - Multi OrderBy (Array): ');
  U := Prototype.Entity<TUser>;
  Spec := TSpecification<TUser>.Create;
  Query := TFluentQuery<TUser>.Create(nil, Spec);
  
  Query
    .OrderBy([U.Name.Asc, U.Id.Desc]);
    
  Should(Length(Spec.GetOrderBy)).Be(2);
  Should(Spec.GetOrderBy[1].GetPropertyName).Be('Id');
  Should(Spec.GetOrderBy[1].GetAscending).BeFalse;
  WriteLn('[PASS]');

  Query := Default(TFluentQuery<TUser>);
  Spec := nil;
end;

procedure TQueryParityTest.TestTypedSelect;
var
  U: TUser;
  Query: TFluentQuery<TUser>;
  Spec: ISpecification<TUser>;
  Projection: TFluentQuery<string>;
begin
  Write('  - Typed Select (Prop<T>): ');
  U := Prototype.Entity<TUser>;
  Spec := TSpecification<TUser>.Create;
  Query := TFluentQuery<TUser>.Create(nil, Spec);
  
  Projection := Query.Select<string>(U.Email);
  
  Should(Length(Spec.GetSelectedColumns)).Be(1);
  Should(Spec.GetSelectedColumns[0]).Be('Email');
  WriteLn('[PASS]');

  // Explicitly clear to avoid leaks in ActRec
  Projection := Default(TFluentQuery<string>);
  Query := Default(TFluentQuery<TUser>);
  Spec := nil;
end;

procedure TQueryParityTest.TestSkipTakeOptimization;
var
  Query: TFluentQuery<TUser>;
  Spec: ISpecification<TUser>;
begin
  Write('  - Skip/Take Optimization (SQL-side): ');
  Spec := TSpecification<TUser>.Create;
  Query := TFluentQuery<TUser>.Create(nil, Spec);
  
  Query.Skip(10).Take(20);
  
  Should(Spec.GetSkip).Be(10);
  Should(Spec.GetTake).Be(20);
  WriteLn('[PASS]');

  Query := Default(TFluentQuery<TUser>);
  Spec := nil;
end;

procedure TQueryParityTest.TestScalarOptimization;
var
  Query: TFluentQuery<TUser>;
  Spec: ISpecification<TUser>;
  CountCalled: Boolean;
begin
  Write('  - Scalar Optimization (Count SQL-side): ');
  CountCalled := False;
  Spec := TSpecification<TUser>.Create;
  
  Query := TFluentQuery<TUser>.Create(
      nil, 
      Spec,
      function(S: ISpecification): Integer
      begin
        CountCalled := True;
        Result := 42;
      end,
      nil,
      nil,
      nil
    );
  
  Should(Query.Count).Be(42);
  Should(CountCalled).BeTrue;
  WriteLn('[PASS]');

  Query := Default(TFluentQuery<TUser>);
  Spec := nil;
end;

procedure TQueryParityTest.TestEntityTrackingLifetime;
var
  Query: TFluentQuery<TUser>;
  Spec: ISpecification<TUser>;
begin
  Write('  - Entity Tracking Lifetime (AsNoTracking): ');
  Spec := TSpecification<TUser>.Create;
  Query := TFluentQuery<TUser>.Create(nil, Spec);
  
  Query.AsNoTracking;
  
  Should(Spec.IsTrackingEnabled).BeFalse;
  WriteLn('[PASS]');

  Query := Default(TFluentQuery<TUser>);
  Spec := nil;
end;

end.
