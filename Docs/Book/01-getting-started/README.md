# 1. Getting Started

Welcome to Dext! This section will get you up and running in minutes.

## Chapters

1. [Where to Start?](where-to-start.md) - Choosing your learning path
2. [Installation](installation.md) - Getting started with Dext
3. [Hello World](hello-world.md) - Your first application
4. [Project Structure](project-structure.md) - Folder layout and organization
5. [Application Startup](application-startup.md) - The Startup Class pattern

## Quick Start

```pascal
program HelloDext;

{$APPTYPE CONSOLE}

uses
  Dext.Web;

begin
  TWebHostBuilder.CreateDefault(nil)
    .UseUrls('http://localhost:5000')
    .Configure(procedure(App: IApplicationBuilder)
      begin
        App.MapGet('/hello', procedure(Ctx: IHttpContext)
          begin
            Ctx.Response.Write('Hello, Dext!');
          end);
      end)
    .Build
    .Run;
end.
```

Run and visit `http://localhost:5000/hello` 🎉

---

[Next: Installation →](installation.md)
