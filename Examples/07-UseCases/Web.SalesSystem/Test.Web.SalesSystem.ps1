# Test.Web.SalesSystem.ps1
# Script para testar os endpoints do projeto Sales System Minimal API
# Garanta que o servidor esteja rodando em http://localhost:8080

# Configurar encoding UTF-8 para exibir emojis e caracteres acentuados corretamente
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$baseUrl = "http://localhost:8080"
$token = $null

Write-Host "[START] Iniciando Atividades de Teste no Sales System..." -ForegroundColor Cyan

# 1. Health Check (Acesso P blico)
Write-Host "`n[TEST] Health Check (/health)..."
try {
    $health = Invoke-RestMethod -Uri "$baseUrl/health" -Method Get
    if ($health.status -eq "healthy") {
        Write-Host "PASS: Servidor Online ($($health.timestamp))" -ForegroundColor Green
    }
    else {
        Write-Host "FAIL: Status inesperado: $($health.status)" -ForegroundColor Red
    }
}
catch {
    Write-Host "FAIL: N o foi poss vel acessar /health. O servidor est  rodando? Erro: $_" -ForegroundColor Red
}

# 2. Login (Obter JWT)
Write-Host "`n[TEST] Autentica  o (/auth/login)..."
try {
    $loginBody = @{
        username = "admin"
        password = "admin"
    } | ConvertTo-Json

    $loginResp = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method Post -Body $loginBody -ContentType "application/json"
    
    if ($loginResp.token) {
        $token = $loginResp.token
        Write-Host "PASS: Login bem-sucedido. Token JWT gerado." -ForegroundColor Green
    }
    else {
        Write-Host "FAIL: Token n o recebido na resposta." -ForegroundColor Red
    }
}
catch {
    Write-Host "FAIL: Erro na requisi  o de login: $_" -ForegroundColor Red
}

# Se temos o token, prosseguimos com os testes protegidos
if ($token) {
    $headers = @{ "Authorization" = "Bearer $token" }

    # 3. Listar Clientes (DataApi)
    Write-Host "`n[TEST] Listar Clientes (/api/customers)..."
    try {
        $customers = Invoke-RestMethod -Uri "$baseUrl/api/customers" -Headers $headers -Method Get
        Write-Host "PASS: $($customers.Count) clientes retornados." -ForegroundColor Green
    }
    catch {
        Write-Host "FAIL: Erro ao listar clientes: $_" -ForegroundColor Red
    }

    # 4. Listar Produtos (DataApi)
    Write-Host "`n[TEST] Listar Produtos (/api/products)..."
    try {
        $products = Invoke-RestMethod -Uri "$baseUrl/api/products" -Headers $headers -Method Get
        Write-Host "PASS: $($products.Count) produtos retornados." -ForegroundColor Green
        
        if ($products.Count -gt 0) {
            $firstProduct = $products[0]
            Write-Host " - Produto Exemplo: $($firstProduct.name) ($($firstProduct.price))"
        }
    }
    catch {
        Write-Host "FAIL: Erro ao listar produtos: $_" -ForegroundColor Red
    }

    # 5. Criar Pedido (CQRS Command)
    Write-Host "`n[TEST] Criar Novo Pedido (/api/orders)..."
    try {
        $orderBody = @{
            items = @(
                @{ productId = 1; quantity = 2 },
                @{ productId = 2; quantity = 1 }
            )
        } | ConvertTo-Json

        $orderResp = Invoke-RestMethod -Uri "$baseUrl/api/orders" -Headers $headers -Method Post -Body $orderBody -ContentType "application/json"
        Write-Host "PASS: Pedido criado com ID: $($orderResp.id) | Total: $($orderResp.total)" -ForegroundColor Green
    }
    catch {
        $errMsg = $_
        try {
            $response = $_.Exception.Response
            if ($null -ne $response) {
                $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
                $detail = $reader.ReadToEnd()
                Write-Host "FAIL: Erro ao criar pedido. Detalhe: $detail" -ForegroundColor Red
            }
            else {
                Write-Host "FAIL: Erro ao criar pedido: $errMsg" -ForegroundColor Red
            }
        }
        catch {
            Write-Host "FAIL: Erro ao processar falha de cria  o: $_" -ForegroundColor Red
        }
    }

    # 6. Consultar Pedidos (Custom Query com OrderBy)
    Write-Host "`n[TEST] Consultar Pedidos Criados (/api/orders)..."
    try {
        $orders = Invoke-RestMethod -Uri "$baseUrl/api/orders" -Headers $headers -Method Get
        Write-Host "PASS: $($orders.Count) pedidos recuperados (Ordenados por Data Desc)." -ForegroundColor Green
        
        foreach ($o in $orders) {
            Write-Host " - Pedido #$($o.id) | Status: $($o.status) | Total: $($o.total) | Data: $($o.createdAt)"
        }
    }
    catch {
        Write-Host "FAIL: Erro ao consultar pedidos: $_" -ForegroundColor Red
    }

}
else {
    Write-Host "`n[SKIP] Pulando testes protegidos pois n o houve autentica  o." -ForegroundColor Yellow
}

Write-Host "`n  Atividades de Teste Conclu das." -ForegroundColor Cyan
