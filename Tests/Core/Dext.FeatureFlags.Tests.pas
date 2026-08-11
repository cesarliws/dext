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
unit Dext.FeatureFlags.Tests;

interface

uses
  Dext.Testing;

type
  [TestFixture]
  TDextFeatureFlagsTests = class
  public
    [Test]
    procedure Test_NonExisting_Feature_Returns_False;
    [Test]
    procedure Test_Boolean_Feature_Flag_Enabled;
    [Test]
    procedure Test_Deterministic_Percentage_Rollout_Per_User;
    [Test]
    procedure Test_TimeWindow_Filter_Evaluation;
    [Test]
    procedure Test_Custom_Feature_Filter_Registration;
    [Test]
    procedure Test_IsEnabled_With_Context_Object_Extracts_UserId_Via_RTTI;
  end;

implementation

uses
  System.SysUtils,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.Configuration.Interfaces,
  Dext.Configuration.Core,
  Dext.FeatureFlags;

type
  TMockCustomFilter = class(TInterfacedObject, IFeatureFilter)
  public
    function GetName: string;
    function Evaluate(const AContext: TFeatureFilterEvaluationContext): Boolean;
  end;

function TMockCustomFilter.GetName: string;
begin
  Result := 'CustomRegionFilter';
end;

function TMockCustomFilter.Evaluate(const AContext: TFeatureFilterEvaluationContext): Boolean;
var
  Region: string;
begin
  Result := False;
  if Assigned(AContext.Parameters) and AContext.Parameters.TryGetValue('AllowedRegion', Region) then
    Result := SameText(Region, 'BR');
end;

{ TDextFeatureFlagsTests }

procedure TDextFeatureFlagsTests.Test_NonExisting_Feature_Returns_False;
var
  Config: IConfiguration;
  Mgr: IFeatureManager;
begin
  Config := TDextConfiguration.New.Build;
  Mgr := TFeatureManager.Create(Config);

  // Requirement: Non-existing feature MUST return False by default
  Should(Mgr.IsEnabled('NonExistingFeature')).BeFalse;
end;

procedure TDextFeatureFlagsTests.Test_Boolean_Feature_Flag_Enabled;
var
  Config: IConfiguration;
  Mgr: IFeatureManager;
begin
  Config := TDextConfiguration.New
    .AddValues([
      TPair<string, string>.Create('FeatureManagement:BetaFeature', 'True'),
      TPair<string, string>.Create('FeatureManagement:DisabledFeature', 'False')
    ])
    .Build;
  Mgr := TFeatureManager.Create(Config);

  Should(Mgr.IsEnabled('BetaFeature')).BeTrue;
  Should(Mgr.IsEnabled('DisabledFeature')).BeFalse;
end;

procedure TDextFeatureFlagsTests.Test_Deterministic_Percentage_Rollout_Per_User;
var
  Filter: IFeatureFilter;
  CtxUser1, CtxUser2: TFeatureFilterEvaluationContext;
  Params: IDictionary<string, string>;
  Res1User1, Res2User1: Boolean;
begin
  Filter := TPercentageFilter.Create;
  Params := TCollections.CreateDictionary<string, string>;
  Params.AddOrSetValue('Value', '50');

  CtxUser1.FeatureName := 'NewCheckoutV2';
  CtxUser1.UserOrTenantKey := 'user-12345';
  CtxUser1.Parameters := Params;

  CtxUser2.FeatureName := 'NewCheckoutV2';
  CtxUser2.UserOrTenantKey := 'user-99999';
  CtxUser2.Parameters := Params;

  // Evaluation MUST be deterministic for the same User key
  Res1User1 := Filter.Evaluate(CtxUser1);
  Res2User1 := Filter.Evaluate(CtxUser1);
  Should(Res1User1).Be(Res2User1);
end;

procedure TDextFeatureFlagsTests.Test_TimeWindow_Filter_Evaluation;
var
  Filter: IFeatureFilter;
  Ctx: TFeatureFilterEvaluationContext;
  Params: IDictionary<string, string>;
begin
  Filter := TTimeWindowFilter.Create;
  Params := TCollections.CreateDictionary<string, string>;

  Ctx.FeatureName := 'BlackFridayDiscount';
  Ctx.Parameters := Params;

  Should(Filter.Evaluate(Ctx)).BeTrue;

  Params.AddOrSetValue('Start', '2099-01-01T00:00:00Z');
  Should(Filter.Evaluate(Ctx)).BeFalse;
end;

procedure TDextFeatureFlagsTests.Test_Custom_Feature_Filter_Registration;
var
  Config: IConfiguration;
  Mgr: TFeatureManager;
  CustomFilter: IFeatureFilter;
begin
  Config := TDextConfiguration.New
    .AddValues([
      TPair<string, string>.Create('FeatureManagement:RegionFeature:EnabledFor:0', 'CustomRegionFilter'),
      TPair<string, string>.Create('FeatureManagement:RegionFeature:EnabledFor:0:Parameters:AllowedRegion', 'BR')
    ])
    .Build;

  Mgr := TFeatureManager.Create(Config);
  try
    CustomFilter := TMockCustomFilter.Create;
    Mgr.RegisterFilter(CustomFilter);

    // Custom filter successfully registered and evaluated
    Should(Mgr.IsEnabled('RegionFeature', 'user-key')).BeTrue;
  finally
    Mgr.Free;
  end;
end;

type
  TUserContext = class
  private
    FUserId: string;
  public
    constructor Create(const AUserId: string);
    property UserId: string read FUserId write FUserId;
  end;

constructor TUserContext.Create(const AUserId: string);
begin
  inherited Create;
  FUserId := AUserId;
end;

procedure TDextFeatureFlagsTests.Test_IsEnabled_With_Context_Object_Extracts_UserId_Via_RTTI;
var
  Config: IConfiguration;
  Mgr: TFeatureManager;
  UserCtx: TUserContext;
  Res: Boolean;
begin
  Config := TDextConfiguration.New
    .AddValues([
      TPair<string, string>.Create('FeatureManagement:FeatureX:EnabledFor:0', 'Percentage'),
      TPair<string, string>.Create('FeatureManagement:FeatureX:EnabledFor:0:Parameters:Value', '100')
    ])
    .Build;

  Mgr := TFeatureManager.Create(Config);
  UserCtx := TUserContext.Create('usr_987654');
  try
    // Calling IsEnabled with TUserContext invokes RTTI extraction
    Res := Mgr.IsEnabled('FeatureX', UserCtx);
    Should(Res).BeTrue;
  finally
    UserCtx.Free;
    Mgr.Free;
  end;
end;

end.
