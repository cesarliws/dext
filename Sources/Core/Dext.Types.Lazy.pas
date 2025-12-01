unit Dext.Types.Lazy;

interface

uses
  System.SysUtils,
  System.Rtti,
  System.TypInfo,
  System.SyncObjs,
  System.Generics.Collections;

type
  {$M+}
  ILazy = interface
    ['{40223BA9-0C66-49E7-AA33-BDAEF9F506D6}']
    function GetIsValueCreated: Boolean;
    function GetValue: TValue;
    property IsValueCreated: Boolean read GetIsValueCreated;
    property Value: TValue read GetValue;
  end;

  ILazy<T> = interface(ILazy)
    ['{89709823-1234-4321-ABCD-EF0123456789}']
    function GetValueT: T;
    property Value: T read GetValueT;
  end;

  // Forward declarations
  TLazy<T> = class;
  TValueLazy<T> = class;

//  Lazy<T> = record
//  private
//    FInstance: ILazy<T>;
//    function GetIsValueCreated: Boolean;
//    function GetValue: T;
//  public
//    class function Create: Lazy<T>; overload; static;
//    constructor Create(const AValueFactory: TFunc<T>); overload;
//    constructor CreateFrom(const AValue: T);
//
//    class operator Implicit(const Value: Lazy<T>): T;
//    class operator Implicit(const Value: T): Lazy<T>;
//    class operator Implicit(const ValueFactory: TFunc<T>): Lazy<T>;
//
//    property IsValueCreated: Boolean read GetIsValueCreated;
//    property Value: T read GetValue;
//  end;

  TLazy<T> = class(TInterfacedObject, ILazy, ILazy<T>)
  private
    FValueFactory: TFunc<T>;
    FValue: T;
    FIsValueCreated: Boolean;
    FLock: TCriticalSection;
    
    function GetIsValueCreated: Boolean;
    function GetValue: TValue;
    function GetValueT: T;
    // function ILazy<T>.GetValue = GetValueT;
  public
    constructor Create(const AValueFactory: TFunc<T>);
    destructor Destroy; override;
  end;

  TValueLazy<T> = class(TInterfacedObject, ILazy, ILazy<T>)
  private
    FValue: T;
    function GetIsValueCreated: Boolean;
    function GetValue: TValue;
    function GetValueT: T;
    // function ILazy<T>.GetValue = GetValueT;
  public
    constructor Create(const AValue: T);
  end;

implementation

uses
  System.Classes;

{ TLazy<T> }

constructor TLazy<T>.Create(const AValueFactory: TFunc<T>);
begin
  inherited Create;
  FValueFactory := AValueFactory;
  FIsValueCreated := False;
  FLock := TCriticalSection.Create;
end;

destructor TLazy<T>.Destroy;
begin
  FLock.Free;
  inherited;
end;

function TLazy<T>.GetIsValueCreated: Boolean;
begin
  Result := FIsValueCreated;
end;

function TLazy<T>.GetValue: TValue;
begin
  Result := TValue.From<T>(GetValueT);
end;

function TLazy<T>.GetValueT: T;
begin
  if not FIsValueCreated then
  begin
    FLock.Enter;
    try
      if not FIsValueCreated then
      begin
        if Assigned(FValueFactory) then
          FValue := FValueFactory()
        else
          FValue := Default(T);
        FIsValueCreated := True;
      end;
    finally
      FLock.Leave;
    end;
  end;
  Result := FValue;
end;

{ TValueLazy<T> }

constructor TValueLazy<T>.Create(const AValue: T);
begin
  inherited Create;
  FValue := AValue;
end;

function TValueLazy<T>.GetIsValueCreated: Boolean;
begin
  Result := True;
end;

function TValueLazy<T>.GetValue: TValue;
begin
  Result := TValue.From<T>(FValue);
end;

function TValueLazy<T>.GetValueT: T;
begin
  Result := FValue;
end;

//{ Lazy<T> }
//
//class function Lazy<T>.Create: Lazy<T>;
//begin
//  // Default constructor returns empty/default
//  Result.FInstance := TValueLazy<T>.Create(Default(T));
//end;
//
//constructor Lazy<T>.Create(const AValueFactory: TFunc<T>);
//begin
//  FInstance := TLazy<T>.Create(AValueFactory);
//end;
//
//constructor Lazy<T>.CreateFrom(const AValue: T);
//begin
//  FInstance := TValueLazy<T>.Create(AValue);
//end;
//
//function Lazy<T>.GetIsValueCreated: Boolean;
//begin
//  if FInstance <> nil then
//    Result := FInstance.IsValueCreated
//  else
//    Result := False;
//end;
//
//function Lazy<T>.GetValue: T;
//begin
//  if FInstance <> nil then
//    Result := FInstance.Value
//  else
//    Result := Default(T);
//end;
//
//class operator Lazy<T>.Implicit(const Value: Lazy<T>): T;
//begin
//  Result := Value.Value;
//end;
//
//class operator Lazy<T>.Implicit(const Value: T): Lazy<T>;
//begin
//  Result.CreateFrom(Value);
//end;
//
//class operator Lazy<T>.Implicit(const ValueFactory: TFunc<T>): Lazy<T>;
//begin
//  Result.Create(ValueFactory);
//end;

end.
