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
unit Dext.Web.Routing.Attributes;

interface

uses
  System.SysUtils;

type
  // ===========================================================================
  // BASE ROUTE ATTRIBUTE
  // ===========================================================================
  
  /// <summary>
  ///   Base attribute for HTTP route definitions.
  /// </summary>
  RouteAttribute = class(TCustomAttribute)
  private
    FPath: string;
    FMethod: string;
  public
    constructor Create(const APath: string; const AMethod: string = '');
    property Path: string read FPath;
    property Method: string read FMethod;
  end;

  // ===========================================================================
  // HTTP VERB ATTRIBUTES
  // ===========================================================================
  
  /// <summary>Marks a method as handling HTTP GET requests.</summary>
  HttpGetAttribute = class(RouteAttribute)
  public
    constructor Create(const APath: string = '');
  end;

  /// <summary>Marks a method as handling HTTP POST requests.</summary>
  HttpPostAttribute = class(RouteAttribute)
  public
    constructor Create(const APath: string = '');
  end;

  /// <summary>Marks a method as handling HTTP PUT requests.</summary>
  HttpPutAttribute = class(RouteAttribute)
  public
    constructor Create(const APath: string = '');
  end;

  /// <summary>Marks a method as handling HTTP DELETE requests.</summary>
  HttpDeleteAttribute = class(RouteAttribute)
  public
    constructor Create(const APath: string = '');
  end;

  /// <summary>Marks a method as handling HTTP PATCH requests.</summary>
  HttpPatchAttribute = class(RouteAttribute)
  public
    constructor Create(const APath: string = '');
  end;

  /// <summary>Marks a method as handling HTTP HEAD requests.</summary>
  HttpHeadAttribute = class(RouteAttribute)
  public
    constructor Create(const APath: string = '');
  end;

  /// <summary>Marks a method as handling HTTP OPTIONS requests.</summary>
  HttpOptionsAttribute = class(RouteAttribute)
  public
    constructor Create(const APath: string = '');
  end;

  /// <summary>Marks a method as handling HTTP QUERY requests.</summary>
  HttpQueryAttribute = class(RouteAttribute)
  public
    constructor Create(const APath: string = '');
  end;

  // ===========================================================================
  // CONTROLLER ATTRIBUTE
  // ===========================================================================
  
  /// <summary>
  ///   Marks a class as an API controller with an optional route prefix.
  /// </summary>
  ApiControllerAttribute = class(TCustomAttribute)
  private
    FPrefix: string;
  public
    constructor Create(const APrefix: string = '');
    property Prefix: string read FPrefix;
  end;

  // ===========================================================================
  // HTTP EXCEPTION
  // ===========================================================================
  
  /// <summary>
  ///   Exception that carries an HTTP status code.
  /// </summary>
  HttpException = class(Exception)
  private
    FStatusCode: Integer;
  public
    constructor Create(AStatusCode: Integer; const AMessage: string);
    property StatusCode: Integer read FStatusCode;
  end;

  // ===========================================================================
  // DEPRECATED ALIASES (for backward compatibility)
  // ===========================================================================
  
  /// <summary>Deprecated. Use RouteAttribute instead.</summary>
  DextRouteAttribute = RouteAttribute deprecated 'Use RouteAttribute instead';
  
  /// <summary>Deprecated. Use HttpGetAttribute instead.</summary>
  DextGetAttribute = HttpGetAttribute deprecated 'Use HttpGetAttribute instead';

  /// <summary>Deprecated. Use HttpPostAttribute instead.</summary>
  DextPostAttribute = HttpPostAttribute deprecated 'Use HttpPostAttribute instead';

  /// <summary>Deprecated. Use HttpPutAttribute instead.</summary>
  DextPutAttribute = HttpPutAttribute deprecated 'Use HttpPutAttribute instead';

  /// <summary>Deprecated. Use HttpDeleteAttribute instead.</summary>
  DextDeleteAttribute = HttpDeleteAttribute deprecated 'Use HttpDeleteAttribute instead';

  /// <summary>Deprecated. Use HttpPatchAttribute instead.</summary>
  DextPatchAttribute = HttpPatchAttribute deprecated 'Use HttpPatchAttribute instead';

  /// <summary>Deprecated. Use HttpHeadAttribute instead.</summary>
  DextHeadAttribute = HttpHeadAttribute deprecated 'Use HttpHeadAttribute instead';

  /// <summary>Deprecated. Use HttpOptionsAttribute instead.</summary>
  DextOptionsAttribute = HttpOptionsAttribute deprecated 'Use HttpOptionsAttribute instead';

  /// <summary>Deprecated. Use ApiControllerAttribute instead.</summary>
  DextControllerAttribute = ApiControllerAttribute deprecated 'Use ApiControllerAttribute instead';
  
  /// <summary>Deprecated. Use HttpException instead.</summary>
  EDextHttpException = HttpException deprecated 'Use HttpException instead';

implementation

{ RouteAttribute }

constructor RouteAttribute.Create(const APath: string; const AMethod: string);
begin
  inherited Create;
  FPath := APath;
  FMethod := AMethod;
end;

{ HttpGetAttribute }

constructor HttpGetAttribute.Create(const APath: string);
begin
  inherited Create(APath, 'GET');
end;

{ HttpPostAttribute }

constructor HttpPostAttribute.Create(const APath: string);
begin
  inherited Create(APath, 'POST');
end;

{ HttpPutAttribute }

constructor HttpPutAttribute.Create(const APath: string);
begin
  inherited Create(APath, 'PUT');
end;

{ HttpDeleteAttribute }

constructor HttpDeleteAttribute.Create(const APath: string);
begin
  inherited Create(APath, 'DELETE');
end;

{ HttpPatchAttribute }

constructor HttpPatchAttribute.Create(const APath: string);
begin
  inherited Create(APath, 'PATCH');
end;

{ HttpHeadAttribute }

constructor HttpHeadAttribute.Create(const APath: string);
begin
  inherited Create(APath, 'HEAD');
end;

{ HttpOptionsAttribute }

constructor HttpOptionsAttribute.Create(const APath: string);
begin
  inherited Create(APath, 'OPTIONS');
end;

{ HttpQueryAttribute }

constructor HttpQueryAttribute.Create(const APath: string);
begin
  inherited Create(APath, 'QUERY');
end;

{ ApiControllerAttribute }

constructor ApiControllerAttribute.Create(const APrefix: string);
begin
  inherited Create;
  FPrefix := APrefix;
end;

{ HttpException }

constructor HttpException.Create(AStatusCode: Integer; const AMessage: string);
begin
  inherited Create(AMessage);
  FStatusCode := AStatusCode;
end;

end.
