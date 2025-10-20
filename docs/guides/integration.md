# lunco-sim Integration Guide

## Overview

This guide explains how to integrate Modelica physics simulations into the lunco-sim game project using the generic Modelica integration addon.

## Architecture Layers

```
┌──────────────────────────────────────┐
│ Layer 4: Game Logic                 │
│ (scripts/systems/)                  │
│ - ThermalSystem                      │
│ - UI Controllers                     │
│ - Game State Management              │
└──────────────────────────────────────┘
              ↓
┌──────────────────────────────────────┐
│ Layer 3: Component Wrappers         │
│ (apps/modelica/integration/)        │
│ - ThermalComponent                   │
│ - Signals & Helper Methods           │
└──────────────────────────────────────┘
              ↓
┌──────────────────────────────────────┐
│ Layer 2: Generic Node               │
│ (addons/modelica_integration/)      │
│ - ModelicaNode                       │
│ - Generic load/step/get/set API      │
└──────────────────────────────────────┘
              ↓
┌──────────────────────────────────────┐
│ Layer 1: Physics Engine              │
│ (apps/modelica/models/)             │
│ - Compiled Modelica models (.so)     │
└──────────────────────────────────────┘
```

## Directory Structure

```
lunco-sim/
├── addons/
│   └── modelica_integration/              # Generic addon (built from Rust)
│       ├── modelica.gdextension
│       └── bin/
│           └── libgodot_modelica_integration.so
│
├── apps/
│   └── modelica/
│       ├── models/                        # Source .mo files
│       │   ├── SimpleThermalMVP.mo
│       │   └── package.mo
│       │
│       ├── build/                         # Compiled models (gitignored)
│       │   └── SimpleThermalMVP/
│       │       └── SimpleThermalMVP.so
│       │
│       ├── integration/                   # GDScript wrappers
│       │   ├── thermal_component.gd
│       │   └── README.md
│       │
│       ├── build_models.sh                # Build script
│       └── core/                          # DEPRECATED - old implementation
│
├── scripts/
│   └── systems/                           # Game system scripts
│       ├── thermal_system.gd
│       └── life_support_system.gd
│
└── scenes/
    └── systems/                           # System test scenes
        └── thermal_habitat.tscn
```

## Step-by-Step Integration

### Step 1: Install the Generic Addon

The addon is already built and deployed by the master build script:

```bash
cd ~/v-ics.le/godot-colony-sim
./build.sh
```

**Verify Installation:**
```bash
ls lunco-sim/addons/modelica_integration/bin/
# Should show: libgodot_modelica_integration.so (or .dylib/.dll)
```

**Enable in Godot:**
1. Open lunco-sim in Godot
2. Go to Project → Project Settings → Plugins
3. Enable "Modelica Integration"

### Step 2: Create Your Modelica Models

**Location:** `apps/modelica/models/`

**Example - SimpleThermalMVP.mo:**
```modelica
model SimpleThermalMVP
  "Minimal viable thermal model for habitat"
  
  // Inputs
  input Boolean heaterOn "Heater control signal";
  
  // Outputs
  output Real temperature(start=250.0) "Room temperature (K)";
  output Real heaterStatus "Heater status (0=off, 1=on)";
  
  // Parameters
  parameter Real roomCapacity = 1000.0 "Heat capacity (J/K)";
  parameter Real ambientTemp = 250.0 "Ambient temperature (K)";
  parameter Real heaterPower = 500.0 "Heater power (W)";
  parameter Real lossCoefficient = 2.0 "Heat loss coefficient (W/K)";
  
  // Internal variables
  Real heating "Heating power (W)";
  Real losses "Heat losses (W)";
  
equation
  // Thermal dynamics
  roomCapacity * der(temperature) = heating - losses;
  
  // Heater logic
  heating = if heaterOn then heaterPower else 0.0;
  heaterStatus = if heaterOn then 1.0 else 0.0;
  
  // Heat loss to ambient
  losses = lossCoefficient * (temperature - ambientTemp);
  
end SimpleThermalMVP;
```

**Build the model:**
```bash
cd apps/modelica
./build_models.sh
```

### Step 3: Create Component Wrapper

**Location:** `apps/modelica/integration/thermal_component.gd`

**Purpose:** Provide a clean GDScript API specific to your component

```gdscript
extends Node
class_name ThermalComponent
## Wrapper for SimpleThermalMVP Modelica component

signal temperature_changed(new_temp: float)
signal heater_state_changed(is_on: bool)

var modelica_node: ModelicaNode
var temperature: float = 250.0

var heater_on: bool = false:
    set(value):
        if heater_on != value:
            heater_on = value
            if modelica_node:
                modelica_node.set_bool_input("heaterOn", heater_on)
            heater_state_changed.emit(heater_on)

const COMPONENT_NAME = "SimpleThermalMVP"

func _ready():
    _initialize_modelica()

func _process(_delta):
    if modelica_node:
        _update_outputs()

func _initialize_modelica():
    """Initialize the Modelica simulation"""
    modelica_node = ModelicaNode.new()
    add_child(modelica_node)
    
    if not modelica_node.load_component(COMPONENT_NAME):
        push_error("Failed to load thermal component '%s'" % COMPONENT_NAME)
        return
    
    print("✓ Thermal component initialized")

func _update_outputs():
    """Read outputs from simulation"""
    var new_temp = modelica_node.get_real_output("temperature")
    if abs(new_temp - temperature) > 0.01:
        temperature = new_temp
        temperature_changed.emit(temperature)

## Get temperature in Celsius
func get_temperature_celsius() -> float:
    return temperature - 273.15

## Get temperature in Fahrenheit
func get_temperature_fahrenheit() -> float:
    return (temperature - 273.15) * 9.0/5.0 + 32.0

## Set heater state
func set_heater(on: bool):
    heater_on = on

## Check if temperature is comfortable (18-24°C)
func is_comfortable() -> bool:
    var temp_c = get_temperature_celsius()
    return temp_c >= 18.0 and temp_c <= 24.0

## Get comfort level (0.0 = uninhabitable, 1.0 = perfect)
func get_comfort_level() -> float:
    var temp_c = get_temperature_celsius()
    var ideal_temp = 21.0
    
    if temp_c < -50.0 or temp_c > 60.0:
        return 0.0
    
    var temp_diff = abs(temp_c - ideal_temp)
    
    if temp_diff < 3.0:
        return 1.0
    elif temp_diff < 10.0:
        return 1.0 - (temp_diff - 3.0) / 7.0
    else:
        return max(0.0, 0.5 - (temp_diff - 10.0) / 50.0)
```

**Key Features:**
- Wraps ModelicaNode with domain-specific API
- Emits signals for state changes
- Provides helper methods (temperature conversions, comfort calculations)
- Hides low-level Modelica variable names

### Step 4: Create Game System

**Location:** `scripts/systems/thermal_system.gd`

**Purpose:** Implement game logic on top of physics simulation

```gdscript
extends Node3D
class_name ThermalSystem
## Game system for thermal management

var thermal: ThermalComponent

@export var target_temperature: float = 21.0  # Celsius
@export var temperature_deadband: float = 2.0
@export var heater_power_kw: float = 0.5

@onready var temp_label: Label3D = $TempLabel

func _ready():
    _setup_thermal_component()
    _connect_signals()

func _setup_thermal_component():
    """Initialize the Modelica thermal component"""
    thermal = ThermalComponent.new()
    add_child(thermal)

func _connect_signals():
    """Connect to thermal component signals"""
    if thermal:
        thermal.temperature_changed.connect(_on_temperature_changed)
        thermal.heater_state_changed.connect(_on_heater_changed)

func _process(_delta):
    _update_thermostat()
    _update_ui()

func _update_thermostat():
    """Simple bang-bang thermostat control"""
    if not thermal:
        return
    
    var temp_c = thermal.get_temperature_celsius()
    
    if temp_c < target_temperature - temperature_deadband:
        thermal.set_heater(true)
    elif temp_c > target_temperature + temperature_deadband:
        thermal.set_heater(false)

func _update_ui():
    """Update visual indicators"""
    if temp_label and thermal:
        var temp_c = thermal.get_temperature_celsius()
        var comfort = thermal.get_comfort_level()
        
        temp_label.text = "%.1f°C\n%s" % [
            temp_c,
            "🟢" if comfort > 0.8 else "🟡" if comfort > 0.5 else "🔴"
        ]

func _on_temperature_changed(new_temp: float):
    """Handle temperature change"""
    # Could trigger events, achievements, etc.
    pass

func _on_heater_changed(is_on: bool):
    """Handle heater state change"""
    # Update power grid consumption
    EventBus.emit_signal("power_consumption_changed", get_power_consumption())

func get_power_consumption() -> float:
    """Get current power draw in kW"""
    if thermal and thermal.heater_on:
        return heater_power_kw
    return 0.0

func get_status() -> Dictionary:
    """Get system status for UI/monitoring"""
    if not thermal:
        return {"status": "offline"}
    
    return {
        "status": "online",
        "temperature_c": thermal.get_temperature_celsius(),
        "temperature_k": thermal.temperature,
        "heater_on": thermal.heater_on,
        "comfort_level": thermal.get_comfort_level(),
        "power_draw_kw": get_power_consumption()
    }
```

### Step 5: Create Test Scene

**Location:** `scenes/systems/thermal_habitat.tscn`

**Setup:**
1. Create new 3D scene
2. Add node structure:
   ```
   [Node3D] ThermalHabitat
   ├── [ThermalSystem] (attach thermal_system.gd)
   │   └── [Label3D] TempLabel
   ├── [MeshInstance3D] HabitatMesh
   └── [Camera3D]
   ```

3. Configure ThermalSystem:
   - target_temperature: 21.0
   - temperature_deadband: 2.0
   - heater_power_kw: 0.5

4. Configure TempLabel:
   - Position: (0, 2, 0)
   - Billboard: Enabled
   - Font Size: 32

5. Configure HabitatMesh:
   - Mesh: BoxMesh (2x2x2)
   - Material: Basic with emissive for heater indicator

**Test Script (attach to root):**
```gdscript
extends Node3D

@onready var thermal_system = $ThermalSystem

func _ready():
    print("=== Thermal Habitat Test ===")
    print("Initial temp: %.1f°C" % thermal_system.thermal.get_temperature_celsius())

func _process(_delta):
    # Print status every 2 seconds
    if int(Time.get_ticks_msec()) % 2000 < 16:
        var status = thermal_system.get_status()
        print("Temp: %.1f°C | Heater: %s | Comfort: %.0f%%" % [
            status.temperature_c,
            "ON " if status.heater_on else "OFF",
            status.comfort_level * 100
        ])
```

### Step 6: Test in Godot

1. Open lunco-sim in Godot
2. Open `scenes/systems/thermal_habitat.tscn`
3. Press F5 to run
4. Watch console output:
   ```
   === Thermal Habitat Test ===
   Initial temp: -23.1°C
   Temp: -23.1°C | Heater: ON  | Comfort: 0%
   Temp: -18.4°C | Heater: ON  | Comfort: 5%
   Temp: -12.7°C | Heater: ON  | Comfort: 15%
   ...
   Temp: 19.2°C | Heater: ON  | Comfort: 95%
   Temp: 21.8°C | Heater: OFF | Comfort: 100%
   ```

## Integration Patterns

### Pattern 1: Multiple Systems

```gdscript
# scripts/habitat_module.gd
extends Node3D
class_name HabitatModule

var thermal: ThermalComponent
var power: PowerComponent
var life_support: LifeSupportComponent

func _ready():
    thermal = ThermalComponent.new()
    add_child(thermal)
    
    power = PowerComponent.new()
    add_child(power)
    
    life_support = LifeSupportComponent.new()
    add_child(life_support)
    
    # Connect systems
    thermal.heater_state_changed.connect(_on_thermal_power_changed)

func _on_thermal_power_changed(is_on: bool):
    var power_draw = 0.5 if is_on else 0.0
    power.request_power("thermal", power_draw)

func get_total_power_consumption() -> float:
    return (
        thermal.get_power_consumption() +
        life_support.get_power_consumption()
    )
```

### Pattern 2: Save/Load Integration

```gdscript
# Add to ThermalComponent
func get_save_data() -> Dictionary:
    return {
        "temperature": temperature,
        "heater_on": heater_on
    }

func load_save_data(data: Dictionary):
    if modelica_node:
        # Reset simulation to saved state
        modelica_node.reset_simulation()
        # Note: Need to implement state restoration in ModelicaNode
        # This is a future enhancement
```

### Pattern 3: UI Integration

```gdscript
# scripts/ui/thermal_monitor.gd
extends Control

@onready var temp_label = $VBoxContainer/TempLabel
@onready var comfort_bar = $VBoxContainer/ComfortBar
@onready var heater_indicator = $VBoxContainer/HeaterIndicator

var thermal_system: ThermalSystem

func _ready():
    thermal_system = get_node("/root/GameWorld/HabitatModule/ThermalSystem")
    
    if thermal_system and thermal_system.thermal:
        thermal_system.thermal.temperature_changed.connect(_update_display)
        thermal_system.thermal.heater_state_changed.connect(_update_heater)

func _update_display(temp: float):
    var temp_c = temp - 273.15
    temp_label.text = "%.1f°C" % temp_c
    
    var comfort = thermal_system.thermal.get_comfort_level()
    comfort_bar.value = comfort * 100

func _update_heater(is_on: bool):
    heater_indicator.modulate = Color.RED if is_on else Color.GRAY
```

### Pattern 4: Event-Driven Architecture

```gdscript
# autoload/event_bus.gd
extends Node

signal temperature_critical(habitat_id: String, temp: float)
signal power_shortage(total_demand: float, available: float)
signal life_support_failure(system_name: String)

# scripts/systems/thermal_system.gd
func _on_temperature_changed(new_temp: float):
    var temp_c = new_temp - 273.15
    
    if temp_c < 10.0 or temp_c > 30.0:
        EventBus.emit_signal("temperature_critical", name, temp_c)
```

## Best Practices

### 1. Layer Separation

**DO:**
- Keep physics in Modelica models
- Keep game logic in GDScript systems
- Use component wrappers as clean interfaces

**DON'T:**
- Put game logic in Modelica models
- Access ModelicaNode directly from game systems
- Mix concerns across layers

### 2. Signal Usage

**DO:**
```gdscript
# Component emits signals for state changes
signal temperature_changed(new_temp: float)

# Systems listen to signals
thermal.temperature_changed.connect(_on_temp_changed)
```

**DON'T:**
```gdscript
# Polling in game loop
func _process(_delta):
    var temp = thermal.get_temperature()  # Every frame!
```

### 3. Error Handling

**DO:**
```gdscript
func _initialize_modelica():
    modelica_node = ModelicaNode.new()
    add_child(modelica_node)
    
    if not modelica_node.load_component(COMPONENT_NAME):
        push_error("Critical: Cannot load component")
        queue_free()  # Remove this component
        return false
    
    return true
```

**DON'T:**
```gdscript
func _ready():
    modelica_node.load_component(COMPONENT_NAME)  # Hope it works!
```

### 4. Performance

**DO:**
- Update UI only when values change significantly
- Use signals to avoid polling
- Batch multiple inputs before stepping

**DON'T:**
- Read all outputs every frame
- Create/destroy components frequently
- Step simulation multiple times per frame

## Migration from Old System

If you're migrating from `apps/modelica/core/` (deprecated):

### Old Way:
```gdscript
var sim = load("res://apps/modelica/core/simulator.gd").new()
sim.load_model("SimpleThermalMVP")
sim.step(delta)
```

### New Way:
```gdscript
var thermal = ThermalComponent.new()
add_child(thermal)
# Stepping happens automatically
```

### Migration Checklist:

- [ ] Identify all uses of old simulator
- [ ] Create component wrappers for each model
- [ ] Update scripts to use new components
- [ ] Test thoroughly
- [ ] Remove old dependencies
- [ ] Update documentation

## Troubleshooting

### Component Won't Load

**Symptoms:**
- Error: "Failed to load thermal component"
- ModelicaNode returns false from load_component()

**Solutions:**
1. Verify model is built:
   ```bash
   ls apps/modelica/build/SimpleThermalMVP/SimpleThermalMVP.so
   ```

2. Rebuild models:
   ```bash
   cd apps/modelica
   ./build_models.sh
   ```

3. Check component name matches exactly

### Simulation Not Updating

**Symptoms:**
- Temperature stuck at initial value
- No state changes visible

**Debug:**
```gdscript
func _process(delta):
    print("Delta: ", delta)
    if modelica_node:
        print("Stepping simulation...")
        var temp_before = modelica_node.get_real_output("temperature")
        # ModelicaNode steps automatically
        var temp_after = modelica_node.get_real_output("temperature")
        print("Temp: ", temp_before, " -> ", temp_after)
```

### Performance Issues

**Symptoms:**
- Low FPS with simulation running
- Stuttering

**Solutions:**
1. Profile which component is slow
2. Consider fixed timestep in `_physics_process()`
3. Reduce number of active components
4. Optimize Modelica model

## Advanced Topics

### Custom Solvers

Future enhancement - currently uses default Euler integration.

### State Serialization

Future enhancement - save/load simulation state.

### Networked Simulations

Future enhancement - sync simulations across network.

### Parallel Processing

Future enhancement - step multiple components in parallel.

## See Also

- [ModelicaNode Documentation](./modelica_node_docs.md)
- [Build System Documentation](./build_system_docs.md)
- [Component Wrapper README](../apps/modelica/integration/README.md)
- [Modelica Language Documentation](https://modelica.org/)