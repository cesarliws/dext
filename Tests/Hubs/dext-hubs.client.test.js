'use strict'

const assert = require('node:assert/strict')
const path = require('node:path')

const clientPath = path.resolve(__dirname, '../../Sources/Hubs/wwwroot/dext-hubs.js')
const { DextHubConnection } = require(clientPath)

class FailingWebSocket {
  static instances = 0

  constructor(url) {
    this.url = url
    FailingWebSocket.instances += 1
    queueMicrotask(() => this.onerror && this.onerror(new Error('blocked')))
  }

  close() {}
}

class WorkingWebSocket {
  static instances = 0

  constructor(url) {
    this.url = url
    WorkingWebSocket.instances += 1
    queueMicrotask(() => this.onopen && this.onopen())
  }

  send() {}
  close() {}
}

class WorkingEventSource {
  static instances = 0

  constructor(url, options) {
    this.url = url
    this.options = options
    WorkingEventSource.instances += 1
    queueMicrotask(() => this.onopen && this.onopen())
  }

  addEventListener() {}
  close() {}
}

async function testWebSocketFallsBackToSSE() {
  const fetchCalls = []
  global.WebSocket = FailingWebSocket
  global.EventSource = WorkingEventSource
  global.fetch = async (url, options) => {
    fetchCalls.push({ url, options })
    return {
      ok: true,
      json: async () => ({
        connectionId: '0123456789abcdef0123456789abcdef',
        availableTransports: [
          { transport: 'WebSockets', transferFormats: ['Text'] },
          { transport: 'ServerSentEvents', transferFormats: ['Text'] }
        ]
      })
    }
  }

  const connection = new DextHubConnection('https://example.test/hubs/events')
  await connection.start()

  assert.equal(FailingWebSocket.instances, 1)
  assert.equal(WorkingEventSource.instances, 1)
  assert.equal(connection.transport, 'serverSentEvents')
  assert.equal(connection.connectionState, 'connected')
  assert.equal(fetchCalls[0].options.credentials, 'same-origin')
  assert.equal(connection.eventSource.options.withCredentials, true)

  await connection.stop()
}

async function testNegotiationCapabilitiesAreRespected() {
  FailingWebSocket.instances = 0
  WorkingEventSource.instances = 0
  global.fetch = async () => ({
    ok: true,
    json: async () => ({
      connectionId: 'fedcba9876543210fedcba9876543210',
      availableTransports: [
        { transport: 'ServerSentEvents', transferFormats: ['Text'] }
      ]
    })
  })

  const connection = new DextHubConnection('https://example.test/hubs/events')
  await connection.start()

  assert.equal(FailingWebSocket.instances, 0)
  assert.equal(WorkingEventSource.instances, 1)
  assert.equal(connection.transport, 'serverSentEvents')

  await connection.stop()
}

async function testDisabledFallbackFailsClosed() {
  FailingWebSocket.instances = 0
  WorkingEventSource.instances = 0
  global.fetch = async () => ({
    ok: true,
    json: async () => ({
      connectionId: '00112233445566778899aabbccddeeff',
      availableTransports: [
        { transport: 'WebSockets', transferFormats: ['Text'] },
        { transport: 'ServerSentEvents', transferFormats: ['Text'] }
      ]
    })
  })

  const connection = new DextHubConnection('https://example.test/hubs/events', {
    transport: 'webSockets',
    fallback: false
  })

  await assert.rejects(connection.start(), /WebSocket connection failed/)
  assert.equal(WorkingEventSource.instances, 0)
  assert.equal(connection.connectionState, 'disconnected')
}

// A second start() whose negotiation no longer advertises the transport the
// connection was using must fail closed, instead of reporting 'connected' on
// the transport left over from the previous session.
async function testRestartWithNoCandidateFailsClosed() {
  let advertiseWebSockets = true
  global.WebSocket = WorkingWebSocket
  global.EventSource = WorkingEventSource
  global.fetch = async () => ({
    ok: true,
    json: async () => ({
      connectionId: 'ffeeddccbbaa99887766554433221100',
      availableTransports: advertiseWebSockets
        ? [{ transport: 'WebSockets', transferFormats: ['Text'] }]
        : [{ transport: 'ServerSentEvents', transferFormats: ['Text'] }]
    })
  })

  const connection = new DextHubConnection('https://example.test/hubs/events', {
    transport: 'webSockets',
    fallback: false
  })

  await connection.start()
  assert.equal(connection.transport, 'webSockets')

  // Reproduce the reconnect path: _handleReconnect() drops the socket and calls
  // start() again without going through stop(), so start() is what has to clear
  // the transport left over from the previous session.
  connection.state = 'reconnecting'
  connection.socket = null
  advertiseWebSockets = false

  await assert.rejects(connection.start(),
    /No compatible Hub transport is available/)
  assert.equal(connection.transport, null)
  assert.equal(connection.connectionState, 'disconnected')
}

// A hub URL with a trailing slash must not produce '//negotiate', which the
// server routes as a distinct path.
function testHubUrlIsCanonicalized() {
  assert.equal(new DextHubConnection('/hubs/demo/').hubUrl, '/hubs/demo')
  assert.equal(new DextHubConnection('https://example.test/hubs/demo//').hubUrl,
    'https://example.test/hubs/demo')
  assert.equal(new DextHubConnection('/hubs/demo').hubUrl, '/hubs/demo')
  assert.equal(new DextHubConnection('/').hubUrl, '/')
}

async function main() {
  testHubUrlIsCanonicalized()
  await testWebSocketFallsBackToSSE()
  await testNegotiationCapabilitiesAreRespected()
  await testDisabledFallbackFailsClosed()
  await testRestartWithNoCandidateFailsClosed()
  console.log('Dext Hub JavaScript client tests passed')
}

main().catch(error => {
  console.error(error)
  process.exitCode = 1
})
