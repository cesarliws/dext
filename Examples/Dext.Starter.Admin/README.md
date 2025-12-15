# 🚀 Dext Admin Starter Kit

A professional, full-stack "SaaS Admin" template built with **Delphi (Dext)** and **Modern Web Technologies**.

> **Use Case:** Perfect for developers migrating from VCL/IntraWeb who want a modern look without the complexity of Node.js/Webpack build chains.

## ✨ Features

*   **Logic in Delphi**: Backend API, Database, and Routing all handled by Dext.
*   **Modern Frontend**: Uses **Tailwind CSS** for styling and **HTMX** for dynamic interactions.
*   **Zero Build Tools**: No `npm install`, no `webpack`. Just plain HTML files served by Delphi.
*   **Authentication**: Complete Login flow with Cookie-based auth.
*   **Dashboard**: Interactive charts (Chart.js) and real-time stats.
*   **CRUD**: Complete Customer management example.

## 🛠️ Technology Stack

*   **Backend**: Dext Framework (Minimal APIs + Service Layer + Dext.Entity)
*   **Database**: SQLite (Zero config file `dext_admin.db`)
*   **Frontend**: 
    *   **HTMX**: For SPA-like navigation without writing JavaScript.
    *   **Tailwind CSS**: For utility-first styling (via CDN).
    *   **Alpine.js**: For minimal client-side interactivity (Sidebar toggle).
    *   **Chart.js**: For data visualization.

---

## 🏗️ Architecture Overview

The application follows a modular, feature-based architecture (Vertical Slice Architecture), keeping related logic together.

```
Dext.Starter.Admin/
├── AppStartup.pas          # DI & Middleware Configuration
├── AppResponseConsts.pas   # Centralized HTML/JSON Templates
├── Domain/                 # Entities & Core Business Rules
│   ├── Entities/           # Database Entities (ORM)
│   └── DbSeeder.pas        # Database Seeding Logic
├── Features/               # Vertical Slices (Endpoints + Services)
│   ├── Auth/               # Login & JWT Logic
│   ├── Customers/          # Customer CRUD
│   ├── Dashboard/          # Stats & Charts
│   └── Settings/           # User Profile
└── wwwroot/                # Static files (CSS, JS, dashboard.html)
```

## 🚀 Key Concepts

### 1. Minimal API (Endpoints)
Instead of Controllers, we use **Minimal APIs** (`MapGet`, `MapPost`) defined in static `Map` methods within each Feature.

**Example (`Customer.Endpoints.pas`):**
```delphi
class procedure TCustomerEndpoints.Map(App: TDextAppBuilder);
begin
  App.MapGet<ICustomerService, IHttpContext>('/customers/',
    procedure(Service: ICustomerService; Context: IHttpContext)
    begin
       // Use Generic Parameter Injection!
       var Data := Service.GetAll;
       // Return Response...
    end);
end;
```

### 2. Service Layer Pattern
Business logic is decoupled from Endpoints using Services (`ICustomerService`, `IDashboardService`).
- **Endpoint**: Parses Request -> Calls Service -> Formats Response (HTML/JSON).
- **Service**: Business Logic -> Database Access (`TAppDbContext`).

**Example (`Customer.Service.pas`):**
```delphi
function TCustomerService.GetAll: IList<TCustomer>;
begin
  Result := FDb.Entities<TCustomer>.List;
end;
```

### 3. HTMX & Server-Side Rendering
The UI is dynamic but rendered on the server.
- **HTMX Attributes** (`hx-get`, `hx-target`) in HTML trigger partial updates.
- **Endpoints** return HTML snippets (defined in `AppResponseConsts.pas`) instead of full pages or JSON.

## 🏃 Getting Started

1.  **Open Project**: Open `Dext.Starter.Admin.dpr` in Delphi.
2.  **Build**: Compile the project (Console Application).
3.  **Run**: Execute the binary. It will start a web server at `http://localhost:8080`.
    *   *Note*: The first run will automatically create the SQLite database and seed it with demo data.
4.  **Login**:
    *   **Username**: `admin`
    *   **Password**: `admin`

---

## 🚶 Walkthrough & Features

### 1. Exploring the Features

#### Login Screen
*   Navigate to `http://localhost:8080`. You will be redirected to the Login page.
*   **Visuals**: Split screen layout (Image + Form) styled with Tailwind.
*   **Under the Hood**: Uses `hx-post="/auth/login"`. The server validates credentials and sets a cookie.

#### Dashboard
*   After login, you see the Dashboard.
*   **Stats Cards**: Loaded asynchronously via `hx-trigger="load"`.
*   **Chart**: Renders using Chart.js with data fetched from `/dashboard/chart`.
*   **Implementation**: Relies on `IDashboardService` to fetch stats and chart data.

#### Customers Management
*   Click "Customers" in the sidebar.
*   **HTMX Navigation**: The content area updates *without* a full page reload.
*   **Implementation**: `TCustomerEndpoints` works with `ICustomerService` to retrieve data and return HTML rows.

### 2. Code Highlights

#### Dependency Injection
Services are registered in `AppStartup.pas`:
```delphi
procedure TAppStartup.ConfigureServices(const Services: TDextServices; ...);
begin
  Services.AddScoped<ICustomerService, TCustomerService>;
  Services.AddScoped<IDashboardService, TDashboardService>;
end;
```

#### Zero-Build Frontend
Open `wwwroot/views/dashboard.html`. You'll see standard `<script>` tags for Tailwind and HTMX. No `node_modules`.

```html
<script src="https://cdn.tailwindcss.com"></script>
<script src="https://unpkg.com/htmx.org@1.9.10"></script>
```

## 🛠️ Step-by-Step Implementation Guide

To add a new feature (e.g., "Orders"):
1.  **Define Entities**: Create `TOrder` in `Domain\Entities`.
2.  **Create Service**: Define `IOrderService` and implement it using `TAppDbContext`.
3.  **Register DI**: Add the service to `AppStartup.pas`.
4.  **Create Endpoint**: Create `TOrderEndpoints` injecting `IOrderService`.
5.  **Wire Up**: Call `TOrderEndpoints.Map(WebApp)` in `AppStartup.Configure`.

## 📚 Further Reading
- [Dext Framework Guide](../../README.md)
