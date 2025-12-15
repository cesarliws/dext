# Dext JSON - Features & Documentation

**Dext.Json** is a high-performance, pluggable, and feature-rich JSON serialization library for Delphi. It is designed to be the backbone of the Dext Framework but can be used as a standalone library in any Delphi project.

## 🚀 Key Features

*   **Pluggable Architecture**: Switch between different JSON engines (Drivers) without changing your code.
*   **High Performance**: Optimized for speed and low memory usage.
*   **Zero Boilerplate**: Serialize and deserialize records, classes, arrays, and lists with a single line of code.
*   **Attribute-Based Control**: Customize serialization with attributes like `[JsonName]`, `[JsonIgnore]`, `[JsonFormat]`.
*   **Fluent Settings**: Configure behavior (Case Style, Date Format, Null Handling) using a fluent API.
*   **Cross-Platform**: Compatible with Windows, Linux, macOS, iOS, and Android.

## 🔌 Drivers

Dext.Json abstracts the underlying JSON implementation. You can choose the driver that best fits your needs.

### Available Drivers

1.  **JsonDataObjects** (Default)
    *   **Unit**: `Dext.Json.Driver.JsonDataObjects`
    *   **Pros**: Extremely fast, lightweight, supports older Delphi versions.
    *   **Cons**: Third-party dependency (included in Dext).

2.  **System.JSON** (Native)
    *   **Unit**: `Dext.Json.Driver.SystemJson`
    *   **Pros**: Native Delphi RTL, no external dependencies.
    *   **Cons**: Performance varies by Delphi version.

### Switching Drivers

To switch the driver, simply set the `TDextJson.Provider` property at application startup:

```pascal
uses
  Dext.Json,
  Dext.Json.Driver.SystemJson; // Add the driver unit

begin
  // Switch to System.JSON
  TDextJson.Provider := TSystemJsonProvider.Create;
  
  // That's it! All JSON operations will now use System.JSON.
end;
```

## 📦 Usage Examples

### Basic Serialization

```pascal
type
  TUser = record
    Id: Integer;
    Name: string;
    Email: string;
  end;

var
  User: TUser;
  Json: string;
begin
  User.Id := 1;
  User.Name := 'John Doe';
  User.Email := 'john@example.com';

  // Serialize
  Json := TDextJson.Serialize(User);
  // Output: {"Id":1,"Name":"John Doe","Email":"john@example.com"}

  // Deserialize
  User := TDextJson.Deserialize<TUser>(Json);
end;
```

### Using Attributes

```pascal
type
  TProduct = record
    [JsonName('product_id')]
    Id: Integer;

    [JsonIgnore]
    InternalCode: string;

    [JsonFormat('yyyy-mm-dd')]
    CreatedAt: TDateTime;
    
    [JsonString] // Force number to be serialized as string
    Price: Double;
  end;
```

### Custom Settings

You can customize the serialization behavior using `TDextSettings`:

```pascal
var
  Settings: TDextSettings;
  Json: string;
begin
  Settings := TDextSettings.Default
    .WithCamelCase           // Id -> id, UserName -> userName
    .WithIgnoreNullValues    // Skip null fields
    .WithEnumAsString        // Enum.Value -> "Value"
    .WithISODateFormat;      // 2025-11-18T22:00:00.000

  Json := TDextJson.Serialize(MyData, Settings);
end;
```

### Handling Lists and Arrays

Dext.Json natively supports `TArray<T>` and `TList<T>`:

```pascal
var
  Users: TList<TUser>;
  Json: string;
begin
  Users := TList<TUser>.Create;
  // ... add users ...
  
  Json := TDextJson.Serialize(Users);
  // Output: [{"Id":1,...}, {"Id":2,...}]
  
  Users.Free;
end;
```

## 🛠️ Advanced Topics

### Implementing a Custom Driver

If you want to use another JSON library (e.g., SuperObject), you can implement the `IDextJsonProvider` interface:

1.  Create a class implementing `IDextJsonProvider`.
2.  Implement `IDextJsonObject` and `IDextJsonArray` wrappers.
3.  Register your provider: `TDextJson.Provider := TMyCustomProvider.Create;`.

### Thread Safety

`TDextJson` is thread-safe. The `Provider` property should be set once at startup and not changed during concurrent operations. The serializer instances are created per-call (or per-request in the web framework), ensuring isolation.

---

*Documentation generated for Dext Framework v1.0*
