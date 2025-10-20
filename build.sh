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