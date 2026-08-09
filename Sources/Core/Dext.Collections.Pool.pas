unit Dext.Collections.Pool;

interface

uses
{$IFDEF MSWINDOWS}
  Winapi.Windows,
{$ENDIF}
  System.SysUtils,
  System.Classes,
  System.SyncObjs;

type
  /// <summary>
  ///   Interface implemented by objects that require automated state cleanup
  ///   or sanitization before returning to a TDextPool instance.
  /// </summary>
  IPoolable = interface
    ['{8E7A6B5C-4D3E-2F1A-0B9C-8D7E6F5A4B3C}']
    procedure ResetState;
  end;

  /// <summary>
  ///   Configuration settings for TDextPool<T>.
  /// </summary>
  TDextPoolConfig = record
    MinSize: Integer;
    MaxSize: Integer;
    IdleTimeoutMs: Integer;
    AcquireTimeoutMs: Integer;
    class function Default: TDextPoolConfig; static;
  end;

  /// <summary>
  ///   Generic interface for high-performance thread-safe object pools.
  /// </summary>
  IDextPool<T: class> = interface
    ['{1F2E3D4C-5B6A-7F8E-9D0C-1A2B3C4D5E6F}']
    function Acquire(out AItem: T): Boolean;
    procedure Release(AItem: T);
    procedure Use(const AProc: TProc<T>); overload;
    function GetCount: Integer;
    property Count: Integer read GetCount;
  end;

  /// <summary>
  ///   High-performance, thread-safe generic object pool with auto-recycling.
  /// </summary>
  TDextPool<T: class, constructor> = class(TInterfacedObject, IDextPool<T>)
  private
    FConfig: TDextPoolConfig;
    FFactory: TFunc<T>;
    FResetAction: TProc<T>;
    FItems: TArray<T>;
    FLock: TSpinLock;
    FCount: Integer;
    FTotalAllocated: Integer;
    procedure InternalPush(AItem: T);
    function InternalPop(out AItem: T): Boolean;
    function CreateInstance: T;
  public
    constructor Create(const AConfig: TDextPoolConfig; const AResetAction: TProc<T> = nil); overload;
    constructor Create(const AConfig: TDextPoolConfig; const AFactory: TFunc<T>; const AResetAction: TProc<T> = nil); overload;
    destructor Destroy; override;

    function Acquire(out AItem: T): Boolean;
    procedure Release(AItem: T);
    procedure Use(const AProc: TProc<T>); overload;
    function Use<TResult>(const AFunc: TFunc<T, TResult>): TResult; overload;
    function GetCount: Integer;
    property Count: Integer read GetCount;
  end;

implementation

{ TDextPoolConfig }

class function TDextPoolConfig.Default: TDextPoolConfig;
begin
  Result.MinSize := 4;
  Result.MaxSize := 64;
  Result.IdleTimeoutMs := 30000;
  Result.AcquireTimeoutMs := 5000;
end;

{ TDextPool<T> }

constructor TDextPool<T>.Create(const AConfig: TDextPoolConfig; const AResetAction: TProc<T>);
begin
  Create(AConfig, nil, AResetAction);
end;

constructor TDextPool<T>.Create(const AConfig: TDextPoolConfig; const AFactory: TFunc<T>; const AResetAction: TProc<T>);
var
  I: Integer;
  Item: T;
begin
  inherited Create;
  FConfig := AConfig;
  FFactory := AFactory;
  FResetAction := AResetAction;
  FLock := TSpinLock.Create(False);
  FCount := 0;
  FTotalAllocated := 0;

  if FConfig.MaxSize < 1 then
    FConfig.MaxSize := 64;
  if FConfig.MinSize > FConfig.MaxSize then
    FConfig.MinSize := FConfig.MaxSize;

  SetLength(FItems, FConfig.MaxSize);

  // Warm-up pool with MinSize instances
  for I := 0 to FConfig.MinSize - 1 do
  begin
    Item := CreateInstance;
    InternalPush(Item);
  end;
end;

destructor TDextPool<T>.Destroy;
var
  Item: T;
  Obj: TObject;
begin
  FLock.Enter;
  try
    while FCount > 0 do
    begin
      Dec(FCount);
      Item := FItems[FCount];
      FItems[FCount] := nil;
      Obj := TObject(Item);
      Obj.Free;
    end;
  finally
    FLock.Exit;
  end;
  inherited Destroy;
end;

function TDextPool<T>.CreateInstance: T;
begin
  if Assigned(FFactory) then
    Result := FFactory()
  else
    Result := T.Create;
  Inc(FTotalAllocated);
end;

procedure TDextPool<T>.InternalPush(AItem: T);
begin
  FItems[FCount] := AItem;
  Inc(FCount);
end;

function TDextPool<T>.InternalPop(out AItem: T): Boolean;
begin
  if FCount > 0 then
  begin
    Dec(FCount);
    AItem := FItems[FCount];
    FItems[FCount] := nil;
    Result := True;
  end
  else
  begin
    AItem := nil;
    Result := False;
  end;
end;

function TDextPool<T>.Acquire(out AItem: T): Boolean;
var
  Popped: Boolean;
  CanAllocate: Boolean;
begin
  FLock.Enter;
  try
    Popped := InternalPop(AItem);
    if not Popped then
    begin
      CanAllocate := (FConfig.MaxSize <= 0) or (FTotalAllocated < FConfig.MaxSize);
      if CanAllocate then
      begin
        AItem := CreateInstance;
        Result := True;
        Exit;
      end;
    end;
  finally
    FLock.Exit;
  end;

  if Popped then
    Exit(True);

  AItem := nil;
  Result := False;
end;

procedure TDextPool<T>.Release(AItem: T);
var
  Poolable: IPoolable;
  ShouldDestroy: Boolean;
begin
  if AItem = nil then
    Exit;

  // Sanitization / Recycling
  try
    if Assigned(FResetAction) then
      FResetAction(AItem);

    if Supports(AItem, IPoolable, Poolable) then
      Poolable.ResetState;
  except
    FLock.Enter;
    try
      Dec(FTotalAllocated);
    finally
      FLock.Exit;
    end;
    AItem.Free;
    Exit;
  end;

  ShouldDestroy := False;
  FLock.Enter;
  try
    if (FConfig.MaxSize > 0) and (FCount >= FConfig.MaxSize) then
    begin
      ShouldDestroy := True;
      Dec(FTotalAllocated);
    end
    else
      InternalPush(AItem);
  finally
    FLock.Exit;
  end;

  if ShouldDestroy then
    TObject(AItem).Free;
end;

procedure TDextPool<T>.Use(const AProc: TProc<T>);
var
  Item: T;
begin
  if not Acquire(Item) then
    raise Exception.Create('Failed to acquire instance from object pool.');
  try
    AProc(Item);
  finally
    Release(Item);
  end;
end;

function TDextPool<T>.Use<TResult>(const AFunc: TFunc<T, TResult>): TResult;
var
  Item: T;
begin
  if not Acquire(Item) then
    raise Exception.Create('Failed to acquire instance from object pool.');
  try
    Result := AFunc(Item);
  finally
    Release(Item);
  end;
end;

function TDextPool<T>.GetCount: Integer;
begin
  FLock.Enter;
  try
    Result := FCount;
  finally
    FLock.Exit;
  end;
end;

end.
