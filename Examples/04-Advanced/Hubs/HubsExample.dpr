program HubsExample;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  Dext.MM,
  System.SysUtils,
  System.Classes,
  System.Rtti,
  Dext,
  Dext.Utils,
  Dext.Web,
  Dext.Web.Hubs,
  Dext.Web.Hubs.Extensions;

type
  /// <summary>
  /// Example Hub for real-time communication
  /// </summary>
  TDemoHub = class(THub)
  public
    /// <summary>
    /// Called when a client connects
    /// </summary>
    procedure OnConnectedAsync; override;
    
    /// <summary>
    /// Called when a client disconnects
    /// </summary>
    procedure OnDisconnectedAsync(const Exception: Exception); override;
    
    /// <summary>
    /// Client invokes this to send a message to everyone
    /// </summary>
    [HubMethod]
    procedure SendMessage(const User, Message: string);
    
    /// <summary>
    /// Client invokes this to join a group
    /// </summary>
    [HubMethod]
    procedure JoinGroup(const GroupName: string);
    
    /// <summary>
    /// Client invokes this to leave a group
    /// </summary>
    [HubMethod]
    procedure LeaveGroup(const GroupName: string);
    
    /// <summary>
    /// Client invokes this to send a message to a group
    /// </summary>
    [HubMethod]
    procedure SendToGroup(const GroupName, User, Message: string);
  end;

procedure TDemoHub.OnConnectedAsync;
begin
  WriteLn('[Hub] Client connected: ', Context.ConnectionId);
  
  // Notify all clients except caller
  Clients.Others.SendAsync('UserConnected', [TValue.From(Context.ConnectionId)]);
end;

procedure TDemoHub.OnDisconnectedAsync(const Exception: Exception);
begin
  WriteLn('[Hub] Client disconnected: ', Context.ConnectionId);
  
  if Exception <> nil then
    WriteLn('[Hub] Reason: ', Exception.Message);
    
  // Notify all clients
  Clients.Others.SendAsync('UserDisconnected', [TValue.From(Context.ConnectionId)]);
end;

procedure TDemoHub.SendMessage(const User, Message: string);
begin
  WriteLn('[Hub] ', User, ': ', Message);
  
  // Broadcast to all clients
  Clients.All.SendAsync('ReceiveMessage', [TValue.From(User), TValue.From(Message)]);
end;

procedure TDemoHub.JoinGroup(const GroupName: string);
begin
  WriteLn('[Hub] ', Context.ConnectionId, ' joined group: ', GroupName);
  
  Groups.AddToGroupAsync(Context.ConnectionId, GroupName);
  
  // Notify the caller
  Clients.Caller.SendAsync('JoinedGroup', [TValue.From(GroupName)]);
  
  // Notify others in the group
  Clients.OthersInGroup(GroupName).SendAsync('UserJoinedGroup', [
    TValue.From(Context.ConnectionId), 
    TValue.From(GroupName)
  ]);
end;

procedure TDemoHub.LeaveGroup(const GroupName: string);
begin
  WriteLn('[Hub] ', Context.ConnectionId, ' left group: ', GroupName);
  
  Groups.RemoveFromGroupAsync(Context.ConnectionId, GroupName);
  
  // Notify the caller
  Clients.Caller.SendAsync('LeftGroup', [TValue.From(GroupName)]);
  
  // Notify others in the group
  Clients.Group(GroupName).SendAsync('UserLeftGroup', [
    TValue.From(Context.ConnectionId), 
    TValue.From(GroupName)
  ]);
end;

procedure TDemoHub.SendToGroup(const GroupName, User, Message: string);
begin
  WriteLn('[Hub] [', GroupName, '] ', User, ': ', Message);
  
  // Send only to group members
  Clients.Group(GroupName).SendAsync('ReceiveGroupMessage', [
    TValue.From(GroupName), 
    TValue.From(User), 
    TValue.From(Message)
  ]);
end;

var
  App: IWebApplication;
  TimeThread: TThread;
  TimeCounter: Integer;
  Running: Boolean;
  Builder: TAppBuilder;
begin
  try
    WriteLn('===========================================');
    WriteLn('   Dext.Web.Hubs - Example Server');
    WriteLn('===========================================');
    WriteLn;
    
    // 1. Create Application
    App := TDextApplication.Create;
    
    // 2. Configure pipeline
    Builder := App.GetBuilder;
    
    // Serve static files (for the demo HTML page)
    Builder.UseStaticFiles;
    
    // Enable Hubs middleware
    THubExtensions.UseHubs(Builder.Unwrap);
    
    // Map our demo Hub
    MapHub(Builder.Unwrap, '/hubs/demo', TDemoHub);
    
    WriteLn('Hub endpoints:');
    WriteLn('  POST /hubs/demo/negotiate - Get connection ID');
    WriteLn('  GET  /hubs/demo/poll?id=xxx - Poll for messages');
    WriteLn('  POST /hubs/demo?id=xxx    - Invoke method');
    WriteLn;
    WriteLn('Static files: ./wwwroot');
    WriteLn;
    WriteLn('Starting server on port 5000...');
    WriteLn('Open http://localhost:5000 in your browser');
    WriteLn;
    WriteLn('Press Enter to stop');
    
    // Build services
    App.BuildServices;
    
    // Start background thread for server time broadcast
    Running := True;
    TimeCounter := 0;
    TimeThread := TThread.CreateAnonymousThread(
      procedure
      var
        HubContext: IHubContext;
        TimeStr: string;
      begin
        Sleep(2000); // Wait for server startup
        
        while Running do
        begin
          try
            HubContext := THubExtensions.GetHubContext;
            if HubContext <> nil then
            begin
              Inc(TimeCounter);
              TimeStr := FormatDateTime('hh:nn:ss', Now);
              HubContext.Clients.All.SendAsync('ServerTime', [
                TValue.From(TimeStr), 
                TValue.From(TimeCounter)
              ]);
            end;
          except
            // Ignore broadcast errors
          end;
          Sleep(5000); // Every 5 seconds
        end;
      end
    );
    TimeThread.FreeOnTerminate := False;
    TimeThread.Start;
    
    // Run on port 5000
    App.Run(5000);
    
    // Cleanup
    Running := False;
    TimeThread.WaitFor;
    TimeThread.Free;
    
  except
    on E: Exception do
    begin
      WriteLn('Error: ', E.ClassName, ': ', E.Message);
    end;
  end;
  ConsolePause;
end.
