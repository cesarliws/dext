unit Dext.Hosting.CLI.Tools.IndexGen;

interface

uses
  System.Classes,
  System.IOUtils,
  System.SysUtils,
  DelphiAST,
  DelphiAST.Classes,
  DelphiAST.Consts,
  SimpleParser.Lexer.Types,
  Dext.Collections,
  Dext.Collections.HashSet,
  Dext.Collections.Dict,
  Dext.Utils,
  Dext.Json,
  Dext.Json.Types;

type
  /// <summary>
  /// Represents public symbol details extracted from a unit.
  /// </summary>
  TSimpleSymbol = record
    name: string;
    kind: string;       // 'Class', 'Interface', 'Record', 'Method', 'Property', 'Constant', 'Type', etc.
    visibility: string; // 'PUBLIC', 'PUBLISHED', 'PROTECTED', 'PRIVATE', or empty for globals
    line: Integer;
    col: Integer;
    details: string;    // E.g., signature or parent
  end;

  /// <summary>
  /// Represents a parsed unit with its public symbols.
  /// </summary>
  TSimpleUnit = record
    unitName: string;
    path: string;       // relative to search path
    symbols: TArray<TSimpleSymbol>;
  end;

  /// <summary>
  /// Represents the complete symbol index payload.
  /// </summary>
  TSimpleIndex = record
    units: TArray<TSimpleUnit>;
  end;

  /// <summary>
  /// Generator that scans directories, parses Delphi units with DelphiAST,
  /// and outputs indexed public symbols in Markdown, JSON, or CSV formats.
  /// </summary>
  TDextIndexGenerator = class
  private
    FSourcePath: string;
    FOutputPath: string;
    FFormat: string;
    FExcludedPaths: IHashSet<string>;
    FUnits: IList<TSimpleUnit>;
    FProcessedFilesCount: Integer;

    procedure ScanFolder(const Folder: string);
    procedure ProcessFile(const FileName: string);
    function GetNodeText(Node: TSyntaxNode): string;
    function GetMethodSignature(const MethodNode: TSyntaxNode; out Args, RetType: string): string;
    procedure ExtractClassMembers(const UnitName: string; var Symbols: TArray<TSimpleSymbol>; ClassNode: TSyntaxNode);
    function IsExcluded(const Path: string): Boolean;
    
    // Format writers
    procedure SaveAsMarkdown;
    procedure SaveAsJson;
    procedure SaveAsCsv;
  public
    /// <summary>
    /// Initializes a new instance of TDextIndexGenerator.
    /// </summary>
    constructor Create(const SourcePath, OutputPath, Format: string; const Excluded: TArray<string>);
    /// <summary>
    /// Destroys the TDextIndexGenerator instance.
    /// </summary>
    destructor Destroy; override;
    /// <summary>
    /// Executes the scanning, parsing, and index file generation.
    /// </summary>
    procedure Execute;
    /// <summary>
    /// Number of files successfully processed containing public symbols.
    /// </summary>
    property ProcessedFilesCount: Integer read FProcessedFilesCount;
  end;

implementation

{ TDextIndexGenerator }

constructor TDextIndexGenerator.Create(const SourcePath, OutputPath, Format: string; const Excluded: TArray<string>);
var
  S: string;
begin
  FSourcePath := TPath.GetFullPath(SourcePath);
  FOutputPath := TPath.GetFullPath(OutputPath);
  FFormat := Format.ToLower.Trim;
  FProcessedFilesCount := 0;
  
  FExcludedPaths := TCollections.CreateHashSet<string>;
  for S in Excluded do
    FExcludedPaths.Add(S.Trim.ToLower);

  // Add default exclusions
  FExcludedPaths.Add('.git');
  FExcludedPaths.Add('__recovery');
  FExcludedPaths.Add('external');
  FExcludedPaths.Add('bin');
  FExcludedPaths.Add('lib');
  
  FUnits := TCollections.CreateList<TSimpleUnit>;
end;

destructor TDextIndexGenerator.Destroy;
begin
  inherited;
end;

function TDextIndexGenerator.IsExcluded(const Path: string): Boolean;
var
  LowerPath: string;
  Ex: string;
begin
  Result := False;
  LowerPath := Path.ToLower;
  for Ex in FExcludedPaths do
  begin
    if (Ex <> '') and (LowerPath.Contains('\' + Ex + '\') or LowerPath.Contains('/' + Ex + '/') or LowerPath.EndsWith('\' + Ex) or LowerPath.EndsWith('/' + Ex)) then
      Exit(True);
  end;
end;

function TDextIndexGenerator.GetNodeText(Node: TSyntaxNode): string;
begin
  Result := Node.GetAttribute(anName);
  if Result = '' then Result := Node.GetAttribute(anType);
  if Result = '' then Result := Node.GetAttribute(anKind);
  
  if Result = '' then
  begin
    if Node is TValuedSyntaxNode then
      Result := TValuedSyntaxNode(Node).Value;
  end;
  
  if Result.StartsWith('&') then
    Result := Result.Substring(1);
end;

function TDextIndexGenerator.GetMethodSignature(const MethodNode: TSyntaxNode; out Args, RetType: string): string;
var
  Child, Param, ParamsNode, PChild, RChild: TSyntaxNode;
  FirstParam: Boolean;
  Modifier: string;
  ParamName, ParamType: string;
  Params: TStringBuilder;
begin
  Params := TStringBuilder.Create;
  try
    Params.Append('(');
    FirstParam := True;
    
    ParamsNode := nil;
    for Child in MethodNode.ChildNodes do
    begin
      if Child.Typ = ntParameters then
      begin
        ParamsNode := Child;
        Break;
      end;
    end;

    if ParamsNode <> nil then
    begin
      for Param in ParamsNode.ChildNodes do
      begin
        ParamName := Param.GetAttribute(anName);
        if ParamName = '' then
        begin
          for PChild in Param.ChildNodes do
            if PChild.Typ = ntName then
            begin
              ParamName := PChild.GetAttribute(anName);
              if ParamName = '' then ParamName := GetNodeText(PChild);
              Break;
            end;
        end;

        ParamType := Param.GetAttribute(anType);
        if ParamType = '' then
        begin
          for PChild in Param.ChildNodes do
            if PChild.Typ = ntType then
            begin
              ParamType := PChild.GetAttribute(anName);
              if ParamType = '' then ParamType := GetNodeText(PChild);
              Break;
            end;
        end;

        Modifier := Param.GetAttribute(anKind);
        if SameText(Modifier, '0') then Modifier := '';

        if not FirstParam then Params.Append('; ');
        
        // Append modifier if present (const, var, out)
        if (Modifier <> '') and (not SameText(Modifier, ParamName)) then
          Params.Append(Modifier + ' ');

        if ParamType <> '' then
          Params.AppendFormat('%s: %s', [ParamName, ParamType])
        else
          Params.Append(ParamName);

        FirstParam := False;
      end;
    end;
    
    Args := Params.ToString;
    if Args = '(' then Args := ''; 
    if Args <> '' then Args := Args + ')';
    
    RetType := '';
    for Child in MethodNode.ChildNodes do
    begin
      if Child.Typ = ntReturnType then
      begin
        RetType := ': ' + Child.GetAttribute(anType);
        if RetType = ': ' then
        begin
          for RChild in Child.ChildNodes do
            if RChild.Typ = ntType then RetType := ': ' + GetNodeText(RChild);
        end;
        Break;
      end;
    end;
  finally
    Params.Free;
  end;
end;

procedure TDextIndexGenerator.ExtractClassMembers(const UnitName: string; var Symbols: TArray<TSimpleSymbol>; ClassNode: TSyntaxNode);
  procedure Scan(ContextNode: TSyntaxNode; CurrentVis: string; Depth: Integer);
  var
    CChild: TSyntaxNode;
    MName: string;
    Vis: string;
    Sym: TSimpleSymbol;
    Args, RetType: string;
  begin
    if Depth > 10 then Exit;
    Vis := CurrentVis;
      
    if ContextNode.Typ = ntPrivate then Vis := 'PRIVATE'
    else if ContextNode.Typ = ntStrictPrivate then Vis := 'PRIVATE'
    else if ContextNode.Typ = ntProtected then Vis := 'PROTECTED'
    else if ContextNode.Typ = ntPublic then Vis := 'PUBLIC'
    else if ContextNode.Typ = ntPublished then Vis := 'PUBLISHED';
      
    for CChild in ContextNode.ChildNodes do
    begin
      if CChild.Typ in [ntMethod, ntProperty, ntField] then
      begin
        MName := GetNodeText(CChild);
        if MName = '' then Continue;

        // Skip private or strict private symbols to keep the index focused on public symbols
        if (Vis = 'PRIVATE') then Continue;

        Sym.name := MName;
        Sym.line := CChild.Line;
        Sym.col := CChild.Col;
        Sym.visibility := Vis;

        if CChild.Typ = ntMethod then
        begin
          Sym.kind := 'Method';
          GetMethodSignature(CChild, Args, RetType);
          Sym.details := CChild.GetAttribute(anKind) + ' ' + MName + Args + RetType;
        end
        else if CChild.Typ = ntProperty then
        begin
          Sym.kind := 'Property';
          Sym.details := CChild.GetAttribute(anType);
        end
        else
        begin
          Sym.kind := 'Field';
          Sym.details := '';
        end;

        SetLength(Symbols, Length(Symbols) + 1);
        Symbols[High(Symbols)] := Sym;
      end
      else
        Scan(CChild, Vis, Depth + 1);
    end;
  end;
begin
  Scan(ClassNode, 'PUBLIC', 0);
end;

procedure TDextIndexGenerator.ProcessFile(const FileName: string);
var
  Builder: TPasSyntaxTreeBuilder;
  Content: string;
  Stream: TStringStream;
  RootNode: TSyntaxNode;
  InterfaceNode: TSyntaxNode;
  Child, TypeNode, Sub, EVal: TSyntaxNode;
  UnitName: string;
  SimpleUnit: TSimpleUnit;
  Sym: TSimpleSymbol;
  Args, RetType: string;
  TypeType, NodeName: string;
  ClassNode, Candidate, IChild: TSyntaxNode;
  CandKind, NameFound: string;
  EnumValues: string;
  EnumSB: TStringBuilder;
begin
  if IsExcluded(FileName) then Exit;

  Builder := TPasSyntaxTreeBuilder.Create;
  try
    Builder.InitDefinesDefinedByCompiler;
    Builder.AddDefine('MSWINDOWS');
    Builder.UseDefines := True;
    
    try
      Content := TFile.ReadAllText(FileName);
      Stream := TStringStream.Create(Content, TEncoding.UTF8);
      try
        RootNode := Builder.Run(Stream);
      finally
        Stream.Free;
      end;
    except
      RootNode := nil;
    end;
  finally
    Builder.Free;
  end;

  if RootNode = nil then Exit;

  try
    UnitName := RootNode.GetAttribute(anName);
    if UnitName = '' then
      UnitName := TPath.GetFileNameWithoutExtension(FileName);

    SimpleUnit.unitName := UnitName;
    SimpleUnit.path := ExtractRelativePath(FSourcePath, FileName);
    SimpleUnit.symbols := [];

    InterfaceNode := RootNode.FindNode(ntInterface);
    if InterfaceNode = nil then
      InterfaceNode := RootNode;

    for Child in InterfaceNode.ChildNodes do
    begin
      // 1. Global Methods
      if Child.Typ = ntMethod then
      begin
        NodeName := GetNodeText(Child);
        if NodeName <> '' then
        begin
          Sym.name := NodeName;
          Sym.kind := 'Function';
          Sym.visibility := '';
          Sym.line := Child.Line;
          Sym.col := Child.Col;
          GetMethodSignature(Child, Args, RetType);
          Sym.details := Child.GetAttribute(anKind) + ' ' + NodeName + Args + RetType;
          
          SetLength(SimpleUnit.symbols, Length(SimpleUnit.symbols) + 1);
          SimpleUnit.symbols[High(SimpleUnit.symbols)] := Sym;
        end;
      end
      // 2. Global Constants
      else if Child.Typ = ntConstants then
      begin
        for TypeNode in Child.ChildNodes do
        begin
          if TypeNode.Typ = ntConstant then
          begin
            NodeName := GetNodeText(TypeNode);
            if NodeName <> '' then
            begin
              Sym.name := NodeName;
              Sym.kind := 'Constant';
              Sym.visibility := '';
              Sym.line := TypeNode.Line;
              Sym.col := TypeNode.Col;
              Sym.details := '';
              
              SetLength(SimpleUnit.symbols, Length(SimpleUnit.symbols) + 1);
              SimpleUnit.symbols[High(SimpleUnit.symbols)] := Sym;
            end;
          end;
        end;
      end
      // 3. Types and Classes
      else if Child.Typ = ntTypeSection then
      begin
        for TypeNode in Child.ChildNodes do
        begin
          if TypeNode.Typ = ntTypeDecl then
          begin
            TypeType := TypeNode.GetAttribute(anType);
            NodeName := GetNodeText(TypeNode);
            if NodeName = '' then Continue;

            ClassNode := TypeNode;

            if (TypeType = '') and (Length(TypeNode.ChildNodes) > 0) then
            begin
              for Candidate in TypeNode.ChildNodes do
              begin
                CandKind := Candidate.GetAttribute(anType);
                if CandKind = '' then CandKind := Candidate.GetAttribute(anKind);
                if SameText(CandKind, 'class') or SameText(CandKind, 'interface') or SameText(CandKind, 'record') then
                begin
                  TypeType := CandKind;
                  ClassNode := Candidate;
                  Break;
                end;
              end;

              if TypeType = '' then
              begin
                ClassNode := TypeNode.ChildNodes[0];
                TypeType := ClassNode.GetAttribute(anType);
                if TypeType = '' then TypeType := ClassNode.GetAttribute(anKind);
              end;
            end;

            // Classes, Interfaces, Records
            if SameText(TypeType, 'class') or SameText(TypeType, 'interface') or SameText(TypeType, 'record') then
            begin
              Sym.name := NodeName;
              Sym.kind := TypeType;
              Sym.visibility := 'PUBLIC';
              Sym.line := TypeNode.Line;
              Sym.col := TypeNode.Col;
              
              // Find Parent
              NameFound := '';
              for IChild in ClassNode.ChildNodes do
              begin
                if IChild.Typ = ntInherited then
                begin
                  NameFound := IChild.GetAttribute(anName);
                  if NameFound = '' then
                    for Sub in IChild.ChildNodes do
                      if Sub.Typ in [ntName, ntType] then NameFound := GetNodeText(Sub);
                  if NameFound = '' then NameFound := GetNodeText(IChild);
                end;
              end;
              if (NameFound = '') and SameText(TypeType, 'class') then
                NameFound := 'TObject';
              Sym.details := NameFound;

              SetLength(SimpleUnit.symbols, Length(SimpleUnit.symbols) + 1);
              SimpleUnit.symbols[High(SimpleUnit.symbols)] := Sym;

              // Members
              ExtractClassMembers(UnitName, SimpleUnit.symbols, ClassNode);
            end
            // Enums / Aliases / Other Custom Types
            else
            begin
              if (TypeType = '') and (Length(ClassNode.ChildNodes) > 0) then
              begin
                for Sub in ClassNode.ChildNodes do
                  if (Sub.Typ = ntType) and SameText(Sub.GetAttribute(anName), 'enum') then
                  begin
                    TypeType := 'enumeration';
                    Break;
                  end;
              end;

              Sym.name := NodeName;
              Sym.line := TypeNode.Line;
              Sym.col := TypeNode.Col;
              Sym.visibility := 'PUBLIC';

              if SameText(TypeType, 'enumeration') or ((TypeType = '') and (Length(ClassNode.ChildNodes) > 0) and (ClassNode.ChildNodes[0].Typ in [ntName, ntIdentifier])) then
              begin
                Sym.kind := 'Enum';
                EnumSB := TStringBuilder.Create;
                try
                  for EVal in ClassNode.ChildNodes do
                    if EVal.Typ in [ntName, ntIdentifier] then
                      EnumSB.Append(GetNodeText(EVal) + ', ');
                  EnumValues := EnumSB.ToString.TrimRight([',', ' ']);
                finally
                  EnumSB.Free;
                end;
                Sym.details := EnumValues;
              end
              else
              begin
                Sym.kind := 'Type';
                Sym.details := TypeType;
              end;

              SetLength(SimpleUnit.symbols, Length(SimpleUnit.symbols) + 1);
              SimpleUnit.symbols[High(SimpleUnit.symbols)] := Sym;
            end;
          end;
        end;
      end;
    end;

    // Only add unit if it actually has symbols
    if Length(SimpleUnit.symbols) > 0 then
    begin
      FUnits.Add(SimpleUnit);
      Inc(FProcessedFilesCount);
    end;
  finally
    RootNode.Free;
  end;
end;

procedure TDextIndexGenerator.ScanFolder(const Folder: string);
var
  FilePaths: TArray<string>;
  FilePath: string;
  DirPaths: TArray<string>;
  DirPath: string;
begin
  if IsExcluded(Folder) then Exit;

  // Scan current folder files
  try
    FilePaths := TDirectory.GetFiles(Folder, '*.pas');
    for FilePath in FilePaths do
      ProcessFile(FilePath);
  except
    // ignore dir access errors
  end;

  // Scan subfolders
  try
    DirPaths := TDirectory.GetDirectories(Folder);
    for DirPath in DirPaths do
      ScanFolder(DirPath);
  except
    // ignore dir access errors
  end;
end;

procedure TDextIndexGenerator.Execute;
begin
  ScanFolder(FSourcePath);
  
  if FFormat = 'json' then
    SaveAsJson
  else if FFormat = 'csv' then
    SaveAsCsv
  else
    SaveAsMarkdown; // Default
end;

procedure TDextIndexGenerator.SaveAsMarkdown;
var
  Output: TStringList;
  U: TSimpleUnit;
  S: TSimpleSymbol;
begin
  Output := TStringList.Create;
  try
    Output.Add('# Dext Framework - Public Symbols Map');
    Output.Add('');
    Output.Add(Format('Generated on %s. Total indexed units: %d.', [DateTimeToStr(Now), FUnits.Count]));
    Output.Add('');
    
    for U in FUnits do
    begin
      Output.Add(Format('## Unit: %s', [U.unitName]));
      Output.Add(Format('*File Path: `%s`*', [U.path.Replace('\', '/')]));
      Output.Add('');
      
      for S in U.symbols do
      begin
        if S.kind = 'Class' then
          Output.Add(Format('### Class: %s (extends %s) [Line %d]', [S.name, S.details, S.line]))
        else if S.kind = 'Interface' then
          Output.Add(Format('### Interface: %s [Line %d]', [S.name, S.line]))
        else if S.kind = 'Record' then
          Output.Add(Format('### Record: %s [Line %d]', [S.name, S.line]))
        else if S.kind = 'Enum' then
          Output.Add(Format('- **Enum**: `%s` = `(%s)` [Line %d]', [S.name, S.details, S.line]))
        else if S.kind = 'Type' then
          Output.Add(Format('- **Type**: `%s` [Line %d]', [S.name, S.line]))
        else if S.kind = 'Constant' then
          Output.Add(Format('- **Constant**: `%s` [Line %d]', [S.name, S.line]))
        else if S.kind = 'Function' then
          Output.Add(Format('- **Global Method**: `%s` [Line %d]', [S.details, S.line]))
        else if S.kind = 'Method' then
          Output.Add(Format('  - **Method**: `%s` (`%s`) [Line %d]', [S.details, S.visibility, S.line]))
        else if S.kind = 'Property' then
          Output.Add(Format('  - **Property**: `%s: %s` (`%s`) [Line %d]', [S.name, S.details, S.visibility, S.line]))
        else
          Output.Add(Format('  - **%s**: `%s` [Line %d]', [S.kind, S.name, S.line]));
      end;
      Output.Add('');
      Output.Add('---');
      Output.Add('');
    end;
    
    TFile.WriteAllText(FOutputPath, Output.Text, TEncoding.UTF8);
  finally
    Output.Free;
  end;
end;

procedure TDextIndexGenerator.SaveAsJson;
var
  IndexData: TSimpleIndex;
  JsonStr: string;
  i: Integer;
begin
  SetLength(IndexData.units, FUnits.Count);
  for i := 0 to FUnits.Count - 1 do
    IndexData.units[i] := FUnits[i];
    
  // Serialize using Dext Json serializer
  JsonStr := TDextJson.Serialize<TSimpleIndex>(IndexData, TJsonSettings.Indented);
  TFile.WriteAllText(FOutputPath, JsonStr, TEncoding.UTF8);
end;

procedure TDextIndexGenerator.SaveAsCsv;
var
  Output: TStringList;
  U: TSimpleUnit;
  S: TSimpleSymbol;
begin
  Output := TStringList.Create;
  try
    Output.Add('Symbol;Kind;Visibility;Unit;Line;Col;FilePath;Details');
    for U in FUnits do
    begin
      for S in U.symbols do
      begin
        Output.Add(Format('%s;%s;%s;%s;%d;%d;%s;%s', [
          S.name,
          S.kind,
          S.visibility,
          U.unitName,
          S.line,
          S.col,
          U.path.Replace('\', '/'),
          S.details.Replace(';', ',')
        ]));
      end;
    end;
    TFile.WriteAllText(FOutputPath, Output.Text, TEncoding.UTF8);
  finally
    Output.Free;
  end;
end;

end.
