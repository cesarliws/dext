# Dext ORM - UniDAC Community Driver

Community-maintained driver for **Devart UniDAC** integration with the Dext ORM framework.

> **[IMPORTANT] Maintenance & License Notice:**
> The maintainers of the Dext core repository **do not hold a commercial license** for Devart UniDAC. Consequently:
> - Automated CI tests and core builds do not include UniDAC components.
> - Maintenance, support, and compatibility updates for this driver are entirely provided by the community members who use UniDAC.

---

## Architectural Future & Specification Notice

> **Architecture Roadmap Note:**
> To better accommodate community database drivers (such as UniDAC) without modifying core setup units, `Dext.Entity.Setup.pas` is planned for refactoring to support dependency injection and pluggable driver factories (`IDbDriverFactory`).
>
> For details on the planned refactoring, see [Specification S56: Driver Abstraction & Setup Refactoring](../../../Docs/Specs/S56-Driver-Abstraction-Refactoring.md).

---

## Overview

This driver provides full integration between Dext ORM (`IDbConnection`, `IDbCommand`, `IDbReader`, `IDbTransaction`) and Devart UniDAC components (`TUniConnection`, `TUniQuery`, `TParam`), enabling seamless usage of UniDAC database providers (SQLite, PostgreSQL, MySQL, SQL Server, Oracle, InterBase/Firebird, etc.) without introducing compile-time third-party dependencies into the core framework.

## Structure

```text
Community/Drivers/UniDAC/
├── Sources/
│   ├── Dext.Entity.Drivers.UniDAC.pas
│   ├── Dext.Entity.Drivers.UniDAC.Manager.pas
│   ├── Dext.Entity.Drivers.UniDAC.Links.pas
│   └── Dext.Entity.Setup.UniDAC.pas
├── Packages/
│   └── Dext.EF.UniDAC.dpk
├── Tests/
│   └── Dext.Entity.Driver.UniDAC.Test.pas
├── Examples/
│   └── Orm.UniDACDemo/
│       ├── Orm.UniDACDemo.dpr
│       ├── Orm.UniDACDemo.dproj
│       ├── README.md
│       ├── UniDACDemo.DbConfig.pas
│       ├── UniDACDemo.Entities.pas
│       ├── UniDACDemo.Tests.Base.pas
│       ├── UniDACDemo.Tests.CRUD.pas
│       └── build_debug.bat
└── README.md
```

## How to Use

1. Add `Community/Drivers/UniDAC/Sources` to your project's search path.
2. Include `Dext.Entity.Setup.UniDAC` and `Dext.Entity.Drivers.UniDAC` in your unit's `uses` clause.
3. Build your connection using the standalone helper:
   ```pascal
   var
     Options: TUniDACDbContextOptions;
     Conn: IDbConnection;
   begin
     Options := TUniDACDbContextOptions.Create;
     Options.UseSQLite(':memory:');
     Conn := Options.BuildConnection;
   end;
   ```
