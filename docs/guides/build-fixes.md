# Build System Fix for Updated lunco-sim Structure

## Problem

The build script is looking for Modelica models in the old location:
```
space-colony-modelica-core/build/SimpleThermalMVP
```

But based on the lunco-sim architecture, they should be in:
```
lunco-sim/apps/modelica/build/SimpleThermalMVP
```

## Solution

We need to update the Rust FFI `build.rs` to point to the correct location within lunco-sim.

### Step 1: Update FFI build.rs

**File:** `godot-modelica-rust-integration/modelica-rust-gdext/modelica-rust-ffi/build.rs`

**Change the modelica_core path:**

```rust
fn main() {
    // OLD - looking in wrong place
    // let modelica_core = PathBuf::from("space-colony-modelica-core");
    
    // NEW - point to lunco-sim apps structure
    let modelica_core = PathBuf::from("../../../lunco-sim/apps/modelica");
    
    // Rest of build script...
    let build_dir = modelica_core.join("build");
    
    // Check if SimpleThermalMVP exists
    let component_dir = build_dir.join("SimpleThermalMVP");
    if !component_dir.exists() {
        panic!(
            "SimpleThermalMVP.c not found in {}\n\
            Please run: cd lunco-sim/apps/modelica && ./build_models.sh",
            component_dir.display()
        );
    }
    
    // Continue with compilation...
    compile_component(&modelica_core, "SimpleThermalMVP", &omc_include, &omc_gc_include);
    generate_bindings(&modelica_core, "SimpleThermalMVP", &omc_include, &omc_gc_include);
}

fn compile_component(
    modelica_core: &Path,
    component: &str,
    omc_include: &str,
    omc_gc_include: &str,
) {
    println!("cargo:warning=Compiling Modelica component: {}", component);
    
    // Point to lunco-sim structure
    let build_dir = modelica_core.join("build").join(component);
    
    if !build_dir.exists() {
        panic!(
            "Component directory not found: {}\n\
            Build the models first: cd lunco-sim/apps/modelica && ./build_models.sh",
            build_dir.display()
        );
    }
    
    // Find all .c files except the main
    let c_files: Vec<_> = std::fs::read_dir(&build_dir)
        .unwrap()
        .filter_map(|entry| {
            let entry = entry.ok()?;
            let path = entry.path();
            if path.extension()? == "c" 
                && !path.file_name()?.to_str()?.contains("_main.c") 
            {
                Some(path)
            } else {
                None
            }
        })
        .collect();
    
    if c_files.is_empty() {
        panic!(
            "No C files found in {}\n\
            The model may not be compiled. Run: cd lunco-sim/apps/modelica && ./build_models.sh",
            build_dir.display()
        );
    }
    
    println!("cargo:warning=Found {} C files to compile", c_files.len());
    
    // Compile all C files
    let mut build = cc::Build::new();
    build
        .include(omc_include)
        .include(omc_gc_include)
        .include(&build_dir);
    
    for file in c_files {
        println!("cargo:warning=Compiling: {}", file.display());
        build.file(file);
    }
    
    build.compile(&format!("{}_modelica", component.to_lowercase()));
}

fn generate_bindings(
    modelica_core: &Path,
    component: &str,
    omc_include: &str,
    omc_gc_include: &str,
) {
    println!("cargo:warning=Generating bindings for: {}", component);
    
    let build_dir = modelica_core.join("build").join(component);
    let header_file = build_dir.join(format!("{}_model.h", component));
    
    if !header_file.exists() {
        panic!(
            "Header file not found: {}\n\
            Build the models first: cd lunco-sim/apps/modelica && ./build_models.sh",
            header_file.display()
        );
    }
    
    let bindings = bindgen::Builder::default()
        .header(header_file.to_str().unwrap())
        .clang_arg(format!("-I{}", omc_include))
        .clang_arg(format!("-I{}", omc_gc_include))
        .clang_arg(format!("-I{}", build_dir.display()))
        .parse_callbacks(Box::new(bindgen::CargoCallbacks))
        .generate()
        .expect("Unable to generate bindings");
    
    let out_path = PathBuf::from(env::var("OUT_DIR").unwrap());
    bindings
        .write_to_file(out_path.join(format!("{}_bindings.rs", component.to_lowercase())))
        .expect("Couldn't write bindings!");
    
    println!("cargo:warning=Bindings generated successfully");
}
```

### Step 2: Update build_models.sh

**File:** `lunco-sim/apps/modelica/build_models.sh`

Make it more robust:

```bash
#!/bin/bash
set -e

echo "======================================"
echo "Building Modelica Models"
echo "======================================"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODELS_DIR="$SCRIPT_DIR/models"
BUILD_DIR="$SCRIPT_DIR/build"

# Create build directory
mkdir -p "$BUILD_DIR"

# Check if OpenModelica is installed
if ! command -v omc &> /dev/null; then
    echo "Error: OpenModelica compiler (omc) not found"
    echo "Please install OpenModelica from https://openmodelica.org/"
    exit 1
fi

echo "Using OpenModelica:"
omc --version

# Function to build a model
build_model() {
    local model_name=$1
    local model_file="$MODELS_DIR/$model_name.mo"
    
    if [ ! -f "$model_file" ]; then
        echo "Error: Model file not found: $model_file"
        return 1
    fi
    
    echo ""
    echo "Building: $model_name"
    echo "----------------------------------------"
    
    # Create build directory for this model
    local model_build_dir="$BUILD_DIR/$model_name"
    mkdir -p "$model_build_dir"
    cd "$model_build_dir"
    
    # Copy model file
    cp "$model_file" .
    
    # Compile with OpenModelica
    echo "Compiling $model_name.mo..."
    omc --simCodeTarget=C -s "$model_name.mo" 2>&1 | grep -v "^$" || true
    
    # Check if compilation was successful
    if [ -f "${model_name}.c" ]; then
        echo "✓ $model_name compiled successfully"
        echo "  Files generated: $(ls -1 | wc -l)"
        echo "  Location: $model_build_dir"
    else
        echo "✗ Failed to compile $model_name"
        return 1
    fi
    
    cd "$SCRIPT_DIR"
}

# Build all models or specific model
if [ $# -eq 0 ]; then
    # Build all .mo files in models directory
    echo "Building all models in $MODELS_DIR"
    
    for model_file in "$MODELS_DIR"/*.mo; do
        if [ -f "$model_file" ]; then
            model_name=$(basename "$model_file" .mo)
            build_model "$model_name" || echo "Warning: Failed to build $model_name"
        fi
    done
else
    # Build specific model
    build_model "$1"
fi

echo ""
echo "======================================"
echo "✓ Build complete!"
echo "======================================"
echo ""
echo "Built models are in: $BUILD_DIR"
echo ""
echo "Next steps:"
echo "  1. Run: cd ../../../ && ./build.sh"
echo "  2. Open lunco-sim in Godot"
echo ""
```

Make it executable:
```bash
chmod +x lunco-sim/apps/modelica/build_models.sh
```

### Step 3: Update Master build.sh

**File:** `godot-colony-sim/build.sh`

```bash
#!/bin/bash
set -e

echo "======================================"
echo "Building Modelica Integration for LunCo"
echo "======================================"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Step 0: Build Modelica models first
echo "Step 0/4: Building Modelica models..."
cd "$SCRIPT_DIR/lunco-sim/apps/modelica"

if [ -f "build_models.sh" ]; then
    ./build_models.sh
else
    echo "Warning: build_models.sh not found, skipping model compilation"
fi

cd "$SCRIPT_DIR"

# Step 1: Build FFI layer
echo ""
echo "Step 1/4: Building modelica-rust-ffi..."
cd godot-modelica-rust-integration/modelica-rust-gdext/modelica-rust-ffi
cargo build --release

if [ $? -ne 0 ]; then
    echo "Error: FFI build failed"
    exit 1
fi

cd ../../..

# Step 2: Build GDExtension
echo ""
echo "Step 2/4: Building modelica-integration extension..."
cd godot-modelica-rust-integration/modelica-rust-gdext/modelica-integration
cargo build --release

if [ $? -ne 0 ]; then
    echo "Error: Extension build failed"
    exit 1
fi

cd ../../..

# Step 3: Deploy to lunco-sim
echo ""
echo "Step 3/4: Deploying to lunco-sim..."
mkdir -p lunco-sim/addons/modelica_integration/bin

# Copy library (handle different platforms)
if [ -f "godot-modelica-rust-integration/modelica-rust-gdext/target/release/libgodot_modelica_integration.dylib" ]; then
    cp godot-modelica-rust-integration/modelica-rust-gdext/target/release/libgodot_modelica_integration.dylib \
       lunco-sim/addons/modelica_integration/bin/
    echo "✓ Copied macOS library (.dylib)"
elif [ -f "godot-modelica-rust-integration/modelica-rust-gdext/target/release/libgodot_modelica_integration.so" ]; then
    cp godot-modelica-rust-integration/modelica-rust-gdext/target/release/libgodot_modelica_integration.so \
       lunco-sim/addons/modelica_integration/bin/
    echo "✓ Copied Linux library (.so)"
elif [ -f "godot-modelica-rust-integration/modelica-rust-gdext/target/release/godot_modelica_integration.dll" ]; then
    cp godot-modelica-rust-integration/modelica-rust-gdext/target/release/godot_modelica_integration.dll \
       lunco-sim/addons/modelica_integration/bin/
    echo "✓ Copied Windows library (.dll)"
else
    echo "Error: No library file found!"
    exit 1
fi

# Step 4: Create/verify GDExtension config
echo ""
echo "Step 4/4: Setting up GDExtension configuration..."
cat > lunco-sim/addons/modelica_integration/modelica.gdextension << 'EOF'
[configuration]
entry_symbol = "gdextension_rust_init"
compatibility_minimum = "4.2"

[libraries]
linux.x86_64 = "res://addons/modelica_integration/bin/libgodot_modelica_integration.so"
macos = "res://addons/modelica_integration/bin/libgodot_modelica_integration.dylib"
windows.x86_64 = "res://addons/modelica_integration/bin/godot_modelica_integration.dll"
EOF

echo "✓ GDExtension configuration created"

echo ""
echo "======================================"
echo "✓ Build Complete!"
echo "======================================"
echo ""
echo "Integration deployed to:"
echo "  lunco-sim/addons/modelica_integration/"
echo ""
echo "Models built in:"
echo "  lunco-sim/apps/modelica/build/"
echo ""
echo "Next steps:"
echo "  1. Open lunco-sim in Godot"
echo "  2. Enable the Modelica Integration plugin"
echo "  3. Run a test scene: scenes/systems/thermal_habitat.tscn"
echo ""
```

### Step 4: Fix Directory Structure

According to LunCo architecture, systems should be in `apps/modelica/systems/`, not `scripts/systems/`:

**Create the proper structure:**
```bash
cd lunco-sim

# Ensure directories exist
mkdir -p apps/modelica/systems
mkdir -p apps/modelica/integration
mkdir -p apps/modelica/scenes

# If you have systems in scripts/, move them
if [ -d "scripts/systems" ]; then
    mv scripts/systems/* apps/modelica/systems/ 2>/dev/null || true
fi
```

### Step 5: Update .gitignore

**File:** `lunco-sim/.gitignore`

```gitignore
# Modelica integration artifacts
addons/modelica_integration/bin/*.so
addons/modelica_integration/bin/*.dll
addons/modelica_integration/bin/*.dylib

# Compiled Modelica models
apps/modelica/build/

# Keep these tracked
!addons/modelica_integration/modelica.gdextension
!apps/modelica/models/**/*.mo
!apps/modelica/build_models.sh
```

## Complete Build Process (Fixed)

### Initial Setup

```bash
cd ~/v-ics.le/godot-colony-sim

# 1. First, build the Modelica models
cd lunco-sim/apps/modelica
./build_models.sh

# 2. Then build the Rust integration
cd ../../..
./build.sh
```

### Expected Output

```
======================================
Building Modelica Integration for LunCo
======================================
Step 0/4: Building Modelica models...

======================================
Building Modelica Models
======================================
Using OpenModelica:
OMCompiler v1.26.0

Building all models in .../lunco-sim/apps/modelica/models

Building: SimpleThermalMVP
----------------------------------------
Compiling SimpleThermalMVP.mo...
✓ SimpleThermalMVP compiled successfully
  Files generated: 21
  Location: .../build/SimpleThermalMVP

======================================
✓ Build complete!
======================================

Step 1/4: Building modelica-rust-ffi...
   Compiling modelica-rust-ffi v0.1.0
    Finished release [optimized] target(s)

Step 2/4: Building modelica-integration extension...
   Compiling godot-modelica-integration v0.1.0
    Finished release [optimized] target(s)

Step 3/4: Deploying to lunco-sim...
✓ Copied macOS library (.dylib)

Step 4/4: Setting up GDExtension configuration...
✓ GDExtension configuration created

======================================
✓ Build Complete!
======================================

Integration deployed to:
  lunco-sim/addons/modelica_integration/

Models built in:
  lunco-sim/apps/modelica/build/

Next steps:
  1. Open lunco-sim in Godot
  2. Enable the Modelica Integration plugin
  3. Run a test scene: scenes/systems/thermal_habitat.tscn
```

## Troubleshooting

### Error: "SimpleThermalMVP.c not found"

**Cause:** Models haven't been compiled yet

**Solution:**
```bash
cd lunco-sim/apps/modelica
./build_models.sh
```

### Error: "omc: command not found"

**Cause:** OpenModelica not installed or not in PATH

**Solution (macOS):**
```bash
# Add to ~/.zshrc or ~/.bashrc
export PATH="/Applications/OpenModelica/build_cmake/install_cmake/bin:$PATH"

# Or use full path in build_models.sh
OMC="/Applications/OpenModelica/build_cmake/install_cmake/bin/omc"
$OMC --simCodeTarget=C -s SimpleThermalMVP.mo
```

### Error: Cargo can't find libraries

**Cause:** OpenModelica paths don't match your installation

**Solution:** Update paths in `modelica-rust-ffi/build.rs`:
```rust
// Check your actual installation path
let omc_base = "/Applications/OpenModelica/build_cmake/install_cmake";

// For Linux, might be:
// let omc_base = "/usr";

// For custom install:
// let omc_base = "/opt/openmodelica";
```

##Summary of Changes

1. ✅ **FFI build.rs** - Points to `lunco-sim/apps/modelica/build/`
2. ✅ **build_models.sh** - Robust script in `apps/modelica/`
3. ✅ **Master build.sh** - Builds models first, then Rust code
4. ✅ **Directory structure** - Matches LunCo architecture
5. ✅ **Error messages** - Point to correct locations
6. ✅ **Platform detection** - Handles .so/.dylib/.dll automatically

Try running the fixed build process now!