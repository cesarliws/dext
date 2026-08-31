program GraphDemo;

{$APPTYPE CONSOLE}

uses
  Winapi.Windows,
  System.SysUtils,
  System.Math,
  System.JSON,
  System.IOUtils,
  System.Classes,
  Dext.AI.MCP.Tools,
  Dext.AI.MCP.Types,
  Dext.AI.MCP.Protocol,
  Dext.AI.MCP.Attributes,
  Dext.AI.Agent.Contracts,
  Dext.AI.Agent.Factory,
  Dext.AI.Agent.Observer,
  Dext.AI.Graph.Contracts,
  Dext.AI.Graph.State,
  Dext.AI.Graph.Edge,
  Dext.AI.Graph.Graph,
  Dext.AI.Graph.Compiled,
  Dext.AI.Graph.Checkpointer,
  Dext.AI.Graph.Node.LLM,
  Dext.AI.Graph.Node.Tools;

type
  TFileSystemTools = class(TMCPToolProvider)
  public
    [MCPTool('list_files', 'Lista arquivos em um diretório')]
    [MCPParam('path', 'Caminho do diretório', ptString, True)]
    [MCPParam('extension', 'Filtro ex: .pas (opcional)', ptString, False)]
    function ListFiles(const Args: TJSONObject): TMCPToolResult;

    [MCPTool('read_file', 'Lê o conteúdo de um arquivo')]
    [MCPParam('path', 'Caminho completo do arquivo', ptString, True)]
    [MCPParam('max_lines', 'Máximo de linhas (default: 50)', ptInteger, False)]
    function ReadFile(const Args: TJSONObject): TMCPToolResult;

    [MCPTool('count_lines', 'Conta linhas de código em um arquivo')]
    [MCPParam('path', 'Caminho completo do arquivo', ptString, True)]
    function CountLines(const Args: TJSONObject): TMCPToolResult;
  end;

function TFileSystemTools.ListFiles(const Args: TJSONObject): TMCPToolResult;
var
  Path, Ext, Pattern: string;
  SR: TSearchRec;
  JA: TJSONArray;
begin
  Path := Args.GetValue<string>('path', '.');
  Ext  := Args.GetValue<string>('extension', '');

  if not DirectoryExists(Path) then
    Exit(TMCPToolResult.Error('Diretório não encontrado: ' + Path));

  Pattern := IncludeTrailingPathDelimiter(Path) + '*' + Ext;
  JA := TJSONArray.Create;
  try
    if FindFirst(Pattern, faAnyFile, SR) = 0 then
    try
      repeat
        if (SR.Attr and faDirectory) = 0 then
        begin
          var JO := TJSONObject.Create;
          JO.AddPair('name', SR.Name);
          JO.AddPair('size', TJSONNumber.Create(SR.Size));
          JA.AddElement(JO);
        end;
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
    Result := TMCPToolResult.Text(
      Format('{"path":"%s","filter":"%s","count":%d,"files":%s}',
        [Path, Ext, JA.Count, JA.ToJSON])
    );
  finally
    JA.Free;
  end;
end;

function TFileSystemTools.ReadFile(const Args: TJSONObject): TMCPToolResult;
var
  Path: string;
  MaxLines, I: Integer;
  Lines: TStringList;
  SB: TStringBuilder;
begin
  Path     := Args.GetValue<string>('path', '');
  MaxLines := Args.GetValue<Integer>('max_lines', 50);

  if not FileExists(Path) then
    Exit(TMCPToolResult.Error('Arquivo não encontrado: ' + Path));

  Lines := TStringList.Create;
  SB    := TStringBuilder.Create;
  try
    Lines.LoadFromFile(Path, TEncoding.UTF8);
    SB.AppendLine(Format('// %s — %d linhas total', [ExtractFileName(Path), Lines.Count]));
    for I := 0 to Min(MaxLines - 1, Lines.Count - 1) do
      SB.AppendFormat('%4d  %s', [I + 1, Lines[I]]).AppendLine;
    if Lines.Count > MaxLines then
      SB.AppendLine(Format('// ... (%d linhas restantes)', [Lines.Count - MaxLines]));
    Result := TMCPToolResult.Text(SB.ToString);
  finally
    Lines.Free;
    SB.Free;
  end;
end;

function TFileSystemTools.CountLines(const Args: TJSONObject): TMCPToolResult;
var
  Path: string;
  Lines: TStringList;
  Code, Comment, Blank: Integer;
  Line: string;
begin
  Path := Args.GetValue<string>('path', '');
  if not FileExists(Path) then
    Exit(TMCPToolResult.Error('Arquivo não encontrado: ' + Path));

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(Path, TEncoding.UTF8);
    Code := 0; Comment := 0; Blank := 0;
    for Line in Lines do
    begin
      var T := Line.Trim;
      if T = '' then Inc(Blank)
      else if T.StartsWith('//') or T.StartsWith('{') or T.StartsWith('(*') then Inc(Comment)
      else Inc(Code);
    end;
    Result := TMCPToolResult.Text(
      Format('{"file":"%s","total":%d,"code":%d,"comments":%d,"blank":%d}',
        [ExtractFileName(Path), Lines.Count, Code, Comment, Blank])
    );
  finally
    Lines.Free;
  end;
end;

var
  Config:       TAgentConfig;
  Provider:     ILLMProvider;
  Observer:     IAgentObserver;
  ToolsNode:    TToolsNode;
  LLMNode:      TLLMNode;
  Graph:        TAgentGraph;
  Agent:        ICompiledAgent;
  Checkpointer: ICheckpointer;
  Input, ThreadId: string;
  RunResult:    TGraphRunResult;
  Confirm:      string;

begin
  ReportMemoryLeaksOnShutdown := True;

  SetConsoleOutputCP(CP_UTF8);
  SetConsoleCP(CP_UTF8);

  Config := TAgentConfig.OpenAI('gpt-4o');
  Config.ApiKey := GetEnvironmentVariable('OPENAI_API_KEY');
  Config.SystemPrompt :=
    'Você é um assistente técnico especializado em projetos Delphi. ' +
    'Use as tools disponíveis para responder. Nunca invente dados.';

  if Config.ApiKey = '' then
  begin
    Writeln('ERRO: Defina OPENAI_API_KEY');
    ExitCode := 1;
    Exit;
  end;

  try
    Provider := TLLMFactory.CreateProvider(Config);
  except
    on E: ELLMProviderError do
    begin
      Writeln('ERRO: ' + E.Message);
      ExitCode := 1;
      Exit;
    end;
  end;

  Observer  := TConsoleObserver.Create;
  ToolsNode := TToolsNode.Create;
  LLMNode   := nil;
  try
    ToolsNode.RegisterProvider(TFileSystemTools.Create);
    LLMNode := TLLMNode.Create(ToolsNode.GetToolSchemas);

    Checkpointer := TMemoryCheckpointer.Create;

    Graph := TAgentGraph.Create;
    try
      Agent := Graph
        .AddNode('call_llm', LLMNode.AsHandler)
        .AddNode('execute_tools', ToolsNode.AsHandler)
        .SetEntryPoint('call_llm')
        .AddConditionalEdge('call_llm',
          DefaultShouldContinue,
          [TEdgeRoute.To_('execute_tools'), TEdgeRoute.ToEnd])
        .AddEdge('execute_tools', 'call_llm')
        .RequireApproval('execute_tools')
        .Compile(Provider, Config, Observer, Checkpointer);
    finally
      Graph.Free;
    end;

    Writeln('═══════════════════════════════════════════════════════');
    Writeln('  Dext.AI.Graph — Demo (estilo LangGraph)');
    Writeln(Format('  Provider: %s | Model: %s',
      [Provider.ProviderName, Provider.ModelName]));
    Writeln('  Digite sua pergunta. Enter em branco para sair.');
    Writeln('═══════════════════════════════════════════════════════');
    Writeln;

    ThreadId := 'demo-session-001';

    repeat
      Write('Pergunta: ');
      Readln(Input);
      if Input.Trim = '' then
        Break;

      Writeln;
      RunResult := Agent.Run(Input, ThreadId);

      case RunResult.Status of
        grsFinished:
          Writeln('');

        grsWaitingApproval:
        begin
          Writeln;
          Writeln('⏸  Aguardando aprovação humana...');
          Writeln('   Nó pendente: ' + RunResult.PendingNode);
          Write('   Aprovar? (s/n): ');
          Readln(Confirm);
          if Confirm.ToLower = 's' then
          begin
            RunResult := Agent.Resume(ThreadId);
            Writeln('   Continuando...');
          end
          else
          begin
            Agent.Cancel(ThreadId);
            Writeln('   Cancelado.');
          end;
        end;

        grsError:
          Writeln('ERRO: ' + RunResult.ErrorMsg);
      end;
      Writeln;
    until False;
  finally
    Agent := nil;
    LLMNode.Free;
    ToolsNode.Free;
  end;
end.
