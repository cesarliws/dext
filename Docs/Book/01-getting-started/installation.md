# Dext Framework Installation Guide

This guide covers the installation of the Dext Framework. You can choose between the **Automated Setup** (recommended via TMS Smart Setup) or the **Manual Setup**.

---

## 1. Automated Setup (TMS Smart Setup - Recommended)

If you use **TMS Smart Setup**, the installation, compilation, and IDE configuration of the framework is fully automated.

> [!IMPORTANT]
> **Enabling the Community Server**  
> Since Dext Framework is an open-source community package, you must ensure that the **Community Server** is enabled in your TMS Smart Setup workspace. You can enable it using either of the following methods:
> 
> * **Via Command Line**: Open your terminal and run:
>   ```bash
>   tms server-enable community
>   ```
> * **Via GUI Tool**: Launch the `tmsgui.exe` application. (If this is a new workspace, the initialization wizard will immediately ask you which servers to enable. Otherwise, click on the Settings gear icon in the top right and ensure the **Community Server** option is enabled).
> 
>   ![TMS Smart Setup Community](../../Images/smart-setup-community.png)

Once the Community Server is enabled, you can install Dext using either the Graphical User Interface (GUI) or the Command Line Interface (CLI):

### 1.1. GUI Installation
1. Open the **TMS Smart Setup** application (`tmsgui.exe`).
2. In the search box, type `dotpas.dext`.
3. Select **Dext Framework** from the product list.
4. Click the **Install** button.

### 1.2. CLI Installation
Simply run the following command in your terminal:
```bash
tms install dotpas.dext
```

The Smart Setup tool will read the `tmsbuild.yaml` manifest, build all packages for all supported platforms, and automatically configure all Library Paths, Browsing Paths, environment variables, and BPL directory path overrides in your Delphi IDE.

> [!NOTE]
> **Linux64 and OpenSSL.** Native HTTPS is **off** by default (`DEXT_ENABLE_SSL` in `Dext.inc`) so TMS Setup does not require `libssl-dev` in the RAD Studio SDK. If the linker fails with `cannot find -lcrypto` / `cannot find -lssl`, see the [OpenSSL on Linux article](../../Articles/2026-08-28-dext-openssl-linux-sdk-cannot-find-lcrypto-pt-br.md).

> [!TIP]
> You can download the latest version of TMS Smart Setup from the [TMS Smart Setup Download Page](https://doc.tmssoftware.com/smartsetup/download/).

---

## 2. Manual Setup

If you prefer to compile and configure the framework manually, follow the steps below.

### 2.1. Customizing the Framework (Dext.inc)

Before compiling the Dext Framework, you can customize its behavior and active database drivers/integrations by editing the `Sources\Common\Dext.inc` file. This file centralizes all global compilation directives:

#### A. Database Drivers (Dext.Entity)
By default, Dext is configured with only the **SQLite** driver enabled, ensuring full compatibility with the **Delphi Community Edition**. If you use Delphi Enterprise/Architect and want to enable other database drivers, uncomment the corresponding lines:
```pascal
{$DEFINE DEXT_ENABLE_DB_SQLITE}      // Enabled by default
{.$DEFINE DEXT_ENABLE_DB_POSTGRES}   // Remove the dot (.) to enable
{.$DEFINE DEXT_ENABLE_DB_MYSQL}
{.$DEFINE DEXT_ENABLE_DB_MSSQL}
{.$DEFINE DEXT_ENABLE_DB_ORACLE}
{.$DEFINE DEXT_ENABLE_DB_FIREBIRD}
```
*Important:* When enabling other databases, add the `Dext.Entity.Drivers.FireDAC.Links` unit to your project (e.g., in the `.dpr` or Main Form `uses` clause) to ensure that the active drivers are correctly linked.

#### B. TestInsight Integration (`DEXT_TESTINSIGHT`)
If you use **TestInsight** to manage and execute unit tests directly inside the Delphi IDE, uncomment the following line to enable native integration:
```pascal
{.$DEFINE DEXT_TESTINSIGHT}
```
*Note: Requires `TestInsight.Client.pas` to be in your IDE's Library Path.*

#### C. Web Stencils (`DEXT_ENABLE_WEB_STENCILS`)
For projects developed in **Delphi 12.2 or higher** on Windows, Dext supports native integration with Embarcadero's **Web Stencils** template engine:
```pascal
{$IFDEF DEXT_DELPHI12_UP}
  {$IFDEF MSWINDOWS}
    {$DEFINE DEXT_ENABLE_WEB_STENCILS}
  {$ENDIF}
{$ENDIF}
```

> [!NOTE]
> **Web Stencils** support is conditional. The `Dext.Web.Core.dpk` package includes the `Dext.inc` file and conditionally declares the package dependency on Embarcadero's `inetstn` only if `DEXT_ENABLE_WEB_STENCILS` is active. On versions prior to 12.2 or other platforms, this dependency and the related code are completely disabled/ignored by the compiler transparently, without any warnings.


#### D. Component Naming Conflicts (`DEXT_USE_ENTITY_PREFIX`)
If you have other libraries installed (such as Devart EntityDAC) that use the same component names (`TEntityDataSet`, `TEntityDataProvider`), uncomment the following line to avoid IDE registration conflicts:
```pascal
{.$DEFINE DEXT_USE_ENTITY_PREFIX}
```
This registers them as **`TDextEntityDataSet`** and **`TDextEntityDataProvider`**.

#### E. Native HTTPS / OpenSSL (`DEXT_ENABLE_SSL`)
By default Dext does **not** link `libssl`/`libcrypto` at build time, so Linux64 installs via TMS Smart Setup work without an OpenSSL SDK. HTTP, Windows `http.sys`, and the rest of the framework remain available.

To enable native HTTPS (epoll server, Redis `rediss://`, Memory BIO engine), uncomment this in `Sources\Common\Dext.inc` and **rebuild** the packages:

```pascal
{$DEFINE DEXT_ENABLE_SSL}
```

On **Windows**, place `libssl-3.dll` and `libcrypto-3.dll` next to the executable.

On **Linux**, the Delphi linker uses the SDK cached on Windows. Install `libssl-dev` on the PAServer machine (Ubuntu/WSL2), ensure `libssl.so` and `libcrypto.so` exist (not only `.so.3`), then in **Tools → Options → Deployment → SDK Manager** click **Update Local File Cache**. Otherwise Linux64 fails with `E2597 cannot find -lcrypto` / `-lssl`.

Full walkthrough: [HTTPS in Dext and cannot find -lcrypto](../../Articles/2026-08-28-dext-openssl-linux-sdk-cannot-find-lcrypto-pt-br.md).

---

### 2.2. Build the Project Group

Once you have adjusted `Dext.inc` to suit your needs:

1. Open the main project group in Delphi:
    - `Sources\DextFramework.groupproj`
2. In the Project Manager, right-click the root node (**ProjectGroup**) and select **Build All**.
3. Wait for the compilation of all packages to complete.

All compiled artifacts (DCUs, BPLs, and DCPs) are generated in the exact same folder:
- `..\Output\$(ProductVersion)\$(Platform)\$(Config)` (relative to the package directories)

*Example output folder for Delphi 12 Athens Win32 Debug:*
- `Output\23.0\Win32\Debug`

> [!IMPORTANT]
> **Delphi Version Compatibility Limit**
> Dext uses the Lib Suffix `$(Auto)` to automatically version-mark the BPL filename, and the `$(ProductVersion)` variable to organize the output directories. These features require **Delphi 10.4 Sydney** or newer.
>
> For Delphi versions prior to 10.4:
> - You must perform the manual installation.
> - Since `$(ProductVersion)` and Lib Suffix `$(Auto)` are not supported, installing multiple Delphi versions or platforms side-by-side on the same machine may cause conflicts. This happens because the IDE loads BPLs via the Windows system `PATH` environment variable, and will load the first BPL file it finds.

---

### 2.3. Environment Variable Configuration

Using an environment variable simplifies your Library Paths and allows you to switch between different versions of Dext easily.

1. In Delphi, go to **Tools** > **Options** > **IDE** > **Environment Variables**.
2. Under **User System Overrides**, click **New...**
3. **Variable Name**: `DEXT`
4. **Value**: The full path to the `Sources` directory inside your cloned repository.
    - *Example*: `C:\dev\Dext\DextRepository\Sources`
    - *Note*: Ensure it points to the `Sources` folder, not the root.

    ![DEXT Environment Variable](../../Images/ide-env-var.png)

---

### 2.4. Configure Library Path (DCUs & DCPs)

Add the paths to the compiled files in the Library Path of the IDE.

> [!IMPORTANT]
> The Delphi IDE **does not expand** dynamic project variables like `$(Platform)`, `$(Config)`, or `$(ProductVersion)` in global Library Path settings. Therefore, you must specify the exact paths for each configuration and Delphi version you wish to use.
>
> Common `$(ProductVersion)` values:
> - **21.0** for Delphi 10.4 Sydney
> - **22.0** for Delphi 11 Alexandria
> - **23.0** for Delphi 12 Athens

1. In Delphi, go to **Tools** > **Options** > **Language** > **Delphi** > **Library**.
2. Select your target **Platform** (e.g., Windows 32-bit).
3. In the **Library Path** field, add the following paths. Use the `$(DEXT)` variable to simplify:
    - `$(DEXT)\Common` (contains `Dext.inc` and other useful units like `Dext.MM` or `Dext.Testing.TestInsight`)
    - `$(DEXT)\..\Output\23.0\Win32\Release` (for DCUs, BPLs, and DCPs in the Release configuration)

*Note: Repeat for other platforms (e.g., Win64) or configurations, adjusting the version and platform name accordingly.*

---

### 2.5. Configure Execution Path (BPLs)

Since the runtime packages (BPLs) are generated in the output directory, the Delphi IDE needs to locate them when loading design-time packages. You must add the compiled output directories to the IDE's (or Windows system's) `PATH` environment variable:

1. In Delphi, go to **Tools** > **Options** > **IDE** > **Environment Variables**.
2. Under **User System Overrides**, select the **PATH** variable and click **Edit** (or click **New...** if it does not exist).
3. Append the paths to the compiled artifacts (BPL, DCP, DCU) for the **Release** build configuration, adjusting to match your compiler version:
    - *Example for Delphi 12 Athens (23.0)*:
      `;C:\dev\Dext\DextRepository\Output\23.0\Win32\Release;C:\dev\Dext\DextRepository\Output\23.0\Win64\Release`

---

### 2.6. Configure Debug DCU Path

To debug the framework's source code step-by-step in your application:

1. Compile the Dext Framework packages in **Debug** configuration.
2. In Delphi, go to **Tools** > **Options** > **Language** > **Delphi** > **Library**.
3. Under **Debug DCU Path**, add the output directory for the Debug configuration:
    - `$(DEXT)\..\Output\23.0\Win32\Debug`

---

### 2.7. Install Design-Time Packages

To install the framework's design-time components and IDE integrations:

1. Open `Sources\DextFramework.groupproj` in Delphi.
2. Right-click the root node (**ProjectGroup**) and select **Build All** (ensures all packages are compiled).
3. Install the following packages by right-clicking them in the Project Manager and selecting **Install**:
    - **`Dext.EF.Design.dpk`**: Design-time support for database components (`TEntityDataSet`, `TEntityDataProvider`, scaffolding experts, and custom editors).
    - **`Dext.Testing.Design.dpk`**: Design-time support for the **Dext Test Explorer** expert (to execute unit tests directly inside the IDE).

---

### 2.8. Configure Memory Manager (Dext.MM)

The Dext memory manager (`Dext.MM.pas`) resides in the `Sources\Common` folder. To use it in your executable applications:

1. Ensure the `$(DEXT)\Common` folder is added to your Library Path (as shown in Step 2.4).
2. In your main application file (the `.dpr` of your executable), add `Dext.MM` as the **very first** unit in the `uses` clause.
   - *Example*:
     ```pascal
     program MyProject;

     uses
       Dext.MM, // Must always be the first unit!
       Vcl.Forms,
       ...
     ```

### 2.9. Optional Integrations (WebStencils and TestInsight)

For portability and automated installation compatibility, optional integration units are not statically included in the main packages of the framework:

* **Web Stencils**: The `Dext.Web.View.WebStencils.pas` unit resides in `Sources\Web` and is only compiled when the `DEXT_ENABLE_WEB_STENCILS` conditional is enabled in your `Dext.inc`.
* **TestInsight**: The `Dext.Testing.TestInsight.pas` unit resides in `Sources\Testing`. To use it in your test projects, add it directly to your test `.dpr` project's `uses` list (conditioned on `{$IFDEF TESTINSIGHT}`) and make sure the TestInsight client library is added to your IDE's library path.

---

### 2.10. Configure Browsing Path (Source Code)

Add the following paths to your **Browsing Path** (Tools > Options > Language > Delphi > Library) for your target platforms.
This allows the IDE to find the source code for debugging and "Ctrl+Click" navigation.

> [!WARNING]
> **DO NOT put these source folders in the Library Path field!**  
> If you place source folders in the Library Path, the Delphi compiler will recompile parts of Dext every time you compile your development project. This will result in different versions of `.dcu` files scattered throughout your project directories, causing hard-to-debug compilation errors (such as `F2051`).  
> **Dext should only be compiled during its installation.**

```text
$(DEXT)
$(DEXT)\AI
$(DEXT)\AI\MCP
$(DEXT)\Core
$(DEXT)\Core\Base
$(DEXT)\Core\Interception
$(DEXT)\Core\Json
$(DEXT)\Dashboard
$(DEXT)\Data
$(DEXT)\Debug
$(DEXT)\Design
$(DEXT)\Events
$(DEXT)\Hosting
$(DEXT)\Hosting\CLI
$(DEXT)\Hosting\CLI\Logger
$(DEXT)\Hosting\CLI\Tools
$(DEXT)\Hubs
$(DEXT)\Hubs\Transports
$(DEXT)\Net
$(DEXT)\Testing
$(DEXT)\UI
$(DEXT)\Web
$(DEXT)\Web\Caching
$(DEXT)\Web\Hosting
$(DEXT)\Web\Indy
$(DEXT)\Web\Middleware
$(DEXT)\Web\Mvc
$(DEXT)\..\Apps\CLI\Commands
```

> [!TIP]
> **Tip:** Adding each item manually is tedious, so you can copy the line below and paste it directly at the end of your **Browsing Path** field:
> ```text
> ;$(DEXT);$(DEXT)\AI;$(DEXT)\AI\MCP;$(DEXT)\Core;$(DEXT)\Core\Base;$(DEXT)\Core\Interception;$(DEXT)\Core\Json;$(DEXT)\Dashboard;$(DEXT)\Data;$(DEXT)\Debug;$(DEXT)\Design;$(DEXT)\Events;$(DEXT)\Hosting;$(DEXT)\Hosting\CLI;$(DEXT)\Hosting\CLI\Logger;$(DEXT)\Hosting\CLI\Tools;$(DEXT)\Hubs;$(DEXT)\Hubs\Transports;$(DEXT)\Net;$(DEXT)\Testing;$(DEXT)\UI;$(DEXT)\Web;$(DEXT)\Web\Caching;$(DEXT)\Web\Hosting;$(DEXT)\Web\Indy;$(DEXT)\Web\Middleware;$(DEXT)\Web\Mvc;$(DEXT)\..\Apps\CLI\Commands
> ```

---

### 2.11. Multi-Platform Installation (Linux, Win64, Android, iOS...)

Dext Framework supports multi-platform compilation. If you want to use Dext on platforms like Linux, Windows 64-bit, or mobile, follow these instructions:

1. **Add the Target Platform (if needed):**
   In the Delphi Project Manager, if the desired platform is not listed under **Target Platforms** for the package, right-click **Target Platforms**, select **Add Platform...**, and add your target platform.
2. **Select the Active Platform via the Toolbar:**
   To compile Dext packages for the desired platform, select the target platform in the active platform drop-down menu in Delphi's main toolbar.
3. **Build the Project Group:**
   With your desired active platform selected, right-click the root node (**ProjectGroup**) in the Project Manager and select **Build All**.
4. **Configure Paths for the New Platform:**
   Repeat the **Library Path** (Step 2.4) and **Browsing Path** (Step 2.10) configuration steps for each of the new platforms in the Delphi IDE Library Options.

---

## Troubleshooting

### F2051: Unit was compiled with a different version

**Cause:**  
This occurs when the compiler finds a mismatch between pre-compiled `.dcu` files and raw `.pas` source files, usually because the source paths (`Sources`) were incorrectly added to the global **Library Path** instead of the **Browsing Path**.

**Solution:**
1. Go to **Tools** > **Options** > **Language** > **Delphi** > **Library**.
2. Verify your **Library Path**:
    - ✅ Must contain **only** the compiled output folders and common directives folder (e.g., `Output\23.0\Win32\Release` and `$(DEXT)\Common`).
    - ❌ Remove any `Sources\*` directories from the Library Path.
3. Verify your **Browsing Path**:
    - ✅ Must contain the source paths (e.g., `Sources\*` paths).
4. Clean and rebuild:
    - Delete any `.dcu` files under your application project directories.
    - Rebuild the Dext framework (`Sources\DextFramework.groupproj` > **Build All**).
    - Rebuild your application.

### Compilation fails with "File not found"

**Cause:**  
The Library Path does not contain the compiled DCU/DCP/BPL directory, or the framework has not been built for the active target platform/configuration.

**Solution:**
1. Ensure you have built the Dext framework for the target platform and build configuration.
2. Check that your Library Path includes the compiled output folders:
    - `$(DEXT)\..\Output\23.0\Win32\Release`

---

### Quick Reference: Path Configuration Summary

| Path Type         | What to Add                                    | Purpose                                  |
|-------------------|------------------------------------------------|------------------------------------------|
| **Library Path**  | `Output\23.0\Win32\Release`                    | Locate compiled `.dcu` / `.dcp` / `.bpl` |
| **Library Path**  | `$(DEXT)\Common`                               | Locate `Dext.inc` and common units       |
| **System PATH**   | `Output\23.0\Win32\Release`                    | Locate runtime `.bpl` packages at runtime|
| **Browsing Path** | All `Sources\*` folders                        | Code navigation and debugging            |
| **Debug DCU Path**| `Output\23.0\Win32\Debug`                      | Locate compiled debug `.dcu` files       |

---

[← Back to Getting Started](../../README.md) | [Next: Hello World →](hello-world.md)
