unit Dext.Hubs;

interface

uses
  System.SysUtils,
  Dext,
  Dext.Web,
  // {BEGIN_DEXT_USES}
  // Generated Uses
  Dext.Web.Hubs.Clients,
  Dext.Web.Hubs.Connections,
  Dext.Web.Hubs.Context,
  Dext.Web.Hubs.Extensions,
  Dext.Web.Hubs.Hub,
  Dext.Web.Hubs.Interfaces,
  Dext.Web.Hubs.Middleware,
  Dext.Web.Hubs,
  Dext.Web.Hubs.Types,
  Dext.Web.Hubs.Transport.SSE
  // {END_DEXT_USES}
  ;

type
  // {BEGIN_DEXT_ALIASES}
  // Generated Aliases

  // Dext.Web.Hubs
  THubOptions = Dext.Web.Hubs.THubOptions;
  TNegotiateResponse = Dext.Web.Hubs.TNegotiateResponse;
  HubMethodAttribute = Dext.Web.Hubs.HubMethodAttribute;
  TJsonHubProtocol = Dext.Web.Hubs.TJsonHubProtocol;
  EHubException = Dext.Web.Hubs.EHubException;
  EConnectionNotFoundException = Dext.Web.Hubs.EConnectionNotFoundException;
  EHubMethodNotFoundException = Dext.Web.Hubs.EHubMethodNotFoundException;
  EHubInvocationException = Dext.Web.Hubs.EHubInvocationException;
  EHubPayloadTooLargeException = Dext.Web.Hubs.EHubPayloadTooLargeException;

  // Dext.Web.Hubs.Clients
  TClientProxy = Dext.Web.Hubs.Clients.TClientProxy;
  TAllClientsProxy = Dext.Web.Hubs.Clients.TAllClientsProxy;
  TGroupClientsProxy = Dext.Web.Hubs.Clients.TGroupClientsProxy;
  TUserClientsProxy = Dext.Web.Hubs.Clients.TUserClientsProxy;
  THubClients = Dext.Web.Hubs.Clients.THubClients;

  // Dext.Web.Hubs.Connections
  THubConnection = Dext.Web.Hubs.Connections.THubConnection;
  TConnectionManager = Dext.Web.Hubs.Connections.TConnectionManager;
  TGroupManager = Dext.Web.Hubs.Connections.TGroupManager;

  // Dext.Web.Hubs.Context
  THubContext = Dext.Web.Hubs.Context.THubContext;
  THubCallerContext = Dext.Web.Hubs.Context.THubCallerContext;

  // Dext.Web.Hubs.Extensions
  THubExtensions = Dext.Web.Hubs.Extensions.THubExtensions;

  // Dext.Web.Hubs.Hub
  THub = Dext.Web.Hubs.Hub.THub;
  THubClass = Dext.Web.Hubs.Hub.THubClass;

  // Dext.Web.Hubs.Interfaces
  IClientProxy = Dext.Web.Hubs.Interfaces.IClientProxy;
  IHubClients = Dext.Web.Hubs.Interfaces.IHubClients;
  IGroupManager = Dext.Web.Hubs.Interfaces.IGroupManager;
  IHubCallerContext = Dext.Web.Hubs.Interfaces.IHubCallerContext;
  IHubConnection = Dext.Web.Hubs.Interfaces.IHubConnection;
  IConnectionManager = Dext.Web.Hubs.Interfaces.IConnectionManager;
  IHubProtocol = Dext.Web.Hubs.Interfaces.IHubProtocol;
  TTransportType = Dext.Web.Hubs.Interfaces.TTransportType;
  TTransportTypes = Dext.Web.Hubs.Interfaces.TTransportTypes;
  TConnectionState = Dext.Web.Hubs.Interfaces.TConnectionState;
  IHubContext = Dext.Web.Hubs.Interfaces.IHubContext;
  THubMessageType = Dext.Web.Hubs.Interfaces.THubMessageType;
  THubMessage = Dext.Web.Hubs.Interfaces.THubMessage;
  TOnMessageReceived = Dext.Web.Hubs.Interfaces.TOnMessageReceived;
  TOnConnectionEvent = Dext.Web.Hubs.Interfaces.TOnConnectionEvent;
  IHubTransport = Dext.Web.Hubs.Interfaces.IHubTransport;
  IHubLifecycle = Dext.Web.Hubs.Interfaces.IHubLifecycle;

  // Dext.Web.Hubs.Middleware
  THubEndpoint = Dext.Web.Hubs.Middleware.THubEndpoint;
  THubDispatcher = Dext.Web.Hubs.Middleware.THubDispatcher;
  THubMiddleware = Dext.Web.Hubs.Middleware.THubMiddleware;

  // Dext.Web.Hubs.Transport.SSE
  TSSEConnection = Dext.Web.Hubs.Transport.SSE.TSSEConnection;
  TSSETransport = Dext.Web.Hubs.Transport.SSE.TSSETransport;
  TSSEWriter = Dext.Web.Hubs.Transport.SSE.TSSEWriter;

  // Dext.Web.Hubs.Types
  TTransportInfo = Dext.Web.Hubs.Types.TTransportInfo;
  TInvocationRequest = Dext.Web.Hubs.Types.TInvocationRequest;
  TInvocationResult = Dext.Web.Hubs.Types.TInvocationResult;

const
  // Dext.Web.Hubs.Interfaces
  ttWebSockets = Dext.Web.Hubs.Interfaces.ttWebSockets;
  ttServerSentEvents = Dext.Web.Hubs.Interfaces.ttServerSentEvents;
  ttLongPolling = Dext.Web.Hubs.Interfaces.ttLongPolling;
  csConnecting = Dext.Web.Hubs.Interfaces.csConnecting;
  csConnected = Dext.Web.Hubs.Interfaces.csConnected;
  csReconnecting = Dext.Web.Hubs.Interfaces.csReconnecting;
  csDisconnected = Dext.Web.Hubs.Interfaces.csDisconnected;
  hmtInvocation = Dext.Web.Hubs.Interfaces.hmtInvocation;
  hmtStreamItem = Dext.Web.Hubs.Interfaces.hmtStreamItem;
  hmtCompletion = Dext.Web.Hubs.Interfaces.hmtCompletion;
  hmtStreamInvocation = Dext.Web.Hubs.Interfaces.hmtStreamInvocation;
  hmtCancelInvocation = Dext.Web.Hubs.Interfaces.hmtCancelInvocation;
  hmtPing = Dext.Web.Hubs.Interfaces.hmtPing;
  hmtClose = Dext.Web.Hubs.Interfaces.hmtClose;
  // {END_DEXT_ALIASES}

implementation

end.
