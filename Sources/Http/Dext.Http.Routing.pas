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
unit Dext.Http.Routing;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.RegularExpressions,
  System.StrUtils,
  Dext.Http.Interfaces;
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

  TRoutePattern = class
  private
    FPattern: string;
    FRegex: TRegEx;
    FParameterNames: TArray<string>;
    function BuildRegexPattern(const APattern: string): string;
    function ExtractParameterNames(const APattern: string): TArray<string>;
  public
    constructor Create(const APattern: string);
    function Match(const APath: string; out AParams: TDictionary<string, string>): Boolean;
    property Pattern: string read FPattern;
    property ParameterNames: TArray<string> read FParameterNames;
  end;

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

  IRouteMatcher = interface
    ['{A1B2C3D4-E5F6-4A7B-8C9D-0E1F2A3B4C5D}']
    function FindMatchingRoute(const AContext: IHttpContext;
      out AHandler: TRequestDelegate;
      out ARouteParams: TDictionary<string, string>;
      out AMetadata: TEndpointMetadata): Boolean;
  end;

  TRouteMatcher = class(TInterfacedObject, IRouteMatcher)
  private
    FRoutes: TObjectList<TRouteDefinition>;
    function GetRequestedApiVersion(const AContext: IHttpContext): string;
    function IsVersionMatch(const RequestedVersion: string; const SupportedVersions: TArray<string>): Boolean;
  public
    constructor Create(const ARoutes: TList<TRouteDefinition>);
    destructor Destroy; override;
    function FindMatchingRoute(const AContext: IHttpContext;
      out AHandler: TRequestDelegate;
      out ARouteParams: TDictionary<string, string>;
      out AMetadata: TEndpointMetadata): Boolean;
  end;

  ERouteException = class(Exception);

implementation

{ TRoutePattern }

constructor TRoutePattern.Create(const APattern: string);
begin
  inherited Create;
  FPattern := APattern;

  if APattern = '' then
    raise ERouteException.Create('Route pattern cannot be empty');

  FParameterNames := ExtractParameterNames(APattern);
  FRegex := TRegEx.Create(BuildRegexPattern(APattern), [roIgnoreCase]);
end;

function TRoutePattern.ExtractParameterNames(const APattern: string): TArray<string>;
var
  Matches: TMatchCollection;
  I: Integer;
begin
  var PatternRegex := TRegEx.Create('\{(.+?)\}');
  Matches := PatternRegex.Matches(APattern);

  SetLength(Result, Matches.Count);
  for I := 0 to Matches.Count - 1 do
  begin
    Result[I] := Matches[I].Groups[1].Value;

    if Result[I].IsEmpty then
      raise ERouteException.CreateFmt('Invalid parameter name in pattern: %s', [APattern]);
  end;
end;

function TRoutePattern.BuildRegexPattern(const APattern: string): string;
begin
  Result := APattern;
  Result := TRegEx.Replace(Result, '([.+?^=!:${}()|\[\]\\])', '\\$1');
  Result := TRegEx.Replace(Result, '\\\{([^}]+)\\\}', '([^/]+)');
  Result := '^' + Result + '$';
end;

function TRoutePattern.Match(const APath: string;
  out AParams: TDictionary<string, string>): Boolean;
var
  Match: TMatch;
  I: Integer;
begin
  AParams := nil;
  Result := False;

  Match := FRegex.Match(APath);

  if Match.Success then
  begin
    AParams := TDictionary<string, string>.Create;

    try
      for I := 0 to High(FParameterNames) do
      begin
        if I + 1 < Match.Groups.Count then
          AParams.Add(FParameterNames[I], Match.Groups[I + 1].Value);
      end;

      Result := True;

    except
      AParams.Free;
      raise;
    end;
  end;
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

{ TRouteMatcher }

constructor TRouteMatcher.Create(const ARoutes: TList<TRouteDefinition>);
var
  Route: TRouteDefinition;
begin
  inherited Create;
  FRoutes := TObjectList<TRouteDefinition>.Create(True); // Owns objects
  
  // Clone routes to ensure thread safety and independence
  for Route in ARoutes do
  begin
    var NewRoute := TRouteDefinition.Create(Route.Method, Route.Path, Route.Handler);
    NewRoute.Metadata := Route.Metadata;
    FRoutes.Add(NewRoute);
  end;
end;

destructor TRouteMatcher.Destroy;
begin
  FRoutes.Clear; // Force clear
  FRoutes.Free;
  inherited;
end;

function TRouteMatcher.GetRequestedApiVersion(const AContext: IHttpContext): string;
begin
  // Simple default logic: check Query string then Header
  // NOTE: In production this should be pluggable via DI
  Result := AContext.Request.Query.Values['api-version'];
  if Result = '' then
  begin
    if not AContext.Request.Headers.TryGetValue('X-Version', Result) then
      Result := '';
  end;
end;

function TRouteMatcher.IsVersionMatch(const RequestedVersion: string; const SupportedVersions: TArray<string>): Boolean;
begin
  // If no version requested, match anything that DOESN'T require a specific version?
  // Or match typically V1?
  // Policy: If route has NO versions defined, it matches any request (implicit neutral).
  // If route HAS versions, request MUST match one of them.
  
  if Length(SupportedVersions) = 0 then
    Exit(True); // Route is version neutral
    
  if RequestedVersion = '' then
  begin
    // If no version requested, do we match versioned routes?
    // Maybe default to '1.0' or reject?
    // For now: assume neutral match only if requested matches. 
    // If requested is empty, we only match neutral routes (Length=0 check matches).
    // What if we want default version?
    // Let's assume empty request only matches neutral routes.
    Exit(False); 
  end;
    
  for var V in SupportedVersions do
    if SameText(V, RequestedVersion) then
      Exit(True);
      
  Result := False;
end;

function TRouteMatcher.FindMatchingRoute(const AContext: IHttpContext;
  out AHandler: TRequestDelegate;
  out ARouteParams: TDictionary<string, string>;
  out AMetadata: TEndpointMetadata): Boolean;
var
  Route: TRouteDefinition;
  Method, Path, RequestVersion: string;
  Candidates: TList<TRouteDefinition>;
  BestMatch: TRouteDefinition;
begin
  ARouteParams := nil;
  Result := False;
  Method := AContext.Request.Method;
  Path := AContext.Request.Path;
  RequestVersion := GetRequestedApiVersion(AContext);
  
  // Collect all path-matching candidates
  Candidates := TList<TRouteDefinition>.Create;
  try
    for Route in FRoutes do
    begin
        if (Route.Method = Method) then
        begin
             if (Route.Pattern = nil) and (Route.Path = Path) then
               Candidates.Add(Route)
             else if (Route.Pattern <> nil) and Route.Pattern.Match(Path, ARouteParams) then
             begin
               // Note: Match creates ARouteParams. If we continue loop, we overwrite/leak it.
               // We need to manage ARouteParams carefully. 
               // Since Pattern Match creates a dictionary, we should check if we keep this candidate.
               // Re-matching later is safer/simpler for this logic block, or cache params.
               
               // Optimization: For now, just add candidate. We will re-match parameters for the WINNER.
               if Assigned(ARouteParams) then 
               begin
                 ARouteParams.Free;
                 ARouteParams := nil;
               end;
               Candidates.Add(Route);
             end;
        end;
    end;
    
    // Select Best Candidate based on Version
    BestMatch := nil;
    
    // 1. Try to find exact version match
    for Route in Candidates do
    begin
      if IsVersionMatch(RequestVersion, Route.Metadata.ApiVersions) then
      begin
        BestMatch := Route;
        Break; // Priority to first defined match or exact match?
        // If we have V1 and V2, and request is V1, we get V1.
        // If we have Neutral and V1, and request is V1, we get V1 (because we checked Version match).
      end;
    end;
    
    // 2. If no exact version match found and RequestVersion is empty, try to find a neutral route
    if (BestMatch = nil) and (RequestVersion = '') then
    begin
      for Route in Candidates do
        if Length(Route.Metadata.ApiVersions) = 0 then
        begin
          BestMatch := Route;
          Break;
        end;
    end;
    
    if BestMatch <> nil then
    begin
        AHandler := BestMatch.Handler;
        AMetadata := BestMatch.Metadata;
        
        // Re-generate params for the winner
        if BestMatch.Pattern <> nil then
           BestMatch.Pattern.Match(Path, ARouteParams);
           
        Result := True;
    end;
    
  finally
    Candidates.Free;
  end;
end;

end.

