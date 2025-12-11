unit Dext.ServerTest.Cors.Consts;

interface

const
   TextCorsHtml =
      '<!DOCTYPE html>' +
      '<html lang="en">' +
      '<head>' +
      '<meta charset="UTF-8">' +
      '<meta name="viewport" content="width=device-width, initial-scale=1.0">' +
      '<title>Dext Framework - CORS Test Demo</title>' +
      '<style>' +
      'body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }' +
      '.container { max-width: 800px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }' +
      'h1 { color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 10px; }' +
      '.test-section { margin: 20px 0; padding: 15px; border-left: 4px solid #3498db; background: #f8f9fa; }' +
      'button { background: #3498db; color: white; border: none; padding: 10px 15px; margin: 5px; border-radius: 4px; cursor: pointer; }' +
      'button:hover { background: #2980b9; }' +
      'button:disabled { background: #95a5a6; cursor: not-allowed; }' +
      '.success { color: #27ae60; }' +
      '.error { color: #e74c3c; }' +
      '.warning { color: #f39c12; }' +
      '#results { margin-top: 20px; padding: 15px; background: #f8f9fa; border-radius: 4px; max-height: 400px; overflow-y: auto; }' +
      '.log-entry { margin: 5px 0; padding: 5px; border-bottom: 1px solid #eee; }' +
      '</style>' +
      '</head>' +
      '<body>' +
      '<div class="container">' +
      '<h1>🚀 Dext Framework - CORS Test Demo</h1>' +
      '<p>Teste completo das funcionalidades CORS do framework Dext</p>' +
      '<div class="test-section">' +
      '<h3>1. Teste CORS Básico</h3>' +
      '<button onclick="testBasicCors()">Testar GET com CORS</button>' +
      '<button onclick="testPreflight()">Testar Preflight OPTIONS</button>' +
      '</div>' +
      '<div class="test-section">' +
      '<h3>2. Teste com Credenciais</h3>' +
      '<button onclick="testWithCredentials()">Testar com Credenciais</button>' +
      '<button onclick="testWithAuthHeader()">Testar com Authorization Header</button>' +
      '</div>' +
      '<div class="test-section">' +
      '<h3>3. Teste de Métodos HTTP</h3>' +
      '<button onclick="testPost()">Testar POST</button>' +
      '<button onclick="testPut()">Testar PUT</button>' +
      '<button onclick="testDelete()">Testar DELETE</button>' +
      '</div>' +
      '<div class="test-section">' +
      '<h3>4. Teste de Erros</h3>' +
      '<button onclick="testInvalidOrigin()">Testar Origem Inválida</button>' +
      '<button onclick="testInvalidMethod()">Testar Método Não Permitido</button>' +
      '</div>' +
      '<div id="results">' +
      '<h3>📋 Resultados dos Testes:</h3>' +
      '<div id="log"></div>' +
      '</div>' +
      '</div>' +
      '<script>' +
      'const BASE_URL = "http://localhost:8080";' +
      'let testCount = 0;' +
      'function log(message, type = "info") {' +
      'testCount++;' +
      'const logDiv = document.getElementById("log");' +
      'const entry = document.createElement("div");' +
      'entry.className = "log-entry " + type;' +
      'entry.innerHTML = "<strong>#" + testCount + "</strong> " + new Date().toLocaleTimeString() + " - " + message;' +
      'logDiv.appendChild(entry);' +
      'logDiv.scrollTop = logDiv.scrollHeight;' +
      '}' +
      'async function testBasicCors() {' +
      'log("🔄 Iniciando teste CORS básico...", "warning");' +
      'try {' +
      'const response = await fetch(BASE_URL + "/cors-test", {' +
      'method: "GET",' +
      'headers: { "Content-Type": "application/json" }' +
      '});' +
      'if (response.ok) {' +
      'const data = await response.json();' +
      'const corsHeader = response.headers.get("access-control-allow-origin");' +
      'log("✅ <strong>SUCESSO</strong> - CORS Header: " + corsHeader + " | Response: " + JSON.stringify(data), "success");' +
      '} else {' +
      'log("❌ <strong>ERRO</strong> - Status: " + response.status, "error");' +
      '}' +
      '} catch (error) {' +
      'log("💥 <strong>EXCEÇÃO</strong> - " + error.message, "error");' +
      '}' +
      '}' +
      'async function testPreflight() {' +
      'log("🔄 Iniciando teste Preflight OPTIONS...", "warning");' +
      'try {' +
      'const response = await fetch(BASE_URL + "/cors-test", {' +
      'method: "OPTIONS",' +
      'headers: {' +
      '"Origin": "http://localhost:3000",' +
      '"Access-Control-Request-Method": "GET",' +
      '"Access-Control-Request-Headers": "Content-Type, Authorization"' +
      '}' +
      '});' +
      'const allowOrigin = response.headers.get("access-control-allow-origin");' +
      'const allowMethods = response.headers.get("access-control-allow-methods");' +
      'const allowHeaders = response.headers.get("access-control-allow-headers");' +
      'if (response.status === 204) {' +
      'log("✅ <strong>PREFLIGHT SUCESSO</strong> - Status: " + response.status + " | Headers: Origin=" + allowOrigin + ", Methods=" + allowMethods + ", Headers=" + allowHeaders, "success");' +
      '} else {' +
      'log("❌ <strong>PREFLIGHT ERRO</strong> - Status: " + response.status, "error");' +
      '}' +
      '} catch (error) {' +
      'log("💥 <strong>PREFLIGHT EXCEÇÃO</strong> - " + error.message, "error");' +
      '}' +
      '}' +
      'async function testWithCredentials() {' +
      'log("🔄 Testando com credenciais...", "warning");' +
      'try {' +
      'const response = await fetch(BASE_URL + "/cors-test", {' +
      'method: "GET",' +
      'credentials: "include",' +
      'headers: { "Content-Type": "application/json" }' +
      '});' +
      'const allowCredentials = response.headers.get("access-control-allow-credentials");' +
      'if (response.ok) {' +
      'log("✅ <strong>CREDENCIAIS SUCESSO</strong> - Allow-Credentials: " + allowCredentials, "success");' +
      '} else {' +
      'log("❌ <strong>CREDENCIAIS ERRO</strong> - Status: " + response.status, "error");' +
      '}' +
      '} catch (error) {' +
      'log("💥 <strong>CREDENCIAIS EXCEÇÃO</strong> - " + error.message, "error");' +
      '}' +
      '}' +
      'async function testWithAuthHeader() {' +
      'log("🔄 Testando com Authorization header...", "warning");' +
      'try {' +
      'const response = await fetch(BASE_URL + "/cors-test", {' +
      'method: "GET",' +
      'headers: {' +
      '"Content-Type": "application/json",' +
      '"Authorization": "Bearer dext-test-token-123"' +
      '}' +
      '});' +
      'if (response.ok) {' +
      'const data = await response.json();' +
      'log("✅ <strong>AUTH HEADER SUCESSO</strong> - Request com Authorization enviado", "success");' +
      '} else {' +
      'log("❌ <strong>AUTH HEADER ERRO</strong> - Status: " + response.status, "error");' +
      '}' +
      '} catch (error) {' +
      'log("💥 <strong>AUTH HEADER EXCEÇÃO</strong> - " + error.message, "error");' +
      '}' +
      '}' +
      'async function testPost() {' +
      'log("🔄 Testando POST...", "warning");' +
      'try {' +
      'const response = await fetch(BASE_URL + "/cors-test", {' +
      'method: "POST",' +
      'headers: { "Content-Type": "application/json" },' +
      'body: JSON.stringify({ test: "post", data: new Date().toISOString() })' +
      '});' +
      'log("📨 <strong>POST ENVIADO</strong> - Status: " + response.status, "success");' +
      '} catch (error) {' +
      'log("💥 <strong>POST EXCEÇÃO</strong> - " + error.message, "error");' +
      '}' +
      '}' +
      'async function testPut() {' +
      'log("🔄 Testando PUT...", "warning");' +
      'try {' +
      'const response = await fetch(BASE_URL + "/cors-test", {' +
      'method: "PUT",' +
      'headers: { "Content-Type": "application/json" },' +
      'body: JSON.stringify({ test: "put", data: new Date().toISOString() })' +
      '});' +
      'log("📨 <strong>PUT ENVIADO</strong> - Status: " + response.status, "success");' +
      '} catch (error) {' +
      'log("💥 <strong>PUT EXCEÇÃO</strong> - " + error.message, "error");' +
      '}' +
      '}' +
      'async function testDelete() {' +
      'log("🔄 Testando DELETE...", "warning");' +
      'try {' +
      'const response = await fetch(BASE_URL + "/cors-test", {' +
      'method: "DELETE"' +
      '});' +
      'log("📨 <strong>DELETE ENVIADO</strong> - Status: " + response.status, "success");' +
      '} catch (error) {' +
      'log("💥 <strong>DELETE EXCEÇÃO</strong> - " + error.message, "error");' +
      '}' +
      '}' +
      'async function testInvalidOrigin() {' +
      'log("🔄 Testando origem inválida...", "warning");' +
      'try {' +
      'const response = await fetch(BASE_URL + "/cors-test", {' +
      'method: "GET",' +
      'headers: {' +
      '"Content-Type": "application/json",' +
      '"Origin": "http://invalid-origin.com"' +
      '}' +
      '});' +
      'const allowOrigin = response.headers.get("access-control-allow-origin");' +
      'log("🔍 <strong>ORIGEM INVÁLIDA</strong> - Allow-Origin: " + allowOrigin, "warning");' +
      '} catch (error) {' +
      'log("💥 <strong>ORIGEM INVÁLIDA EXCEÇÃO</strong> - " + error.message, "error");' +
      '}' +
      '}' +
      'async function testInvalidMethod() {' +
      'log("🔄 Testando método não permitido...", "warning");' +
      'try {' +
      'const response = await fetch(BASE_URL + "/cors-test", {' +
      'method: "PATCH",' +
      'headers: { "Content-Type": "application/json" }' +
      '});' +
      'log("🔍 <strong>MÉTODO NÃO PERMITIDO</strong> - Status: " + response.status, "warning");' +
      '} catch (error) {' +
      'log("💥 <strong>MÉTODO NÃO PERMITIDO EXCEÇÃO</strong> - " + error.message, "error");' +
      '}' +
      '}' +
      '</script>' +
      '</body>' +
      '</html>';

   TextCorsHtmlTestPage =
      '<!DOCTYPE html>' +
      '<html>' +
      '<head>' +
      '<meta charset="UTF-8">' +  // ✅ FORÇAR UTF-8
      '<title>CORS Test from Different Origin</title>' +
      '<style>' +
      'body { font-family: Arial, sans-serif; margin: 40px; }' +
      'button { padding: 10px; margin: 5px; background: #007acc; color: white; border: none; border-radius: 4px; cursor: pointer; }' +
      '.success { color: green; }' +
      '.error { color: red; }' +
      '#results { margin-top: 20px; padding: 15px; background: #f5f5f5; border-radius: 4px; }' +
      '</style>' +
      '</head>' +
      '<body>' +
      '<h1>CORS Test - Different Origin</h1>' +
      '<p>Origem: http://localhost:3000</p>' +
      '<p>Destino: http://localhost:8080</p>' +
      '<button onclick="testCors()">Test CORS</button>' +
      '<button onclick="testPreflight()">Test Preflight</button>' +
      '<div id="results"></div>' +
      '<script>' +
      'const DEXT_URL = "http://localhost:8080";' +
      'function log(msg, isError) {' +
      'const r = document.getElementById("results");' +
      'const d = document.createElement("div");' +
      'd.className = isError ? "error" : "success";' +
      'd.innerHTML = new Date().toLocaleTimeString() + " - " + msg;' +
      'r.appendChild(d);' +
      '}' +
      'async function testCors() {' +
      'try {' +
      'log("Sending cross-origin request...");' +
      'const response = await fetch(DEXT_URL + "/cors-test");' +
      'const corsHeader = response.headers.get("access-control-allow-origin");' +
      'const data = await response.json();' +
      'log("SUCCESS! CORS Header: " + corsHeader + " | Data: " + JSON.stringify(data));' +
      '} catch (error) {' +
      'log("ERROR: " + error.message, true);' +
      '}' +
      '}' +
      'async function testPreflight() {' +
      'try {' +
      'log("Sending preflight OPTIONS...");' +
      'const response = await fetch(DEXT_URL + "/cors-test", {' +
      'method: "OPTIONS",' +
      'headers: {' +
      '"Origin": "http://localhost:3000",' +
      '"Access-Control-Request-Method": "GET"' +
      '}' +
      '});' +
      'const allowOrigin = response.headers.get("access-control-allow-origin");' +
      'const allowMethods = response.headers.get("access-control-allow-methods");' +
      'log("PREFLIGHT! Status: " + response.status + " | Allow-Origin: " + allowOrigin + " | Methods: " + allowMethods);' +
      '} catch (error) {' +
      'log("PREFLIGHT ERROR: " + error.message, true);' +
      '}' +
      '}' +
      '</script>' +
      '</body>' +
      '</html>';


implementation

end.
