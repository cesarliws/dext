# Where to Start?

Welcome to **Dext**!

If you are coming from classic Delphi (where building systems meant dragging visual components onto a form), or if you are arriving now to build modern microservices, you might ask yourself: *where do I start among so many features?*

Dext is a modular ecosystem by design. Thanks to the Delphi compiler, only the features you actually use will be included in the final binary. This means you can adopt it as a super lightweight micro-framework or as a complete enterprise suite, without weight or CPU overhead.

To facilitate your journey, we have organized the learning path into **Thematic Tracks**. Choose the one that best aligns with your current goal:

---

## 🚀 Track A — Web APIs & Microservices
If you need to build lightweight, fast, and scalable REST APIs, or want to replace existing solutions (such as Horse) with a more modular architecture featuring native dependency injection.

*   **1. Getting Started:** Understand the [Installation](installation.md) and run your first [Hello World](hello-world.md).
*   **2. Minimal APIs:** Learn how to map simple and direct routes in [Minimal APIs](../02-web-framework/minimal-apis.md).
*   **3. Middleware Pipeline:** Add error handling, CORS, and compression in the [Middleware Pipeline](../02-web-framework/middleware.md).
*   **4. Practical Examples:** Explore the source code of the [Web.MinimalAPI](../../Examples/Web.MinimalAPI/) example.

---

## 💾 Track B — Persistence & ORM (Dext.Entity)
If your primary goal is to interact with relational databases in a modern way, eliminating manual SQL strings using strongly-typed LINQ and efficient Change Tracking.

*   **1. ORM Concept:** Understand how to declare your first entity and context in [Getting Started with ORM](../05-orm/getting-started.md).
*   **2. Mapping:** Learn how to map tables, primary keys, and columns in [Entities & Mapping](../05-orm/entities.md).
*   **3. Modern Queries:** Perform type-safe queries in [Querying](../05-orm/querying.md) and [Smart Properties](../05-orm/smart-properties.md).
*   **4. Practical Examples:** Explore the [Orm.EntityDemo](../../Examples/Orm.EntityDemo/) example.

---

## 📡 Track C — Integration and API Consumption (RestClient)
If you need your Delphi application to communicate with other servers, consume third-party APIs (such as fetching ZIP codes, weather data, or payment gateways) resiliently.

*   **1. REST Client:** Learn how to make fluent HTTP requests in [REST Client](../12-networking/rest-client.md).

---

## 🏢 Track D — Legacy ERP Modernization (VCL/FMX)
If you have a giant desktop system and want to start applying Clean Architecture or patterns like MVVM (separating business logic from the visual IDE form) without losing RAD Studio productivity.

*   **1. Dependency Injection:** Understand how to organize the lifecycle of your classes and avoid coupling in [Dependency Injection](../10-advanced/dependency-injection.md).
*   **2. EntityDataSet:** Map POCO object collections from memory directly to visual components like Delphi Grids in [Desktop UI (Dext.UI)](../11-desktop-ui/README.md).

---

## 🛠️ Track E — Best Practices: Testing & Security
To ensure that your software continues to function correctly after any changes, without the need for exhaustive manual testing.

*   **1. Unit Testing:** Learn how to create elegant mocks and assertions in [Testing](../08-testing/README.md).

---

### Golden Tip
We recommend starting by cloning the repository, setting up the environment through the [Installation](installation.md) guide, and playing with the [Hello World](hello-world.md). From there, follow the track that makes the most sense for your project!
