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
unit Dext.Web.Formatters.Selector;

interface

uses
  System.Classes,
  System.SysUtils,
  Dext.Web.Interfaces,
  Dext.Collections,
  Dext.Collections.Comparers,
  Dext.Web.Formatters.Interfaces;

type
  /// <summary>
  ///   Represents a media type value with its respective quality weight (q-factor).
  /// </summary>
  TMediaTypeHeaderValue = record
    MediaType: string;
    Quality: Double;
    class function ParseList(const AHeaderValue: string): TArray<TMediaTypeHeaderValue>; static;
  end;

  /// <summary>
  ///   Default selector responsible for choosing the best output formatter based on the 'Accept' header of the request.
  /// </summary>
  TDefaultOutputFormatterSelector = class(TInterfacedObject, IOutputFormatterSelector)
  public
    function SelectFormatter(const Context: IOutputFormatterContext; const Formatters: TArray<IOutputFormatter>): IOutputFormatter;
  end;

implementation

{ TMediaTypeHeaderValue }

class function TMediaTypeHeaderValue.ParseList(const AHeaderValue: string): TArray<TMediaTypeHeaderValue>;
var
  List: IList<TMediaTypeHeaderValue>;
  Len: Integer;
  PosIdx: Integer;
  ItemStart: Integer;
  ItemEnd: Integer;
  ParamStart: Integer;
  ParamEnd: Integer;
  SemiIdx: Integer;
  MediaTypeVal: TMediaTypeHeaderValue;
  P: string;
  QStr: string;

  function TrimCopy(AStart, AEnd: Integer): string;
  begin
    while (AStart <= AEnd) and ((AHeaderValue[AStart] = ' ') or
      (AHeaderValue[AStart] = #9)) do
      Inc(AStart);
    while (AEnd >= AStart) and ((AHeaderValue[AEnd] = ' ') or
      (AHeaderValue[AEnd] = #9)) do
      Dec(AEnd);
    if AStart <= AEnd then
      Result := Copy(AHeaderValue, AStart, AEnd - AStart + 1)
    else
      Result := '';
  end;

  function IsBlankHeader: Boolean;
  var
    i: Integer;
  begin
    for i := 1 to Length(AHeaderValue) do
      if (AHeaderValue[i] <> ' ') and (AHeaderValue[i] <> #9) then
        Exit(False);
    Result := True;
  end;

  function HasComplexAcceptSyntax: Boolean;
  var
    i: Integer;
  begin
    for i := 1 to Length(AHeaderValue) do
      if (AHeaderValue[i] = ',') or (AHeaderValue[i] = ';') then
        Exit(True);
    Result := False;
  end;
begin
  if IsBlankHeader then
  begin
    SetLength(Result, 1);
    Result[0].MediaType := '*/*';
    Result[0].Quality := 1.0;
    Exit;
  end;

  if not HasComplexAcceptSyntax then
  begin
    SetLength(Result, 1);
    Result[0].MediaType := TrimCopy(1, Length(AHeaderValue));
    if Result[0].MediaType = '' then
      Result[0].MediaType := '*/*';
    Result[0].Quality := 1.0;
    Exit;
  end;

  List := TCollections.CreateList<TMediaTypeHeaderValue>;
  try
    Len := Length(AHeaderValue);
    PosIdx := 1;
    while PosIdx <= Len do
    begin
      while (PosIdx <= Len) and ((AHeaderValue[PosIdx] = ',') or
        (AHeaderValue[PosIdx] = ' ') or (AHeaderValue[PosIdx] = #9)) do
        Inc(PosIdx);
      if PosIdx > Len then
        Break;

      ItemStart := PosIdx;
      while (PosIdx <= Len) and (AHeaderValue[PosIdx] <> ',') do
        Inc(PosIdx);
      ItemEnd := PosIdx - 1;

      SemiIdx := ItemStart;
      while (SemiIdx <= ItemEnd) and (AHeaderValue[SemiIdx] <> ';') do
        Inc(SemiIdx);

      MediaTypeVal.MediaType := TrimCopy(ItemStart, SemiIdx - 1);
      MediaTypeVal.Quality := 1.0;
      if MediaTypeVal.MediaType <> '' then
      begin
        ParamStart := SemiIdx + 1;
        while ParamStart <= ItemEnd do
        begin
          while (ParamStart <= ItemEnd) and ((AHeaderValue[ParamStart] = ';') or
            (AHeaderValue[ParamStart] = ' ') or (AHeaderValue[ParamStart] = #9)) do
            Inc(ParamStart);
          if ParamStart > ItemEnd then
            Break;

          ParamEnd := ParamStart;
          while (ParamEnd <= ItemEnd) and (AHeaderValue[ParamEnd] <> ';') do
            Inc(ParamEnd);

          P := TrimCopy(ParamStart, ParamEnd - 1);
          if P.StartsWith('q=', True) then
          begin
            QStr := P.Substring(2);
            MediaTypeVal.Quality := StrToFloatDef(QStr, 1.0,
              TFormatSettings.Invariant);
          end;
          ParamStart := ParamEnd + 1;
        end;

        List.Add(MediaTypeVal);
      end;

      Inc(PosIdx);
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
    // List is ARC
  end;
end;

{ TDefaultOutputFormatterSelector }

function TDefaultOutputFormatterSelector.SelectFormatter(const Context: IOutputFormatterContext; const Formatters: TArray<IOutputFormatter>): IOutputFormatter;
var
  AcceptHeader: string;
  MediaTypes: TArray<TMediaTypeHeaderValue>;
  MT: TMediaTypeHeaderValue;
  Formatter: IOutputFormatter;
  IsWildcard: Boolean;
  Supported: TArray<string>;
  MediaType: string;
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
    IsWildcard := (MT.MediaType = '*/*');
    
    for Formatter in Formatters do
    begin
      if not Formatter.CanWriteResult(Context) then Continue;
      
      Supported := Formatter.GetSupportedMediaTypes;
      for MediaType in Supported do
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

