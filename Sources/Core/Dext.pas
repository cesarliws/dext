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
{  Created: 2025-12-11                                                      }
{                                                                           }
{***************************************************************************}
unit Dext;

interface

uses
  Dext.Core.Activator,
  Dext.Collections.Extensions,
  Dext.Collections,
  Dext.Configuration.Binder,
  Dext.Configuration.Core,
  Dext.Configuration.EnvironmentVariables,
  Dext.Configuration.Interfaces,
  Dext.Configuration.Json,
  Dext.DI.Comparers,
  Dext.DI.Core,
  Dext.DI.Extensions,
  Dext.DI.Interfaces,
  Dext.Hosting.BackgroundService,
  Dext.Json,
  Dext.Json.Types,
  Dext.Logging,
  Dext.Logging.Console,
  Dext.Logging.Extensions,
  Dext.Options,
  Dext.Options.Extensions,
  Dext.Specifications.Evaluator,
  Dext.Specifications.Fluent,
  Dext.Specifications.Interfaces,
  Dext.Specifications.OrderBy,
  Dext.Specifications.Types,
  Dext.Threading.Async,
  Dext.Validation,
  Dext.Core.CancellationToken,
  Dext.Core.Extensions,
  Dext.Core.Memory,
  Dext.Core.ValueConverters,
  Dext.Types.Lazy;

type
  // ===========================================================================
  // ??? Dext Core Aliases
  // ===========================================================================

  // Dependency Injection
  IServiceCollection = Dext.DI.Interfaces.IServiceCollection;
  IServiceProvider = Dext.DI.Interfaces.IServiceProvider;
  TServiceType = Dext.DI.Interfaces.TServiceType;
  ServiceLifetime = Dext.DI.Interfaces.TServiceLifetime;
  TMatchMode = Dext.Specifications.Interfaces.TMatchMode;
  TBinaryOperator = Dext.Specifications.Types.TBinaryOperator;
  TLogicalOperator = Dext.Specifications.Types.TLogicalOperator;
  TUnaryOperator = Dext.Specifications.Types.TUnaryOperator;
  
  // JSON Enums
  TDextCaseStyle = Dext.Json.TDextCaseStyle;
  TDextEnumStyle = Dext.Json.TDextEnumStyle;
  TDextFormatting = Dext.Json.TDextFormatting;
  TDextDateFormat = Dext.Json.TDextDateFormat;
  TDextJsonNodeType = Dext.Json.Types.TDextJsonNodeType;
  
  // Configuration
  IConfiguration = Dext.Configuration.Interfaces.IConfiguration;
  IConfigurationSection = Dext.Configuration.Interfaces.IConfigurationSection;
  IConfigurationBuilder = Dext.Configuration.Interfaces.IConfigurationBuilder;
  
  // Logging
  ILogger = Dext.Logging.ILogger;
  ILoggerFactory = Dext.Logging.ILoggerFactory;
  ILoggerProvider = Dext.Logging.ILoggerProvider;
  TLogLevel = Dext.Logging.TLogLevel;

  // Validation
  TValidationError = Dext.Validation.TValidationError;
  TValidationResult = Dext.Validation.TValidationResult;
  TValidator = Dext.Validation.TValidator;

  // Threading
  IAsyncTask = Dext.Threading.Async.IAsyncTask;
  
  // Specifications
  IExpression = Dext.Specifications.Interfaces.IExpression;
  TFluentExpression = Dext.Specifications.Types.TFluentExpression;
  
  // Specifications Fluent
  Specification = Dext.Specifications.Fluent.Specification;
  
  // Activator
  TActivator = Dext.Core.Activator.TActivator;

  // Collections
  TListExtensions = Dext.Collections.Extensions.TListExtensions;
  TCollections = Dext.Collections.TCollections;

  // Configuration
  EConfigurationException = Dext.Configuration.Interfaces.EConfigurationException;
  TConfigurationBinder = Dext.Configuration.Binder.TConfigurationBinder;
  TConfigurationProvider = Dext.Configuration.Core.TConfigurationProvider;
  TConfigurationSection = Dext.Configuration.Core.TConfigurationSection;
  TConfigurationRoot = Dext.Configuration.Core.TConfigurationRoot;
  TConfigurationBuilder = Dext.Configuration.Core.TConfigurationBuilder;
  TConfigurationPath = Dext.Configuration.Core.TConfigurationPath;
  IConfigurationProvider = Dext.Configuration.Interfaces.IConfigurationProvider;
  IConfigurationSource = Dext.Configuration.Interfaces.IConfigurationSource;
  TEnvironmentVariablesConfigurationProvider = Dext.Configuration.EnvironmentVariables.TEnvironmentVariablesConfigurationProvider;
  TEnvironmentVariablesConfigurationSource = Dext.Configuration.EnvironmentVariables.TEnvironmentVariablesConfigurationSource;
  TJsonConfigurationProvider = Dext.Configuration.Json.TJsonConfigurationProvider;
  TJsonConfigurationSource = Dext.Configuration.Json.TJsonConfigurationSource;

  // Dependency Injection
  TServiceTypeComparer = Dext.DI.Comparers.TServiceTypeComparer;
  TServiceDescriptor = Dext.DI.Core.TServiceDescriptor;
  TDextServiceProvider = Dext.DI.Core.TDextServiceProvider;
  TDextServiceScope = Dext.DI.Core.TDextServiceScope;
  TDextServiceCollection = Dext.DI.Core.TDextServiceCollection;
  TServiceCollectionExtensions = Dext.DI.Extensions.TServiceCollectionExtensions;
  TServiceProviderExtensions = Dext.DI.Extensions.TServiceProviderExtensions;
  EDextDIException = Dext.DI.Interfaces.EDextDIException;
  IServiceScope = Dext.DI.Interfaces.IServiceScope;
  TDextDIFactory = Dext.DI.Interfaces.TDextDIFactory;
  TDextServiceCollectionExtensions = Dext.Core.Extensions.TDextServiceCollectionExtensions;

  // Hosting
  IHostedService = Dext.Hosting.BackgroundService.IHostedService;
  IHostedServiceManager = Dext.Hosting.BackgroundService.IHostedServiceManager;
  TBackgroundService = Dext.Hosting.BackgroundService.TBackgroundService;
  THostedServiceManager = Dext.Hosting.BackgroundService.THostedServiceManager;
  TBackgroundServiceBuilder = Dext.Hosting.BackgroundService.TBackgroundServiceBuilder;

  // JSON
  EDextJsonException = Dext.Json.EDextJsonException;
  DextAttribute = Dext.Json.DextAttribute;
  JsonNameAttribute = Dext.Json.JsonNameAttribute;
  JsonIgnoreAttribute = Dext.Json.JsonIgnoreAttribute;
  JsonFormatAttribute = Dext.Json.JsonFormatAttribute;
  JsonStringAttribute = Dext.Json.JsonStringAttribute;
  JsonNumberAttribute = Dext.Json.JsonNumberAttribute;
  JsonBooleanAttribute = Dext.Json.JsonBooleanAttribute;
  TDextJson = Dext.Json.TDextJson;
  TDextSerializer = Dext.Json.TDextSerializer;
  IDextJsonNode = Dext.Json.Types.IDextJsonNode;
  IDextJsonObject = Dext.Json.Types.IDextJsonObject;
  IDextJsonArray = Dext.Json.Types.IDextJsonArray;
  IDextJsonProvider = Dext.Json.Types.IDextJsonProvider;

  // Logging (Already partially added, completing)
  TConsoleLogger = Dext.Logging.Console.TConsoleLogger;
  TConsoleLoggerProvider = Dext.Logging.Console.TConsoleLoggerProvider;
  ILoggingBuilder = Dext.Logging.Extensions.ILoggingBuilder;
  TServiceCollectionLoggingExtensions = Dext.Logging.Extensions.TServiceCollectionLoggingExtensions;
  // TLoggingBuilder is private implementation detail
  TAbstractLogger = Dext.Logging.TAbstractLogger;
  TAggregateLogger = Dext.Logging.TAggregateLogger;
  TLoggerFactory = Dext.Logging.TLoggerFactory;

  // Options
  TOptionsServiceCollectionExtensions = Dext.Options.Extensions.TOptionsServiceCollectionExtensions;
  TOptionsFactory = Dext.Options.TOptionsFactory;

  // Specifications
  TExpressionEvaluator = Dext.Specifications.Evaluator.TExpressionEvaluator;
  //TEvaluatorVisitor = Dext.Specifications.Evaluator.TEvaluatorVisitor; // private
  IOrderBy = Dext.Specifications.Interfaces.IOrderBy;
  IExpressionVisitor = Dext.Specifications.Interfaces.IExpressionVisitor;
  TOrderBy = Dext.Specifications.OrderBy.TOrderBy;
  TAbstractExpression = Dext.Specifications.Types.TAbstractExpression;
  TBinaryExpression = Dext.Specifications.Types.TBinaryExpression;
  TLogicalExpression = Dext.Specifications.Types.TLogicalExpression;
  TUnaryExpression = Dext.Specifications.Types.TUnaryExpression;
  TConstantExpression = Dext.Specifications.Types.TConstantExpression;

  // Threading
  ICancellationToken = Dext.Core.CancellationToken.ICancellationToken;
  TCancellationToken = Dext.Core.CancellationToken.TCancellationToken;
  TCancellationTokenSource = Dext.Core.CancellationToken.TCancellationTokenSource;

  // Validation Attributes
  ValidationAttribute = Dext.Validation.ValidationAttribute;
  RequiredAttribute = Dext.Validation.RequiredAttribute;
  StringLengthAttribute = Dext.Validation.StringLengthAttribute;
  EmailAddressAttribute = Dext.Validation.EmailAddressAttribute;
  RangeAttribute = Dext.Validation.RangeAttribute;
  // Note: TValidator is overloaded (generic & non-generic). Using non-generic only.
  // TValidator = Dext.Validation.TValidator; // Already present in previous block

  // Memory & Utils
  IDeferred = Dext.Core.Memory.IDeferred;
  TDeferredAction = Dext.Core.Memory.TDeferredAction;
  
  // Value Converters
  IValueConverter = Dext.Core.ValueConverters.IValueConverter;
  TValueConverterRegistry = Dext.Core.ValueConverters.TValueConverterRegistry;
  TValueConverter = Dext.Core.ValueConverters.TValueConverter;
  TBaseConverter = Dext.Core.ValueConverters.TBaseConverter;
  TVariantToIntegerConverter = Dext.Core.ValueConverters.TVariantToIntegerConverter;
  TVariantToStringConverter = Dext.Core.ValueConverters.TVariantToStringConverter;
  TVariantToBooleanConverter = Dext.Core.ValueConverters.TVariantToBooleanConverter;
  TVariantToFloatConverter = Dext.Core.ValueConverters.TVariantToFloatConverter;
  TVariantToDateTimeConverter = Dext.Core.ValueConverters.TVariantToDateTimeConverter;
  TVariantToEnumConverter = Dext.Core.ValueConverters.TVariantToEnumConverter;
  TVariantToGuidConverter = Dext.Core.ValueConverters.TVariantToGuidConverter;
  TVariantToClassConverter = Dext.Core.ValueConverters.TVariantToClassConverter;
  TIntegerToEnumConverter = Dext.Core.ValueConverters.TIntegerToEnumConverter;
  TStringToGuidConverter = Dext.Core.ValueConverters.TStringToGuidConverter;
  TVariantToBytesConverter = Dext.Core.ValueConverters.TVariantToBytesConverter;
  TStringToBytesConverter = Dext.Core.ValueConverters.TStringToBytesConverter;
  TClassToClassConverter = Dext.Core.ValueConverters.TClassToClassConverter;

  // Lazy
  ILazy = Dext.Types.Lazy.ILazy;
  
const
  // TServiceLifetime Constants
  Singleton = Dext.DI.Interfaces.Singleton;
  Transient = Dext.DI.Interfaces.Transient;
  Scoped = Dext.DI.Interfaces.Scoped;

  // TLogLevel Constants
  Trace = Dext.Logging.Trace;
  Debug = Dext.Logging.Debug;
  Information = Dext.Logging.Information;
  Warning = Dext.Logging.Warning;
  Error = Dext.Logging.Error;
  Critical = Dext.Logging.Critical;
  None = Dext.Logging.None;

  // JSON Constants
  // CaseStyle
  Unchanged = Dext.Json.Unchanged;
  CamelCase = Dext.Json.CamelCase;
  PascalCase = Dext.Json.PascalCase;
  SnakeCase = Dext.Json.SnakeCase;
  // EnumStyle
  AsNumber = Dext.Json.AsNumber;
  AsString = Dext.Json.AsString;
  // Formatting
  // None = Dext.Json.None; // CONFLICT with TLogLevel.None
  Indented = Dext.Json.Indented;
  // DateFormat
  ISO8601 = Dext.Json.ISO8601;
  UnixTimestamp = Dext.Json.UnixTimestamp;
  CustomFormat = Dext.Json.CustomFormat;
  
  // JSON Node Types
  jntNull = Dext.Json.Types.jntNull;
  jntString = Dext.Json.Types.jntString;
  jntNumber = Dext.Json.Types.jntNumber;
  jntBoolean = Dext.Json.Types.jntBoolean;
  jntObject = Dext.Json.Types.jntObject;
  jntArray = Dext.Json.Types.jntArray;

  // Specification MatchMode
  mmExact = Dext.Specifications.Interfaces.mmExact;
  mmStart = Dext.Specifications.Interfaces.mmStart;
  mmEnd = Dext.Specifications.Interfaces.mmEnd;
  mmAnywhere = Dext.Specifications.Interfaces.mmAnywhere;

  // Specification Operators
  boEqual = Dext.Specifications.Types.boEqual;
  boNotEqual = Dext.Specifications.Types.boNotEqual;
  boGreaterThan = Dext.Specifications.Types.boGreaterThan;
  boGreaterThanOrEqual = Dext.Specifications.Types.boGreaterThanOrEqual;
  boLessThan = Dext.Specifications.Types.boLessThan;
  boLessThanOrEqual = Dext.Specifications.Types.boLessThanOrEqual;
  boLike = Dext.Specifications.Types.boLike;
  boNotLike = Dext.Specifications.Types.boNotLike;
  boIn = Dext.Specifications.Types.boIn;
  boNotIn = Dext.Specifications.Types.boNotIn;
  
  loAnd = Dext.Specifications.Types.loAnd;
  loOr = Dext.Specifications.Types.loOr;
  
  uoNot = Dext.Specifications.Types.uoNot;
  uoIsNull = Dext.Specifications.Types.uoIsNull;
  uoIsNotNull = Dext.Specifications.Types.uoIsNotNull;

/// <summary>
///   Global helper to create a property expression.
/// </summary>
function Prop(const AName: string): TPropExpression;

implementation

function Prop(const AName: string): TPropExpression;
begin
  Result := TPropExpression.Create(AName);
end;

end.
