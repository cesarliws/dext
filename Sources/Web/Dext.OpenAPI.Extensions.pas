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
unit Dext.OpenAPI.Extensions;

interface

uses
  System.SysUtils,
  System.TypInfo,
  Dext.Web.Interfaces;

type
  /// <summary>
  ///   Fluent extensions for adding OpenAPI metadata to endpoints.
  /// </summary>
  TEndpointMetadataExtensions = class
  public
    /// <summary>
    ///   Adds a summary to the endpoint.
    /// </summary>
    class function WithSummary(App: IApplicationBuilder; const ASummary: string): IApplicationBuilder;
    
    /// <summary>
    ///   Adds a description to the endpoint.
    /// </summary>
    class function WithDescription(App: IApplicationBuilder; const ADescription: string): IApplicationBuilder;
    
    /// <summary>
    ///   Adds a tag to the endpoint.
    /// </summary>
    class function WithTag(App: IApplicationBuilder; const ATag: string): IApplicationBuilder;
    
    /// <summary>
    ///   Adds multiple tags to the endpoint.
    /// </summary>
    class function WithTags(App: IApplicationBuilder; const ATags: array of string): IApplicationBuilder;
    
    /// <summary>
    ///   Adds metadata to the endpoint (summary, description, and tags).
    /// </summary>
    class function WithMetadata(App: IApplicationBuilder; const ASummary, ADescription: string; const ATags: array of string): IApplicationBuilder;

    /// <summary>
    ///   Adds security requirements to the endpoint.
    /// </summary>
    class function RequireAuthorization(App: IApplicationBuilder; const ASchemes: array of string): IApplicationBuilder; overload;
    class function RequireAuthorization(App: IApplicationBuilder; const AScheme: string): IApplicationBuilder; overload;

    /// <summary>
    ///   Marks the endpoint as allowing anonymous access (skips authorization).
    /// </summary>
    class function AllowAnonymous(App: IApplicationBuilder): IApplicationBuilder;
    
    /// <summary>
    ///   Adds a documented response to the endpoint.
    /// </summary>
    class function WithResponse(App: IApplicationBuilder; Code: Integer; const Description: string = ''; ASchemaType: PTypeInfo = nil; const AMediaType: string = ''): IApplicationBuilder; overload;
    
    /// <summary>
    ///   explicitly sets the request type for OpenAPI documentation.
    /// </summary>
    class function WithRequestType(App: IApplicationBuilder; ATypeInfo: PTypeInfo): IApplicationBuilder;
    
    /// <summary>
    ///   Configures the accepted query content types for the endpoint.
    /// </summary>
    class function AcceptsQuery(App: IApplicationBuilder; const AMediaTypes: array of string): IApplicationBuilder;
    
    /// <summary>
    ///   Update the last registered route's metadata. Internal/Helper use.
    /// </summary>
    class procedure UpdateRouteMetadata(App: IApplicationBuilder; RequestType: PTypeInfo; ResponseType: PTypeInfo);
  end;

implementation

uses
  Dext.Utils,
  Dext.Web.Builder,
  Dext.Web.Routing;

{ TEndpointMetadataExtensions }

class function TEndpointMetadataExtensions.WithSummary(App: IApplicationBuilder; const ASummary: string): IApplicationBuilder;
var
  Routes: TArray<TEndpointMetadata>;
  Metadata: TEndpointMetadata;
begin
  Result := App;
  
  Routes := App.GetRoutes;
  if Length(Routes) > 0 then
  begin
    Metadata := Routes[High(Routes)];
    Metadata.Summary := ASummary;
    App.UpdateLastRouteMetadata(Metadata);
  end;
end;

class function TEndpointMetadataExtensions.WithDescription(App: IApplicationBuilder; const ADescription: string): IApplicationBuilder;
var
  Routes: TArray<TEndpointMetadata>;
  Metadata: TEndpointMetadata;
begin
  Result := App;
  
  Routes := App.GetRoutes;
  if Length(Routes) > 0 then
  begin
    Metadata := Routes[High(Routes)];
    Metadata.Description := ADescription;
    App.UpdateLastRouteMetadata(Metadata);
  end;
end;

class function TEndpointMetadataExtensions.WithTag(App: IApplicationBuilder; const ATag: string): IApplicationBuilder;
var
  Routes: TArray<TEndpointMetadata>;
  Metadata: TEndpointMetadata;
  CurrentTags: TArray<string>;
begin
  Result := App;
  
  Routes := App.GetRoutes;
  if Length(Routes) > 0 then
  begin
    Metadata := Routes[High(Routes)];
    CurrentTags := Metadata.Tags;
    SetLength(CurrentTags, Length(CurrentTags) + 1);
    CurrentTags[High(CurrentTags)] := ATag;
    Metadata.Tags := CurrentTags;
    App.UpdateLastRouteMetadata(Metadata);
  end;
end;

class function TEndpointMetadataExtensions.WithTags(App: IApplicationBuilder; const ATags: array of string): IApplicationBuilder;
var
  Routes: TArray<TEndpointMetadata>;
  Metadata: TEndpointMetadata;
  I: Integer;
  NewTags: TArray<string>;
begin
  Result := App;
  
  Routes := App.GetRoutes;
  if Length(Routes) > 0 then
  begin
    Metadata := Routes[High(Routes)];
    SetLength(NewTags, Length(ATags));
    for I := 0 to High(ATags) do
      NewTags[I] := ATags[I];
    Metadata.Tags := NewTags;
    App.UpdateLastRouteMetadata(Metadata);
  end;
end;

class function TEndpointMetadataExtensions.WithMetadata(App: IApplicationBuilder; 
  const ASummary, ADescription: string; const ATags: array of string): IApplicationBuilder;
var
  Routes: TArray<TEndpointMetadata>;
  Metadata: TEndpointMetadata;
  I: Integer;
  NewTags: TArray<string>;
begin
  Result := App;
  
  Routes := App.GetRoutes;
  if Length(Routes) > 0 then
  begin
    Metadata := Routes[High(Routes)];
    Metadata.Summary := ASummary;
    Metadata.Description := ADescription;
    
    SetLength(NewTags, Length(ATags));
    for I := 0 to High(ATags) do
      NewTags[I] := ATags[I];
    Metadata.Tags := NewTags;
    
    App.UpdateLastRouteMetadata(Metadata);
  end;
end;

class function TEndpointMetadataExtensions.RequireAuthorization(App: IApplicationBuilder; const ASchemes: array of string): IApplicationBuilder;
var
  Routes: TArray<TEndpointMetadata>;
  Metadata: TEndpointMetadata;
  I: Integer;
  NewSecurity: TArray<string>;
begin
  Result := App;
  
  Routes := App.GetRoutes;
  if Length(Routes) > 0 then
  begin
    Metadata := Routes[High(Routes)];
    SetLength(NewSecurity, Length(ASchemes));
    for I := 0 to High(ASchemes) do
      NewSecurity[I] := ASchemes[I];
    Metadata.Security := NewSecurity;
    App.UpdateLastRouteMetadata(Metadata);
  end;
end;

class function TEndpointMetadataExtensions.RequireAuthorization(App: IApplicationBuilder; const AScheme: string): IApplicationBuilder;
begin
  Result := RequireAuthorization(App, [AScheme]);
end;

class function TEndpointMetadataExtensions.AllowAnonymous(App: IApplicationBuilder): IApplicationBuilder;
var
  Routes: TArray<TEndpointMetadata>;
  Metadata: TEndpointMetadata;
begin
  Result := App;
  
  Routes := App.GetRoutes;
  if Length(Routes) > 0 then
  begin
    Metadata := Routes[High(Routes)];
    Metadata.AllowAnonymous := True;
    App.UpdateLastRouteMetadata(Metadata);
  end;
end;

class function TEndpointMetadataExtensions.WithResponse(App: IApplicationBuilder; 
  Code: Integer; const Description: string; ASchemaType: PTypeInfo; const AMediaType: string): IApplicationBuilder;
var
  Routes: TArray<TEndpointMetadata>;
  Metadata: TEndpointMetadata;
  Responses: TArray<TOpenAPIResponseMetadata>;
begin
  Result := App;
  
  Routes := App.GetRoutes;
  if Length(Routes) > 0 then
  begin
    Metadata := Routes[High(Routes)];
    Responses := Metadata.Responses;
    SetLength(Responses, Length(Responses) + 1);
    
    with Responses[High(Responses)] do
    begin
      StatusCode := Code;
      
      // Default description for common codes if not provided
      if Description = '' then
      begin
        case Code of
          200: Description := 'OK';
          201: Description := 'Created';
          204: Description := 'No Content';
          400: Description := 'Bad Request';
          401: Description := 'Unauthorized';
          403: Description := 'Forbidden';
          404: Description := 'Not Found';
          500: Description := 'Internal Server Error';
          else Description := 'Response ' + IntToStr(Code);
        end;
      end
      else
        Description := Description;
        
      SchemaType := ASchemaType;
      MediaType := AMediaType;
    end;
    
    Metadata.Responses := Responses;
    App.UpdateLastRouteMetadata(Metadata);
  end;
end;

class function TEndpointMetadataExtensions.WithRequestType(App: IApplicationBuilder; ATypeInfo: PTypeInfo): IApplicationBuilder;
begin
  Result := App;
  UpdateRouteMetadata(App, ATypeInfo, nil);
end;

class function TEndpointMetadataExtensions.AcceptsQuery(App: IApplicationBuilder; const AMediaTypes: array of string): IApplicationBuilder;
var
  Routes: TArray<TEndpointMetadata>;
  Metadata: TEndpointMetadata;
  i: Integer;
begin
  Result := App;
  Routes := App.GetRoutes;
  if Length(Routes) > 0 then
  begin
    Metadata := Routes[High(Routes)];
    SetLength(Metadata.AcceptQueryTypes, Length(AMediaTypes));
    for i := 0 to High(AMediaTypes) do
      Metadata.AcceptQueryTypes[i] := AMediaTypes[i];
    App.UpdateLastRouteMetadata(Metadata);
  end;
end;

class procedure TEndpointMetadataExtensions.UpdateRouteMetadata(App: IApplicationBuilder; RequestType: PTypeInfo; ResponseType: PTypeInfo);
var
  Routes: TArray<TEndpointMetadata>;
  Metadata: TEndpointMetadata;
begin
  Routes := App.GetRoutes;
  if Length(Routes) > 0 then
  begin
    Metadata := Routes[High(Routes)];
    
    if RequestType <> nil then 
    begin
      // SafeWriteLn('DEBUG: Setting RequestType for ' + Metadata.Path + ' to ' + string(RequestType.Name));
      Metadata.RequestType := RequestType;
    end;
      
    if ResponseType <> nil then 
    begin
      // SafeWriteLn('DEBUG: Setting ResponseType for ' + Metadata.Path + ' to ' + string(ResponseType.Name));
      Metadata.ResponseType := ResponseType;
    end;
      
    App.UpdateLastRouteMetadata(Metadata);
  end;
end;

end.
