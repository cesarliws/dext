{***************************************************************************}
{                                                                           }
{           Dext Framework - DI Attributes                                  }
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
{  Created: 2025-12-24                                                      }
{                                                                           }
{  Description:                                                             }
{    Attributes for Dependency Injection configuration.                     }
{                                                                           }
{***************************************************************************}
unit Dext.DI.Attributes;

interface

type
  /// <summary>
  ///   Marks a constructor as the preferred one for DI resolution.
  ///   When a class has multiple constructors, the one marked with this
  ///   attribute will be used by the DI container.
  /// </summary>
  /// <remarks>
  ///   If multiple constructors are marked, the first one found will be used.
  ///   If no constructor is marked, the greedy strategy (most parameters) is used.
  /// </remarks>
  ServiceConstructorAttribute = class(TCustomAttribute)
  end;

implementation

end.
