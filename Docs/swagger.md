# Dext Swagger/OpenAPI Integration

## Overview

Dext Framework now includes full support for **OpenAPI 3.0** specification and **Swagger UI**, allowing you to automatically generate interactive API documentation for your endpoints.

## Features

- ✅ **Automatic OpenAPI 3.0 Generation**: Converts your registered endpoints into OpenAPI specification
- ✅ **Swagger UI Integration**: Beautiful, interactive API documentation served at `/swagger`
- ✅ **Fluent Metadata API**: Add summaries, descriptions, and tags to your endpoints
- ✅ **Method-Aware Routing**: Full support for GET, POST, PUT, DELETE, PATCH
- ✅ **Path Parameters**: Automatic detection of route parameters (e.g., `/users/{id}`)
- ✅ **Customizable**: Configure API info, servers, contact, and license information

## Quick Start

### 1. Basic Setup

```pascal
program SwaggerExample;

uses
  Dext.Core.WebApplication,
  Dext.Core.ApplicationBuilder.Extensions,
  Dext.Swagger.Middleware,
  Dext.OpenAPI.Extensions,
  Dext.OpenAPI.Generator;

var
  App: IWebApplication;
  Options: TOpenAPIOptions;
begin
  App := TWebApplication.Create;
  
  // Configure OpenAPI options
  Options := TOpenAPIOptions.Default;
  Options.Title := 'My Awesome API';
  Options.Description := 'A comprehensive API built with Dext Framework';
  Options.Version := '1.0.0';
  Options.ContactName := 'Your Name';
  Options.ContactEmail := 'your.email@example.com';
  
  // Add Swagger middleware
  TSwaggerExtensions.UseSwagger(App.GetApplicationBuilder, Options);
  
  // Register your endpoints
  App.GetApplicationBuilder
    .MapGet('/api/users', 
      procedure(Ctx: IHttpContext)
      begin
        Ctx.Response.Json('{"users": []}');
      end);
  
  App.Run(8080);
end.
```

### 2. Adding Metadata to Endpoints

Use the fluent API to add rich metadata to your endpoints:

```pascal
uses
  Dext.OpenAPI.Extensions;

// Simple summary
TEndpointMetadataExtensions.WithSummary(
  App.GetApplicationBuilder.MapGet('/api/users', GetUsersHandler),
  'Get all users'
);

// Summary + Description
TEndpointMetadataExtensions.WithMetadata(
  App.GetApplicationBuilder.MapPost('/api/users', CreateUserHandler),
  'Create a new user',
  'Creates a new user account with the provided information',
  ['Users', 'Authentication']
);

// Chaining metadata (if you prefer)
var Builder := App.GetApplicationBuilder;
TEndpointMetadataExtensions.WithSummary(
  TEndpointMetadataExtensions.WithDescription(
    TEndpointMetadataExtensions.WithTag(
      Builder.MapGet('/api/products', GetProductsHandler),
      'Products'
    ),
    'Retrieves a paginated list of all products'
  ),
  'Get all products'
);
```

### 3. Using Generic Handlers with Metadata

```pascal
type
  TCreateUserRequest = record
    Name: string;
    Email: string;
    Password: string;
  end;

  TUserResponse = record
    Id: Integer;
    Name: string;
    Email: string;
  end;

// Register endpoint with generic handler
TEndpointMetadataExtensions.WithMetadata(
  TApplicationBuilderExtensions.MapPost<TCreateUserRequest>(
    App.GetApplicationBuilder,
    '/api/users',
    procedure(Req: TCreateUserRequest; Ctx: IHttpContext)
    var
      Response: TUserResponse;
    begin
      // Create user logic
      Response.Id := 1;
      Response.Name := Req.Name;
      Response.Email := Req.Email;
      
      Ctx.Response.Json(TJson.Serialize<TUserResponse>(Response));
    end
  ),
  'Create User',
  'Creates a new user account with the provided credentials',
  ['Users', 'Authentication']
);
```

## Accessing Swagger UI

Once your application is running, you can access:

- **Swagger UI**: `http://localhost:8080/swagger`
- **OpenAPI JSON**: `http://localhost:8080/swagger.json`

## Advanced Configuration

### Custom Swagger Paths

```pascal
var
  Middleware: TSwaggerMiddleware;
begin
  Middleware := TSwaggerMiddleware.Create(
    Options,
    '/api-docs',      // Swagger UI path
    '/api-docs.json'  // OpenAPI JSON path
  );
  
  App.GetApplicationBuilder.UseMiddleware(TSwaggerMiddleware, TValue.From(Options));
end;
```

### Multiple Servers

```pascal
Options := TOpenAPIOptions.Default;
Options.Title := 'Multi-Environment API';
Options.ServerUrl := 'http://localhost:8080';
Options.ServerDescription := 'Development server';

// Note: Currently only one server is supported
// Multiple servers will be added in a future version
```

### License Information

```pascal
Options.LicenseName := 'Apache 2.0';
Options.LicenseUrl := 'https://www.apache.org/licenses/LICENSE-2.0';
```

## Architecture

### Components

1. **`Dext.OpenAPI.Types.pas`**: Type definitions for OpenAPI document structure
   - `TOpenAPIDocument`, `TOpenAPIOperation`, `TOpenAPISchema`, etc.

2. **`Dext.OpenAPI.Generator.pas`**: Converts endpoint metadata to OpenAPI JSON
   - `TOpenAPIGenerator`: Main generator class
   - `TOpenAPIOptions`: Configuration options

3. **`Dext.Swagger.Middleware.pas`**: Serves Swagger UI and OpenAPI spec
   - `TSwaggerMiddleware`: Handles `/swagger` and `/swagger.json` requests
   - `TSwaggerExtensions`: Fluent API for adding Swagger to your app

4. **`Dext.OpenAPI.Extensions.pas`**: Fluent API for endpoint metadata
   - `TEndpointMetadataExtensions`: Methods for adding metadata to routes

### How It Works

1. **Route Registration**: When you call `MapGet`, `MapPost`, etc., a `TRouteDefinition` is created with basic metadata (method, path)

2. **Metadata Enhancement**: Use `TEndpointMetadataExtensions` to add summary, description, and tags

3. **OpenAPI Generation**: `TOpenAPIGenerator` reads all registered routes via `IApplicationBuilder.GetRoutes()` and generates an OpenAPI 3.0 document

4. **Serving Documentation**: `TSwaggerMiddleware` intercepts requests to `/swagger` and `/swagger.json`, serving the UI and spec respectively

## Best Practices

### 1. Organize with Tags

```pascal
// Group related endpoints with tags
TEndpointMetadataExtensions.WithTag(
  App.GetApplicationBuilder.MapGet('/api/users', GetUsersHandler),
  'Users'
);

TEndpointMetadataExtensions.WithTag(
  App.GetApplicationBuilder.MapPost('/api/users', CreateUserHandler),
  'Users'
);

TEndpointMetadataExtensions.WithTag(
  App.GetApplicationBuilder.MapGet('/api/products', GetProductsHandler),
  'Products'
);
```

### 2. Provide Meaningful Descriptions

```pascal
TEndpointMetadataExtensions.WithMetadata(
  App.GetApplicationBuilder.MapGet('/api/users/{id}', GetUserByIdHandler),
  'Get User by ID',
  'Retrieves detailed information about a specific user by their unique identifier. ' +
  'Returns 404 if the user is not found.',
  ['Users']
);
```

### 3. Use Consistent Naming

```pascal
// Good: RESTful naming
.MapGet('/api/users')        // Get all users
.MapGet('/api/users/{id}')   // Get user by ID
.MapPost('/api/users')       // Create user
.MapPut('/api/users/{id}')   // Update user
.MapDelete('/api/users/{id}') // Delete user

// Avoid: Inconsistent naming
.MapGet('/getUsers')
.MapPost('/createNewUser')
```

## Limitations & Future Enhancements

### Current Limitations

- Schema introspection for request/response bodies is basic
- Only one server configuration supported
- No support for authentication schemes in OpenAPI spec (yet)
- No support for examples in schemas

### Planned Features

- [ ] Full RTTI-based schema generation for records and classes
- [ ] Support for multiple servers
- [ ] Authentication/Authorization scheme documentation
- [ ] Request/Response examples
- [ ] Custom schema annotations via attributes
- [ ] Support for file uploads
- [ ] Webhook documentation

## Troubleshooting

### Swagger UI shows "Failed to load API definition"

**Cause**: The OpenAPI JSON endpoint is not accessible or returning invalid JSON.

**Solution**: 
1. Check that `/swagger.json` returns valid JSON
2. Verify CORS is configured if accessing from a different origin
3. Check browser console for detailed error messages

### Endpoints not appearing in Swagger

**Cause**: Routes registered after `UseSwagger` middleware.

**Solution**: Ensure `UseSwagger` is called **before** registering your endpoints:

```pascal
// ✅ Correct order
App.GetApplicationBuilder.UseSwagger(Options);
App.GetApplicationBuilder.MapGet('/api/users', Handler);

// ❌ Wrong order
App.GetApplicationBuilder.MapGet('/api/users', Handler);
App.GetApplicationBuilder.UseSwagger(Options); // Too late!
```

### Metadata not updating

**Cause**: Metadata extensions called on wrong builder instance.

**Solution**: Use the same builder instance:

```pascal
var Builder := App.GetApplicationBuilder;
TEndpointMetadataExtensions.WithSummary(
  Builder.MapGet('/api/users', Handler),
  'Get all users'
);
```

## Examples

See the `/Examples` directory for complete working examples:

- `SwaggerBasic.dpr`: Basic Swagger setup
- `SwaggerAdvanced.dpr`: Advanced usage with metadata and tags
- `SwaggerGeneric.dpr`: Using generic handlers with Swagger

## Contributing

Contributions are welcome! If you'd like to improve the Swagger/OpenAPI integration:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

This feature is part of the Dext Framework and is licensed under the MIT License.
