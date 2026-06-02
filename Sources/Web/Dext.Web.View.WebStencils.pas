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
unit Dext.Web.View.WebStencils;

interface

{$I Dext.inc}

uses
  System.Classes,
  System.Rtti,
  System.SyncObjs,
  System.SysUtils,
  System.Variants,
  {$IFDEF DEXT_ENABLE_WEB_STENCILS}
  System.Bindings.EvalProtocol,
  Web.Stencils,
  {$ENDIF}
  Dext.Collections.Dict,
  Dext.Core.SmartTypes,
  Dext.Threading.Sync,
  Dext.Types.Nullable,
  Dext.Web.Interfaces,
  Dext.Web.View;

type
  {$IFDEF DEXT_ENABLE_WEB_STENCILS}
  /// <summary>
  ///   View Engine based on Embarcadero's WebStencils (Delphi 12.2+).
  ///   Provides deep integration with the Dext ecosystem (Entities, SmartProps).
  /// </summary>
  TWebStencilsViewEngine = class(TInterfacedObject, IViewEngine)
  private
    FEngine: TWebStencilsEngine;
    FOptions: TViewOptions;
  public
    class procedure RegisterWebStencilsFunctions;
    class procedure ApplyWhitelist(AOptions: TViewOptions);
    constructor Create(AOptions: TViewOptions);
    destructor Destroy; override;
    function Render(AContext: IHttpContext; const AViewName: string; AViewData: IViewData): string;
  end;

  /// <summary>
  ///   Render context that maps the <see cref="IViewData"/> to WebStencils variables.
  /// </summary>
  TWebStencilsRenderContext = class
  private
    FViewData: IViewData;
    {$IF CompilerVersion >= 37.0}
    function HandleLookup(AVar: TWebStencilsDataVar; const APropName: string; var AValue: string): Boolean;
    {$ENDIF}
    function ResolveValue(AObj: TObject; const APropName: string): TValue;
  public
    constructor Create(AData: IViewData);
    procedure SetupProcessor(AProcessor: TWebStencilsProcessor);
    procedure OnValue(Sender: TObject; const AObjectName, APropName: string;
      var AValue: string; var AHandled: Boolean);
  end;
  {$ELSE}
  TWebStencilsViewEngine = class(TInterfacedObject, IViewEngine)
  public
    class procedure ApplyWhitelist(AOptions: TViewOptions);
    function Render(AContext: IHttpContext; const AViewName: string; AViewData: IViewData): string;
  end;
  {$ENDIF}

implementation

{$IFDEF DEXT_ENABLE_WEB_STENCILS}
uses
  {$IFDEF MSWINDOWS}Winapi.Windows,{$ENDIF}
  System.IOUtils,
  System.Bindings.Methods,
  Dext.Core.Reflection,
  Dext.Entity.Core,
  Dext.Entity.Mapping,
  Dext.Entity.Context;

{ TWebStencilsViewEngine }

class procedure TWebStencilsViewEngine.RegisterWebStencilsFunctions;
begin
  TBindingMethodsFactory.RegisterMethod(
    TMethodDescription.Create(
      MakeInvokable(function(Args: TArray<IValue>): IValue
      var
        Value, Unwrapped: TValue;
      begin
        try
          if Length(Args) <> 1 then
            raise Exception.Create('Expected 1 parameter for @(Prop(Value))');
            
          Value := Args[0].GetValue;
          if Value.IsEmpty then
          begin
            Result := TValueWrapper.Create('');
            Exit;
          end;

          if TReflection.TryUnwrapProp(Value, Unwrapped) then
            Result := TValueWrapper.Create(Unwrapped.ToString)
          else
            Result := TValueWrapper.Create(Value.ToString);
        except
          on E: Exception do
            Result := TValueWrapper.Create('Err: ' + E.Message);
        end;
      end),
      'Prop', 'Prop', '', True, 'Extracts the underlying value of a Dext SmartProp type', nil));
end;

class procedure TWebStencilsViewEngine.ApplyWhitelist(AOptions: TViewOptions);
{$IF CompilerVersion >= 37.0}
var
  C: TClass;
  Map: TEntityMap;
  RType: TRttiType;
  Builder: TModelBuilder;
begin
  if not Assigned(AOptions) then Exit;
  
  if Length(AOptions.WhitelistedClasses) > 0 then
  begin
    for C in AOptions.WhitelistedClasses do
      TWebStencilsProcessor.Whitelist.Configure(C, [], [], False);
  end;

  if AOptions.WhitelistEntities then
  begin
    // 1. Whitelist from Global ModelBuilder Instance
    for Map in TModelBuilder.Instance.GetMaps do
    begin
      if Map.EntityType <> nil then
      begin
        RType := TReflection.Context.GetType(Map.EntityType);
        if (RType <> nil) and (RType.IsInstance) then
          TWebStencilsProcessor.Whitelist.Configure(RType.AsInstance.MetaclassType, [], [], False);
      end;
    end;

    // 2. Whitelist from each registered TDbContext's ModelBuilder
    TDbContext.FModelLock.BeginRead;
    try
      if Assigned(TDbContext.FModelCache) then
      begin
        for Builder in TDbContext.FModelCache.Values do
        begin
          for Map in Builder.GetMaps do
          begin
            if Map.EntityType <> nil then
            begin
              RType := TReflection.Context.GetType(Map.EntityType);
              if (RType <> nil) and (RType.IsInstance) then
                TWebStencilsProcessor.Whitelist.Configure(RType.AsInstance.MetaclassType, [], [], False);
            end;
          end;
        end;
      end;
    finally
      TDbContext.FModelLock.EndRead;
    end;
  end;
end;
{$ELSE}
begin
  // Whitelist feature only available in Delphi 13 (Athens) / CompilerVersion 37.0+
end;
{$IFEND}

constructor TWebStencilsViewEngine.Create(AOptions: TViewOptions);
begin
  inherited Create;
  FOptions := AOptions;
  ApplyWhitelist(FOptions);
  FEngine := TWebStencilsEngine.Create(nil);
  FEngine.RootDirectory := FOptions.TemplateRoot;
end;

destructor TWebStencilsViewEngine.Destroy;
begin
  FEngine.Free;
  FOptions.Free;
  inherited;
end;

function TWebStencilsViewEngine.Render(AContext: IHttpContext; const AViewName: string; AViewData: IViewData): string;
var
  Processor: TWebStencilsProcessor;
  ViewPath: string;
  RenderCtx: TWebStencilsRenderContext;
begin
  ViewPath := TPath.Combine(FOptions.TemplateRoot, AViewName);
  if not ViewPath.EndsWith('.html', True) then
    ViewPath := ViewPath + '.html';

  if not TFile.Exists(ViewPath) then
    raise EFileNotFoundException.CreateFmt('View template not found: %s', [ViewPath]);

  Processor := TWebStencilsProcessor.Create(nil);
  RenderCtx := TWebStencilsRenderContext.Create(AViewData);
  try
    Processor.Engine := FEngine;
    // OnValue event is our fallback for unknown variables or loops
    Processor.OnValue := RenderCtx.OnValue;
    
    // Configure initial variables with LookupHandler to intercept properties
    RenderCtx.SetupProcessor(Processor);
    
    Processor.InputFileName := ViewPath;
    Result := Processor.Content;
  finally
    Processor.Free;
    RenderCtx.Free;
  end;
end;

{ TWebStencilsRenderContext }

constructor TWebStencilsRenderContext.Create(AData: IViewData);
begin
  inherited Create;
  FViewData := AData;
end;

procedure TWebStencilsRenderContext.SetupProcessor(AProcessor: TWebStencilsProcessor);
var
  ObjPair: Dext.Collections.Dict.TPair<string, TObject>;
begin
  for ObjPair in FViewData.Objects do
  begin
    if ObjPair.Value <> nil then
    begin
       {$IF CompilerVersion >= 37.0}
       AProcessor.AddVar(ObjPair.Key, ObjPair.Value, False, HandleLookup);
       {$ELSE}
       AProcessor.AddVar(ObjPair.Key, ObjPair.Value, False);
       {$IFEND}
    end;
  end;
end;

function TWebStencilsRenderContext.ResolveValue(AObj: TObject; const APropName: string): TValue;
begin
  Result := TReflection.GetValue(AObj, APropName);
end;

{$IF CompilerVersion >= 37.0}
function TWebStencilsRenderContext.HandleLookup(AVar: TWebStencilsDataVar; const APropName: string; var AValue: string): Boolean;
var
  Value, Unwrapped: TValue;
begin
  Result := False;
  if (AVar = nil) or (AVar.TheObject = nil) then Exit;

  Value := ResolveValue(AVar.TheObject, APropName);

  if not Value.IsEmpty then
  begin
    if TReflection.TryUnwrapProp(Value, Unwrapped) then
    begin
      Value := Unwrapped;
    end;

    AValue := Value.ToString;
    Result := True;
  end;
end;
{$ENDIF}

procedure TWebStencilsRenderContext.OnValue(Sender: TObject; const AObjectName, APropName: string;
  var AValue: string; var AHandled: Boolean);
var
  Value, Unwrapped: TValue;
  Obj: TObject;
begin
  if AHandled then Exit;

  Obj := nil;

  // 1. Try to find the object in ViewData
  if AObjectName <> '' then
  begin
    Obj := FViewData.GetData(AObjectName);
  end;

  // 2. Fallback for global fields or Model
  if (Obj = nil) and ((AObjectName = '') or SameText(AObjectName, 'Model')) then
  begin
    Value := FViewData.GetValue(APropName);
    if Value.IsEmpty then
      Obj := FViewData.GetData('Model')
    else
    begin
      // Scalar registered via WithValue: emit directly (nexo1 customization)
      if TReflection.TryUnwrapProp(Value, Unwrapped) then
        Value := Unwrapped;
      AValue := Value.ToString;
      AHandled := True;
      Exit;
    end;
  end;

  // 2b. Scalar via @varName: RTL passes AObjectName=<var>, APropName='' for a
  //     bare @identifier (no dot). Resolve from ViewData.Values -- completes
  //     e6dfb75a9, which only covered the ''/'Model' object path. nexo1 custom.
  if (not AHandled) and (Obj = nil) and (APropName = '') and (AObjectName <> '')
    and not SameText(AObjectName, 'Model') then
  begin
    Value := FViewData.GetValue(AObjectName);
    if not Value.IsEmpty then
    begin
      if TReflection.TryUnwrapProp(Value, Unwrapped) then
        Value := Unwrapped;
      AValue := Value.ToString;
      AHandled := True;
      Exit;
    end;
  end;

  // 3. If we have the object, resolve and unwrap SmartProps
  if Obj <> nil then
  begin
    Value := ResolveValue(Obj, APropName);
    if not Value.IsEmpty then
    begin
       if TReflection.TryUnwrapProp(Value, Unwrapped) then
         Value := Unwrapped;

       AValue := Value.ToString;
       AHandled := True;
    end;
  end;
end;

{$ELSE}
class procedure TWebStencilsViewEngine.ApplyWhitelist(AOptions: TViewOptions);
begin
  // Do nothing
end;

function TWebStencilsViewEngine.Render(AContext: IHttpContext; const AViewName: string; AViewData: IViewData): string;
begin
  raise Exception.Create('Web Stencils requires Delphi 12.2 or higher.');
end;
{$ENDIF}

end.
