{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2025 Cesar Romero & Dext Contributors             }
{                                                                           }
{***************************************************************************}
unit Dext.Web.DataApi;

interface

uses
  System.Classes,
  System.Rtti,
  System.SysUtils,
  System.Character,
  System.TypInfo,
  Dext.Logging,
  Dext.DI.Interfaces,
  Dext.Entity,
  Dext.Entity.Context,
  Dext.Entity.Core,
  Dext.Json,
  Dext.Json.Types,
  Dext.Web.Interfaces,
  Dext.Web.Routing,
  Dext.Web.Pipeline,
  Dext.Collections.Dict,
  Dext.Entity.Mapping,
  Dext.Entity.Drivers.Interfaces,
  Dext.Entity.TypeConverters,
  Dext.Entity.Dialects,
  Dext.Core.ValueConverters,
  Dext.OpenAPI.Extensions,
  Dext.Web.DataApi.Resolver,
  Dext.Web.DataApi.Utils,
  Dext.Web.ModelBinding,
  Dext.Core.Reflection,
  Dext.Specifications.Base,
  Dext.Specifications.Interfaces,
  Dext.Specifications.Parser,
  Dext.Collections,
  Dext.Logging.Global;

type
  TApiMethod = (amGet, amGetList, amPost, amPut, amDelete);
  TApiMethods = set of TApiMethod;

  const AllApiMethods = [amGet, amGetList, amPost, amPut, amDelete];

type
  /// <summary>
  ///   Configuration options for a Data API, allowing control over permissions, naming conventions, and Swagger.
  /// </summary>
  TDataApiOptions = class
  protected
    FAllowedMethods: TApiMethods;
    FTenantIdRequired: Boolean;
    FRequireAuthentication: Boolean;
    FRolesForRead: string;
    FRolesForWrite: string;
    FNamingStrategy: TCaseStyle;
    FEnumStyle: TEnumStyle;
    FContextClass: TClass;
    FEnableSwagger: Boolean;
    FSwaggerTag: string;
    FSwaggerDescription: string;
    FSql: string;
  public
    constructor Create;
    function Allow(AMethods: TApiMethods): TDataApiOptions;
    function RequireTenant(Value: Boolean = True): TDataApiOptions;
    function RequireAuth(Value: Boolean = True): TDataApiOptions;
    function RequireRole(const ARoles: string): TDataApiOptions;
    function RequireReadRole(const ARoles: string): TDataApiOptions;
    function RequireWriteRole(const ARoles: string): TDataApiOptions;
    function UseSnakeCase: TDataApiOptions;
    function UseCamelCase: TDataApiOptions;
    function UseSwagger(Value: Boolean = True): TDataApiOptions;
    function Tag(const ATag: string): TDataApiOptions;
    function Description(const ADescription: string): TDataApiOptions;
    function DbContext(AContextClass: TClass): TDataApiOptions; overload;
    function DbContext<TCtx: class>: TDataApiOptions; overload;
    function UseSql(const ASql: string): TDataApiOptions;
    function EnumsAsStrings: TDataApiOptions;
    function EnumsAsNumbers: TDataApiOptions;

    property Sql: string read FSql write FSql;
    property AllowedMethods: TApiMethods read FAllowedMethods write FAllowedMethods;
    property TenantIdRequired: Boolean read FTenantIdRequired write FTenantIdRequired;
    property RequireAuthentication: Boolean read FRequireAuthentication write FRequireAuthentication;
    property RolesForRead: string read FRolesForRead write FRolesForRead;
    property RolesForWrite: string read FRolesForWrite write FRolesForWrite;
    property ContextClass: TClass read FContextClass write FContextClass;
    property EnableSwagger: Boolean read FEnableSwagger write FEnableSwagger;
    property SwaggerTag: string read FSwaggerTag write FSwaggerTag;
    property SwaggerDescription: string read FSwaggerDescription write FSwaggerDescription;
    property NamingStrategy: TCaseStyle read FNamingStrategy write FNamingStrategy;
    property EnumStyle: TEnumStyle read FEnumStyle write FEnumStyle;
    
    class var FDefaults: TDataApiOptions;
    class constructor Create;
    class destructor Destroy;
    class function Defaults: TDataApiOptions;
  end;

  /// <summary>
  ///   Fluent builder for configuring Data API options.
  /// </summary>
  TDataApiOptionsBuilder = record
  private
    FAllowedMethods: TApiMethods;
    FTenantIdRequired: Boolean;
    FRequireAuthentication: Boolean;
    FRolesForRead: string;
    FRolesForWrite: string;
    FNamingStrategy: TCaseStyle;
    FEnumStyle: TEnumStyle;
    FContextClass: TClass;
    FEnableSwagger: Boolean;
    FSwaggerTag: string;
    FSwaggerDescription: string;
    FSql: string;
  public
    class function Create: TDataApiOptionsBuilder; static;
    function Allow(AMethods: TApiMethods): TDataApiOptionsBuilder;
    function RequireTenant(Value: Boolean = True): TDataApiOptionsBuilder;
    function RequireAuth(Value: Boolean = True): TDataApiOptionsBuilder;
    function RequireRole(const ARoles: string): TDataApiOptionsBuilder;
    function RequireReadRole(const ARoles: string): TDataApiOptionsBuilder;
    function RequireWriteRole(const ARoles: string): TDataApiOptionsBuilder;
    function UseSnakeCase: TDataApiOptionsBuilder;
    function UseCamelCase: TDataApiOptionsBuilder;
    function UseSwagger(Value: Boolean = True): TDataApiOptionsBuilder;
    function Tag(const ATag: string): TDataApiOptionsBuilder;
    function Description(const ADescription: string): TDataApiOptionsBuilder;
    function DbContext(AContextClass: TClass): TDataApiOptionsBuilder; overload;
    function DbContext<TCtx: class>: TDataApiOptionsBuilder; overload;
    function ContextClass(AContextClass: TClass): TDataApiOptionsBuilder;
    function UseSql(const ASql: string): TDataApiOptionsBuilder;
    function EnumsAsStrings: TDataApiOptionsBuilder;
    function EnumsAsNumbers: TDataApiOptionsBuilder;

    function Build: TDataApiOptions;
    class operator Implicit(const ABuilder: TDataApiOptionsBuilder): TDataApiOptions;
  end;

  /// <summary>
  ///   Attribute to mark an entity class for automatic Data API generation.
  /// </summary>
  DataApiAttribute = class(TCustomAttribute)
  private
    FRoute: string;
    FDbContext: TClass;
  public
    constructor Create(const ARoute: string = ''; ADbContext: TClass = nil);
    property Route: string read FRoute;
    property DbContext: TClass read FDbContext;
  end;

  /// <summary>
  ///   Attribute to exclude a specific entity class from automatic Data API generation.
  /// </summary>
  DataApiIgnoreAttribute = class(TCustomAttribute);

  /// <summary>
  ///   Strong-typed options for Data API generation.
  /// </summary>
  TDataApiOptions<T: class> = class(TDataApiOptions)
  public
    // Fluent configuration
    function Allow(AMethods: TApiMethods): TDataApiOptions<T>;
    function RequireTenant(Value: Boolean = True): TDataApiOptions<T>;
    function RequireAuth(Value: Boolean = True): TDataApiOptions<T>;
    function RequireRole(const ARoles: string): TDataApiOptions<T>;
    function RequireReadRole(const ARoles: string): TDataApiOptions<T>;
    function RequireWriteRole(const ARoles: string): TDataApiOptions<T>;
    function UseSnakeCase: TDataApiOptions<T>;
    function UseCamelCase: TDataApiOptions<T>;
    function UseSwagger(Value: Boolean = True): TDataApiOptions<T>;
    function Tag(const ATag: string): TDataApiOptions<T>;
    function Description(const ADescription: string): TDataApiOptions<T>;
    function DbContext(AContextClass: TClass): TDataApiOptions<T>; overload;
    function DbContext<TCtx: class>: TDataApiOptions<T>; overload;
    function UseSql(const ASql: string): TDataApiOptions<T>;
    function EnumsAsStrings: TDataApiOptions<T>;
    function EnumsAsNumbers: TDataApiOptions<T>;
  end;

  /// <summary>
  ///   Base handler for Data APIs using dynamic TClass and IDbSet.
  /// </summary>
  TDataApiHandler = class
  protected
    FRoutePrefix: string;
    FOptions: TDataApiOptions;
    FDbContext: TDbContext;
    FEntityClass: TClass;
    FSerializer: TDextSerializer;

    procedure RegisterRoutes(const ABuilder: IApplicationBuilder);
    function CheckAuthorization(const Context: IHttpContext; AIsWrite: Boolean): IResult;
    function GetJsonSettings: TJsonSettings;
    procedure ApplyQueryParameters(const Context: IHttpContext; const ASpec: ISpecification);
    function ResolvePropertyName(const ASnakeName: string): string;
    function GetDbContext(const Context: IHttpContext): TDbContext;
    function ValueToJson(const AValue: TValue): string;
  public
    constructor Create(const ARoutePrefix: string; AEntityClass: TClass; AOptions: TDataApiOptions = nil; ADbContext: TDbContext = nil);
    destructor Destroy; override;

    // Handlers
    function HandleGetList(const Context: IHttpContext): IResult;
    function HandleGet(const Context: IHttpContext): IResult;
    procedure HandlePost(const Context: IHttpContext; var Result: IResult);
    procedure HandlePut(const Context: IHttpContext; var Result: IResult);
    function HandleDelete(const Context: IHttpContext): IResult;

    class procedure Map(const ABuilder: IApplicationBuilder; const AClass: TClass; const APath: string = ''; ADbContext: TDbContext = nil; AOptions: TDataApiOptions = nil);
  end;

  /// <summary>
  ///   Strong-typed version of DataAPI handler for backward compatibility and fluent API.
  /// </summary>
  TDataApiHandler<T: class, constructor> = class(TDataApiHandler)
  public
    constructor Create(const ARoutePrefix: string; AOptions: TDataApiOptions<T>; ADbContext: TDbContext = nil);
    class procedure Map(const ABuilder: IApplicationBuilder; const APath: string; ADbContext: TDbContext = nil; AOptions: TDataApiOptions<T> = nil); overload;
    class procedure Map(const ABuilder: IApplicationBuilder; const APath: string; AOptions: TDataApiOptions<T>); overload;
  end;

  /// <summary>
  ///   Public API for DataAPI registration and automatic scanning.
  /// </summary>
  TDataApi = class
  public
    class procedure Map(const ABuilder: IApplicationBuilder; const AClass: TClass; const APath: string = ''; AOptions: TDataApiOptions = nil);
    class procedure MapAll(const ABuilder: IApplicationBuilder);
  end;

/// <summary>Factory function returning a fluent builder for Data API options.</summary>
function DataApiOptions: TDataApiOptionsBuilder;

implementation

uses
  System.StrUtils,
  Dext.Http.StatusCodes,
  Dext.Web.Results,
  Dext.Json.Utf8,
  Dext.Auth.Identity,
  Dext.Collections.Base,
  System.JSON,
  Dext.Logging.Telemetry;

function ReadRequestBodyUtf8(const AStream: TStream): string;
var
  BodyLen: Integer;
  Bytes: TBytes;
begin
  if (AStream = nil) or (AStream.Size = 0) then
    Exit('');

  BodyLen := Integer(AStream.Size);
  if AStream is TBytesStream then
    Bytes := TBytesStream(AStream).Bytes
  else
  begin
    AStream.Position := 0;
    SetLength(Bytes, BodyLen);
    if BodyLen > 0 then
      AStream.ReadBuffer(Bytes[0], BodyLen);
  end;

  Result := TEncoding.UTF8.GetString(Bytes, 0, BodyLen);
end;

{ TDataApiOptions }

constructor TDataApiOptions.Create;
begin
  inherited Create;
  FAllowedMethods := AllApiMethods;
  FTenantIdRequired := False;
  FNamingStrategy := TCaseStyle.CaseInherit;
  FEnumStyle := TEnumStyle.EnumInherit;
  FEnableSwagger := True;
end;

class constructor TDataApiOptions.Create;
begin
  FDefaults := TDataApiOptions.Create;
end;

class destructor TDataApiOptions.Destroy;
begin
  FDefaults.Free;
end;

class function TDataApiOptions.Defaults: TDataApiOptions;
begin
  Result := FDefaults;
end;

function TDataApiOptions.Allow(AMethods: TApiMethods): TDataApiOptions;
begin
  FAllowedMethods := AMethods;
  Result := Self;
end;

function TDataApiOptions.RequireTenant(Value: Boolean): TDataApiOptions;
begin
  FTenantIdRequired := Value;
  Result := Self;
end;

function TDataApiOptions.RequireAuth(Value: Boolean): TDataApiOptions;
begin
  FRequireAuthentication := Value;
  Result := Self;
end;

function TDataApiOptions.RequireRole(const ARoles: string): TDataApiOptions;
begin
  FRequireAuthentication := True;
  FRolesForRead := ARoles;
  FRolesForWrite := ARoles;
  Result := Self;
end;

function TDataApiOptions.RequireReadRole(const ARoles: string): TDataApiOptions;
begin
  FRequireAuthentication := True;
  FRolesForRead := ARoles;
  Result := Self;
end;

function TDataApiOptions.RequireWriteRole(const ARoles: string): TDataApiOptions;
begin
  FRequireAuthentication := True;
  FRolesForWrite := ARoles;
  Result := Self;
end;

function TDataApiOptions.UseSnakeCase: TDataApiOptions;
begin
  FNamingStrategy := TCaseStyle.SnakeCase;
  Result := Self;
end;

function TDataApiOptions.UseCamelCase: TDataApiOptions;
begin
  FNamingStrategy := TCaseStyle.CamelCase;
  Result := Self;
end;

function TDataApiOptions.UseSwagger(Value: Boolean): TDataApiOptions;
begin
  FEnableSwagger := Value;
  Result := Self;
end;

function TDataApiOptions.Tag(const ATag: string): TDataApiOptions;
begin
  FSwaggerTag := ATag;
  Result := Self;
end;

function TDataApiOptions.Description(const ADescription: string): TDataApiOptions;
begin
  FSwaggerDescription := ADescription;
  Result := Self;
end;

function TDataApiOptions.DbContext(AContextClass: TClass): TDataApiOptions;
begin
  FContextClass := AContextClass;
  Result := Self;
end;

function TDataApiOptions.DbContext<TCtx>: TDataApiOptions;
begin
  FContextClass := TCtx;
  Result := Self;
end;

function TDataApiOptions.UseSql(const ASql: string): TDataApiOptions;
begin
  FSql := ASql;
  Result := Self;
end;

function TDataApiOptions.EnumsAsStrings: TDataApiOptions;
begin
  FEnumStyle := TEnumStyle.AsString;
  Result := Self;
end;

function TDataApiOptions.EnumsAsNumbers: TDataApiOptions;
begin
  FEnumStyle := TEnumStyle.AsNumber;
  Result := Self;
end;

{ TDataApiOptionsBuilder }

class function TDataApiOptionsBuilder.Create: TDataApiOptionsBuilder;
begin
  Result.FAllowedMethods := AllApiMethods;
  Result.FTenantIdRequired := False;
  Result.FRequireAuthentication := False;
  Result.FRolesForRead := '';
  Result.FRolesForWrite := '';
  Result.FNamingStrategy := TCaseStyle.CaseInherit;
  Result.FEnumStyle := TEnumStyle.EnumInherit;
  Result.FContextClass := nil;
  Result.FEnableSwagger := True;
  Result.FSwaggerTag := '';
  Result.FSwaggerDescription := '';
  Result.FSql := '';
end;

function TDataApiOptionsBuilder.Allow(AMethods: TApiMethods): TDataApiOptionsBuilder;
begin
  Result := Self;
  Result.FAllowedMethods := AMethods;
end;

function TDataApiOptionsBuilder.RequireTenant(Value: Boolean): TDataApiOptionsBuilder;
begin
  Result := Self;
  Result.FTenantIdRequired := Value;
end;

function TDataApiOptionsBuilder.RequireAuth(Value: Boolean): TDataApiOptionsBuilder;
begin
  Result := Self;
  Result.FRequireAuthentication := Value;
end;

function TDataApiOptionsBuilder.RequireRole(const ARoles: string): TDataApiOptionsBuilder;
begin
  Result := Self;
  Result.FRequireAuthentication := True;
  Result.FRolesForRead := ARoles;
  Result.FRolesForWrite := ARoles;
end;

function TDataApiOptionsBuilder.RequireReadRole(const ARoles: string): TDataApiOptionsBuilder;
begin
  Result := Self;
  Result.FRequireAuthentication := True;
  Result.FRolesForRead := ARoles;
end;

function TDataApiOptionsBuilder.RequireWriteRole(const ARoles: string): TDataApiOptionsBuilder;
begin
  Result := Self;
  Result.FRequireAuthentication := True;
  Result.FRolesForWrite := ARoles;
end;

function TDataApiOptionsBuilder.UseSnakeCase: TDataApiOptionsBuilder;
begin
  Result := Self;
  Result.FNamingStrategy := TCaseStyle.SnakeCase;
end;

function TDataApiOptionsBuilder.UseCamelCase: TDataApiOptionsBuilder;
begin
  Result := Self;
  Result.FNamingStrategy := TCaseStyle.CamelCase;
end;

function TDataApiOptionsBuilder.UseSwagger(Value: Boolean): TDataApiOptionsBuilder;
begin
  Result := Self;
  Result.FEnableSwagger := Value;
end;

function TDataApiOptionsBuilder.Tag(const ATag: string): TDataApiOptionsBuilder;
begin
  Result := Self;
  Result.FSwaggerTag := ATag;
end;

function TDataApiOptionsBuilder.Description(const ADescription: string): TDataApiOptionsBuilder;
begin
  Result := Self;
  Result.FSwaggerDescription := ADescription;
end;

function TDataApiOptionsBuilder.DbContext(AContextClass: TClass): TDataApiOptionsBuilder;
begin
  Result := Self;
  Result.FContextClass := AContextClass;
end;

function TDataApiOptionsBuilder.DbContext<TCtx>: TDataApiOptionsBuilder;
begin
  Result := Self;
  Result.FContextClass := TCtx;
end;

function TDataApiOptionsBuilder.ContextClass(AContextClass: TClass): TDataApiOptionsBuilder;
begin
  Result := Self;
  Result.FContextClass := AContextClass;
end;

function TDataApiOptionsBuilder.UseSql(const ASql: string): TDataApiOptionsBuilder;
begin
  Result := Self;
  Result.FSql := ASql;
end;

function TDataApiOptionsBuilder.EnumsAsStrings: TDataApiOptionsBuilder;
begin
  Result := Self;
  Result.FEnumStyle := TEnumStyle.AsString;
end;

function TDataApiOptionsBuilder.EnumsAsNumbers: TDataApiOptionsBuilder;
begin
  Result := Self;
  Result.FEnumStyle := TEnumStyle.AsNumber;
end;

function TDataApiOptionsBuilder.Build: TDataApiOptions;
begin
  Result := TDataApiOptions.Create;
  Result.AllowedMethods := FAllowedMethods;
  Result.TenantIdRequired := FTenantIdRequired;
  Result.RequireAuthentication := FRequireAuthentication;
  Result.RolesForRead := FRolesForRead;
  Result.RolesForWrite := FRolesForWrite;
  Result.NamingStrategy := FNamingStrategy;
  Result.EnumStyle := FEnumStyle;
  Result.ContextClass := FContextClass;
  Result.EnableSwagger := FEnableSwagger;
  Result.SwaggerTag := FSwaggerTag;
  Result.SwaggerDescription := FSwaggerDescription;
  Result.Sql := FSql;
end;

class operator TDataApiOptionsBuilder.Implicit(const ABuilder: TDataApiOptionsBuilder): TDataApiOptions;
begin
  Result := ABuilder.Build;
end;

{ TDataApiOptions<T> }

function TDataApiOptions<T>.Allow(AMethods: TApiMethods): TDataApiOptions<T>;
begin
  FAllowedMethods := AMethods;
  Result := Self;
end;

function TDataApiOptions<T>.RequireTenant(Value: Boolean): TDataApiOptions<T>;
begin
  FTenantIdRequired := Value;
  Result := Self;
end;

function TDataApiOptions<T>.RequireAuth(Value: Boolean): TDataApiOptions<T>;
begin
  FRequireAuthentication := Value;
  Result := Self;
end;

function TDataApiOptions<T>.RequireRole(const ARoles: string): TDataApiOptions<T>;
begin
  FRequireAuthentication := True;
  FRolesForRead := ARoles;
  FRolesForWrite := ARoles;
  Result := Self;
end;

function TDataApiOptions<T>.RequireReadRole(const ARoles: string): TDataApiOptions<T>;
begin
  FRequireAuthentication := True;
  FRolesForRead := ARoles;
  Result := Self;
end;

function TDataApiOptions<T>.RequireWriteRole(const ARoles: string): TDataApiOptions<T>;
begin
  FRequireAuthentication := True;
  FRolesForWrite := ARoles;
  Result := Self;
end;

function TDataApiOptions<T>.UseSnakeCase: TDataApiOptions<T>;
begin
  FNamingStrategy := TCaseStyle.SnakeCase;
  Result := Self;
end;

function TDataApiOptions<T>.UseCamelCase: TDataApiOptions<T>;
begin
  FNamingStrategy := TCaseStyle.CamelCase;
  Result := Self;
end;

function TDataApiOptions<T>.UseSwagger(Value: Boolean): TDataApiOptions<T>;
begin
  FEnableSwagger := Value;
  Result := Self;
end;

function TDataApiOptions<T>.Tag(const ATag: string): TDataApiOptions<T>;
begin
  FSwaggerTag := ATag;
  Result := Self;
end;

function TDataApiOptions<T>.Description(const ADescription: string): TDataApiOptions<T>;
begin
  FSwaggerDescription := ADescription;
  Result := Self;
end;

function TDataApiOptions<T>.DbContext(AContextClass: TClass): TDataApiOptions<T>;
begin
  FContextClass := AContextClass;
  Result := Self;
end;

function TDataApiOptions<T>.DbContext<TCtx>: TDataApiOptions<T>;
begin
  FContextClass := TCtx;
  Result := Self;
end;

function TDataApiOptions<T>.UseSql(const ASql: string): TDataApiOptions<T>;
begin
  FSql := ASql;
  Result := Self;
end;

function TDataApiOptions<T>.EnumsAsStrings: TDataApiOptions<T>;
begin
  FEnumStyle := TEnumStyle.AsString;
  Result := Self;
end;

function TDataApiOptions<T>.EnumsAsNumbers: TDataApiOptions<T>;
begin
  FEnumStyle := TEnumStyle.AsNumber;
  Result := Self;
end;

function DataApiOptions: TDataApiOptionsBuilder;
begin
  Result := TDataApiOptionsBuilder.Create;
end;

{ DataApiAttribute }

constructor DataApiAttribute.Create(const ARoute: string; ADbContext: TClass);
begin
  FRoute := ARoute;
  FDbContext := ADbContext;
end;

{ TDataApiHandler }

constructor TDataApiHandler.Create(const ARoutePrefix: string; AEntityClass: TClass; AOptions: TDataApiOptions;
  ADbContext: TDbContext);
begin
  inherited Create;
  FRoutePrefix := ARoutePrefix;
  FEntityClass := AEntityClass;
  FOptions := AOptions;
  FDbContext := ADbContext;
  if FOptions = nil then
    FOptions := TDataApiOptions.Create;
  FSerializer := TDextSerializer.Create(GetJsonSettings);
end;

destructor TDataApiHandler.Destroy;
begin
  FSerializer.Free;
  FOptions.Free;
  inherited;
end;

function TDataApiHandler.GetDbContext(const Context: IHttpContext): TDbContext;
begin
  if FDbContext <> nil then
    Exit(FDbContext);
    
  if FOptions.ContextClass <> nil then
    Result := Context.Services.GetService(TServiceType.FromClass(FOptions.ContextClass)) as TDbContext
  else
    Result := TDextServices.GetServiceObject<TDbContext>(Context.Services);
    
  if Result = nil then
    raise Exception.Create('DbContext not found in DI container for DataAPI');
end;

function TDataApiHandler.CheckAuthorization(const Context: IHttpContext; AIsWrite: Boolean): IResult;
var
  RequiredRoles: string;
  HasRole: Boolean;
  Len: Integer;
  PosIdx: Integer;
  StartIdx: Integer;
  EndIdx: Integer;
  Role: string;
begin
  Result := nil;
  if not FOptions.RequireAuthentication then Exit;

  if not Context.User.Identity.IsAuthenticated then
    Exit(Results.StatusCode(401, '{"error":"Unauthorized"}'));

  RequiredRoles := IfThen(AIsWrite, FOptions.RolesForWrite, FOptions.RolesForRead);
  if RequiredRoles <> '' then
  begin
    HasRole := False;
    Len := Length(RequiredRoles);
    PosIdx := 1;
    while PosIdx <= Len do
    begin
      while (PosIdx <= Len) and ((RequiredRoles[PosIdx] = ',') or
        (RequiredRoles[PosIdx] = ' ') or (RequiredRoles[PosIdx] = #9)) do
        Inc(PosIdx);
      if PosIdx > Len then
        Break;

      StartIdx := PosIdx;
      while (PosIdx <= Len) and (RequiredRoles[PosIdx] <> ',') do
        Inc(PosIdx);
      EndIdx := PosIdx - 1;
      while (EndIdx >= StartIdx) and ((RequiredRoles[EndIdx] = ' ') or
        (RequiredRoles[EndIdx] = #9)) do
        Dec(EndIdx);

      if StartIdx <= EndIdx then
      begin
        Role := Copy(RequiredRoles, StartIdx, EndIdx - StartIdx + 1);
        if Context.User.IsInRole(Role) then
        begin
          HasRole := True;
          Break;
        end;
      end;
      Inc(PosIdx);
    end;
      
    if not HasRole then
      Result := Results.StatusCode(403, '{"error":"Forbidden"}');
  end;
end;

function TDataApiHandler.ValueToJson(const AValue: TValue): string;
begin
  Result := FSerializer.Serialize(AValue);
end;

function TDataApiHandler.GetJsonSettings: TJsonSettings;
begin
  Result := TJsonSettings.Default;
  Result.CaseStyle := FOptions.NamingStrategy;
  Result.EnumStyle := FOptions.EnumStyle;
end;

procedure TDataApiHandler.ApplyQueryParameters(const Context: IHttpContext; const ASpec: ISpecification);
var
  PropName, BinaryOp, ValStr: string;
  Param: TPair<string, string>;
  ActualName: string;
  Expr: IExpression;
begin
  for Param in Context.Request.Query.ToArray do
  begin
    // Reservas de paginação
    if Param.Key = '_limit' then begin ASpec.Take(StrToIntDef(Param.Value, 50)); Continue; end;
    if Param.Key = '_offset' then begin ASpec.Skip(StrToIntDef(Param.Value, 0)); Continue; end;
    
    // Filtros dinâmicos
    BinaryOp := '=';
    PropName := Param.Key;

    if PropName.EndsWith('_gt') then begin BinaryOp := '>'; PropName := PropName.Substring(0, PropName.Length - 3); end
    else if PropName.EndsWith('_gte') then begin BinaryOp := '>='; PropName := PropName.Substring(0, PropName.Length - 4); end
    else if PropName.EndsWith('_lt') then begin BinaryOp := '<'; PropName := PropName.Substring(0, PropName.Length - 3); end
    else if PropName.EndsWith('_lte') then begin BinaryOp := '<='; PropName := PropName.Substring(0, PropName.Length - 4); end
    else if PropName.EndsWith('_neq') then begin BinaryOp := '<>'; PropName := PropName.Substring(0, PropName.Length - 4); end
    else if PropName.EndsWith('_like') then begin BinaryOp := 'LIKE'; PropName := PropName.Substring(0, PropName.Length - 5); end;

    ActualName := ResolvePropertyName(PropName);
    if ActualName <> '' then
    begin
       ValStr := Param.Value;
       Expr := TStringExpressionParser.Parse(ActualName + ' ' + BinaryOp + ' ' + ValStr);
       if Expr <> nil then
         ASpec.Where(Expr);
    end;
  end;
end;

function TDataApiHandler.ResolvePropertyName(const ASnakeName: string): string;
var
  Meta: TTypeMetadata;
  Handler: IPropertyHandler;
begin
  Result := '';
  Meta := TReflection.GetMetadata(FEntityClass.ClassInfo);
  Handler := Meta.GetHandlerBySnakeCase(ASnakeName);
  if Handler <> nil then
    Result := Handler.Name;
end;

procedure TDataApiHandler.RegisterRoutes(const ABuilder: IApplicationBuilder);
var
  CleanPath: string;
begin
  CleanPath := FRoutePrefix.TrimRight(['/']);
  if amGetList in FOptions.AllowedMethods then
    ABuilder.MapGet(CleanPath, procedure(C: IHttpContext) begin HandleGetList(C).Execute(C); end);
    
  if amGet in FOptions.AllowedMethods then
    ABuilder.MapGet(CleanPath + '/{id}', procedure(C: IHttpContext) begin HandleGet(C).Execute(C); end);
    
  if amPost in FOptions.AllowedMethods then
    ABuilder.MapPost(CleanPath, procedure(C: IHttpContext)
      var
        R: IResult;
      begin
        HandlePost(C, R);
        R.Execute(C);
      end);
    
  if amPut in FOptions.AllowedMethods then
    ABuilder.MapPut(CleanPath + '/{id}', procedure(C: IHttpContext)
      var
        R: IResult;
      begin
        HandlePut(C, R);
        R.Execute(C);
      end);
    
  if amDelete in FOptions.AllowedMethods then
  begin
    ABuilder.MapDelete(CleanPath + '/{id}',
      procedure(C: IHttpContext)
      begin
        HandleDelete(C).Execute(C);
      end);
  end;
end;

class procedure TDataApiHandler.Map(const ABuilder: IApplicationBuilder; const AClass: TClass; const APath: string; ADbContext: TDbContext; AOptions: TDataApiOptions);
var
  Path: string;
  Handler: TDataApiHandler;
begin
  Path := APath;
  if Path = '' then
    Path := TDataApiNaming.GetDefaultPath(AClass.ClassInfo);
    
  Handler := TDataApiHandler.Create(Path, AClass, AOptions, ADbContext);
  Handler.RegisterRoutes(ABuilder);
  ABuilder.RegisterForDisposal(Handler);
end;

function TDataApiHandler.HandleGetList(const Context: IHttpContext): IResult;
var
  DbCtx: TDbContext;
  SetObj: IDbSet;
  List: IList<TObject>;
  Spec: ISpecification;
  Auth: IResult;
begin
  Log.Debug('DataApi: Listing {0}', [FEntityClass.ClassName]);
  try
    Auth := CheckAuthorization(Context, False);
    if Auth <> nil then Exit(Auth);

    DbCtx := GetDbContext(Context);
    SetObj := DbCtx.DataSet(FEntityClass.ClassInfo);

    Spec := TSpecification<TObject>.Create;
    ApplyQueryParameters(Context, Spec);

    List := SetObj.ListObjects(Spec);
    Result := Results.Json(ValueToJson(TValue.From<IObjectList>(List as IObjectList)));
  except
    on E: Exception do
    begin
      Log.Error(E, 'DataApi: Error listing {0}', [FEntityClass.ClassName]);
      Result := Results.StatusCode(500, E.Message);
    end;
  end;
end;

function TDataApiHandler.HandleGet(const Context: IHttpContext): IResult;
var
  DbCtx: TDbContext;
  IdStr: string;
  PKValue: Variant;
  Entity: TObject;
  Binder: IModelBinder;
  Auth: IResult;
begin
  Log.Debug('DataApi: Getting {0}', [FEntityClass.ClassName]);
  try
    Auth := CheckAuthorization(Context, False);
    if Auth <> nil then Exit(Auth);

    if not Context.Request.RouteParams.TryGetValue('id', IdStr) then
      Exit(Results.BadRequest('Missing id'));

    DbCtx := GetDbContext(Context);
    Binder := TDextServices.GetService<IModelBinder>(Context.Services);
    PKValue := TEntityIdResolver.Resolve(DbCtx.GetMapping(FEntityClass.ClassInfo) as TEntityMap, IdStr, Binder);
    Entity := DbCtx.DataSet(FEntityClass.ClassInfo).FindObject(PKValue);
    
    if Entity = nil then
      Result := Results.NotFound
    else
      Result := Results.Json(ValueToJson(TValue.From<TObject>(Entity)));
  except
    on E: Exception do
    begin
      Log.Error(E, 'DataApi: Error getting {0}', [FEntityClass.ClassName]);
      Result := Results.StatusCode(500, E.Message);
    end;
  end;
end;

procedure TDataApiHandler.HandlePost(const Context: IHttpContext; var Result: IResult);
var
  DbCtx: TDbContext;
  Entity: TObject;
  Stream: TStream;
  JsonString: string;
  Auth: IResult;
  TelemetryPayload: TJSONObject;
  DeserializedValue: TValue;
  TelemetryComplete: TJSONObject;
  TelemetryActive: Boolean;
begin
  Log.Debug('DataApi: Creating {0}', [FEntityClass.ClassName]);
  TelemetryActive := TDiagnosticSource.Instance.IsActive;
  try
    Auth := CheckAuthorization(Context, True);
    if Auth <> nil then begin Result := Auth; Exit; end;

    DbCtx := GetDbContext(Context);
    
    Stream := Context.Request.Body;
    if (Stream = nil) or (Stream.Size = 0) then
      raise Exception.Create('Request body is empty');

    JsonString := ReadRequestBodyUtf8(Stream);

    if TelemetryActive then
    begin
      TelemetryPayload := TJSONObject.Create;
      TelemetryPayload.AddPair('Entity', FEntityClass.ClassName);
      TelemetryPayload.AddPair('Action', 'Deserialization');
      TDiagnosticSource.Instance.Write('DataApi.ModelBinding.Start', TelemetryPayload, 'API');
    end;

    DeserializedValue := TDextJson.Deserialize(FEntityClass.ClassInfo, JsonString, GetJsonSettings);
    Entity := DeserializedValue.AsObject;
    if Entity = nil then
      raise Exception.Create('Could not deserialize request body.');

    if TelemetryActive then
    begin
      TelemetryComplete := TJSONObject.Create;
      TelemetryComplete.AddPair('Entity', FEntityClass.ClassName);
      TelemetryComplete.AddPair('Action', 'Tracking');
      TDiagnosticSource.Instance.Write('DataApi.ModelBinding.Complete', TelemetryComplete, 'API');
    end;

    DbCtx.DataSet(FEntityClass.ClassInfo).Add(Entity);
    DbCtx.SaveChanges;
    
    Result := Results.Json(ValueToJson(TValue.From<TObject>(Entity)), 201);
  except
    on E: Exception do
    begin
      Log.Error(E, 'DataApi: Error creating {0}', [FEntityClass.ClassName]);
      Result := Results.StatusCode(500, E.Message);
    end;
  end;
end;

procedure TDataApiHandler.HandlePut(const Context: IHttpContext; var Result: IResult);
var
  DbCtx: TDbContext;
  IdStr: string;
  Entity: TObject;
  Stream: TStream;
  JsonString: string;
  Auth: IResult;
begin
  Log.Debug('DataApi: Updating {0}', [FEntityClass.ClassName]);
  try
    Auth := CheckAuthorization(Context, True);
    if Auth <> nil then begin Result := Auth; Exit; end;

    if not Context.Request.RouteParams.TryGetValue('id', IdStr) then
    begin
      Result := Results.BadRequest('Missing id');
      Exit;
    end;

    DbCtx := GetDbContext(Context);
    
    Stream := Context.Request.Body;
    if (Stream = nil) or (Stream.Size = 0) then
      raise Exception.Create('Request body is empty');

    JsonString := ReadRequestBodyUtf8(Stream);

    Entity := TDextJson.Deserialize(FEntityClass.ClassInfo, JsonString, GetJsonSettings).AsObject;
    if Entity = nil then
      raise Exception.Create('Could not deserialize request body.');

    DbCtx.DataSet(FEntityClass.ClassInfo).Update(Entity);
    DbCtx.SaveChanges;
    
    Result := Results.Json(ValueToJson(TValue.From<TObject>(Entity)));
  except
    on E: Exception do
    begin
      Log.Error(E, 'DataApi: Error updating {0}', [FEntityClass.ClassName]);
      Result := Results.StatusCode(500, E.Message);
    end;
  end;
end;

function TDataApiHandler.HandleDelete(const Context: IHttpContext): IResult;
var
  DbCtx: TDbContext;
  IdStr: string;
  PKValue: Variant;
  Existing: TObject;
  Binder: IModelBinder;
  Auth: IResult;
begin
  try
    Auth := CheckAuthorization(Context, True);
    if Auth <> nil then Exit(Auth);

    if not Context.Request.RouteParams.TryGetValue('id', IdStr) then
      Exit(Results.BadRequest('Missing id'));

    DbCtx := GetDbContext(Context);
    Binder := TDextServices.GetService<IModelBinder>(Context.Services);
    PKValue := TEntityIdResolver.Resolve(DbCtx.GetMapping(FEntityClass.ClassInfo) as TEntityMap, IdStr, Binder);
    Existing := DbCtx.DataSet(FEntityClass.ClassInfo).FindObject(PKValue);
    
    if Existing <> nil then
    begin
      DbCtx.DataSet(FEntityClass.ClassInfo).Remove(Existing);
      DbCtx.SaveChanges;
    end;
    
    Result := Results.Ok;
  except
    on E: Exception do
    begin
      Log.Error(E, 'DataApi: Error deleting {0}', [FEntityClass.ClassName]);
      Result := Results.StatusCode(500, E.Message);
    end;
  end;
end;

{ TDataApiHandler<T> }

constructor TDataApiHandler<T>.Create(const ARoutePrefix: string; AOptions: TDataApiOptions<T>; ADbContext: TDbContext);
begin
  inherited Create(ARoutePrefix, TClass(T), AOptions, ADbContext);
end;

class procedure TDataApiHandler<T>.Map(const ABuilder: IApplicationBuilder; const APath: string; ADbContext: TDbContext;
  AOptions: TDataApiOptions<T>);
begin
  TDataApiHandler.Map(ABuilder, TClass(T), APath, ADbContext, AOptions);
end;

class procedure TDataApiHandler<T>.Map(const ABuilder: IApplicationBuilder; const APath: string; AOptions: TDataApiOptions<T>);
begin
  Map(ABuilder, APath, nil, AOptions);
end;

{ TDataApi }

class procedure TDataApi.Map(const ABuilder: IApplicationBuilder; const AClass: TClass; const APath: string;
  AOptions: TDataApiOptions);
begin
  TDataApiHandler.Map(ABuilder, AClass, APath, nil, AOptions);
end;

class procedure TDataApi.MapAll(const ABuilder: IApplicationBuilder);
var
  LType: TRttiType;
  LAttr: DataApiAttribute;
  LPath: string;
  LAttribute: TCustomAttribute;
begin
  for LType in TReflection.Context.GetTypes do
  begin
    if LType.IsInstance and (LType.AsInstance.MetaclassType <> nil) and 
       not LType.Name.EndsWith('Helper') then
    begin
      LAttr := nil;
      for LAttribute in LType.GetAttributes do
      begin
        if LAttribute.ClassName.Contains('DataApi') then
        begin
          LAttr := DataApiAttribute(LAttribute);
          Break;
        end;
      end;

      if LAttr <> nil then
      begin
        LPath := LAttr.Route;
        if LPath = '' then
          LPath := TDataApiNaming.GetDefaultPath(LType.Handle);
          
        TDataApiHandler.Map(ABuilder, LType.AsInstance.MetaclassType, LPath, nil, nil);
      end;
    end;
  end;
end;



end.
