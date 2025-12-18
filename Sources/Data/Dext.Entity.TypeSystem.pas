unit Dext.Entity.TypeSystem;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Rtti,
  System.TypInfo,
  System.Generics.Collections,
  Dext.Core.ValueConverters,
  Dext.Specifications.Types,
  Dext.Specifications.Interfaces; // For IPredicate/IExpression

type
  /// <summary>
  ///   Holds the heavy RTTI metadata for a property.
  ///   Class-based to ensure single instance per property per entity type.
  /// </summary>
  TPropertyInfo = class
  private
    FName: string;
    FPropInfo: PPropInfo;
    FPropTypeInfo: PTypeInfo;
    FConverter: IValueConverter;
  public
    constructor Create(const AName: string; APropInfo: PPropInfo; APropTypeInfo: PTypeInfo; AConverter: IValueConverter = nil);
    
    // RTTI & Metadata
    property Name: string read FName;
    property PropInfo: PPropInfo read FPropInfo;
    property PropTypeInfo: PTypeInfo read FPropTypeInfo;
    property Converter: IValueConverter read FConverter write FConverter;
    
    // Runtime Access helpers (using TypeInfo cache)
    function GetValue(Instance: TObject): TValue;
    procedure SetValue(Instance: TObject; const Value: TValue);
  end;

  /// <summary>
  ///   Lightweight record wrapper for TPropertyInfo that provides strongest typing and
  ///   operator overloading for the Query Expressions syntax.
  ///   TProp<Integer> -> allows operators >, <, =, etc. against Integers.
  /// </summary>
  TProp<T> = record
  private
    FInfo: TPropertyInfo;
  public
    // Implicit conversion to "Old" TPropExpression for backward compatibility
    class operator Implicit(const Value: TProp<T>): TPropExpression;
    
    // Implicit from TPropertyInfo (used by the scaffold/init)
    class operator Implicit(const Value: TPropertyInfo): TProp<T>;
    
    // Implicit to TPropertyInfo (for usage in IEntityBuilder)
    class operator Implicit(const Value: TProp<T>): TPropertyInfo;

    // Operators returning TFluentExpression (compatible with logical & and |)
    class operator Equal(const Left: TProp<T>; Right: T): TFluentExpression;
    class operator NotEqual(const Left: TProp<T>; Right: T): TFluentExpression;
    class operator GreaterThan(const Left: TProp<T>; Right: T): TFluentExpression;
    class operator GreaterThanOrEqual(const Left: TProp<T>; Right: T): TFluentExpression;
    class operator LessThan(const Left: TProp<T>; Right: T): TFluentExpression;
    class operator LessThanOrEqual(const Left: TProp<T>; Right: T): TFluentExpression;
    
    // Fluent Methods (Strings, Nulls, Sets)
    function Like(const Pattern: string): TFluentExpression;
    function StartsWith(const Value: string): TFluentExpression;
    function EndsWith(const Value: string): TFluentExpression;
    function Contains(const Value: string): TFluentExpression;
    
    function In_(const Values: TArray<T>): TFluentExpression;
    function NotIn(const Values: TArray<T>): TFluentExpression;
    
    function IsNull: TFluentExpression;
    function IsNotNull: TFluentExpression;
    
    function Between(const Lower, Upper: T): TFluentExpression;
    
    // OrderBy
    function Asc: IOrderBy;
    function Desc: IOrderBy;

    // Access to underlying metadata
    property Info: TPropertyInfo read FInfo;
  end;

  /// <summary>
  ///   Fluent builder for creating and populating entities using TypeSystem metadata.
  /// </summary>
  IEntityBuilder<T: class> = interface
    ['{A1C2E3B4-D5F6-4789-8123-456789ABCDEF}']
    function Prop(const AInfo: TPropertyInfo; const AValue: TValue): IEntityBuilder<T>; overload;
    function Prop(const AProp: TProp<string>; const AValue: string): IEntityBuilder<T>; overload;
    function Prop(const AProp: TProp<Integer>; const AValue: Integer): IEntityBuilder<T>; overload;
    function Prop(const AProp: TProp<Double>; const AValue: Double): IEntityBuilder<T>; overload;
    function Prop(const AProp: TProp<Boolean>; const AValue: Boolean): IEntityBuilder<T>; overload;
    function Prop(const AProp: TProp<TDateTime>; const AValue: TDateTime): IEntityBuilder<T>; overload;
    function Build: T;
  end;

  /// <summary>
  ///   Default implementation of IEntityBuilder.
  /// </summary>
  TEntityBuilder<T: class> = class(TInterfacedObject, IEntityBuilder<T>)
  private
    FEntity: T;
  public
    constructor Create;
    destructor Destroy; override;
    function Prop(const AInfo: TPropertyInfo; const AValue: TValue): IEntityBuilder<T>; overload;
    function Prop(const AProp: TProp<string>; const AValue: string): IEntityBuilder<T>; overload;
    function Prop(const AProp: TProp<Integer>; const AValue: Integer): IEntityBuilder<T>; overload;
    function Prop(const AProp: TProp<Double>; const AValue: Double): IEntityBuilder<T>; overload;
    function Prop(const AProp: TProp<Boolean>; const AValue: Boolean): IEntityBuilder<T>; overload;
    function Prop(const AProp: TProp<TDateTime>; const AValue: TDateTime): IEntityBuilder<T>; overload;
    function Build: T;
  end;

  /// <summary>
  ///   The static registry for an Entity Type.
  ///   This class is meant to be inherited and populated via Scaffolding/Experts.
  ///   e.g. TUserType = class(TEntityType<TUser>)
  /// </summary>
  TEntityType<T: class> = class
  public
    class var EntityTypeInfo: PTypeInfo;
    class constructor Create;
    class function New: IEntityBuilder<T>;
    class function Construct(const AInit: TProc<IEntityBuilder<T>>): T; static;
  end;

var
  GlobalRttiContext: TRttiContext;

implementation

{ TPropertyInfo }

constructor TPropertyInfo.Create(const AName: string; APropInfo: PPropInfo;
  APropTypeInfo: PTypeInfo; AConverter: IValueConverter);
begin
  FName := AName;
  FPropInfo := APropInfo;
  FPropTypeInfo := APropTypeInfo;
  FConverter := AConverter;
end;

function TPropertyInfo.GetValue(Instance: TObject): TValue;
begin
  var RttiType := GlobalRttiContext.GetType(Instance.ClassType);
  var RttiProp := RttiType.GetProperty(FName);
  if RttiProp <> nil then
    Result := RttiProp.GetValue(Instance)
  else
    Result := TValue.Empty;
end;

procedure TPropertyInfo.SetValue(Instance: TObject; const Value: TValue);
begin
  var RttiType := GlobalRttiContext.GetType(Instance.ClassType);
  var RttiProp := RttiType.GetProperty(FName);
  if RttiProp <> nil then
    RttiProp.SetValue(Instance, Value);
end;

{ TProp<T> }

class operator TProp<T>.Implicit(const Value: TProp<T>): TPropExpression;
begin
  if Value.FInfo = nil then
    Result := TPropExpression.Create('')
  else
    Result := TPropExpression.Create(Value.FInfo.Name);
end;

class operator TProp<T>.Implicit(const Value: TPropertyInfo): TProp<T>;
begin
  Result.FInfo := Value;
end;

class operator TProp<T>.Implicit(const Value: TProp<T>): TPropertyInfo;
begin
  Result := Value.FInfo;
end;

class operator TProp<T>.Equal(const Left: TProp<T>; Right: T): TFluentExpression;
begin
  Result := TPropExpression.Create(Left.FInfo.Name) = TValue.From<T>(Right);
end;

class operator TProp<T>.NotEqual(const Left: TProp<T>; Right: T): TFluentExpression;
begin
  Result := TPropExpression.Create(Left.FInfo.Name) <> TValue.From<T>(Right);
end;

class operator TProp<T>.GreaterThan(const Left: TProp<T>; Right: T): TFluentExpression;
begin
  Result := TPropExpression.Create(Left.FInfo.Name) > TValue.From<T>(Right);
end;

class operator TProp<T>.GreaterThanOrEqual(const Left: TProp<T>; Right: T): TFluentExpression;
begin
  Result := TPropExpression.Create(Left.FInfo.Name) >= TValue.From<T>(Right);
end;

class operator TProp<T>.LessThan(const Left: TProp<T>; Right: T): TFluentExpression;
begin
  Result := TPropExpression.Create(Left.FInfo.Name) < TValue.From<T>(Right);
end;

class operator TProp<T>.LessThanOrEqual(const Left: TProp<T>; Right: T): TFluentExpression;
begin
  Result := TPropExpression.Create(Left.FInfo.Name) <= TValue.From<T>(Right);
end;

function TProp<T>.Like(const Pattern: string): TFluentExpression;
begin
  Result := TPropExpression.Create(FInfo.Name).Like(Pattern);
end;

function TProp<T>.StartsWith(const Value: string): TFluentExpression;
begin
  Result := TPropExpression.Create(FInfo.Name).StartsWith(Value);
end;

function TProp<T>.EndsWith(const Value: string): TFluentExpression;
begin
  Result := TPropExpression.Create(FInfo.Name).EndsWith(Value);
end;

function TProp<T>.Contains(const Value: string): TFluentExpression;
begin
  Result := TPropExpression.Create(FInfo.Name).Contains(Value);
end;

function TProp<T>.In_(const Values: TArray<T>): TFluentExpression;
begin
  Result := TBinaryExpression.Create(FInfo.Name, boIn, TValue.From<TArray<T>>(Values));
end;

function TProp<T>.NotIn(const Values: TArray<T>): TFluentExpression;
begin
  Result := TBinaryExpression.Create(FInfo.Name, boNotIn, TValue.From<TArray<T>>(Values));
end;

function TProp<T>.IsNull: TFluentExpression;
begin
  Result := TPropExpression.Create(FInfo.Name).IsNull;
end;

function TProp<T>.IsNotNull: TFluentExpression;
begin
  Result := TPropExpression.Create(FInfo.Name).IsNotNull;
end;

function TProp<T>.Between(const Lower, Upper: T): TFluentExpression;
begin
  Result := TPropExpression.Create(FInfo.Name).Between(TValue.From<T>(Lower).AsVariant, TValue.From<T>(Upper).AsVariant);
end;

function TProp<T>.Asc: IOrderBy;
begin
  Result := TPropExpression.Create(FInfo.Name).Asc;
end;

function TProp<T>.Desc: IOrderBy;
begin
  Result := TPropExpression.Create(FInfo.Name).Desc;
end;

{ TEntityType<T> }

class constructor TEntityType<T>.Create;
begin
  EntityTypeInfo := TypeInfo(T);
  // Optional: Auto-discover properties via RTTI if not manually defined by scaffold
end;

class function TEntityType<T>.New: IEntityBuilder<T>;
begin
  Result := TEntityBuilder<T>.Create;
end;

class function TEntityType<T>.Construct(const AInit: TProc<IEntityBuilder<T>>): T;
begin
  var Builder := New;
  if Assigned(AInit) then
    AInit(Builder);
  Result := Builder.Build;
end;

{ TEntityBuilder<T> }

constructor TEntityBuilder<T>.Create;
begin
  inherited Create;
  // Use RTTI context to create instance if T doesn't have a parameterless constructor known to compiler?
  // Since T: class, we can use T.Create if we have a way.
  // RTTI is safer to ensure we get a valid instance of the generic type.
  var RType := GlobalRttiContext.GetType(TypeInfo(T));
  if (RType <> nil) and RType.IsInstance then
  begin
    var Method := RType.AsInstance.GetMethod('Create');
    if Method <> nil then
      FEntity := Method.Invoke(RType.AsInstance.MetaclassType, []).AsType<T>
    else
      FEntity := Default(T); // Should not happen with T: class if it has public Create
  end;
end;

destructor TEntityBuilder<T>.Destroy;
begin
  // FEntity is NOT freed here if Build was called?
  // Actually, standard builder pattern: Build returns the instance,
  // but who owns it? The caller.
  // If Build was NOT called, we might leak.
  // But usually builders are used in a single expression.
  inherited;
end;

function TEntityBuilder<T>.Build: T;
begin
  Result := FEntity;
  FEntity := nil; // Ownership transferred to caller
end;

function TEntityBuilder<T>.Prop(const AInfo: TPropertyInfo;
  const AValue: TValue): IEntityBuilder<T>;
begin
  if (FEntity <> nil) and (AInfo <> nil) then
    AInfo.SetValue(FEntity, AValue);
  Result := Self;
end;

function TEntityBuilder<T>.Prop(const AProp: TProp<string>; const AValue: string): IEntityBuilder<T>;
begin
  Result := Prop(AProp.Info, TValue.From<string>(AValue));
end;

function TEntityBuilder<T>.Prop(const AProp: TProp<Integer>; const AValue: Integer): IEntityBuilder<T>;
begin
  Result := Prop(AProp.Info, TValue.From<Integer>(AValue));
end;

function TEntityBuilder<T>.Prop(const AProp: TProp<Double>; const AValue: Double): IEntityBuilder<T>;
begin
  Result := Prop(AProp.Info, TValue.From<Double>(AValue));
end;

function TEntityBuilder<T>.Prop(const AProp: TProp<Boolean>; const AValue: Boolean): IEntityBuilder<T>;
begin
  Result := Prop(AProp.Info, TValue.From<Boolean>(AValue));
end;

function TEntityBuilder<T>.Prop(const AProp: TProp<TDateTime>; const AValue: TDateTime): IEntityBuilder<T>;
begin
  Result := Prop(AProp.Info, TValue.From<TDateTime>(AValue));
end;

initialization
  GlobalRttiContext := TRttiContext.Create;

finalization
  GlobalRttiContext.Free;

end.
