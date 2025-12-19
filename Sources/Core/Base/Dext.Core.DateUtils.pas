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

unit Dext.Core.DateUtils;

interface

uses
  System.SysUtils,
  System.DateUtils;

/// <summary>
///   Tries to parse an ISO 8601 date/time string.
/// </summary>
function TryParseISODateTime(const Value: string; out DateTime: TDateTime): Boolean;

/// <summary>
///   Tries to parse a date/time string using common formats (ISO, dd/mm/yyyy, etc).
/// </summary>
function TryParseCommonDate(const Value: string; out DateTime: TDateTime): Boolean;

implementation

function TryParseISODateTime(const Value: string; out DateTime: TDateTime): Boolean;
var
  Year, Month, Day, Hour, Min, Sec, MSec: Word;
  Parts: TArray<string>;
  DatePart, TimePart: string;
begin
  Result := False;
  if Value = '' then
    Exit;

  try
    if Length(Value) >= 19 then
    begin
      DatePart := Copy(Value, 1, 10);
      TimePart := Copy(Value, 12, 12);

      Parts := DatePart.Split(['-']);
      if Length(Parts) = 3 then
      begin
        Year := StrToInt(Parts[0]);
        Month := StrToInt(Parts[1]);
        Day := StrToInt(Parts[2]);

        if (Length(TimePart) >= 8) and (TimePart[3] = ':') and (TimePart[6] = ':') then
        begin
          Hour := StrToInt(Copy(TimePart, 1, 2));
          Min := StrToInt(Copy(TimePart, 4, 2));
          Sec := StrToInt(Copy(TimePart, 7, 2));

          if (Length(TimePart) > 8) and (TimePart[9] = '.') then
            MSec := StrToInt(Copy(TimePart, 10, 3))
          else
            MSec := 0;

          DateTime := EncodeDateTime(Year, Month, Day, Hour, Min, Sec, MSec);
          Result := True;
          Exit;
        end;
      end;
    end;

    if Length(Value) = 10 then
    begin
      Parts := Value.Split(['-']);
      if Length(Parts) = 3 then
      begin
        Year := StrToInt(Parts[0]);
        Month := StrToInt(Parts[1]);
        Day := StrToInt(Parts[2]);
        DateTime := EncodeDate(Year, Month, Day);
        Result := True;
        Exit;
      end;
    end;

    try
      DateTime := ISO8601ToDate(Value);
      Result := True;
    except
      Result := False;
    end;
  except
    Result := False;
  end;
end;

function TryParseCommonDate(const Value: string; out DateTime: TDateTime): Boolean;
var
  FormatSettings: TFormatSettings;
  Parts: TArray<string>;
  Year, Month, Day: Word;
begin
  if TryParseISODateTime(Value, DateTime) then
    Exit(True);

  FormatSettings := TFormatSettings.Create;

  FormatSettings.DateSeparator := '/';
  FormatSettings.ShortDateFormat := 'dd/mm/yyyy';
  if TryStrToDateTime(Value, DateTime, FormatSettings) then
    Exit(True);

  FormatSettings.ShortDateFormat := 'mm/dd/yyyy';
  if TryStrToDateTime(Value, DateTime, FormatSettings) then
    Exit(True);

  FormatSettings.ShortDateFormat := 'yyyy/mm/dd';
  if TryStrToDateTime(Value, DateTime, FormatSettings) then
    Exit(True);

  Parts := Value.Split(['/', '-']);
  if Length(Parts) = 3 then
  begin
    try
      Day := StrToInt(Parts[0]);
      Month := StrToInt(Parts[1]);
      Year := StrToInt(Parts[2]);
      if (Year > 1900) and (Year < 2100) and (Month >= 1) and (Month <= 12) and (Day >= 1) and (Day <= 31) then
      begin
        DateTime := EncodeDate(Year, Month, Day);
        Exit(True);
      end;

      Month := StrToInt(Parts[0]);
      Day := StrToInt(Parts[1]);
      Year := StrToInt(Parts[2]);
      if (Year > 1900) and (Year < 2100) and (Month >= 1) and (Month <= 12) and (Day >= 1) and (Day <= 31) then
      begin
        DateTime := EncodeDate(Year, Month, Day);
        Exit(True);
      end;
    except
    end;
  end;

  Result := False;
end;

end.
