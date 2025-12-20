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
{  Created: 2025-12-14                                                      }
{                                                                           }
{  Description:                                                             }
{    Memory manager wrapper for Dext applications.                          }
{    This unit should be the FIRST unit in the uses clause of any Dext      }
{    application to enable enhanced memory management features.             }
{                                                                           }
{    To enable FastMM5, add the following to your project options or        }
{    include file:                                                          }
{      $DEFINE DEXT_USE_FASTMM5                                             }
{                                                                           }
{    Alternatively, set the conditional in Project Options:                 }
{      Project > Options > Delphi Compiler > Conditional defines            }
{      Add: DEXT_USE_FASTMM5                                                }
{                                                                           }
{***************************************************************************}
unit Dext.MM;

interface

{$DEFINE DEXT_USE_FASTMM5}
{$IFDEF DEXT_USE_FASTMM5}
uses
  FastMM5;
{$ENDIF}

/// <summary>
///   Enables memory leak reporting on application shutdown.
///   Only effective when FastMM5 is enabled via DEXT_USE_FASTMM5 define.
/// </summary>
procedure EnableMemoryLeakReporting;

/// <summary>
///   Disables memory leak reporting on application shutdown.
/// </summary>
procedure DisableMemoryLeakReporting;

/// <summary>
///   Returns True if FastMM5 is active (DEXT_USE_FASTMM5 is defined).
/// </summary>
function IsFastMMEnabled: Boolean;

implementation

procedure EnableMemoryLeakReporting;
begin
  {$IFDEF DEXT_USE_FASTMM5}
  ReportMemoryLeaksOnShutdown := True;
  {$ELSE}
  // No-op when FastMM5 is not enabled
  // Standard Delphi memory manager does not support detailed leak reporting
  System.ReportMemoryLeaksOnShutdown := True;
  {$ENDIF}
end;

procedure DisableMemoryLeakReporting;
begin
  {$IFDEF DEXT_USE_FASTMM5}
  ReportMemoryLeaksOnShutdown := False;
  {$ELSE}
  System.ReportMemoryLeaksOnShutdown := False;
  {$ENDIF}
end;

function IsFastMMEnabled: Boolean;
begin
  {$IFDEF DEXT_USE_FASTMM5}
  Result := True;
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

initialization
  // By default, enable memory leak reporting in DEBUG builds
  {$IFDEF DEBUG}
  EnableMemoryLeakReporting;
  {$ENDIF}

end.
