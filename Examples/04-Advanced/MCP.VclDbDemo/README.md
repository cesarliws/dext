# MCP VCL Database Demo

This example demonstrates how to use the native **Dext MCP Server** implementation integrated into a visual VCL application in Delphi with a **FireDAC** (in-memory SQLite) database.

> [!WARNING]
> **Architecture & Scalability Warning:**
> This demo project was designed with the sole purpose of showing a quick integration of the Dext MCP Server in existing legacy VCL systems. For simplicity, the provider class (`TDatabaseMCPProvider`) is tightly coupled to the main form (`TFormMain`) and directly shares its UI and connection components.
>
> **For production environments:**
> - **Decoupling:** Do not couple business logic, database components, or MCP providers to the forms' code-behind.
> - **Layers & DI:** Create isolated service classes for business logic and leverage Dext's native Dependency Injection (DI) system to inject the `TDbContext` or its connection.
> - **Lifecycle Management:** Database connections must be scoped (Scoped/Transient) per request thread to support concurrent calls without colliding with the UI thread connection.

---

## Features Demonstrated

- **Asynchronous MCP Server**: Starts the server in background threads without freezing the VCL application's main UI thread.
- **FireDAC SQLite**: In-memory data querying and updates.
- **DBGrid**: Real-time visualization of database modifications performed by the AI model.
- **Event Console**: Integrated Memo component printing incoming MCP request logs.
- **Custom Tools**:
  - `listar-participantes`: Returns the current list of registered participants.
  - `sortear-participante`: Draws a random participant who has not won yet and updates the DB.
  - `executar-sql`: Allows the AI to execute SELECT queries or UPDATE commands directly against the database.

---

## How to Run

1. Compile and execute the `MCP.VclDbDemo.dproj` project.
2. Click the **Iniciar Servidor** (Start Server) button. By default, it listens on port `3031`.
3. To test locally using curl:
   ```bash
   curl http://localhost:3031/health
   ```
4. Connect to your preferred AI assistant client (e.g. Claude Code):
   ```bash
   claude mcp add db-demo http://localhost:3031/mcp
   ```

5. Interact with the AI:
   > "Draw a participant right now and tell me who won"
   > "How many participants are in the database?"
   > "Run a query to see who has already been drawn"
