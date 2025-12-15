# Dext Framework - Architectural Standards

## Memory Management & Dependency Injection

### 🎯 Core Principle
**All singleton services MUST implement interfaces for proper ARC (Automatic Reference Counting) management.**

### ✅ Standard Pattern

#### 1. Define Interface
```delphi
IMyService = interface
  ['{GUID-HERE}']
  procedure DoSomething;
end;
```

#### 2. Implement with TInterfacedObject
```delphi
TMyService = class(TInterfacedObject, IMyService)
public
  procedure DoSomething;
end;
```

#### 3. Register by Interface
```delphi
Services.AddSingleton(
  TServiceType.FromInterface(IMyService),
  TMyService,
  Factory  // or nil for default constructor
);
```

#### 4. Resolve by Interface
```delphi
var Service := Provider.GetServiceAsInterface(
  TServiceType.FromInterface(IMyService)
) as IMyService;
```

### 📋 Rules

1. **Singletons**: MUST implement interface → ARC manages lifecycle
2. **Scoped**: MUST implement interface → ARC manages lifecycle  
3. **Transient**: CAN be class-only → Caller manages lifecycle

### ❌ Anti-Patterns

**DON'T:**
```delphi
// ❌ Registering singleton as class
Services.AddSingleton(TServiceType.FromClass(TMyService), TMyService);

// ❌ Manually freeing ARC-managed objects
MyService.Free; // Will cause double-free!
```

**DO:**
```delphi
// ✅ Register by interface
Services.AddSingleton(TServiceType.FromInterface(IMyService), TMyService);

// ✅ Let ARC handle cleanup
// No manual Free needed!
```

### 🔍 Why This Matters

- **Zero Memory Leaks**: ARC automatically frees objects when refcount reaches 0
- **No Double-Free**: Only ARC manages object lifetime
- **Type Safety**: Interfaces provide clear contracts
- **Testability**: Easy to mock interfaces

### 📊 Current Implementation Status

| Service | Has Interface | Status |
|---------|--------------|--------|
| THostedServiceManager | ✅ IHostedServiceManager | ✅ Compliant |
| THealthCheckService | ✅ IHealthCheckService | ✅ Compliant |
| TWorkerService | ✅ IHostedService | ✅ Compliant |

### 🚀 Migration Guide

If you have an existing singleton without interface:

1. Create interface with all public methods
2. Change class to inherit from `TInterfacedObject`
3. Implement the interface
4. Update registration to use `TServiceType.FromInterface`
5. Update resolution to use `GetServiceAsInterface`

### 💡 Special Cases

**Middleware Pattern:**
```delphi
// Constructor receives interface (for DI)
constructor TMyMiddleware.Create(Service: IMyService);
begin
  // Can cast to concrete class if needed internally
  FService := Service as TMyService;
end;
```

---

**Last Updated**: 2025-12-09  
**Enforced Since**: v1.0.0
