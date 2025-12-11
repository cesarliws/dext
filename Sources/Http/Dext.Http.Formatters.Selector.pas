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
unit Dext.Http.Formatters.Selector;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Generics.Collections,
  System.Generics.Defaults,
  Dext.Http.Interfaces,
  Dext.Http.Formatters.Interfaces;

type
  TMediaTypeHeaderValue = record
    MediaType: string;
    Quality: Double;
    class function ParseList(const AHeaderValue: string): TArray<TMediaTypeHeaderValue>; static;
  end;

  TDefaultOutputFormatterSelector = class(TInterfacedObject, IOutputFormatterSelector)
  public
    function SelectFormatter(const Context: IOutputFormatterContext; const Formatters: TArray<IOutputFormatter>): IOutputFormatter;
  end;

implementation

{ TMediaTypeHeaderValue }

class function TMediaTypeHeaderValue.ParseList(const AHeaderValue: string): TArray<TMediaTypeHeaderValue>;
var
  Parts: TArray<string>;
  Item: string;
  List: TList<TMediaTypeHeaderValue>;
  MediaRange: string;
  Params: TArray<string>;
  i: Integer;
begin
  if AHeaderValue.Trim = '' then
  begin
    SetLength(Result, 1);
    Result[0].MediaType := '*/*';
    Result[0].Quality := 1.0;
    Exit;
  end;

  List := TList<TMediaTypeHeaderValue>.Create;
  try
    Parts := AHeaderValue.Split([',']);
    for Item in Parts do
    begin
      MediaRange := Item.Trim;
      if MediaRange = '' then Continue;

      // Parse parameters (e.g. application/json; q=0.9)
      Params := MediaRange.Split([';']);
      
      var MediaTypeVal: TMediaTypeHeaderValue;
      MediaTypeVal.MediaType := Params[0].Trim.ToLower;
      MediaTypeVal.Quality := 1.0; // Default

      for i := 1 to High(Params) do
      begin
        var P := Params[i].Trim;
        if P.StartsWith('q=', True) then
        begin
          var QStr := P.Substring(2);
          // Handle dot or comma decimal separator if needed, usually dot in HTTP
          // Use Val or TryStrToFloat with specific settings to be safe
          var FormatSettings: TFormatSettings;
          FormatSettings := TFormatSettings.Create;
          FormatSettings.DecimalSeparator := '.';
          MediaTypeVal.Quality := StrToFloatDef(QStr, 1.0, FormatSettings);
        end;
      end;
      
      List.Add(MediaTypeVal);
    end;

    // Sort by Quality descending
    List.Sort(TComparer<TMediaTypeHeaderValue>.Construct(
      function(const Left, Right: TMediaTypeHeaderValue): Integer
      begin
        if Left.Quality > Right.Quality then Result := -1
        else if Left.Quality < Right.Quality then Result := 1
        else Result := 0; 
      end));
      
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

{ TDefaultOutputFormatterSelector }

function TDefaultOutputFormatterSelector.SelectFormatter(const Context: IOutputFormatterContext; const Formatters: TArray<IOutputFormatter>): IOutputFormatter;
var
  AcceptHeader: string;
  MediaTypes: TArray<TMediaTypeHeaderValue>;
  MT: TMediaTypeHeaderValue;
  Formatter: IOutputFormatter;
begin
  Result := nil;
  if Length(Formatters) = 0 then Exit;

  // 1. Get Accept Header
  if not Context.HttpContext.Request.Headers.TryGetValue('Accept', AcceptHeader) then
    AcceptHeader := '';
  
  // 2. Parse Media Types
  MediaTypes := TMediaTypeHeaderValue.ParseList(AcceptHeader);
  
  // 3. Match
  for MT in MediaTypes do
  begin
    // Wildcard handling
    var IsWildcard := (MT.MediaType = '*/*');
    
    for Formatter in Formatters do
    begin
      if not Formatter.CanWriteResult(Context) then Continue;
      
      var Supported := Formatter.GetSupportedMediaTypes;
      for var MediaType in Supported do
      begin
        // If client accepts everything (*/*), pick the first one this formatter supports
        // Or if client request matches explicitly
        if IsWildcard or SameText(MediaType, MT.MediaType) then
        begin
          // Set Content-Type on Response immediately? 
          // Usually better to let the Formatter decide or set it here.
          // For now, allow formatter to run.
          Result := Formatter;
          Exit;
        end;
      end;
    end;
  end;
  
  // Fallback: If no match found but we have formatters, use the first one 
  // (unless strict 406 mode is enabled, which implies returning nil here)
  if (Result = nil) and (Length(Formatters) > 0) then
    Result := Formatters[0];
end;

end.

