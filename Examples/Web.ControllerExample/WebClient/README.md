# Dext Controller Showcase - Web Client

Uma aplicação web moderna que demonstra todas as features do Dext Framework Controllers.

## 🚀 Features Demonstradas

### 1. **JWT Authentication**
- Login com credenciais (admin/admin)
- Token armazenado no localStorage
- Headers de autorização automáticos

### 2. **Route Parameter Binding**
- `GET /api/greet/:name`
- Demonstra `[FromRoute]` attribute
- Binding automático de parâmetros da URL

### 3. **Body Binding com Validação**
- `POST /api/greet/`
- Demonstra `[FromBody]` com DTOs
- Validação automática com `[Required]` e `[StringLength]`
- Mensagens de erro detalhadas

### 4. **Query Parameter Binding**
- `GET /api/greet/search`
- Demonstra `[FromQuery]` com nomes customizados
- Binding de múltiplos parâmetros

### 5. **Authorization Enforcement**
- Controller protegido com `[SwaggerAuthorize]`
- Retorna 401 se não autenticado
- Middleware JWT validando tokens

## 🎨 Design

- **Glassmorphism**: Efeitos de vidro fosco modernos
- **Gradientes Animados**: Cores vibrantes e dinâmicas
- **Micro-animações**: Framer Motion para UX premium
- **Dark Mode**: Design escuro elegante
- **Responsivo**: Funciona em todos os dispositivos

## 📦 Tecnologias

- **React 18** + **TypeScript**
- **Vite** - Build tool ultrarrápido
- **Tailwind CSS** - Estilização utilitária
- **Framer Motion** - Animações fluidas
- **Axios** - Cliente HTTP
- **Lucide React** - Ícones modernos

## 🏃 Como Executar

### 1. Inicie o Backend Dext

```bash
cd c:\dev\Dext\Examples
ControllerExample.exe
```

O backend estará rodando em `http://localhost:8080`

### 2. Inicie o Frontend

```bash
cd c:\dev\Dext\Examples\WebClient
npm run dev
```

O frontend estará em `http://localhost:5173`

### 3. Faça Login

- **Username**: `admin`
- **Password**: `admin`

## 🧪 Testando as Features

### GET - Route Binding
1. Vá para a aba "GET - Route Binding"
2. Digite um nome (ex: "John")
3. Clique em "Send Request"
4. Veja a resposta com o greeting personalizado

### POST - Body Validation
1. Vá para a aba "POST - Body Validation"
2. Teste com nome muito curto (< 3 chars) - verá erro de validação
3. Teste com nome válido e título
4. Veja a resposta 201 Created

### GET - Query Binding
1. Vá para a aba "GET - Query Binding"
2. Digite uma query de busca
3. Ajuste o limite
4. Veja como os parâmetros são mapeados para `?q=...&limit=...`

## 🔒 Segurança

- JWT com secret key configurável
- Tokens com expiração (1 hora)
- CORS habilitado para desenvolvimento
- Validação automática de entrada

## 📝 Estrutura do Projeto

```
WebClient/
├── src/
│   ├── api/
│   │   └── client.ts          # Cliente API com gerenciamento de token
│   ├── pages/
│   │   ├── LoginPage.tsx      # Página de login
│   │   └── DashboardPage.tsx  # Dashboard principal
│   ├── App.tsx                # Componente raiz
│   ├── main.tsx               # Entry point
│   └── index.css              # Estilos globais
├── tailwind.config.js         # Configuração Tailwind
└── package.json
```

## 🎯 Próximos Passos

- [ ] Adicionar mais exemplos de validação
- [ ] Demonstrar upload de arquivos
- [ ] Mostrar paginação
- [ ] Adicionar WebSocket example
- [ ] Criar testes E2E
