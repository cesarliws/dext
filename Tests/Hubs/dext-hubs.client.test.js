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

async function main() {
  await testWebSocketFallsBackToSSE()
  await testNegotiationCapabilitiesAreRespected()
  await testDisabledFallbackFailsClosed()
  console.log('Dext Hub JavaScript client tests passed')
}

main().catch(error => {
  console.error(error)
  process.exitCode = 1
})
