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
unit Dext.OpenAPI.Attributes;

interface

uses
  System.SysUtils;

type
  /// <summary>
  ///   Marks an endpoint to be excluded from Swagger documentation.
  /// </summary>
  SwaggerIgnoreAttribute = class(TCustomAttribute)
  end;

  /// <summary>
  ///   Customizes the operation metadata for an endpoint.
  /// </summary>
  SwaggerOperationAttribute = class(TCustomAttribute)
  private
    FSummary: string;
    FDescription: string;
    FOperationId: string;
    FTags: TArray<string>;
  public
    constructor Create(const ASummary: string); overload;
    constructor Create(const ASummary, ADescription: string); overload;
    constructor Create(const ASummary, ADescription, AOperationId: string); overload;
    
    property Summary: string read FSummary write FSummary;
    property Description: string read FDescription write FDescription;
    property OperationId: string read FOperationId write FOperationId;
    property Tags: TArray<string> read FTags write FTags;
  end;

  /// <summary>
  ///   Defines a custom response for an endpoint.
  /// </summary>
  SwaggerResponseAttribute = class(TCustomAttribute)
  private
    FStatusCode: Integer;
    FDescription: string;
    FContentType: string;
  public
    constructor Create(AStatusCode: Integer; const ADescription: string; const AContentType: string = 'application/json');
    
    property StatusCode: Integer read FStatusCode;
    property Description: string read FDescription;
    property ContentType: string read FContentType;
  end;

  /// <summary>
  ///   Customizes the schema for a type (record or class).
  /// </summary>
  SwaggerSchemaAttribute = class(TCustomAttribute)
  private
    FTitle: string;
    FDescription: string;
    FExample: string;
  public
    constructor Create(const ATitle: string); overload;
    constructor Create(const ATitle, ADescription: string); overload;
    
    property Title: string read FTitle write FTitle;
    property Description: string read FDescription write FDescription;
    property Example: string read FExample write FExample;
  end;

  /// <summary>
  ///   Marks a field/property to be excluded from the schema.
  /// </summary>
  SwaggerIgnorePropertyAttribute = class(TCustomAttribute)
  end;

  /// <summary>
  ///   Customizes a field/property in the schema.
  /// </summary>
  SwaggerPropertyAttribute = class(TCustomAttribute)
  private
    FName: string;
    FDescription: string;
    FExample: string;
    FFormat: string;
    FRequired: Boolean;
  public
    constructor Create(const ADescription: string); overload;
    constructor Create(const AName, ADescription: string); overload;
    
    property Name: string read FName write FName;
    property Description: string read FDescription write FDescription;
    property Example: string read FExample write FExample;
    property Format: string read FFormat write FFormat;
    property Required: Boolean read FRequired write FRequired;
  end;

  /// <summary>
  ///   Marks a field/property as required in the schema.
  /// </summary>
  SwaggerRequiredAttribute = class(TCustomAttribute)
  end;

  /// <summary>
  ///   Adds an example value to a field/property.
  /// </summary>
  SwaggerExampleAttribute = class(TCustomAttribute)
  private
    FValue: string;
  public
    constructor Create(const AValue: string);
    property Value: string read FValue;
  end;

  /// <summary>
  ///   Specifies the format for a field/property (e.g., 'email', 'uri', 'uuid').
  /// </summary>
  SwaggerFormatAttribute = class(TCustomAttribute)
  private
    FFormat: string;
  public
    constructor Create(const AFormat: string);
    property Format: string read FFormat;
  end;

  /// <summary>
  ///   Adds a tag to an endpoint.
  /// </summary>
  SwaggerTagAttribute = class(TCustomAttribute)
  private
    FTag: string;
  public
    constructor Create(const ATag: string);
    property Tag: string read FTag;
  end;

  /// <summary>
  ///   Marks an endpoint as requiring authentication.
  /// </summary>
  SwaggerAuthorizeAttribute = class(TCustomAttribute)
  private
    FScheme: string;
  public
    constructor Create(const AScheme: string = '');
    property Scheme: string read FScheme;
  end;

implementation

{ SwaggerOperationAttribute }

constructor SwaggerOperationAttribute.Create(const ASummary: string);
begin
  inherited Create;
  FSummary := ASummary;
end;

constructor SwaggerOperationAttribute.Create(const ASummary, ADescription: string);
begin
  inherited Create;
  FSummary := ASummary;
  FDescription := ADescription;
end;

constructor SwaggerOperationAttribute.Create(const ASummary, ADescription, AOperationId: string);
begin
  inherited Create;
  FSummary := ASummary;
  FDescription := ADescription;
  FOperationId := AOperationId;
end;

{ SwaggerResponseAttribute }

constructor SwaggerResponseAttribute.Create(AStatusCode: Integer; const ADescription, AContentType: string);
begin
  inherited Create;
  FStatusCode := AStatusCode;
  FDescription := ADescription;
  FContentType := AContentType;
end;

{ SwaggerSchemaAttribute }

constructor SwaggerSchemaAttribute.Create(const ATitle: string);
begin
  inherited Create;
  FTitle := ATitle;
end;

constructor SwaggerSchemaAttribute.Create(const ATitle, ADescription: string);
begin
  inherited Create;
  FTitle := ATitle;
  FDescription := ADescription;
end;

{ SwaggerPropertyAttribute }

constructor SwaggerPropertyAttribute.Create(const ADescription: string);
begin
  inherited Create;
  FDescription := ADescription;
end;

constructor SwaggerPropertyAttribute.Create(const AName, ADescription: string);
begin
  inherited Create;
  FName := AName;
  FDescription := ADescription;
end;

{ SwaggerExampleAttribute }

constructor SwaggerExampleAttribute.Create(const AValue: string);
begin
  inherited Create;
  FValue := AValue;
end;

{ SwaggerFormatAttribute }

constructor SwaggerFormatAttribute.Create(const AFormat: string);
begin
  inherited Create;
  FFormat := AFormat;
end;

{ SwaggerTagAttribute }

constructor SwaggerTagAttribute.Create(const ATag: string);
begin
  inherited Create;
  FTag := ATag;
end;

{ SwaggerAuthorizeAttribute }

constructor SwaggerAuthorizeAttribute.Create(const AScheme: string);
begin
  inherited Create;
  FScheme := AScheme;
end;

end.

