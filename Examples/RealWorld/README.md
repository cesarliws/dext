# 🛒 DextStore - Real World Example

**DextStore** is a simplified E-commerce API designed to demonstrate the capabilities of the **Dext Framework** for Delphi. It showcases a modern, clean architecture using Dependency Injection, Controllers, Minimal APIs, and JWT Authentication.

## 🏗️ Architecture

The project is structured into three main layers:

- **Models** (`DextStore.Models.pas`): Defines Entities (`TProduct`, `TOrder`) and DTOs (`TLoginRequest`).
- **Services** (`DextStore.Services.pas`): Contains business logic and in-memory data repositories. These are registered as Singletons in the DI container.
- **Controllers** (`DextStore.Controllers.pas`): Handles HTTP requests, validates input, and orchestrates services.

## ⚙️ Configuration

The application supports **Environment-based Configuration**, allowing you to have different settings for Development, QA, and Production.

### Configuration Files
- `appsettings.json`: Base configuration shared across all environments.
- `appsettings.Development.json`: Overrides for the `Development` environment (e.g., Verbose logging).
- `appsettings.Production.json`: Overrides for the `Production` environment.

### Switching Environments
Set the `DEXT_ENVIRONMENT` environment variable before running the application.

**PowerShell:**
```powershell
$env:DEXT_ENVIRONMENT="Development"
.\DextStore.exe
```

**CMD:**
```cmd
set DEXT_ENVIRONMENT=Development
DextStore.exe
```

If the variable is not set, it defaults to `Production`.

## 🚀 How to Run

1. Open `DextStore.dpr` in Delphi (12 Athens or newer recommended).
2. Ensure the **Dext** library paths are configured.
3. Build and Run the project.
4. The server will start on `http://localhost:9000`.

## 🔌 API Endpoints

### ❤️ Health Check
- **GET** `/health`
  - Returns the API status and server time.
  - *No Authentication required.*

### 🔐 Authentication
- **POST** `/api/auth/login`
  - **Body**: `{"username": "user", "password": "password"}`
  - **Returns**: A JWT Token to be used in subsequent requests.

### 🛒 Products
- **GET** `/api/products`
  - Lists all available products.
- **GET** `/api/products/{id}`
  - Gets details of a specific product.
- **POST** `/api/products`
  - Creates a new product.
  - *Requires Authentication (Bearer Token).*

### 🛍️ Cart
- **GET** `/api/cart`
  - Shows the current user's cart.
  - *Requires Authentication.*
- **POST** `/api/cart/items`
  - Adds an item to the cart.
  - **Body**: `{"productId": 1, "quantity": 1}`
  - *Requires Authentication.*
- **DELETE** `/api/cart`
  - Clears the cart.
  - *Requires Authentication.*

### 📦 Orders
- **POST** `/api/orders/checkout`
  - Converts the cart into an order.
  - *Requires Authentication.*
- **GET** `/api/orders`
  - Lists the authenticated user's order history.
  - *Requires Authentication.*

## ✨ Features Demonstrated

- **Fluent API**: Configuration using `App.Builder` and `TDextAppBuilderHelper`.
- **Dependency Injection**: Registering services and controllers via `App.Services`.
- **Middleware Pipeline**: Configuring CORS, JWT, and Routing.
- **Minimal APIs**: Mixing Controllers with lightweight endpoints (`App.Builder.MapGet`).
- **Model Binding & Validation**: Using attributes like `[FromBody]`, `[Required]`, `[StringLength]`.
- **JSON Serialization**: Handling JSON responses with `System.JSON` and `REST.Json`.
