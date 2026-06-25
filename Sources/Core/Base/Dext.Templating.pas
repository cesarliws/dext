// ***************************************************************************
//
//           Dext Framework
//
//           Copyright (C) 2025 Cesar Romero & Dext Contributors
//
//           Licensed under the Apache License, Version 2.0 (the "License");
//           you may not use this file except in compliance with the License.
//           You may obtain a copy of the License at
//
//               http://www.apache.org/licenses/LICENSE-2.0
//
//           Unless required by applicable law or agreed to in writing,
//           software distributed under the License is distributed on an
//           "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//           either express or implied. See the License for the specific
//           language governing permissions and limitations under the
//           License.
//
// ***************************************************************************
//
//  Author:  Cesar Romero
//  Created: 2026-04-10
//
//  Dext.Templating - Generic Template Engine Contracts & Implementation
//
// ***************************************************************************

unit Dext.Templating;

interface

uses
  System.Classes,
  System.DateUtils,
  System.Math,
  System.NetEncoding,
  System.Rtti,
  System.StrUtils,
  System.SysUtils,
  System.TypInfo,
  System.Character,
  System.IOUtils,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.Text.Escaping;

type
  TDextTemplateEngine = class;

  /// <summary>
  ///   Defines the execution context for a template, managing variables, objects, and nested scopes.
  /// </summary>
  ITemplateContext = interface
    ['{1A2B3C4D-5E6F-7A8B-9C0D-1E2F3A4B5C6D}']
    procedure SetValue(const AKey: string; const AValue: string);
    function GetValue(const AKey: string): string;
    function TryGetValue(const AKey: string; out AValue: string): Boolean;
    function HasValue(const AKey: string): Boolean;

    procedure SetObject(const AKey: string; AObject: TObject);
    function GetObject(const AKey: string): TObject;

    procedure SetList(const AKey: string; const AItems: TArray<TObject>);
    function GetList(const AKey: string): TArray<TObject>;

    function CreateChildScope: ITemplateContext;
  end;

  TSourcePos = record
    Col: Integer;
    Line: Integer;
    Filename: string;
    constructor Create(ALine, ACol: Integer; const AFilename: string = '');
    function ToString: string;
  end;

  ETemplateException = class(Exception)
  private
    FPos: TSourcePos;
    FTemplateSnippet: string;
  public
    constructor Create(const AMessage: string; const APos: TSourcePos; const ASnippet: string = '');
    property Pos: TSourcePos read FPos;
    property TemplateSnippet: string read FTemplateSnippet;
  end;

  /// <summary>
  ///   Interface for loading template content from a source (e.g., file system, memory).
  /// </summary>
  ITemplateLoader = interface
    ['{5C6D7E8F-9A0B-1C2D-3E4F-5A6B7C8D9E0F}']
    function Load(const ATemplateName: string): string;
  end;

  /// <summary>
  ///   Core interface for the Dext templating engine.
  /// </summary>
  ITemplateEngine = interface
    ['{2B3C4D5E-6F7A-8B9C-0D1E-2F3A4B5C6D7E}']
    function GetIsHtmlMode: Boolean;
    function GetTemplateLoader: ITemplateLoader;
    function Render(const ATemplate: string; const AContext: ITemplateContext): string;
    function RenderTemplate(const ATemplateName: string; const AContext: ITemplateContext): string;

    procedure SetIsHtmlMode(AValue: Boolean);
    procedure SetTemplateLoader(const ALoader: ITemplateLoader);

    property IsHtmlMode: Boolean read GetIsHtmlMode write SetIsHtmlMode;
    property TemplateLoader: ITemplateLoader read GetTemplateLoader write SetTemplateLoader;
  end;

  /// <summary>
  ///   Registry for custom filters that can be applied within templates.
  /// </summary>
  ITemplateFilterRegistry = interface
    ['{6D7E8F9A-0B1C-2D3E-4F5A-6B7C8D9E0F1A}']
    procedure RegisterFilter(const AName: string; const AFilter: System.SysUtils.TFunc<string, string>);
    function ApplyFilter(const AName: string; const AValue: string): string;
  end;

  TTemplateContext = class(TInterfacedObject, ITemplateContext)
  private
    FLists: IDictionary<string, TArray<TObject>>;
    FObjects: IDictionary<string, TObject>;
    FParent: ITemplateContext;
    FValues: IDictionary<string, string>;
  public
    constructor Create; overload;
    constructor Create(const AParent: ITemplateContext); overload;
    destructor Destroy; override;

    procedure SetValue(const AKey: string; const AValue: string);
    function GetValue(const AKey: string): string;
    function TryGetValue(const AKey: string; out AValue: string): Boolean;
    function HasValue(const AKey: string): Boolean;

    procedure SetObject(const AKey: string; AObject: TObject);
    function GetObject(const AKey: string): TObject;

    procedure SetList(const AKey: string; const AItems: TArray<TObject>);
    function GetList(const AKey: string): TArray<TObject>;

    function CreateChildScope: ITemplateContext;
  end;

  TTemplateNode = class
  protected
    FEngine: TDextTemplateEngine;
    FPos: TSourcePos;
  public
    constructor Create(AEngine: TDextTemplateEngine); virtual;
    constructor CreateAt(AEngine: TDextTemplateEngine; const APos: TSourcePos); virtual;
    function Render(const AContext: ITemplateContext): string; virtual; abstract;
    property Pos: TSourcePos read FPos;
  end;

  TTextNode = class(TTemplateNode)
  private
    FText: string;
  public
    constructor Create(AEngine: TDextTemplateEngine; const AText: string); reintroduce;
    constructor CreateAt(AEngine: TDextTemplateEngine; const APos: TSourcePos; const AText: string); reintroduce;
    function Render(const AContext: ITemplateContext): string; override;
  end;

  TExpressionNode = class(TTemplateNode)
  private
    FExpression: string;
    FIsRaw: Boolean;
  public
    constructor Create(AEngine: TDextTemplateEngine; const AExpression: string; AIsRaw: Boolean); reintroduce;
    constructor CreateAt(AEngine: TDextTemplateEngine; const APos: TSourcePos; const AExpression: string; AIsRaw: Boolean); reintroduce;
    function Render(const AContext: ITemplateContext): string; override;
  end;

  TConditionalNode = class(TTemplateNode)
  private
    FCondition: string;
    FTrueNodes: IList<TTemplateNode>;
    FFalseNodes: IList<TTemplateNode>;
  public
    constructor Create(AEngine: TDextTemplateEngine; const ACondition: string); reintroduce;
    constructor CreateAt(AEngine: TDextTemplateEngine; const APos: TSourcePos; const ACondition: string); reintroduce;
    destructor Destroy; override;
    function Render(const AContext: ITemplateContext): string; override;
    property TrueNodes: IList<TTemplateNode> read FTrueNodes;
    property FalseNodes: IList<TTemplateNode> read FFalseNodes;
  end;

  TLoopNode = class(TTemplateNode)
  private
    FElseNodes: IList<TTemplateNode>;
    FItemName: string;
    FListExpr: string;
    FNodes: IList<TTemplateNode>;
  public
    constructor Create(AEngine: TDextTemplateEngine; const AItemName, AListExpr: string); reintroduce;
    constructor CreateAt(AEngine: TDextTemplateEngine; const APos: TSourcePos; const AItemName, AListExpr: string); reintroduce;
    destructor Destroy; override;
    function Render(const AContext: ITemplateContext): string; override;

    property ElseNodes: IList<TTemplateNode> read FElseNodes;
    property Nodes: IList<TTemplateNode> read FNodes;
  end;

  TTemplateNodeList = IList<TTemplateNode>;

  TFileSystemTemplateLoader = class(TInterfacedObject, ITemplateLoader)
  private
    FRoot: string;
  public
    constructor Create(const ARoot: string);
    function Load(const ATemplateName: string): string;
    property Root: string read FRoot;
  end;

  TInMemoryTemplateLoader = class(TInterfacedObject, ITemplateLoader)
  private
    FTemplates: IDictionary<string, string>;
  public
    constructor Create;
    procedure AddTemplate(const AName, AContent: string);
    function Load(const ATemplateName: string): string;
  end;

  /// <summary>
  ///   Factory record for creating standard template contexts and engines.
  /// </summary>
  TTemplating = record
  public
    class function CreateContext: ITemplateContext; static;
    class function CreateEngine: ITemplateEngine; static;
  end;

  TTemplateFilterFunc = reference to function(const AValue: TValue; const AArgs: TArray<TValue>): TValue;

  TDextTemplateEngine = class(TInterfacedObject, ITemplateEngine, ITemplateFilterRegistry)
  private type
    TTemplateArgument = record
      Expression: string;
      Name: string;
    end;

    TInlineTemplateDefinition = class
    public
      Content: string;
      Name: string;
      Parameters: TArray<string>;
    end;

    TTemplateDocument = class
    public
      BodyText: string;
      Definitions: IDictionary<string, TInlineTemplateDefinition>;
      LayoutName: string;
      Sections: IDictionary<string, TStringBuilder>;
      constructor Create;
      destructor Destroy; override;
    end;

    TRenderState = class
    public
      BodyContent: string;
      Definitions: IDictionary<string, TInlineTemplateDefinition>;
      Sections: IDictionary<string, string>;
      TemplateName: string;
      constructor Create;
      destructor Destroy; override;
    end;
  private
    FAdvancedFilters: IDictionary<string, TTemplateFilterFunc>;
    FCurrentState: TRenderState;
    FFilters: IDictionary<string, System.SysUtils.TFunc<string, string>>;
    FIsHtmlMode: Boolean;
    FTemplateAstCache: IDictionary<string, TTemplateNodeList>;
    FTemplateLoader: ITemplateLoader;
    FTemplateRoot: string;

    function GetTemplateLoader: ITemplateLoader;
    procedure SetTemplateLoader(const ALoader: ITemplateLoader);
    function GetIsHtmlMode: Boolean;
    procedure SetIsHtmlMode(AValue: Boolean);

    function Parse(const ATemplate: string): TTemplateNodeList;
    function GetOrParseTemplate(const ATemplate: string): TTemplateNodeList;
    function ParseDocument(const ATemplate: string): TTemplateDocument;
    function RenderNodes(ANodes: TTemplateNodeList; const AContext: ITemplateContext): string;
    function RenderInlineTemplate(const ATemplate: string; const AContext: ITemplateContext): string;
    function RenderTemplateInternal(const ATemplateName: string; const AContext: ITemplateContext): string;
    function RenderResolvedTemplate(const ATemplateName, AResolvedName: string; const AContext: ITemplateContext): string;
    function ResolveTemplateName(const ACurrentTemplate, ARequestedName: string): string;
    function MergeSectionContent(const AChildContent, AParentContent: string): string;
    function ResolveNodeOutput(ANode: TTemplateNode; const AContext: ITemplateContext): string;

    function GetTemplateSnippet(const ATemplate: string; APos: Integer): string;
    function ResolveValue(const AExpr: string; const AContext: ITemplateContext; out AIsRaw, AIsEncoded: Boolean): TValue;
    function ResolveRootValue(const ARoot: string; const AContext: ITemplateContext): TValue;
    function ResolvePathValue(const APath: string; const AContext: ITemplateContext): TValue;
    function ResolveMemberValue(const AValue: TValue; const APath: string; const AContext: ITemplateContext): TValue;
    function EvaluateInlineExpression(const AExpr: string; const AContext: ITemplateContext): TValue;
    function ExecuteInlineFunction(const AName: string; const AArgs: TArray<TValue>; const AContext: ITemplateContext): TValue;
    function HasTopLevelOperator(const AExpr: string): Boolean;
    function ApplyAdvancedFilter(const AName: string; const AValue: TValue; const AArgs: TArray<TValue>): TValue;
    function ParseFilterArguments(const AText: string; const AContext: ITemplateContext): TArray<TValue>;
    function ParseNamedArguments(const AText: string): TArray<TTemplateArgument>;
    function ExtractCallArguments(const AText: string; out AName: string): string;
    function SplitTopLevel(const AText: string; ASeparator: Char): TArray<string>;
    function UnquoteString(const AText: string): string;
    function ValueToString(const AValue: TValue): string;
    function ValueToBoolean(const AValue: TValue): Boolean;
    function GetSectionValue(const AName: string; ARequired: Boolean): string;
    function GetDefinition(const AName: string): TInlineTemplateDefinition;
    function RenderPartial(const ATemplateName: string; const AArgsText: string; const AContext: ITemplateContext): string;
    function RenderMacroCall(const AName: string; const AArgsText: string; const AContext: ITemplateContext): string;

    function ReadBalanced(const AText: string; var APos: Integer; AOpen, AClose: Char): string;
    procedure SkipWhitespace(const AText: string; var APos: Integer);
    procedure SkipLineBreak(const AText: string; var APos: Integer);
    function CaptureUntil(const AText: string; var APos: Integer; const AEndMarker: string): string;
  public
    constructor Create; overload;
    constructor Create(const ALoader: ITemplateLoader); overload;
    destructor Destroy; override;

    function Render(const ATemplate: string; const AContext: ITemplateContext): string;
    function RenderTemplate(const ATemplateName: string; const AContext: ITemplateContext): string;

    procedure RegisterFilter(const AName: string; const AFilter: System.SysUtils.TFunc<string, string>);
    function ApplyFilter(const AName: string; const AValue: string): string;
    procedure RegisterAdvancedFilter(const AName: string; const AFilter: TTemplateFilterFunc);

    property IsHtmlMode: Boolean read FIsHtmlMode write FIsHtmlMode;
    property TemplateLoader: ITemplateLoader read GetTemplateLoader write SetTemplateLoader;
    property TemplateRoot: string read FTemplateRoot write FTemplateRoot;
  end;

implementation

uses
  Data.DB,
  Dext.Core.Reflection,
  Dext.Json;

type
  ETemplateLoopContinue = class(Exception);
  ETemplateLoopBreak = class(Exception);

  TSetNode = class(TTemplateNode)
  private
    FName: string;
    FExpression: string;
  public
    constructor Create(AEngine: TDextTemplateEngine; const AName, AExpression: string); reintroduce;
    constructor CreateAt(AEngine: TDextTemplateEngine; const APos: TSourcePos; const AName, AExpression: string); reintroduce;
    function Render(const AContext: ITemplateContext): string; override;
  end;

  TContinueNode = class(TTemplateNode)
  public
    constructor Create(AEngine: TDextTemplateEngine); reintroduce;
    constructor CreateAt(AEngine: TDextTemplateEngine; const APos: TSourcePos); reintroduce;
    function Render(const AContext: ITemplateContext): string; override;
  end;

  TBreakNode = class(TTemplateNode)
  public
    constructor Create(AEngine: TDextTemplateEngine); reintroduce;
    constructor CreateAt(AEngine: TDextTemplateEngine; const APos: TSourcePos); reintroduce;
    function Render(const AContext: ITemplateContext): string; override;
  end;

  TSwitchCase = class
  public
    Expression: string;
    Nodes: IList<TTemplateNode>;
    constructor Create(const AExpression: string);
    destructor Destroy; override;
  end;

  TSwitchNode = class(TTemplateNode)
  private
    FExpression: string;
    FCases: IList<TSwitchCase>;
    FDefaultNodes: IList<TTemplateNode>;
  public
    constructor Create(AEngine: TDextTemplateEngine; const AExpression: string); reintroduce;
    constructor CreateAt(AEngine: TDextTemplateEngine; const APos: TSourcePos; const AExpression: string); reintroduce;
    destructor Destroy; override;
    function Render(const AContext: ITemplateContext): string; override;
    property Cases: IList<TSwitchCase> read FCases;
    property DefaultNodes: IList<TTemplateNode> read FDefaultNodes;
  end;

  TPartialNode = class(TTemplateNode)
  private
    FTemplateName: string;
    FArgumentsText: string;
  public
    constructor Create(AEngine: TDextTemplateEngine; const ATemplateName, AArgumentsText: string); reintroduce;
    constructor CreateAt(AEngine: TDextTemplateEngine; const APos: TSourcePos; const ATemplateName, AArgumentsText: string); reintroduce;
    function Render(const AContext: ITemplateContext): string; override;
  end;

  TRenderSectionNode = class(TTemplateNode)
  private
    FSectionName: string;
    FRequired: Boolean;
  public
    constructor Create(AEngine: TDextTemplateEngine; const ASectionName: string; ARequired: Boolean); reintroduce;
    constructor CreateAt(AEngine: TDextTemplateEngine; const APos: TSourcePos; const ASectionName: string; ARequired: Boolean); reintroduce;
    function Render(const AContext: ITemplateContext): string; override;
  end;

  TRenderBodyNode = class(TTemplateNode)
  public
    constructor Create(AEngine: TDextTemplateEngine); reintroduce;
    constructor CreateAt(AEngine: TDextTemplateEngine; const APos: TSourcePos); reintroduce;
    function Render(const AContext: ITemplateContext): string; override;
  end;

  TMacroCallNode = class(TTemplateNode)
  private
    FName: string;
    FArgumentsText: string;
  public
    constructor Create(AEngine: TDextTemplateEngine; const AName, AArgumentsText: string); reintroduce;
    constructor CreateAt(AEngine: TDextTemplateEngine; const APos: TSourcePos; const AName, AArgumentsText: string); reintroduce;
    function Render(const AContext: ITemplateContext): string; override;
  end;

{ TTemplateContext }

constructor TTemplateContext.Create;
begin
  inherited Create;
  FValues := TCollections.CreateDictionaryIgnoreCase<string, string>;
  FObjects := TCollections.CreateDictionaryIgnoreCase<string, TObject>;
  FLists := TCollections.CreateDictionaryIgnoreCase<string, TArray<TObject>>;
end;

constructor TTemplateContext.Create(const AParent: ITemplateContext);
begin
  Create;
  FParent := AParent;
end;

destructor TTemplateContext.Destroy;
begin
  FValues := nil;
  FObjects := nil;
  FLists := nil;
  inherited;
end;

function TTemplateContext.CreateChildScope: ITemplateContext;
begin
  Result := TTemplateContext.Create(Self);
end;

function TTemplateContext.GetList(const AKey: string): TArray<TObject>;
begin
  if not FLists.TryGetValue(AKey, Result) and Assigned(FParent) then
    Result := FParent.GetList(AKey);
end;

function TTemplateContext.GetObject(const AKey: string): TObject;
begin
  if not FObjects.TryGetValue(AKey, Result) and Assigned(FParent) then
    Result := FParent.GetObject(AKey);
end;

function TTemplateContext.GetValue(const AKey: string): string;
begin
  if not TryGetValue(AKey, Result) then
    Result := '';
end;

function TTemplateContext.HasValue(const AKey: string): Boolean;
var
  LValue: string;
begin
  Result := TryGetValue(AKey, LValue);
end;

procedure TTemplateContext.SetList(const AKey: string; const AItems: TArray<TObject>);
begin
  FLists.AddOrSetValue(AKey, AItems);
end;

procedure TTemplateContext.SetObject(const AKey: string; AObject: TObject);
var
  Context: TTemplateContext;
begin
  Context := Self;
  while Assigned(Context) do
  begin
    if Context.FObjects.ContainsKey(AKey) then
    begin
      Context.FObjects.AddOrSetValue(AKey, AObject);
      Exit;
    end;
    Context := TTemplateContext(Context.FParent);
  end;
  FObjects.AddOrSetValue(AKey, AObject);
end;

procedure TTemplateContext.SetValue(const AKey, AValue: string);
var
  Context: TTemplateContext;
begin
  Context := Self;
  while Assigned(Context) do
  begin
    if Context.FValues.ContainsKey(AKey) then
    begin
      Context.FValues.AddOrSetValue(AKey, AValue);
      Exit;
    end;
    Context := TTemplateContext(Context.FParent);
  end;
  FValues.AddOrSetValue(AKey, AValue);
end;

function TTemplateContext.TryGetValue(const AKey: string; out AValue: string): Boolean;
begin
  Result := FValues.TryGetValue(AKey, AValue);
  if (not Result) and Assigned(FParent) then
    Result := FParent.TryGetValue(AKey, AValue);
end;

{ TSourcePos }

constructor TSourcePos.Create(ALine, ACol: Integer; const AFilename: string);
begin
  Line := ALine;
  Col := ACol;
  Filename := AFilename;
end;

function TSourcePos.ToString: string;
begin
  if Filename <> '' then
    Result := Format('%s (Line %d, Col %d)', [Filename, Line, Col])
  else
    Result := Format('Line %d, Col %d', [Line, Col]);
end;

{ ETemplateException }

constructor ETemplateException.Create(const AMessage: string; const APos: TSourcePos; const ASnippet: string);
begin
  inherited Create(AMessage + ' at ' + APos.ToString);
  FPos := APos;
  FTemplateSnippet := ASnippet;
end;

{ TTemplateNode }

constructor TTemplateNode.Create(AEngine: TDextTemplateEngine);
begin
  inherited Create;
  FEngine := AEngine;
  FPos.Line := 0;
  FPos.Col := 0;
end;

constructor TTemplateNode.CreateAt(AEngine: TDextTemplateEngine; const APos: TSourcePos);
begin
  inherited Create;
  FEngine := AEngine;
  FPos := APos;
end;

{ TTextNode }

constructor TTextNode.Create(AEngine: TDextTemplateEngine; const AText: string);
begin
  inherited Create(AEngine);
  FText := AText;
end;

constructor TTextNode.CreateAt(AEngine: TDextTemplateEngine; const APos: TSourcePos; const AText: string);
begin
  inherited CreateAt(AEngine, APos);
  FText := AText;
end;

function TTextNode.Render(const AContext: ITemplateContext): string;
begin
  Result := FText;
end;

{ TExpressionNode }

constructor TExpressionNode.Create(AEngine: TDextTemplateEngine; const AExpression: string; AIsRaw: Boolean);
begin
  inherited Create(AEngine);
  FExpression := AExpression;
  FIsRaw := AIsRaw;
end;

constructor TExpressionNode.CreateAt(AEngine: TDextTemplateEngine; const APos: TSourcePos; const AExpression: string; AIsRaw: Boolean);
begin
  inherited CreateAt(AEngine, APos);
  FExpression := AExpression;
  FIsRaw := AIsRaw;
end;

function TExpressionNode.Render(const AContext: ITemplateContext): string;
var
  IsRaw, IsEncoded: Boolean;
  Value: TValue;
begin
  IsRaw := False;
  IsEncoded := False;
  Value := FEngine.ResolveValue(FExpression, AContext, IsRaw, IsEncoded);
  Result := FEngine.ValueToString(Value);
  if (FEngine.IsHtmlMode and (not IsRaw) and (not FIsRaw)) or IsEncoded then
    Result := TDextEscaping.Html(Result);
end;

{ TConditionalNode }

constructor TConditionalNode.Create(AEngine: TDextTemplateEngine; const ACondition: string);
begin
  inherited Create(AEngine);
  FCondition := ACondition;
  FTrueNodes := TCollections.CreateList<TTemplateNode>(True);
  FFalseNodes := TCollections.CreateList<TTemplateNode>(True);
end;

constructor TConditionalNode.CreateAt(AEngine: TDextTemplateEngine; const APos: TSourcePos; const ACondition: string);
begin
  inherited CreateAt(AEngine, APos);
  FCondition := ACondition;
  FTrueNodes := TCollections.CreateList<TTemplateNode>(True);
  FFalseNodes := TCollections.CreateList<TTemplateNode>(True);
end;

destructor TConditionalNode.Destroy;
begin
  inherited;
end;

function TConditionalNode.Render(const AContext: ITemplateContext): string;
var
  IsRaw: Boolean;
  IsEncoded: Boolean;
begin
  IsRaw := False;
  IsEncoded := False;
  if FEngine.ValueToBoolean(FEngine.ResolveValue(FCondition, AContext, IsRaw, IsEncoded)) then
    Result := FEngine.RenderNodes(FTrueNodes, AContext)
  else
    Result := FEngine.RenderNodes(FFalseNodes, AContext);
end;

{ TLoopNode }

constructor TLoopNode.Create(AEngine: TDextTemplateEngine; const AItemName, AListExpr: string);
begin
  inherited Create(AEngine);
  FItemName := AItemName;
  FListExpr := AListExpr;
  FNodes := TCollections.CreateList<TTemplateNode>(True);
  FElseNodes := TCollections.CreateList<TTemplateNode>(True);
end;

constructor TLoopNode.CreateAt(AEngine: TDextTemplateEngine; const APos: TSourcePos; const AItemName, AListExpr: string);
begin
  inherited CreateAt(AEngine, APos);
  FItemName := AItemName;
  FListExpr := AListExpr;
  FNodes := TCollections.CreateList<TTemplateNode>(True);
  FElseNodes := TCollections.CreateList<TTemplateNode>(True);
end;

destructor TLoopNode.Destroy;
begin
  inherited;
end;

function TLoopNode.Render(const AContext: ITemplateContext): string;
var
  Args: TArray<TValue>;
  Builder: TStringBuilder;
  Count: Integer;
  CountProp: TRttiProperty;
  DataSet: TDataSet;
  I: Integer;
  IndexedProp: TRttiIndexedProperty;
  IsRaw, IsEncoded: Boolean;
  ItemsList: TArray<TRttiIndexedProperty>;
  ItemValue: TValue;
  Meta: TTypeMetadata;
  Obj: TObject;
  ObjectList: IObjectList;
  P: TRttiIndexedProperty;
  RttiType: TRttiType;
  Source: TValue;
  TotalCount: Integer;

  procedure RenderItem(AValue: TValue; AIndex: Integer; AFirst, ALast: Boolean);
  var
    ItemChild: ITemplateContext;
  begin
    try
      ItemChild := AContext.CreateChildScope;
      if AValue.IsObject then
        ItemChild.SetObject(FItemName, AValue.AsObject)
      else
        ItemChild.SetValue(FItemName, FEngine.ValueToString(AValue));

      ItemChild.SetValue('index', AIndex.ToString);
      ItemChild.SetValue('@@index', AIndex.ToString);
      ItemChild.SetValue('count', AIndex.ToString);
      ItemChild.SetValue('first', System.StrUtils.IfThen(AFirst, 'true', 'false'));
      ItemChild.SetValue('last', System.StrUtils.IfThen(ALast, 'true', 'false'));
      ItemChild.SetValue('odd', System.StrUtils.IfThen(AIndex mod 2 <> 0, 'true', 'false'));
      ItemChild.SetValue('even', System.StrUtils.IfThen(AIndex mod 2 = 0, 'true', 'false'));

      // Built-in style with @
      ItemChild.SetValue('@index', (AIndex - 1).ToString);
      ItemChild.SetValue('@first', System.SysUtils.BoolToStr(AFirst, True));
      ItemChild.SetValue('@last', System.SysUtils.BoolToStr(ALast, True));

      Builder.Append(FEngine.RenderNodes(FNodes, ItemChild));
    except
      on ETemplateLoopContinue do;
    end;
  end;

begin
  IsRaw := False;
  IsEncoded := False;
  Builder := TStringBuilder.Create;
  try
    try
      Source := FEngine.ResolveValue(FListExpr, AContext, IsRaw, IsEncoded);
      if Source.IsEmpty then
      begin
        Builder.Append(FEngine.RenderNodes(FElseNodes, AContext));
        Exit(Builder.ToString);
      end;

      if Source.IsObject or (Source.Kind = tkInterface) then
      begin
        Obj := nil;
        if Source.IsObject then
          Obj := Source.AsObject;

        if Assigned(Obj) and (Obj is TDataSet) then
        begin
          DataSet := TDataSet(Obj);
          if DataSet.IsEmpty then
            Builder.Append(FEngine.RenderNodes(FElseNodes, AContext))
          else
          begin
            DataSet.DisableControls;
            try
              TotalCount := DataSet.RecordCount;
              DataSet.First;
              I := 1;
              while not DataSet.Eof do
              begin
                RenderItem(TValue.From<TDataSet>(DataSet), I, I = 1, I = TotalCount);
                DataSet.Next;
                Inc(I);
              end;
            finally
              DataSet.EnableControls;
            end;
          end;
        end
        else
        begin
          ObjectList := nil;
          if Assigned(Obj) then
            Supports(Obj, IObjectList, ObjectList)
          else if Source.Kind = tkInterface then
            Supports(Source.AsInterface, IObjectList, ObjectList);

          if Assigned(ObjectList) then
          begin
            if ObjectList.Count = 0 then
              Builder.Append(FEngine.RenderNodes(FElseNodes, AContext))
            else
            begin
              for I := 0 to ObjectList.Count - 1 do
                RenderItem(ObjectList.Items[I], I + 1, I = 0, I = ObjectList.Count - 1);
            end;
          end
          else if TReflection.IsListType(Source.TypeInfo) then
          begin
            Meta := TReflection.GetMetadata(Source.TypeInfo);
            RttiType := Meta.RttiType;
            CountProp := RttiType.GetProperty('Count');
            if CountProp = nil then
              CountProp := RttiType.GetProperty('GetCount');

            IndexedProp := nil;
            ItemsList := RttiType.GetIndexedProperties;
            for P in ItemsList do
              if SameText(P.Name, 'Items') then
              begin
                IndexedProp := P;
                Break;
              end;

            if (IndexedProp = nil) and (Length(ItemsList) > 0) then
              IndexedProp := ItemsList[0];

            if Assigned(CountProp) and Assigned(IndexedProp) then
            begin
              if Source.Kind = tkInterface then
                Count := CountProp.GetValue(Source.AsInterface).AsInteger
              else
                Count := CountProp.GetValue(Obj).AsInteger;

              if Count = 0 then
                Builder.Append(FEngine.RenderNodes(FElseNodes, AContext))
              else
              begin
                for I := 0 to Count - 1 do
                begin
                  SetLength(Args, 1);
                  Args[0] := TValue.From(I);

                  if Source.Kind = tkInterface then
                    ItemValue := IndexedProp.GetValue(Pointer(Source.AsInterface), Args)
                  else
                    ItemValue := IndexedProp.GetValue(Obj, Args);
                  RenderItem(ItemValue, I + 1, I = 0, I = Count - 1);
                end;
              end;
            end
            else
              RenderItem(Source, 1, True, True);
          end
          else
            RenderItem(Source, 1, True, True);
        end;
      end
      else if Source.IsArray then
      begin
        if Source.GetArrayLength = 0 then
          Builder.Append(FEngine.RenderNodes(FElseNodes, AContext))
        else
        begin
          for I := 0 to Source.GetArrayLength - 1 do
            RenderItem(Source.GetArrayElement(I), I + 1, I = 0, I = Source.GetArrayLength - 1);
        end;
      end
      else
        RenderItem(Source, 1, True, True);

      Result := Builder.ToString;
    except
      on ETemplateLoopBreak do
        Result := Builder.ToString;
    end;
  finally
    Builder.Free;
  end;
end;


{ TSwitchCase }

constructor TSwitchCase.Create(const AExpression: string);
begin
  inherited Create;
  Expression := AExpression;
  Nodes := TCollections.CreateList<TTemplateNode>(True);
end;

destructor TSwitchCase.Destroy;
begin
  inherited;
end;

{ TSwitchNode }

constructor TSwitchNode.Create(AEngine: TDextTemplateEngine; const AExpression: string);
begin
  inherited Create(AEngine);
  FExpression := AExpression;
  FCases := TCollections.CreateList<TSwitchCase>(True);
  FDefaultNodes := TCollections.CreateList<TTemplateNode>(True);
end;

constructor TSwitchNode.CreateAt(AEngine: TDextTemplateEngine; const APos: TSourcePos; const AExpression: string);
begin
  inherited CreateAt(AEngine, APos);
  FExpression := AExpression;
  FCases := TCollections.CreateList<TSwitchCase>(True);
  FDefaultNodes := TCollections.CreateList<TTemplateNode>(True);
end;

destructor TSwitchNode.Destroy;
begin
  inherited;
end;

function TSwitchNode.Render(const AContext: ITemplateContext): string;
var
  CaseValue: TValue;
  IsRaw, IsEncoded: Boolean;
  SwitchCase: TSwitchCase;
  SwitchValue: TValue;
begin
  IsRaw := False;
  IsEncoded := False;
  SwitchValue := FEngine.ResolveValue(FExpression, AContext, IsRaw, IsEncoded);
  for SwitchCase in FCases do
  begin
    IsEncoded := False;
    CaseValue := FEngine.ResolveValue(SwitchCase.Expression, AContext, IsRaw, IsEncoded);
    if SameText(FEngine.ValueToString(SwitchValue), FEngine.ValueToString(CaseValue)) then
      Exit(FEngine.RenderNodes(SwitchCase.Nodes, AContext));
  end;
  Result := FEngine.RenderNodes(FDefaultNodes, AContext);
end;

{ TFileSystemTemplateLoader }

constructor TFileSystemTemplateLoader.Create(const ARoot: string);
begin
  inherited Create;
  FRoot := TPath.GetFullPath(ARoot);
end;

function TFileSystemTemplateLoader.Load(const ATemplateName: string): string;
var
  FileName: string;
begin
  FileName := ATemplateName;
  if not TPath.IsPathRooted(FileName) then
    FileName := TPath.Combine(FRoot, FileName);

  if TFile.Exists(FileName) then
    Exit(TFile.ReadAllText(FileName, TEncoding.UTF8));

  if TFile.Exists(FileName + '.html') then
    Exit(TFile.ReadAllText(FileName + '.html', TEncoding.UTF8));

  if TFile.Exists(FileName + '.template') then
    Exit(TFile.ReadAllText(FileName + '.template', TEncoding.UTF8));

  raise EFileNotFoundException.CreateFmt('Template not found: %s', [ATemplateName]);
end;

{ TInMemoryTemplateLoader }

constructor TInMemoryTemplateLoader.Create;
begin
  inherited Create;
  FTemplates := TCollections.CreateDictionaryIgnoreCase<string, string>;
end;

procedure TInMemoryTemplateLoader.AddTemplate(const AName, AContent: string);
begin
  FTemplates.AddOrSetValue(AName, AContent);
end;

function TInMemoryTemplateLoader.Load(const ATemplateName: string): string;
begin
  if not FTemplates.TryGetValue(ATemplateName, Result) then
    raise EFileNotFoundException.CreateFmt('Template not found: %s', [ATemplateName]);
end;

{ TDextTemplateEngine.TTemplateDocument }

constructor TDextTemplateEngine.TTemplateDocument.Create;
begin
  inherited Create;
  Sections := TCollections.CreateDictionary<string, TStringBuilder>(True);
  Definitions := TCollections.CreateDictionary<string, TInlineTemplateDefinition>(True);
end;

destructor TDextTemplateEngine.TTemplateDocument.Destroy;
begin
  inherited;
end;

{ TDextTemplateEngine.TRenderState }

constructor TDextTemplateEngine.TRenderState.Create;
begin
  inherited Create;
  Sections := TCollections.CreateDictionaryIgnoreCase<string, string>;
  Definitions := TCollections.CreateDictionary<string, TInlineTemplateDefinition>(True);
end;

destructor TDextTemplateEngine.TRenderState.Destroy;
begin
  Sections := nil;
  inherited;
end;

{ TDextTemplateEngine }

constructor TDextTemplateEngine.Create;
begin
  Create(nil);
end;

constructor TDextTemplateEngine.Create(const ALoader: ITemplateLoader);
begin
  inherited Create;
  FFilters := TCollections.CreateDictionaryIgnoreCase<string, System.SysUtils.TFunc<string, string>>;
  FAdvancedFilters := TCollections.CreateDictionaryIgnoreCase<string, TTemplateFilterFunc>;
  FTemplateAstCache := TCollections.CreateDictionary<string, TTemplateNodeList>(True);
  FTemplateLoader := ALoader;
  FIsHtmlMode := False;

  RegisterFilter('ToPascalCase',
    function(S: string): string
    var
      i: Integer;
      Parts: TArray<string>;
    begin
      Result := S.DeQuotedString;
      Parts := Result.Split(['_', ' ', '-'], TStringSplitOptions.ExcludeEmpty);
      if Length(Parts) > 1 then
      begin
        Result := '';
        for i := 0 to High(Parts) do
          Result := Result + UpperCase(Copy(Parts[i], 1, 1)) + LowerCase(Copy(Parts[i], 2, MaxInt));
      end
      else if Result <> '' then
        Result := UpperCase(Copy(Result, 1, 1)) + Copy(Result, 2, MaxInt);
    end);

  RegisterFilter('ToCamelCase',
    function(S: string): string
    var
      PascalCase: string;
    begin
      PascalCase := ApplyFilter('ToPascalCase', S);
      if PascalCase = '' then
        Result := ''
      else
        Result := LowerCase(Copy(PascalCase, 1, 1)) + Copy(PascalCase, 2, MaxInt);
    end);

  RegisterFilter('ToSnakeCase',
    function(S: string): string
    var
      i: Integer;
    begin
      Result := '';
      for i := 1 to Length(S) do
      begin
        if (i > 1) and S[i].IsUpper then
          Result := Result + '_';
        Result := Result + S[i].ToLower;
      end;
    end);

  RegisterFilter('Pluralize',
    function(S: string): string
    begin
      Result := S;
      if S = '' then
        Exit;
      if S.EndsWith('y', True) and not S.EndsWith('ay', True) and not S.EndsWith('ey', True) and not S.EndsWith('iy', True) and not S.EndsWith('oy', True) and not S.EndsWith('uy', True) then
        Result := S.Substring(0, S.Length - 1) + 'ies'
      else if S.EndsWith('s', True) or S.EndsWith('x', True) or S.EndsWith('ch', True) or S.EndsWith('sh', True) then
        Result := S + 'es'
      else
        Result := S + 's';
    end);

  RegisterFilter('Singularize',
    function(S: string): string
    begin
      Result := S;
      if S = '' then
        Exit;
      if S.EndsWith('ies', True) then
        Result := S.Substring(0, S.Length - 3) + 'y'
      else if S.EndsWith('es', True) then
        Result := S.Substring(0, S.Length - 2)
      else if S.EndsWith('s', True) and not S.EndsWith('ss', True) then
        Result := S.Substring(0, S.Length - 1);
    end);

  RegisterAdvancedFilter('uppercase',
    function(const AValue: TValue; const AArgs: TArray<TValue>): TValue
    begin
      Result := UpperCase(ValueToString(AValue));
    end);
  RegisterAdvancedFilter('lowercase',
    function(const AValue: TValue; const AArgs: TArray<TValue>): TValue
    begin
      Result := LowerCase(ValueToString(AValue));
    end);
  RegisterAdvancedFilter('capitalize',
    function(const AValue: TValue; const AArgs: TArray<TValue>): TValue
    var
      S: string;
    begin
      S := ValueToString(AValue);
      if S = '' then
        Result := ''
      else
        Result := UpperCase(Copy(S, 1, 1)) + LowerCase(Copy(S, 2, MaxInt));
    end);
  RegisterAdvancedFilter('trim',
    function(const AValue: TValue; const AArgs: TArray<TValue>): TValue
    begin
      Result := System.SysUtils.Trim(ValueToString(AValue));
    end);
  RegisterAdvancedFilter('truncate',
    function(const AValue: TValue; const AArgs: TArray<TValue>): TValue
    var
      S, Suffix: string;
      N: Integer;
    begin
      S := ValueToString(AValue);
      N := 0;
      if Length(AArgs) > 0 then
        N := StrToIntDef(ValueToString(AArgs[0]), 0);
      if Length(AArgs) > 1 then
        Suffix := ValueToString(AArgs[1])
      else
        Suffix := '...';
      if (N > 0) and (Length(S) > N) then
        Result := Copy(S, 1, N) + Suffix
      else
        Result := S;
    end);
  RegisterAdvancedFilter('lpad',
    function(const AValue: TValue; const AArgs: TArray<TValue>): TValue
    var
      S, Pad: string;
      N: Integer;
    begin
      S := ValueToString(AValue);
      N := StrToIntDef(ValueToString(AArgs[0]), Length(S));
      if Length(AArgs) > 1 then
        Pad := ValueToString(AArgs[1])
      else
        Pad := ' ';
      if Pad = '' then
        Pad := ' ';
      while Length(S) < N do
        S := Pad[1] + S;
      Result := S;
    end);
  RegisterAdvancedFilter('rpad',
    function(const AValue: TValue; const AArgs: TArray<TValue>): TValue
    var
      S, Pad: string;
      N: Integer;
    begin
      S := ValueToString(AValue);
      N := StrToIntDef(ValueToString(AArgs[0]), Length(S));
      if Length(AArgs) > 1 then
        Pad := ValueToString(AArgs[1])
      else
        Pad := ' ';
      if Pad = '' then
        Pad := ' ';
      while Length(S) < N do
        S := S + Pad[1];
      Result := S;
    end);
  RegisterAdvancedFilter('replace',
    function(const AValue: TValue; const AArgs: TArray<TValue>): TValue
    begin
      if Length(AArgs) >= 2 then
        Result := ValueToString(AValue).Replace(ValueToString(AArgs[0]), ValueToString(AArgs[1]))
      else
        Result := ValueToString(AValue);
    end);
  RegisterAdvancedFilter('default',
    function(const AValue: TValue; const AArgs: TArray<TValue>): TValue
    var
      S: string;
    begin
      S := ValueToString(AValue);
      if (S = '') and (Length(AArgs) > 0) then
        Result := AArgs[0]
      else
        Result := AValue;
    end);
  RegisterAdvancedFilter('htmlencode',
    function(const AValue: TValue; const AArgs: TArray<TValue>): TValue
    begin
      Result := TDextEscaping.Html(ValueToString(AValue));
    end);
  RegisterAdvancedFilter('urlencode',
    function(const AValue: TValue; const AArgs: TArray<TValue>): TValue
    begin
      Result := TNetEncoding.URL.Encode(ValueToString(AValue));
    end);
  RegisterAdvancedFilter('json',
    function(const AValue: TValue; const AArgs: TArray<TValue>): TValue
    begin
      Result := TDextJson.Serialize(AValue);
    end);
  RegisterAdvancedFilter('raw',
    function(const AValue: TValue; const AArgs: TArray<TValue>): TValue
    begin
      Result := AValue;
    end);
  RegisterAdvancedFilter('datetostr',
    function(const AValue: TValue; const AArgs: TArray<TValue>): TValue
    var
      Fmt: string;
      Dt: TDateTime;
    begin
      if AValue.IsEmpty then
        Exit('');
      if AValue.TryAsType<TDateTime>(Dt) then
      begin
        if Length(AArgs) > 0 then
          Fmt := ValueToString(AArgs[0])
        else
          Fmt := 'dd/mm/yyyy';
        Result := FormatDateTime(Fmt, Dt);
      end
      else
        Result := ValueToString(AValue);
    end);
  RegisterAdvancedFilter('datetimetostr',
    function(const AValue: TValue; const AArgs: TArray<TValue>): TValue
    var
      Fmt: string;
      Dt: TDateTime;
    begin
      if AValue.IsEmpty then
        Exit('');
      if AValue.TryAsType<TDateTime>(Dt) then
      begin
        if Length(AArgs) > 0 then
          Fmt := ValueToString(AArgs[0])
        else
          Fmt := 'dd/mm/yyyy hh:nn:ss';
        Result := FormatDateTime(Fmt, Dt);
      end
      else
        Result := ValueToString(AValue);
    end);
  RegisterAdvancedFilter('formatfloat',
    function(const AValue: TValue; const AArgs: TArray<TValue>): TValue
    var
      N: Extended;
      Fmt: string;
    begin
      Fmt := '0.00';
      if Length(AArgs) > 0 then
        Fmt := ValueToString(AArgs[0]);
      if AValue.TryAsType<Extended>(N) then
        Result := System.SysUtils.FormatFloat(Fmt, N)
      else
        Result := ValueToString(AValue);
    end);
  RegisterAdvancedFilter('formatint',
    function(const AValue: TValue; const AArgs: TArray<TValue>): TValue
    var
      I64: Int64;
    begin
      if AValue.TryAsType<Int64>(I64) then
        Result := Format('%d', [I64])
      else
        Result := ValueToString(AValue);
    end);
  RegisterAdvancedFilter('round',
    function(const AValue: TValue; const AArgs: TArray<TValue>): TValue
    var
      N: Extended;
      Digits: Integer;
    begin
      Digits := 0;
      if Length(AArgs) > 0 then
        Digits := StrToIntDef(ValueToString(AArgs[0]), 0);
      if AValue.TryAsType<Extended>(N) then
        Result := System.Math.SimpleRoundTo(N, -Digits)
      else
        Result := ValueToString(AValue);
    end);
  RegisterAdvancedFilter('eq',
    function(const AValue: TValue; const AArgs: TArray<TValue>): TValue
    begin
      if Length(AArgs) = 0 then
        Exit(False);
      Result := SameText(ValueToString(AValue), ValueToString(AArgs[0]));
    end);
  RegisterAdvancedFilter('ne',
    function(const AValue: TValue; const AArgs: TArray<TValue>): TValue
    begin
      if Length(AArgs) = 0 then
        Exit(True);
      Result := not SameText(ValueToString(AValue), ValueToString(AArgs[0]));
    end);
  RegisterAdvancedFilter('gt',
    function(const AValue: TValue; const AArgs: TArray<TValue>): TValue
    begin
      if Length(AArgs) = 0 then
        Exit(False);
      Result := ValueToString(AValue) > ValueToString(AArgs[0]);
    end);
  RegisterAdvancedFilter('ge',
    function(const AValue: TValue; const AArgs: TArray<TValue>): TValue
    begin
      if Length(AArgs) = 0 then
        Exit(False);
      Result := ValueToString(AValue) >= ValueToString(AArgs[0]);
    end);
  RegisterAdvancedFilter('lt',
    function(const AValue: TValue; const AArgs: TArray<TValue>): TValue
    begin
      if Length(AArgs) = 0 then
        Exit(False);
      Result := ValueToString(AValue) < ValueToString(AArgs[0]);
    end);
  RegisterAdvancedFilter('le',
    function(const AValue: TValue; const AArgs: TArray<TValue>): TValue
    begin
      if Length(AArgs) = 0 then
        Exit(False);
      Result := ValueToString(AValue) <= ValueToString(AArgs[0]);
    end);
  RegisterAdvancedFilter('contains',
    function(const AValue: TValue; const AArgs: TArray<TValue>): TValue
    begin
      if Length(AArgs) = 0 then
        Exit(False);
      Result := ContainsText(ValueToString(AValue), ValueToString(AArgs[0]));
    end);
  RegisterAdvancedFilter('startswith',
    function(const AValue: TValue; const AArgs: TArray<TValue>): TValue
    begin
      if Length(AArgs) = 0 then
        Exit(False);
      Result := StartsText(ValueToString(AArgs[0]), ValueToString(AValue));
    end);
  RegisterAdvancedFilter('endswith',
    function(const AValue: TValue; const AArgs: TArray<TValue>): TValue
    begin
      if Length(AArgs) = 0 then
        Exit(False);
      Result := EndsText(ValueToString(AArgs[0]), ValueToString(AValue));
    end);
end;

destructor TDextTemplateEngine.Destroy;
begin
  FAdvancedFilters := nil;
  FFilters := nil;
  inherited;
end;

function TDextTemplateEngine.GetTemplateLoader: ITemplateLoader;
begin
  Result := FTemplateLoader;
end;

procedure TDextTemplateEngine.SetTemplateLoader(const ALoader: ITemplateLoader);
begin
  FTemplateLoader := ALoader;
end;

procedure TDextTemplateEngine.RegisterFilter(const AName: string; const AFilter: System.SysUtils.TFunc<string, string>);
begin
  FFilters.AddOrSetValue(AName, AFilter);
end;

procedure TDextTemplateEngine.RegisterAdvancedFilter(const AName: string; const AFilter: TTemplateFilterFunc);
begin
  FAdvancedFilters.AddOrSetValue(AName, AFilter);
end;

function TDextTemplateEngine.ApplyFilter(const AName, AValue: string): string;
var
  LFilter: System.SysUtils.TFunc<string, string>;
begin
  if FFilters.TryGetValue(System.SysUtils.Trim(AName), LFilter) and Assigned(LFilter) then
    Result := LFilter(AValue)
  else
    Result := AValue;
end;

function TDextTemplateEngine.ApplyAdvancedFilter(const AName: string; const AValue: TValue; const AArgs: TArray<TValue>): TValue;
var
  LFilter: TTemplateFilterFunc;
begin
  if FAdvancedFilters.TryGetValue(AName, LFilter) then
    Exit(LFilter(AValue, AArgs));

  Result := ApplyFilter(AName, ValueToString(AValue));
end;

function TDextTemplateEngine.ValueToString(const AValue: TValue): string;
var
  LUnwrapped: TValue;
  LObj: TObject;
begin
  if AValue.IsEmpty then
    Exit('');

  if TReflection.TryUnwrapProp(AValue, LUnwrapped) then
    Exit(ValueToString(LUnwrapped));

  if (AValue.Kind = tkClass) then
  begin
    LObj := AValue.AsObject;
    if LObj = nil then Exit('');
    Exit(LObj.ToString);
  end;

  if (AValue.Kind = tkInterface) then
    Exit('');

  Result := AValue.ToString;
end;

function TDextTemplateEngine.ValueToBoolean(const AValue: TValue): Boolean;
var
  LText: string;
begin
  if AValue.IsEmpty then
    Exit(False);

  if AValue.Kind = tkEnumeration then
  begin
    if AValue.TypeInfo = TypeInfo(Boolean) then
      Exit(AValue.AsBoolean);
  end;

  if AValue.Kind in [tkInteger, tkInt64] then
    Exit(AValue.AsInt64 <> 0);

  LText := ValueToString(AValue).Trim.ToLower;
  Result := (LText <> '') and (LText <> 'false') and (LText <> '0') and (LText <> 'null') and (LText <> 'no');
end;

function TDextTemplateEngine.ResolveRootValue(const ARoot: string; const AContext: ITemplateContext): TValue;
var
  LText: string;
  LObject: TObject;
  LList: TArray<TObject>;
begin
  Result := TValue.Empty;

  if (ARoot = '@@index') or (ARoot = 'index') or SameText(ARoot, '@@index') or SameText(ARoot, 'index') then
    Result := AContext.GetValue('index')
  else if (ARoot = '@@first') or SameText(ARoot, '@@first') then
    Result := AContext.GetValue('first')
  else if (ARoot = '@@last') or SameText(ARoot, '@@last') then
    Result := AContext.GetValue('last')
  else if (ARoot = '@@odd') or SameText(ARoot, '@@odd') then
    Result := AContext.GetValue('odd')
  else if (ARoot = '@@even') or SameText(ARoot, '@@even') then
    Result := AContext.GetValue('even');

  if not Result.IsEmpty then Exit;
  if SameText(ARoot, '@@first') then
    Exit(AContext.GetValue('first'));
  if SameText(ARoot, '@@last') then
    Exit(AContext.GetValue('last'));
  if SameText(ARoot, '@@odd') then
    Exit(AContext.GetValue('odd'));
  if SameText(ARoot, '@@even') then
    Exit(AContext.GetValue('even'));

  LObject := AContext.GetObject(ARoot);
  if Assigned(LObject) then
    Exit(TValue.From<TObject>(LObject));

  LList := AContext.GetList(ARoot);
  if Length(LList) > 0 then
    Exit(TValue.From<TArray<TObject>>(LList));

  if AContext.TryGetValue(ARoot, LText) then
    Exit(LText);
end;

function TDextTemplateEngine.ResolvePathValue(const APath: string; const AContext: ITemplateContext): TValue;
var
  LWorkPath: string;
  LParts: TArray<string>;
  I: Integer;
  LPart: string;
begin
  LWorkPath := System.SysUtils.Trim(APath);
  if StartsText('@', LWorkPath) and (not StartsText('@@', LWorkPath)) then
    LWorkPath := Copy(LWorkPath, 2, MaxInt);

  LParts := SplitTopLevel(LWorkPath, '.');
  if Length(LParts) = 0 then
    Exit(TValue.Empty);

  Result := ResolveRootValue(System.SysUtils.Trim(LParts[0]), AContext);
  for I := 1 to High(LParts) do
  begin
    LPart := System.SysUtils.Trim(LParts[I]);
    Result := ResolveMemberValue(Result, LPart, AContext);
    
    if Result.IsEmpty then
      Exit(TValue.Empty);
  end;
end;

function TDextTemplateEngine.ResolveMemberValue(const AValue: TValue; const APath: string; const AContext: ITemplateContext): TValue;
var
  LWorking: TValue;
  LMeta: TTypeMetadata;
  LHandler: IPropertyHandler;
  LName: string;
  LObject: TObject;
  LCheckName: string;
  LArgs: TArray<TValue>;
  LArgsStr: string;
  LParenPos: Integer;
  LDataSetField: TField;
  LContext: TRttiContext;
  LRttiType: TRttiType;
  LMethod: TRttiMethod;
  LProp: TRttiProperty;
  LRttiField: TRttiField;
  LBPos: Integer;
  LIndexStr: string;
  LField: TField;
begin
  Result := TValue.Empty;
  LName := System.SysUtils.Trim(APath);

  if StartsText('@@', LName) then
    Exit(ResolveRootValue(LName, AContext));

  LWorking := AValue;

  if TReflection.TryUnwrapProp(LWorking, Result) then
    LWorking := Result;

  if LWorking.IsEmpty then
    Exit(TValue.Empty);

  // Check if it's a filter call (fallback or dot-syntax)
  LCheckName := LName;
  LArgs := [];
  LParenPos := LName.IndexOf('(');
  if LParenPos >= 0 then
  begin
      LCheckName := LName.Substring(0, LParenPos);
      LArgsStr := LName.Substring(LParenPos + 1, LName.Length - LParenPos - 2);
      if LArgsStr <> '' then
        LArgs := ParseFilterArguments(LArgsStr, AContext);
  end;

  if FAdvancedFilters.ContainsKey(LCheckName) or FFilters.ContainsKey(LCheckName) then
    Exit(ApplyAdvancedFilter(LCheckName, LWorking, LArgs));

  // Try standard member resolution (Property or Field)
  if LWorking.Kind = tkClass then
  begin
    LObject := LWorking.AsObject;
    if Assigned(LObject) then
    begin
      if LObject is TDataSet then
      begin
        LDataSetField := TDataSet(LObject).FindField(LCheckName);
        if LDataSetField <> nil then
          Exit(TValue.FromVariant(LDataSetField.Value));
      end;
      
      LContext := TRttiContext.Create;
      LRttiType := LContext.GetType(LObject.ClassType);
      if LRttiType <> nil then
      begin
        // Try Method invocation
        LMethod := LRttiType.GetMethod(LCheckName);
        if LMethod <> nil then
           Exit(LMethod.Invoke(LObject, LArgs));
           
        // Try Property
        LProp := LRttiType.GetProperty(LCheckName);
        if LProp <> nil then
           Exit(LProp.GetValue(LObject));
           
        // Try Field
        LRttiField := LRttiType.GetField(LCheckName);
        if LRttiField = nil then LRttiField := LRttiType.GetField('F' + LCheckName);
        if LRttiField <> nil then
           Exit(LRttiField.GetValue(LObject));
      end;
    end;
  end;

  if LWorking.Kind = tkRecord then
  begin
    LMeta := TReflection.GetMetadata(LWorking.TypeInfo);
    LHandler := LMeta.GetHandler(LName);
    if Assigned(LHandler) then
      Exit(LHandler.GetValue(LWorking.GetReferenceToRawData));
  end;

  if LWorking.Kind = tkInterface then
  begin
    LMeta := TReflection.GetMetadata(LWorking.TypeInfo);
    LHandler := LMeta.GetHandler(LName);
    if Assigned(LHandler) then
      Exit(LHandler.GetValue(LWorking.GetReferenceToRawData));
  end;

  // Check if it's an indexed property
  if (LName.Length > 2) and LName.EndsWith(']') then
  begin
    LBPos := LName.LastIndexOf('[');
    if LBPos > 0 then
    begin
        LIndexStr := LName.Substring(LBPos + 1, LName.Length - LBPos - 2);
        // Special case for TDataSet fields/indexed
        if (LWorking.Kind = tkClass) and (not LWorking.IsEmpty) and (LWorking.AsObject is TDataSet) then
        begin
           LField := TDataSet(LWorking.AsObject).FindField(LIndexStr);
           if LField <> nil then Exit(TValue.FromVariant(LField.Value));
        end;
        // Generic GetValue handles some indexed props
        if LWorking.Kind = tkClass then
           Exit(TReflection.GetValue(LWorking.AsObject, LName)); 
    end;
  end;

  Result := TValue.Empty;
end;

function TDextTemplateEngine.UnquoteString(const AText: string): string;
begin
  Result := System.SysUtils.Trim(AText);
  if (Length(Result) >= 2) and (((Result[1] = '''') and (Result[High(Result)] = '''')) or
     ((Result[1] = '"') and (Result[High(Result)] = '"'))) then
    Result := Copy(Result, 2, Length(Result) - 2);
end;

function TDextTemplateEngine.SplitTopLevel(const AText: string; ASeparator: Char): TArray<string>;
var
  I, LStart, LDepth: Integer;
  LQuote: Char;
  LItems: TList<string>;
begin
  LItems := TList<string>.Create;
  try
    LStart := 1;
    LDepth := 0;
    LQuote := #0;
    for I := 1 to Length(AText) do
    begin
      if (LQuote <> #0) then
      begin
        if AText[I] = LQuote then
          LQuote := #0;
        Continue;
      end;

      if CharInSet(AText[I], ['''', '"']) then
      begin
        LQuote := AText[I];
        Continue;
      end;

      if (AText[I] = '(') or (AText[I] = '[') then
        Inc(LDepth)
      else if (AText[I] = ')') or (AText[I] = ']') then
        Dec(LDepth)
      else if (AText[I] = ASeparator) and (LDepth = 0) then
      begin
        LItems.Add(Copy(AText, LStart, I - LStart));
        LStart := I + 1;
      end;
    end;
    LItems.Add(Copy(AText, LStart, MaxInt));
    Result := LItems.ToArray;
  finally
    LItems.Free;
  end;
end;

function TDextTemplateEngine.ParseFilterArguments(const AText: string; const AContext: ITemplateContext): TArray<TValue>;
var
  LParts: TArray<string>;
  I: Integer;
  LIsRaw: Boolean;
  LIsEncoded: Boolean;
begin
  LParts := SplitTopLevel(AText, ',');
  SetLength(Result, Length(LParts));
  for I := 0 to High(LParts) do
  begin
    LIsRaw := False;
    LIsEncoded := False;
    Result[I] := ResolveValue(LParts[I], AContext, LIsRaw, LIsEncoded);
  end;
end;

function TDextTemplateEngine.ParseNamedArguments(const AText: string): TArray<TTemplateArgument>;
var
  LParts: TArray<string>;
  LItem: string;
  LColon: Integer;
  LList: TList<TTemplateArgument>;
  LArg: TTemplateArgument;
begin
  LList := TList<TTemplateArgument>.Create;
  try
    LParts := SplitTopLevel(AText, ',');
    for LItem in LParts do
    begin
      if System.SysUtils.Trim(LItem) = '' then
        Continue;

      LColon := System.Pos(':', LItem);
      if LColon > 0 then
      begin
        LArg.Name := System.SysUtils.Trim(Copy(LItem, 1, LColon - 1));
        LArg.Expression := System.SysUtils.Trim(Copy(LItem, LColon + 1, MaxInt));
      end
      else
      begin
        LArg.Name := '';
        LArg.Expression := System.SysUtils.Trim(LItem);
      end;
      LList.Add(LArg);
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function TDextTemplateEngine.ExtractCallArguments(const AText: string; out AName: string): string;
var
  LOpen: Integer;
  LClosePos: Integer;
begin
  AName := System.SysUtils.Trim(AText);
  LOpen := System.Pos('(', AName);
  if LOpen = 0 then
  begin
    Result := '';
    Exit;
  end;

  Result := Copy(AName, LOpen + 1, MaxInt);
  AName := System.SysUtils.Trim(Copy(AName, 1, LOpen - 1));
  LClosePos := Result.LastIndexOf(')');
  if LClosePos >= 0 then
    Result := Copy(Result, 1, LClosePos);
end;

function TDextTemplateEngine.HasTopLevelOperator(const AExpr: string): Boolean;
var
  I, LDepth: Integer;
  LQuote: Char;
begin
  Result := False;
  LDepth := 0;
  LQuote := #0;
  for I := 1 to Length(AExpr) do
  begin
    if LQuote <> #0 then
    begin
      if AExpr[I] = LQuote then
        LQuote := #0;
      Continue;
    end;

    if CharInSet(AExpr[I], ['''', '"']) then
    begin
      LQuote := AExpr[I];
      Continue;
    end;

    if AExpr[I] = '(' then
      Inc(LDepth)
    else if AExpr[I] = ')' then
      Dec(LDepth)
    else if (LDepth = 0) and CharInSet(AExpr[I], ['+', '-', '*', '/', '>', '<', '=', '!']) then
      Exit(True);
  end;
end;

function TDextTemplateEngine.ExecuteInlineFunction(const AName: string; const AArgs: TArray<TValue>; const AContext: ITemplateContext): TValue;
var
  LName: string;
  LNum1, LNum2: Double;
  LInt: Integer;
  LText: string;
  LBase: TValue;
  LParts: TArray<string>;
  LMethodName: string;
begin
  LName := System.SysUtils.Trim(AName);

  if LName.Contains('.') then
  begin
    LParts := SplitTopLevel(LName, '.');
    LMethodName := LParts[High(LParts)];
    LBase := ResolvePathValue(string.Join('.', Copy(LParts, 0, Length(LParts) - 1)), AContext);
    Exit(ApplyAdvancedFilter(LMethodName, LBase, AArgs));
  end;

  LName := LowerCase(LName);

  if LName = 'length' then
    Exit(Length(ValueToString(AArgs[0])));
  if LName = 'upper' then
    Exit(UpperCase(ValueToString(AArgs[0])));
  if LName = 'lower' then
    Exit(LowerCase(ValueToString(AArgs[0])));
  if LName = 'trim' then
    Exit(System.SysUtils.Trim(ValueToString(AArgs[0])));
  if LName = 'sqrt' then
  begin
    LNum1 := StrToFloatDef(ValueToString(AArgs[0]), 0, TFormatSettings.Invariant);
    Exit(System.Sqrt(LNum1));
  end;
  if LName = 'abs' then
  begin
    LNum1 := StrToFloatDef(ValueToString(AArgs[0]), 0, TFormatSettings.Invariant);
    Exit(System.Abs(LNum1));
  end;
  if LName = 'round' then
  begin
    LNum1 := StrToFloatDef(ValueToString(AArgs[0]), 0, TFormatSettings.Invariant);
    if Length(AArgs) > 1 then
      LInt := StrToIntDef(ValueToString(AArgs[1]), 0)
    else
      LInt := 0;
    Exit(System.Math.SimpleRoundTo(LNum1, -LInt));
  end;
  if LName = 'min' then
  begin
    LNum1 := StrToFloatDef(ValueToString(AArgs[0]), 0, TFormatSettings.Invariant);
    LNum2 := StrToFloatDef(ValueToString(AArgs[1]), 0, TFormatSettings.Invariant);
    Exit(System.Math.Min(LNum1, LNum2));
  end;
  if LName = 'max' then
  begin
    LNum1 := StrToFloatDef(ValueToString(AArgs[0]), 0, TFormatSettings.Invariant);
    LNum2 := StrToFloatDef(ValueToString(AArgs[1]), 0, TFormatSettings.Invariant);
    Exit(System.Math.Max(LNum1, LNum2));
  end;
  if LName = 'left' then
  begin
    LText := ValueToString(AArgs[0]);
    LInt := StrToIntDef(ValueToString(AArgs[1]), 0);
    Exit(Copy(LText, 1, LInt));
  end;
  if LName = 'right' then
  begin
    LText := ValueToString(AArgs[0]);
    LInt := StrToIntDef(ValueToString(AArgs[1]), 0);
    if LInt <= 0 then
      Exit('');
    if LInt >= Length(LText) then
      Exit(LText);
    Exit(Copy(LText, Length(LText) - LInt + 1, LInt));
  end;

  Result := TValue.Empty;
end;

function TDextTemplateEngine.EvaluateInlineExpression(const AExpr: string; const AContext: ITemplateContext): TValue;
var
  S: string;
  P: Integer;

  procedure SkipSpaces;
  begin
    while (P <= Length(S)) and S[P].IsWhiteSpace do
      Inc(P);
  end;

  function ParseExpression: TValue; forward;

  function TryAsNumber(const AValue: TValue; out ANumber: Double): Boolean;
  begin
    Result := TryStrToFloat(ValueToString(AValue), ANumber, TFormatSettings.Invariant);
    if not Result and (AValue.Kind = tkEnumeration) and (AValue.TypeInfo = TypeInfo(Boolean)) then
    begin
      ANumber := Ord(AValue.AsBoolean);
      Result := True;
    end;
  end;

  function ParseStringLiteral: string;
  var
    LQuote: Char;
    LStart: Integer;
  begin
    LQuote := S[P];
    Inc(P);
    LStart := P;
    while (P <= Length(S)) and (S[P] <> LQuote) do
      Inc(P);
    Result := Copy(S, LStart, P - LStart);
    if (P <= Length(S)) and (S[P] = LQuote) then
      Inc(P);
  end;

  function ParseNameToken: string;
  var
    LStart: Integer;
  begin
    if (P <= Length(S)) and (S[P] = '@') then
      Inc(P);
    LStart := P;
    while (P <= Length(S)) and CharInSet(S[P], ['A'..'Z', 'a'..'z', '0'..'9', '_', '.', '@']) do
      Inc(P);
    Result := Copy(S, LStart, P - LStart);
  end;

  function ParsePathToken: string;
  var
    LStart, LDepth: Integer;
    LQuote: Char;
  begin
    if (P <= Length(S)) and (S[P] = '@') then
      Inc(P);
    LStart := P;
    LDepth := 0;
    LQuote := #0;
    while P <= Length(S) do
    begin
      if LQuote <> #0 then
      begin
        if S[P] = LQuote then LQuote := #0;
        Inc(P);
        Continue;
      end;
      if CharInSet(S[P], ['''', '"']) then
      begin
        LQuote := S[P];
        Inc(P);
        Continue;
      end;
      if S[P] = '(' then Inc(LDepth)
      else if S[P] = ')' then
      begin
        //   Outer context's closing paren (depth 0 before the ')') - stop without consuming
        if LDepth = 0 then
          Break;
        Dec(LDepth);
        // After closing a filter call (depth back to 0), include ')' and check for chain
        if LDepth = 0 then
        begin
          Inc(P); // consume the ')'
          // If next char is '.' this is a chained call like .trim().uppercase() - continue
          if (P <= Length(S)) and (S[P] = '.') then
            Continue;
          Break; // no chain, stop here
        end;
      end;

      if LDepth = 0 then
      begin
        if not CharInSet(S[P], ['A'..'Z', 'a'..'z', '0'..'9', '_', '.', '@']) then
          Break;
      end;
      Inc(P);
    end;
    Result := Copy(S, LStart, P - LStart);
  end;

  function ParsePrimary: TValue;
  var
    LName: string;
    LArgs: TList<TValue>;
    LStartPos: Integer;
  begin
    SkipSpaces;
    if P > Length(S) then
      Exit(TValue.Empty);

    if S[P] = '(' then
    begin
      Inc(P);
      Result := ParseExpression;
      SkipSpaces;
      if (P <= Length(S)) and (S[P] = ')') then
        Inc(P);
      Exit;
    end;

    if CharInSet(S[P], ['''', '"']) then
      Exit(ParseStringLiteral);

    if CharInSet(S[P], ['0'..'9']) then
    begin
      LName := ParseNameToken;
      if Pos('.', LName) > 0 then
        Exit(StrToFloatDef(LName, 0, TFormatSettings.Invariant));
      Exit(StrToInt64Def(LName, 0));
    end;

    LStartPos := P;
    LName := ParseNameToken;
    SkipSpaces;
    if (P <= Length(S)) and (S[P] = '(') and (Pos('.', LName) = 0) then
    begin
      Inc(P);
      LArgs := TList<TValue>.Create;
      try
        SkipSpaces;
        if (P <= Length(S)) and (S[P] <> ')') then
        begin
          repeat
            LArgs.Add(ParseExpression);
            SkipSpaces;
            if (P <= Length(S)) and (S[P] = ',') then
            begin
              Inc(P);
              SkipSpaces;
            end
            else
              Break;
          until False;
        end;
        if (P <= Length(S)) and (S[P] = ')') then
          Inc(P);
        Result := ExecuteInlineFunction(LName, LArgs.ToArray, AContext);
      finally
        LArgs.Free;
      end;
      Exit;
    end;

    P := LStartPos;
    LName := ParsePathToken;
    Result := ResolvePathValue(LName, AContext);
  end;

  function ParseUnary: TValue;
  var
    LNum: Double;
  begin
    SkipSpaces;
    if (P <= Length(S)) and (S[P] = '-') then
    begin
      Inc(P);
      Result := ParseUnary;
      if TryAsNumber(Result, LNum) then
        Result := -LNum
      else
        Result := TValue.Empty;
      Exit;
    end;
    Result := ParsePrimary;
  end;

  function ParseMulDiv: TValue;
  var
    LLeft, LRight: TValue;
    LOp: Char;
    LNum1, LNum2: Double;
  begin
    LLeft := ParseUnary;
    while True do
    begin
      SkipSpaces;
      if (P > Length(S)) or (not CharInSet(S[P], ['*', '/'])) then
        Break;
      LOp := S[P];
      Inc(P);
      LRight := ParseUnary;
      LNum1 := 0;
      LNum2 := 0;
      TryAsNumber(LLeft, LNum1);
      TryAsNumber(LRight, LNum2);
      if LOp = '*' then
        LLeft := LNum1 * LNum2
      else if LNum2 <> 0 then
        LLeft := LNum1 / LNum2
      else
        LLeft := 0;
    end;
    Result := LLeft;
  end;

  function ParseAddSub: TValue;
  var
    LLeft, LRight: TValue;
    LOp: Char;
    LNum1, LNum2: Double;
    LIsNum1, LIsNum2: Boolean;
  begin
    LLeft := ParseMulDiv;
    while True do
    begin
      SkipSpaces;
      if (P > Length(S)) or (not CharInSet(S[P], ['+', '-'])) then
        Break;
      LOp := S[P];
      Inc(P);
      LRight := ParseMulDiv;
      LIsNum1 := TryAsNumber(LLeft, LNum1);
      LIsNum2 := TryAsNumber(LRight, LNum2);
      if (LOp = '+') and (not (LIsNum1 and LIsNum2)) then
        LLeft := ValueToString(LLeft) + ValueToString(LRight)
      else if LOp = '+' then
        LLeft := LNum1 + LNum2
      else
        LLeft := LNum1 - LNum2;
    end;
    Result := LLeft;
  end;

  function ParseComparison: TValue;
  var
    LLeft, LRight: TValue;
    LOp: string;
    LNum1, LNum2: Double;
    LIsNum1, LIsNum2: Boolean;
  begin
    LLeft := ParseAddSub;
    SkipSpaces;
    if P > Length(S) then
      Exit(LLeft);

    LOp := '';
    if (P < Length(S)) and (((S[P] = '>') and (S[P + 1] = '=')) or ((S[P] = '<') and (S[P + 1] = '=')) or
       ((S[P] = '=') and (S[P + 1] = '=')) or ((S[P] = '!') and (S[P + 1] = '='))) then
    begin
      LOp := Copy(S, P, 2);
      Inc(P, 2);
    end
    else if CharInSet(S[P], ['>', '<']) then
    begin
      LOp := S[P];
      Inc(P);
    end;

    if LOp = '' then
      Exit(LLeft);

    LRight := ParseAddSub;
    LIsNum1 := TryAsNumber(LLeft, LNum1);
    LIsNum2 := TryAsNumber(LRight, LNum2);

    if LIsNum1 and LIsNum2 then
    begin
      if LOp = '>' then Exit(LNum1 > LNum2);
      if LOp = '<' then Exit(LNum1 < LNum2);
      if LOp = '>=' then Exit(LNum1 >= LNum2);
      if LOp = '<=' then Exit(LNum1 <= LNum2);
      if LOp = '==' then Exit(LNum1 = LNum2);
      if LOp = '!=' then Exit(LNum1 <> LNum2);
    end
    else
    begin
      if LOp = '==' then Exit(SameText(ValueToString(LLeft), ValueToString(LRight)));
      if LOp = '!=' then Exit(not SameText(ValueToString(LLeft), ValueToString(LRight)));
      if LOp = '>' then Exit(ValueToString(LLeft) > ValueToString(LRight));
      if LOp = '<' then Exit(ValueToString(LLeft) < ValueToString(LRight));
      if LOp = '>=' then Exit(ValueToString(LLeft) >= ValueToString(LRight));
      if LOp = '<=' then Exit(ValueToString(LLeft) <= ValueToString(LRight));
    end;

    Result := False;
  end;

  function ParseExpression: TValue;
  begin
    Result := ParseComparison;
  end;

begin
  S := System.SysUtils.Trim(AExpr);
  P := 1;
  Result := ParseExpression;
end;

function TDextTemplateEngine.ResolveValue(const AExpr: string; const AContext: ITemplateContext; out AIsRaw, AIsEncoded: Boolean): TValue;
var
  LExpr: string;
  LParts: TArray<string>;
  LCurrent: TValue;
  I, LParenPos: Integer;
  LFilterName, LArgsText: string;
  LArgs: TArray<TValue>;
  LInt64: Int64;
  LFloat: Double;
  LHasAdvanced: TTemplateFilterFunc;
  LLegacyFilter: System.SysUtils.TFunc<string, string>;
begin
  AIsRaw := False;
  AIsEncoded := False;
  LExpr := System.SysUtils.Trim(AExpr);
  if LExpr = '' then
    Exit(TValue.Empty);

  if StartsText('raw(', LExpr) and LExpr.EndsWith(')') then
  begin
    AIsRaw := True;
    LExpr := Copy(LExpr, 5, Length(LExpr) - 5);
  end
  else if StartsText('encoded(', LExpr) and LExpr.EndsWith(')') then
  begin
    AIsEncoded := True;
    LExpr := Copy(LExpr, 9, Length(LExpr) - 9);
  end;

  if StartsText('@', LExpr) and (not StartsText('@@', LExpr)) then
    LExpr := Copy(LExpr, 2, MaxInt);

  if (Length(LExpr) >= 2) and (((LExpr[1] = '''') and (LExpr[Length(LExpr)] = '''')) or
     ((LExpr[1] = '"') and (LExpr[Length(LExpr)] = '"'))) then
    Exit(UnquoteString(LExpr));

  if SameText(LExpr, 'true') then
    Exit(True);
  if SameText(LExpr, 'false') then
    Exit(False);

  if TryStrToInt64(LExpr, LInt64) then
    Exit(LInt64);
  if TryStrToFloat(LExpr, LFloat, TFormatSettings.Invariant) then
    Exit(LFloat);

  if HasTopLevelOperator(LExpr) or (System.Pos('(', LExpr) > 0) then
    Exit(EvaluateInlineExpression(LExpr, AContext));

  LParts := SplitTopLevel(LExpr, '|');
  if Length(LParts) = 0 then
    Exit(TValue.Empty);
 
  // Resolve the first part as a property path
  LCurrent := ResolvePathValue(System.SysUtils.Trim(LParts[0]), AContext);
 
  // Apply subsequent parts as filters
  for I := 1 to High(LParts) do
  begin
    LFilterName := System.SysUtils.Trim(LParts[I]);
    LParenPos := System.Pos('(', LFilterName);
    if LParenPos > 0 then
    begin
      LArgsText := Copy(LFilterName, LParenPos + 1, MaxInt);
      LFilterName := Copy(LFilterName, 1, LParenPos - 1);
      if EndsText(')', LArgsText) then
        LArgsText := Copy(LArgsText, 1, Length(LArgsText) - 1);
      LArgs := ParseFilterArguments(LArgsText, AContext);
      if SameText(LFilterName, 'raw') then
        AIsRaw := True
      else if SameText(LFilterName, 'encoded') then
        AIsEncoded := True;
      LCurrent := ApplyAdvancedFilter(LFilterName, LCurrent, LArgs);
    end
    else
    begin
      if FAdvancedFilters.TryGetValue(LFilterName, LHasAdvanced) or FFilters.TryGetValue(LFilterName, LLegacyFilter) then
        LCurrent := ApplyAdvancedFilter(LFilterName, LCurrent, [])
      else
        LCurrent := ResolveMemberValue(LCurrent, LFilterName, AContext);
    end;
  end;
 
  Result := LCurrent;
end;



procedure TDextTemplateEngine.SkipWhitespace(const AText: string; var APos: Integer);
begin
  // This version is used in non-parsing contexts (like layout reading)
  // which don't track pos. I'll add an overload or just ignore pos here.
  while (APos <= Length(AText)) and CharInSet(AText[APos], [' ', #9, #13, #10]) do
    Inc(APos);
end;

procedure TDextTemplateEngine.SkipLineBreak(const AText: string; var APos: Integer);
begin
  if (APos <= Length(AText)) and (AText[APos] = #13) then Inc(APos);
  if (APos <= Length(AText)) and (AText[APos] = #10) then Inc(APos);
end;

function TDextTemplateEngine.ReadBalanced(const AText: string; var APos: Integer; AOpen, AClose: Char): string;
var
  LDepth: Integer;
  LStart: Integer;
  LQuote: Char;
begin
  Result := '';
  if (APos > Length(AText)) or (AText[APos] <> AOpen) then
    Exit;

  LDepth := 1;
  LQuote := #0;
  LStart := APos + 1;
  Inc(APos);
  while (APos <= Length(AText)) and (LDepth > 0) do
  begin
    if LQuote <> #0 then
    begin
      if AText[APos] = LQuote then
        LQuote := #0;
      Inc(APos);
      Continue;
    end;

    if CharInSet(AText[APos], ['''', '"']) then
      LQuote := AText[APos]
    else if AText[APos] = AOpen then
      Inc(LDepth)
    else if AText[APos] = AClose then
      Dec(LDepth);

    Inc(APos);
  end;

  Result := Copy(AText, LStart, APos - LStart - 1);
end;

function TDextTemplateEngine.CaptureUntil(const AText: string; var APos: Integer; const AEndMarker: string): string;
var
  LEndPos: Integer;
  LLine, LCol, I: Integer;
begin
  LEndPos := Pos(AEndMarker, AText, APos);
  if LEndPos = 0 then
  begin
    LLine := 1;
    LCol := 1;
    for I := 1 to APos - 1 do
      if AText[I] = #10 then begin Inc(LLine); LCol := 1; end else Inc(LCol);
    raise ETemplateException.Create('Missing closing marker ' + AEndMarker,
      TSourcePos.Create(LLine, LCol), GetTemplateSnippet(AText, APos));
  end;
  Result := Copy(AText, APos, LEndPos - APos);
  APos := LEndPos + Length(AEndMarker);
end;

function TDextTemplateEngine.GetTemplateSnippet(const ATemplate: string; APos: Integer): string;
var
  LStart, LEnd: Integer;
begin
  LStart := Max(1, APos - 20);
  LEnd := Min(Length(ATemplate), APos + 20);
  Result := Copy(ATemplate, LStart, LEnd - LStart + 1);
  if LStart > 1 then Result := '...' + Result;
  if LEnd < Length(ATemplate) then Result := Result + '...';
end;

function TDextTemplateEngine.Parse(const ATemplate: string): TTemplateNodeList;
var
  LPos: Integer;
  LCurrentLine, LCurrentCol: Integer;
  ATrimNext: Boolean;

  procedure UpdatePos(AOldPos, ANewPos: Integer);
  var I: Integer;
  begin
    for I := AOldPos to ANewPos - 1 do
    begin
      if (I >= 1) and (I <= Length(ATemplate)) then
      begin
        if ATemplate[I] = #10 then
        begin
          Inc(LCurrentLine);
          LCurrentCol := 1;
        end
        else
          Inc(LCurrentCol);
      end;
    end;
  end;

  function GetCurrentPos: TSourcePos;
  begin
    Result := TSourcePos.Create(LCurrentLine, LCurrentCol);
  end;

  procedure TrimTrailingWhitespaceFromLastText(ATarget: TTemplateNodeList);
  var
    LNode: TTemplateNode;
  begin
    if ATarget.Count = 0 then
      Exit;
    LNode := ATarget.Last;
    if LNode is TTextNode then
      TTextNode(LNode).FText := System.SysUtils.TrimRight(TTextNode(LNode).FText);
  end;

  function ConsumeTrimRight(const AText: string; var ACurrentPos: Integer): Boolean;
  var LOldPos: Integer;
  begin
    Result := False;
    if (ACurrentPos <= Length(AText)) and (AText[ACurrentPos] = '~') then
    begin
      Result := True;
      LOldPos := ACurrentPos;
      Inc(ACurrentPos);
      while (ACurrentPos <= Length(AText)) and CharInSet(AText[ACurrentPos], [' ', #9, #13, #10]) do
        Inc(ACurrentPos);
      UpdatePos(LOldPos, ACurrentPos);
    end;
  end;

  procedure ParseBlock(ATarget: TTemplateNodeList; const AEndMarkers: TArray<string>; const ABeginPos: TSourcePos; var ATrimNext: Boolean);
  var
    LNextAt: Integer;
    LMarker: string;
    LContent: string;
    LNode: TConditionalNode;
    LLoopNode: TLoopNode;
    LSwitchNode: TSwitchNode;
    LCaseNode: TSwitchCase;
    LSetName, LSetExpr: string;
    LParts: TArray<string>;
    LRequired: Boolean;
    LEqPos: Integer;
    LOldPos: Integer;
    LTrimLeft: Boolean;
    LCallName: string;
    LCallArgs: string;
    LTextStart: Integer;
    LDirectivePos: TSourcePos;
    LNext: Integer;
    LMatchName: string;
    LReportMarkers: TArray<string>;
    LHasElse, LHasEndif: Boolean;
    LM: string;
    LExpectedList: string;
    LChar: Char;
    LPseudoStart: Integer;
    LPseudoName: string;

    function MatchCommand(const ACommand: string; AConsume: Boolean; ABoundaryCheck: Boolean = True): Boolean;
    var
      LNextChar: Char;
    begin
      Result := SameText(Copy(ATemplate, LPos, Length(ACommand)), ACommand);
      if Result then
      begin
        if ABoundaryCheck and (LPos + Length(ACommand) <= Length(ATemplate)) then
        begin
          LNextChar := ATemplate[LPos + Length(ACommand)];
          if LNextChar.IsLetterOrDigit or (LNextChar = '_') then
          begin
            Result := False;
            Exit;
          end;
        end;

        if AConsume then
        begin
          LOldPos := LPos;
          Inc(LPos, Length(ACommand));
          UpdatePos(LOldPos, LPos);
        end;
      end;
    end;

  begin
    while LPos <= Length(ATemplate) do
    begin
      for LMarker in AEndMarkers do
      begin
        // Boundary check is false for markers to allow @elseText
        if MatchCommand('@' + LMarker, False, False) then
        begin
          Exit;
        end;
      end;

      LNextAt := Pos('@', ATemplate, LPos);
      if LNextAt = 0 then
      begin
        if LPos <= Length(ATemplate) then
        begin
          LContent := Copy(ATemplate, LPos, MaxInt);
          if ATrimNext then
            LContent := System.SysUtils.TrimLeft(LContent);
          ATarget.Add(TTextNode.CreateAt(Self, GetCurrentPos, LContent));
          UpdatePos(LPos, Length(ATemplate) + 1);
          LPos := Length(ATemplate) + 1;
        end;
        
        if Length(AEndMarkers) > 0 then
        begin
          // When both 'else' and 'endif' are markers, only report 'endif'
          // because @else is optional - the user must close with @endif
          LReportMarkers := AEndMarkers;
          LHasElse := System.StrUtils.MatchStr('else', LReportMarkers);
          LHasEndif := System.StrUtils.MatchStr('endif', LReportMarkers);
          if LHasElse and LHasEndif then
          begin
            SetLength(LReportMarkers, 0);
            for LM in AEndMarkers do
              if LM <> 'else' then
              begin
                SetLength(LReportMarkers, Length(LReportMarkers) + 1);
                LReportMarkers[High(LReportMarkers)] := LM;
              end;
          end;
          LExpectedList := string.Join(' or @', LReportMarkers);
          raise ETemplateException.Create('Missing closing marker @' + LExpectedList, ABeginPos, '');
        end;
        Exit;
      end;

      if (LNextAt > LPos) then
      begin
        LContent := Copy(ATemplate, LPos, LNextAt - LPos);
        if ATrimNext then
        begin
          LContent := System.SysUtils.TrimLeft(LContent);
          ATrimNext := False;
        end;
        ATarget.Add(TTextNode.CreateAt(Self, GetCurrentPos, LContent));
        UpdatePos(LPos, LNextAt);
        LPos := LNextAt;
        Continue; 
      end;

      LOldPos := LPos;
      LDirectivePos := GetCurrentPos;
      LPos := LNextAt; 
      UpdatePos(LOldPos, LPos);

      if (LPos <= Length(ATemplate)) and (ATemplate[LPos] = '@') then
      begin
        LChar := ATemplate[LPos];
        if (LChar = '{') and (LPos < Length(ATemplate)) and (ATemplate[LPos+1] = '{') then
        begin
          LNext := LPos + 2;
          LMatchName := '';
          while (LNext <= Length(ATemplate)) and CharInSet(ATemplate[LNext], ['a'..'z', 'A'..'Z']) do
          begin
            LMatchName := LMatchName + ATemplate[LNext];
            Inc(LNext);
          end;

          if not (SameText(LMatchName, 'index') or SameText(LMatchName, 'count') or
                  SameText(LMatchName, 'first') or SameText(LMatchName, 'last') or
                  SameText(LMatchName, 'odd') or SameText(LMatchName, 'even')) then
          begin
            ATarget.Add(TTextNode.CreateAt(Self, GetCurrentPos, '@'));
            Inc(LPos, 2);
            Continue;
          end;
        end;
        Inc(LPos); 
      if (LPos <= Length(ATemplate)) and (ATemplate[LPos] = '~') then
      begin
        if (ATarget.Count > 0) and (ATarget.Last is TTextNode) then
          TTextNode(ATarget.Last).FText := System.SysUtils.TrimRight(TTextNode(ATarget.Last).FText);
        Inc(LPos);
      end;
        UpdatePos(LPos - 1, LPos);
      end;

      LTrimLeft := False;
      if (LPos <= Length(ATemplate)) and (ATemplate[LPos] = '~') then
      begin
        LTrimLeft := True;
        LOldPos := LPos;
        Inc(LPos);
        UpdatePos(LOldPos, LPos);
      end;
      if LTrimLeft then
        TrimTrailingWhitespaceFromLastText(ATarget);

      if (LPos <= Length(ATemplate)) and (ATemplate[LPos] = '@') then
      begin
        ATarget.Add(TTextNode.CreateAt(Self, GetCurrentPos, '@'));
        LOldPos := LPos;
        Inc(LPos);
        UpdatePos(LOldPos, LPos);
        Continue;
      end;

      if (LPos <= Length(ATemplate)) and (ATemplate[LPos] = '*') then
      begin
        LOldPos := LPos;
        Inc(LPos);
        UpdatePos(LOldPos, LPos);
        LContent := CaptureUntil(ATemplate, LPos, '*@');
        UpdatePos(LOldPos + 1, LPos);
        Continue;
      end;

      if MatchCommand('if', True) then
      begin
        SkipWhitespace(ATemplate, LPos);
        LOldPos := LPos;
        LContent := ReadBalanced(ATemplate, LPos, '(', ')');
        UpdatePos(LOldPos, LPos);
        LNode := TConditionalNode.CreateAt(Self, LDirectivePos, LContent);
        ATarget.Add(LNode);
        SkipLineBreak(ATemplate, LPos);
        ParseBlock(LNode.TrueNodes, ['else', 'endif'], LDirectivePos, ATrimNext);
        if MatchCommand('@else', True, False) then
        begin
          ATrimNext := ConsumeTrimRight(ATemplate, LPos);
          SkipLineBreak(ATemplate, LPos);
          ParseBlock(LNode.FalseNodes, ['endif'], LDirectivePos, ATrimNext);
        end;
        if MatchCommand('@endif', True, False) then
        begin
          ATrimNext := ConsumeTrimRight(ATemplate, LPos);
          if ATrimNext then
          begin
            if LNode.FalseNodes.Count > 0 then
              TrimTrailingWhitespaceFromLastText(LNode.FalseNodes)
            else
              TrimTrailingWhitespaceFromLastText(LNode.TrueNodes);
          end;
          SkipLineBreak(ATemplate, LPos);
        end;
        ATrimNext := ConsumeTrimRight(ATemplate, LPos);
        Continue;
      end;
  
      if MatchCommand('for', True) then
      begin
        SkipWhitespace(ATemplate, LPos);
        LContent := ReadBalanced(ATemplate, LPos, '(', ')');
        LParts := LContent.Split([';'], TStringSplitOptions.ExcludeEmpty);
        if Length(LParts) >= 3 then
          LLoopNode := TLoopNode.CreateAt(Self, LDirectivePos, LParts[0], LParts[1] + ';' + LParts[2])
        else
          raise EInvalidOpException.CreateFmt('Invalid for expression: %s', [LContent]);
 
        ATarget.Add(LLoopNode);
        SkipLineBreak(ATemplate, LPos);
        ParseBlock(LLoopNode.Nodes, ['else', 'endfor'], LDirectivePos, ATrimNext);
        if MatchCommand('@else', True, False) then
        begin
          ATrimNext := ConsumeTrimRight(ATemplate, LPos);
          SkipLineBreak(ATemplate, LPos);
          ParseBlock(LLoopNode.ElseNodes, ['endfor'], GetCurrentPos, ATrimNext);
        end;
        if MatchCommand('@endfor', True, False) then
        begin
          ATrimNext := ConsumeTrimRight(ATemplate, LPos);
          SkipLineBreak(ATemplate, LPos);
        end;
        ATrimNext := ConsumeTrimRight(ATemplate, LPos);
        Continue;
      end;

      if MatchCommand('foreach', True) then
      begin
        SkipWhitespace(ATemplate, LPos);
        LOldPos := LPos;
        LContent := ReadBalanced(ATemplate, LPos, '(', ')');
        UpdatePos(LOldPos, LPos);
        LParts := LContent.Split([' '], TStringSplitOptions.ExcludeEmpty);
        if (Length(LParts) >= 4) and SameText(LParts[0], 'var') then
          LLoopNode := TLoopNode.CreateAt(Self, LDirectivePos, LParts[1], LParts[3])
        else if Length(LParts) >= 3 then
          LLoopNode := TLoopNode.CreateAt(Self, LDirectivePos, LParts[0], LParts[2])
        else
          raise EInvalidOpException.CreateFmt('Invalid foreach expression: %s', [LContent]);

        ATarget.Add(LLoopNode);
        SkipLineBreak(ATemplate, LPos);
        ParseBlock(LLoopNode.Nodes, ['else', 'endforeach'], LDirectivePos, ATrimNext);
        if MatchCommand('@else', True, False) then
        begin
          ATrimNext := ConsumeTrimRight(ATemplate, LPos);
          SkipLineBreak(ATemplate, LPos);
          ParseBlock(LLoopNode.ElseNodes, ['endforeach'], GetCurrentPos, ATrimNext);
        end;
        if MatchCommand('@endforeach', True, False) then
        begin
          ATrimNext := ConsumeTrimRight(ATemplate, LPos);
          SkipLineBreak(ATemplate, LPos);
        end;
        ATrimNext := ConsumeTrimRight(ATemplate, LPos);
        Continue;
      end;
 
      if MatchCommand('set', True) then
      begin
        SkipWhitespace(ATemplate, LPos);
        if (LPos <= Length(ATemplate)) and (ATemplate[LPos] = '(') then
        begin
          LContent := ReadBalanced(ATemplate, LPos, '(', ')');
        end
        else
        begin
          LTextStart := LPos;
          while (LPos <= Length(ATemplate)) and (ATemplate[LPos] <> #13) and (ATemplate[LPos] <> #10) do
            Inc(LPos);
          LContent := System.SysUtils.Trim(Copy(ATemplate, LTextStart, LPos - LTextStart));
        end;
 
        LEqPos := System.Pos('=', LContent);
        if LEqPos > 0 then
        begin
          LSetName := System.SysUtils.Trim(Copy(LContent, 1, LEqPos - 1));
          LSetExpr := System.SysUtils.Trim(Copy(LContent, LEqPos + 1, MaxInt));
          if StartsText('@', LSetExpr) then
            LSetExpr := Copy(LSetExpr, 2, MaxInt);
          ATarget.Add(TSetNode.CreateAt(Self, LDirectivePos, LSetName, LSetExpr));
        end;
        SkipLineBreak(ATemplate, LPos);
        ATrimNext := ConsumeTrimRight(ATemplate, LPos);
        Continue;
      end;
 
      if MatchCommand('continue', True) then
      begin
        ATarget.Add(TContinueNode.CreateAt(Self, LDirectivePos));
        ATrimNext := ConsumeTrimRight(ATemplate, LPos);
        Continue;
      end;
 
      if MatchCommand('break', True) then
      begin
        ATarget.Add(TBreakNode.CreateAt(Self, LDirectivePos));
        ATrimNext := ConsumeTrimRight(ATemplate, LPos);
        Continue;
      end;
 
      if MatchCommand('switch', True) then
      begin
        SkipWhitespace(ATemplate, LPos);
        LOldPos := LPos;
        LContent := ReadBalanced(ATemplate, LPos, '(', ')');
        UpdatePos(LOldPos, LPos);
        LSwitchNode := TSwitchNode.CreateAt(Self, LDirectivePos, LContent);
        ATarget.Add(LSwitchNode);
        SkipWhitespace(ATemplate, LPos);
 
        while LPos <= Length(ATemplate) do
        begin
          if MatchCommand('@endswitch', True, False) then
          begin
            ATrimNext := ConsumeTrimRight(ATemplate, LPos);
            SkipLineBreak(ATemplate, LPos);
            Break;
          end;
 
          if MatchCommand('@case', True, False) then
          begin
            SkipWhitespace(ATemplate, LPos);
            LOldPos := LPos;
            LContent := ReadBalanced(ATemplate, LPos, '(', ')');
            UpdatePos(LOldPos, LPos);
            LCaseNode := TSwitchCase.Create(LContent);
            LSwitchNode.Cases.Add(LCaseNode);
            SkipWhitespace(ATemplate, LPos);
            ParseBlock(LCaseNode.Nodes, ['case', 'default', 'endswitch'], LDirectivePos, ATrimNext);
            Continue;
          end;
 
          if MatchCommand('@default', True, False) then
          begin
            ATrimNext := ConsumeTrimRight(ATemplate, LPos);
            SkipLineBreak(ATemplate, LPos);
            ParseBlock(LSwitchNode.DefaultNodes, ['endswitch'], LDirectivePos, ATrimNext);
            Continue;
          end;
 
          Inc(LPos);
        end;
        ATrimNext := ConsumeTrimRight(ATemplate, LPos);
        Continue;
      end;
 
      if MatchCommand('partial', True) or MatchCommand('include', True) then
      begin
        SkipWhitespace(ATemplate, LPos);
        LContent := ReadBalanced(ATemplate, LPos, '(', ')');
        LCallArgs := LContent;
        LParts := SplitTopLevel(LCallArgs, ',');
        if Length(LParts) > 0 then
        begin
          LCallName := UnquoteString(LParts[0]);
          if Length(LParts) > 1 then
            LCallArgs := Copy(LCallArgs, Length(LParts[0]) + 2, MaxInt)
          else
            LCallArgs := '';
          ATarget.Add(TPartialNode.CreateAt(Self, GetCurrentPos, LCallName, LCallArgs));
        end;
        ATrimNext := ConsumeTrimRight(ATemplate, LPos);
        Continue;
      end;
 
      if StartsText('renderSection', Copy(ATemplate, LPos, 13)) then
      begin
        LOldPos := LPos;
        Inc(LPos, 13);
        SkipWhitespace(ATemplate, LPos);
        LContent := ReadBalanced(ATemplate, LPos, '(', ')');
        UpdatePos(LOldPos, LPos);
        LParts := SplitTopLevel(LContent, ',');
        LCallName := UnquoteString(LParts[0]);
        LRequired := True;
        if Length(LParts) > 1 then
          LRequired := not ContainsText(LParts[1], 'false');
        ATarget.Add(TRenderSectionNode.CreateAt(Self, GetCurrentPos, LCallName, LRequired));
        ATrimNext := ConsumeTrimRight(ATemplate, LPos);
        Continue;
      end;
 
      if StartsText('renderBody', Copy(ATemplate, LPos, 10)) then
      begin
        LOldPos := LPos;
        Inc(LPos, 10);
        ATarget.Add(TRenderBodyNode.CreateAt(Self, GetCurrentPos));
        ATrimNext := ConsumeTrimRight(ATemplate, LPos);
        Continue;
      end;
 
      if (LPos <= Length(ATemplate)) and (ATemplate[LPos] = '>') then
      begin
        LOldPos := LPos;
        Inc(LPos);
        SkipWhitespace(ATemplate, LPos);
        LTextStart := LPos;
        while (LPos <= Length(ATemplate)) and (ATemplate[LPos] <> #13) and (ATemplate[LPos] <> #10) do
          Inc(LPos);
        LContent := System.SysUtils.Trim(Copy(ATemplate, LTextStart, LPos - LTextStart));
        LCallArgs := ExtractCallArguments(LContent, LCallName);
        ATarget.Add(TMacroCallNode.CreateAt(Self, GetCurrentPos, LCallName, LCallArgs));
        ATrimNext := ConsumeTrimRight(ATemplate, LPos);
        Continue;
      end;
 
      if StartsText('raw', Copy(ATemplate, LPos, 3)) then
      begin
        Inc(LPos, 3);
        SkipWhitespace(ATemplate, LPos);
        if (LPos <= Length(ATemplate)) and (ATemplate[LPos] = '(') then
        begin
          LOldPos := LPos;
          LContent := ReadBalanced(ATemplate, LPos, '(', ')');
          UpdatePos(LOldPos, LPos);
          ATarget.Add(TExpressionNode.CreateAt(Self, GetCurrentPos, LContent, True));
        end
        else
        begin
          SkipLineBreak(ATemplate, LPos);
          LOldPos := LPos;
          LContent := CaptureUntil(ATemplate, LPos, '@endraw');
          UpdatePos(LOldPos, LPos);
          ATarget.Add(TTextNode.CreateAt(Self, GetCurrentPos, LContent));
          ATrimNext := ConsumeTrimRight(ATemplate, LPos);
        end;
        ATrimNext := ConsumeTrimRight(ATemplate, LPos);
        Continue;
      end;
 
      if (LPos <= Length(ATemplate)) and (ATemplate[LPos] = '(') then
      begin
        LOldPos := LPos;
        LContent := ReadBalanced(ATemplate, LPos, '(', ')');
        UpdatePos(LOldPos, LPos);
        ATarget.Add(TExpressionNode.CreateAt(Self, GetCurrentPos, LContent, False));
        ATrimNext := ConsumeTrimRight(ATemplate, LPos);
        Continue;
      end;

      LOldPos := LPos;
      while (LPos <= Length(ATemplate)) do
      begin
        LChar := ATemplate[LPos];
        if CharInSet(LChar, [#13, #10, ' ', '<', '>', '/', '\', ';', ':', ',', '=', '+', '-', '*', '!', '?', '|', '~', ')', ']', '''', '"']) then
           Break;

        if (LPos > LOldPos) and (LChar = '@') then
        begin
          if (LPos < Length(ATemplate)) and (ATemplate[LPos + 1] = '@') then
          begin
            LPseudoStart := LPos + 2;
            LPseudoName := '';
            while (LPseudoStart <= Length(ATemplate)) and CharInSet(ATemplate[LPseudoStart], ['a'..'z', 'A'..'Z']) do
            begin
              LPseudoName := LPseudoName + ATemplate[LPseudoStart];
              Inc(LPseudoStart);
            end;
            if SameText(LPseudoName, 'index') or SameText(LPseudoName, 'count') or
               SameText(LPseudoName, 'first') or SameText(LPseudoName, 'last') or
               SameText(LPseudoName, 'odd') or SameText(LPseudoName, 'even') then
            begin
              Inc(LPos); 
              Continue; 
            end;
          end;
          Break;
        end;

        if (LChar = '(') then
        begin
             if (LPos + 1 <= Length(ATemplate)) and (ATemplate[LPos+1] = '@') then
             begin
                  if (LPos + 2 > Length(ATemplate)) or (ATemplate[LPos+2] <> '@') then
                    Break; 
             end;
             
             ReadBalanced(ATemplate, LPos, '(', ')');
             Continue;
        end;
        if (LChar = '[') then
        begin
             ReadBalanced(ATemplate, LPos, '[', ']');
             Continue;
        end;
        
        Inc(LPos);
      end;

      LContent := Copy(ATemplate, LOldPos, LPos - LOldPos);
      UpdatePos(LOldPos, LPos);
      ATarget.Add(TExpressionNode.CreateAt(Self, GetCurrentPos, LContent, False));
      
      if (LPos <= Length(ATemplate)) and (ATemplate[LPos] = '~') then
      begin
        LOldPos := LPos;
        ATrimNext := ConsumeTrimRight(ATemplate, LPos);
        UpdatePos(LOldPos, LPos);
      end;
      Continue;
    end;
  end;

begin
  LCurrentLine := 1;
  LCurrentCol := 1;
  LPos := 1;
  Result := TCollections.CreateList<TTemplateNode>(True);
  try
    ATrimNext := False;
    ParseBlock(Result, [], GetCurrentPos, ATrimNext);
  except
    Result := nil;
    raise;
  end;
end;

function TDextTemplateEngine.GetOrParseTemplate(const ATemplate: string): TTemplateNodeList;
begin
  if not FTemplateAstCache.TryGetValue(ATemplate, Result) then
  begin
    Result := Parse(ATemplate);
    FTemplateAstCache.Add(ATemplate, Result);
  end;
end;

function TDextTemplateEngine.ParseDocument(const ATemplate: string): TTemplateDocument;
var
  LPos, LBodyStart: Integer;
  LName, LArgs, LInner: string;
  LDef: TInlineTemplateDefinition;
  LBuilder: TStringBuilder;
  LParts: TArray<string>;
  I: Integer;
begin
  Result := TTemplateDocument.Create;
  LPos := 1;
  LBodyStart := 1;

  while LPos <= Length(ATemplate) do
  begin
    if (ATemplate[LPos] = '@') and (LPos < Length(ATemplate)) and (ATemplate[LPos + 1] <> '@') then
    begin
      if StartsText('@layout', Copy(ATemplate, LPos, 7)) or StartsText('@extends', Copy(ATemplate, LPos, 8)) or
         StartsText('@section', Copy(ATemplate, LPos, 8)) or StartsText('@block', Copy(ATemplate, LPos, 6)) or
         StartsText('@define', Copy(ATemplate, LPos, 7)) then
      begin
        if LPos > LBodyStart then
          Result.BodyText := Result.BodyText + Copy(ATemplate, LBodyStart, LPos - LBodyStart);

        Inc(LPos);

        if StartsText('layout', Copy(ATemplate, LPos, 6)) then
        begin
          Inc(LPos, 6);
          SkipWhitespace(ATemplate, LPos);
          Result.LayoutName := UnquoteString(ReadBalanced(ATemplate, LPos, '(', ')'));
        end
        else if StartsText('extends', Copy(ATemplate, LPos, 7)) then
        begin
          Inc(LPos, 7);
          SkipWhitespace(ATemplate, LPos);
          Result.LayoutName := UnquoteString(ReadBalanced(ATemplate, LPos, '(', ')'));
        end
        else if StartsText('section', Copy(ATemplate, LPos, 7)) then
        begin
          Inc(LPos, 7);
          SkipWhitespace(ATemplate, LPos);
          LName := UnquoteString(ReadBalanced(ATemplate, LPos, '(', ')'));
          SkipLineBreak(ATemplate, LPos);
          LInner := CaptureUntil(ATemplate, LPos, '@endsection');
          LBuilder := TStringBuilder.Create;
          LBuilder.Append(LInner);
          Result.Sections.AddOrSetValue(LName, LBuilder);
        end
        else if StartsText('block', Copy(ATemplate, LPos, 5)) then
        begin
          Inc(LPos, 5);
          SkipWhitespace(ATemplate, LPos);
          LName := UnquoteString(ReadBalanced(ATemplate, LPos, '(', ')'));
          SkipLineBreak(ATemplate, LPos);
          LInner := CaptureUntil(ATemplate, LPos, '@endblock');
          LBuilder := TStringBuilder.Create;
          LBuilder.Append(LInner);
          Result.Sections.AddOrSetValue(LName, LBuilder);
        end
        else if StartsText('define', Copy(ATemplate, LPos, 6)) then
        begin
          Inc(LPos, 6);
          SkipWhitespace(ATemplate, LPos);
          LArgs := ReadBalanced(ATemplate, LPos, '(', ')');
          LParts := SplitTopLevel(LArgs, ',');
          LDef := TInlineTemplateDefinition.Create;
          LDef.Name := UnquoteString(LParts[0]);
          if Length(LParts) > 1 then
          begin
            SetLength(LDef.Parameters, Length(LParts) - 1);
            for I := 1 to High(LParts) do
              LDef.Parameters[I - 1] := System.SysUtils.Trim(LParts[I]);
          end;
          SkipLineBreak(ATemplate, LPos);
          LDef.Content := CaptureUntil(ATemplate, LPos, '@enddefine');
          Result.Definitions.AddOrSetValue(LDef.Name, LDef);
        end;

        SkipLineBreak(ATemplate, LPos);
        LBodyStart := LPos;
        Continue;
      end;
    end;

    Inc(LPos);
  end;

  if LBodyStart <= Length(ATemplate) then
    Result.BodyText := Result.BodyText + Copy(ATemplate, LBodyStart, MaxInt);
end;

function TDextTemplateEngine.RenderNodes(ANodes: TTemplateNodeList; const AContext: ITemplateContext): string;
var
  LNode: TTemplateNode;
  LBuilder: TStringBuilder;
begin
  LBuilder := TStringBuilder.Create;
  try
    for LNode in ANodes do
      LBuilder.Append(ResolveNodeOutput(LNode, AContext));
    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

function TDextTemplateEngine.ResolveNodeOutput(ANode: TTemplateNode; const AContext: ITemplateContext): string;
begin
  Result := ANode.Render(AContext);
end;

function TDextTemplateEngine.RenderInlineTemplate(const ATemplate: string; const AContext: ITemplateContext): string;
var
  LNodes: TTemplateNodeList;
begin
  LNodes := GetOrParseTemplate(ATemplate);
  Result := RenderNodes(LNodes, AContext);
end;

function TDextTemplateEngine.MergeSectionContent(const AChildContent, AParentContent: string): string;
begin
  if ContainsText(AChildContent, '@inherited') then
    Result := AChildContent.Replace('@inherited', AParentContent)
  else
    Result := AChildContent;
end;

function TDextTemplateEngine.ResolveTemplateName(const ACurrentTemplate, ARequestedName: string): string;
var
  LCandidates: TArray<string>;
  LBaseDir, LName: string;
  LPrefix: string;
  LCandName, LCandidate: string;
  LFinalPath: string;
begin
  if ARequestedName = '' then
    Exit('');

  if TPath.IsPathRooted(ARequestedName) then
    Exit(ARequestedName);

  LName := ARequestedName;
  SetLength(LCandidates, 0);
  if ACurrentTemplate <> '' then
  begin
    LBaseDir := ExtractFilePath(ACurrentTemplate);
    if LBaseDir <> '' then
    begin
      SetLength(LCandidates, Length(LCandidates) + 1);
      LCandidates[High(LCandidates)] := TPath.Combine(LBaseDir, LName);
    end;
  end;

  if FTemplateRoot <> '' then
  begin
    SetLength(LCandidates, Length(LCandidates) + 1);
    LCandName := TPath.Combine(FTemplateRoot, LName);
    LCandidates[High(LCandidates)] := LCandName.Replace('/', '\');
  end;

  for LPrefix in ['shared', 'components', 'layouts'] do
  begin
    SetLength(LCandidates, Length(LCandidates) + 1);
    LCandName := TPath.Combine(LPrefix, LName);
    LCandidates[High(LCandidates)] := LCandName.Replace('/', '\');
  end;

  for LCandidate in LCandidates do
  begin
    for LPrefix in ['', '.html', '.dext', '.htm'] do
    begin
      LFinalPath := LCandidate + LPrefix;
      try
        if Assigned(FTemplateLoader) then
        begin
          FTemplateLoader.Load(LFinalPath);
          Exit(LFinalPath);
        end;
      except
      end;
    end;
  end;

  Result := ARequestedName;
end;

function TDextTemplateEngine.RenderResolvedTemplate(const ATemplateName, AResolvedName: string; const AContext: ITemplateContext): string;
var
  LDocument: TTemplateDocument;
  LRootTemplate: string;
  LCopy: TInlineTemplateDefinition;
  LExistingSection: string;
  LKey: string;
  LDefinition: TInlineTemplateDefinition;
  LSectionBuilder: TStringBuilder;
begin
  LDocument := ParseDocument(FTemplateLoader.Load(AResolvedName));
  try
    if FCurrentState = nil then
      raise ETemplateException.Create('RenderState not initialized for ' + ATemplateName, TSourcePos.Create(0, 0));

    if FCurrentState.TemplateName = '' then
      FCurrentState.TemplateName := AResolvedName;

    for LKey in LDocument.Definitions.Keys do
    begin
      LDefinition := LDocument.Definitions.Items[LKey];
      LCopy := TInlineTemplateDefinition.Create;
      LCopy.Name := LDefinition.Name;
      LCopy.Content := LDefinition.Content;
      LCopy.Parameters := LDefinition.Parameters;
      FCurrentState.Definitions.AddOrSetValue(LCopy.Name, LCopy);
    end;

    if LDocument.LayoutName <> '' then
    begin
      if FCurrentState.BodyContent = '' then
        FCurrentState.BodyContent := LDocument.BodyText;

      for LKey in LDocument.Sections.Keys do
      begin
        LSectionBuilder := LDocument.Sections.Items[LKey];
        if FCurrentState.Sections.TryGetValue(LKey, LExistingSection) then
          FCurrentState.Sections.AddOrSetValue(LKey,
            MergeSectionContent(LExistingSection, LSectionBuilder.ToString))
        else
          FCurrentState.Sections.AddOrSetValue(LKey, LSectionBuilder.ToString);
      end;

      LRootTemplate := ResolveTemplateName(AResolvedName, LDocument.LayoutName);
      Result := RenderResolvedTemplate(LDocument.LayoutName, LRootTemplate, AContext);
      Exit;
    end;

    if FCurrentState.BodyContent = '' then
      FCurrentState.BodyContent := LDocument.BodyText;

    for LKey in LDocument.Sections.Keys do
    begin
      LSectionBuilder := LDocument.Sections.Items[LKey];
      if FCurrentState.Sections.TryGetValue(LKey, LExistingSection) then
        FCurrentState.Sections.AddOrSetValue(LKey,
          MergeSectionContent(LExistingSection, LSectionBuilder.ToString))
      else
        FCurrentState.Sections.AddOrSetValue(LKey, LSectionBuilder.ToString);
    end;

    Result := RenderInlineTemplate(LDocument.BodyText, AContext);
  finally
    LDocument.Free;
  end;
end;

function TDextTemplateEngine.RenderTemplateInternal(const ATemplateName: string; const AContext: ITemplateContext): string;
var
  LResolvedName: string;
begin
  if not Assigned(FTemplateLoader) then
    raise EInvalidOpException.Create('TemplateLoader is required to render named templates.');

  LResolvedName := ResolveTemplateName(FCurrentState.TemplateName, ATemplateName);
  Result := RenderResolvedTemplate(ATemplateName, LResolvedName, AContext);
end;

function TDextTemplateEngine.GetIsHtmlMode: Boolean;
begin
  Result := FIsHtmlMode;
end;

procedure TDextTemplateEngine.SetIsHtmlMode(AValue: Boolean);
begin
  FIsHtmlMode := AValue;
end;

{ TSetNode }

constructor TSetNode.Create(AEngine: TDextTemplateEngine; const AName, AExpression: string);
begin
  inherited Create(AEngine);
  FName := AName;
  FExpression := AExpression;
end;

constructor TSetNode.CreateAt(AEngine: TDextTemplateEngine; const APos: TSourcePos; const AName, AExpression: string);
begin
  inherited CreateAt(AEngine, APos);
  FName := AName;
  FExpression := AExpression;
end;

function TSetNode.Render(const AContext: ITemplateContext): string;
var
  LIsRaw: Boolean;
  LIsEncoded: Boolean;
  LValue: TValue;
begin
  LIsRaw := False;
  LIsEncoded := False;
  LValue := FEngine.ResolveValue(FExpression, AContext, LIsRaw, LIsEncoded);
  if LValue.Kind = tkClass then
    AContext.SetObject(FName, LValue.AsObject)
  else
    AContext.SetValue(FName, FEngine.ValueToString(LValue));
  Result := '';
end;

{ TContinueNode }

constructor TContinueNode.Create(AEngine: TDextTemplateEngine);
begin
  inherited Create(AEngine);
end;

constructor TContinueNode.CreateAt(AEngine: TDextTemplateEngine; const APos: TSourcePos);
begin
  inherited CreateAt(AEngine, APos);
end;

function TContinueNode.Render(const AContext: ITemplateContext): string;
begin
  raise ETemplateLoopContinue.Create('continue');
end;

{ TBreakNode }

constructor TBreakNode.Create(AEngine: TDextTemplateEngine);
begin
  inherited Create(AEngine);
end;

constructor TBreakNode.CreateAt(AEngine: TDextTemplateEngine; const APos: TSourcePos);
begin
  inherited CreateAt(AEngine, APos);
end;

function TBreakNode.Render(const AContext: ITemplateContext): string;
begin
  raise ETemplateLoopBreak.Create('break');
end;

function TDextTemplateEngine.Render(const ATemplate: string; const AContext: ITemplateContext): string;
var
  LDocument: TTemplateDocument;
  LPreviousState: TRenderState;
  LCopy: TInlineTemplateDefinition;
  LKey: string;
  LDefinition: TInlineTemplateDefinition;
begin
  LDocument := ParseDocument(ATemplate);
  try
    if LDocument.LayoutName <> '' then
    begin
      if not Assigned(FTemplateLoader) then
        raise EInvalidOpException.Create('TemplateLoader is required for @layout/@extends.');

      LPreviousState := FCurrentState;
      FCurrentState := TRenderState.Create;
      try
        FCurrentState.BodyContent := LDocument.BodyText;
        for LKey in LDocument.Sections.Keys do
          FCurrentState.Sections.AddOrSetValue(LKey, LDocument.Sections.Items[LKey].ToString);
        for LKey in LDocument.Definitions.Keys do
        begin
          LDefinition := LDocument.Definitions.Items[LKey];
          LCopy := TInlineTemplateDefinition.Create;
          LCopy.Name := LDefinition.Name;
          LCopy.Content := LDefinition.Content;
          LCopy.Parameters := LDefinition.Parameters;
          FCurrentState.Definitions.AddOrSetValue(LCopy.Name, LCopy);
        end;
        Result := RenderTemplateInternal(LDocument.LayoutName, AContext);
      finally
        FCurrentState.Free;
        FCurrentState := LPreviousState;
      end;
    end
    else
    begin
      LPreviousState := FCurrentState;
      if LPreviousState = nil then
        FCurrentState := TRenderState.Create;
      try
        for LKey in LDocument.Definitions.Keys do
        begin
          LDefinition := LDocument.Definitions.Items[LKey];
          LCopy := TInlineTemplateDefinition.Create;
          LCopy.Name := LDefinition.Name;
          LCopy.Content := LDefinition.Content;
          LCopy.Parameters := LDefinition.Parameters;
          FCurrentState.Definitions.AddOrSetValue(LCopy.Name, LCopy);
        end;
        Result := RenderInlineTemplate(LDocument.BodyText, AContext);
      finally
        if LPreviousState = nil then
          FreeAndNil(FCurrentState)
        else
          FCurrentState := LPreviousState;
      end;
    end;
  finally
    LDocument.Free;
  end;
end;

function TDextTemplateEngine.RenderTemplate(const ATemplateName: string; const AContext: ITemplateContext): string;
var
  LPreviousState: TRenderState;
begin
  LPreviousState := FCurrentState;
  FCurrentState := TRenderState.Create;
  try
    FCurrentState.TemplateName := ATemplateName;
    Result := RenderTemplateInternal(ATemplateName, AContext);
  finally
    FCurrentState.Free;
    FCurrentState := LPreviousState;
  end;
end;

function TDextTemplateEngine.GetSectionValue(const AName: string; ARequired: Boolean): string;
begin
  if Assigned(FCurrentState) and FCurrentState.Sections.TryGetValue(AName, Result) then
    Exit;

  if ARequired then
    raise EInvalidOpException.CreateFmt('Required section "%s" was not provided.', [AName]);

  Result := '';
end;

function TDextTemplateEngine.GetDefinition(const AName: string): TInlineTemplateDefinition;
begin
  Result := nil;
  if Assigned(FCurrentState) then
    FCurrentState.Definitions.TryGetValue(AName, Result);
end;

function TDextTemplateEngine.RenderPartial(const ATemplateName, AArgsText: string; const AContext: ITemplateContext): string;
var
  LChildContext: ITemplateContext;
  LArgs: TArray<TTemplateArgument>;
  LArg: TTemplateArgument;
  LIsRaw: Boolean;
  LIsEncoded: Boolean;
  LValue: TValue;
begin
  LChildContext := AContext.CreateChildScope;
  LArgs := ParseNamedArguments(AArgsText);
  for LArg in LArgs do
  begin
    if LArg.Name = '' then
      Continue;
    LIsRaw := False;
    LIsEncoded := False;
    LValue := ResolveValue(LArg.Expression, AContext, LIsRaw, LIsEncoded);
    if LValue.Kind = tkClass then
      LChildContext.SetObject(LArg.Name, LValue.AsObject)
    else
      LChildContext.SetValue(LArg.Name, ValueToString(LValue));
  end;
  Result := RenderTemplateInternal(ATemplateName, LChildContext);
end;

function TDextTemplateEngine.RenderMacroCall(const AName, AArgsText: string; const AContext: ITemplateContext): string;
var
  LDefinition: TInlineTemplateDefinition;
  LChildContext: ITemplateContext;
  LArgs: TArray<string>;
  I: Integer;
  LIsRaw: Boolean;
  LIsEncoded: Boolean;
  LValue: TValue;
begin
  LDefinition := GetDefinition(AName);
  if LDefinition = nil then
    raise EInvalidOpException.CreateFmt('Inline template "%s" was not found.', [AName]);

  LChildContext := AContext.CreateChildScope;
  LArgs := SplitTopLevel(AArgsText, ',');
  for I := 0 to Min(High(LDefinition.Parameters), High(LArgs)) do
  begin
    LIsRaw := False;
    LIsEncoded := False;
    LValue := ResolveValue(LArgs[I], AContext, LIsRaw, LIsEncoded);
    if LValue.Kind = tkClass then
      LChildContext.SetObject(LDefinition.Parameters[I], LValue.AsObject)
    else
      LChildContext.SetValue(LDefinition.Parameters[I], ValueToString(LValue));
  end;

  Result := RenderInlineTemplate(LDefinition.Content, LChildContext);
end;

{ TPartialNode }

constructor TPartialNode.Create(AEngine: TDextTemplateEngine; const ATemplateName, AArgumentsText: string);
begin
  inherited Create(AEngine);
  FTemplateName := ATemplateName;
  FArgumentsText := AArgumentsText;
end;

constructor TPartialNode.CreateAt(AEngine: TDextTemplateEngine; const APos: TSourcePos; const ATemplateName, AArgumentsText: string);
begin
  inherited CreateAt(AEngine, APos);
  FTemplateName := ATemplateName;
  FArgumentsText := AArgumentsText;
end;

function TPartialNode.Render(const AContext: ITemplateContext): string;
begin
  Result := FEngine.RenderPartial(FTemplateName, FArgumentsText, AContext);
end;

{ TRenderSectionNode }

constructor TRenderSectionNode.Create(AEngine: TDextTemplateEngine; const ASectionName: string; ARequired: Boolean);
begin
  inherited Create(AEngine);
  FSectionName := ASectionName;
  FRequired := ARequired;
end;

constructor TRenderSectionNode.CreateAt(AEngine: TDextTemplateEngine; const APos: TSourcePos; const ASectionName: string; ARequired: Boolean);
begin
  inherited CreateAt(AEngine, APos);
  FSectionName := ASectionName;
  FRequired := ARequired;
end;

function TRenderSectionNode.Render(const AContext: ITemplateContext): string;
begin
  Result := FEngine.GetSectionValue(FSectionName, FRequired);
  if Result <> '' then
    Result := FEngine.RenderInlineTemplate(Result, AContext);
end;

{ TRenderBodyNode }

constructor TRenderBodyNode.Create(AEngine: TDextTemplateEngine);
begin
  inherited Create(AEngine);
end;

constructor TRenderBodyNode.CreateAt(AEngine: TDextTemplateEngine; const APos: TSourcePos);
begin
  inherited CreateAt(AEngine, APos);
end;

function TRenderBodyNode.Render(const AContext: ITemplateContext): string;
begin
  if Assigned(FEngine.FCurrentState) then
    Result := FEngine.RenderInlineTemplate(FEngine.FCurrentState.BodyContent, AContext)
  else
    Result := '';
end;

{ TMacroCallNode }

constructor TMacroCallNode.Create(AEngine: TDextTemplateEngine; const AName, AArgumentsText: string);
begin
  inherited Create(AEngine);
  FName := AName;
  FArgumentsText := AArgumentsText;
end;

constructor TMacroCallNode.CreateAt(AEngine: TDextTemplateEngine; const APos: TSourcePos; const AName, AArgumentsText: string);
begin
  inherited CreateAt(AEngine, APos);
  FName := AName;
  FArgumentsText := AArgumentsText;
end;

function TMacroCallNode.Render(const AContext: ITemplateContext): string;
begin
  Result := FEngine.RenderMacroCall(FName, FArgumentsText, AContext);
end;

{ TTemplating }

class function TTemplating.CreateContext: ITemplateContext;
begin
  Result := TTemplateContext.Create;
end;

class function TTemplating.CreateEngine: ITemplateEngine;
begin
  Result := TDextTemplateEngine.Create;
end;

end.
