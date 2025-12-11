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
unit Dext.Core.Controllers;

interface

uses
  Dext.DI.Interfaces,
  Dext.Http.Interfaces;

type
  IHttpHandler = interface
    ['{DBE15360-AD39-42F4-853E-6DCED75B256A}']
    procedure HandleRequest(AContext: IHttpContext);
  end;

  // Para Approach 1: Records estÃ¡ticos
  // TStaticHandler movido para Dext.Http.Interfaces

  // Para Approach 2: Classes com DI
  TControllerClass = class of TController;

  TController = class abstract(TInterfacedObject, IHttpHandler)
  public
    procedure HandleRequest(AContext: IHttpContext); virtual; abstract;
  end;

implementation

end.

