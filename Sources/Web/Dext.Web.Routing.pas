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
unit Dext.Web.Routing;

interface

uses
  System.SysUtils,
  System.StrUtils,
  System.RegularExpressions,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.Web.Interfaces;
  // Note: We don't import Versioning here to avoid circular dep if possible, 
  // or we define IApiVersionReader in Interfaces? 
  // For now, let's assume simple string matching or header reading inside logic if we pass Context.
  // Actually, we can just extract version in Middleware and pass it?
  // No, the interface change allows passing Context.
  
type
  // Forward delcaration if needed, but IApiVersionReader is in another unit.
  // Let's rely on manually checking context headers/query for now to minimize dependencies,
  // OR assume the Caller (Middleware) passes the Version string?
  // Ideally: FindMatchingRoute(Context).

  TRouteSegment = record
  public
    IsLiteral: Boolean;
    Text: string;
  end;

  /// <summary>
  ///   Represents a compiled route pattern. Analyzes and stores literal segments
  ///   and parameter names extracted from the route definition (e.g., /users/{id}).
  /// </summary>
  TRoutePattern = class
  private
    FPattern: string;
    FSegments: TArray<TRouteSegment>;
    FParameterNames: TArray<string>;
    procedure ParseSegments(const APattern: string);
  public
    constructor Create(const APattern: string);
    /// <summary>
    ///   Tries to match a real path against this pattern.
    ///   Extracts the resulting parameters into the AParams dictionary on success.
    /// </summary>
    function Match(const APath: string; out AParams: TRouteValueDictionary): Boolean;
    /// <summary>Original route pattern (e.g., /api/{controller}/{id}).</summary>
    property Pattern: string read FPattern;
    /// <summary>Parameter names found in the pattern.</summary>
    property ParameterNames: TArray<string> read FParameterNames;
  end;

  /// <summary>
  ///   Represents a single route definition linked to a handler and metadata.
  /// </summary>
  TRouteDefinition = class
  private
    FMethod: string;
    FPath: string;
    FHandler: TRequestDelegate;
    FPattern: TRoutePattern;
    FMetadata: TEndpointMetadata;
  public
    constructor Create(const AMethod, APath: string; AHandler: TRequestDelegate);
    destructor Destroy; override;
    property Method: string read FMethod;
    property Path: string read FPath;
    property Handler: TRequestDelegate read FHandler;
    property Pattern: TRoutePattern read FPattern;
    property Metadata: TEndpointMetadata read FMetadata write FMetadata;
  end;

  /// <summary>
  ///   Interface for the engine that finds routes matching a request.
  /// </summary>
  IRouteMatcher = interface
    ['{A1B2C3D4-E5F6-4A7B-8C9D-0E1F2A3B4C5D}']
    function FindMatchingRoute(const AContext: IHttpContext;
      out AHandler: TRequestDelegate;
      out ARouteParams: TRouteValueDictionary;
      out AMetadata: TEndpointMetadata): Boolean;
  end;

  /// <summary>
  ///   Default implementation of the route matcher.
  ///   Manages API versioning and prioritizes literal (exact) routes over parameterized routes.
  /// </summary>
  /// <summary>
  ///   Represents a leaf node in the routing tree, representing a configured endpoint.
  /// </summary>
  TRouteLeaf = class
  public
    /// <summary>HTTP method/verb (e.g. GET, POST) of the route.</summary>
    Method: string;
    /// <summary>The delegate handler invoked when the route is matched.</summary>
    Handler: TRequestDelegate;
    /// <summary>Endpoint metadata (authorization, CORS, etc.) for this route.</summary>
    Metadata: TEndpointMetadata;
    /// <summary>Initializes a new route leaf.</summary>
    constructor Create(
      const AMethod: string;
      AHandler: TRequestDelegate;
      const AMetadata: TEndpointMetadata
    );
  end;

  /// <summary>
  ///   Represents a segment node in the Radix routing tree.
  /// </summary>
  TRouteNode = class
  public
    /// <summary>The path segment string represented by this node.</summary>
    Segment: string;
    /// <summary>Indicates if this node is a route parameter (e.g. {id}).</summary>
    IsParameter: Boolean;
    /// <summary>The name of the parameter if IsParameter is True.</summary>
    ParameterName: string;
    /// <summary>List of child nodes branch-off from this path segment.</summary>
    Children: IList<TRouteNode>;
    /// <summary>First parameter child, if any, for fast fallback without scanning all literals again.</summary>
    ParameterChild: TRouteNode;
    /// <summary>List of configured endpoint leaves at this path level.</summary>
    Leaves: IList<TRouteLeaf>;
    /// <summary>Initializes a new route node with a segment name.</summary>
    constructor Create(const ASegment: string);
    /// <summary>Cleans up child nodes and leaves lists.</summary>
    destructor Destroy; override;
  end;

  TDextCompiledRouteLeaf = record
    Method: string;
    MethodMask: Word;
    Handler: TRequestDelegate;
    Metadata: TEndpointMetadata;
    Plan: Pointer;
  end;

  TDextCompiledRouteNode = record
  public
    Segment: string;
    IsParameter: Boolean;
    ParameterName: string;
    Children: TArray<TDextCompiledRouteNode>;
    ParameterChild: Pointer;
    Leaves: TArray<TDextCompiledRouteLeaf>;
    AllowedMethodsMask: Word;
  end;
  PDextCompiledRouteNode = ^TDextCompiledRouteNode;

  TRouteMatcher = class(TInterfacedObject, IRouteMatcher)
  private
    FRoutes: IList<TRouteDefinition>;
    FRoot: TRouteNode;
    FCompiledRoot: TDextCompiledRouteNode;
    FExactRoutes: IDictionary<string, TRouteLeaf>;
    procedure AddRouteToTree(const ARoute: TRouteDefinition);
    function GetRequestedApiVersion(const AContext: IHttpContext): string;
    function IsVersionMatch(
      const RequestedVersion: string;
      const SupportedVersions: TArray<string>
    ): Boolean;
    function MatchNodePath(
      Node: TRouteNode;
      const APath: string;
      AStartPos, AEndPos: Integer;
      const AMethod, AVersion: string;
      out ALeaf: TRouteLeaf;
      var AParams: TRouteValueDictionary
    ): Boolean;
  public
    constructor Create(const ARoutes: IList<TRouteDefinition>);
    destructor Destroy; override;
    function FindMatchingRoute(const AContext: IHttpContext;
      out AHandler: TRequestDelegate;
      out ARouteParams: TRouteValueDictionary;
      out AMetadata: TEndpointMetadata): Boolean;
  end;

  ERouteException = class(Exception);

implementation

function BuildExactRouteKey(const AMethod, APath: string): string;
var
  EndPos: Integer;
begin
  EndPos := Length(APath);
  if (EndPos > 1) and (APath[EndPos] = '/') then
    Dec(EndPos);
  Result := AMethod + #1 + Copy(APath, 1, EndPos);
end;

function SamePathSegmentText(const APath: string; AStartPos, ALen: Integer;
  const ASegment: string): Boolean;
var
  i: Integer;
  C1: Char;
  C2: Char;
begin
  if ALen <> Length(ASegment) then
    Exit(False);

  for i := 1 to ALen do
  begin
    C1 := APath[AStartPos + i - 1];
    C2 := ASegment[i];
    if (Ord(C1) > 127) or (Ord(C2) > 127) then
      Exit(SameText(Copy(APath, AStartPos, ALen), ASegment));
    if (C1 >= 'A') and (C1 <= 'Z') then
      C1 := Chr(Ord(C1) + 32);
    if (C2 >= 'A') and (C2 <= 'Z') then
      C2 := Chr(Ord(C2) + 32);
    if C1 <> C2 then
      Exit(False);
  end;
  Result := True;
end;

function GetMethodMask(const AMethod: string): Word;
begin
  if SameText(AMethod, 'GET') then Exit(1);
  if SameText(AMethod, 'POST') then Exit(2);
  if SameText(AMethod, 'PUT') then Exit(4);
  if SameText(AMethod, 'DELETE') then Exit(8);
  if SameText(AMethod, 'OPTIONS') then Exit(16);
  if SameText(AMethod, 'HEAD') then Exit(32);
  if SameText(AMethod, 'PATCH') then Exit(64);
  Result := 128;
end;

function IsVersionMatchHelper(
  const RequestedVersion: string;
  const SupportedVersions: TArray<string>
): Boolean;
var
  V: string;
begin
  if Length(SupportedVersions) = 0 then
    Exit(True);

  if RequestedVersion = '' then
    Exit(False);

  for V in SupportedVersions do
    if SameText(V, RequestedVersion) then
      Exit(True);

  Result := False;
end;

function CompileRouteNode(Source: TRouteNode): TDextCompiledRouteNode;
var
  I: Integer;
  LeafMask: Word;
begin
  Result.Segment := Source.Segment;
  Result.IsParameter := Source.IsParameter;
  Result.ParameterName := Source.ParameterName;
  Result.AllowedMethodsMask := 0;

  // Compile Children
  SetLength(Result.Children, Source.Children.Count);
  for I := 0 to Source.Children.Count - 1 do
  begin
    Result.Children[I] := CompileRouteNode(Source.Children[I]);
    Result.AllowedMethodsMask := Result.AllowedMethodsMask or
      Result.Children[I].AllowedMethodsMask;
  end;

  // Compile ParameterChild
  if Source.ParameterChild <> nil then
  begin
    for I := 0 to Length(Result.Children) - 1 do
    begin
      if Result.Children[I].Segment = Source.ParameterChild.Segment then
      begin
        Result.ParameterChild := @Result.Children[I];
        Break;
      end;
    end;
  end
  else
    Result.ParameterChild := nil;

  // Compile Leaves
  SetLength(Result.Leaves, Source.Leaves.Count);
  for I := 0 to Source.Leaves.Count - 1 do
  begin
    Result.Leaves[I].Method := Source.Leaves[I].Method;
    Result.Leaves[I].Handler := Source.Leaves[I].Handler;
    Result.Leaves[I].Metadata := Source.Leaves[I].Metadata;
    Result.Leaves[I].Plan := nil;

    LeafMask := GetMethodMask(Source.Leaves[I].Method);
    Result.Leaves[I].MethodMask := LeafMask;
    Result.AllowedMethodsMask := Result.AllowedMethodsMask or LeafMask;
  end;
end;

function MatchCompiledNodePath(
  Node: PDextCompiledRouteNode;
  const APath: string;
  AStartPos, AEndPos: Integer;
  const AMethod, AVersion: string;
  out ALeaf: TDextCompiledRouteLeaf;
  var AParams: TRouteValueDictionary
): Boolean;
var
  I: Integer;
  Child: PDextCompiledRouteNode;
  Segment: string;
  SegmentLen: Integer;
  SlashPos: Integer;
  NextPos: Integer;
  MethodMask: Word;
begin
  MethodMask := GetMethodMask(AMethod);

  if (Node^.AllowedMethodsMask and MethodMask) = 0 then
    Exit(False);

  if AStartPos > AEndPos then
  begin
    for I := 0 to Length(Node^.Leaves) - 1 do
    begin
      if (Node^.Leaves[I].MethodMask = MethodMask) and
         IsVersionMatchHelper(AVersion, Node^.Leaves[I].Metadata.ApiVersions) then
      begin
        ALeaf := Node^.Leaves[I];
        Exit(True);
      end;
    end;

    for I := 0 to Length(Node^.Leaves) - 1 do
    begin
      if (Node^.Leaves[I].MethodMask = MethodMask) and
         (AVersion = '') and
         (Length(Node^.Leaves[I].Metadata.ApiVersions) = 0) then
      begin
        ALeaf := Node^.Leaves[I];
        Exit(True);
      end;
    end;
    Exit(False);
  end;

  SlashPos := AStartPos;
  while (SlashPos <= AEndPos) and (APath[SlashPos] <> '/') do
    Inc(SlashPos);

  SegmentLen := SlashPos - AStartPos;
  NextPos := SlashPos + 1;

  for I := 0 to Length(Node^.Children) - 1 do
  begin
    Child := @Node^.Children[I];
    if (not Child^.IsParameter) and
       SamePathSegmentText(APath, AStartPos, SegmentLen, Child^.Segment) then
    begin
      if MatchCompiledNodePath(
        Child, APath, NextPos, AEndPos, AMethod, AVersion, ALeaf, AParams
      ) then
        Exit(True);
    end;
  end;

  if Node^.ParameterChild <> nil then
  begin
    Child := Node^.ParameterChild;
    if MatchCompiledNodePath(
      Child, APath, NextPos, AEndPos, AMethod, AVersion, ALeaf, AParams
    ) then
    begin
      Segment := Copy(APath, AStartPos, SegmentLen);
      AParams.Add(Child^.ParameterName, Segment);
      Exit(True);
    end;
  end;

  Result := False;
end;

{ TRoutePattern }

constructor TRoutePattern.Create(const APattern: string);
begin
  inherited Create;
  FPattern := APattern;

  if APattern = '' then
    raise ERouteException.Create('Route pattern cannot be empty');

  ParseSegments(APattern);
end;

procedure TRoutePattern.ParseSegments(const APattern: string);
var
  Idx, StartIdx: Integer;
  InParam: Boolean;
begin
  FSegments := nil;
  FParameterNames := nil;
  
  StartIdx := 1;
  InParam := False;
  Idx := 1;
  while Idx <= Length(APattern) do
  begin
    if (not InParam) and (APattern[Idx] = '{') then
    begin
      // Flush literal
      if Idx > StartIdx then
      begin
        SetLength(FSegments, Length(FSegments) + 1);
        FSegments[High(FSegments)].IsLiteral := True;
        FSegments[High(FSegments)].Text := Copy(APattern, StartIdx, Idx - StartIdx);
      end;
      StartIdx := Idx + 1;
      InParam := True;
    end
    else if InParam and (APattern[Idx] = '}') then
    begin
      // Flush param
      if Idx > StartIdx then
      begin
        SetLength(FSegments, Length(FSegments) + 1);
        FSegments[High(FSegments)].IsLiteral := False;
        FSegments[High(FSegments)].Text := Copy(APattern, StartIdx, Idx - StartIdx);
        
        SetLength(FParameterNames, Length(FParameterNames) + 1);
        FParameterNames[High(FParameterNames)] := FSegments[High(FSegments)].Text;
      end;
      StartIdx := Idx + 1;
      InParam := False;
    end;
    Inc(Idx);
  end;
  
  if StartIdx <= Length(APattern) then
  begin
    if InParam then
      raise ERouteException.Create('Unclosed parameter in pattern');
    SetLength(FSegments, Length(FSegments) + 1);
    FSegments[High(FSegments)].IsLiteral := True;
    FSegments[High(FSegments)].Text := Copy(APattern, StartIdx, Length(APattern) - StartIdx + 1);
  end;
end;

function TRoutePattern.Match(const APath: string;
  out AParams: TRouteValueDictionary): Boolean;
var
  I: Integer;
  PathIdx: Integer;
  Seg: TRouteSegment;
  ValueStart, ValueLen: Integer;
begin
  AParams.Clear;
  PathIdx := 1;

  for I := 0 to High(FSegments) do
  begin
    Seg := FSegments[I];
    
    if Seg.IsLiteral then
    begin
      if Length(APath) - PathIdx + 1 < Length(Seg.Text) then
        Exit(False);
        
      if StrLIComp(PChar(APath) + PathIdx - 1, PChar(Seg.Text), Length(Seg.Text)) <> 0 then
        Exit(False);
        
      Inc(PathIdx, Length(Seg.Text));
    end
    else
    begin
      ValueStart := PathIdx;
      
      if I < High(FSegments) then
      begin
        while (PathIdx <= Length(APath)) and (APath[PathIdx] <> '/') do
        begin
          if FSegments[I+1].IsLiteral and (Length(FSegments[I+1].Text) > 0) then
          begin
            if (Length(APath) - PathIdx + 1 >= Length(FSegments[I+1].Text)) and
               (StrLIComp(PChar(APath) + PathIdx - 1, PChar(FSegments[I+1].Text), Length(FSegments[I+1].Text)) = 0) then
              Break;
          end;
          Inc(PathIdx);
        end;
      end
      else
      begin
        while (PathIdx <= Length(APath)) and (APath[PathIdx] <> '/') do
          Inc(PathIdx);
      end;
      
      ValueLen := PathIdx - ValueStart;
      if ValueLen = 0 then
        Exit(False);
        
      AParams.Add(Seg.Text, Copy(APath, ValueStart, ValueLen));
    end;
  end;
  
  if PathIdx <= Length(APath) then
    Exit(False);
    
  Result := True;
end;

{ TRouteDefinition }

constructor TRouteDefinition.Create(const AMethod, APath: string; AHandler: TRequestDelegate);
begin
  inherited Create;
  FMethod := AMethod;
  FPath := APath;
  FHandler := AHandler;
  
  if APath.Contains('{') then
    FPattern := TRoutePattern.Create(APath)
  else
    FPattern := nil;

  FMetadata.Method := AMethod;
  FMetadata.Path := APath;
end;

destructor TRouteDefinition.Destroy;
begin
  if FPattern <> nil then
  begin
    FPattern.Free;
    FPattern := nil;
  end;
  inherited;
end;

{ TRouteLeaf }

constructor TRouteLeaf.Create(
  const AMethod: string;
  AHandler: TRequestDelegate;
  const AMetadata: TEndpointMetadata
);
begin
  inherited Create;
  Method := AMethod;
  Handler := AHandler;
  Metadata := AMetadata;
end;

{ TRouteNode }

constructor TRouteNode.Create(const ASegment: string);
begin
  inherited Create;
  Segment := ASegment;
  IsParameter := (Length(ASegment) >= 2) and
                 (ASegment[1] = '{') and
                 (ASegment[Length(ASegment)] = '}');
  if IsParameter then
    ParameterName := Copy(ASegment, 2, Length(ASegment) - 2)
  else
    ParameterName := '';
  ParameterChild := nil;
  Children := TCollections.CreateList<TRouteNode>(True);
  Leaves := TCollections.CreateList<TRouteLeaf>(True);
end;

destructor TRouteNode.Destroy;
begin
  Children := nil;
  Leaves := nil;
  inherited;
end;

{ TRouteMatcher }

constructor TRouteMatcher.Create(const ARoutes: IList<TRouteDefinition>);
var
  Route: TRouteDefinition;
  NewRoute: TRouteDefinition;
begin
  inherited Create;
  FRoutes := TCollections.CreateList<TRouteDefinition>(True);
  FRoot := TRouteNode.Create('');
  FExactRoutes := TCollections.CreateDictionary<string, TRouteLeaf>(ARoutes.Count);

  for Route in ARoutes do
  begin
    NewRoute := TRouteDefinition.Create(
      Route.Method, Route.Path, Route.Handler
    );
    NewRoute.Metadata := Route.Metadata;
    FRoutes.Add(NewRoute);
    AddRouteToTree(NewRoute);
  end;

  FCompiledRoot := CompileRouteNode(FRoot);
end;

destructor TRouteMatcher.Destroy;
begin
  FRoot.Free;
  FExactRoutes := nil;
  FRoutes := nil;
  inherited;
end;

procedure TRouteMatcher.AddRouteToTree(const ARoute: TRouteDefinition);
var
  Path: string;
  Segments: TArray<string>;
  CurrNode: TRouteNode;
  Segment: string;
  i: Integer;
  FoundChild: TRouteNode;
  Child: TRouteNode;
  Leaf: TRouteLeaf;
  Found: Boolean;
begin
  Path := ARoute.Path;
  if (Length(Path) > 1) and (Path[Length(Path)] = '/') then
    Path := Copy(Path, 1, Length(Path) - 1);
  if (Length(Path) > 0) and (Path[1] = '/') then
    Path := Copy(Path, 2, Length(Path) - 1);

  if Path = '' then
    Segments := nil
  else
    Segments := Path.Split(['/']);

  CurrNode := FRoot;
  for Segment in Segments do
  begin
    Found := False;
    FoundChild := nil;
    for i := 0 to CurrNode.Children.Count - 1 do
    begin
      Child := CurrNode.Children[i];
      if SameText(Child.Segment, Segment) then
      begin
        FoundChild := Child;
        Found := True;
        Break;
      end;
    end;

    if not Found then
    begin
      FoundChild := TRouteNode.Create(Segment);
      CurrNode.Children.Add(FoundChild);
      if FoundChild.IsParameter and (CurrNode.ParameterChild = nil) then
        CurrNode.ParameterChild := FoundChild;
    end;
    CurrNode := FoundChild;
  end;

  Leaf := TRouteLeaf.Create(ARoute.Method, ARoute.Handler, ARoute.Metadata);
  CurrNode.Leaves.Add(Leaf);
  if ARoute.Pattern = nil then
    FExactRoutes.AddOrSetValue(BuildExactRouteKey(ARoute.Method, ARoute.Path), Leaf);
end;

function TRouteMatcher.GetRequestedApiVersion(
  const AContext: IHttpContext
): string;
begin
  if AContext.Request.Query.TryGetValue('api-version', Result) then
    Exit;
  if AContext.Request.Headers.TryGetValue('X-Version', Result) then
    Exit;
  Result := '';
end;

function TRouteMatcher.IsVersionMatch(
  const RequestedVersion: string;
  const SupportedVersions: TArray<string>
): Boolean;
var
  V: string;
begin
  if Length(SupportedVersions) = 0 then
    Exit(True);

  if RequestedVersion = '' then
    Exit(False);

  for V in SupportedVersions do
    if SameText(V, RequestedVersion) then
      Exit(True);

  Result := False;
end;

function TRouteMatcher.MatchNodePath(
  Node: TRouteNode;
  const APath: string;
  AStartPos, AEndPos: Integer;
  const AMethod, AVersion: string;
  out ALeaf: TRouteLeaf;
  var AParams: TRouteValueDictionary
): Boolean;
var
  i: Integer;
  Child: TRouteNode;
  Segment: string;
  SegmentLen: Integer;
  SlashPos: Integer;
  NextPos: Integer;
begin
  if AStartPos > AEndPos then
  begin
    for i := 0 to Node.Leaves.Count - 1 do
    begin
      if (Node.Leaves[i].Method = AMethod) and
         IsVersionMatch(AVersion, Node.Leaves[i].Metadata.ApiVersions) then
      begin
        ALeaf := Node.Leaves[i];
        Exit(True);
      end;
    end;

    for i := 0 to Node.Leaves.Count - 1 do
    begin
      if (Node.Leaves[i].Method = AMethod) and
         (AVersion = '') and
         (Length(Node.Leaves[i].Metadata.ApiVersions) = 0) then
      begin
        ALeaf := Node.Leaves[i];
        Exit(True);
      end;
    end;
    Exit(False);
  end;

  SlashPos := AStartPos;
  while (SlashPos <= AEndPos) and (APath[SlashPos] <> '/') do
    Inc(SlashPos);

  SegmentLen := SlashPos - AStartPos;
  NextPos := SlashPos + 1;

  for i := 0 to Node.Children.Count - 1 do
  begin
    Child := Node.Children[i];
    if (not Child.IsParameter) and
       SamePathSegmentText(APath, AStartPos, SegmentLen, Child.Segment) then
    begin
      if MatchNodePath(
        Child, APath, NextPos, AEndPos, AMethod, AVersion, ALeaf, AParams
      ) then
        Exit(True);
    end;
  end;

  Child := Node.ParameterChild;
  if Child <> nil then
  begin
    if MatchNodePath(
      Child, APath, NextPos, AEndPos, AMethod, AVersion, ALeaf, AParams
    ) then
    begin
      Segment := Copy(APath, AStartPos, SegmentLen);
      AParams.Add(Child.ParameterName, Segment);
      Exit(True);
    end;
  end;

  Result := False;
end;

function TRouteMatcher.FindMatchingRoute(
  const AContext: IHttpContext;
  out AHandler: TRequestDelegate;
  out ARouteParams: TRouteValueDictionary;
  out AMetadata: TEndpointMetadata
): Boolean;
var
  Method, Path, RequestVersion: string;
  Leaf: TRouteLeaf;
  StartPos: Integer;
  EndPos: Integer;
  AllowMethods: string;
  AcceptQuery: string;
  ExactKey: string;
  MatchingRoute: TRouteDefinition;
  i: Integer;
  HasQuery: Boolean;
begin
  ARouteParams.Clear;
  Result := False;
  Method := AContext.Request.Method;
  Path := AContext.Request.Path;
  RequestVersion := GetRequestedApiVersion(AContext);

  ExactKey := BuildExactRouteKey(Method, Path);
  if FExactRoutes.TryGetValue(ExactKey, Leaf) and
     IsVersionMatch(RequestVersion, Leaf.Metadata.ApiVersions) then
  begin
    AHandler := Leaf.Handler;
    AMetadata := Leaf.Metadata;
    Result := True;
    Exit;
  end;

  StartPos := 1;
  EndPos := Length(Path);
  if (EndPos > 1) and (Path[EndPos] = '/') then
    Dec(EndPos);
  if (StartPos <= EndPos) and (Path[StartPos] = '/') then
    Inc(StartPos);

  begin
    var CompiledLeaf: TDextCompiledRouteLeaf;
    if MatchCompiledNodePath(
      @FCompiledRoot, Path, StartPos, EndPos, Method, RequestVersion,
      CompiledLeaf, ARouteParams
    ) then
    begin
      AHandler := CompiledLeaf.Handler;
      AMetadata := CompiledLeaf.Metadata;
      Result := True;
      Exit;
    end;
  end;

  if Method = 'OPTIONS' then
  begin
    AllowMethods := 'OPTIONS';
    AcceptQuery := '';
    HasQuery := False;

    for MatchingRoute in FRoutes do
    begin
      if MatchingRoute.Pattern = nil then
      begin
        if MatchingRoute.Path = AContext.Request.Path then
        begin
          if not AllowMethods.Contains(MatchingRoute.Method) then
            AllowMethods := AllowMethods + ', ' + MatchingRoute.Method;
          if MatchingRoute.Method = 'QUERY' then
          begin
            HasQuery := True;
            if Length(MatchingRoute.Metadata.AcceptQueryTypes) > 0 then
            begin
              for i := 0 to High(MatchingRoute.Metadata.AcceptQueryTypes) do
              begin
                if AcceptQuery <> '' then
                  AcceptQuery := AcceptQuery + ', ';
                AcceptQuery := AcceptQuery +
                  MatchingRoute.Metadata.AcceptQueryTypes[i];
              end;
            end;
          end;
        end;
      end
      else if MatchingRoute.Pattern.Match(Path, ARouteParams) then
      begin
        ARouteParams.Clear;
        if not AllowMethods.Contains(MatchingRoute.Method) then
          AllowMethods := AllowMethods + ', ' + MatchingRoute.Method;
        if MatchingRoute.Method = 'QUERY' then
        begin
          HasQuery := True;
          if Length(MatchingRoute.Metadata.AcceptQueryTypes) > 0 then
          begin
            for i := 0 to High(MatchingRoute.Metadata.AcceptQueryTypes) do
            begin
              if AcceptQuery <> '' then
                AcceptQuery := AcceptQuery + ', ';
              AcceptQuery := AcceptQuery +
                MatchingRoute.Metadata.AcceptQueryTypes[i];
            end;
          end;
        end;
      end;
    end;

    if AllowMethods <> 'OPTIONS' then
    begin
      AHandler := procedure(Ctx: IHttpContext)
        begin
          Ctx.Response.StatusCode := 200;
          Ctx.Response.AddHeader('Allow', AllowMethods);
          if HasQuery then
          begin
            if AcceptQuery = '' then
              AcceptQuery := 'application/json';
            Ctx.Response.AddHeader('Accept-Query', AcceptQuery);
          end;
          Ctx.Response.Write('');
        end;

      FillChar(AMetadata, SizeOf(AMetadata), 0);
      AMetadata.Method := 'OPTIONS';
      AMetadata.Path := Path;

      Result := True;
      Exit;
    end;
  end;
end;

end.
