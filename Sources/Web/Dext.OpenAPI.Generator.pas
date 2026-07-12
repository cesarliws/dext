unit Dext.OpenAPI.Generator;

interface

uses
  System.SysUtils,
  System.Rtti,
  System.TypInfo,
  Dext,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.OpenAPI.Types,
  Dext.OpenAPI.Attributes,
  Dext.Web.Interfaces,
  Dext.Core.Reflection,
  Dext.Json;

type
  /// <summary>
  ///   Configuration options for OpenAPI document generation.
  /// </summary>
  TOpenAPIOptions = record
    Title: string;
    Description: string;
    Version: string;
    Servers: TArray<TOpenAPIServer>; // Changed from single ServerUrl/Description
    ContactName: string;
    ContactEmail: string;
    LicenseName: string;
    LicenseUrl: string;

    // Swagger UI paths
    SwaggerPath: string;      // Default: '/swagger'
    SwaggerJsonPath: string;  // Default: '/swagger.json'

    // Security configuration
    EnableBearerAuth: Boolean;
    BearerFormat: string;  // e.g., 'JWT'
    BearerDescription: string;

    EnableApiKeyAuth: Boolean;
    ApiKeyName: string;    // e.g., 'X-API-Key'
    ApiKeyLocation: TApiKeyLocation;
    ApiKeyDescription: string;

    // Global responses (e.g., 429, 500) applied to all operations
    GlobalResponses: TArray<TPair<Integer, string>>;

    // Additional Security definitions
    SecuritySchemes: TArray<TPair<string, TOpenAPISecurityScheme>>;

    class function Default: TOpenAPIOptions; static;

    /// <summary>
    ///   Adds a server to the configuration. Use fluently: Options.WithServer(...).WithServer(...)
    /// </summary>
    function WithServer(const AUrl, ADescription: string): TOpenAPIOptions;

    /// <summary>
    ///   Enables Bearer token authentication (JWT).
    /// </summary>
    function WithBearerAuth(const AFormat: string = 'JWT'; const ADescription: string = 'Bearer token authentication'): TOpenAPIOptions;

    /// <summary>
    ///   Enables API Key authentication.
    /// </summary>
    function WithApiKeyAuth(const AKeyName: string = 'X-API-Key'; ALocation: TApiKeyLocation = aklHeader; const ADescription: string = 'API Key authentication'): TOpenAPIOptions;

    /// <summary>
    ///   Adds a global response (e.g., 400, 500) to all operations.
    /// </summary>
    function WithGlobalResponse(ACode: Integer; const ADescription: string): TOpenAPIOptions;
  end;

  /// <summary>
  ///   Fluent builder for creating OpenAPI/Swagger options.
  ///   This is a managed record - no manual memory management required.
  /// </summary>
  TOpenAPIBuilder = record
  private
    FOptions: TOpenAPIOptions;
    FInitialized: Boolean;
    procedure EnsureInitialized;
  public
    /// <summary>
    ///   Creates a new OpenAPI builder with default options.
    /// </summary>
    class function Create: TOpenAPIBuilder; static;

    /// <summary>
    ///   Sets the API title.
    /// </summary>
    function Title(const ATitle: string): TOpenAPIBuilder;

    /// <summary>
    ///   Sets the API description.
    /// </summary>
    function Description(const ADescription: string): TOpenAPIBuilder;

    /// <summary>
    ///   Sets the API version.
    /// </summary>
    function Version(const AVersion: string): TOpenAPIBuilder;

    /// <summary>
    ///   Adds a server to the configuration.
    /// </summary>
    function Server(const AUrl: string; const ADescription: string = ''): TOpenAPIBuilder;

    /// <summary>
    ///   Sets contact information.
    /// </summary>
    function Contact(const AName: string; const AEmail: string = ''): TOpenAPIBuilder;

    /// <summary>
    ///   Sets license information.
    /// </summary>
    function License(const AName: string; const AUrl: string = ''): TOpenAPIBuilder;

    /// <summary>
    ///   Sets custom Swagger UI path (default: /swagger).
    /// </summary>
    function SwaggerPath(const APath: string): TOpenAPIBuilder;

    /// <summary>
    ///   Sets custom Swagger JSON path (default: /swagger.json).
    /// </summary>
    function SwaggerJsonPath(const APath: string): TOpenAPIBuilder;

    /// <summary>
    ///   Enables Bearer token authentication (JWT).
    /// </summary>
    function BearerAuth(const AFormat: string = 'JWT'; const ADescription: string = 'Bearer token authentication'): TOpenAPIBuilder;

    /// <summary>
    ///   Enables API Key authentication.
    /// </summary>
    function ApiKeyAuth(const AKeyName: string = 'X-API-Key'; ALocation: TApiKeyLocation = aklHeader; const ADescription: string = 'API Key authentication'): TOpenAPIBuilder;

    /// <summary>
    ///   Adds a global response (e.g., 400, 500) to all operations.
    /// </summary>
    function GlobalResponse(ACode: Integer; const ADescription: string): TOpenAPIBuilder;

    /// <summary>
    ///   Returns the built OpenAPI options.
    /// </summary>
    function Build: TOpenAPIOptions;

    /// <summary>
    ///   Implicit conversion to TOpenAPIOptions for direct use in UseSwagger.
    /// </summary>
    class operator Implicit(const ABuilder: TOpenAPIBuilder): TOpenAPIOptions;
  end;

  /// <summary>
  ///   Generates OpenAPI 3.0 documentation from endpoint metadata.
  /// </summary>
  TOpenAPIGenerator = class
  private
    FOptions: TOpenAPIOptions;
    FKnownTypes: IDictionary<PTypeInfo, string>;
    FDefinitions: IDictionary<string, TOpenAPISchema>;

    function CreateInfoSection: TOpenAPIInfo;
    function CreatePathItem(const AMetadata: TEndpointMetadata): TOpenAPIPathItem;
    function CreateOperation(const AMetadata: TEndpointMetadata): TOpenAPIOperation;
    function GetOperationId(const AMethod, APath: string): string;
    function GetSchemaName(ATypeInfo: PTypeInfo): string;

    /// <summary>
    ///   Creates security schemes based on options.
    /// </summary>
    procedure CreateSecuritySchemes(ADocument: TOpenAPIDocument);

    /// <summary>
    ///   Converts a Delphi RTTI type to an OpenAPI schema.
    /// </summary>
    function TypeToSchema(ATypeInfo: PTypeInfo): TOpenAPISchema;

    /// <summary>
    ///   Converts an OpenAPI schema to JSON object recursively.
    /// </summary>
    function SchemaToJson(ASchema: TOpenAPISchema): TJsonObject;

    /// <summary>
    ///   Extracts path parameters from a route pattern (e.g., /users/{id}).
    /// </summary>
    function ExtractPathParameters(const APath: string): TArray<string>;

    /// <summary>
    ///   Processes Swagger attributes on a type and applies them to the schema.
    /// </summary>
    procedure ProcessTypeAttributes(ARttiType: TRttiType; ASchema: TOpenAPISchema);

    /// <summary>
    ///   Processes Swagger attributes on a field/property and applies them to the schema.
    /// </summary>
    procedure ProcessFieldAttributes(AMember: TRttiMember; ASchema: TOpenAPISchema; out AShouldIgnore: Boolean);

  public
    constructor Create(const AOptions: TOpenAPIOptions);
    destructor Destroy; override;

    /// <summary>
    ///   Generates a complete OpenAPI document from endpoint metadata.
    /// </summary>
    function Generate(const AEndpoints: TArray<TEndpointMetadata>): TOpenAPIDocument;

    /// <summary>
    ///   Generates OpenAPI JSON string from endpoint metadata.
    /// </summary>
    function GenerateJson(const AEndpoints: TArray<TEndpointMetadata>): string;
  end;

/// <summary>
///   Global helper function for creating OpenAPI/Swagger configuration.
///   Usage: App.Builder.UseSwagger(Swagger.Title('My API').Version('v1'));
/// </summary>
function Swagger: TOpenAPIBuilder;

implementation

uses
  System.RegularExpressions,
  System.StrUtils;

{ TOpenAPIOptions }

class function TOpenAPIOptions.Default: TOpenAPIOptions;
begin
  Result.Title := 'Dext API';
  Result.Description := 'API documentation generated by Dext Framework';
  Result.Version := '1.0.0';
  SetLength(Result.Servers, 0); // No default servers - use WithServer() to add
  Result.ContactName := '';
  Result.ContactEmail := '';
  Result.LicenseName := 'MIT';
  Result.LicenseUrl := 'https://opensource.org/licenses/MIT';

  // Swagger UI paths defaults
  Result.SwaggerPath := '/swagger';
  Result.SwaggerJsonPath := '/swagger.json';

  // Security defaults
  Result.EnableBearerAuth := False;
  Result.BearerFormat := '';
  Result.BearerDescription := '';
  Result.EnableApiKeyAuth := False;
  Result.ApiKeyName := '';
  Result.ApiKeyLocation := aklHeader;
  Result.ApiKeyDescription := '';
  SetLength(Result.GlobalResponses, 0);
  SetLength(Result.SecuritySchemes, 0); // Initialize
end;

function TOpenAPIOptions.WithBearerAuth(const AFormat, ADescription: string): TOpenAPIOptions;
begin
  Result := Self;
  Result.EnableBearerAuth := True;
  Result.BearerFormat := AFormat;
  Result.BearerDescription := ADescription;
end;

function TOpenAPIOptions.WithApiKeyAuth(const AKeyName: string; ALocation: TApiKeyLocation; const ADescription: string): TOpenAPIOptions;
begin
  Result := Self;
  Result.EnableApiKeyAuth := True;
  Result.ApiKeyName := AKeyName;
  Result.ApiKeyLocation := ALocation;
  Result.ApiKeyDescription := ADescription;
end;

function TOpenAPIOptions.WithGlobalResponse(ACode: Integer; const ADescription: string): TOpenAPIOptions;
begin
  Result := Self;
  SetLength(Result.GlobalResponses, Length(Result.GlobalResponses) + 1);
  Result.GlobalResponses[High(Result.GlobalResponses)] := TPair<Integer, string>.Create(ACode, ADescription);
end;

function TOpenAPIOptions.WithServer(const AUrl, ADescription: string): TOpenAPIOptions;
var
  NewLength: Integer;
begin
  Result := Self;
  NewLength := Length(Result.Servers) + 1;
  SetLength(Result.Servers, NewLength);
  // TOpenAPIServer is now a record, so no Create needed
  Result.Servers[NewLength - 1].Url := AUrl;
  Result.Servers[NewLength - 1].Description := ADescription;
end;

{ Swagger helper function }

function Swagger: TOpenAPIBuilder;
begin
  Result := TOpenAPIBuilder.Create;
end;

{ TOpenAPIBuilder }

procedure TOpenAPIBuilder.EnsureInitialized;
begin
  if not FInitialized then
  begin
    FOptions := TOpenAPIOptions.Default;
    FInitialized := True;
  end;
end;

class function TOpenAPIBuilder.Create: TOpenAPIBuilder;
begin
  Result.FOptions := TOpenAPIOptions.Default;
  Result.FInitialized := True;
end;

function TOpenAPIBuilder.Title(const ATitle: string): TOpenAPIBuilder;
begin
  EnsureInitialized;
  FOptions.Title := ATitle;
  Result := Self;
end;

function TOpenAPIBuilder.Description(const ADescription: string): TOpenAPIBuilder;
begin
  EnsureInitialized;
  FOptions.Description := ADescription;
  Result := Self;
end;

function TOpenAPIBuilder.Version(const AVersion: string): TOpenAPIBuilder;
begin
  EnsureInitialized;
  FOptions.Version := AVersion;
  Result := Self;
end;

function TOpenAPIBuilder.Server(const AUrl: string; const ADescription: string): TOpenAPIBuilder;
var
  NewLength: Integer;
begin
  EnsureInitialized;
  NewLength := Length(FOptions.Servers) + 1;
  SetLength(FOptions.Servers, NewLength);
  FOptions.Servers[NewLength - 1].Url := AUrl;
  FOptions.Servers[NewLength - 1].Description := ADescription;
  Result := Self;
end;

function TOpenAPIBuilder.Contact(const AName: string; const AEmail: string): TOpenAPIBuilder;
begin
  EnsureInitialized;
  FOptions.ContactName := AName;
  FOptions.ContactEmail := AEmail;
  Result := Self;
end;

function TOpenAPIBuilder.License(const AName: string; const AUrl: string): TOpenAPIBuilder;
begin
  EnsureInitialized;
  FOptions.LicenseName := AName;
  FOptions.LicenseUrl := AUrl;
  Result := Self;
end;

function TOpenAPIBuilder.SwaggerPath(const APath: string): TOpenAPIBuilder;
begin
  EnsureInitialized;
  FOptions.SwaggerPath := APath;
  Result := Self;
end;

function TOpenAPIBuilder.SwaggerJsonPath(const APath: string): TOpenAPIBuilder;
begin
  EnsureInitialized;
  FOptions.SwaggerJsonPath := APath;
  Result := Self;
end;

function TOpenAPIBuilder.BearerAuth(const AFormat: string; const ADescription: string): TOpenAPIBuilder;
begin
  EnsureInitialized;
  FOptions.EnableBearerAuth := True;
  FOptions.BearerFormat := AFormat;
  FOptions.BearerDescription := ADescription;
  Result := Self;
end;

function TOpenAPIBuilder.ApiKeyAuth(const AKeyName: string; ALocation: TApiKeyLocation; const ADescription: string): TOpenAPIBuilder;
begin
  EnsureInitialized;
  FOptions.EnableApiKeyAuth := True;
  FOptions.ApiKeyName := AKeyName;
  FOptions.ApiKeyLocation := ALocation;
  FOptions.ApiKeyDescription := ADescription;
  Result := Self;
end;

function TOpenAPIBuilder.GlobalResponse(ACode: Integer; const ADescription: string): TOpenAPIBuilder;
begin
  EnsureInitialized;
  SetLength(FOptions.GlobalResponses, Length(FOptions.GlobalResponses) + 1);
  FOptions.GlobalResponses[High(FOptions.GlobalResponses)] := TPair<Integer, string>.Create(ACode, ADescription);
  Result := Self;
end;

function TOpenAPIBuilder.Build: TOpenAPIOptions;
begin
  EnsureInitialized;
  Result := FOptions;
end;

class operator TOpenAPIBuilder.Implicit(const ABuilder: TOpenAPIBuilder): TOpenAPIOptions;
begin
  Result := ABuilder.FOptions;
end;

{ TOpenAPIGenerator }

constructor TOpenAPIGenerator.Create(const AOptions: TOpenAPIOptions);
begin
  inherited Create;
  FOptions := AOptions;
  FKnownTypes := TCollections.CreateDictionary<PTypeInfo, string>;
  FDefinitions := TCollections.CreateDictionary<string, TOpenAPISchema>;
end;

destructor TOpenAPIGenerator.Destroy;
var
  Key: string;
  LKeys: TArray<string>;
  i: Integer;
begin
  LKeys := FDefinitions.Keys;
  for i := 0 to High(LKeys) do
  begin
    Key := LKeys[i];
    FDefinitions[Key].Free;
  end;
  inherited;
end;

function TOpenAPIGenerator.CreateInfoSection: TOpenAPIInfo;
begin
  Result := TOpenAPIInfo.Create;
  Result.Title := FOptions.Title;
  Result.Description := FOptions.Description;
  Result.Version := FOptions.Version;

  if FOptions.ContactName <> '' then
  begin
    Result.Contact := TOpenAPIContact.Create;
    Result.Contact.Name := FOptions.ContactName;
    Result.Contact.Email := FOptions.ContactEmail;
  end;

  if FOptions.LicenseName <> '' then
  begin
    Result.License := TOpenAPILicense.Create;
    Result.License.Name := FOptions.LicenseName;
    Result.License.Url := FOptions.LicenseUrl;
  end;
end;

procedure TOpenAPIGenerator.CreateSecuritySchemes(ADocument: TOpenAPIDocument);
var
  i: Integer;
  LPairs: TArray<TPair<string, TOpenAPISecurityScheme>>;
  Pair: TPair<string, TOpenAPISecurityScheme>;
  Scheme: TOpenAPISecurityScheme;
begin
  if FOptions.EnableBearerAuth then
  begin
    Scheme := TOpenAPISecurityScheme.Create;
    Scheme.SchemeType := sstHttp;
    Scheme.Scheme := 'bearer';
    Scheme.BearerFormat := FOptions.BearerFormat;
    Scheme.Description := FOptions.BearerDescription;
    if not ADocument.SecuritySchemes.ContainsKey('bearerAuth') then
      ADocument.SecuritySchemes.Add('bearerAuth', Scheme)
    else
      Scheme.Free;
  end;

  if FOptions.EnableApiKeyAuth then
  begin
    Scheme := TOpenAPISecurityScheme.Create;
    Scheme.SchemeType := sstApiKey;
    Scheme.Name := FOptions.ApiKeyName;
    Scheme.Location := FOptions.ApiKeyLocation;
    Scheme.Description := FOptions.ApiKeyDescription;
    if not ADocument.SecuritySchemes.ContainsKey('apiKeyAuth') then
      ADocument.SecuritySchemes.Add('apiKeyAuth', Scheme)
    else
      Scheme.Free;
  end;

  if FOptions.SecuritySchemes <> nil then
  begin
     LPairs := FOptions.SecuritySchemes;
     for i := 0 to High(LPairs) do
     begin
        Pair := LPairs[i];
        if not ADocument.SecuritySchemes.ContainsKey(Pair.Key) then
          ADocument.SecuritySchemes.Add(Pair.Key, Pair.Value);
     end;
  end;
end;

function TOpenAPIGenerator.GetOperationId(const AMethod, APath: string): string;
var
  CleanPath: string;
begin
  // Convert /users/{id} to getUsersById
  CleanPath := APath.Replace('/', '_').Replace('{', '').Replace('}', '');
  if CleanPath.StartsWith('_') then
    CleanPath := CleanPath.Substring(1);
  Result := AMethod.ToLower + CleanPath;
end;

function TOpenAPIGenerator.ExtractPathParameters(const APath: string): TArray<string>;
var
  Matches: TMatchCollection;
  I: Integer;
  Regex: TRegEx;
begin
  Regex := TRegEx.Create('\{([^}]+)\}');
  Matches := Regex.Matches(APath);

  SetLength(Result, Matches.Count);
  for I := 0 to Matches.Count - 1 do
    Result[I] := Matches[I].Groups[1].Value;
end;

function TOpenAPIGenerator.GetSchemaName(ATypeInfo: PTypeInfo): string;
var
  Attr: TCustomAttribute;
  I: Integer;
  Typ: TRttiType;
begin
  Result := string(ATypeInfo.Name);
  if Result.StartsWith('T') and (Result.Length > 1) then
    Result := Result.Substring(1); // Standard Delphi convention TUser -> User

  // Check for override
  Typ := TReflection.Context.GetType(ATypeInfo);
  if Assigned(Typ) then
  begin
    for I := 0 to High(Typ.GetAttributes) do
    begin
      Attr := Typ.GetAttributes[I];
      if Attr is SwaggerSchemaAttribute then
      begin
        if SwaggerSchemaAttribute(Attr).Title <> '' then
          Exit(SwaggerSchemaAttribute(Attr).Title);
      end;
    end;
  end;
end;

function TOpenAPIGenerator.TypeToSchema(ATypeInfo: PTypeInfo): TOpenAPISchema;
var
  ArrayType: TRttiDynamicArrayType;
  Attr: TCustomAttribute;
  DefinitionSchema: TOpenAPISchema;
  ElementType: TRttiType;
  EnumValues: TArray<string>;
  Field: TRttiField;
  FieldSchema: TOpenAPISchema;
  I, j: Integer;
  LTypeName: string;
  Prop: TRttiProperty;
  PropName: string;
  RttiType: TRttiType;
  SchemaName: string;
  ShouldIgnore: Boolean;
  TypeData: PTypeData;
  ValueField: TRttiField;
  ValueProp: TRttiProperty;
begin
  // Handle complex types (Record/Class) with References
  if (ATypeInfo.Kind in [tkRecord, tkMRecord, tkClass]) then
  begin
    // Special handling for Dext Smart Types (Prop<T>) - Unwrap value
    LTypeName := string(ATypeInfo.Name);
    if (ATypeInfo.Kind in [tkRecord, tkMRecord]) and
       (LTypeName.Contains('Prop<')) then
    begin
      RttiType := TReflection.Context.GetType(ATypeInfo);
      if Assigned(RttiType) then
      begin
        // For SmartTypes, we want to return the schema of the inner 'Value' property/field
        ValueProp := RttiType.GetProperty('Value');
        if Assigned(ValueProp) then
        begin
          Result := TypeToSchema(ValueProp.PropertyType.Handle);
          Exit;
        end;

        // Fallback to FValue field if property not found
        ValueField := RttiType.GetField('FValue');
        if Assigned(ValueField) then
        begin
          Result := TypeToSchema(ValueField.FieldType.Handle);
          Exit;
        end;
      end;
    end;

    // Check if we already know this type
    if FKnownTypes.TryGetValue(ATypeInfo, SchemaName) then
    begin
      Result := TOpenAPISchema.Create;
      Result.Ref := '#/components/schemas/' + SchemaName;
      Exit;
    end;

    // Register new type
    SchemaName := GetSchemaName(ATypeInfo);

    // Handle specific generic types or collisions if needed, for now assume unique names
    if FDefinitions.ContainsKey(SchemaName) then
    begin
       // Simple collision handling or assume same type
       // In strict mode we might check if PTypeInfo matches
       Result := TOpenAPISchema.Create;
       Result.Ref := '#/components/schemas/' + SchemaName;
       Exit;
    end;

    FKnownTypes.Add(ATypeInfo, SchemaName);

    // Create the definition
    DefinitionSchema := TOpenAPISchema.Create;
    DefinitionSchema.DataType := odtObject;
    FDefinitions.Add(SchemaName, DefinitionSchema);

    // Now populate the definition (recursively)
    RttiType := TReflection.Context.GetType(ATypeInfo);
    if Assigned(RttiType) then
    begin
      ProcessTypeAttributes(RttiType, DefinitionSchema);

      // Fields
      for I := 0 to High(RttiType.GetFields) do
      begin
        Field := RttiType.GetFields[I];
        if Field.Visibility in [mvPublic, mvPublished] then
        begin
          ShouldIgnore := False;
          FieldSchema := TypeToSchema(Field.FieldType.Handle);
          ProcessFieldAttributes(Field, FieldSchema, ShouldIgnore);

          PropName := Field.Name;
          for j := 0 to High(Field.GetAttributes) do
          begin
            Attr := Field.GetAttributes[j];
            if Attr is SwaggerPropertyAttribute then
              if SwaggerPropertyAttribute(Attr).Name <> '' then
                 PropName := SwaggerPropertyAttribute(Attr).Name;
          end;

          if (not ShouldIgnore) and (not DefinitionSchema.Properties.ContainsKey(PropName)) then
            DefinitionSchema.Properties.Add(PropName, FieldSchema)
          else
            FieldSchema.Free;
        end;
      end;

      // Properties
      if ATypeInfo.Kind = tkClass then
      begin
        for I := 0 to High(RttiType.GetProperties) do
        begin
          Prop := RttiType.GetProperties[I];
          if (Prop.Visibility in [mvPublic, mvPublished]) and Prop.IsReadable then
          begin
             ShouldIgnore := False;

             PropName := Prop.Name;
             for j := 0 to High(Prop.GetAttributes) do
             begin
                Attr := Prop.GetAttributes[j];
                if Attr is SwaggerPropertyAttribute then
                     if SwaggerPropertyAttribute(Attr).Name <> '' then
                        PropName := SwaggerPropertyAttribute(Attr).Name;
             end;

             if not DefinitionSchema.Properties.ContainsKey(PropName) then
             begin
                FieldSchema := TypeToSchema(Prop.PropertyType.Handle);
                ProcessFieldAttributes(Prop, FieldSchema, ShouldIgnore);
                if not ShouldIgnore then
                  DefinitionSchema.Properties.Add(PropName, FieldSchema)
                else
                  FieldSchema.Free;
             end;
          end;
        end;
      end;
    end;

    // Return reference to the newly created definition
    Result := TOpenAPISchema.Create;
    Result.Ref := '#/components/schemas/' + SchemaName;
    Exit;
  end;

  // Simple Types and Arrays
  Result := TOpenAPISchema.Create;

  case ATypeInfo.Kind of
    tkInteger, tkInt64:
    begin
      Result.DataType := odtInteger;
      Result.Format := 'int64';
    end;

    tkFloat:
    begin
      Result.DataType := odtNumber;
      if ATypeInfo = TypeInfo(TDateTime) then
      begin
        Result.Format := 'date-time';
        Result.Description := 'Date and time in ISO 8601 format';
      end
      else if ATypeInfo = TypeInfo(TDate) then
      begin
        Result.Format := 'date';
        Result.Description := 'Date in ISO 8601 format';
      end
      else if ATypeInfo = TypeInfo(TTime) then
      begin
        Result.Format := 'time';
        Result.Description := 'Time in ISO 8601 format';
      end
      else
        Result.Format := 'double';
    end;

    tkString, tkLString, tkWString, tkUString:
    begin
      Result.DataType := odtString;
    end;

    tkEnumeration:
    begin
      if ATypeInfo = TypeInfo(Boolean) then
        Result.DataType := odtBoolean
      else
      begin
        Result.DataType := odtString;
        TypeData := GetTypeData(ATypeInfo);
        if Assigned(TypeData) then
        begin
          SetLength(EnumValues, TypeData.MaxValue - TypeData.MinValue + 1);
          for I := TypeData.MinValue to TypeData.MaxValue do
            EnumValues[I - TypeData.MinValue] := GetEnumName(ATypeInfo, I);
          Result.Enum := EnumValues;
        end;
      end;
    end;

    tkDynArray:
    begin
      Result.DataType := odtArray;
      RttiType := TReflection.Context.GetType(ATypeInfo);
      if Assigned(RttiType) and (RttiType is TRttiDynamicArrayType) then
      begin
        ArrayType := TRttiDynamicArrayType(RttiType);
        ElementType := ArrayType.ElementType;
        if Assigned(ElementType) then
          Result.Items := TypeToSchema(ElementType.Handle);
      end;
    end;
  end;
end;

function TOpenAPIGenerator.SchemaToJson(ASchema: TOpenAPISchema): TJsonObject;
var
  EnumArray: TJsonArray;
  ExampleJson: TJsonBaseObject;
  i: Integer;
  PropertiesJson: TJsonObject;
  PropPair: TPair<string, TOpenAPISchema>;
  PropSchema: TOpenAPISchema;
  RequiredArray: TJsonArray;
  PropPairs: TArray<TPair<string, TOpenAPISchema>>;
begin
  Result := TJsonObject.Create;

  if ASchema.Ref <> '' then
  begin
    Result.S['$ref'] := ASchema.Ref;
    Exit;
  end;

  // Type
  case ASchema.DataType of
    odtString: Result.S['type'] := 'string';
    odtNumber: Result.S['type'] := 'number';
    odtInteger: Result.S['type'] := 'integer';
    odtBoolean: Result.S['type'] := 'boolean';
    odtArray: Result.S['type'] := 'array';
    odtObject: Result.S['type'] := 'object';
  end;

  // Format
  if ASchema.Format <> '' then
    Result.S['format'] := ASchema.Format;

  // Description
  if ASchema.Description <> '' then
    Result.S['description'] := ASchema.Description;

  // Enum values
  if Length(ASchema.Enum) > 0 then
  begin
    EnumArray := TJsonArray.Create;
    for i := 0 to High(ASchema.Enum) do
      EnumArray.Add(ASchema.Enum[i]);
    Result.A['enum'] := EnumArray;
  end;

  // Properties (for objects)
  if (ASchema.DataType = odtObject) and (ASchema.Properties.Count > 0) then
  begin
    PropertiesJson := TJsonObject.Create;
    PropPairs := ASchema.Properties.ToArray;
    for i := 0 to High(PropPairs) do
    begin
      PropPair := PropPairs[i];
      PropSchema := PropPair.Value;
      PropertiesJson.O[PropPair.Key] := SchemaToJson(PropSchema);
    end;
    Result.O['properties'] := PropertiesJson;

    // Required fields
    if Length(ASchema.Required) > 0 then
    begin
      RequiredArray := TJsonArray.Create;
      for i := 0 to High(ASchema.Required) do
        RequiredArray.Add(ASchema.Required[i]);
      Result.A['required'] := RequiredArray;
    end;
  end;

  // Items (for arrays)
  if (ASchema.DataType = odtArray) and Assigned(ASchema.Items) then
  begin
    Result.O['items'] := SchemaToJson(ASchema.Items);
  end;

  // Example
  if ASchema.Example <> '' then
  begin
    // Try to parse example as JSON if it looks like one, otherwise treat as string
    if (ASchema.Example.StartsWith('{') and ASchema.Example.EndsWith('}')) or
       (ASchema.Example.StartsWith('[') and ASchema.Example.EndsWith(']')) then
    begin
      try
        ExampleJson := TJsonObject.Parse(ASchema.Example);
        if Assigned(ExampleJson) then
        begin
          if ExampleJson is TJsonObject then
            Result.O['example'] := TJsonObject(ExampleJson)
          else if ExampleJson is TJsonArray then
            Result.A['example'] := TJsonArray(ExampleJson)
          else
            Result.S['example'] := ASchema.Example;
        end
        else
        begin
          // If not object, maybe array? TJsonObject.Parse handles both?
          // JsonDataObjects TJsonObject.Parse returns TJsonBaseObject.
          // Let's keep it simple: if it's a string, just add it as string for now to be safe,
          // unless we are sure.
          // Actually, for simple types (int, bool), the attribute value is a string.
          // We should try to convert based on DataType.
          Result.S['example'] := ASchema.Example;
        end;
      except
        Result.S['example'] := ASchema.Example;
      end;
    end
    else
    begin
      // Convert based on type
      case ASchema.DataType of
        odtInteger: Result.L['example'] := StrToInt64Def(ASchema.Example, 0);
        odtNumber: Result.D['example'] := StrToFloatDef(ASchema.Example, 0.0);
        odtBoolean: Result.B['example'] := SameText(ASchema.Example, 'true');
        else Result.S['example'] := ASchema.Example;
      end;
    end;
  end;
end;

procedure TOpenAPIGenerator.ProcessTypeAttributes(ARttiType: TRttiType; ASchema: TOpenAPISchema);
var
  Attr: TCustomAttribute;
  I: Integer;
  SchemaAttr: SwaggerSchemaAttribute;
begin
  if not Assigned(ARttiType) then
    Exit;

  for I := 0 to High(ARttiType.GetAttributes) do
  begin
    Attr := ARttiType.GetAttributes[I];
    if Attr is SwaggerSchemaAttribute then
    begin
      SchemaAttr := SwaggerSchemaAttribute(Attr);
      if SchemaAttr.Title <> '' then
        ASchema.Description := SchemaAttr.Title + '. ' + ASchema.Description;
      if SchemaAttr.Description <> '' then
        ASchema.Description := SchemaAttr.Description;
    end;
  end;
end;

procedure TOpenAPIGenerator.ProcessFieldAttributes(AMember: TRttiMember; ASchema: TOpenAPISchema; out AShouldIgnore: Boolean);
var
  Attr: TCustomAttribute;
  ExampleAttr: SwaggerExampleAttribute;
  FormatAttr: SwaggerFormatAttribute;
  I: Integer;
  PropAttr: SwaggerPropertyAttribute;
begin
  AShouldIgnore := False;

  if not Assigned(AMember) then
    Exit;

  for I := 0 to High(AMember.GetAttributes) do
  begin
    Attr := AMember.GetAttributes[I];
    // Check if should ignore
    if Attr is SwaggerIgnorePropertyAttribute then
    begin
      AShouldIgnore := True;
      Exit;
    end;

    // Process property customization
    if Attr is SwaggerPropertyAttribute then
    begin
      PropAttr := SwaggerPropertyAttribute(Attr);
      if PropAttr.Description <> '' then
        ASchema.Description := PropAttr.Description;
      if PropAttr.Format <> '' then
        ASchema.Format := PropAttr.Format;
    end;

    // Process format
    if Attr is SwaggerFormatAttribute then
    begin
      FormatAttr := SwaggerFormatAttribute(Attr);
      ASchema.Format := FormatAttr.Format;
    end;

    // Process example
    if Attr is SwaggerExampleAttribute then
    begin
      ExampleAttr := SwaggerExampleAttribute(Attr);
      ASchema.Example := ExampleAttr.Value;
    end;
  end;
end;

function TOpenAPIGenerator.CreateOperation(const AMetadata: TEndpointMetadata): TOpenAPIOperation;
var
  ExtraResp, GResponse: TOpenAPIResponse;
  GlobalResp: TPair<Integer, string>;
  i: Integer;
  GlobalRespPairs: TArray<TPair<Integer, string>>;
  Param: TOpenAPIParameter;
  ParamName: string;
  PathParams: TArray<string>;
  RespMeta: TOpenAPIResponseMetadata;
  Response: TOpenAPIResponse;
  ResponseSchema, ExtraSchema, ErrorSchema: TOpenAPISchema;
  Schema: TOpenAPISchema;
  SecRequirement: IDictionary<string, TArray<string>>;
  SuccessCode, SuccessDesc, CodeStr, ContentType, SchemeName: string;
begin
  Result := TOpenAPIOperation.Create;
  Result.Summary := AMetadata.Summary;
  Result.Description := AMetadata.Description;
  Result.OperationId := GetOperationId(AMetadata.Method, AMetadata.Path);
  Result.Tags := AMetadata.Tags;

  // Extract path parameters
  PathParams := ExtractPathParameters(AMetadata.Path);
  for i := 0 to High(PathParams) do
  begin
    ParamName := PathParams[i];
    Param := TOpenAPIParameter.Create;
    Param.Name := ParamName;
    Param.Location := oplPath;
    Param.Required := True;
    Param.Schema.DataType := odtString; // Default to string
    Result.Parameters.Add(Param);
  end;

  // Add request body for POST/PUT/PATCH only if a RequestType is defined
  if (AMetadata.Method.ToUpper.Equals('POST') or
     AMetadata.Method.ToUpper.Equals('PUT') or
     AMetadata.Method.ToUpper.Equals('PATCH')) and
     Assigned(AMetadata.RequestType) then
  begin
    Result.RequestBody := TOpenAPIRequestBody.Create;
    Result.RequestBody.Required := True;

    Schema := TypeToSchema(AMetadata.RequestType);
    Result.RequestBody.Content.Add('application/json', Schema);
  end;

  // Add appropriate responses based on method and metadata

  // Determine success status code
  SuccessCode := '200';
  SuccessDesc := 'Successful response';

  if AMetadata.Method.ToUpper.Equals('POST') then
  begin
    SuccessCode := '201'; // Default to 201 for POST
    SuccessDesc := 'Created';
  end
  else if AMetadata.Method.ToUpper.Equals('DELETE') then
  begin
    SuccessCode := '204';
    SuccessDesc := 'No Content';
  end;

  // Add primary success response
  Response := TOpenAPIResponse.Create;
  Response.Description := SuccessDesc;

  // Only add content schema for non-204 responses
  if SuccessCode <> '204' then
  begin
    if Assigned(AMetadata.ResponseType) then
    begin
      ResponseSchema := TypeToSchema(AMetadata.ResponseType);
      Response.Content.Add('application/json', ResponseSchema);
    end;
  end;

  Result.Responses.Add(SuccessCode, Response);

  // Add explicitly documented responses
  for i := 0 to High(AMetadata.Responses) do
  begin
    RespMeta := AMetadata.Responses[i];
    CodeStr := IntToStr(RespMeta.StatusCode);

    // If it's the success code we already added, arguably we should merge or skip.
    // However, explicit metadata usually overrides default.
    // For now, let's only add if not present, OR overwrite if explicit.
    // Let's overwrite/add.

    ExtraResp := TOpenAPIResponse.Create;
    ExtraResp.Description := RespMeta.Description;
    if ExtraResp.Description = '' then
      ExtraResp.Description := 'Response ' + CodeStr;

    // Schema
    if RespMeta.StatusCode <> 204 then
    begin
       ContentType := RespMeta.MediaType;
       if ContentType = '' then ContentType := 'application/json';

       if Assigned(RespMeta.SchemaType) then
       begin
         ExtraSchema := TypeToSchema(RespMeta.SchemaType);
         ExtraResp.Content.Add(ContentType, ExtraSchema);
       end;
    end;

    if Result.Responses.ContainsKey(CodeStr) then
      Result.Responses[CodeStr].Free; // Free old one

    Result.Responses.AddOrSetValue(CodeStr, ExtraResp);
  end;

  // ? Add Global Responses (e.g., 429, 500)
  GlobalRespPairs := FOptions.GlobalResponses;
  for i := 0 to High(GlobalRespPairs) do
  begin
    GlobalResp := GlobalRespPairs[i];
    // Don't overwrite if specific response exists
    if not Result.Responses.ContainsKey(IntToStr(GlobalResp.Key)) then
    begin
      GResponse := TOpenAPIResponse.Create;
      GResponse.Description := GlobalResp.Value;

      // Add a generic error schema
      ErrorSchema := TOpenAPISchema.Create;
      ErrorSchema.DataType := odtObject;
      ErrorSchema.Properties.Add('error', TOpenAPISchema.Create);
      ErrorSchema.Properties['error'].DataType := odtString;

      GResponse.Content.Add('application/json', ErrorSchema);

      Result.Responses.Add(IntToStr(GlobalResp.Key), GResponse);
    end;
  end;

  // Add security requirements
  if Length(AMetadata.Security) > 0 then
  begin
    for i := 0 to High(AMetadata.Security) do
    begin
      SchemeName := AMetadata.Security[i];
      SecRequirement := TCollections.CreateDictionary<string, TArray<string>>;
      SecRequirement.Add(SchemeName, []);
      Result.Security.Add(SecRequirement);
    end;
  end;
end;

function TOpenAPIGenerator.CreatePathItem(const AMetadata: TEndpointMetadata): TOpenAPIPathItem;
var
  Operation: TOpenAPIOperation;
begin
  Result := TOpenAPIPathItem.Create;
  Operation := CreateOperation(AMetadata);

  case IndexStr(AMetadata.Method.ToUpper, ['GET', 'POST', 'PUT', 'DELETE', 'PATCH']) of
    0: Result.Get := Operation;
    1: Result.Post := Operation;
    2: Result.Put := Operation;
    3: Result.Delete := Operation;
    4: Result.Patch := Operation;
  else
    Operation.Free;
  end;
end;

function TOpenAPIGenerator.Generate(const AEndpoints: TArray<TEndpointMetadata>): TOpenAPIDocument;
var
  DefPairs: TArray<TPair<string, TOpenAPISchema>>;
  ExistingPathItem: TOpenAPIPathItem;
  i: Integer;
  Metadata: TEndpointMetadata;
  Operation: TOpenAPIOperation;
  Pair: TPair<string, TOpenAPISchema>;
  PathItem: TOpenAPIPathItem;
begin
  // Reset state to ensure clean generation
  FKnownTypes.Clear;
  FDefinitions.Clear;

  Result := TOpenAPIDocument.Create;
  if Result.Info <> nil then Result.Info.Free; // Free default instance to avoid leak
  Result.Info := CreateInfoSection;

  // Add servers from options
  for i := 0 to Length(FOptions.Servers) - 1 do
  begin
    Result.Servers.Add(FOptions.Servers[i]);
  end;

  CreateSecuritySchemes(Result);

  for i := 0 to High(AEndpoints) do
  begin
    Metadata := AEndpoints[i];
    // Check if path already exists (multiple methods on same path)
    if Result.Paths.TryGetValue(Metadata.Path, ExistingPathItem) then
    begin
      // Add operation to existing path item
      Operation := CreateOperation(Metadata);
      case IndexStr(Metadata.Method.ToUpper, ['GET', 'POST', 'PUT', 'DELETE', 'PATCH']) of
        0:
        begin
          if Assigned(ExistingPathItem.Get) then ExistingPathItem.Get.Free;
          ExistingPathItem.Get := Operation;
        end;
        1:
        begin
          if Assigned(ExistingPathItem.Post) then ExistingPathItem.Post.Free;
          ExistingPathItem.Post := Operation;
        end;
        2:
        begin
          if Assigned(ExistingPathItem.Put) then ExistingPathItem.Put.Free;
          ExistingPathItem.Put := Operation;
        end;
        3:
        begin
          if Assigned(ExistingPathItem.Delete) then ExistingPathItem.Delete.Free;
          ExistingPathItem.Delete := Operation;
        end;
        4:
        begin
          if Assigned(ExistingPathItem.Patch) then ExistingPathItem.Patch.Free;
          ExistingPathItem.Patch := Operation;
        end;
      else
        Operation.Free;
      end;
    end
    else
    begin
      // Create new path item
      PathItem := CreatePathItem(Metadata);
      Result.Paths.Add(Metadata.Path, PathItem);
    end;
  end;

  // Transfer definitions (Schemas)
  DefPairs := FDefinitions.ToArray;
  for i := 0 to High(DefPairs) do
  begin
    Pair := DefPairs[i];
    if not Result.Schemas.ContainsKey(Pair.Key) then
      Result.Schemas.Add(Pair.Key, Pair.Value);
  end;

  // We cleared definitions list in the object, but we transferring ownership
  // DO NOT Free the values here as they are now owned by Document
  FDefinitions.Clear;
end;

function TOpenAPIGenerator.GenerateJson(const AEndpoints: TArray<TEndpointMetadata>): string;
var
  AddOperation: TProc<TOpenAPIOperation, string>;
  ComponentsJson, SchemasJson, SecSchemesJson: TJsonObject;
  ContactJson, LicenseJson: TJsonObject;
  Doc: TOpenAPIDocument;
  i: Integer;
  InfoJson: TJsonObject;
  Json: TJsonObject;
  Pair: TPair<string, TOpenAPIPathItem>;
  Pairs: TArray<TPair<string, TOpenAPIPathItem>>;
  PathItem: TOpenAPIPathItem;
  PathItemJson: TJsonObject;
  PathsJson: TJsonObject;
  SchemaPair: TPair<string, TOpenAPISchema>;
  SchemaPairs: TArray<TPair<string, TOpenAPISchema>>;
  Scheme: TOpenAPISecurityScheme;
  SchemeJson: TJsonObject;
  SecSchemePair: TPair<string, TOpenAPISecurityScheme>;
  SecSchemePairs: TArray<TPair<string, TOpenAPISecurityScheme>>;
  Server: TOpenAPIServer;
  ServerJson: TJsonObject;
  ServersArray: TJsonArray;
begin
  Doc := Generate(AEndpoints);
  try
    Json := TJsonObject.Create;
    try
      Json.S['openapi'] := Doc.OpenAPI;

      // Info section
      InfoJson := TJsonObject.Create;
      InfoJson.S['title'] := Doc.Info.Title;
      InfoJson.S['description'] := Doc.Info.Description;
      InfoJson.S['version'] := Doc.Info.Version;

      if Assigned(Doc.Info.Contact) then
      begin
        ContactJson := TJsonObject.Create;
        if Doc.Info.Contact.Name <> '' then
          ContactJson.S['name'] := Doc.Info.Contact.Name;
        if Doc.Info.Contact.Email <> '' then
          ContactJson.S['email'] := Doc.Info.Contact.Email;
        InfoJson.O['contact'] := ContactJson;
      end;

      if Assigned(Doc.Info.License) then
      begin
        LicenseJson := TJsonObject.Create;
        LicenseJson.S['name'] := Doc.Info.License.Name;
        if Doc.Info.License.Url <> '' then
          LicenseJson.S['url'] := Doc.Info.License.Url;
        InfoJson.O['license'] := LicenseJson;
      end;

      Json.O['info'] := InfoJson;

      // Servers section
      ServersArray := TJsonArray.Create;
      for i := 0 to Doc.Servers.Count - 1 do
      begin
        Server := Doc.Servers[i];
        ServerJson := TJsonObject.Create;
        ServerJson.S['url'] := Server.Url;
        ServerJson.S['description'] := Server.Description;
        ServersArray.Add(ServerJson);
      end;
      Json.A['servers'] := ServersArray;

      // Paths section
      PathsJson := TJsonObject.Create;
      Pairs := Doc.Paths.ToArray;
      for i := 0 to High(Pairs) do
      begin
        Pair := Pairs[i];
        PathItem := Pair.Value;
        PathItemJson := TJsonObject.Create;

        // Helper procedure to add operation
        AddOperation := procedure(Op: TOpenAPIOperation; MethodName: string)
        var
          ContentJson: TJsonObject;
          i, j, k: Integer;
          LSchema: TOpenAPISchema;
          LSchemaPair: TPair<string, TOpenAPISchema>;
          MediaTypeJson: TJsonObject;
          OperationJson: TJsonObject;
          Param: TOpenAPIParameter;
          ParamJson: TJsonObject;
          ParamsArray: TJsonArray;
          RequestBodyJson: TJsonObject;
          Response: TOpenAPIResponse;
          ResponseJson: TJsonObject;
          ResponsePair: TPair<string, TOpenAPIResponse>;
          ResponsePairs: TArray<TPair<string, TOpenAPIResponse>>;
          ResponsesJson: TJsonObject;
          SchemaPairs: TArray<TPair<string, TOpenAPISchema>>;
          ScopesArray: TJsonArray;
          SecJson: TJsonObject;
          SecPair: TPair<string, TArray<string>>;
          SecPairs: TArray<TPair<string, TArray<string>>>;
          SecReq: IDictionary<string, TArray<string>>;
          SecurityArray: TJsonArray;
          TagsArray: TJsonArray;
        begin
          if not Assigned(Op) then Exit;

          OperationJson := TJsonObject.Create;
          if Op.Summary <> '' then
            OperationJson.S['summary'] := Op.Summary;
          if Op.Description <> '' then
            OperationJson.S['description'] := Op.Description;
          OperationJson.S['operationId'] := Op.OperationId;

          // Tags
          if Length(Op.Tags) > 0 then
          begin
            TagsArray := TJsonArray.Create;
            for i := 0 to High(Op.Tags) do
              TagsArray.Add(Op.Tags[i]);
            OperationJson.A['tags'] := TagsArray;
          end;

          // Parameters
          if Op.Parameters.Count > 0 then
          begin
            ParamsArray := TJsonArray.Create;
            for i := 0 to Op.Parameters.Count - 1 do
            begin
              Param := Op.Parameters[i];
              ParamJson := TJsonObject.Create;
              ParamJson.S['name'] := Param.Name;

              case Param.Location of
                oplQuery: ParamJson.S['in'] := 'query';
                oplPath: ParamJson.S['in'] := 'path';
                oplHeader: ParamJson.S['in'] := 'header';
                oplCookie: ParamJson.S['in'] := 'cookie';
              end;

              ParamJson.B['required'] := Param.Required;

              if Param.Description <> '' then
                ParamJson.S['description'] := Param.Description;

              // Schema - use SchemaToJson for complete schema conversion
              ParamJson.O['schema'] := SchemaToJson(Param.Schema);
              ParamsArray.Add(ParamJson);
            end;
            OperationJson.A['parameters'] := ParamsArray;
          end;

          // Request Body
          if Assigned(Op.RequestBody) then
          begin
            RequestBodyJson := TJsonObject.Create;
            RequestBodyJson.B['required'] := Op.RequestBody.Required;

            ContentJson := TJsonObject.Create;
            SchemaPairs := Op.RequestBody.Content.ToArray;
            for i := 0 to High(SchemaPairs) do
            begin
              LSchemaPair := SchemaPairs[i];
              LSchema := LSchemaPair.Value;
              // OpenAPI 3.0 requires: content -> mediaType -> schema -> {schema definition}
              MediaTypeJson := TJsonObject.Create;
              MediaTypeJson.O['schema'] := SchemaToJson(LSchema);
              ContentJson.O[LSchemaPair.Key] := MediaTypeJson;
            end;

            RequestBodyJson.O['content'] := ContentJson;
            OperationJson.O['requestBody'] := RequestBodyJson;
          end;

          // Responses
          ResponsesJson := TJsonObject.Create;
          ResponsePairs := Op.Responses.ToArray;
          for i := 0 to High(ResponsePairs) do
          begin
            ResponsePair := ResponsePairs[i];
            Response := ResponsePair.Value;
            ResponseJson := TJsonObject.Create;
            ResponseJson.S['description'] := Response.Description;

            if Response.Content.Count > 0 then
            begin
              ContentJson := TJsonObject.Create;
              SchemaPairs := Response.Content.ToArray;
              for j := 0 to High(SchemaPairs) do
              begin
                LSchemaPair := SchemaPairs[j];
                LSchema := LSchemaPair.Value;
                // OpenAPI 3.0 requires: content -> mediaType -> schema -> {schema definition}
                MediaTypeJson := TJsonObject.Create;
                MediaTypeJson.O['schema'] := SchemaToJson(LSchema);
                ContentJson.O[LSchemaPair.Key] := MediaTypeJson;
              end;
              ResponseJson.O['content'] := ContentJson;
            end;

            ResponsesJson.O[ResponsePair.Key] := ResponseJson;
          end;
          OperationJson.O['responses'] := ResponsesJson;

          if Op.Security.Count > 0 then
          begin
            SecurityArray := TJsonArray.Create;
            for i := 0 to Op.Security.Count - 1 do
            begin
              SecReq := Op.Security[i];
              SecJson := TJsonObject.Create;
              SecPairs := SecReq.ToArray;
              for j := 0 to High(SecPairs) do
              begin
                SecPair := SecPairs[j];
                ScopesArray := TJsonArray.Create;
                for k := 0 to High(SecPair.Value) do
                  ScopesArray.Add(SecPair.Value[k]);
                SecJson.A[SecPair.Key] := ScopesArray;
              end;
              SecurityArray.Add(SecJson);
            end;
            OperationJson.A['security'] := SecurityArray;
          end;

          PathItemJson.O[MethodName] := OperationJson;
        end;

        AddOperation(PathItem.Get, 'get');
        AddOperation(PathItem.Post, 'post');
        AddOperation(PathItem.Put, 'put');
        AddOperation(PathItem.Delete, 'delete');
        AddOperation(PathItem.Patch, 'patch');

        PathsJson.O[Pair.Key] := PathItemJson;
      end;
      Json.O['paths'] := PathsJson;

      // Components
      if (Doc.Schemas.Count > 0) or (Doc.SecuritySchemes.Count > 0) then
      begin
         ComponentsJson := TJsonObject.Create;

         if Doc.Schemas.Count > 0 then
         begin
           SchemasJson := TJsonObject.Create;
           SchemaPairs := Doc.Schemas.ToArray;
            for i := 0 to High(SchemaPairs) do
            begin
              SchemaPair := SchemaPairs[i];
              SchemasJson.O[SchemaPair.Key] := SchemaToJson(SchemaPair.Value);
            end;
           ComponentsJson.O['schemas'] := SchemasJson;
         end;

         if Doc.SecuritySchemes.Count > 0 then
         begin
           SecSchemesJson := TJsonObject.Create;
           SecSchemePairs := Doc.SecuritySchemes.ToArray;
            for i := 0 to High(SecSchemePairs) do
            begin
              SecSchemePair := SecSchemePairs[i];
             Scheme := SecSchemePair.Value;
             SchemeJson := TJsonObject.Create;

             case Scheme.SchemeType of
               sstHttp:
               begin
                 SchemeJson.S['type'] := 'http';
                 SchemeJson.S['scheme'] := Scheme.Scheme;
                 if Scheme.BearerFormat <> '' then
                   SchemeJson.S['bearerFormat'] := Scheme.BearerFormat;
               end;
               sstApiKey:
               begin
                 SchemeJson.S['type'] := 'apiKey';
                 SchemeJson.S['name'] := Scheme.Name;
                 case Scheme.Location of
                   aklQuery: SchemeJson.S['in'] := 'query';
                   aklHeader: SchemeJson.S['in'] := 'header';
                   aklCookie: SchemeJson.S['in'] := 'cookie';
                 end;
               end;
               sstOAuth2: SchemeJson.S['type'] := 'oauth2';
               sstOpenIdConnect: SchemeJson.S['type'] := 'openIdConnect';
             end;

             if Scheme.Description <> '' then
               SchemeJson.S['description'] := Scheme.Description;

             SecSchemesJson.O[SecSchemePair.Key] := SchemeJson;
           end;
           ComponentsJson.O['securitySchemes'] := SecSchemesJson;
         end;

         Json.O['components'] := ComponentsJson;
      end;

      Result := Json.ToJSON;
    finally
      Json.Free;
    end;
  finally
    Doc.Free;
  end;
end;

end.







