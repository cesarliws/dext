---
name: dext-mcp
description: Create and configure MCP (Model Context Protocol) servers, tools, resources, and prompts using Dext. Use for connecting Delphi databases and logic to AI models.
---

# Dext MCP Server

Dext includes native support for the **Model Context Protocol (MCP) v2025-03-26**, allowing you to expose your Delphi applications (databases, business logic, tools) to AI models (like Gemini and Claude) locally or over HTTP.

## Core Imports

```pascal
uses
  Dext.AI.MCP.Server,
  Dext.AI.MCP.Tools,
  Dext.AI.MCP.Types,
  Dext.AI.MCP.Attributes,
  Dext.AI.MCP.Protocol;
```

---

## 🏗️ Creating an MCP Provider (RTTI)

The most organized way to write tools, resources, and prompts is by inheriting from `TMCPToolProvider` and using custom RTTI attributes.

```pascal
type
  TMyDatabaseProvider = class(TMCPToolProvider)
  private
    FConn: TFDConnection;
  public
    constructor Create(AConn: TFDConnection);

    // Expose a Tool
    [MCPTool('get-participants', 'Returns the list of participants.')]
    function GetParticipants(const Args: TJSONObject): TMCPToolResult; virtual;

    // Expose a Tool with Parameters
    [MCPTool('draw-winner', 'Draws a random winner.')]
    [MCPParam('event_name', 'The name of the event', ptString, True)]
    function DrawWinner(const Args: TJSONObject): TMCPToolResult; virtual;

    // Expose a Resource (documents/rules AI can read by URI)
    [MCPResource('rules://draw', 'Draw Rules', 'Rules of the game', 'text/plain')]
    function ReadRules(const AUri: string): TMCPResourceContents; virtual;
  end;
```

### Implementing Safe DB Tool Callbacks

MCP Tool callbacks are executed in **background threads** (when using HTTP/SSE transports). You must create local query components or synchronize visual updates with the Main Thread:

```pascal
function TMyDatabaseProvider.DrawWinner(const Args: TJSONObject): TMCPToolResult;
var
  Qry: TFDQuery;
  EventName: string;
begin
  EventName := Args.GetValue<string>('event_name');
  
  Qry := TFDQuery.Create(nil);
  try
    Qry.Connection := FConn;
    Qry.Open('SELECT id, name FROM participants WHERE status = 0 ORDER BY RANDOM() LIMIT 1');
    
    if Qry.IsEmpty then
      Exit(TMCPToolResult.Error('No participants left.'));
      
    var Name := Qry.FieldByName('name').AsString;
    
    // Update DB
    Qry.Close;
    Qry.SQL.Text := 'UPDATE participants SET status = 1 WHERE name = :name';
    Qry.ParamByName('name').AsString := Name;
    Qry.ExecSQL;
    
    // If you need to update a DBGrid or any UI:
    TThread.Queue(nil,
      procedure
      begin
        // Refresh Grid / Query on the Main Thread
        FormMain.FDTable1.Refresh;
      end);

    Result := TMCPToolResult.Text(Format('Winner drawn for %s: %s', [EventName, Name]));
  finally
    Qry.Free;
  end;
end;
```

---

## 🛠️ Dynamic Database Serialization to JSON

When returning table/query data from a custom tool (e.g. `execute-sql`), avoid ambiguous Variant-to-JSON issues by checking `DataType`:

```pascal
function TMyDatabaseProvider.ExecuteSQL(const Args: TJSONObject): TMCPToolResult;
var
  Qry: TFDQuery;
  JA: TJSONArray;
  I: Integer;
begin
  var Sql := Args.GetValue<string>('sql');
  Qry := TFDQuery.Create(nil);
  try
    Qry.Connection := FConn;
    Qry.SQL.Text := Sql;
    
    if Sql.Trim.ToLower.StartsWith('select') then
    begin
      Qry.Open;
      JA := TJSONArray.Create;
      while not Qry.Eof do
      begin
        var JO := TJSONObject.Create;
        for I := 0 to Qry.FieldCount - 1 do
        begin
          if Qry.Fields[I].IsNull then
            JO.AddPair(Qry.Fields[I].FieldName, TJSONNull.Create)
          else
            case Qry.Fields[I].DataType of
              ftInteger, ftSmallint, ftWord, ftLargeint:
                JO.AddPair(Qry.Fields[I].FieldName, TJSONNumber.Create(Qry.Fields[I].AsLargeInt));
              ftFloat, ftCurrency, ftBCD, ftFMTBcd:
                JO.AddPair(Qry.Fields[I].FieldName, TJSONNumber.Create(Qry.Fields[I].AsFloat));
              ftBoolean:
                JO.AddPair(Qry.Fields[I].FieldName, TJSONBool.Create(Qry.Fields[I].AsBoolean));
              else
                JO.AddPair(Qry.Fields[I].FieldName, Qry.Fields[I].AsString);
            end;
        end;
        JA.Add(JO);
        Qry.Next;
      end;
      Result := TMCPToolResult.Text(JA.ToJSON);
    end
    else
    begin
      Qry.ExecSQL;
      Result := TMCPToolResult.Text('Command executed successfully.');
    end;
  finally
    Qry.Free;
  end;
end;
```

---

## 🚀 Running the MCP Server

```pascal
var
  Server: TMCPServer;
begin
  Server := TMCPServer.Create('my-mcp-service', '1.0.0');
  try
    // Server takes ownership of the provider
    Server.RegisterProvider(TMyDatabaseProvider.Create(FDConnection1));
    
    // mtStreamable: Non-blocking HTTP Server (Indy) - perfect for VCL/FMX
    // mtStdio: Blocking Standard Input/Output loop (Claude Desktop)
    Server.Run(mtStreamable, 'http://localhost:3031');
    
    // Application keeps running...
  finally
    Server.Stop;
    Server.Free;
  end;
end;
```

## Common Mistakes

| Wrong | Correct |
|-------|---------|
| Running `Server.Run` on mtStdio in a VCL Application without arguments | Stdio blocks the thread; use `mtStreamable` for non-blocking VCL/FMX HTTP servers. |
| Accessing/Refreshing DBGrids directly inside MCP tool callbacks | MCP HTTP callbacks run on background threads; wrap UI updates in `TThread.Queue` or `TThread.Synchronize`. |
| Adding `TField.Value` directly to `TJSONObject.AddPair` | Causes compilation errors due to Variant overload ambiguities; use a `case` switch on `TField.DataType`. |
