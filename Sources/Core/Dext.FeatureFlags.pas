{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2026 Cesar Romero & Dext Contributors             }
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
{  Author:  Cesar Romero & Antigravity                                      }
{  Created: 2026-08-10                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.FeatureFlags;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Rtti,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.Configuration.Interfaces;

type
  /// <summary>
  ///   Exception thrown when feature management encounters an error.
  /// </summary>
  EFeatureManagementException = class(Exception);

  /// <summary>
  ///   Evaluation context passed to feature filters.
  /// </summary>
  TFeatureFilterEvaluationContext = record
    FeatureName: string;
    Parameters: IDictionary<string, string>;
    TargetContext: TObject;
    UserOrTenantKey: string;
  end;

  /// <summary>
  ///   Interface for custom feature filter logic.
  /// </summary>
  IFeatureFilter = interface
    ['{C1234567-89AB-CDEF-0123-456789ABCDEF}']
    function GetName: string;
    function Evaluate(const AContext: TFeatureFilterEvaluationContext): Boolean;
  end;

  /// <summary>
  ///   Central interface for evaluating Feature Flags.
  /// </summary>
  IFeatureManager = interface
    ['{B98E1A23-4567-4890-ABCD-FEA123456789}']
    function IsEnabled(const AFeatureName: string): Boolean; overload;
    function IsEnabled(const AFeatureName: string; const AContext: TObject): Boolean; overload;
    function IsEnabled(const AFeatureName, AUserOrTenantKey: string): Boolean; overload;
  end;

  /// <summary>
  ///   Attribute to declare feature gate requirements on controllers or actions.
  /// </summary>
  FeatureGateAttribute = class(TCustomAttribute)
  private
    FFeatureName: string;
  public
    constructor Create(const AFeatureName: string);
    property FeatureName: string read FFeatureName;
  end;

  /// <summary>
  ///   Implementation of IFeatureManager integrated with Dext IConfiguration.
  /// </summary>
  TFeatureManager = class(TInterfacedObject, IFeatureManager)
  private
    FConfiguration: IConfiguration;
    FFilters: IDictionary<string, IFeatureFilter>;
    procedure RegisterDefaultFilters;
    function EvaluateEnabledForRules(const AFeatureSection: IConfigurationSection;
      const AContext: TFeatureFilterEvaluationContext): Boolean;
    function ExtractKeyFromContextObject(const AContextObj: TObject): string;
    function IsEnabledCore(const AFeatureName, AUserOrTenantKey: string;
      const AContext: TObject): Boolean;
  public
    constructor Create(const AConfig: IConfiguration);
    destructor Destroy; override;

    procedure RegisterFilter(const AFilter: IFeatureFilter);
    function IsEnabled(const AFeatureName: string): Boolean; overload;
    function IsEnabled(const AFeatureName: string; const AContext: TObject): Boolean; overload;
    function IsEnabled(const AFeatureName, AUserOrTenantKey: string): Boolean; overload;
  end;

  /// <summary>
  ///   Built-in percentage rollout feature filter. Uses UserOrTenantKey for deterministic rollout per user/tenant.
  /// </summary>
  TPercentageFilter = class(TInterfacedObject, IFeatureFilter)
  public
    function GetName: string;
    function Evaluate(const AContext: TFeatureFilterEvaluationContext): Boolean;
  end;

  /// <summary>
  ///   Built-in time window feature filter.
  /// </summary>
  TTimeWindowFilter = class(TInterfacedObject, IFeatureFilter)
  public
    function GetName: string;
    function Evaluate(const AContext: TFeatureFilterEvaluationContext): Boolean;
  end;

implementation

uses
  System.DateUtils;

{ FeatureGateAttribute }

constructor FeatureGateAttribute.Create(const AFeatureName: string);
begin
  inherited Create;
  FFeatureName := AFeatureName;
end;

{ TPercentageFilter }

function TPercentageFilter.GetName: string;
begin
  Result := 'Percentage';
end;

function TPercentageFilter.Evaluate(const AContext: TFeatureFilterEvaluationContext): Boolean;
var
  ValStr: string;
  ValInt: Integer;
  HashVal: Cardinal;
  KeyToHash: string;
  i: Integer;
begin
  Result := False;
  if not Assigned(AContext.Parameters) or not AContext.Parameters.TryGetValue('Value', ValStr) then
    Exit;

  if not TryStrToInt(ValStr, ValInt) then
    Exit;

  if ValInt <= 0 then
    Exit(False);
  if ValInt >= 100 then
    Exit(True);

  // Require explicit User/Tenant key when percentage rollout rule is active
  if AContext.UserOrTenantKey.IsEmpty then
    Exit(False); // Security default: deny when context key is missing

  KeyToHash := AContext.FeatureName + ':' + AContext.UserOrTenantKey;

  HashVal := 2166136261;
  for i := 1 to Length(KeyToHash) do
  begin
    HashVal := HashVal xor Ord(KeyToHash[i]);
    HashVal := HashVal * 16777619;
  end;

  Result := (HashVal mod 100) < Cardinal(ValInt);
end;

{ TTimeWindowFilter }

function TTimeWindowFilter.GetName: string;
begin
  Result := 'TimeWindow';
end;

function TTimeWindowFilter.Evaluate(const AContext: TFeatureFilterEvaluationContext): Boolean;
var
  StartStr, EndStr: string;
  StartDt, EndDt, NowDt: TDateTime;
begin
  Result := True;
  NowDt := TTimeZone.Local.ToUniversalTime(Now);

  if Assigned(AContext.Parameters) and AContext.Parameters.TryGetValue('Start', StartStr) and not StartStr.IsEmpty then
  begin
    if not TryISO8601ToDate(StartStr, StartDt) then
      Exit(False); // Security rule: Invalid date format MUST deny feature
    if NowDt < StartDt then
      Exit(False);
  end;

  if Assigned(AContext.Parameters) and AContext.Parameters.TryGetValue('End', EndStr) and not EndStr.IsEmpty then
  begin
    if not TryISO8601ToDate(EndStr, EndDt) then
      Exit(False); // Security rule: Invalid date format MUST deny feature
    if NowDt > EndDt then
      Exit(False);
  end;
end;

{ TFeatureManager }

constructor TFeatureManager.Create(const AConfig: IConfiguration);
begin
  inherited Create;
  FConfiguration := AConfig;
  FFilters := TCollections.CreateDictionaryIgnoreCase<string, IFeatureFilter>;
  RegisterDefaultFilters;
end;

destructor TFeatureManager.Destroy;
begin
  FFilters := nil;
  inherited Destroy;
end;

procedure TFeatureManager.RegisterDefaultFilters;
begin
  RegisterFilter(TPercentageFilter.Create);
  RegisterFilter(TTimeWindowFilter.Create);
end;

procedure TFeatureManager.RegisterFilter(const AFilter: IFeatureFilter);
begin
  if AFilter <> nil then
    FFilters.AddOrSetValue(AFilter.GetName, AFilter);
end;

function TFeatureManager.ExtractKeyFromContextObject(const AContextObj: TObject): string;
var
  RttiCtx: TRttiContext;
  RttiType: TRttiType;
  Prop: TRttiProperty;
begin
  Result := '';
  if AContextObj = nil then
    Exit;

  RttiCtx := TRttiContext.Create;
  try
    RttiType := RttiCtx.GetType(AContextObj.ClassType);
    if RttiType <> nil then
    begin
      // Extract key dynamically from property UserId, TenantId, Id or Key
      Prop := RttiType.GetProperty('UserId');
      if Prop = nil then Prop := RttiType.GetProperty('TenantId');
      if Prop = nil then Prop := RttiType.GetProperty('Id');
      if Prop = nil then Prop := RttiType.GetProperty('Key');

      if Prop <> nil then
        Result := Prop.GetValue(AContextObj).ToString;
    end;
  finally
    RttiCtx.Free;
  end;
end;

function TFeatureManager.IsEnabled(const AFeatureName: string): Boolean;
begin
  Result := IsEnabledCore(AFeatureName, '', nil);
end;

function TFeatureManager.IsEnabled(const AFeatureName: string; const AContext: TObject): Boolean;
var
  Key: string;
begin
  Key := ExtractKeyFromContextObject(AContext);
  Result := IsEnabledCore(AFeatureName, Key, AContext);
end;

function TFeatureManager.IsEnabled(const AFeatureName, AUserOrTenantKey: string): Boolean;
begin
  Result := IsEnabledCore(AFeatureName, AUserOrTenantKey, nil);
end;

function TFeatureManager.IsEnabledCore(const AFeatureName, AUserOrTenantKey: string;
  const AContext: TObject): Boolean;
var
  EvalContext: TFeatureFilterEvaluationContext;
  SectionPath: string;
  Section: IConfigurationSection;
  DirectVal: string;
  BoolVal: Boolean;
begin
  Result := False;
  if FConfiguration = nil then
    Exit;

  SectionPath := 'FeatureManagement:' + AFeatureName;
  Section := FConfiguration.GetSection(SectionPath);

  if Section = nil then
    Exit(False); // Non-existing feature MUST default to False

  DirectVal := Section.Value;
  if not DirectVal.IsEmpty then
  begin
    if TryStrToBool(DirectVal, BoolVal) then
      Exit(BoolVal);
  end;

  EvalContext.FeatureName := AFeatureName;
  EvalContext.TargetContext := AContext;
  EvalContext.UserOrTenantKey := AUserOrTenantKey;

  Result := EvaluateEnabledForRules(Section, EvalContext);
end;

function TFeatureManager.EvaluateEnabledForRules(const AFeatureSection: IConfigurationSection;
  const AContext: TFeatureFilterEvaluationContext): Boolean;
var
  EnabledForSection: IConfigurationSection;
  Children: TArray<IConfigurationSection>;
  RuleSection: IConfigurationSection;
  ParamsSection: IConfigurationSection;
  FilterName: string;
  TargetFilter: IFeatureFilter;
  ParamsDict: IDictionary<string, string>;
  ParamsChildren: TArray<IConfigurationSection>;
  ParamChild: IConfigurationSection;
  i: Integer;
  EvalCtx: TFeatureFilterEvaluationContext;
begin
  Result := False;
  if not Assigned(AFeatureSection) then
    Exit(False);

  EnabledForSection := AFeatureSection.GetSection('EnabledFor');
  if not Assigned(EnabledForSection) then
    Exit(False);

  Children := EnabledForSection.GetChildren;
  if Length(Children) = 0 then
    Exit(False);

  EvalCtx := AContext;

  for i := 0 to Length(Children) - 1 do
  begin
    RuleSection := Children[i];
    FilterName := RuleSection.Value;
    if FilterName.IsEmpty then
      FilterName := RuleSection.GetItem('Name');

    if FFilters.TryGetValue(FilterName, TargetFilter) then
    begin
      ParamsDict := TCollections.CreateDictionary<string, string>;

      ParamsSection := RuleSection.GetSection('Parameters');
      if Assigned(ParamsSection) then
      begin
        ParamsChildren := ParamsSection.GetChildren;
        for ParamChild in ParamsChildren do
          ParamsDict.AddOrSetValue(ParamChild.Key, ParamChild.Value);
      end;

      EvalCtx.Parameters := ParamsDict;

      if TargetFilter.Evaluate(EvalCtx) then
        Exit(True);
    end;
  end;
end;

end.
