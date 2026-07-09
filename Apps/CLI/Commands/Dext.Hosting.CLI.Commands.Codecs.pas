{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2026 Cesar Romero & Dext Contributors             }
{                                                                           }
{           Licensed under the Apache License, Version 2.0 (the "License"); }
{           you may not use this file except in compliance with the License. }
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
unit Dext.Hosting.CLI.Commands.Codecs;

interface

uses
  System.Classes,
  System.IOUtils,
  System.RegularExpressions,
  System.SysUtils,
  Dext.Collections,
  Dext.Hosting.CLI.Args;

type
  TCodecsCommand = class(TInterfacedObject, IConsoleCommand)
  private
    /// <summary>Generates a Pascal unit with static codec registrations and readers/writers.</summary>
    procedure GenerateCodecs(const AUnitFile, AOutputFile: string);
    /// <summary>Exports a proto3 file from a code-first DTO unit.</summary>
    procedure ExportProto(const AUnitFile, AOutputFile: string);
  public
    /// <summary>Returns the command name used by the CLI.</summary>
    function GetName: string;
    /// <summary>Returns the human-readable command description.</summary>
    function GetDescription: string;
    /// <summary>Runs the codecs command using the parsed CLI arguments.</summary>
    procedure Execute(const Args: TCommandLineArgs);
  end;

implementation

type
  TCodecMember = record
    Tag: Integer;
    Name: string;
    DelphiType: string;
  end;

  TCodecClass = record
    Name: string;
    Members: TArray<TCodecMember>;
  end;

function StripTypePrefix(const TypeName: string): string;
begin
  Result := TypeName.Trim;
  if (Result.Length > 1) and (Result[1] = 'T') then
    Result := Result.Substring(1);
end;

function ExtractGenericArg(const DelphiType: string): string;
var
  i: Integer;
  j: Integer;
begin
  Result := '';
  i := DelphiType.IndexOf('<');
  j := DelphiType.LastIndexOf('>');
  if (i >= 0) and (j > i) then
    Result := DelphiType.Substring(i + 1, j - i - 1).Trim;
end;

function IsClassTypeName(const DelphiType: string): Boolean;
var
  T: string;
begin
  T := DelphiType.Trim;
  Result := (T.Length > 1) and (T[1] = 'T') and
    not SameText(T, 'TBytes') and not SameText(T, 'TDateTime');
end;

function IsListTypeName(const DelphiType: string): Boolean;
var
  T: string;
begin
  T := DelphiType.Trim.ToLower;
  Result := T.StartsWith('ilist<') or T.StartsWith('iobjectlist<');
end;

function ListElementTypeName(const DelphiType: string): string;
begin
  Result := ExtractGenericArg(DelphiType);
end;

function ListOwnsObjects(const DelphiType: string): Boolean;
var
  T: string;
begin
  T := ListElementTypeName(DelphiType).Trim;
  Result := (T.Length > 1) and (T[1] = 'T') and
    not SameText(T, 'TBytes') and not SameText(T, 'TDateTime');
end;

function IsGeneratedSupportedType(const DelphiType: string): Boolean;
var
  T: string;
begin
  T := DelphiType.Trim.ToLower;
  Result := ((T = 'integer') or (T = 'smallint') or (T = 'shortint') or
    (T = 'int64') or (T = 'boolean') or (T = 'bool') or
    (T = 'single') or (T = 'double') or (T = 'datetime') or
    (T = 'string') or (T = 'tbytes') or IsClassTypeName(DelphiType) or
    IsListTypeName(DelphiType));
end;

function ProtoTypeOf(const DelphiType: string): string;
var
  T: string;
  ElementType: string;
begin
  T := DelphiType.Trim.ToLower;
  if (T = 'integer') or (T = 'smallint') or (T = 'shortint') then
    Result := 'int32'
  else if T = 'int64' then
    Result := 'int64'
  else if (T = 'boolean') or (T = 'bool') then
    Result := 'bool'
  else if T = 'single' then
    Result := 'float'
  else if (T = 'double') or (T = 'tdatetime') then
    Result := 'double'
  else if T = 'tbytes' then
    Result := 'bytes'
  else if IsListTypeName(DelphiType) then
  begin
    ElementType := ListElementTypeName(DelphiType);
    if ElementType <> '' then
      Result := 'repeated ' + StripTypePrefix(ElementType)
    else
      Result := 'repeated string';
  end
  else if IsClassTypeName(DelphiType) then
    Result := StripTypePrefix(DelphiType)
  else
    Result := 'string';
end;

function WriterMethodOf(const DelphiType: string): string;
var
  T: string;
begin
  T := DelphiType.Trim.ToLower;
  if (T = 'integer') or (T = 'smallint') or (T = 'shortint') then
    Result := 'WriteInt32'
  else if T = 'int64' then
    Result := 'WriteInt64'
  else if (T = 'boolean') or (T = 'bool') then
    Result := 'WriteBool'
  else if T = 'single' then
    Result := 'WriteSingle'
  else if (T = 'double') or (T = 'tdatetime') then
    Result := 'WriteDouble'
  else if T = 'tbytes' then
    Result := 'WriteBytes'
  else
    Result := 'WriteString';
end;

function ReaderMethodOf(const DelphiType: string): string;
var
  T: string;
begin
  T := DelphiType.Trim.ToLower;
  if (T = 'integer') or (T = 'smallint') or (T = 'shortint') then
    Result := 'ReadInt32'
  else if T = 'int64' then
    Result := 'ReadInt64'
  else if (T = 'boolean') or (T = 'bool') then
    Result := 'ReadBool'
  else if T = 'single' then
    Result := 'ReadSingle'
  else if (T = 'double') or (T = 'tdatetime') then
    Result := 'ReadDouble'
  else if T = 'tbytes' then
    Result := 'ReadBytes'
  else
    Result := 'ReadString';
end;

procedure ParseGrpcMessages(const AUnitFile: string; out AUnitName: string;
  out AClasses: TArray<TCodecClass>);
var
  Lines: TStringList;
  i: Integer;
  Line: string;
  Match: TMatch;
  InGrpcMessage: Boolean;
  InClass: Boolean;
  PendingTag: Integer;
  Current: TCodecClass;
  Member: TCodecMember;
begin
  AClasses := [];
  AUnitName := TPath.GetFileNameWithoutExtension(AUnitFile);
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(AUnitFile);
    InGrpcMessage := False;
    InClass := False;
    PendingTag := 0;

    for i := 0 to Lines.Count - 1 do
    begin
      Line := Lines[i].Trim;
      if SameText(Line, '[GrpcMessage]') then
      begin
        InGrpcMessage := True;
        Continue;
      end;

      if InGrpcMessage and not InClass then
      begin
        Match := TRegEx.Match(Line, '^(T\w+)\s*=\s*class\b', [roIgnoreCase]);
        if Match.Success then
        begin
          Current := Default(TCodecClass);
          Current.Name := Match.Groups[1].Value;
          Current.Members := [];
          InClass := True;
        end;
        Continue;
      end;

      if InClass then
      begin
        if SameText(Line, 'end;') then
        begin
          SetLength(AClasses, Length(AClasses) + 1);
          AClasses[High(AClasses)] := Current;
          InClass := False;
          InGrpcMessage := False;
          PendingTag := 0;
          Continue;
        end;

        Match := TRegEx.Match(Line, '^\[ProtoMember\((\d+)\)\]', [roIgnoreCase]);
        if Match.Success then
        begin
          PendingTag := StrToIntDef(Match.Groups[1].Value, 0);
          Continue;
        end;

        if PendingTag > 0 then
        begin
          Match := TRegEx.Match(Line, '^property\s+(\w+)\s*:\s*([^\s]+)\s+read\b', [roIgnoreCase]);
          if Match.Success then
          begin
            Member.Tag := PendingTag;
            Member.Name := Match.Groups[1].Value;
            Member.DelphiType := Match.Groups[2].Value;
            SetLength(Current.Members, Length(Current.Members) + 1);
            Current.Members[High(Current.Members)] := Member;
            PendingTag := 0;
          end;
        end;
      end;
    end;
  finally
    Lines.Free;
  end;
end;

procedure TCodecsCommand.ExportProto(const AUnitFile, AOutputFile: string);
var
  UnitName: string;
  Classes: TArray<TCodecClass>;
  C: TCodecClass;
  M: TCodecMember;
  Output: TStringList;
begin
  ParseGrpcMessages(AUnitFile, UnitName, Classes);
  Output := TStringList.Create;
  try
    Output.Add('syntax = "proto3";');
    Output.Add('');
    Output.Add('package dext.generated;');
    Output.Add('');
    for C in Classes do
    begin
      Output.Add('message ' + C.Name.Substring(1) + ' {');
      for M in C.Members do
        Output.Add(Format('  %s %s = %d;', [ProtoTypeOf(M.DelphiType), M.Name, M.Tag]));
      Output.Add('}');
      Output.Add('');
    end;
    if TPath.GetDirectoryName(AOutputFile) <> '' then
      TDirectory.CreateDirectory(TPath.GetDirectoryName(AOutputFile));
    Output.SaveToFile(AOutputFile, TEncoding.UTF8);
  finally
    Output.Free;
  end;
end;

procedure TCodecsCommand.GenerateCodecs(const AUnitFile, AOutputFile: string);
var
  UnitName: string;
  Classes: TArray<TCodecClass>;
  C: TCodecClass;
  M: TCodecMember;
  Output: TStringList;
  OutUnit: string;
begin
  ParseGrpcMessages(AUnitFile, UnitName, Classes);
  OutUnit := TPath.GetFileNameWithoutExtension(AOutputFile);
  Output := TStringList.Create;
  try
    Output.Add('unit ' + OutUnit + ';');
    Output.Add('');
    Output.Add('interface');
    Output.Add('');
    Output.Add('uses');
    Output.Add('  System.SysUtils,');
    Output.Add('  Dext.Collections,');
    Output.Add('  Dext.Codecs.Registry,');
    Output.Add('  Dext.Serialization.Protobuf,');
    Output.Add('  ' + UnitName + ';');
    Output.Add('');
    Output.Add('procedure RegisterDextCodecs;');
    Output.Add('');
    Output.Add('implementation');
    Output.Add('');
    Output.Add('function ReadMessageObject(Reader: TProtobufReader; Obj: TObject): TObject;');
    Output.Add('var');
    Output.Add('  Bytes: TBytes;');
    Output.Add('begin');
    Output.Add('  Bytes := Reader.ReadBytes;');
    Output.Add('  TProtobufSerializer.Deserialize(Bytes, Obj);');
    Output.Add('  Result := Obj;');
    Output.Add('end;');
    Output.Add('');

    for C in Classes do
    begin
      Output.Add(Format('procedure Write_%s(AWriter: TObject; AObj: TObject);', [C.Name]));
      Output.Add('var');
      Output.Add('  Writer: TProtobufWriter;');
      Output.Add('  i: Integer;');
      Output.Add(Format('  Obj: %s;', [C.Name]));
      Output.Add('begin');
      Output.Add('  Writer := TProtobufWriter(AWriter);');
      Output.Add(Format('  Obj := %s(AObj);', [C.Name]));
      for M in C.Members do
      begin
        if not IsGeneratedSupportedType(M.DelphiType) then
          Output.Add(Format('  // %s is not supported by the initial static codec generator.', [M.Name]))
        else if IsListTypeName(M.DelphiType) then
        begin
          Output.Add(Format('  if Obj.%s <> nil then', [M.Name]));
          Output.Add('  begin');
          Output.Add(Format('    for i := 0 to Obj.%s.Count - 1 do', [M.Name]));
          if IsClassTypeName(ListElementTypeName(M.DelphiType)) then
            Output.Add(Format('      if Assigned(Obj.%s[i]) then Writer.WriteMessage(%d, TProtobufSerializer.Serialize(Obj.%s[i]));', [M.Name, M.Tag, M.Name]))
          else
            Output.Add(Format('      Writer.%s(%d, Obj.%s[i]);', [WriterMethodOf(ListElementTypeName(M.DelphiType)), M.Tag, M.Name]));
          Output.Add('  end;');
        end
        else if IsClassTypeName(M.DelphiType) then
          Output.Add(Format('  if Obj.%s <> nil then Writer.WriteMessage(%d, TProtobufSerializer.Serialize(Obj.%s));', [M.Name, M.Tag, M.Name]))
        else
          Output.Add(Format('  Writer.%s(%d, Obj.%s);', [WriterMethodOf(M.DelphiType), M.Tag, M.Name]));
      end;
      Output.Add('end;');
      Output.Add('');

      Output.Add(Format('procedure Read_%s(AReader: TObject; AObj: TObject);', [C.Name]));
      Output.Add('var');
      Output.Add('  Reader: TProtobufReader;');
      Output.Add(Format('  Obj: %s;', [C.Name]));
      Output.Add('begin');
      Output.Add('  Reader := TProtobufReader(AReader);');
      Output.Add(Format('  Obj := %s(AObj);', [C.Name]));
      Output.Add('  while Reader.ReadField do');
      Output.Add('    case Reader.Tag of');
      for M in C.Members do
      begin
        if not IsGeneratedSupportedType(M.DelphiType) then
          Output.Add(Format('      %d: Reader.SkipField;', [M.Tag]))
        else if IsListTypeName(M.DelphiType) then
        begin
          Output.Add(Format('      %d:', [M.Tag]));
          Output.Add('      begin');
          Output.Add(Format('        if Obj.%s = nil then', [M.Name]));
          Output.Add(Format('          Obj.%s := TCollections.CreateList<%s>(%s);', [M.Name, ListElementTypeName(M.DelphiType), BoolToStr(ListOwnsObjects(M.DelphiType), True)]));
          if IsClassTypeName(ListElementTypeName(M.DelphiType)) then
            Output.Add(Format('        Obj.%s.Add(%s(ReadMessageObject(Reader, %s.Create)));', [M.Name, ListElementTypeName(M.DelphiType), ListElementTypeName(M.DelphiType)]))
          else
            Output.Add(Format('        Obj.%s.Add(Reader.%s);', [M.Name, ReaderMethodOf(ListElementTypeName(M.DelphiType))]));
          Output.Add('      end;');
        end
        else if IsClassTypeName(M.DelphiType) then
          Output.Add(Format('      %d: Obj.%s := %s(ReadMessageObject(Reader, %s.Create));', [M.Tag, M.Name, M.DelphiType, M.DelphiType]))
        else
          Output.Add(Format('      %d: Obj.%s := Reader.%s;', [M.Tag, M.Name, ReaderMethodOf(M.DelphiType)]));
      end;
      Output.Add('    else');
      Output.Add('      Reader.SkipField;');
      Output.Add('    end;');
      Output.Add('end;');
      Output.Add('');
    end;

    Output.Add('procedure RegisterDextCodecs;');
    Output.Add('begin');
    for C in Classes do
      Output.Add(Format('  TDextCodecRegistry.RegisterProtobuf<%s>(Write_%s, Read_%s);', [C.Name, C.Name, C.Name]));
    Output.Add('end;');
    Output.Add('');
    Output.Add('initialization');
    Output.Add('  RegisterDextCodecs;');
    Output.Add('');
    Output.Add('end.');

    if TPath.GetDirectoryName(AOutputFile) <> '' then
      TDirectory.CreateDirectory(TPath.GetDirectoryName(AOutputFile));
    Output.SaveToFile(AOutputFile, TEncoding.UTF8);
  finally
    Output.Free;
  end;
end;

procedure TCodecsCommand.Execute(const Args: TCommandLineArgs);
var
  Mode: string;
  UnitFile: string;
  OutputFile: string;
begin
  Mode := 'generate';
  if Args.Values.Count > 0 then
    Mode := Args.Values[0].ToLower;

  UnitFile := Args.GetOption('unit');
  if UnitFile = '' then
    UnitFile := Args.GetOption('u');
  if UnitFile = '' then
    raise Exception.Create('Missing --unit <file.pas>.');

  if not TFile.Exists(UnitFile) then
    raise Exception.CreateFmt('Unit file not found: %s', [UnitFile]);

  OutputFile := Args.GetOption('out');
  if OutputFile = '' then
    OutputFile := Args.GetOption('o');

  if OutputFile = '' then
  begin
    if SameText(Mode, 'proto') or SameText(Mode, 'export-proto') then
      OutputFile := TPath.ChangeExtension(UnitFile, '.proto')
    else
      OutputFile := TPath.Combine(TPath.GetDirectoryName(UnitFile),
        TPath.GetFileNameWithoutExtension(UnitFile) + '.DextCodecs.pas');
  end;

  if SameText(Mode, 'proto') or SameText(Mode, 'export-proto') then
    ExportProto(UnitFile, OutputFile)
  else
    GenerateCodecs(UnitFile, OutputFile);

  Writeln('Generated: ', OutputFile);
end;

function TCodecsCommand.GetDescription: string;
begin
  Result := 'Generates Dext static codecs and proto files for simple [GrpcMessage] DTO units.';
end;

function TCodecsCommand.GetName: string;
begin
  Result := 'codecs';
end;

end.



