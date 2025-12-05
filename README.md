# 🔨 Forge: C++ Project Generator

**Forge** is a PowerShell script (`forge.ps1`) designed to instantly scaffold modern, CMake-based C++ projects (applications or libraries). It handles directory structure, initial source files, CMake configuration, and setup for Git and coding standards tools.

---

## ✨ Features

* **Project Types:** Create ready-to-build **Applications** or **Static/Interface Libraries**.
* **Modern CMake:** Generates `CMakeLists.txt` using modern target-based properties, C++23 standard, and robust warning flags (`-Wall -Wextra -Werror`).
* **Utility Scripts:** Includes essential PowerShell scripts (`build.ps1`, `clean.ps1`, `run.ps1`, `test.ps1`) for seamless workflow management.
* **Testing Setup:** Initializes a basic `tests` directory with a working `CTest` integration.
* **Tooling Integration:** Initialization of Git, `.clang-format`, and `.clang-tidy` files.

---

## 🚀 Usage

### 1. Execute the Script

Run the script from your terminal and provide the required arguments.

```powershell
.\forge.ps1 <ProjectName> [-Lib]
````

### 2\. Parameters

| Parameter | Type | Required | Description |
| :--- | :--- | :--- | :--- |
| **`-Name`** | `[string]` | **Yes** | The name of the project and the directory to be created. |
| **`-App`** | `[switch]` | No | Creates an **Application** (default if `-Lib` is not used). |
| **`-Lib`** | `[switch]` | No | Creates a **Library** (generates a header/source pair). |

### 3\. Examples

#### Example A: Create a C++ Application with Tooling

```powershell
# Creates a folder named 'MyApp', sets it up as an application, 
# initializes git, and adds clang-format/tidy files.
.\forge.ps1 MyApp
```

#### Example B: Create a Static Library

```powershell
# Creates a folder named 'UtilityCore' as a static library.
.\forge.ps1 UtilityCore -Lib
```

-----

## 🛠️ Project Workflow Scripts

After running **Forge**, your new project directory will contain a `scripts/` folder with the following utility files:

| Script | Purpose | Example Usage |
| :--- | :--- | :--- |
| `build.ps1` | Configures and compiles the project. Supports compiler and build type selection. | `.\scripts\build.ps1 -BuildType Release -Compiler clang` |
| `clean.ps1` | Removes the `build/`, `bin/`, and `external/` directories. | `.\scripts\clean.ps1` |
| `rebuild.ps1` | Runs `clean.ps1` then `build.ps1` for a fresh compilation. | `.\scripts\rebuild.ps1 -Tests` |
| `run.ps1` | Builds the project, then executes the main application (`<ProjectName>.exe`). (Skips if project is a library). | `.\scripts\run.ps1` |
| `test.ps1` | Builds the project with tests enabled, then executes `ctest` with output on failure. | `.\scripts\test.ps1` |

-----
