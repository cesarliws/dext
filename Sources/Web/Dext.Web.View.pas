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
{  Created: 2026-03-06                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.Web.View;

interface

{$TYPEINFO ON}

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Rtti,
  Dext.Collections.Base,
  Dext.Collections.Dict,
  Dext.Collections,
  Dext.Entity.Query,
  Dext.Web.Interfaces,
  Dext.DI.Interfaces;

type
  /// <summary>
  ///   Encapsulates data passed from the controller to the view.
  /// </summary>
  IViewData = interface
    ['{B9E2A1D4-5C3F-4B8E-9D1A-2F7E6B5D4C3A}']
    procedure SetValue(const AName: string; const AValue: TValue);
    function GetValue(const AName: string): TValue;
    procedure SetData(const AName: string; AData: TObject; AOwns: Boolean = False);
    function GetData(const AName: string): TObject;
    function GetValues: IDictionary<string, TValue>;
    function GetObjects: IDictionary<string, TObject>;
    property Values: IDictionary<string, TValue> read GetValues;
    property Objects: IDictionary<string, TObject> read GetObjects;
  end;

  /// <summary>
  ///   Base interface for all view engines (e.g. Web Stencils, Mustache, Native).
  /// </summary>
  {$M+}
  IViewEngine = interface(IInterface)
    ['{A1B2C3D4-E5F6-4789-0123-456789ABCDEF}']
    function Render(AContext: IHttpContext; const AViewName: string; AViewData: IViewData): string;
  end;

  /// <summary>
  ///   A result that renders a view using the registered IViewEngine.
  /// </summary>
  IViewResult = interface(IResult)
    ['{C3D4E5F6-A1B2-4789-0123-456789ABCDEF}']
    function WithValue(const AName: string; const AValue: TValue): IViewResult;
    function WithData(const AName: string; AData: TObject; AOwns: Boolean = False): IViewResult;
    function WithQuery(const AName: string; AQuery: TObject): IViewResult;
    function WithLayout(const ALayout: string): IViewResult;
    function Render(AContext: IHttpContext): string;
  end;

  /// <summary>
  ///   Fluid wrapper for IViewResult to support generic methods.
  /// </summary>
  TDextViewResult = record
  private
    FResult: IViewResult;
  public
    constructor Create(const AResult: IViewResult);
    class operator Implicit(const AResult: IViewResult): TDextViewResult;
    class operator Implicit(const AWrapper: TDextViewResult): IViewResult;

    function WithValue(const AName: string; const AValue: TValue): TDextViewResult;
    function WithData(const AName: string; AData: TObject; AOwns: Boolean = False): TDextViewResult;
    function WithQuery(const AName: string; AQuery: TObject): TDextViewResult; overload;
    function WithQuery<T: class>(const AName: string; const AQuery: TFluentQuery<T>): TDextViewResult; overload;
    function WithLayout(const ALayout: string): TDextViewResult;
  end;

  TViewData = class(TInterfacedObject, IViewData)
  private
    FValues: IDictionary<string, TValue>;
    FObjects: IDictionary<string, TObject>;
    FOwnedObjects: IList<TObject>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure SetValue(const AName: string; const AValue: TValue);
    function GetValue(const AName: string): TValue;
    procedure SetData(const AName: string; AData: TObject; AOwns: Boolean = False);
    function GetData(const AName: string): TObject;
    function GetValues: IDictionary<string, TValue>;
    function GetObjects: IDictionary<string, TObject>;
  end;

  TViewResult = class(TInterfacedObject, IViewResult, IResult)
  private
    FViewName: string;
    FViewData: IViewData;
  public
    constructor Create(const AViewName: string);
    function WithValue(const AName: string; const AValue: TValue): IViewResult;
    function WithData(const AName: string; AData: TObject; AOwns: Boolean = False): IViewResult;
    function WithQuery(const AName: string; AQuery: TObject): IViewResult;
    function WithLayout(const ALayout: string): IViewResult;
    function Render(AContext: IHttpContext): string;
    procedure Execute(AContext: IHttpContext);
  end;

  /// <summary>
  ///   Global configuration options for the view system.
  /// </summary>
  TViewOptions = class
  private
    FTemplateRoot: string;
    FAutoReload: Boolean;
    FDefaultLayout: string;
    FWhitelistedClasses: TArray<TClass>;
    FWhitelistEntities: Boolean;
  public
    constructor Create;
    property TemplateRoot: string read FTemplateRoot write FTemplateRoot;
    property AutoReload: Boolean read FAutoReload write FAutoReload;
    property DefaultLayout: string read FDefaultLayout write FDefaultLayout;
    property WhitelistedClasses: TArray<TClass> read FWhitelistedClasses write FWhitelistedClasses;
    property WhitelistEntities: Boolean read FWhitelistEntities write FWhitelistEntities;
  end;

  /// <summary>
  ///   Fluent builder for configuring template directories and security rules (Whitelist).
  /// </summary>
  TViewOptionsBuilder = record
  private
    FTemplateRoot: string;
    FAutoReload: Boolean;
    FDefaultLayout: string;
    FWhitelistedClasses: TArray<TClass>;
    FWhitelistEntities: Boolean;
  public
    class function Create: TViewOptionsBuilder; static;
    function TemplateRoot(const Value: string): TViewOptionsBuilder;
    function AutoReload(Value: Boolean = True): TViewOptionsBuilder;
    function DefaultLayout(const Value: string): TViewOptionsBuilder;
    function WhiteList(AClass: TClass): TViewOptionsBuilder; overload;
    function WhiteList(const AClasses: array of TClass): TViewOptionsBuilder; overload;
    function WhiteListEntities: TViewOptionsBuilder;

    class operator Implicit(const ABuilder: TViewOptionsBuilder): TViewOptions;
  end;

  /// <summary>
  ///   Factory function returning a fluent builder for TViewOptions.
  /// </summary>
  function ViewOptions: TViewOptionsBuilder;
type
  /// <summary>
  ///   Proxy for IEnumerator to make it compatible with RTTI-based engines like Web Stencils.
  /// </summary>
  TStreamingEnumeratorProxy<T: class> = class
  private
    FEnumerator: IEnumerator<T>;
    FNeedYieldFirst: Boolean;
    FFirstItemValid: Boolean;
  public
    constructor Create(AEnum: IEnumerator<T>; ANeedYieldFirst, AFirstItemValid: Boolean);
    destructor Destroy; override;
    function MoveNext: Boolean;
    function GetCurrent: T;
    property Current: T read GetCurrent;
  end;

  /// <summary>
  ///   Makes IEnumerator compatible with Web Stencils @For (GetEnumerator) and
  ///   native @foreach (IStreamingSequence). Both paths render during MoveNext
  ///   so the flyweight ORM iterator keeps O(1) memory.
  /// </summary>
  TStreamingListWrapper<T: class> = class(TInterfacedPersistent, IStreamingSequence)
  private
    FEnumerator: IEnumerator<T>;
    FIsEvaluated: Boolean;
    FIsEmpty: Boolean;
    FSeqStarted: Boolean;
    procedure EnsureEvaluated;
  public
    constructor Create(AEnum: IEnumerator<T>);
    destructor Destroy; override;
    function GetEnumerator: TStreamingEnumeratorProxy<T>;
    function GetIsEmpty: Boolean;
    function MoveNext: Boolean;
    function GetCurrent: TObject;
    property IsEmpty: Boolean read GetIsEmpty;
  end;

implementation

uses
  Dext.Collections.Comparers;

{ TViewData }

constructor TViewData.Create;
begin
  inherited Create;
  FValues := TCollections.CreateDictionaryIgnoreCase<string, TValue>;
  FObjects := TCollections.CreateDictionaryIgnoreCase<string, TObject>;
  FOwnedObjects := TCollections.CreateList<TObject>;
end;

destructor TViewData.Destroy;
var
  Obj: TObject;
  Owned: IList<TObject>;
begin
  // Capture the list and clear refs first to avoid zombie pointers in collections
  Owned := FOwnedObjects;
  FOwnedObjects := nil;
  FValues := nil;
  FObjects := nil;

  if Assigned(Owned) then
  begin
    for Obj in Owned do
      Obj.Free;
  end;
  inherited;
end;

function TViewData.GetData(const AName: string): TObject;
begin
  if not FObjects.TryGetValue(AName, Result) then
    Result := nil;
end;

function TViewData.GetObjects: IDictionary<string, TObject>;
begin
  Result := FObjects;
end;

function TViewData.GetValue(const AName: string): TValue;
begin
  if not FValues.TryGetValue(AName, Result) then
    Result := TValue.Empty;
end;

function TViewData.GetValues: IDictionary<string, TValue>;
begin
  Result := FValues;
end;

procedure TViewData.SetData(const AName: string; AData: TObject; AOwns: Boolean);
begin
  if Assigned(FObjects) then
    FObjects[AName] := AData;
    
  if AOwns and (AData <> nil) and Assigned(FOwnedObjects) then
  begin
    // Prevent double-ownership and subsequent double-free
    if not FOwnedObjects.Contains(AData) then
      FOwnedObjects.Add(AData);
  end;
end;

procedure TViewData.SetValue(const AName: string; const AValue: TValue);
begin
  if Assigned(FValues) then
    FValues[AName] := AValue;
end;

{ TViewResult }

constructor TViewResult.Create(const AViewName: string);
begin
  inherited Create;
  FViewName := AViewName;
  FViewData := TViewData.Create;
end;

procedure TViewResult.Execute(AContext: IHttpContext);
begin
  AContext.Response.ContentType := 'text/html; charset=utf-8';
  AContext.Response.Write(Self.Render(AContext));
end;

function TViewResult.Render(AContext: IHttpContext): string;
var
  EngineObj: IInterface;
  Engine: IViewEngine;
begin
  EngineObj := AContext.Services.GetServiceAsInterface(System.TypeInfo(IViewEngine));
  if (EngineObj = nil) or not Supports(EngineObj, IViewEngine, Engine) then
    raise Exception.Create('No IViewEngine registered in services. Use App.UseViewEngine.');

  // Auto-detect HTMX to suggest partial rendering if Layout wasn't explicitly set
  if not FViewData.Values.ContainsKey('Layout') then
  begin
    if AContext.Request.GetHeader('HX-Request') <> '' then
       FViewData.SetValue('Layout', '');
  end;

  Result := Engine.Render(AContext, FViewName, FViewData);
end;

function TViewResult.WithData(const AName: string; AData: TObject; AOwns: Boolean): IViewResult;
begin
  FViewData.SetData(AName, AData, AOwns);
  Result := Self;
end;

function TViewResult.WithQuery(const AName: string; AQuery: TObject): IViewResult;
begin
  FViewData.SetData(AName, AQuery, True);
  Result := Self;
end;

function TViewResult.WithLayout(const ALayout: string): IViewResult;
begin
  FViewData.SetValue('Layout', ALayout);
  Result := Self;
end;

function TViewResult.WithValue(const AName: string; const AValue: TValue): IViewResult;
begin
  FViewData.SetValue(AName, AValue);
  Result := Self;
end;

{ TViewOptions }

constructor TViewOptions.Create;
begin
  FTemplateRoot := TPath.GetFullPath('wwwroot/views');
  FAutoReload := True;
  FDefaultLayout := '_Layout.html';
  FWhitelistEntities := True;
end;

{ TViewOptionsBuilder }

class function TViewOptionsBuilder.Create: TViewOptionsBuilder;
begin
  Result.FTemplateRoot := '';
  Result.FAutoReload := True;
  Result.FDefaultLayout := '';
  Result.FWhitelistedClasses := [];
  Result.FWhitelistEntities := False;
end;

function TViewOptionsBuilder.TemplateRoot(const Value: string): TViewOptionsBuilder;
begin
  Result := Self;
  Result.FTemplateRoot := Value;
end;

function TViewOptionsBuilder.AutoReload(Value: Boolean): TViewOptionsBuilder;
begin
  Result := Self;
  Result.FAutoReload := Value;
end;

function TViewOptionsBuilder.DefaultLayout(const Value: string): TViewOptionsBuilder;
begin
  Result := Self;
  Result.FDefaultLayout := Value;
end;

function TViewOptionsBuilder.WhiteList(AClass: TClass): TViewOptionsBuilder;
var
  C: TClass;
begin
  Result := Self;
  for C in Result.FWhitelistedClasses do
    if C = AClass then Exit;
    
  Result.FWhitelistedClasses := Result.FWhitelistedClasses + [AClass];
end;

function TViewOptionsBuilder.WhiteList(const AClasses: array of TClass): TViewOptionsBuilder;
var
  C, Exists: TClass;
  AlreadyExists: Boolean;
begin
  Result := Self;
  for C in AClasses do
  begin
    AlreadyExists := False;
    for Exists in Result.FWhitelistedClasses do
      if Exists = C then
      begin
        AlreadyExists := True;
        Break;
      end;
      
    if not AlreadyExists then
      Result.FWhitelistedClasses := Result.FWhitelistedClasses + [C];
  end;
end;

function TViewOptionsBuilder.WhiteListEntities: TViewOptionsBuilder;
begin
  Result := Self;
  Result.FWhitelistEntities := True;
end;

class operator TViewOptionsBuilder.Implicit(const ABuilder: TViewOptionsBuilder): TViewOptions;
begin
  Result := TViewOptions.Create;
  if ABuilder.FTemplateRoot <> '' then
    Result.TemplateRoot := ABuilder.FTemplateRoot;
  Result.AutoReload := ABuilder.FAutoReload;
  if ABuilder.FDefaultLayout <> '' then
    Result.DefaultLayout := ABuilder.FDefaultLayout;
  Result.WhitelistedClasses := ABuilder.FWhitelistedClasses;
  Result.WhitelistEntities := ABuilder.FWhitelistEntities;
end;

function ViewOptions: TViewOptionsBuilder;
begin
  Result := TViewOptionsBuilder.Create;
end;

{ TStreamingEnumeratorProxy<T> }

constructor TStreamingEnumeratorProxy<T>.Create(AEnum: IEnumerator<T>; ANeedYieldFirst, AFirstItemValid: Boolean);
begin
  inherited Create;
  FEnumerator := AEnum;
  FNeedYieldFirst := ANeedYieldFirst;
  FFirstItemValid := AFirstItemValid;
end;

destructor TStreamingEnumeratorProxy<T>.Destroy;
begin
  FEnumerator := nil;
  inherited;
end;

function TStreamingEnumeratorProxy<T>.GetCurrent: T;
begin
  Result := FEnumerator.GetCurrent;
end;

function TStreamingEnumeratorProxy<T>.MoveNext: Boolean;
begin
  if FNeedYieldFirst then
  begin
    FNeedYieldFirst := False;
    Result := FFirstItemValid;
  end
  else
    Result := FEnumerator.MoveNext;
end;

{ TStreamingListWrapper<T> }

constructor TStreamingListWrapper<T>.Create(AEnum: IEnumerator<T>);
begin
  inherited Create;
  FEnumerator := AEnum;
  FIsEvaluated := False;
end;

destructor TStreamingListWrapper<T>.Destroy;
var
  Enum: IInterface;
begin
  if Assigned(FEnumerator) then
  begin
    Enum := FEnumerator;
    FEnumerator := nil;
    Enum := nil;
  end;
  inherited;
end;

procedure TStreamingListWrapper<T>.EnsureEvaluated;
begin
  if not FIsEvaluated then
  begin
    FIsEvaluated := True;
    if Assigned(FEnumerator) then
      FIsEmpty := not FEnumerator.MoveNext
    else
      FIsEmpty := True;
  end;
end;

function TStreamingListWrapper<T>.GetEnumerator: TStreamingEnumeratorProxy<T>;
begin
  EnsureEvaluated;
  Result := TStreamingEnumeratorProxy<T>.Create(FEnumerator, True, not FIsEmpty);
end;

function TStreamingListWrapper<T>.GetIsEmpty: Boolean;
begin
  EnsureEvaluated;
  Result := FIsEmpty;
end;

function TStreamingListWrapper<T>.MoveNext: Boolean;
begin
  EnsureEvaluated;
  if not FSeqStarted then
  begin
    FSeqStarted := True;
    Result := not FIsEmpty;
  end
  else if Assigned(FEnumerator) then
    Result := FEnumerator.MoveNext
  else
    Result := False;
end;

function TStreamingListWrapper<T>.GetCurrent: TObject;
begin
  Result := TValue.From<T>(FEnumerator.GetCurrent).AsObject;
end;

{ TDextViewResult }

constructor TDextViewResult.Create(const AResult: IViewResult);
begin
  FResult := AResult;
end;

class operator TDextViewResult.Implicit(const AResult: IViewResult): TDextViewResult;
begin
  Result := TDextViewResult.Create(AResult);
end;

class operator TDextViewResult.Implicit(const AWrapper: TDextViewResult): IViewResult;
begin
  Result := AWrapper.FResult;
end;

function TDextViewResult.WithData(const AName: string; AData: TObject; AOwns: Boolean): TDextViewResult;
begin
  if Assigned(FResult) then
    FResult.WithData(AName, AData, AOwns);
  Result := Self;
end;

function TDextViewResult.WithQuery(const AName: string; AQuery: TObject): TDextViewResult;
begin
  if Assigned(FResult) then
    FResult.WithQuery(AName, AQuery);
  Result := Self;
end;

function TDextViewResult.WithLayout(const ALayout: string): TDextViewResult;
begin
  if Assigned(FResult) then
    FResult.WithLayout(ALayout);
  Result := Self;
end;

function TDextViewResult.WithQuery<T>(const AName: string; const AQuery: TFluentQuery<T>): TDextViewResult;
begin
  if Assigned(FResult) then
    FResult.WithQuery(AName, TStreamingListWrapper<T>.Create(AQuery.GetStreamingEnumerator));
  Result := Self;
end;

function TDextViewResult.WithValue(const AName: string; const AValue: TValue): TDextViewResult;
begin
  if Assigned(FResult) then
    FResult.WithValue(AName, AValue);
  Result := Self;
end;

end.
