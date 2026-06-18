program TestDextHubs;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  Dext.MM,
  Dext.Utils,
  System.SysUtils,
  System.Rtti,
  System.JSON,
  Dext.Collections,
  // Dext.Hubs units
  Dext.Web.Hubs.Interfaces,
  Dext.Web.Hubs.Types,
  Dext.Web.Hubs.Hub,
  Dext.Web.Hubs.Connections,
  Dext.Web.Hubs.Clients,
  Dext.Web.Hubs.Context,
  Dext.Web.Hubs.Protocol.Json,
  Dext.Web.Hubs.Client.Tests;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure Check(Condition: Boolean; const TestName: string);
begin
  if Condition then
  begin
    Inc(TestsPassed);
    WriteLn('[PASS] ', TestName);
  end
  else
  begin
    Inc(TestsFailed);
    WriteLn('[FAIL] ', TestName);
  end;
end;

procedure TestTHubMessage;
var
  Msg: THubMessage;
begin
  WriteLn;
  WriteLn('=== THubMessage Tests ===');
  
  // Test Invocation
  Msg := THubMessage.Invocation('SendMessage', [TValue.From('Hello'), TValue.From(42)]);
  Check(Msg.MessageType = hmtInvocation, 'Invocation MessageType');
  Check(Msg.Target = 'SendMessage', 'Invocation Target');
  Check(Length(Msg.Arguments) = 2, 'Invocation Arguments count');
  
  // Test Completion
  Msg := THubMessage.Completion('inv123', TValue.From(True));
  Check(Msg.MessageType = hmtCompletion, 'Completion MessageType');
  Check(Msg.InvocationId = 'inv123', 'Completion InvocationId');
  
  // Test Ping
  Msg := THubMessage.Ping;
  Check(Msg.MessageType = hmtPing, 'Ping MessageType');
  
  // Test Close
  Msg := THubMessage.Close('Server shutdown');
  Check(Msg.MessageType = hmtClose, 'Close MessageType');
  Check(Msg.Error = 'Server shutdown', 'Close Error');
end;

procedure TestTJsonHubProtocol;
var
  Protocol: TJsonHubProtocol;
  Msg, Parsed: THubMessage;
  Json: string;
begin
  WriteLn;
  WriteLn('=== TJsonHubProtocol Tests ===');
  
  Protocol := TJsonHubProtocol.Create;
  try
    // Test protocol properties (via getter methods)
    Check(Protocol.GetName = 'json', 'Protocol Name');
    Check(Protocol.GetVersion = 1, 'Protocol Version');
    Check(Protocol.GetTransferFormat = 'Text', 'Protocol TransferFormat');
    
    // Test Invocation serialization
    Msg := THubMessage.Invocation('ReceiveMessage', [TValue.From('Test')]);
    Json := Protocol.Serialize(Msg);
    Check(Pos('"type":1', Json) > 0, 'Serialize Invocation type');
    Check(Pos('"target":"ReceiveMessage"', Json) > 0, 'Serialize Invocation target');
    Check(Pos('"arguments":', Json) > 0, 'Serialize Invocation arguments');
    
    // Test IsCompleteMessage
    Check(Protocol.IsCompleteMessage(Json), 'IsCompleteMessage with RS');
    Check(not Protocol.IsCompleteMessage('{"type":1}'), 'IsCompleteMessage without RS');
    
    // Test Deserialization
    Parsed := Protocol.Deserialize(Json);
    Check(Parsed.MessageType = hmtInvocation, 'Deserialize MessageType');
    Check(Parsed.Target = 'ReceiveMessage', 'Deserialize Target');
    
    // Test Ping serialization
    Json := TJsonHubProtocol.SerializePing;
    Check(Pos('"type":6', Json) > 0, 'SerializePing');
    
    // Test Close serialization
    Json := TJsonHubProtocol.SerializeClose('Error message');
    Check(Pos('"type":7', Json) > 0, 'SerializeClose type');
    Check(Pos('"error":"Error message"', Json) > 0, 'SerializeClose error');
  finally
    Protocol.Free;
  end;
end;

procedure TestTConnectionManager;
var
  ConnectionManager: TConnectionManager;
  Connection1, Connection2: THubConnection;
  Retrieved: IHubConnection;
  AllConns: TArray<IHubConnection>;
begin
  WriteLn;
  WriteLn('=== TConnectionManager Tests ===');
  
  ConnectionManager := TConnectionManager.Create;
  try
    // Test Add
    Connection1 := THubConnection.Create('conn1', ttServerSentEvents);
    Connection2 := THubConnection.Create('conn2', ttServerSentEvents);
    
    ConnectionManager.Add(Connection1);
    ConnectionManager.Add(Connection2);
    
    Check(ConnectionManager.Count = 2, 'Add connections count');
    Check(ConnectionManager.Contains('conn1'), 'Contains conn1');
    Check(ConnectionManager.Contains('conn2'), 'Contains conn2');
    Check(not ConnectionManager.Contains('conn3'), 'Not contains conn3');
    
    // Test TryGet
    Check(ConnectionManager.TryGet('conn1', Retrieved), 'TryGet existing');
    Check(Retrieved.ConnectionId = 'conn1', 'TryGet correct connection');
    Check(not ConnectionManager.TryGet('notexist', Retrieved), 'TryGet non-existing');
    
    // Test Get
    Retrieved := ConnectionManager.Get('conn2');
    Check(Retrieved.ConnectionId = 'conn2', 'Get connection');
    
    // Test GetAll
    AllConns := ConnectionManager.GetAll;
    Check(Length(AllConns) = 2, 'GetAll count');
    
    // Test Remove
    ConnectionManager.Remove('conn1');
    Check(ConnectionManager.Count = 1, 'Remove count');
    Check(not ConnectionManager.Contains('conn1'), 'Removed connection gone');
    
  finally
    ConnectionManager.Free;
  end;
end;

procedure TestTGroupManager;
var
  GroupManager: TGroupManager;
  Groups: TArray<string>;
  Connections: TArray<string>;
begin
  WriteLn;
  WriteLn('=== TGroupManager Tests ===');
  
  GroupManager := TGroupManager.Create;
  try
    // Test AddToGroup
    GroupManager.AddToGroupAsync('conn1', 'group1');
    GroupManager.AddToGroupAsync('conn1', 'group2');
    GroupManager.AddToGroupAsync('conn2', 'group1');
    
    Check(GroupManager.IsInGroup('conn1', 'group1'), 'IsInGroup conn1 in group1');
    Check(GroupManager.IsInGroup('conn1', 'group2'), 'IsInGroup conn1 in group2');
    Check(GroupManager.IsInGroup('conn2', 'group1'), 'IsInGroup conn2 in group1');
    Check(not GroupManager.IsInGroup('conn2', 'group2'), 'IsInGroup conn2 not in group2');
    
    // Test GetGroupsForConnection
    Groups := GroupManager.GetGroupsForConnection('conn1');
    Check(Length(Groups) = 2, 'GetGroupsForConnection count');
    
    // Test GetConnectionsInGroup
    Connections := GroupManager.GetConnectionsInGroup('group1');
    Check(Length(Connections) = 2, 'GetConnectionsInGroup count');
    
    // Test RemoveFromGroup
    GroupManager.RemoveFromGroupAsync('conn1', 'group1');
    Check(not GroupManager.IsInGroup('conn1', 'group1'), 'RemoveFromGroup');
    Check(GroupManager.IsInGroup('conn1', 'group2'), 'RemoveFromGroup keeps other groups');
    
    // Test RemoveFromAllGroups
    GroupManager.RemoveFromAllGroupsAsync('conn1');
    Groups := GroupManager.GetGroupsForConnection('conn1');
    Check(Length(Groups) = 0, 'RemoveFromAllGroups');
    
  finally
    GroupManager.Free;
  end;
end;

procedure TestTNegotiateResponse;
var
  Response: TNegotiateResponse;
  Json: string;
begin
  WriteLn;
  WriteLn('=== TNegotiateResponse Tests ===');
  
  Response := TNegotiateResponse.Create('test-connection-id');
  
  Check(Response.ConnectionId = 'test-connection-id', 'ConnectionId');
  Check(Response.NegotiateVersion = 1, 'NegotiateVersion');
  Check(Length(Response.AvailableTransports) = 3, 'AvailableTransports count');
  
  Json := Response.ToJson;
  Check(Pos('"connectionId":"test-connection-id"', Json) > 0, 'ToJson connectionId');
  Check(Pos('"negotiateVersion":1', Json) > 0, 'ToJson negotiateVersion');
  Check(Pos('"availableTransports":', Json) > 0, 'ToJson availableTransports');
end;

procedure TestTHubContext;
var
  ConnectionManager: TConnectionManager;
  GroupManager: TGroupManager;
  HubContext: THubContext;
  Clients: IHubClients;
begin
  WriteLn;
  WriteLn('=== THubContext Tests ===');
  
  GroupManager := TGroupManager.Create;
  ConnectionManager := TConnectionManager.Create;
  ConnectionManager.SetGroupManager(GroupManager);
  
  HubContext := THubContext.Create(ConnectionManager, GroupManager);
  try
    Clients := HubContext.Clients;
    Check(Clients <> nil, 'GetClients returns non-nil');
    Check(HubContext.Groups <> nil, 'GetGroups returns non-nil');
  finally
    HubContext.Free;
  end;
end;

procedure TestTHubCallerContext;
var
  Context: THubCallerContext;
begin
  WriteLn;
  WriteLn('=== THubCallerContext Tests ===');
  
  Context := THubCallerContext.Create('my-connection', ttServerSentEvents);
  try
    Check(Context.ConnectionId = 'my-connection', 'ConnectionId');
    Check(Context.TransportType = ttServerSentEvents, 'TransportType');
    Check(Context.Items <> nil, 'Items not nil');
    Check(Context.UserIdentifier = '', 'UserIdentifier empty without user');
    
    // Test Items
    Context.Items.Add('key1', TValue.From('value1'));
    Check(Context.Items['key1'].AsString = 'value1', 'Items access');
  finally
    Context.Free;
  end;
end;

type
  TTestHub = class(THub)
  public
    procedure TestMethod(const Message: string);
  end;

procedure TTestHub.TestMethod(const Message: string);
begin
  // Test method - would normally send to clients
  Clients.All.SendAsync('Echo', [TValue.From(Message)]);
end;

procedure TestTHub;
var
  Hub: TTestHub;
  ConnectionManager: TConnectionManager;
  GroupManager: TGroupManager;
  CallerContext: IHubCallerContext;
  HubClients: IHubClients;
begin
  WriteLn;
  WriteLn('=== THub Tests ===');
  
  GroupManager := TGroupManager.Create;
  ConnectionManager := TConnectionManager.Create;
  ConnectionManager.SetGroupManager(GroupManager);
  
  Hub := TTestHub.Create;
  try
    CallerContext := THubCallerContext.Create('test-conn', ttServerSentEvents);
    HubClients := THubClients.Create(ConnectionManager, 'test-conn');
    
    Hub.SetContext(CallerContext, HubClients, GroupManager);
    
    // Just verify it doesn't crash - actual sending needs connections
    try
      Hub.TestMethod('Hello World');
      Check(True, 'Hub method invocation');
    except
      Check(False, 'Hub method invocation');
    end;
    
    // Test lifecycle methods
    try
      Hub.OnConnectedAsync;
      Hub.OnDisconnectedAsync(nil);
      Check(True, 'Hub lifecycle methods');
    except
      Check(False, 'Hub lifecycle methods');
    end;
  finally
    Hub.Free;
  end;
end;

procedure TestValueSerialization;
var
  Value: TValue;
  JsonValue: TJSONValue;
begin
  WriteLn;
  WriteLn('=== Value Serialization Tests ===');
  
  // Integer
  Value := TValue.From(42);
  JsonValue := TJsonHubProtocol.ValueToJson(Value);
  try
    Check(JsonValue is TJSONNumber, 'Integer to JSON');
    Check(TJSONNumber(JsonValue).AsInt = 42, 'Integer value');
  finally
    JsonValue.Free;
  end;
  
  // String
  Value := TValue.From('Hello');
  JsonValue := TJsonHubProtocol.ValueToJson(Value);
  try
    Check(JsonValue is TJSONString, 'String to JSON');
    Check(TJSONString(JsonValue).Value = 'Hello', 'String value');
  finally
    JsonValue.Free;
  end;
  
  // Boolean
  Value := TValue.From(True);
  JsonValue := TJsonHubProtocol.ValueToJson(Value);
  try
    Check(JsonValue is TJSONBool, 'Boolean to JSON');
    Check(TJSONBool(JsonValue).AsBoolean = True, 'Boolean value');
  finally
    JsonValue.Free;
  end;
  
  // Float
  Value := TValue.From(3.14);
  JsonValue := TJsonHubProtocol.ValueToJson(Value);
  try
    Check(JsonValue is TJSONNumber, 'Float to JSON');
  finally
    JsonValue.Free;
  end;
end;

procedure TestTHubConnection;
var
  Connection: THubConnection;
  SentMessages: IList<string>;
begin
  WriteLn;
  WriteLn('=== THubConnection Tests ===');
  
  SentMessages := TCollections.CreateList<string>;
  try
    Connection := THubConnection.Create('test-conn', ttServerSentEvents);
    try
      Check(Connection.ConnectionId = 'test-conn', 'ConnectionId');
      Check(Connection.TransportType = ttServerSentEvents, 'TransportType');
      Check(Connection.State = csConnecting, 'State initially csConnecting');
      
      // Set state to connected (middleware would do this)
      Connection.SetState(csConnected);
      Check(Connection.State = csConnected, 'SetState to csConnected');
      
      // Test SendAsync with handler
      Connection.SetOnSend(
        procedure(Msg: string)
        begin
          SentMessages.Add(Msg);
        end
      );
      
      Connection.SendAsync('test-message-1');
      Connection.SendAsync('test-message-2');
      Check(SentMessages.Count = 2, 'SendAsync handler called');
      Check(SentMessages[0] = 'test-message-1', 'SendAsync message 1');
      Check(SentMessages[1] = 'test-message-2', 'SendAsync message 2');
      
      // Test Close
      Connection.Close('test reason');
      Check(Connection.State = csDisconnected, 'Close sets State to csDisconnected');
      
      // SendAsync should not work after close
      SentMessages.Clear;
      Connection.SendAsync('should-not-send');
      Check(SentMessages.Count = 0, 'SendAsync does nothing after Close');
      
    finally
      Connection.Free;
    end;
  finally
    // SentMessages.Free;
  end;
end;

procedure TestConnectionManagerEdgeCases;
var
  ConnectionManager: TConnectionManager;
  Connection: THubConnection;
  Retrieved: IHubConnection;
begin
  WriteLn;
  WriteLn('=== TConnectionManager Edge Cases ===');
  
  ConnectionManager := TConnectionManager.Create;
  try
    // Test TryGet non-existing returns False
    Check(not ConnectionManager.TryGet('nonexistent', Retrieved), 'TryGet non-existing returns False');
    Check(not ConnectionManager.Contains('nonexistent'), 'Contains non-existing returns False');
    
    // Test double add same ID (should replace or just work)
    Connection := THubConnection.Create('same-id', ttServerSentEvents);
    ConnectionManager.Add(Connection);
    Check(ConnectionManager.Count = 1, 'Add first');
    
    // Add another with same ID - behavior depends on implementation
    Connection := THubConnection.Create('same-id', ttLongPolling);
    ConnectionManager.Add(Connection);
    Check(ConnectionManager.Count >= 1, 'Add duplicate ID handled');
    
    // Test Remove non-existing (should not crash)
    try
      ConnectionManager.Remove('does-not-exist');
      Check(True, 'Remove non-existing does not crash');
    except
      Check(False, 'Remove non-existing does not crash');
    end;
    
    // Test Clear (if available) or remove all
    ConnectionManager.Remove('same-id');
    
  finally
    ConnectionManager.Free;
  end;
end;

procedure TestGroupManagerEdgeCases;
var
  GroupManager: TGroupManager;
  Connections: TArray<string>;
begin
  WriteLn;
  WriteLn('=== TGroupManager Edge Cases ===');
  
  GroupManager := TGroupManager.Create;
  try
    // Test GetConnectionsInGroup for non-existing group
    Connections := GroupManager.GetConnectionsInGroup('no-such-group');
    Check(Length(Connections) = 0, 'GetConnectionsInGroup empty for non-existing');
    
    // Test IsInGroup for non-existing
    Check(not GroupManager.IsInGroup('conn', 'no-group'), 'IsInGroup false for non-existing');
    
    // Test double add to same group (should be idempotent)
    GroupManager.AddToGroupAsync('conn1', 'group1');
    GroupManager.AddToGroupAsync('conn1', 'group1');
    Connections := GroupManager.GetConnectionsInGroup('group1');
    Check(Length(Connections) = 1, 'Double add is idempotent');
    
    // Test remove from group not in
    try
      GroupManager.RemoveFromGroupAsync('conn1', 'not-in-this-group');
      Check(True, 'Remove from non-member group does not crash');
    except
      Check(False, 'Remove from non-member group does not crash');
    end;
    
    // Test RemoveFromAllGroups for connection with no groups
    try
      GroupManager.RemoveFromAllGroupsAsync('no-groups-conn');
      Check(True, 'RemoveFromAllGroups for untracked connection does not crash');
    except
      Check(False, 'RemoveFromAllGroups for untracked connection does not crash');
    end;
    
  finally
    GroupManager.Free;
  end;
end;

procedure TestProtocolMultipleArguments;
var
  Protocol: TJsonHubProtocol;
  Msg, Parsed: THubMessage;
  Json: string;
begin
  WriteLn;
  WriteLn('=== Protocol Multiple Arguments Tests ===');
  
  Protocol := TJsonHubProtocol.Create;
  try
    // Test with multiple arguments of different types
    Msg := THubMessage.Invocation('MultiArg', [
      TValue.From('string'),
      TValue.From(42),
      TValue.From(True),
      TValue.From(3.14)
    ]);
    
    Json := Protocol.Serialize(Msg);
    Check(Pos('"arguments":["string",42,true,', Json) > 0, 'Multiple args serialized');
    
    // Deserialize and check
    Parsed := Protocol.Deserialize(Json);
    Check(Parsed.Target = 'MultiArg', 'MultiArg target preserved');
    Check(Length(Parsed.Arguments) = 4, 'MultiArg arguments count');
    
    // Test empty arguments
    Msg := THubMessage.Invocation('NoArgs', []);
    Json := Protocol.Serialize(Msg);
    Check(Pos('"arguments":[]', Json) > 0, 'Empty arguments serialized');
    
  finally
    Protocol.Free;
  end;
end;

procedure TestProtocolWithInvocationId;
var
  Protocol: TJsonHubProtocol;
  Msg: THubMessage;
  Json: string;
begin
  WriteLn;
  WriteLn('=== Protocol Invocation ID Tests ===');
  
  Protocol := TJsonHubProtocol.Create;
  try
    // Create message with invocation ID
    Msg.MessageType := hmtInvocation;
    Msg.InvocationId := 'inv-12345';
    Msg.Target := 'MethodWithResult';
    SetLength(Msg.Arguments, 1);
    Msg.Arguments[0] := TValue.From('arg1');
    
    Json := Protocol.Serialize(Msg);
    Check(Pos('"invocationId":"inv-12345"', Json) > 0, 'InvocationId serialized');
    
    // Test Completion message
    Msg := THubMessage.Completion('inv-12345', TValue.From('result-value'));
    Json := Protocol.Serialize(Msg);
    Check(Pos('"type":3', Json) > 0, 'Completion type');
    Check(Pos('"invocationId":"inv-12345"', Json) > 0, 'Completion invocationId');
    
    // Test Completion with error
    Msg := THubMessage.CompletionError('inv-error', 'Something went wrong');
    Json := Protocol.Serialize(Msg);
    Check(Pos('"error":"Something went wrong"', Json) > 0, 'Completion error');
    
  finally
    Protocol.Free;
  end;
end;

begin
  try
    WriteLn('=========================================');
    WriteLn('   Dext.Hubs Unit Tests');
    WriteLn('=========================================');
    
    TestTHubMessage;
    TestTJsonHubProtocol;
    TestTConnectionManager;
    TestTGroupManager;
    TestTNegotiateResponse;
    TestTHubContext;
    TestTHubCallerContext;
    TestTHub;
    TestValueSerialization;
    
    // New tests
    TestTHubConnection;
    TestConnectionManagerEdgeCases;
    TestGroupManagerEdgeCases;
    TestProtocolMultipleArguments;
    TestProtocolWithInvocationId;
    
    // Delphi Hub Client Tests
    RunClientTests(TestsPassed, TestsFailed);
    
    WriteLn;
    WriteLn('=========================================');
    WriteLn(Format('Results: %d passed, %d failed', [TestsPassed, TestsFailed]));
    WriteLn('=========================================');
    
    if TestsFailed > 0 then
      ExitCode := 1
    else
      ExitCode := 0;
      
  except
    on E: Exception do
    begin
      WriteLn('EXCEPTION: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
  
  ConsolePause;
end.
