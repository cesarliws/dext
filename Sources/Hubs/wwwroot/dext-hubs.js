/**
 * Dext Hub Connection Client
 * 
 * SignalR-compatible JavaScript client for Dext.Hubs
 * 
 * Usage:
 *   const connection = new DextHubConnection('/hubs/dashboard');
 *   connection.on('ReceiveMessage', (msg) => console.log(msg));
 *   await connection.start();
 *   await connection.invoke('SendMessage', 'Hello!');
 * 
 * @author Cesar Romero
 * @license Apache-2.0
 */

class DextHubConnection {
  /**
   * Creates a new Hub connection
   * @param {string} hubUrl - The Hub endpoint URL (e.g., '/hubs/dashboard')
   * @param {Object} options - Connection options
   */
  constructor(hubUrl, options = {}) {
    this.hubUrl = hubUrl;
    this.options = {
      transport: 'auto',
      fallback: true,
      withCredentials: true,
      reconnect: true,
      reconnectDelay: 3000,
      ...options
    };
    
    this.connectionId = null;
    this.eventSource = null;
    this.socket = null;
    this.transport = null;
    this.handlers = new Map();
    this.state = 'disconnected'; // disconnected, connecting, connected, reconnecting
    this.invocationId = 0;
    this.pendingInvocations = new Map();
  }
  
  /**
   * Registers a handler for a Hub method
   * @param {string} methodName - The method name to handle
   * @param {Function} handler - The handler function
   */
  on(methodName, handler) {
    if (!this.handlers.has(methodName)) {
      this.handlers.set(methodName, []);
    }
    this.handlers.get(methodName).push(handler);
    return this;
  }
  
  /**
   * Removes a handler for a Hub method
   * @param {string} methodName - The method name
   * @param {Function} handler - The handler to remove (optional, removes all if not specified)
   */
  off(methodName, handler) {
    if (!handler) {
      this.handlers.delete(methodName);
    } else if (this.handlers.has(methodName)) {
      const handlers = this.handlers.get(methodName);
      const index = handlers.indexOf(handler);
      if (index > -1) {
        handlers.splice(index, 1);
      }
    }
    return this;
  }
  
  /**
   * Starts the Hub connection
   * @returns {Promise<void>}
   */
  async start() {
    if (this.state === 'connected') {
      return;
    }
    
    this.state = 'connecting';
    
    try {
      // Step 1: Negotiate
      const negotiateResponse = await this._negotiate();
      this.connectionId = negotiateResponse.connectionId;
      
      // Step 2: Connect the best advertised transport, with a real fallback.
      const transports = this._getTransportCandidates(negotiateResponse);
      let lastError = null;
      for (const transport of transports) {
        try {
          if (transport === 'webSockets') {
            await this._connectWebSocket();
          } else if (transport === 'serverSentEvents') {
            await this._connectSSE();
          }
          this.transport = transport;
          lastError = null;
          break;
        } catch (error) {
          lastError = error;
          this._cleanupTransport();
        }
      }

      if (lastError || !this.transport) {
        throw lastError || new Error('No compatible Hub transport is available');
      }
      
      this.state = 'connected';
      this._triggerHandlers('connected', { connectionId: this.connectionId });
      
    } catch (error) {
      this.state = 'disconnected';
      throw error;
    }
  }
  
  /**
   * Stops the Hub connection
   * @returns {Promise<void>}
   */
  async stop() {
    this._cleanupTransport();

    for (const pending of this.pendingInvocations.values()) {
      pending.reject(new Error('Hub connection stopped'));
    }
    this.pendingInvocations.clear();
    
    this.state = 'disconnected';
    this.connectionId = null;
    this.transport = null;
    this._triggerHandlers('disconnected', {});
  }
  
  /**
   * Invokes a Hub method on the server
   * @param {string} methodName - The method to invoke
   * @param {...any} args - Arguments to pass
   * @returns {Promise<any>} The method result
   */
  async invoke(methodName, ...args) {
    if (this.state !== 'connected') {
      throw new Error('Cannot invoke: not connected');
    }
    
    const invocationId = String(++this.invocationId);
    
    const request = {
      type: 1, // Invocation
      invocationId: invocationId,
      target: methodName,
      arguments: args
    };
    
    if (this.transport === 'webSockets' && this.socket) {
      return new Promise((resolve, reject) => {
        this.pendingInvocations.set(invocationId, { resolve, reject });
        try {
          this.socket.send(JSON.stringify(request) + '\x1e');
        } catch (error) {
          this.pendingInvocations.delete(invocationId);
          reject(error);
        }
      });
    }
    
    return new Promise(async (resolve, reject) => {
      this.pendingInvocations.set(invocationId, { resolve, reject });
      
      try {
        const response = await fetch(`${this.hubUrl}?id=${this.connectionId}`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json'
          },
          credentials: this.options.withCredentials ? 'same-origin' : 'omit',
          body: JSON.stringify(request)
        });
        
        const result = await response.json();
        
        this.pendingInvocations.delete(invocationId);
        
        if (result.error) {
          reject(new Error(result.error));
        } else {
          resolve(result.result);
        }
      } catch (error) {
        this.pendingInvocations.delete(invocationId);
        reject(error);
      }
    });
  }
  
  /**
   * Sends a message without waiting for result
   * @param {string} methodName - The method to invoke
   * @param {...any} args - Arguments to pass
   */
  async send(methodName, ...args) {
    if (this.state !== 'connected') {
      throw new Error('Cannot send: not connected');
    }
    
    const request = {
      type: 1, // Invocation
      target: methodName,
      arguments: args
    };
    
    if (this.transport === 'webSockets' && this.socket) {
      this.socket.send(JSON.stringify(request) + '\x1e');
    } else {
      await fetch(`${this.hubUrl}?id=${this.connectionId}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        credentials: this.options.withCredentials ? 'same-origin' : 'omit',
        body: JSON.stringify(request)
      });
    }
  }
  
  /**
   * Negotiate connection
   * @private
   */
  async _negotiate() {
    const response = await fetch(`${this.hubUrl}/negotiate`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      credentials: this.options.withCredentials ? 'same-origin' : 'omit'
    });
    
    if (!response.ok) {
      throw new Error(`Negotiate failed: ${response.status}`);
    }
    
    return await response.json();
  }

  /**
   * Returns client/server compatible transports in connection priority order.
   * @private
   */
  _getTransportCandidates(negotiateResponse) {
    const advertised = new Set(
      (negotiateResponse.availableTransports || []).map(item => item.transport)
    );
    const supported = [];
    if (advertised.has('WebSockets') && typeof WebSocket !== 'undefined') {
      supported.push('webSockets');
    }
    if (advertised.has('ServerSentEvents') && typeof EventSource !== 'undefined') {
      supported.push('serverSentEvents');
    }

    const requested = String(this.options.transport || 'auto').toLowerCase();
    if (requested === 'auto') {
      return supported;
    }

    const normalized = requested === 'websockets'
      ? 'webSockets'
      : requested === 'serversentevents'
        ? 'serverSentEvents'
        : null;
    if (!normalized) {
      throw new Error(`Unsupported Hub transport: ${this.options.transport}`);
    }

    const selected = supported.filter(item => item === normalized);
    if (this.options.fallback && normalized === 'webSockets') {
      selected.push(...supported.filter(item => item !== normalized));
    }
    return selected;
  }

  /** @private */
  _cleanupTransport() {
    if (this.socket) {
      this.socket.onopen = null;
      this.socket.onerror = null;
      this.socket.onclose = null;
      this.socket.onmessage = null;
      this.socket.close();
      this.socket = null;
    }
    if (this.eventSource) {
      this.eventSource.onopen = null;
      this.eventSource.onerror = null;
      this.eventSource.onmessage = null;
      this.eventSource.close();
      this.eventSource = null;
    }
  }
  
  /**
   * Connect using Server-Sent Events
   * @private
   */
  async _connectSSE() {
    return new Promise((resolve, reject) => {
      const url = `${this.hubUrl}?id=${this.connectionId}`;
      let settled = false;
      this.eventSource = new EventSource(url, {
        withCredentials: this.options.withCredentials
      });
      
      this.eventSource.onopen = () => {
        settled = true;
        resolve();
      };
      
      this.eventSource.onerror = (event) => {
        if (!settled) {
          settled = true;
          reject(new Error('SSE connection failed'));
        } else if (this.options.reconnect && this.state === 'connected') {
          this._handleReconnect();
        }
      };
      
      // Handle 'connected' event
      this.eventSource.addEventListener('connected', (event) => {
        const data = JSON.parse(event.data);
        console.log('Hub connected:', data.connectionId);
      });
      
      // Handle default message event (Hub invocations)
      this.eventSource.onmessage = (event) => {
        this._handleMessage(event.data);
      };
    });
  }
  
  /**
   * Connect using WebSockets
   * @private
   */
  async _connectWebSocket() {
    return new Promise((resolve, reject) => {
      let wsUrl;
      let settled = false;
      if (this.hubUrl.startsWith('http://') || this.hubUrl.startsWith('https://')) {
        wsUrl = this.hubUrl.replace(/^http/, 'ws');
      } else {
        const loc = window.location;
        const protocol = loc.protocol === 'https:' ? 'wss:' : 'ws:';
        const host = loc.host;
        const path = this.hubUrl.startsWith('/') ? this.hubUrl : '/' + this.hubUrl;
        wsUrl = `${protocol}//${host}${path}`;
      }
      
      wsUrl += `?id=${this.connectionId}`;
      
      this.socket = new WebSocket(wsUrl);
      
      this.socket.onopen = () => {
        settled = true;
        resolve();
      };
      
      this.socket.onerror = (error) => {
        if (!settled) {
          settled = true;
          reject(new Error('WebSocket connection failed'));
        } else if (this.options.reconnect && this.state === 'connected') {
          this._handleReconnect();
        }
      };
      
      this.socket.onclose = () => {
        if (!settled) {
          settled = true;
          reject(new Error('WebSocket connection closed before opening'));
          return;
        }
        if (this.state === 'connected') {
          if (this.options.reconnect) {
            this._handleReconnect();
          } else {
            this.stop();
          }
        }
      };
      
      this.socket.onmessage = (event) => {
        const records = event.data.split('\x1e');
        for (const record of records) {
          if (record) {
            this._handleMessage(record);
          }
        }
      };
    });
  }
  
  /**
   * Connect using Long Polling (fallback)
   * @private
   */
  async _connectLongPolling() {
    // Long polling implementation would go here
    throw new Error('Long polling not yet implemented');
  }
  
  /**
   * Handle incoming message
   * @private
   */
  _handleMessage(data) {
    try {
      // Remove record separator if present
      const cleanData = data.replace(/\x1e$/, '');
      if (!cleanData) return;
      
      const message = JSON.parse(cleanData);
      
      switch (message.type) {
        case 1: // Invocation
          this._handleInvocation(message);
          break;
        case 3: // Completion
          this._handleCompletion(message);
          break;
        case 6: // Ping
          // Keep-alive, no action needed
          break;
        case 7: // Close
          this._handleClose(message);
          break;
      }
    } catch (error) {
      console.error('Error handling message:', error, data);
    }
  }
  
  /**
   * Handle Hub method invocation from server
   * @private
   */
  _handleInvocation(message) {
    const { target, arguments: args } = message;
    this._triggerHandlers(target, ...(args || []));
  }
  
  /**
   * Handle completion message
   * @private
   */
  _handleCompletion(message) {
    const pending = this.pendingInvocations.get(message.invocationId);
    if (pending) {
      this.pendingInvocations.delete(message.invocationId);
      if (message.error) {
        pending.reject(new Error(message.error));
      } else {
        pending.resolve(message.result);
      }
    }
  }
  
  /**
   * Handle close message
   * @private
   */
  _handleClose(message) {
    console.log('Hub connection closed:', message.error || 'No error');
    this.stop();
  }
  
  /**
   * Handle reconnection
   * @private
   */
  async _handleReconnect() {
    if (this.state === 'reconnecting') return;
    
    this.state = 'reconnecting';
    console.log('Attempting to reconnect...');
    
    if (this.socket) {
      this.socket.close();
      this.socket = null;
    }
    
    if (this.eventSource) {
      this.eventSource.close();
      this.eventSource = null;
    }
    
    setTimeout(async () => {
      try {
        await this.start();
        console.log('Reconnected successfully');
      } catch (error) {
        console.error('Reconnection failed:', error);
        this._handleReconnect(); // Try again
      }
    }, this.options.reconnectDelay);
  }
  
  /**
   * Trigger handlers for a method
   * @private
   */
  _triggerHandlers(methodName, ...args) {
    const handlers = this.handlers.get(methodName);
    if (handlers) {
      handlers.forEach(handler => {
        try {
          handler(...args);
        } catch (error) {
          console.error(`Error in handler for ${methodName}:`, error);
        }
      });
    }
  }
  
  /**
   * Gets the current connection state
   */
  get connectionState() {
    return this.state;
  }
}

// Export for different module systems
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { DextHubConnection };
} else if (typeof window !== 'undefined') {
  window.DextHubConnection = DextHubConnection;
}
