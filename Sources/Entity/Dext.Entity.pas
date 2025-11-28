unit Dext.Entity;

interface

uses
  System.SysUtils,
  System.TypInfo,
  System.Generics.Collections,
  Dext.Entity.Core,
  Dext.Entity.DbSet,
  Dext.Entity.Drivers.Interfaces,
  Dext.Entity.Dialects;

type
  /// <summary>
  ///   Concrete implementation of DbContext.
  ///   Manages database connection, transactions, and entity sets.
  ///   
  ///   Note: This class implements IDbContext but disables reference counting.
  ///   You must manage its lifecycle manually (Free).
  /// </summary>
  TDbContext = class(TObject, IDbContext)
  private
    FConnection: IDbConnection;
    FDialect: ISQLDialect;
    FTransaction: IDbTransaction;
    FCache: TDictionary<PTypeInfo, IInterface>; // Cache for DbSets
  protected
    // IDbContext Implementation
    function QueryInterface(const IID: TGUID; out Obj): HResult; stdcall;
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;
    
  public
    constructor Create(AConnection: IDbConnection; ADialect: ISQLDialect);
    destructor Destroy; override;
    
    function Connection: IDbConnection;
    function Dialect: ISQLDialect;
    
    procedure BeginTransaction;
    procedure Commit;
    procedure Rollback;
    
    /// <summary>
    ///   Access the DbSet for a specific entity type.
    /// </summary>
    function Entities<T: class>: IDbSet<T>;
  end;

implementation

{ TDbContext }

constructor TDbContext.Create(AConnection: IDbConnection; ADialect: ISQLDialect);
begin
  inherited Create;
  FConnection := AConnection;
  FDialect := ADialect;
  FCache := TDictionary<PTypeInfo, IInterface>.Create;
end;

destructor TDbContext.Destroy;
begin
  FCache.Free;
  inherited;
end;

function TDbContext.QueryInterface(const IID: TGUID; out Obj): HResult;
begin
  if GetInterface(IID, Obj) then
    Result := 0
  else
    Result := E_NOINTERFACE;
end;

function TDbContext._AddRef: Integer;
begin
  Result := -1; // Disable ref counting
end;

function TDbContext._Release: Integer;
begin
  Result := -1; // Disable ref counting
end;

function TDbContext.Connection: IDbConnection;
begin
  Result := FConnection;
end;

function TDbContext.Dialect: ISQLDialect;
begin
  Result := FDialect;
end;

procedure TDbContext.BeginTransaction;
begin
  FTransaction := FConnection.BeginTransaction;
end;

procedure TDbContext.Commit;
begin
  if FTransaction <> nil then
  begin
    FTransaction.Commit;
    FTransaction := nil;
  end;
end;

procedure TDbContext.Rollback;
begin
  if FTransaction <> nil then
  begin
    FTransaction.Rollback;
    FTransaction := nil;
  end;
end;

function TDbContext.Entities<T>: IDbSet<T>;
var
  TypeInfo: PTypeInfo;
  NewSet: IDbSet<T>;
begin
  TypeInfo := System.TypeInfo(T);
  
  if not FCache.ContainsKey(TypeInfo) then
  begin
    // Create the DbSet instance.
    // Note: TDbSet<T> constructor expects IDbContext. 
    // Since we are TDbContext (implementing IDbContext), we pass Self.
    NewSet := TDbSet<T>.Create(Self);
    FCache.Add(TypeInfo, NewSet);
  end;
  
  Result := IDbSet<T>(FCache[TypeInfo]);
end;

end.
