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
unit Dext.Configuration.Binder;

interface

uses
  System.SysUtils,
  System.Rtti,
  System.TypInfo,
  Dext.Configuration.Interfaces,
  Dext.Configuration.Core;

type
  TConfigurationBinder = class
  private
    class procedure BindInternal(Configuration: IConfiguration; Instance: TObject; RttiType: TRttiType);
    class function GetValue(Configuration: IConfiguration; RttiType: TRttiType; const Key: string): TValue;
  public
    class function Bind<T: class, constructor>(Configuration: IConfiguration): T; overload;
    class procedure Bind(Configuration: IConfiguration; Instance: TObject); overload;
    class function Get<T>(Configuration: IConfiguration): T; overload;
  end;

implementation

{ TConfigurationBinder }

class function TConfigurationBinder.Bind<T>(Configuration: IConfiguration): T;
begin
  Result := T.Create;
  try
    Bind(Configuration, Result);
  except
    Result.Free;
    raise;
  end;
end;

class function TConfigurationBinder.Get<T>(Configuration: IConfiguration): T;
var
  Val: TValue;
  Ctx: TRttiContext;
begin
  Ctx := TRttiContext.Create;
  Val := GetValue(Configuration, Ctx.GetType(TypeInfo(T)), '');
  Result := Val.AsType<T>;
end;

class procedure TConfigurationBinder.Bind(Configuration: IConfiguration; Instance: TObject);
var
  Ctx: TRttiContext;
  RttiType: TRttiType;
begin
  if Instance = nil then
    Exit;
    
  Ctx := TRttiContext.Create;
  RttiType := Ctx.GetType(Instance.ClassType);
  BindInternal(Configuration, Instance, RttiType);
end;

class procedure TConfigurationBinder.BindInternal(Configuration: IConfiguration; Instance: TObject; RttiType: TRttiType);
var
  Prop: TRttiProperty;
  Section: IConfigurationSection;
  Val: TValue;
begin
  for Prop in RttiType.GetProperties do
  begin
    if not Prop.IsWritable then
      Continue;
      
    // Check if configuration has this key
    // For simple properties, look for value.
    // For complex objects, look for section.
    
    Section := Configuration.GetSection(Prop.Name);
    
    if (Section.Value <> '') or (Length(Section.GetChildren) > 0) then
    begin
      Val := GetValue(Section, Prop.PropertyType, '');
      if not Val.IsEmpty then
        Prop.SetValue(Instance, Val);
    end;
  end;
end;

class function TConfigurationBinder.GetValue(Configuration: IConfiguration; RttiType: TRttiType; const Key: string): TValue;
var
  StrVal: string;
  Config: IConfiguration;
  ConfigSection: IConfigurationSection;
begin
  Result := TValue.Empty;

  if Key <> '' then
    Config := Configuration.GetSection(Key)
  else
    Config := Configuration;

  // Get raw string value if it's a section
  if Supports(Config, IConfigurationSection, ConfigSection) then
    StrVal := ConfigSection.Value
  else
    StrVal := '';
    
  case RttiType.TypeKind of
    tkInteger:
      if StrVal <> '' then
        Result := StrToIntDef(StrVal, 0);
      
    tkInt64:
      if StrVal <> '' then
        Result := StrToInt64Def(StrVal, 0);
      
    tkFloat:
      if StrVal <> '' then
      begin
        var FS := TFormatSettings.Invariant;
        Result := StrToFloatDef(StrVal, 0, FS);
      end;
      
    tkString, tkLString, tkWString, tkUString:
      if StrVal <> '' then
        Result := StrVal;
      
    tkEnumeration:
      if StrVal <> '' then
      begin
        if RttiType.Handle = TypeInfo(Boolean) then
          Result := StrToBoolDef(StrVal, False)
        else
        begin
          try
            Result := TValue.FromOrdinal(RttiType.Handle, GetEnumValue(RttiType.Handle, StrVal));
          except
            // Ignore invalid enum values
          end;
        end;
      end;
      
    tkClass:
      begin
        if RttiType.AsInstance.MetaclassType <> nil then
        begin
          var Instance := RttiType.AsInstance.MetaclassType.Create;
          BindInternal(Config, Instance, RttiType);
          Result := Instance;
        end;
      end;
  end;
end;

end.

