param(
    [Parameter(Mandatory=$true)]
    [string]$Name,

    [switch]$App,          # Create an application
    [switch]$Lib           # Create a library
)

# ------------------------------------------------------------
# Determine project type (Simplified and robust check)
# ------------------------------------------------------------

if ($App -and $Lib) {
    Write-Host "❌ You must specify either -App or -Lib, but not both." -ForegroundColor Red
    exit 1
}

# App is default unless -Lib is specified.
$IsLibrary = $Lib.IsPresent

$projectType = if ($IsLibrary) { "Library" } else { "Application" }

Write-Host "📁 Creating new C++ $projectType project: $Name" -ForegroundColor Cyan


# -----------------------------------------
# Create project structure
# -----------------------------------------
$ProjectPath = Join-Path -Path "." -ChildPath $Name

if (Test-Path $ProjectPath) {
    Write-Host "❌ Folder '$Name' already exists." -ForegroundColor Red
    exit 1
}

Write-Host "📁 Creating project structure..."
$dirsToCreate = @(
    "$ProjectPath",
    "$ProjectPath/src",
    "$ProjectPath/include",
    "$ProjectPath/tests",
    "$ProjectPath/scripts",
    "$ProjectPath/libs",
    "$ProjectPath/cmake",
    "$ProjectPath/external"
)

try {
    foreach ($dir in $dirsToCreate) {
        New-Item -ItemType Directory -Path $dir -ErrorAction Stop | Out-Null
    }
} catch {
    Write-Host "❌ Failed to create project structure directories. Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# ---------------------------
# Create main.cpp for apps or sample src/header for libs
# ---------------------------
if (-not $IsLibrary) {
    $MainCpp = @"
#include <iostream>

int main() {
    std::cout << "Hello from $Name!\n";
    return 0;
}
"@
    Set-Content "$ProjectPath/src/main.cpp" $MainCpp
}
elseif ($IsLibrary) {
    $HeaderGuard = ($Name.ToUpper() -replace '[^A-Z0-9]', '_') + "_HPP"
    $SampleHeader = @"
#ifndef $HeaderGuard
#define $HeaderGuard

#include <string>

namespace $Name {
// Sample definition
std::string get_greeting(const std::string& name);
}// namespace $Name

#endif // !$HeaderGuard
"@
    $SampleSrc = @"
#include "$Name.hpp"

// Sample implementation
namespace $Name {
std::string get_greeting(const std::string& name) {
    return "Hello, " + name + " from the $Name library!";
}
}// namespace $Name
"@
    Set-Content "$ProjectPath/include/$Name.hpp" $SampleHeader
    Set-Content "$ProjectPath/src/$Name.cpp" $SampleSrc
}

# ---------------------------
# Sample test_main.cpp
# ---------------------------
$TestMain = @"
#include <catch2/catch_test_macros.hpp>
TEST_CASE("test 1"){
    REQUIRE(1==1);
}

TEST_CASE("test 2"){
    REQUIRE(1==1);
}
"@
Set-Content "$ProjectPath/tests/test_main.cpp" $TestMain

# ---------------------------
# CMakeLists.txt
# ---------------------------
if (-not $IsLibrary) {
    $CMake = @"
cmake_minimum_required(VERSION 3.15)
project($Name LANGUAGES CXX)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY `${CMAKE_BINARY_DIR}/bin)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY `${CMAKE_BINARY_DIR}/lib)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY `${CMAKE_BINARY_DIR}/lib)


if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Release" CACHE STRING "" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Release" "MinSizeRel" "RelWithDebInfo")
endif()

add_executable($Name
    src/main.cpp
    # Add all other .cpp files here
)

target_include_directories($Name PRIVATE
    $<INSTALL_INTERFACE:include>
    $<BUILD_INTERFACE:`${PROJECT_SOURCE_DIR}/include>
)

target_compile_options($Name PRIVATE
    -Wall -Wextra -Werror
    -Wshadow -Wnon-virtual-dtor -Wold-style-cast -Wcast-align
    -Wunused -Wpedantic -Wconversion -Wsign-conversion
    -Wnull-dereference -Wdouble-promotion -Wformat=2
    -Wimplicit-fallthrough
)
target_compile_options($Name PRIVATE
    \$<$<CONFIG:Debug>:-O0>
    \$<$<CONFIG:Release>:-O3 -DNDEBUG>
    \$<$<CONFIG:MinSizeRel>:-Os -DNDEBUG>
    \$<$<CONFIG:RelWithDebInfo>:-O2 -DNDEBUG>
)
target_link_options($Name PRIVATE
    \$<$<CONFIG:Debug>:-g>
    \$<$<CONFIG:RelWithDebInfo>:-g>
)

option(${Name}_BUILD_TESTS "Build tests" `${PROJECT_IS_TOP_LEVEL})
if (${Name}_BUILD_TESTS)
    include(FetchContent)

    FetchContent_Declare(
    Catch2
    GIT_REPOSITORY https://github.com/catchorg/Catch2.git
    GIT_TAG v3.11.0
    )

    FetchContent_MakeAvailable(Catch2)

    enable_testing()
    add_executable(${Name}_Tests
        tests/test_main.cpp
        # Add all other .cpp files here
    )
    # Apply the same strict warnings
    target_compile_options(${Name}_Tests PRIVATE
        -Wall -Wextra -Werror -Wshadow -Wnon-virtual-dtor -Wold-style-cast -Wcast-align
        -Wunused -Wpedantic -Wconversion -Wsign-conversion -Wnull-dereference -Wdouble-promotion -Wformat=2
        -Wimplicit-fallthrough
    )

    target_compile_options(${Name}_Tests PRIVATE
        \$<$<CONFIG:Debug>:-O0>
        \$<$<CONFIG:Release>:-O3 -DNDEBUG>
        \$<$<CONFIG:MinSizeRel>:-Os -DNDEBUG>
        \$<$<CONFIG:RelWithDebInfo>:-O2 -DNDEBUG>
    )

    target_link_options(${Name}_Tests PRIVATE
        \$<$<CONFIG:Debug>:-g>
        \$<$<CONFIG:RelWithDebInfo>:-g>
    )

    target_link_libraries(${Name}_Tests PRIVATE Catch2::Catch2WithMain)
    target_include_directories(${Name}_Tests PRIVATE `${PROJECT_SOURCE_DIR}/include)
    include(Catch)
    catch_discover_tests(${Name}_Tests)
endif()
"@
}
elseif ($IsLibrary) {
    $CMake = @"
cmake_minimum_required(VERSION 3.15)
project($Name LANGUAGES CXX)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY `${CMAKE_BINARY_DIR}/bin)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY `${CMAKE_BINARY_DIR}/lib)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY `${CMAKE_BINARY_DIR}/lib)


if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Release" CACHE STRING "" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Release" "MinSizeRel" "RelWithDebInfo")
endif()

# Build library (INTERFACE for header-only, STATIC if src present)
file(GLOB LIB_SRC CONFIGURE_DEPENDS src/*.cpp)

if (LIB_SRC)
    add_library($Name STATIC `${LIB_SRC})

    # These settings are only valid for a STATIC target
    target_include_directories($Name PRIVATE `${CMAKE_CURRENT_SOURCE_DIR}/include) # Changed PUBLIC to PRIVATE for the BUILD_INTERFACE part of the original line

    target_compile_options($Name PRIVATE
        -Wall -Wextra -Werror
        -Wshadow -Wnon-virtual-dtor -Wold-style-cast -Wcast-align
        -Wunused -Wpedantic -Wconversion -Wsign-conversion
        -Wnull-dereference -Wdouble-promotion -Wformat=2
        -Wimplicit-fallthrough
    )
    target_compile_options($Name PRIVATE
        \$<$<CONFIG:Debug>:-O0>
        \$<$<CONFIG:Release>:-O3 -DNDEBUG>
        \$<$<CONFIG:MinSizeRel>:-Os -DNDEBUG>
        \$<$<CONFIG:RelWithDebInfo>:-O2 -DNDEBUG>
    )
    target_link_options($Name PRIVATE
        \$<$<CONFIG:Debug>:-g>
        \$<$<CONFIG:RelWithDebInfo>:-g>
    )
else()
    add_library($Name INTERFACE)
endif()

add_library($Name::$Name ALIAS $Name)

target_include_directories($Name INTERFACE
    $<BUILD_INTERFACE:`${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)

option(${Name}_BUILD_TESTS "Build tests" `${PROJECT_IS_TOP_LEVEL})
if (${Name}_BUILD_TESTS)
    include(FetchContent)

    FetchContent_Declare(
    Catch2
    GIT_REPOSITORY https://github.com/catchorg/Catch2.git
    GIT_TAG v3.11.0
    )

    FetchContent_MakeAvailable(Catch2)

    enable_testing()
    add_executable(${Name}_Tests tests/test_main.cpp)
    target_include_directories(${Name}_Tests PRIVATE `${PROJECT_SOURCE_DIR}/include)
    target_link_libraries(${Name}_Tests PRIVATE $Name Catch2::Catch2WithMain)

    # Apply the same strict warnings
    target_compile_options(${Name}_Tests PRIVATE
        -Wall -Wextra -Werror -Wshadow -Wnon-virtual-dtor -Wold-style-cast -Wcast-align
        -Wunused -Wpedantic -Wconversion -Wsign-conversion -Wnull-dereference -Wdouble-promotion -Wformat=2
        -Wimplicit-fallthrough
    )

    target_compile_options(${Name}_Tests PRIVATE
        \$<$<CONFIG:Debug>:-O0>
        \$<$<CONFIG:Release>:-O3 -DNDEBUG>
        \$<$<CONFIG:MinSizeRel>:-Os -DNDEBUG>
        \$<$<CONFIG:RelWithDebInfo>:-O2 -DNDEBUG>
    )

    target_link_options(${Name}_Tests PRIVATE
        \$<$<CONFIG:Debug>:-g>
        \$<$<CONFIG:RelWithDebInfo>:-g>
    )

    include(Catch)
    catch_discover_tests(${Name}_Tests)
endif()
"@
}

Set-Content "$ProjectPath/CMakeLists.txt" $CMake
# ---------------------------
# scripts
# ---------------------------

$build=@'
param(
    [ValidateSet("Debug", "Release", "RelWithDebInfo", "MinSizeRel")]
    [string]$BuildType = "Debug",

    [ValidateSet("g++", "clang", "clang++", "gcc")]
    [string]$Compiler = "g++",

    [switch]$Tests
)

Write-Host "🔨 Starting CMake build ($BuildType)..."

$current_dir = Get-Location
$project_dir = if ($PSScriptRoot) {
    Split-Path -Parent $PSScriptRoot
} else {
    Get-Location
}

# Per-config build directory
$build_dir = Join-Path $project_dir "build/$BuildType"

if (-not (Test-Path $build_dir)) {
    Write-Host "📁 Creating build directory: $build_dir"
    New-Item -ItemType Directory -Path $build_dir -Force | Out-Null
}

Set-Location $build_dir

# Determine compiler
$cxx_compiler = switch ($Compiler) {
    "clang" { "clang++" }
    "clang++" { "clang++" }
    default { "g++" }
}

if (-not (Get-Command $cxx_compiler -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Compiler '$cxx_compiler' not found in PATH." -ForegroundColor Red
    Set-Location $current_dir
    exit 1
}

$testsFlag = if ($Tests.IsPresent) { "ON" } else { "OFF" }

# Configure
Write-Host "⚙️  Configuring ($BuildType)..."
cmake `
    -S $project_dir `
    -B . `
    -DCMAKE_BUILD_TYPE=$BuildType `
    -DCMAKE_CXX_COMPILER=$cxx_compiler `

'@+
"    -D$name`_BUILD_TESTS=`$testsFlag
+@'

# Build
Write-Host "🚧 Building ($BuildType)..."
cmake --build .

Set-Location $current_dir
Write-Host "✅ Build finished: build/$BuildType"
'@
Set-Content "$ProjectPath/scripts/build.ps1" $build

$clean=@'
Write-Host "🧹 Cleaning build artifacts..."

$project_dir=$pwd
if ($PSScriptRoot -eq $pwd){
    $project_dir = Split-Path -parent $PSScriptRoot
}

$paths = @("$project_dir\build", "$project_dir\bin", "$project_dir\external")

foreach ($p in $paths) {
    if (Test-Path $p) {
        Write-Host "🗑️  Removing $p ..."
        Remove-Item -Recurse -Force $p
    }
}
Write-Host "✅ Clean complete!"
'@
Set-Content "$ProjectPath/scripts/clean.ps1" $clean

$rebuild=@'
param(
    [ValidateSet("Debug", "Release", "RelWithDebInfo", "MinSizeRel")]
    [string]$BuildType = "Debug",

    [ValidateSet("g++", "clang", "clang++", "gcc")]
    [string]$Compiler = "g++",

    [switch]$Tests
)

Write-Host "♻️  Performing full rebuild..."

.$PSScriptRoot\clean.ps1
.$PSScriptRoot\build.ps1 -BuildType $BuildType -Compiler $Compiler -Tests:$Tests
'@
Set-Content "$ProjectPath/scripts/rebuild.ps1" $rebuild

$run=@'
param(
    [ValidateSet("Debug", "Release", "RelWithDebInfo", "MinSizeRel")]
    [string]$BuildType = "Debug",

    [ValidateSet("g++", "clang", "clang++", "gcc")]
    [string]$Compiler = "g++"
)

Write-Host "🚀 Building and running ($BuildType)..."

$current_dir = Get-Location
$project_dir = if ($PSScriptRoot) {

    Split-Path -Parent $PSScriptRoot
} else {
    Get-Location
}

# Build
& "$PSScriptRoot\build.ps1" -BuildType $BuildType -Compiler $Compiler
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Build failed." -ForegroundColor Red
    exit 1

# Detect if project is app (Check if add_library is NOT present, implying it's an executable project)
$rootCMake = Get-Content (Join-Path -Path $project_dir -ChildPath "CMakeLists.txt") -Raw
if ($rootCMake -match "add_library") {
    Write-Host "ℹ️ Project is a library, nothing to run."
    exit 0
} else {
    # Assuming the executable name is the project name
    $exe_name = Split-Path -Leaf $project_dir
    $exe = Join-Path $project_dir "build/$BuildType/bin/$exe_name.exe"
}

if (-not (Test-Path $exe)) {
    Write-Host "❌ Executable not found: $exe" -ForegroundColor Red
    exit 1
}

Write-Host "▶️ Running $exe_name ($BuildType)..."
& $exe

Set-Location $current_dir
'@
Set-Content "$ProjectPath/scripts/run.ps1" $run

$test=@'
param(
    [ValidateSet("Debug", "Release", "RelWithDebInfo", "MinSizeRel")]
    [string]$BuildType = "Debug",

    [ValidateSet("Debug", "Release", "RelWithDebInfo", "MinSizeRel")]
    [string]$Compiler = "g++"
)

Write-Host "🧪 Building and running tests..."

$current_dir=$pwd
$project_dir=$pwd
if ($PSScriptRoot -eq $pwd){
    $project_dir = Split-Path -parent $PSScriptRoot
}

.$PSScriptRoot\build.ps1 -BuildType $BuildType -Compiler $Compiler -Tests

if (-not (Test-Path "$project_dir/build")) {
    Write-Host "❌ Build directory missing" -ForegroundColor Red
    exit 1
}

Set-Location "$project_dir/build/bin"

Write-Host "📋 Running ctest..."
ctest --output-on-failure --build-config $BuildType

Set-Location $current_dir
Write-Host "✅ Tests finished!"
'@
Set-Content "$ProjectPath/scripts/test.ps1" $test

# ---------------------------
# cmd wrappers
# ---------------------------

$wrapper=@'
@echo off
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dpn0.ps1" %*
'@

Set-Content "$ProjectPath/scripts/build.cmd" $wrapper
Set-Content "$ProjectPath/scripts/clean.cmd" $wrapper
Set-Content "$ProjectPath/scripts/rebuild.cmd" $wrapper
Set-Content "$ProjectPath/scripts/run.cmd" $wrapper
Set-Content "$ProjectPath/scripts/test.cmd" $wrapper


# ---------------------------
# clang-format / clang-tidy
# ---------------------------
$Format = @"
BasedOnStyle: LLVM
IndentWidth: 4
ColumnLimit: 100
"@
Set-Content "$ProjectPath/.clang-format" $Format

Write-Host "📝 Adding .clang-tidy"
$Tidy = @"
Checks: "-*,cppcoreguidelines-*,-cppcoreguidelines-pro-bounds-pointer-arithmetic,-cppcoreguidelines-pro-type-vararg,hicpp-*,-hicpp-vararg,modernize-*,-modernize-use-trailing-return-type,readability-*,clang-analyzer-*,performance-*"
WarningsAsErrors: ""
HeaderFilterRegex: ".*"
FormatStyle: "file"
CheckOptions:
  # Configuration for local variables (non-parameter, non-loop counter, non-exception)
  readability-identifier-length.IgnoredVariableNames: "^([xyz]|mu|pi)$" # Ignore variables named x, y, or z

  # Configuration for function parameters
  readability-identifier-length.IgnoredParameterNames: "^([xyz]|mu)$" # Ignore parameters named x, y, or z


  # Optional: You can also adjust the minimum length or ignore other types if needed
  # readability-identifier-length.MinimumVariableNameLength: 3 # Default is 3
  # readability-identifier-length.IgnoredLoopCounterNames: '^[ijk]$' # Default ignores i, j, k
"@
Set-Content "$ProjectPath/.clang-tidy" $Tidy

# -----------------------------------------
# Initialize Git repo
# -----------------------------------------
Write-Host "🔧 Initializing git repo..."
$gitignore = @"
# CMake
/build/
CMakeCache.txt
CMakeFiles/
CMakeScripts/
Testing/
_deps/

# Visual Studio
.vs/
*.VC.db
*.VC.opendb
*.sdf
*.suo
*.user
*.ilk
*.obj
*.pdb
*.lib
*.dll
*.exe
*.exp
*.aps
*.bsc
*.ncb
*.opensdf
*.res
*.tlog

# macOS
.DS_Store

# Linux
*.o
*.so
*.a

# Misc
*~
*.bak
*.swp
.vscode/
.zed/

"@
Set-Content "$ProjectPath/.gitignore" $gitignore
$gitatrib=@"
# Auto detect text files and perform LF normalization
* text=auto
"@
Set-Content "$ProjectPath/.gitattributes" $gitatrib
git -C $ProjectPath init | Out-Null
git -C $ProjectPath add . | Out-Null
git -C $ProjectPath commit -m "Initial $($IsLibrary ? 'lib' : 'app') project" | Out-Null

Write-Host "✅ Project '$Name' created successfully as $($IsLibrary  ? 'library' : 'app')!"
Set-Location $ProjectPath
