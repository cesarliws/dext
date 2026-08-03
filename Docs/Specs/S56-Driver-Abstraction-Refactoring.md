# Specification S56: Driver Abstraction & Setup Refactoring

## Status
- **Type**: Architectural Specification
- **Status**: Proposed
- **Target**: Dext ORM Core (`Dext.Entity.Setup`)

## Objective
Refactor `Dext.Entity.Setup.pas` and `TDbContextOptions` to decouple third-party/commercial database driver instantiation from core framework setup units. The goal is to allow database drivers (such as FireDAC, UniDAC, Zeos, etc.) to be injected as dependencies or registered via pluggable driver factories rather than hardcoding driver-specific types directly in `TDbContextOptions`.

---

## Architectural Problem
Currently, `TDbContextOptions.BuildConnection` in `Dext.Entity.Setup.pas` contains direct references to FireDAC components (`TDextFireDACManager`, `TFireDACConnection`). Attempting to add support for third-party or commercial drivers (like Devart UniDAC) directly into `TDbContextOptions` introduces compile-time dependencies (`{$IFDEF DEXT_USE_UNIDAC}`) and pollutes core framework units with third-party code.

---

## Proposed Design

### 1. Driver Factory Abstraction (`IDbDriverFactory`)
Introduce a standard driver factory interface in `Dext.Entity.Drivers.Interfaces.pas`:

```pascal
type
  IDbDriverFactory = interface
    ['{B1E2A3C4-5678-90AB-CDEF-1234567890AB}']
    function CreateConnection(AOptions: TDbContextOptions): IDbConnection;
    function GetDriverName: string;
  end;
```

### 2. Driver Registry & Injection in `TDbContextOptions`
Update `TDbContextOptions` to accept an injected driver factory or custom driver builder:

```pascal
type
  TDbContextOptions = class
  private
    FDriverFactory: IDbDriverFactory;
    // ...
  public
    function UseDriverFactory(const ADriverFactory: IDbDriverFactory): TDbContextOptions;
    function BuildConnection: IDbConnection;
  end;
```

### 3. Execution Flow
- **Default (Core)**: If no custom `IDbDriverFactory` is injected, `TDbContextOptions` defaults to the built-in FireDAC driver factory (`TFireDACDriverFactory`).
- **Community Drivers**: Community drivers (e.g., UniDAC under `Community/Drivers/UniDAC/`) implement `IDbDriverFactory` (e.g., `TUniDACDriverFactory`) and register or inject themselves explicitly when required by the application:
  ```pascal
  Options := TDbContextOptions.Create;
  Options.UseDriverFactory(TUniDACDriverFactory.Create);
  ```

---

## Benefits
1. **Zero-Dependency Core**: `Dext.Entity.Setup.pas` will have zero references to specific third-party components (UniDAC, Zeos, etc.).
2. **Pluggable Architecture**: Adding new database drivers becomes completely modular without modifying core framework files.
3. **CI/CD Friendly**: Core builds and automated test runners do not need commercial licenses or third-party packages installed.
