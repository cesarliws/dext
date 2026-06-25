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
unit Dext.Web.ModelBinding;

interface

uses
  System.Classes,
  System.Rtti,
  System.SysUtils,
  System.TypInfo,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.DI.Interfaces,
  Dext.Json,
  Dext.Json.Types,
  Dext.Types.UUID,
  Dext.Web.Interfaces,
  Dext.Utils;

type
  EBindingException = class(Exception);

  /// <summary>
  ///   Defines the source from where a model or parameter should be bound.
  /// </summary>
  TBindingSource = (
    bsBody,     // JSON body
    bsQuery,    // Query string
    bsRoute,    // Route parameters
    bsHeader,   // HTTP headers
    bsServices, // DI Container
    bsForm      // Form data (future)
  );

  /// <summary>
  ///   Base class for binding attributes.
  /// </summary>
  BindingAttribute = class abstract(TCustomAttribute)
  private
    FSource: TBindingSource;
  public
    constructor Create(ASource: TBindingSource);
    /// <summary>Data source (Body, Query, Route, Header, etc.).</summary>
    property Source: TBindingSource read FSource;
  end;

  /// <summary>Attribute to bind a parameter from the request body (JSON).</summary>
  FromBodyAttribute = class(BindingAttribute)
  public
    constructor Create; overload;
  end;

  /// <summary>Attribute to bind a parameter from the query string.</summary>
  FromQueryAttribute = class(BindingAttribute)
  private
    FName: string;
  public
    constructor Create; overload;
    constructor Create(const AName: string); overload;
    property Name: string read FName;
  end;

  /// <summary>Attribute to bind a parameter from route data ({id}).</summary>
  FromRouteAttribute = class(BindingAttribute)
  private
    FName: string;
  public
    constructor Create; overload;
    constructor Create(const AName: string); overload;
    property Name: string read FName;
  end;

  /// <summary>Attribute to bind a parameter from HTTP headers.</summary>
  FromHeaderAttribute = class(BindingAttribute)
  private
    FName: string;
  public
    constructor Create; overload;
    constructor Create(const AName: string); overload;
    property Name: string read FName;
  end;

  /// <summary>Attribute to inject a service directly from the DI container into the handler parameter.</summary>
  FromServicesAttribute = class(BindingAttribute)
  public
    constructor Create; overload;
  end;

  /// <summary>
  ///   Defines the contract for model binding.
  /// </summary>
  IModelBinder = interface
    ['{6CDDAA4C-EB6B-42F0-A138-614FFBA931A5}']
    /// <summary>Binds a model from the request body (JSON).</summary>
    function BindBody(AType: PTypeInfo; Context: IHttpContext): TValue;
    
    /// <summary>Binds a model from the query string.</summary>
    function BindQuery(AType: PTypeInfo; Context: IHttpContext): TValue;
    
    /// <summary>Binds a model from route parameters.</summary>
    function BindRoute(AType: PTypeInfo; Context: IHttpContext): TValue;
    
    /// <summary>Binds a model from HTTP headers.</summary>
    function BindHeader(AType: PTypeInfo; Context: IHttpContext): TValue;
    
    /// <summary>Injects a dependency from the service container.</summary>
    function BindServices(AType: PTypeInfo; Context: IHttpContext): TValue;

    /// <summary>Binds all parameters of a controller/handler method.</summary>
    function BindMethodParameters(AMethod: TRttiMethod; AContext: IHttpContext): TArray<TValue>;
    
    /// <summary>Binds a single parameter, applying inference rules if necessary.</summary>
    function BindParameter(AParam: TRttiParameter; AContext: IHttpContext): TValue;

    /// <summary>
    ///   Performs hybrid binding of a Record. 
    ///   Fields can come from different sources based on meta-informative attributes.
    /// </summary>
    function BindRecordHybrid(AType: PTypeInfo; Context: IHttpContext): TValue;

    /// <summary>Converts a raw string value to the specified native type via RTTI.</summary>
    function BindValue(const AValue: string; AType: PTypeInfo): TValue;
  end;

  /// <summary>
  ///   Dext Model Binding mechanism.
  ///   Converts data from various HTTP sources to native Delphi types using RTTI.
  /// </summary>
  TModelBinder = class(TInterfacedObject, IModelBinder)
  private
    function BindBodyPrimitive(AParam: TRttiParameter; Context: IHttpContext): TValue;
  public
    constructor Create;
    destructor Destroy; override;

    // Interface methods
    function BindBody(AType: PTypeInfo; Context: IHttpContext): TValue; overload;
    function BindQuery(AType: PTypeInfo; Context: IHttpContext): TValue; overload;
    function BindRoute(AType: PTypeInfo; Context: IHttpContext): TValue; overload;
    function BindHeader(AType: PTypeInfo; Context: IHttpContext): TValue;
    function BindServices(AType: PTypeInfo; Context: IHttpContext): TValue;

    // Helper methods with generics
    /// <summary>Binds and deserializes the request body to type T.</summary>
    function BindBody<T>(Context: IHttpContext): T; overload;
    /// <summary>Binds the query string to type T (record or class).</summary>
    function BindQuery<T>(Context: IHttpContext): T; overload;
    /// <summary>Binds route parameters to type T.</summary>
    function BindRoute<T>(Context: IHttpContext): T; overload;

    function BindMethodParameters(AMethod: TRttiMethod; AContext: IHttpContext): TArray<TValue>;
    function BindParameter(AParam: TRttiParameter; AContext: IHttpContext): TValue;

    /// <summary>
    ///   Performs hybrid binding: record properties can come from different sources 
    ///   based on attributes (Header, Query, Route, Body).
    /// </summary>
    function BindRecordHybrid(AType: PTypeInfo; Context: IHttpContext): TValue;

    function BindValue(const AValue: string; AType: PTypeInfo): TValue;
  end;

  TModelBinderHelper = class
  public
    class function BindQuery<T>(ABinder: IModelBinder; Context: IHttpContext): T; static;
    class function BindBody<T>(ABinder: IModelBinder; Context: IHttpContext): T; static;
    class function BindRoute<T>(ABinder: IModelBinder; Context: IHttpContext): T; static;
  end;

  // BINDING PROVIDER
  IBindingSourceProvider = interface
    ['{8D4F3A7C-1E4A-4B8D-B0E7-9F3A8C5D2B1E}']
    function GetBindingSource(Param: TRttiParameter): TBindingSource;
    function GetBindingName(Param: TRttiParameter): string;
  end;

  TBindingSourceProvider = class(TInterfacedObject, IBindingSourceProvider)
  public
    function GetBindingSource(Field: TRttiField): TBindingSource; overload;
    function GetBindingName(Field: TRttiField): string; overload;

    function GetBindingSource(Param: TRttiParameter): TBindingSource; overload;
    function GetBindingName(Param: TRttiParameter): string; overload;
  end;


implementation

uses
  System.NetEncoding,
  System.Variants,
  Dext.Core.DateUtils,
  Dext.Core.Span,
  Dext.Entity.Attributes,
  Dext.Json.Utf8.Serializer,
  Dext.Core.Activator,
  Dext.Core.Reflection;


{ BindingAttribute }

constructor BindingAttribute.Create(ASource: TBindingSource);
begin
  inherited Create;
  FSource := ASource;
end;

{ FromBodyAttribute }

constructor FromBodyAttribute.Create;
begin
  inherited Create(bsBody);
end;

{ FromQueryAttribute }

constructor FromQueryAttribute.Create;
begin
  inherited Create(bsQuery);
end;

constructor FromQueryAttribute.Create(const AName: string);
begin
  inherited Create(bsQuery);
  FName := AName;
end;

{ FromRouteAttribute }

constructor FromRouteAttribute.Create;
begin
  inherited Create(bsRoute);
end;

constructor FromRouteAttribute.Create(const AName: string);
begin
  inherited Create(bsRoute);
  FName := AName;
end;

{ FromHeaderAttribute }

constructor FromHeaderAttribute.Create;
begin
  inherited Create(bsHeader);
end;

constructor FromHeaderAttribute.Create(const AName: string);
begin
  inherited Create(bsHeader);
  FName := AName;
end;

{ FromServicesAttribute }

constructor FromServicesAttribute.Create;
begin
  inherited Create(bsServices);
end;

{ TModelBinder }

constructor TModelBinder.Create;
begin
  inherited Create;
end;

destructor TModelBinder.Destroy;
begin

  inherited;
end;

function TModelBinder.BindBodyPrimitive(AParam: TRttiParameter; Context: IHttpContext): TValue;
var
  Stream: TStream;
  Bytes: TBytes;
  BodyJsonStr: string;
  JsonNode: IDextJsonNode;
  JsonObj: IDextJsonObject;
  NodeVal: IDextJsonNode;
begin
  Stream := Context.Request.Body;
  if (Stream = nil) or (Stream.Size = 0) then
    Exit(TReflection.GetDefaultValue(nil, AParam.ParamType.Handle));

  Stream.Position := 0;
  SetLength(Bytes, Stream.Size);
  if Stream.Size > 0 then
    Stream.ReadBuffer(Bytes[0], Stream.Size);
  BodyJsonStr := TEncoding.UTF8.GetString(Bytes);

  if BodyJsonStr <> '' then
  begin
    try
      JsonNode := TDextJson.Provider.Parse(BodyJsonStr);
      if (JsonNode <> nil) then
      begin
        if (JsonNode.GetNodeType = jntObject) then
        begin
          JsonObj := JsonNode as IDextJsonObject;
          if JsonObj.Contains(AParam.Name) then
          begin
            NodeVal := JsonObj.GetNode(AParam.Name);
            if (NodeVal <> nil) and not NodeVal.IsNull then
            begin
              if AParam.ParamType.Handle.Kind = tkDynArray then
              begin
                Result := TDextJson.Deserialize(AParam.ParamType.Handle, NodeVal.ToJson());
              end
              else
              begin
                case NodeVal.GetNodeType of
                  jntString: Result := TReflection.CastFromString(NodeVal.AsString, AParam.ParamType.Handle);
                  jntNumber: Result := TReflection.CastFromString(NodeVal.AsString, AParam.ParamType.Handle);
                  jntBoolean: Result := TValue.From<Boolean>(NodeVal.AsBoolean);
                  jntNull: Result := TReflection.GetDefaultValue(AParam, AParam.ParamType.Handle);
                else
                  Result := TReflection.CastFromString(NodeVal.AsString, AParam.ParamType.Handle);
                end;
              end;
            end
            else
              Result := TReflection.GetDefaultValue(AParam, AParam.ParamType.Handle);
          end
          else
            Result := TReflection.GetDefaultValue(AParam, AParam.ParamType.Handle);
          Exit;
        end;

        case JsonNode.GetNodeType of
          jntString: Result := TReflection.CastFromString(JsonNode.AsString, AParam.ParamType.Handle);
          jntNumber: Result := TReflection.CastFromString(JsonNode.AsString, AParam.ParamType.Handle);
          jntBoolean: Result := TValue.From<Boolean>(JsonNode.AsBoolean);
          jntNull: Result := TReflection.GetDefaultValue(nil, AParam.ParamType.Handle);
        else
          if AParam.ParamType.Handle.Kind = tkDynArray then
            Result := TDextJson.Deserialize(AParam.ParamType.Handle, BodyJsonStr)
          else if (Length(BodyJsonStr) >= 2) and (BodyJsonStr[1] = '"') and (BodyJsonStr[Length(BodyJsonStr)] = '"') then
            Result := TReflection.CastFromString(Copy(BodyJsonStr, 2, Length(BodyJsonStr) - 2), AParam.ParamType.Handle)
          else
            Result := TReflection.CastFromString(BodyJsonStr, AParam.ParamType.Handle);
        end;
      end
      else
        Result := TReflection.GetDefaultValue(nil, AParam.ParamType.Handle);
    except
      on E: Exception do
      begin
        if AParam.ParamType.Handle.Kind = tkDynArray then
          Result := TReflection.GetDefaultValue(nil, AParam.ParamType.Handle)
        else if (Length(BodyJsonStr) >= 2) and (BodyJsonStr[1] = '"') and (BodyJsonStr[Length(BodyJsonStr)] = '"') then
          Result := TReflection.CastFromString(Copy(BodyJsonStr, 2, Length(BodyJsonStr) - 2), AParam.ParamType.Handle)
        else
          Result := TReflection.CastFromString(BodyJsonStr, AParam.ParamType.Handle);
      end;
    end;
  end
  else
    Result := TReflection.GetDefaultValue(nil, AParam.ParamType.Handle);
end;

function TModelBinder.BindBody(AType: PTypeInfo; Context: IHttpContext): TValue;
var
  Stream: TStream;
  JsonString: string;
  Settings: TJsonSettings;
  Bytes: TBytes;
  Span: TByteSpan;
begin
  if (AType.Kind <> tkRecord) and (AType.Kind <> tkClass) then
    raise EBindingException.Create('BindBody currently only supports records and classes');

  Stream := Context.Request.Body;
  if (Stream = nil) or (Stream.Size = 0) then
  begin
     // For Classes, might be valid to return nil, but generally body is expected.
     raise EBindingException.Create('Request body is empty');
  end;

  // OPTIMIZATION: Check if we can use Zero-Allocation UTF8 Serializer
  // Currently we just read bytes to avoid String conversion. 
  // In future we can get Span directly from Request if driver supports it.
  
  try
    // Read Body as Bytes (One copy stream -> bytes, but avoids bytes -> string -> TJsonDOM)
    if Stream is TBytesStream then
      Bytes := TBytesStream(Stream).Bytes
    else
    begin
      Stream.Position := 0;
      SetLength(Bytes, Stream.Size);
      if Stream.Size > 0 then
        Stream.ReadBuffer(Bytes[0], Stream.Size);
    end;
    
    if Length(Bytes) = 0 then
         raise EBindingException.Create('Request body is empty');

    Span := TByteSpan.FromBytes(Bytes);

    // Call Generic Deserialize<T> dynamically? 
    // TUtf8JsonSerializer.Deserialize<T> is static generic.
    // We have AType (PTypeInfo).
    // The current signature of BindBody returns TValue.
    // We need to invoke Deserialize via RTTI or use the non-generic version if we expose one.
    // However, TUtf8JsonSerializer currently exposes `Deserialize<T>`.
    // Let's use RTTI to invoke it for now, or just fallback to String for this specific non-generic call 
    // IF we are not called via generic BindBody<T>. 
    // BUT BindBody<T> calls this BindBody(PTypeInfo).
    
    // To truly use the new serializer efficiently without heavy generic invoking:
    // We should refactor BindBody<T> to call the serializer directly.
    // But for now, let's keep the architecture:
    
    // We'll read as string for THIS method (legacy path) unless we refactor BindBody<T>.
    // Wait, the user wants "Zero-Allocation". 
    // Reading stream to Bytes is fine.
    
    // Let's modify BindBody<T> below to use the new serializer, and keep this for compat/dynamic calls.
    // OR we change this method to try to dispatch to Utf8Serializer if possible.
    
    // Fallback to legacy string based for now in the non-generic untyped method
    JsonString := TEncoding.UTF8.GetString(Bytes);
    Settings := TJsonSettings.Default.CaseInsensitive.ServiceProvider(Context.Services);
    
    Result := TDextJson.Deserialize(AType, JsonString, Settings);
  except
    on E: Exception do
      raise EBindingException.Create('Error binding body: ' + E.Message);
  end;
end;

// Optimized Generic Version
function TModelBinder.BindBody<T>(Context: IHttpContext): T;
var
  Stream: TStream;
  Bytes: TBytes;
  Span: TByteSpan;
  Value: TValue;
begin
  // Only for Records for now
  if PTypeInfo(System.TypeInfo(T)).Kind = tkRecord then
  begin
      Stream := Context.Request.Body;
      if (Stream = nil) or (Stream.Size = 0) then
        raise EBindingException.Create('Request body is empty');

      // Read RAW BYTES (Zero String Allocation)
      // Ideally Context.Request would expose a Span/Bytes directly.
      if Stream is TBytesStream then
      begin
         Bytes := TBytesStream(Stream).Bytes;
         // Note: TBytesStream.Bytes returns the internal array usually - Zero copy? 
         // System.Classes TBytesStream properties expose raw TBytes. Good.
      end
      else
      begin
        Stream.Position := 0;
        SetLength(Bytes, Stream.Size);
        if Stream.Size > 0 then
          Stream.ReadBuffer(Bytes[0], Stream.Size);
      end;
      
      try
        Span := TByteSpan.FromBytes(Bytes);
        // FAST PATH: UTF8 Zero-Allocation Deserialization
        Result := TUtf8JsonSerializer.Deserialize<T>(Span);
        Exit;
      except
        // Fallback or re-raise
        on E: EUtf8SerializationException do
           raise EBindingException.Create('Error parsing JSON body: ' + E.Message);
      end;
  end;

  // Fallback for Classes/Other types (Legacy)
  Value := BindBody(TypeInfo(T), Context);
  Result := Value.AsType<T>;
end;

function TModelBinder.BindQuery(AType: PTypeInfo; Context: IHttpContext): TValue;
var
  RttiType: TRttiType;
  QueryParams: IStringDictionary;
  FieldName: string;
  FieldValue: string;
  Field: TRttiField;
  Prop: TRttiProperty;
  Attr: TCustomAttribute;
  M: TRttiMethod;
  MetaClass: TClass;
  FoundCreate: Boolean;
  SourceProvider: TBindingSourceProvider;
begin
  if (AType.Kind <> tkRecord) and (AType.Kind <> tkClass) then
    raise EBindingException.Create('BindQuery currently only supports records and classes');

  RttiType := TReflection.Context.GetType(AType);
  QueryParams := Context.Request.Query;

  // 1. Initialize Result
  if AType.Kind = tkClass then
  begin
    MetaClass := (RttiType as TRttiInstanceType).MetaclassType;
    FoundCreate := False;
    
    // Robustly searching for parameterless constructor
    for M in RttiType.GetMethods do
    begin
      if (SameText(M.Name, 'Create')) and (M.MethodKind = mkConstructor) and (Length(M.GetParameters) = 0) then
      begin
        Result := M.Invoke(MetaClass, []);
        FoundCreate := True;
        Break;
      end;
    end;
    
    if not FoundCreate then
      raise EBindingException.CreateFmt('Cannot find parameterless constructor "Create" for %s in BindQuery.', [AType.Name]);
  end
  else
  begin
    TValue.Make(nil, AType, Result);
  end;

  // 2. Bind Fields (Records)
  if AType.Kind = tkRecord then
  begin
    SourceProvider := TBindingSourceProvider.Create;
    try
      for Field in RttiType.GetFields do
      begin
        FieldName := SourceProvider.GetBindingName(Field);

        if QueryParams.TryGetValue(FieldName, FieldValue) then
          Field.SetValue(Result.GetReferenceToRawData, TReflection.CastFromString(FieldValue, Field.FieldType.Handle))
        else
          Field.SetValue(Result.GetReferenceToRawData, TReflection.GetDefaultValue(Field, Field.FieldType.Handle));
      end;
    finally
      SourceProvider.Free;
    end;
  end
  // 3. Bind Properties (Classes)
  else if AType.Kind = tkClass then
  begin
    for Prop in RttiType.GetProperties do
    begin
      if not Prop.IsWritable then Continue;
      
      FieldName := Prop.Name;
      for Attr in Prop.GetAttributes do
      begin
        if Attr is FromQueryAttribute then
        begin
          if FromQueryAttribute(Attr).Name <> '' then FieldName := FromQueryAttribute(Attr).Name;
        end;
      end;

      if QueryParams.TryGetValue(FieldName, FieldValue) then
        Prop.SetValue(Result.AsObject, TReflection.CastFromString(FieldValue, Prop.PropertyType.Handle))
      else
        Prop.SetValue(Result.AsObject, TReflection.GetDefaultValue(Prop, Prop.PropertyType.Handle));
    end;
  end;
end;

function TModelBinder.BindQuery<T>(Context: IHttpContext): T;
var
  Value: TValue;
begin
  Value := BindQuery(TypeInfo(T), Context);
  Result := Value.AsType<T>;
end;

function TModelBinder.BindRoute(AType: PTypeInfo; Context: IHttpContext): TValue;
var
  RttiType: TRttiType;
  RouteParams: TRouteValueDictionary;
  Field: TRttiField;
  FieldName: string;
  FieldValue: string;
  SingleParamValue: string;
  SourceProvider: TBindingSourceProvider;
begin
  // ✅ SUPPORT FOR PRIMITIVES (Single Route Param Inference)
  if (AType.Kind in [tkInteger, tkInt64, tkFloat, tkString, tkLString, tkWString, tkUString, tkEnumeration]) or
     ((AType.Kind = tkRecord) and ((AType = TypeInfo(TGUID)) or (AType = TypeInfo(TUUID)))) then
  begin
    RouteParams := Context.Request.RouteParams;
    
    if RouteParams.Count = 1 then
    begin
      SingleParamValue := RouteParams.GetValueByIndex(0);
      
      try
        Result := TReflection.CastFromString(SingleParamValue, AType);
        Exit;
      except
        on E: Exception do
          raise EBindingException.CreateFmt('Error converting route param "%s" to %s: %s', [SingleParamValue, AType.Name, E.Message]);
      end;
    end
    else if RouteParams.Count > 1 then
      raise EBindingException.CreateFmt('Ambiguous binding for type %s. Found %d route parameters. Use a Record.', [AType.Name, RouteParams.Count]);
  end;

  if AType.Kind <> tkRecord then
    raise EBindingException.Create('BindRoute currently only supports records or single primitive inference');

  TValue.Make(nil, AType, Result);

  RttiType := TReflection.Context.GetType(AType);
  RouteParams := Context.Request.RouteParams;

  SourceProvider := TBindingSourceProvider.Create;
  try
    for Field in RttiType.GetFields do
    begin
      // Obter nome do campo (com suporte a atributos [FromRoute])
      FieldName := SourceProvider.GetBindingName(Field);

      // Buscar valor do route parameter
      if RouteParams.TryGetValue(FieldName, FieldValue) then
        Field.SetValue(Result.GetReferenceToRawData, TReflection.CastFromString(FieldValue, Field.FieldType.Handle))
      else
        Field.SetValue(Result.GetReferenceToRawData, TReflection.GetDefaultValue(Field, Field.FieldType.Handle));
    end; // for each field
  finally
    SourceProvider.Free;
  end;
end;

function TModelBinder.BindRoute<T>(Context: IHttpContext): T;
var
  Value: TValue;
begin
  Value := BindRoute(TypeInfo(T), Context);
  Result := Value.AsType<T>;
end;

function TModelBinder.BindHeader(AType: PTypeInfo; Context: IHttpContext): TValue;
var
  RttiType: TRttiType;
  Headers: IStringDictionary;
  Field: TRttiField;
  FieldName: string;
  FieldValue: string;
  Val: TValue;
  SourceProvider: TBindingSourceProvider;
begin
  if AType.Kind <> tkRecord then
    raise EBindingException.Create('BindHeader currently only supports records');

  TValue.Make(nil, AType, Result);

  RttiType := TReflection.Context.GetType(AType);
  Headers := Context.Request.Headers;

  SourceProvider := TBindingSourceProvider.Create;
  try
    for Field in RttiType.GetFields do
    begin
      // Obter nome do campo (com suporte a atributos [FromHeader])
      FieldName := SourceProvider.GetBindingName(Field);

      // Get header value (case-insensitive via GetHeader)
      FieldValue := Context.Request.GetHeader(FieldName);
      if FieldValue <> '' then
      begin
        // USE ROBUST CONVERSION
        try
          Val := TReflection.CastFromString(FieldValue, Field.FieldType.Handle);
          Field.SetValue(Result.GetReferenceToRawData, Val);
        except
          on E: Exception do
          begin
            SafeWriteln(Format('⚠️ BindHeader warning: Error converting field "%s" value "%s": %s',
              [FieldName, FieldValue, E.Message]));
          end;
        end; // try
      end; // if header exists
    end; // for each field
  finally
    SourceProvider.Free;
  end;
end;

function TModelBinder.BindMethodParameters(AMethod: TRttiMethod;
  AContext: IHttpContext): TArray<TValue>;
var
  I: Integer;
  Params: TArray<TRttiParameter>;
begin
  Params := AMethod.GetParameters;
  SetLength(Result, Length(Params));

  for I := 0 to High(Params) do
    Result[I] := BindParameter(Params[I], AContext);
end;

function TModelBinder.BindParameter(AParam: TRttiParameter;
  AContext: IHttpContext): TValue;
var
  Attr: TCustomAttribute;
  A: TCustomAttribute;
  ParamName: string;
  QueryParams: IStringDictionary;
  QueryValue: string;
  RouteParams: TRouteValueDictionary;
  RouteValue: string;
  HeaderValue: string;
  FoundDefault: Boolean;
  IsService: Boolean;
begin
  // 1. IHttpContext
  if AParam.ParamType.Handle = TypeInfo(IHttpContext) then
  begin
    Result := TValue.From<IHttpContext>(AContext);
    Exit;
  end;

  // 2. Explicit Attributes
  for Attr in AParam.GetAttributes do
  begin
    if Attr is FromQueryAttribute then
    begin
      ParamName := FromQueryAttribute(Attr).Name;
      if ParamName = '' then ParamName := AParam.Name;

      QueryParams := AContext.Request.Query;
      if QueryParams.TryGetValue(ParamName, QueryValue) then
        Result := TReflection.CastFromString(QueryValue, AParam.ParamType.Handle)
      else
      begin
        // 1. Try DefaultValueAttribute
        FoundDefault := False;
        for A in AParam.GetAttributes do
          if A is DefaultValueAttribute then
          begin
             Result := TValue.FromVariant(DefaultValueAttribute(A).Value);
             FoundDefault := True;
             Break;
          end;
        
        // 2. Fallback to standard conversion
        if not FoundDefault then
          Result := TReflection.CastFromString('', AParam.ParamType.Handle);
      end;
      Exit;
    end
    else if Attr is FromRouteAttribute then
    begin
      ParamName := FromRouteAttribute(Attr).Name;
      if ParamName = '' then ParamName := AParam.Name;

      RouteParams := AContext.Request.RouteParams;
      if RouteParams.TryGetValue(ParamName, RouteValue) then
        Result := TReflection.CastFromString(RouteValue, AParam.ParamType.Handle)
      else
        raise EBindingException.CreateFmt('Route parameter not found: %s', [ParamName]);
      Exit;
    end
    else if Attr is FromBodyAttribute then
    begin
      if (AParam.ParamType.Handle.Kind <> tkRecord) and (AParam.ParamType.Handle.Kind <> tkClass) then
        Result := BindBodyPrimitive(AParam, AContext)
      else
        Result := BindBody(AParam.ParamType.Handle, AContext);
      Exit;
    end
    else if Attr is FromServicesAttribute then
    begin
      Result := BindServices(AParam.ParamType.Handle, AContext);
      Exit;
    end
    else if Attr is FromHeaderAttribute then
    begin
      ParamName := FromHeaderAttribute(Attr).Name;
      if ParamName = '' then ParamName := AParam.Name;

      HeaderValue := AContext.Request.GetHeader(ParamName);
      if HeaderValue <> '' then
        Result := TReflection.CastFromString(HeaderValue, AParam.ParamType.Handle)
      else
      begin
        FoundDefault := False;
        for A in AParam.GetAttributes do
          if A is DefaultValueAttribute then
          begin
             Result := TValue.FromVariant(DefaultValueAttribute(A).Value);
             FoundDefault := True;
             Break;
          end;
        if not FoundDefault then
          Result := TReflection.CastFromString('', AParam.ParamType.Handle);
      end;
      Exit;
    end;
  end;

  // 3. Inference
  if (AParam.ParamType.TypeKind = tkRecord) then
  begin
    // Use hybrid binding for records - supports Header, Query, Route, Body
    Result := BindRecordHybrid(AParam.ParamType.Handle, AContext);
  end
  else if (AParam.ParamType.TypeKind = tkClass) then
  begin
     // 1. Try Service Injection First
     IsService := False;
     try
       Result := BindServices(AParam.ParamType.Handle, AContext);
       if not Result.IsEmpty and not Result.AsObject.Equals(nil) then
         IsService := True;
     except
       // Service resolution failed, continue to Model Binding
     end;

     if IsService then Exit;

     // 2. Model Binding (Body vs Query)
     if (AContext.Request.Method = 'POST') or (AContext.Request.Method = 'PUT') or (AContext.Request.Method = 'PATCH') then
         Result := BindBody(AParam.ParamType.Handle, AContext)
     else
         Result := BindQuery(AParam.ParamType.Handle, AContext);
  end
  else if (AParam.ParamType.TypeKind = tkInterface) then
  begin
    Result := BindServices(AParam.ParamType.Handle, AContext);
  end
  else
  begin
    // Primitives: Route -> Query
    ParamName := AParam.Name;
    RouteParams := AContext.Request.RouteParams;
    
    if RouteParams.TryGetValue(ParamName, RouteValue) then
    begin
      Result := TReflection.CastFromString(RouteValue, AParam.ParamType.Handle);
    end
    else
    begin
      QueryParams := AContext.Request.Query;
      if QueryParams.TryGetValue(ParamName, QueryValue) then
        Result := TReflection.CastFromString(QueryValue, AParam.ParamType.Handle)
      else
      begin
        FoundDefault := False;
        for A in AParam.GetAttributes do
          if A is DefaultValueAttribute then
          begin
             Result := TValue.FromVariant(DefaultValueAttribute(A).Value);
             FoundDefault := True;
             Break;
          end;
        if not FoundDefault then
          Result := TReflection.CastFromString('', AParam.ParamType.Handle);
      end;
    end;
  end;
end;

function TModelBinder.BindServices(AType: PTypeInfo; Context: IHttpContext): TValue;
var
  RttiType: TRttiType;
  Services: IServiceProvider;
  Field: TRttiField;
  ServiceInstance: TValue;
  ServiceType: TServiceType;
  Attr: TCustomAttribute;
  HasServicesAttr: Boolean;
  InterfaceInstance: IInterface;
  ClassType: TClass;
  ClassInstance: TObject;
  InterfaceType: TRttiInterfaceType;
begin
  if (AType.Kind <> tkRecord) and (AType.Kind <> tkInterface) and (AType.Kind <> tkClass) then
    raise EBindingException.Create('BindServices currently only supports records, classes or interfaces');

  RttiType := TReflection.Context.GetType(AType);
  Services := Context.GetServices;
  
  // Class Support (Root Level)
  if AType.Kind = tkClass then
  begin
     ClassType := (RttiType as TRttiInstanceType).MetaclassType;
     ServiceType := TServiceType.FromClass(ClassType);
     ClassInstance := Services.GetService(ServiceType);
     
     if Assigned(ClassInstance) then
     begin
       Result := TValue.From(ClassInstance);
       Exit;
     end
     else
        raise EBindingException.CreateFmt('Service not found for class type: %s. Ensure it is registered in DI.', [String(AType.Name)]);
  end;

  // NEW: Direct support for interfaces
  if AType.Kind = tkInterface then
  begin
    InterfaceType := RttiType as TRttiInterfaceType;
    ServiceType := TServiceType.FromInterface(InterfaceType.GUID);
    InterfaceInstance := Services.GetServiceAsInterface(ServiceType);
    
    if Assigned(InterfaceInstance) then
    begin
      TValue.Make(@InterfaceInstance, AType, Result);
      Exit;
    end
    else
      raise EBindingException.CreateFmt('Service not found for interface: %s', [InterfaceType.Name]);
  end;

    TValue.Make(nil, AType, Result);
    // Services already initialized above

    for Field in RttiType.GetFields do
    begin
      // Check if field has [FromServices] attribute
      HasServicesAttr := False;
      for Attr in Field.GetAttributes do
      begin
        if Attr is FromServicesAttribute then
        begin
          HasServicesAttr := True;
          Break;
        end;
      end;

      if HasServicesAttr then
      begin
        try
          case Field.FieldType.TypeKind of
            tkInterface:
              begin
                // For interfaces, use GUID
                InterfaceType := Field.FieldType as TRttiInterfaceType;
                ServiceType := TServiceType.FromInterface(InterfaceType.GUID);

                // Get service from DI container as interface
                InterfaceInstance := Services.GetServiceAsInterface(ServiceType);
                if Assigned(InterfaceInstance) then
                begin
                  // FIX: Create TValue of specific interface type
                  TValue.Make(@InterfaceInstance, Field.FieldType.Handle, ServiceInstance);
                  Field.SetValue(Result.GetReferenceToRawData, ServiceInstance);
                end
                else
                begin
                  // Service not found - could it be optional or required?
                  // For now, leave field as nil
                end;
              end;

            tkClass:
              begin
                // FIX: Use RTTI to get class correctly
                ClassType := (Field.FieldType as TRttiInstanceType).MetaclassType;
                ServiceType := TServiceType.FromClass(ClassType);

                ClassInstance := Services.GetService(ServiceType);
                if Assigned(ClassInstance) then
                begin
                  ServiceInstance := TValue.From(ClassInstance);
                  Field.SetValue(Result.GetReferenceToRawData, ServiceInstance);
                end;
              end;
          else
            raise EBindingException.CreateFmt(
              'FromServices attribute not supported for field type: %s',
              [Field.FieldType.Name]);
          end;
        except
          on E: Exception do
            raise EBindingException.CreateFmt(
              'Error binding service for field %s: %s',
              [Field.Name, E.Message]);
        end;
      end;
    end;
end;

function TModelBinder.BindRecordHybrid(AType: PTypeInfo; Context: IHttpContext): TValue;
var
  ContextRtti: TRttiContext;
  RttiType: TRttiType;
  Field: TRttiField;
  SourceProvider: TBindingSourceProvider;
  BindingSource: TBindingSource;
  FieldName: string;
  FieldValue: TValue;
  BodyBytes: TBytes;
  Stream: TStream;
  Headers: IStringDictionary;
  RouteParams: TRouteValueDictionary;
  QueryParams: IStringDictionary;
  RouteVal, QueryVal: string;
  BodyJsonObj: IDextJsonObject;
  LMethod, LContentType: string;
  LIsPostLike, LIsJson: Boolean;
  BodyJsonStr: string;
  JsonNode: IDextJsonNode;
  FoundInBody, FieldFound: Boolean;
  JsonFieldName: string;
  HeaderVal: string;
  IntVal: Integer;
  Int64Val: Int64;
  CurrVal: Currency;
  DateStr: string;
  FloatVal: Double;
  BoolVal: Boolean;
  EnumStr: string;
  StrVal: string;
begin
  if AType.Kind <> tkRecord then
    raise EBindingException.Create('BindRecordHybrid only supports records');

  TValue.Make(nil, AType, Result);
  BodyJsonObj := nil;

  ContextRtti := TReflection.Context;
  try
    RttiType := ContextRtti.GetType(AType);
  SourceProvider := TBindingSourceProvider.Create;
  try
    // Get request data sources
    Headers := Context.Request.Headers;
    RouteParams := Context.Request.RouteParams;
    QueryParams := Context.Request.Query;

      // Pre-load body JSON once if it's a POST/PUT/PATCH and likely contains JSON
      LMethod := Context.Request.Method;
      LIsPostLike := (LMethod = 'POST') or (LMethod = 'PUT') or (LMethod = 'PATCH');
      LContentType := Context.Request.GetHeader('Content-Type').ToLower;
      LIsJson := LContentType.Contains('application/json');

      Stream := Context.Request.Body;
      if (Stream <> nil) and (Stream.Size > 0) and (LIsPostLike or LIsJson) then
      begin
        if Stream is TBytesStream then
          BodyBytes := TBytesStream(Stream).Bytes
        else
        begin
          Stream.Position := 0;
          SetLength(BodyBytes, Stream.Size);
          if Stream.Size > 0 then
            Stream.ReadBuffer(BodyBytes[0], Stream.Size);
        end;
        
        BodyJsonStr := TEncoding.UTF8.GetString(BodyBytes);

        if BodyJsonStr <> '' then
        begin
          try
            JsonNode := TDextJson.Provider.Parse(BodyJsonStr);
            if (JsonNode <> nil) and (JsonNode.GetNodeType = jntObject) then
              BodyJsonObj := JsonNode as IDextJsonObject;
          except
            on E: Exception do
              BodyJsonObj := nil;
          end;
        end;
      end;

      for Field in RttiType.GetFields do
      begin
        try
          // 1. Determine binding source from field attributes
          BindingSource := SourceProvider.GetBindingSource(Field);
          FieldName := SourceProvider.GetBindingName(Field);

          // 2. Bind based on source
          case BindingSource of
            bsHeader:
              begin
                // Headers are case-insensitive (GetHeader already handles this)
                HeaderVal := Context.Request.GetHeader(FieldName);
                if HeaderVal <> '' then
                  FieldValue := TReflection.CastFromString(HeaderVal, Field.FieldType.Handle)
                else
                  FieldValue := TReflection.GetDefaultValue(Field, Field.FieldType.Handle);
              end;

            bsQuery:
              begin
                if QueryParams.TryGetValue(FieldName, QueryVal) then
                   FieldValue := TReflection.CastFromString(QueryVal, Field.FieldType.Handle)
                else
                   FieldValue := TReflection.GetDefaultValue(Field, Field.FieldType.Handle);
              end;

            bsRoute:
              begin
                if RouteParams.TryGetValue(FieldName, RouteVal) then
                  FieldValue := TReflection.CastFromString(RouteVal, Field.FieldType.Handle)
                else
                  FieldValue := TReflection.GetDefaultValue(Field, Field.FieldType.Handle);
              end;

            bsServices:
              begin
                // For services, delegate to BindServices for the specific field
                FieldValue := BindServices(Field.FieldType.Handle, Context);
              end;

            bsBody:
              begin
                FoundInBody := False;
                
                // First, try to find in JSON body
                if (BodyJsonObj <> nil) then
                begin
                  // Try to find the field (case-insensitive)
                  JsonFieldName := FieldName;
                  FieldFound := BodyJsonObj.Contains(JsonFieldName);
                  
                  // Try lowercase if not found
                  if not FieldFound then
                  begin
                    JsonFieldName := LowerCase(FieldName);
                    FieldFound := BodyJsonObj.Contains(JsonFieldName);
                  end;
                  
                  // Try camelCase if not found
                  if not FieldFound then
                  begin
                    if Length(FieldName) > 0 then
                    begin
                      JsonFieldName := LowerCase(FieldName[1]) + Copy(FieldName, 2, MaxInt);
                      FieldFound := BodyJsonObj.Contains(JsonFieldName);
                    end;
                  end;
                  
                  if FieldFound then
                  begin
                    FoundInBody := True;
                    // For complex types, we need to check the field type
                    case Field.FieldType.TypeKind of
                      tkInteger:
                        begin
                          IntVal := BodyJsonObj.GetInteger(JsonFieldName);
                          FieldValue := TValue.From<Integer>(IntVal);
                        end;
                      tkInt64:
                        begin
                          Int64Val := BodyJsonObj.GetInt64(JsonFieldName);
                          FieldValue := TValue.From<Int64>(Int64Val);
                        end;
                      tkFloat:
                        begin
                          if (Field.FieldType.Handle = TypeInfo(Currency)) then
                          begin
                            CurrVal := Currency(BodyJsonObj.GetDouble(JsonFieldName));
                            FieldValue := TValue.From<Currency>(CurrVal);
                          end
                          else if (Field.FieldType.Handle = TypeInfo(TDateTime)) or 
                                  (Field.FieldType.Handle = TypeInfo(TDate)) or 
                                  (Field.FieldType.Handle = TypeInfo(TTime)) then
                          begin                            
                            DateStr := BodyJsonObj.GetString(JsonFieldName);
                            FieldValue := TReflection.CastFromString(DateStr, Field.FieldType.Handle);
                          end
                          else
                          begin
                            FloatVal := BodyJsonObj.GetDouble(JsonFieldName);
                            FieldValue := TValue.From<Double>(FloatVal);
                          end;
                        end;
                      tkEnumeration:
                        begin
                          if Field.FieldType.Handle = TypeInfo(Boolean) then
                          begin
                            BoolVal := BodyJsonObj.GetBoolean(JsonFieldName);
                            FieldValue := TValue.From<Boolean>(BoolVal);
                          end
                          else
                          begin
                            EnumStr := BodyJsonObj.GetString(JsonFieldName);
                            FieldValue := TReflection.CastFromString(EnumStr, Field.FieldType.Handle);
                          end;
                        end;
                    else
                      // String and other types
                      StrVal := BodyJsonObj.GetString(JsonFieldName);
                      FieldValue := TReflection.CastFromString(StrVal, Field.FieldType.Handle);
                    end;
                  end;
                end;
                
                // Fallback 1: Try RouteParams (for IDs in URL like /api/products/{id})
                if not FoundInBody then
                begin
                  if RouteParams.TryGetValue(FieldName, RouteVal) then
                  begin
                    FieldValue := TReflection.CastFromString(RouteVal, Field.FieldType.Handle);
                    FoundInBody := True; // Mark as found
                  end;
                end;
                
                // Fallback 2: Try Query params (for ?param=value)
                if not FoundInBody then
                begin
                  if QueryParams.TryGetValue(FieldName, QueryVal) then
                  begin
                    FieldValue := TReflection.CastFromString(QueryVal, Field.FieldType.Handle);
                  end
                  else
                    FieldValue := TReflection.GetDefaultValue(Field, Field.FieldType.Handle);
                end;
              end;

            bsForm:
              begin
                // Form data not implemented yet
                FieldValue := TReflection.CastFromString('', Field.FieldType.Handle);
              end;
          end;

          // 3. Set field value
          if not FieldValue.IsEmpty then
            Field.SetValue(Result.GetReferenceToRawData, FieldValue);

        except
          on E: Exception do
          begin
            // Silently continue with other fields on binding error
            // Uncomment for debugging: SafeWriteln(Format('Warning: Error binding field "%s": %s', [Field.Name, E.Message]));
          end;
        end;
      end;
    finally
      SourceProvider.Free;
    end;
  finally
  ;
  end;
end;

function TModelBinder.BindValue(const AValue: string; AType: PTypeInfo): TValue;
begin
  Result := TReflection.CastFromString(AValue, AType);
end;

{ TModelBinderHelper }

class function TModelBinderHelper.BindQuery<T>(ABinder: IModelBinder; Context: IHttpContext): T;
var
  Value: TValue;
begin
  Value := ABinder.BindQuery(TypeInfo(T), Context);
  Result := Value.AsType<T>;
end;

class function TModelBinderHelper.BindBody<T>(ABinder: IModelBinder; Context: IHttpContext): T;
var
  Value: TValue;
begin
  Value := ABinder.BindBody(TypeInfo(T), Context);
  Result := Value.AsType<T>;
end;

class function TModelBinderHelper.BindRoute<T>(ABinder: IModelBinder; Context: IHttpContext): T;
var
  Value: TValue;
  P: Pointer;
begin
  Value := ABinder.BindRoute(TypeInfo(T), Context);
  
  // For records like TUUID/TGUID, AsType<T> fails with "Insufficient RTTI"
  // Always use direct memory copy for records
  if PTypeInfo(TypeInfo(T)).Kind = tkRecord then
  begin
    P := Value.GetReferenceToRawData;
    if P <> nil then
      Move(P^, Result, SizeOf(T))
    else
      Result := Default(T);
  end
  else
    Result := Value.AsType<T>;
end;

{ TBindingSourceProvider }

function TBindingSourceProvider.GetBindingSource(Field: TRttiField): TBindingSource;
var
  Attr: TCustomAttribute;
begin
  for Attr in Field.GetAttributes do
  begin
    if Attr is BindingAttribute then
      Exit(BindingAttribute(Attr).Source);
  end;

  // Default: FromBody for all field types without explicit binding attribute
  // This is the expected behavior for records used in POST/PUT requests
  // Fields that need to come from Query/Route/Header should use explicit attributes
  Result := bsBody;
end;

function TBindingSourceProvider.GetBindingName(Field: TRttiField): string;
var
  Attr: TCustomAttribute;
begin
  for Attr in Field.GetAttributes do
  begin
    if (Attr is FromQueryAttribute) and (FromQueryAttribute(Attr).Name <> '') then
      Exit(FromQueryAttribute(Attr).Name)
    else if (Attr is FromRouteAttribute) and (FromRouteAttribute(Attr).Name <> '') then
      Exit(FromRouteAttribute(Attr).Name)
    else if (Attr is FromHeaderAttribute) and (FromHeaderAttribute(Attr).Name <> '') then
      Exit(FromHeaderAttribute(Attr).Name);
  end;

  Result := Field.Name;
end;

function TBindingSourceProvider.GetBindingSource(Param: TRttiParameter): TBindingSource;
var
  Attr: TCustomAttribute;
begin
  for Attr in Param.GetAttributes do
  begin
    if Attr is BindingAttribute then
      Exit(BindingAttribute(Attr).Source);
  end;

  // Default: FromBody for complex types, FromQuery for simple types
  if Param.ParamType.TypeKind in [tkRecord, tkClass] then
    Result := bsBody
  else
    Result := bsQuery;
end;

function TBindingSourceProvider.GetBindingName(Param: TRttiParameter): string;
var
  Attr: TCustomAttribute;
begin
  for Attr in Param.GetAttributes do
  begin
    if (Attr is FromQueryAttribute) and (FromQueryAttribute(Attr).Name <> '') then
      Exit(FromQueryAttribute(Attr).Name)
    else if (Attr is FromRouteAttribute) and (FromRouteAttribute(Attr).Name <> '') then
      Exit(FromRouteAttribute(Attr).Name)
    else if (Attr is FromHeaderAttribute) and (FromHeaderAttribute(Attr).Name <> '') then
      Exit(FromHeaderAttribute(Attr).Name);
  end;

  Result := Param.Name;
end;

end.
