# Quick Start Guide - Modelica Integration for LunCo

## Prerequisites

Before you begin, ensure you have:

- [x] **Godot 4.2+** - Game engine
- [x] **OpenModelica 1.26+** - Physics simulation compiler
- [x] **Rust 1.70+** - For building the extension
- [x] **Git** - For version control and submodules

### Installation Check

```bash
# Check installations
godot --version          # Should show 4.2.x or higher
omc --version           # Should show OpenModelica version
rustc --version         # Should show 1.70.x or higher
git --version           # Any recent version
```

## 5-Minute Setup

### Step 1: Clone the Repository

```bash
cd ~/projects  # or your preferred location
git clone <repository-url> godot-colony-sim
cd godot-colony-sim
```

### Step 2: Build Modelica Models

```bash
cd lunco-sim/apps/modelica
./build_models.sh
```

**Expected output:**
```
======================================
Building Modelica Models
======================================
Using OpenModelica: OMCompiler v1.26.0

Building: SimpleThermalMVP
✓ SimpleThermalMVP compiled successfully
```

### Step 3: Build Rust Integration

```bash
cd ../../..  # Back to root
./build.sh
```

**Expected output:**
```
======================================
Building Modelica Integration for LunCo
======================================
...
✓ Build Complete!
```

### Step 4: Open in Godot

```bash
cd lunco-sim
godot --editor .
```

### Step 5: Enable the Plugin

1. In Godot, go to **Project → Project Settings → Plugins**
2. Find **"Modelica Integration"**
3. Check the **Enable** checkbox
4. Click **Close**

### Step 6: Test It!

1. Open scene: `res://apps/modelica/scenes/thermal_habitat.tscn`
2. Press **F5** to run
3. Watch the console - you should see temperature updates!

```
=== Thermal Habitat Test ===
Temp: -23.1°C | Heater: ON  | Comfort: 0%
Temp: -18.4°C | Heater: ON  | Comfort: 5%
...
Temp: 21.0°C | Heater: OFF | Comfort: 100%
```

**🎉 Success!** Your physics simulation is running!

## Your First Custom Model

### Create a Simple Battery Model

**File:** `lunco-sim/apps/modelica/models/SimpleBattery.mo`

```modelica
model SimpleBattery
  "Simple battery with charge/discharge"
  
  // Inputs
  input Real chargeCurrent "Charging current (A)";
  input Real dischargeCurrent "Discharge current (A)";
  
  // Outputs
  output Real chargeLevel(start=50.0) "Charge level (%)";
  output Real voltage "Output voltage (V)";
  
  // Parameters
  parameter Real capacity = 100.0 "Battery capacity (Ah)";
  parameter Real nominalVoltage = 12.0 "Nominal voltage (V)";
  
  // Internal
  Real netCurrent "Net current (A)";
  
equation
  // Net current = charge - discharge
  netCurrent = chargeCurrent - dischargeCurrent;
  
  // Change in charge level over time
  der(chargeLevel) = (netCurrent / capacity) * 100.0;
  
  // Simple voltage model (drops as battery depletes)
  voltage = nominalVoltage * (0.8 + 0.2 * chargeLevel / 100.0);
  
  // Constraints
  chargeLevel = max(0.0, min(100.0, chargeLevel));
  
end SimpleBattery;
```

### Build Your Model

```bash
cd lunco-sim/apps/modelica
./build_models.sh SimpleBattery
```

### Create Component Wrapper

**File:** `lunco-sim/apps/modelica/integration/battery_component.gd`

```gdscript
extends Node
class_name BatteryComponent
## Simple battery simulation component

signal charge_changed(charge_percent: float)
signal low_battery(charge_percent: float)

const COMPONENT_NAME = "SimpleBattery"
const LOW_BATTERY_THRESHOLD = 20.0

var _modelica_node: ModelicaNode
var _initialized: bool = false
var charge_level: float = 50.0

## Charging current in Amps
var charge_current: float = 0.0:
    set(value):
        charge_current = max(0.0, value)
        if _modelica_node and _initialized:
            _modelica_node.set_real_input("chargeCurrent", charge_current)

## Discharge current in Amps
var discharge_current: float = 0.0:
    set(value):
        discharge_current = max(0.0, value)
        if _modelica_node and _initialized:
            _modelica_node.set_real_input("dischargeCurrent", discharge_current)

func _ready():
    _initialize()

func _process(_delta):
    if _initialized:
        _update_outputs()

func _initialize():
    _modelica_node = ModelicaNode.new()
    add_child(_modelica_node)
    
    if not _modelica_node.load_component(COMPONENT_NAME):
        push_error("Failed to load battery component")
        return
    
    _initialized = true
    print("✓ Battery component initialized")

func _update_outputs():
    var new_charge = _modelica_node.get_real_output("chargeLevel")
    
    if abs(new_charge - charge_level) > 0.1:
        charge_level = new_charge
        charge_changed.emit(charge_level)
        
        if charge_level < LOW_BATTERY_THRESHOLD:
            low_battery.emit(charge_level)

func get_voltage() -> float:
    if not _initialized:
        return 0.0
    return _modelica_node.get_real_output("voltage")

func get_charge_percent() -> float:
    return charge_level

func is_depleted() -> bool:
    return charge_level < 1.0

func is_low() -> bool:
    return charge_level < LOW_BATTERY_THRESHOLD
```

### Test Your Battery

**File:** `lunco-sim/apps/modelica/scenes/battery_test.tscn`

Create a new 3D scene:

```
[Node3D] BatteryTest
├── [Node] BatteryComponent
└── [Label3D] Display
```

Attach this script to root:

```gdscript
extends Node3D

@onready var battery = $BatteryComponent
@onready var display = $Display

var test_mode = "discharge"
var time_elapsed = 0.0

func _ready():
    battery.charge_changed.connect(_on_charge_changed)
    battery.low_battery.connect(_on_low_battery)
    
    print("=== Battery Test ===")
    print("Starting charge: %.1f%%" % battery.charge_level)

func _process(delta):
    time_elapsed += delta
    
    # Alternate between charging and discharging
    if time_elapsed > 10.0:
        time_elapsed = 0.0
        if test_mode == "discharge":
            test_mode = "charge"
            battery.discharge_current = 0.0
            battery.charge_current = 5.0
            print("\nSwitching to CHARGE mode")
        else:
            test_mode = "discharge"
            battery.charge_current = 0.0
            battery.discharge_current = 2.0
            print("\nSwitching to DISCHARGE mode")
    
    # Update display
    display.text = "Battery: %.1f%%\nVoltage: %.2fV\nMode: %s" % [
        battery.get_charge_percent(),
        battery.get_voltage(),
        test_mode.to_upper()
    ]

func _on_charge_changed(charge: float):
    print("Charge: %.1f%%" % charge)

func _on_low_battery(charge: float):
    print("⚠ LOW BATTERY: %.1f%%" % charge)
    display.modulate = Color.ORANGE
```

**Run it!** Press F5 and watch your battery charge and discharge.

## Common Tasks

### Add a New Model

```bash
# 1. Create .mo file
vim lunco-sim/apps/modelica/models/MyModel.mo

# 2. Build it
cd lunco-sim/apps/modelica
./build_models.sh MyModel

# 3. Update FFI (if first model)
# Edit: godot-modelica-rust-integration/modelica-rust-gdext/modelica-rust-ffi/build.rs
# Add: compile_component(&modelica_core, "MyModel", ...);

# 4. Rebuild extension
cd ../../../
./build.sh

# 5. Create wrapper
vim lunco-sim/apps/modelica/integration/my_model_component.gd

# 6. Test it!
```

### Update an Existing Model

```bash
# 1. Edit model
vim lunco-sim/apps/modelica/models/SimpleThermalMVP.mo

# 2. Rebuild just that model
cd lunco-sim/apps/modelica
./build_models.sh SimpleThermalMVP

# 3. Rebuild extension (detects changes)
cd ../../..
./build.sh

# 4. Restart Godot to reload extension
```

### Debug a Simulation

```gdscript
# In your component or system
func _process(_delta):
    # Print all outputs
    var outputs = _modelica_node.get_all_outputs()
    print("Outputs: ", outputs)
    
    # Check specific values
    var temp = _modelica_node.get_real_output("temperature")
    if temp < 0 or temp > 500:
        push_warning("Temperature out of range: %.1f" % temp)
```

### Profile Performance

```gdscript
# Time simulation steps
var start_time = Time.get_ticks_usec()
_modelica_node.step(delta)
var end_time = Time.get_ticks_usec()
var step_time_ms = (end_time - start_time) / 1000.0

if step_time_ms > 1.0:  # Slower than 1ms
    push_warning("Slow simulation step: %.2fms" % step_time_ms)
```

## Troubleshooting

### "Component not found" error

**Problem:** ModelicaNode can't load your component

**Solutions:**
```bash
# Check model was built
ls lunco-sim/apps/modelica/build/YourModel/

# Rebuild model
cd lunco-sim/apps/modelica
./build_models.sh YourModel

# Rebuild extension
cd ../../..
./build.sh
```

### "Simulation step failed" error

**Problem:** Model has runtime errors

**Solutions:**
1. Check Modelica model for errors
2. Verify initial conditions are valid
3. Check input values are in valid range
4. Add bounds checking in model

```modelica
// Add constraints
equation
  temperature = max(0, min(500, temperature));  // Clamp to valid range
```

### Extension won't load in Godot

**Problem:** GDExtension not loading

**Solutions:**
```bash
# 1. Check library exists
ls lunco-sim/addons/modelica_integration/bin/

# 2. Check .gdextension config
cat lunco-sim/addons/modelica_integration/modelica.gdextension

# 3. Rebuild
./build.sh

# 4. Check Godot console for error messages
# Look for "Cannot load GDExtension" messages
```

### OpenModelica not found

**Problem:** `omc: command not found`

**macOS Solution:**
```bash
# Add to ~/.zshrc
export PATH="/Applications/OpenModelica/build_cmake/install_cmake/bin:$PATH"
source ~/.zshrc
```

**Linux Solution:**
```bash
sudo apt-get install openmodelica
# or
sudo dnf install openmodelica
```

## Next Steps

### Learn More

1. **[ModelicaNode Documentation](./modelica_node_docs.md)** - Complete API reference
2. **[Build System](./build_system_docs.md)** - Deep dive into build process
3. **[Integration Guide](./integration_guide.md)** - Advanced integration patterns
4. **[LunCo Architecture](./lunco_modelica_arch.md)** - How it fits into LunCo

### Example Projects

Explore these examples in `lunco-sim/apps/modelica/`:

- **SimpleThermalMVP** - Basic thermal simulation
- **Battery** - Your first custom model (from this guide)
- **SolarPanel** - Power generation (coming soon)
- **LifeSupport** - O2/CO2 system (coming soon)

### Join the Community

- **Report Issues**: GitHub Issues
- **Ask Questions**: Discussions
- **Contribute**: Pull Requests welcome!

### Advanced Topics

Once comfortable with basics:

- Create multi-component systems
- Integrate with LunCo's save/load system
- Optimize performance for many instances
- Build visual editors for model parameters
- Create compound models from smaller ones

## Quick Reference

### File Locations

| What | Where |
|------|-------|
| Modelica models (.mo) | `lunco-sim/apps/modelica/models/` |
| Compiled models | `lunco-sim/apps/modelica/build/` |
| Component wrappers | `lunco-sim/apps/modelica/integration/` |
| Game systems | `lunco-sim/apps/modelica/systems/` |
| Test scenes | `lunco-sim/apps/modelica/scenes/` |
| Extension binary | `lunco-sim/addons/modelica_integration/bin/` |

### Key Commands

```bash
# Build models
cd lunco-sim/apps/modelica && ./build_models.sh [ModelName]

# Build extension
./build.sh

# Open in Godot
cd lunco-sim && godot --editor .

# Run tests
cd lunco-sim && godot --headless --script test_runner.gd
```

### Common Code Patterns

**Load component:**
```gdscript
var node = ModelicaNode.new()
add_child(node)
node.load_component("ModelName")
```

**Set inputs:**
```gdscript
node.set_real_input("inputName", 42.0)
node.set_bool_input("enabled", true)
```

**Read outputs:**
```gdscript
var value = node.get_real_output("outputName")
var all = node.get_all_outputs()
```

**Create wrapper:**
```gdscript
extends Node
class_name MyComponent

var _modelica_node: ModelicaNode

func _ready():
    _modelica_node = ModelicaNode.new()
    add_child(_modelica_node)
    _modelica_node.load_component("MyModel")
```

## Success! 🎉

You now have a working physics simulation integration! Start building amazing realistic simulations for your space colony game.

**Happy simulating!** 🚀