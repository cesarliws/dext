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
unit Dext.Core.ModelBinding;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Generics.Collections,
  System.Rtti,
  System.TypInfo,
  Dext.DI.Interfaces,
  Dext.Http.Interfaces,
  Dext.Json,
  Dext.Json.Types;

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
    property Source: TBindingSource read FSource;
  end;

  /// <summary>
  ///   Specifies that a parameter or property should be bound using the request body.
  /// </summary>
  FromBodyAttribute = class(BindingAttribute)
  public
    constructor Create; overload;
  end;

  /// <summary>
  ///   Specifies that a parameter or property should be bound using the request query string.
  /// </summary>
  FromQueryAttribute = class(BindingAttribute)
  private
    FName: string;
  public
    constructor Create; overload;
    constructor Create(const AName: string); overload;
    property Name: string read FName;
  end;

  /// <summary>
  ///   Specifies that a parameter or property should be bound using route data.
  /// </summary>
  FromRouteAttribute = class(BindingAttribute)
  private
    FName: string;
  public
    constructor Create; overload;
    constructor Create(const AName: string); overload;
    property Name: string read FName;
  end;

  /// <summary>
  ///   Specifies that a parameter or property should be bound using the request headers.
  /// </summary>
  FromHeaderAttribute = class(BindingAttribute)
  private
    FName: string;
  public
    constructor Create; overload;
    constructor Create(const AName: string); overload;
    property Name: string read FName;
  end;

  /// <summary>
  ///   Specifies that a parameter should be bound using the dependency injection container.
  /// </summary>
  FromServicesAttribute = class(BindingAttribute)
  public
    constructor Create; overload;
  end;

  /// <summary>
  ///   Defines the contract for model binding.
  /// </summary>
  IModelBinder = interface
    ['{6CDDAA4C-EB6B-42F0-A138-614FFBA931A5}']
    /// <summary>
    ///   Binds a model from the request body.
    /// </summary>
    function BindBody(AType: PTypeInfo; Context: IHttpContext): TValue;
    
    /// <summary>
    ///   Binds a model from the query string.
    /// </summary>
    function BindQuery(AType: PTypeInfo; Context: IHttpContext): TValue;
    
    /// <summary>
    ///   Binds a model from route data.
    /// </summary>
    function BindRoute(AType: PTypeInfo; Context: IHttpContext): TValue;
    
    /// <summary>
    ///   Binds a model from request headers.
    /// </summary>
    function BindHeader(AType: PTypeInfo; Context: IHttpContext): TValue;
    
    /// <summary>
    ///   Binds a model from the service provider.
    /// </summary>
    function BindServices(AType: PTypeInfo; Context: IHttpContext): TValue;

    /// <summary>
    ///   Binds all parameters of a method.
    /// </summary>
    function BindMethodParameters(AMethod: TRttiMethod; AContext: IHttpContext): TArray<TValue>;
    
    /// <summary>
    ///   Binds a single parameter.
    /// </summary>
    function BindParameter(AParam: TRttiParameter; AContext: IHttpContext): TValue;
  end;

  TModelBinder = class(TInterfacedObject, IModelBinder)
  private
    function ReadStreamToString(Stream: TStream): string;
    function ConvertStringToType(const AValue: string; AType: PTypeInfo): TValue;
  public
    constructor Create;
    destructor Destroy; override;

    // Interface methods
    function BindBody(AType: PTypeInfo; Context: IHttpContext): TValue; overload;
    function BindQuery(AType: PTypeInfo; Context: IHttpContext): TValue; overload;
    function BindRoute(AType: PTypeInfo; Context: IHttpContext): TValue; overload;
    function BindHeader(AType: PTypeInfo; Context: IHttpContext): TValue;
    function BindServices(AType: PTypeInfo; Context: IHttpContext): TValue;

    // Helper methods com genéricos
    function BindBody<T>(Context: IHttpContext): T; overload;
    function BindQuery<T>(Context: IHttpContext): T; overload;
    function BindRoute<T>(Context: IHttpContext): T; overload;

    function BindMethodParameters(AMethod: TRttiMethod; AContext: IHttpContext): TArray<TValue>;
    function BindParameter(AParam: TRttiParameter; AContext: IHttpContext): TValue;
  end;

  TModelBinderHelper = class
  public
    class function BindQuery<T>(ABinder: IModelBinder; Context: IHttpContext): T; static;
    class function BindBody<T>(ABinder: IModelBinder; Context: IHttpContext): T; static;
    class function BindRoute<T>(ABinder: IModelBinder; Context: IHttpContext): T; static;
  end;

  // ✅ BINDING PROVIDER
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
  System.NetEncoding;

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

function TModelBinder.BindBody(AType: PTypeInfo; Context: IHttpContext): TValue;
var
  Stream: TStream;
  JsonString: string;
  Settings: TDextSettings;
begin
  if AType.Kind <> tkRecord then
    raise EBindingException.Create('BindBody currently only supports records');

  Stream := Context.Request.Body;
  if (Stream = nil) or (Stream.Size = 0) then
    raise EBindingException.Create('Request body is empty');

  JsonString := ReadStreamToString(Stream);

  // ✅ Usar settings com CaseInsensitive = True para resolver problema de binding
  // quando JSON vem com campos em lowercase mas record Delphi está em PascalCase
  Settings := TDextSettings.Default.WithCaseInsensitive;

  // Desserializar record usando a abstração do Dext.Json
  try
    Result := TDextJson.Deserialize(AType, JsonString, Settings);
  except
    on E: Exception do
      raise EBindingException.Create('Error binding body: ' + E.Message);
  end;
end;

function TModelBinder.BindBody<T>(Context: IHttpContext): T;
begin
  var Value := BindBody(TypeInfo(T), Context);
  Result := Value.AsType<T>;
end;

function TModelBinder.BindQuery(AType: PTypeInfo; Context: IHttpContext): TValue;
var
  ContextRtti: TRttiContext;
  RttiType: TRttiType;
  Field: TRttiField;
  QueryParams: TStrings;
  FieldName: string;
  FieldValue: string;
begin
  if AType.Kind <> tkRecord then
    raise EBindingException.Create('BindQuery currently only supports records');

  TValue.Make(nil, AType, Result);

  ContextRtti := TRttiContext.Create;
  try
    RttiType := ContextRtti.GetType(AType);
    QueryParams := Context.Request.Query;

    for Field in RttiType.GetFields do
    begin
      // Obter nome do campo (com suporte a atributos)
      var SourceProvider := TBindingSourceProvider.Create;
      try
        FieldName := SourceProvider.GetBindingName(Field);
      finally
        SourceProvider.Free;
      end;

        // Buscar valor do query parameter
        if QueryParams.IndexOfName(FieldName) >= 0 then
        begin
          FieldValue := QueryParams.Values[FieldName];
          // ✅ CORREÇÃO 1: URL Decode
          FieldValue := TNetEncoding.URL.Decode(FieldValue);

          try
            var Val := ConvertStringToType(FieldValue, Field.FieldType.Handle);
            Field.SetValue(Result.GetReferenceToRawData, Val);
          except
            on E: Exception do
              Writeln(Format('⚠️ BindQuery warning: Error converting field "%s" value "%s": %s',
                [FieldName, FieldValue, E.Message]));
          end;
        end; // if parameter exists
      end; // for each field

  finally
    ContextRtti.Free;
  end;
end;

function TryGetCaseInsensitive(const ADict: TDictionary<string, string>; const AKey: string; out AValue: string): Boolean;
begin
  Result := False;
  if ADict = nil then Exit;

  if ADict.TryGetValue(AKey, AValue) then
    Exit(True);

  for var Key in ADict.Keys do
  begin
    if SameText(Key, AKey) then
    begin
      AValue := ADict[Key];
      Exit(True);
    end;
  end;
end;

function TModelBinder.BindQuery<T>(Context: IHttpContext): T;
begin
  var Value := BindQuery(TypeInfo(T), Context);
  Result := Value.AsType<T>;
end;

function TModelBinder.BindRoute(AType: PTypeInfo; Context: IHttpContext): TValue;
var
  ContextRtti: TRttiContext;
  RttiType: TRttiType;
  Field: TRttiField;
  RouteParams: TDictionary<string, string>;
  FieldName: string;
  FieldValue: string;
  SingleParamValue: string;
begin
  // ✅ SUPPORT FOR PRIMITIVES (Single Route Param Inference)
  if (AType.Kind in [tkInteger, tkInt64, tkFloat, tkString, tkLString, tkWString, tkUString, tkEnumeration]) or
     ((AType.Kind = tkRecord) and (AType = TypeInfo(TGUID))) then
  begin
    RouteParams := Context.Request.RouteParams;
    
    if RouteParams.Count = 1 then
    begin
      for var Pair in RouteParams do
      begin
        SingleParamValue := Pair.Value;
        Break; 
      end;
      
      try
        Result := ConvertStringToType(SingleParamValue, AType);
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

  ContextRtti := TRttiContext.Create;
  try
    RttiType := ContextRtti.GetType(AType);
    RouteParams := Context.Request.RouteParams;

    for Field in RttiType.GetFields do
    begin
      // Obter nome do campo (com suporte a atributos [FromRoute])
      var SourceProvider := TBindingSourceProvider.Create;
      try
        FieldName := SourceProvider.GetBindingName(Field);
      finally
        SourceProvider.Free;
      end;

      // Buscar valor do route parameter
      if TryGetCaseInsensitive(RouteParams, FieldName, FieldValue) then
      begin
        // FieldValue já foi preenchido pelo TryGetCaseInsensitive

        // ✅ MESMA CONVERSÃO ROBUSTA DO BINDQUERY
        try
          var Val := ConvertStringToType(FieldValue, Field.FieldType.Handle);
          Field.SetValue(Result.GetReferenceToRawData, Val);
        except
          on E: Exception do
          begin
            Writeln(Format('⚠️ BindRoute warning: Error converting field "%s" value "%s": %s',
              [FieldName, FieldValue, E.Message]));
          end;
        end; // try
      end; // if parameter exists
    end; // for each field

  finally
    ContextRtti.Free;
  end;
end;

//function TModelBinder.BindRoute(AType: PTypeInfo; Context: IHttpContext): TValue;
//var
//  ContextRtti: TRttiContext;
//  RttiType: TRttiType;
//  Field: TRttiField;
//  RouteParams: TDictionary<string, string>;
//  FieldName: string;
//  FieldValue: string;
//begin
//  if AType.Kind <> tkRecord then
//    raise EBindingException.Create('BindRoute currently only supports records');
//
//  TValue.Make(nil, AType, Result);
//
//  ContextRtti := TRttiContext.Create;
//  try
//    RttiType := ContextRtti.GetType(AType);
//    RouteParams := Context.Request.RouteParams;
//
//    // ✅ DEBUG: Antes do loop
//    Writeln('🔍 BindRoute - Processing record type: ', RttiType.Name);
//    Writeln('  RouteParams available: ', RouteParams.Count);
//
//    for Field in RttiType.GetFields do
//    begin
//      // Obter nome do campo (com suporte a atributos [FromRoute])
//      var SourceProvider := TBindingSourceProvider.Create;
//      try
//        FieldName := SourceProvider.GetBindingName(Field);
//      finally
//        SourceProvider.Free;
//      end;
//
//      // ✅ DEBUG: Para cada campo
//      Writeln('🔍 Processing field: ', Field.Name);
//      Writeln('  Looking for RouteParam: ', FieldName);
//      Writeln('  Field type: ', Field.FieldType.Name);
//
//      // Buscar valor do route parameter
//      if RouteParams.ContainsKey(FieldName) then
//      begin
//        FieldValue := RouteParams[FieldName];
//        Writeln('  ✅ Found value: ', FieldValue);
//
//        // ✅ CONVERSÃO (código existente)
//        try
//          case Field.FieldType.TypeKind of
//            tkInteger:
//              begin
//                var IntValue := StrToIntDef(FieldValue, 0);
//                Writeln('  Converting to Integer: ', FieldValue, ' -> ', IntValue);
//                Field.SetValue(Result.GetReferenceToRawData, TValue.From<Integer>(IntValue));
//              end;
//
//            tkInt64:
//              Field.SetValue(Result.GetReferenceToRawData,
//                TValue.From<Int64>(StrToInt64Def(FieldValue, 0)));
//
//            tkFloat:
//              begin
//                if Field.FieldType.Handle = TypeInfo(TDateTime) then
//                  Field.SetValue(Result.GetReferenceToRawData,
//                    TValue.From<TDateTime>(StrToDateTimeDef(FieldValue, 0)))
//                else
//                begin
//                  var FloatValue: Double;
//                  if TryStrToFloat(FieldValue, FloatValue, TFormatSettings.Invariant) then
//                    Field.SetValue(Result.GetReferenceToRawData, TValue.From<Double>(FloatValue))
//                  else
//                    Field.SetValue(Result.GetReferenceToRawData, TValue.From<Double>(0));
//                end;
//              end;
//
//            tkString, tkLString, tkWString, tkUString:
//              Field.SetValue(Result.GetReferenceToRawData,
//                TValue.From<string>(FieldValue));
//
//            tkEnumeration:
//              begin
//                if Field.FieldType.Handle = TypeInfo(Boolean) then
//                begin
//                  var BoolValue := SameText(FieldValue, 'true') or
//                                   SameText(FieldValue, '1') or
//                                   SameText(FieldValue, 'yes') or
//                                   SameText(FieldValue, 'on');
//                  Field.SetValue(Result.GetReferenceToRawData,
//                    TValue.From<Boolean>(BoolValue));
//                end
//                else
//                begin
//                  Field.SetValue(Result.GetReferenceToRawData,
//                    TValue.FromOrdinal(Field.FieldType.Handle,
//                      StrToIntDef(FieldValue, 0)));
//                end;
//              end;
//
//            tkRecord:
//              begin
//                if Field.FieldType.Handle = TypeInfo(TGUID) then
//                begin
//                  var GuidValue: TGUID;
//                  var GuidStr := FieldValue.Trim;
//
//                  try
//                    if GuidStr.StartsWith('{') and GuidStr.EndsWith('}') then
//                      GuidValue := StringToGUID(GuidStr)
//                    else if GuidStr.Length = 36 then
//                      GuidValue := StringToGUID('{' + GuidStr + '}')
//                    else
//                      GuidValue := StringToGUID(GuidStr);
//
//                    Field.SetValue(Result.GetReferenceToRawData,
//                      TValue.From<TGUID>(GuidValue));
//                  except
//                    on E: EConvertError do
//                      Field.SetValue(Result.GetReferenceToRawData,
//                        TValue.From<TGUID>(TGUID.Empty));
//                  end;
//                end;
//              end;
//          end; // case
//        except
//          on E: Exception do
//            Writeln('  ❌ Conversion error: ', E.Message);
//        end;
//      end
//      else
//      begin
//        Writeln('  ❌ RouteParam not found: ', FieldName);
//      end;
//    end;
//
//  finally
//    ContextRtti.Free;
//  end;
//end;

function TModelBinder.BindRoute<T>(Context: IHttpContext): T;
begin
  var Value := BindRoute(TypeInfo(T), Context);
  Result := Value.AsType<T>;
end;

function TModelBinder.BindHeader(AType: PTypeInfo; Context: IHttpContext): TValue;
var
  ContextRtti: TRttiContext;
  RttiType: TRttiType;
  Field: TRttiField;
  Headers: TDictionary<string, string>;
  FieldName: string;
  FieldValue: string;
begin
  if AType.Kind <> tkRecord then
    raise EBindingException.Create('BindHeader currently only supports records');

  TValue.Make(nil, AType, Result);

  ContextRtti := TRttiContext.Create;
  try
    RttiType := ContextRtti.GetType(AType);
    Headers := Context.Request.Headers;

    for Field in RttiType.GetFields do
    begin
      // Obter nome do campo (com suporte a atributos [FromHeader])
      var SourceProvider := TBindingSourceProvider.Create;
      try
        FieldName := SourceProvider.GetBindingName(Field);
      finally
        SourceProvider.Free;
      end;

      // Buscar valor do header (case-insensitive)
      var HeaderKey := FieldName.ToLower; // Headers são case-insensitive
      if Headers.ContainsKey(HeaderKey) then
      begin
        FieldValue := Headers[HeaderKey];

        // ✅ MESMA CONVERSÃO ROBUSTA
        try
          case Field.FieldType.TypeKind of
            tkInteger:
              Field.SetValue(Result.GetReferenceToRawData,
                TValue.From<Integer>(StrToIntDef(FieldValue, 0)));

            tkInt64:
              Field.SetValue(Result.GetReferenceToRawData,
                TValue.From<Int64>(StrToInt64Def(FieldValue, 0)));

            tkFloat:
              begin
                if Field.FieldType.Handle = TypeInfo(TDateTime) then
                  Field.SetValue(Result.GetReferenceToRawData,
                    TValue.From<TDateTime>(StrToDateTimeDef(FieldValue, 0)))
                else
                begin
                  var FloatValue: Double;
                  if TryStrToFloat(FieldValue, FloatValue, TFormatSettings.Invariant) then
                    Field.SetValue(Result.GetReferenceToRawData, TValue.From<Double>(FloatValue))
                  else
                    Field.SetValue(Result.GetReferenceToRawData, TValue.From<Double>(0));
                end;
              end;

            tkString, tkLString, tkWString, tkUString:
              Field.SetValue(Result.GetReferenceToRawData,
                TValue.From<string>(FieldValue));

            tkEnumeration:
              begin
                if Field.FieldType.Handle = TypeInfo(Boolean) then
                begin
                  var BoolValue := SameText(FieldValue, 'true') or
                                   SameText(FieldValue, '1') or
                                   SameText(FieldValue, 'yes') or
                                   SameText(FieldValue, 'on');
                  Field.SetValue(Result.GetReferenceToRawData,
                    TValue.From<Boolean>(BoolValue));
                end
                else
                begin
                  Field.SetValue(Result.GetReferenceToRawData,
                    TValue.FromOrdinal(Field.FieldType.Handle,
                      StrToIntDef(FieldValue, 0)));
                end;
              end;

            tkRecord:
              begin
                if Field.FieldType.Handle = TypeInfo(TGUID) then
                begin
                  var GuidValue: TGUID;
                  var GuidStr := FieldValue.Trim;

                  try
                    if GuidStr.StartsWith('{') and GuidStr.EndsWith('}') then
                      GuidValue := StringToGUID(GuidStr)
                    else if GuidStr.Length = 36 then
                      GuidValue := StringToGUID('{' + GuidStr + '}')
                    else
                      GuidValue := StringToGUID(GuidStr);

                    Field.SetValue(Result.GetReferenceToRawData,
                      TValue.From<TGUID>(GuidValue));
                  except
                    on E: EConvertError do
                      Field.SetValue(Result.GetReferenceToRawData,
                        TValue.From<TGUID>(TGUID.Empty));
                  end;
                end;
              end;
          end; // case

        except
          on E: Exception do
          begin
            Writeln(Format('⚠️ BindHeader warning: Error converting field "%s" value "%s": %s',
              [FieldName, FieldValue, E.Message]));
          end;
        end; // try
      end; // if header exists
    end; // for each field

  finally
    ContextRtti.Free;
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
  ParamName: string;
begin
  WriteLn(Format('    🔍 Binding parameter: %s (Type: %s)',
    [AParam.Name, AParam.ParamType.Name]));

  // 1. IHttpContext
  if AParam.ParamType.Handle = TypeInfo(IHttpContext) then
  begin
    Result := TValue.From<IHttpContext>(AContext);
    Exit;
  end;

  // 2. Explicit Attributes
  for Attr in AParam.GetAttributes do
  begin
    WriteLn(Format('    🔍 Found attribute: %s', [Attr.ClassName]));
    if Attr is FromQueryAttribute then
    begin
      ParamName := FromQueryAttribute(Attr).Name;
      if ParamName = '' then ParamName := AParam.Name;

      WriteLn(Format('    📋 FromQuery: %s', [ParamName]));
      var QueryParams := AContext.Request.Query;
      if QueryParams.IndexOfName(ParamName) >= 0 then
        Result := ConvertStringToType(TNetEncoding.URL.Decode(QueryParams.Values[ParamName]), AParam.ParamType.Handle)
      else
        Result := ConvertStringToType('', AParam.ParamType.Handle); // Default
      Exit;
    end
    else if Attr is FromRouteAttribute then
    begin
      ParamName := FromRouteAttribute(Attr).Name;
      if ParamName = '' then ParamName := AParam.Name;
      WriteLn(Format('    🛣️  FromRoute: %s', [ParamName]));

      var RouteParams := AContext.Request.RouteParams;
      var RouteValue: string;
      if TryGetCaseInsensitive(RouteParams, ParamName, RouteValue) then
        Result := ConvertStringToType(RouteValue, AParam.ParamType.Handle)
      else
        raise EBindingException.CreateFmt('Route parameter not found: %s', [ParamName]);
      Exit;
    end
    else if Attr is FromBodyAttribute then
    begin
      WriteLn('    📦 FromBody');
      Result := BindBody(AParam.ParamType.Handle, AContext);
      Exit;
    end
    else if Attr is FromServicesAttribute then
    begin
      WriteLn(Format('    ⚡ FromServices: %s', [AParam.ParamType.Name]));
      Result := BindServices(AParam.ParamType.Handle, AContext);
      Exit;
    end
    else if Attr is FromHeaderAttribute then
    begin
      ParamName := FromHeaderAttribute(Attr).Name;
      if ParamName = '' then ParamName := AParam.Name;

      WriteLn(Format('    📨 FromHeader: %s', [ParamName]));
      var Headers := AContext.Request.Headers;
      if Headers.ContainsKey(LowerCase(ParamName)) then
        Result := ConvertStringToType(Headers[LowerCase(ParamName)], AParam.ParamType.Handle)
      else
        Result := ConvertStringToType('', AParam.ParamType.Handle); // Default
      Exit;
    end;
  end;

  // 3. Inference
  WriteLn('    🤔 No binding attribute - trying inference');

  if (AParam.ParamType.TypeKind = tkRecord) then
  begin
    // Smart Binding for Records: GET/DELETE -> Query, Others -> Body
    if (AContext.Request.Method = 'GET') or (AContext.Request.Method = 'DELETE') then
    begin
      WriteLn('    📋 Inferring FromQuery (record, GET/DELETE)');
      Result := BindQuery(AParam.ParamType.Handle, AContext);
    end
    else
    begin
      WriteLn('    📦 Inferring FromBody (record, POST/PUT/...)');
      Result := BindBody(AParam.ParamType.Handle, AContext);
    end;
  end
  else if (AParam.ParamType.TypeKind = tkInterface) then
  begin
    WriteLn('    ⚡ Inferring FromServices (interface)');
    Result := BindServices(AParam.ParamType.Handle, AContext);
  end
  else
  begin
    // Primitives: Route -> Query
    ParamName := AParam.Name;
    var RouteParams := AContext.Request.RouteParams;
    var RouteValue: string;
    
    if TryGetCaseInsensitive(RouteParams, ParamName, RouteValue) then
    begin
      WriteLn(Format('    🛣️  Inferred FromRoute: %s', [ParamName]));
      Result := ConvertStringToType(RouteValue, AParam.ParamType.Handle);
    end
    else
    begin
      WriteLn(Format('    📋 Inferred FromQuery: %s', [ParamName]));
      var QueryParams := AContext.Request.Query;
      if QueryParams.IndexOfName(ParamName) >= 0 then
        Result := ConvertStringToType(TNetEncoding.URL.Decode(QueryParams.Values[ParamName]), AParam.ParamType.Handle)
      else
        Result := ConvertStringToType('', AParam.ParamType.Handle); // Default
    end;
  end;
end;

function TModelBinder.BindServices(AType: PTypeInfo; Context: IHttpContext): TValue;
var
  ContextRtti: TRttiContext;
  RttiType: TRttiType;
  Field: TRttiField;
  Services: IServiceProvider;
  ServiceInstance: TValue;
  ServiceType: TServiceType;
begin
  if (AType.Kind <> tkRecord) and (AType.Kind <> tkInterface) then
    raise EBindingException.Create('BindServices currently only supports records or interfaces');

  ContextRtti := TRttiContext.Create;
  try
    Services := Context.GetServices;

    // ✅ NOVO: Suporte direto a interfaces
    if AType.Kind = tkInterface then
    begin
      var InterfaceType := ContextRtti.GetType(AType) as TRttiInterfaceType;
      ServiceType := TServiceType.FromInterface(InterfaceType.GUID);
      var InterfaceInstance := Services.GetServiceAsInterface(ServiceType);
      
      if Assigned(InterfaceInstance) then
      begin
        TValue.Make(@InterfaceInstance, AType, Result);
        Exit;
      end
      else
        raise EBindingException.CreateFmt('Service not found for interface: %s', [InterfaceType.Name]);
    end;

    TValue.Make(nil, AType, Result);
    RttiType := ContextRtti.GetType(AType);
    // Services já inicializado acima

    for Field in RttiType.GetFields do
    begin
      // Verificar se o campo tem atributo [FromServices]
      var HasServicesAttr := False;
      for var Attr in Field.GetAttributes do
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
                // Para interfaces, usar o GUID
                var InterfaceType := Field.FieldType as TRttiInterfaceType;
                ServiceType := TServiceType.FromInterface(InterfaceType.GUID);

                // Obter serviço do container DI como interface
                var InterfaceInstance := Services.GetServiceAsInterface(ServiceType);
                if Assigned(InterfaceInstance) then
                begin
                  // ✅ CORREÇÃO: Criar TValue do tipo específico da interface
                  TValue.Make(@InterfaceInstance, Field.FieldType.Handle, ServiceInstance);
                  Field.SetValue(Result.GetReferenceToRawData, ServiceInstance);
                end
                else
                begin
                  // Serviço não encontrado - pode ser opcional ou requerido?
                  // Por enquanto, deixamos o campo como nil
                end;
              end;

            tkClass:
              begin
                // ✅ CORREÇÃO: Usar o RTTI para obter a classe corretamente
                var ClassType := (Field.FieldType as TRttiInstanceType).MetaclassType;
                ServiceType := TServiceType.FromClass(ClassType);

                var ClassInstance := Services.GetService(ServiceType);
                if Assigned(ClassInstance) then
                begin
                  ServiceInstance := TValue.From<TObject>(ClassInstance);
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
  finally
    ContextRtti.Free;
  end;
end;

function TModelBinder.ReadStreamToString(Stream: TStream): string;
var
  Bytes: TBytes;
begin
  SetLength(Bytes, Stream.Size);
  Stream.Position := 0;
  Stream.Read(Bytes[0], Stream.Size);
  Result := TEncoding.UTF8.GetString(Bytes);
end;

function TModelBinder.ConvertStringToType(const AValue: string; AType: PTypeInfo): TValue;
begin
  try
    case AType.Kind of
      tkInteger: Result := TValue.From<Integer>(StrToIntDef(AValue, 0));
      tkInt64: Result := TValue.From<Int64>(StrToInt64Def(AValue, 0));
      tkFloat:
        begin
          if AType = TypeInfo(TDateTime) then
            Result := TValue.From<TDateTime>(StrToDateTimeDef(AValue, 0))
          else
          begin
            var F: Double;
            if TryStrToFloat(AValue, F, TFormatSettings.Invariant) then
              Result := TValue.From<Double>(F)
            else
              Result := TValue.From<Double>(0);
          end;
        end;
      tkString, tkLString, tkWString, tkUString: Result := TValue.From<string>(AValue);
      tkEnumeration:
        begin
          if AType = TypeInfo(Boolean) then
          begin
            var B := SameText(AValue, 'true') or SameText(AValue, '1') or SameText(AValue, 'on');
            Result := TValue.From<Boolean>(B);
          end
          else
            Result := TValue.FromOrdinal(AType, StrToIntDef(AValue, 0));
        end;
      tkRecord:
        begin
          if AType = TypeInfo(TGUID) then
          begin
            var GuidStr := AValue.Trim;
            if GuidStr = '' then
            begin
              Result := TValue.From<TGUID>(TGUID.Empty);
              Exit;
            end;

            if GuidStr.StartsWith('{') and GuidStr.EndsWith('}') then
              Result := TValue.From<TGUID>(StringToGUID(GuidStr))
            else if GuidStr.Length = 36 then
              Result := TValue.From<TGUID>(StringToGUID('{' + GuidStr + '}'))
            else
              Result := TValue.From<TGUID>(StringToGUID(GuidStr));
          end
          else
            raise EBindingException.Create('Cannot convert string to Record (except GUID)');
        end;
      else
        // Default for unknown types
        TValue.Make(nil, AType, Result);
    end;
  except
    on E: Exception do
      // Return default on error
      TValue.Make(nil, AType, Result);
  end;
end;

{ TModelBinderHelper }

class function TModelBinderHelper.BindQuery<T>(ABinder: IModelBinder; Context: IHttpContext): T;
begin
  var Value := ABinder.BindQuery(TypeInfo(T), Context);
  Result := Value.AsType<T>;
end;

class function TModelBinderHelper.BindBody<T>(ABinder: IModelBinder; Context: IHttpContext): T;
begin
  var Value := ABinder.BindBody(TypeInfo(T), Context);
  Result := Value.AsType<T>;
end;

class function TModelBinderHelper.BindRoute<T>(ABinder: IModelBinder; Context: IHttpContext): T;
begin
  var Value := ABinder.BindRoute(TypeInfo(T), Context);
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

  // Default: FromBody para tipos complexos, FromQuery para simples
  if Field.FieldType.TypeKind in [tkRecord, tkClass] then
    Result := bsBody
  else
    Result := bsQuery;
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

  // Default: FromBody para tipos complexos, FromQuery para simples
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

