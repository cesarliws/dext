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
unit Dext.Core.Routing;

interface

uses
  System.SysUtils;

type
  // ===========================================================================
  // ATRIBUTO BASE PARA ROTAS
  // ===========================================================================
  DextRouteAttribute = class(TCustomAttribute)
  private
    FPath: string;
    FMethod: string;
  public
    constructor Create(const APath: string; const AMethod: string);
    property Path: string read FPath;
    property Method: string read FMethod;
  end;

  // ===========================================================================
  // ATRIBUTOS ESPECÍFICOS POR VERBO HTTP
  // ===========================================================================
  DextGetAttribute = class(DextRouteAttribute)
  public
    constructor Create(const APath: string);
  end;

  DextPostAttribute = class(DextRouteAttribute)
  public
    constructor Create(const APath: string);
  end;

  DextPutAttribute = class(DextRouteAttribute)
  public
    constructor Create(const APath: string);
  end;

  DextDeleteAttribute = class(DextRouteAttribute)
  public
    constructor Create(const APath: string);
  end;

  DextPatchAttribute = class(DextRouteAttribute)
  public
    constructor Create(const APath: string);
  end;

  DextHeadAttribute = class(DextRouteAttribute)
  public
    constructor Create(const APath: string);
  end;

  DextOptionsAttribute = class(DextRouteAttribute)
  public
    constructor Create(const APath: string);
  end;

  // ===========================================================================
  // ATRIBUTO PARA CONTROLLERS (opcional)
  // ===========================================================================
  DextControllerAttribute = class(TCustomAttribute)
  private
    FPrefix: string;
  public
    constructor Create(const APrefix: string = '');
    property Prefix: string read FPrefix;
  end;

  // ===========================================================================
  // EXCEÇÃO HTTP PERSONALIZADA
  // ===========================================================================
  EDextHttpException = class(Exception)
  private
    FStatusCode: Integer;
  public
    constructor Create(AStatusCode: Integer; const AMessage: string);
    property StatusCode: Integer read FStatusCode;
  end;

implementation

{ DextRouteAttribute }

constructor DextRouteAttribute.Create(const APath: string; const AMethod: string);
begin
  inherited Create;
  FPath := APath;
  FMethod := AMethod;
end;

{ DextGetAttribute }

constructor DextGetAttribute.Create(const APath: string);
begin
  inherited Create(APath, 'GET');
end;

{ DextPostAttribute }

constructor DextPostAttribute.Create(const APath: string);
begin
  inherited Create(APath, 'POST');
end;

{ DextPutAttribute }

constructor DextPutAttribute.Create(const APath: string);
begin
  inherited Create(APath, 'PUT');
end;

{ DextDeleteAttribute }

constructor DextDeleteAttribute.Create(const APath: string);
begin
  inherited Create(APath, 'DELETE');
end;

{ DextPatchAttribute }

constructor DextPatchAttribute.Create(const APath: string);
begin
  inherited Create(APath, 'PATCH');
end;

{ DextHeadAttribute }

constructor DextHeadAttribute.Create(const APath: string);
begin
  inherited Create(APath, 'HEAD');
end;

{ DextOptionsAttribute }

constructor DextOptionsAttribute.Create(const APath: string);
begin
  inherited Create(APath, 'OPTIONS');
end;

{ DextControllerAttribute }

constructor DextControllerAttribute.Create(const APrefix: string);
begin
  inherited Create;
  FPrefix := APrefix;
end;

{ EDextHttpException }

constructor EDextHttpException.Create(AStatusCode: Integer; const AMessage: string);
begin
  inherited Create(AMessage);
  FStatusCode := AStatusCode;
end;

end.

