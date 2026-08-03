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
unit Dext.Web.PathBase;

interface

uses
  System.SysUtils,
  Dext.Web.Interfaces;

type
  /// <summary>
  ///   Middleware that strips a configured base path from incoming requests
  ///   and populates Request.PathBase.
  /// </summary>
  TDextPathBaseMiddleware = class(TInterfacedObject, IMiddleware)
  private
    FPathBase: string;
  public
    /// <summary>Initializes a new path base middleware instance.</summary>
    /// <param name="APathBase">Configured base path prefix.</param>
    constructor Create(const APathBase: string);
    /// <summary>Executes path base stripping and invokes next delegate.</summary>
    procedure Invoke(Context: IHttpContext; Next: TRequestDelegate);
    /// <summary>Returns normalized path base prefix.</summary>
    property PathBase: string read FPathBase;
  end;

  /// <summary>Type alias for TDextPathBaseMiddleware.</summary>
  TPathBaseMiddleware = TDextPathBaseMiddleware;

implementation

constructor TDextPathBaseMiddleware.Create(const APathBase: string);
begin
  inherited Create;
  FPathBase := APathBase;
  if (FPathBase <> '') and not FPathBase.StartsWith('/') then
    FPathBase := '/' + FPathBase;
  if FPathBase.EndsWith('/') and (Length(FPathBase) > 1) then
    FPathBase := Copy(FPathBase, 1, Length(FPathBase) - 1);
end;

procedure TDextPathBaseMiddleware.Invoke(Context: IHttpContext;
  Next: TRequestDelegate);
var
  PathStr: string;
  Matched: Boolean;
  Remaining: string;
begin
  if (FPathBase <> '') and (FPathBase <> '/') then
  begin
    PathStr := Context.Request.Path;
    Matched := False;

    if SameText(PathStr, FPathBase) then
    begin
      Matched := True;
      Remaining := '/';
    end
    else if SameText(Copy(PathStr, 1, Length(FPathBase) + 1),
      FPathBase + '/') then
    begin
      Matched := True;
      Remaining := Copy(PathStr, Length(FPathBase) + 1, Length(PathStr));
    end;

    if Matched then
    begin
      Context.Request.SetPathBase(FPathBase);
      Context.Request.SetPath(Remaining);
    end;
  end;

  Next(Context);
end;

end.
