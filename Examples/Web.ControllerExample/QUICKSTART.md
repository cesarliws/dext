# 🚀 Quick Start Guide - Dext Controller Showcase

## ⚡ Início Rápido (5 minutos)

### 1️⃣ Backend (Delphi)

```bash
# 1. Abra o Delphi
# 2. Abra o projeto: c:\dev\Dext\Examples\Web.ControllerExample\WebControllerExample.dproj
# 3. Compile (Ctrl+F9)
# 4. Execute (F9)
```

O backend estará rodando em `http://localhost:8080` 🎯

### 2️⃣ Frontend (React)

```bash
# Navegue até a pasta do WebClient
cd c:\dev\Dext\Examples\Web.ControllerExample\WebClient

# Instale as dependências (apenas primeira vez)
npm install

# Inicie o servidor de desenvolvimento
npm run dev
```

O frontend estará em `http://localhost:5173` 🌐

### 3️⃣ Teste!

1. Abra o navegador em `http://localhost:5173`
2. Faça login com:
   - **Username**: `admin`
   - **Password**: `admin`
3. Explore as 3 abas do dashboard! 🎉

---

## 🧪 Testando via cURL

### Login
```bash
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"admin\",\"password\":\"admin\"}"
```

**Resposta:**
```json
{
  "token": "eyJhbGc...",
  "username": "admin"
}
```

### GET - Route Binding
```bash
curl http://localhost:8080/api/greet/John \
  -H "Authorization: Bearer SEU_TOKEN_AQUI"
```

**Resposta:**
```json
{
  "message": "Hello, John! Welcome to Dext Controllers. - 09:45:23.123"
}
```

### POST - Body Validation
```bash
# ✅ Válido
curl -X POST http://localhost:8080/api/greet/ \
  -H "Authorization: Bearer SEU_TOKEN_AQUI" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"John\",\"title\":\"Mr\"}"
```

**Resposta:**
```json
{
  "status": "created",
  "name": "John",
  "title": "Mr"
}
```

```bash
# ❌ Inválido (nome muito curto)
curl -X POST http://localhost:8080/api/greet/ \
  -H "Authorization: Bearer SEU_TOKEN_AQUI" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"Jo\",\"title\":\"Mr\"}"
```

**Resposta (400 Bad Request):**
```json
[
  {
    "FieldName": "Name",
    "ErrorMessage": "The field \"Name\" must be between 3 and 50 characters."
  }
]
```

### GET - Query Binding
```bash
curl "http://localhost:8080/api/greet/search?q=test&limit=5" \
  -H "Authorization: Bearer SEU_TOKEN_AQUI"
```

**Resposta:**
```json
{
  "results": [],
  "query": "test",
  "limit": 5
}
```

---

## 🎯 Features Demonstradas

### ✅ 1. JWT Authentication
- Login retorna token JWT válido
- Token expira em 60 minutos
- Secret key: `dext-secret-key-must-be-very-long-and-secure-at-least-32-chars`

### ✅ 2. Authorization
- Controller protegido com `[SwaggerAuthorize('Bearer')]`
- Retorna **401 Unauthorized** sem token
- Middleware valida token automaticamente

### ✅ 3. Route Binding
- `GET /api/greet/:name`
- Atributo `[FromRoute]` no parâmetro
- Binding automático da URL

### ✅ 4. Body Validation
- `POST /api/greet/`
- DTO com `[Required]` e `[StringLength(3, 50)]`
- Retorna **400 Bad Request** com erros detalhados

### ✅ 5. Query Binding
- `GET /api/greet/search?q=...&limit=...`
- Atributo `[FromQuery('q')]` para custom names
- Binding automático de múltiplos parâmetros

### ✅ 6. Auto JSON Serialization
- Retorno direto de records/DTOs
- Serialização automática para JSON
- Sem necessidade de `IResult`

### ✅ 7. Dependency Injection
- Constructor injection no controller
- `IGreetingService` injetado automaticamente
- Registrado como Singleton

### ✅ 8. CORS
- Habilitado para desenvolvimento
- Permite requisições do frontend (porta 5173)

### ✅ 9. Static Files
- Middleware para servir arquivos estáticos
- Suporte a binários (imagens, fontes)
- MIME type detection automático

---

## 🐛 Troubleshooting

### Backend não compila?
- Verifique se todas as units estão no path
- Certifique-se que Indy está instalado
- Recompile o package `Dext.Core.dpk`

### Frontend não inicia?
```bash
# Limpe node_modules e reinstale
rm -rf node_modules package-lock.json
npm install
npm run dev
```

### CORS Error?
- Certifique-se que o backend está rodando
- Verifique se CORS está habilitado no `ControllerExample.dpr`
- URL do backend deve ser `http://localhost:8080`

### Token inválido?
- Verifique se o secret key é o mesmo no backend e no login
- Token expira em 60 minutos
- Faça login novamente

---

## 📚 Próximos Passos

1. ✅ Explore o código do `ControllerExample.Controller.pas`
2. ✅ Veja como o binding funciona em `Dext.Core.ModelBinding.pas`
3. ✅ Entenda a validação em `Dext.Validation.pas`
4. ✅ Crie seus próprios controllers!

---

**Divirta-se explorando o Dext Framework! 🎉**
