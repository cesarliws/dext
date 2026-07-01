unit Dext.Hosting.CLI.Commands.Index;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  Dext.Hosting.CLI.Args,
  Dext.Hosting.CLI.Tools.IndexGen,
  Dext.Utils;

type
  /// <summary>
  /// CLI Command that handles the 'index' subcommand in DextTool.
  /// </summary>
  TIndexCommand = class(TInterfacedObject, IConsoleCommand)
  public
    /// <summary>
    /// Returns the name of the CLI subcommand ('index').
    /// </summary>
    function GetName: string;
    /// <summary>
    /// Returns the description of the command shown in help.
    /// </summary>
    function GetDescription: string;
    /// <summary>
    /// Executes the command parsing options and running the generator.
    /// </summary>
    procedure Execute(const Args: TCommandLineArgs);
  end;

implementation

{ TIndexCommand }

function TIndexCommand.GetName: string;
begin
  Result := 'index';
end;

function TIndexCommand.GetDescription: string;
begin
  Result := 'Generates an index map of all public symbols (markdown, json, csv) with line numbers.';
end;

procedure TIndexCommand.Execute(const Args: TCommandLineArgs);
var
  SourcePath: string;
  OutputPath: string;
  OutputFormat: string;
  Excluded: TArray<string>;
  Generator: TDextIndexGenerator;
begin
  // 1. Source Path
  if Args.HasOption('path') then
    SourcePath := Args.GetOption('path')
  else if Args.HasOption('p') then
    SourcePath := Args.GetOption('p')
  else if Args.Values.Count > 0 then
    SourcePath := Args.Values[0]
  else
    SourcePath := GetCurrentDir;

  SourcePath := TPath.GetFullPath(SourcePath);

  // 2. Format
  if Args.HasOption('format') then
    OutputFormat := Args.GetOption('format')
  else if Args.HasOption('f') then
    OutputFormat := Args.GetOption('f')
  else
    OutputFormat := 'markdown';

  OutputFormat := OutputFormat.ToLower.Trim;
  if (OutputFormat <> 'markdown') and (OutputFormat <> 'json') and (OutputFormat <> 'csv') then
  begin
    SafeWriteLn('Warning: Invalid format specified. Defaulting to "markdown".');
    OutputFormat := 'markdown';
  end;

  // 3. Output Path
  if Args.HasOption('output') then
    OutputPath := Args.GetOption('output')
  else if Args.HasOption('o') then
    OutputPath := Args.GetOption('o')
  else
  begin
    if OutputFormat = 'json' then
      OutputPath := TPath.Combine(SourcePath, 'dext-symbols.json')
    else if OutputFormat = 'csv' then
      OutputPath := TPath.Combine(SourcePath, 'dext-symbols.csv')
    else
      OutputPath := TPath.Combine(SourcePath, 'dext-symbols.md');
  end;

  OutputPath := TPath.GetFullPath(OutputPath);

  // 4. Excluded list
  Excluded := [];
  if Args.HasOption('exclude') then
    Excluded := Args.GetOption('exclude').Split([','])
  else if Args.HasOption('x') then
    Excluded := Args.GetOption('x').Split([',']);

  SafeWriteLn('Dext Public Symbol Indexer');
  SafeWriteLn('--------------------------');
  SafeWriteLn('Source Path : ' + SourcePath);
  SafeWriteLn('Output File : ' + OutputPath);
  SafeWriteLn('Format      : ' + OutputFormat);
  if Length(Excluded) > 0 then
    SafeWriteLn('Excluded    : ' + string.Join(', ', Excluded));
    
  if not TDirectory.Exists(SourcePath) then
  begin
    SafeWriteLn('Error: Source path does not exist.');
    Exit;
  end;

  Generator := TDextIndexGenerator.Create(SourcePath, OutputPath, OutputFormat, Excluded);
  try
    SafeWriteLn('Scanning and parsing files...');
    Generator.Execute;
    SafeWriteLn(Format('Success! Indexed %d units containing public symbols.', [Generator.ProcessedFilesCount]));
  finally
    Generator.Free;
  end;
end;

end.
