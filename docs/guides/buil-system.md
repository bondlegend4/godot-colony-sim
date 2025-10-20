# Build System Documentation

## Overview

This project uses a multi-stage build system that coordinates:
1. Modelica model compilation (OpenModelica)
2. Rust FFI layer compilation (Cargo)
3. Godot extension building (GDExtension)
4. Integration into lunco-sim game project

## Build Architecture

```
┌─────────────────────────────────────────┐
│ 1. Modelica Models (.mo files)         │
│    └─> OpenModelica Compiler (omc)     │
│        └─> C code + headers             │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│ 2. Rust FFI Layer                       │
│    └─> Links C code                     │
│    └─> Provides Rust API                │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│ 3. Godot Extension (GDExtension)        │
│    └─> Uses Rust FFI                    │
│    └─> Builds shared library            │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│ 4. Deploy to lunco-sim                  │
│    └─> Copy .so/.dll to addons/        │
│    └─> Ready to use in Godot            │
└─────────────────────────────────────────┘
```

## Directory Structure

```
godot-colony-sim/
├── build.sh                                # Master build script
├── godot-modelica-rust-integration/
│   └── modelica-rust-gdext/
│       ├── modelica-rust-ffi/              # FFI layer
│       │   ├── build.rs                    # FFI build script
│       │   ├── Cargo.toml
│       │   └── src/
│       └── modelica-integration/           # GDExtension
│           ├── Cargo.toml
│           └── src/
└── lunco-sim/
    ├── addons/modelica_integration/        # Deployment target
    │   └── bin/
    └── apps/modelica/
        ├── models/                          # Source .mo files
        ├── build/                           # Compiled models
        └── build_models.sh                  # Modelica build script
```

## Build Scripts

### Master Build Script (`build.sh`)

**Location:** `godot-colony-sim/build.sh`

**Purpose:** Orchestrates the entire build process

**Steps:**
1. Build Rust FFI layer
2. Build Godot extension
3. Deploy to lunco-sim
4. Build Modelica models

**Usage:**
```bash
cd ~/v-ics.le/godot-colony-sim
./build.sh
```

**Output:**
```
======================================
Building Generic Modelica Integration
======================================
Step 1/3: Building modelica-rust-ffi...
   Compiling modelica-rust-ffi v0.1.0
    Finished release [optimized] target(s) in 12.34s

Step 2/3: Building generic Modelica integration...
   Compiling godot-modelica-integration v0.1.0
    Finished release [optimized] target(s) in 34.56s

Step 3/3: Deploying to lunco-sim...
✓ Generic integration deployed!

lunco-sim needs to:
  1. Provide Modelica models in models/
  2. Create GDScript wrappers
  3. Load models via ModelicaNode
======================================
```

**Requirements:**
- Rust toolchain installed
- OpenModelica installed (for model building)
- Appropriate permissions for file copying

**Error Handling:**
- `set -e` causes script to exit on first error
- Check error messages for which step failed

### Modelica Build Script (`build_models.sh`)

**Location:** `lunco-sim/apps/modelica/build_models.sh`

**Purpose:** Compiles Modelica source files to C code

**Steps:**
1. Create build directory structure
2. Copy .mo files to build location
3. Run OpenModelica compiler
4. Generate shared libraries

**Usage:**
```bash
cd lunco-sim/apps/modelica
./build_models.sh
```

**Current Implementation:**
```bash
#!/bin/bash
set -e

echo "Building Modelica models..."

MODELS_DIR="$(pwd)/models"
BUILD_DIR="$(pwd)/build"

mkdir -p "$BUILD_DIR"

# Build SimpleThermalMVP
echo "Building SimpleThermalMVP..."
cd "$BUILD_DIR"
mkdir -p SimpleThermalMVP
cd SimpleThermalMVP

# Copy .mo file
cp "$MODELS_DIR/SimpleThermalMVP.mo" .

# Compile with OpenModelica
omc --simCodeTarget=C -s SimpleThermalMVP.mo

echo "✓ Models built successfully"
```

**Adding New Models:**

Edit the script to add new components:
```bash
# Build NewModel
echo "Building NewModel..."
cd "$BUILD_DIR"
mkdir -p NewModel
cd NewModel
cp "$MODELS_DIR/NewModel.mo" .
omc --simCodeTarget=C -s NewModel.mo
```

**Common Issues:**

1. **`omc: command not found`**
   - Solution: Add OpenModelica to PATH or use full path
   ```bash
   OMC="/Applications/OpenModelica/build_cmake/install_cmake/bin/omc"
   $OMC --simCodeTarget=C -s SimpleThermalMVP.mo
   ```

2. **Compilation errors**
   - Check .mo file syntax
   - Verify Modelica library dependencies
   - Check OpenModelica version compatibility

3. **Permission errors**
   - Ensure build directory is writable
   - Check file permissions on .mo files

## Rust FFI Build Process

### FFI Build Script (`modelica-rust-ffi/build.rs`)

**Purpose:** 
- Links OpenModelica runtime libraries
- Compiles Modelica-generated C code
- Generates Rust bindings

**Key Components:**

1. **Library Linking:**
```rust
println!("cargo:rustc-link-search=native={}", omc_lib);
println!("cargo:rustc-link-lib=dylib=SimulationRuntimeC");
println!("cargo:rustc-link-lib=dylib=OpenModelicaRuntimeC");
```

2. **C Code Compilation:**
```rust
fn compile_component(
    modelica_core: &Path,
    component: &str,
    omc_include: &str,
    omc_gc_include: &str,
) {
    // Compile all .c files in component directory
    // Link into static library
}
```

3. **Binding Generation:**
```rust
fn generate_bindings(
    modelica_core: &Path,
    component: &str,
    omc_include: &str,
    omc_gc_include: &str,
) {
    // Use bindgen to create Rust FFI bindings
    // Output to OUT_DIR for inclusion in Rust code
}
```

**Configuration:**

Platform-specific paths are hardcoded:

```rust
// macOS
let omc_base = "/Applications/OpenModelica/build_cmake/install_cmake";

// Linux (future)
// let omc_base = "/usr/lib/openmodelica";

// Windows (future)
// let omc_base = "C:\\OpenModelica\\lib";
```

**Updating for New Components:**

When adding a new Modelica component, update `build.rs`:

```rust
fn main() {
    // ... existing setup ...
    
    // Add your new component
    compile_component(&modelica_core, "NewComponent", &omc_include, &omc_gc_include);
    generate_bindings(&modelica_core, "NewComponent", &omc_include, &omc_gc_include);
}
```

## GDExtension Build Process

### Extension Cargo.toml

**Location:** `modelica-integration/Cargo.toml`

**Key Settings:**
```toml
[lib]
crate-type = ["cdylib"]  # Creates shared library for Godot

[dependencies]
godot = { path = "../godot" }
modelica-rust-ffi = { path = "../modelica-rust-ffi" }
```

**Build Command:**
```bash
cd modelica-integration
cargo build --release
```

**Output:**
- Linux: `target/release/libgodot_modelica_integration.so`
- macOS: `target/release/libgodot_modelica_integration.dylib`
- Windows: `target/release/godot_modelica_integration.dll`

### Deployment

The master `build.sh` script copies the built library to lunco-sim:

```bash
mkdir -p lunco-sim/addons/modelica_integration/bin

cp target/release/libgodot_modelica_integration.* \
   lunco-sim/addons/modelica_integration/bin/
```

**GDExtension Configuration:**

`lunco-sim/addons/modelica_integration/modelica.gdextension`:
```ini
[configuration]
entry_symbol = "gdextension_rust_init"

[libraries]
linux.x86_64 = "res://addons/modelica_integration/bin/libgodot_modelica_integration.so"
macos = "res://addons/modelica_integration/bin/libgodot_modelica_integration.dylib"
windows.x86_64 = "res://addons/modelica_integration/bin/godot_modelica_integration.dll"
```

## Complete Build Workflow

### Initial Setup

```bash
# 1. Clone repository
git clone <repo-url>
cd godot-colony-sim

# 2. Initialize submodules (if using)
git submodule update --init --recursive

# 3. Verify OpenModelica installation
which omc
omc --version

# 4. Verify Rust installation
rustc --version
cargo --version
```

### Development Build

```bash
# Full rebuild everything
./build.sh

# Or build components individually:

# 1. Build only Modelica models
cd lunco-sim/apps/modelica
./build_models.sh

# 2. Build only Rust FFI
cd ../../godot-modelica-rust-integration/modelica-rust-gdext/modelica-rust-ffi
cargo build --release

# 3. Build only GDExtension
cd ../modelica-integration
cargo build --release

# 4. Deploy manually
cp target/release/libgodot_modelica_integration.* \
   ../../../lunco-sim/addons/modelica_integration/bin/
```

### Incremental Builds

**When you change a Modelica model:**
```bash
cd lunco-sim/apps/modelica
./build_models.sh
# Rust will automatically recompile FFI due to changed C files
cd ../../
./build.sh
```

**When you change Rust FFI code:**
```bash
cd godot-modelica-rust-integration/modelica-rust-gdext/modelica-rust-ffi
cargo build --release
# Extension needs rebuild
cd ../modelica-integration
cargo build --release
# Deploy
cp target/release/libgodot_modelica_integration.* \
   ../../../lunco-sim/addons/modelica_integration/bin/
```

**When you change GDExtension code:**
```bash
cd godot-modelica-rust-integration/modelica-rust-gdext/modelica-integration
cargo build --release
cp target/release/libgodot_modelica_integration.* \
   ../../../lunco-sim/addons/modelica_integration/bin/
```

### Release Build

```bash
# Build optimized release version
./build.sh

# Additional optimization flags (add to Cargo.toml):
[profile.release]
lto = true              # Link-time optimization
codegen-units = 1       # Better optimization, slower compile
opt-level = 3           # Maximum optimization
strip = true            # Remove debug symbols
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Build

on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
      with:
        submodules: recursive
    
    - name: Install OpenModelica
      run: |
        sudo apt-get update
        sudo apt-get install openmodelica
    
    - name: Install Rust
      uses: actions-rs/toolchain@v1
      with:
        toolchain: stable
        override: true
    
    - name: Build Project
      run: ./build.sh
    
    - name: Upload Artifacts
      uses: actions/upload-artifact@v3
      with:
        name: modelica-integration
        path: lunco-sim/addons/modelica_integration/bin/
```

## Troubleshooting

### Build Failures

**FFI won't compile:**
```bash
# Check OpenModelica paths
ls /Applications/OpenModelica/build_cmake/install_cmake/lib/omc/

# Check Modelica models are built
ls lunco-sim/apps/modelica/build/SimpleThermalMVP/

# Verify bindgen can find headers
ls /Applications/OpenModelica/build_cmake/install_cmake/include/omc/c/
```

**Extension won't load in Godot:**
```bash
# Check library was copied
ls lunco-sim/addons/modelica_integration/bin/

# Check GDExtension config
cat lunco-sim/addons/modelica_integration/modelica.gdextension

# Check Godot console for error messages
```

**Linking errors:**
```bash
# Verify library dependencies (macOS)
otool -L target/release/libgodot_modelica_integration.dylib

# Verify library dependencies (Linux)
ldd target/release/libgodot_modelica_integration.so
```

### Clean Build

```bash
# Clean all build artifacts
cd godot-colony-sim

# Clean Rust builds
cd godot-modelica-rust-integration/modelica-rust-gdext
cargo clean
cd ../..

# Clean Modelica builds
rm -rf lunco-sim/apps/modelica/build/*

# Clean deployed extension
rm -rf lunco-sim/addons/modelica_integration/bin/*

# Rebuild from scratch
./build.sh
```

## Performance Optimization

### Compile Time

- Use `cargo build` (debug) during development
- Use `cargo build --release` for testing/deployment
- Consider `sccache` for faster Rust compilation

### Runtime Performance

- Ensure release builds for production
- Profile with `cargo flamegraph` if needed
- Monitor Modelica simulation timesteps

## See Also

- [ModelicaNode Documentation](./modelica_node_docs.md)
- [Rust FFI README](../modelica-rust-ffi/README.md)
- [OpenModelica Documentation](https://openmodelica.org/doc/)
- [GDExtension Documentation](https://docs.godotengine.org/en/stable/tutorials/scripting/gdextension/)