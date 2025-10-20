# Modelica Integration in LunCo Architecture

## Overview

The Modelica integration follows LunCo's architectural principles of modularity, extensibility, and reusability. It is structured as an **addon** (generic) plus an **application** (domain-specific).

## Alignment with LunCo Principles

### 1. Open Source
- ✅ Rust FFI layer: MIT/Apache-2.0
- ✅ Generic addon: MIT compatible
- ✅ Modelica models: MIT (user choice)
- ✅ OpenModelica: OSMC-PL (OSI approved)

### 2. Reuse Existing Solutions
- ✅ OpenModelica: Industry-standard physics simulation
- ✅ Godot GDExtension: Native performance
- ✅ Rust: Memory-safe systems programming
- ✅ Standard Modelica language: Widely adopted

### 3. Easily Extensible
- ✅ Generic addon works with ANY Modelica model
- ✅ Apps provide domain-specific models
- ✅ GDScript wrappers customize interface
- ✅ Git submodules for addon distribution (future)

### 4. UX is Key
- ✅ Simple API for game developers
- ✅ Signals for reactive updates
- ✅ Type-safe GDScript wrappers
- ✅ Editor-friendly @export properties

## Integration with LunCo Folder Structure

Following LunCo's architecture document:

```
lunco-sim/
├── addons/                        # Godot plugins
│   └── modelica_integration/      # Generic Modelica addon
│       ├── modelica.gdextension   # Config
│       └── bin/                   # Compiled libraries
│           └── libgodot_modelica_integration.so
│
├── apps/                          # Applications (high-level)
│   └── modelica/                  # Modelica physics application
│       ├── models/                # Physics models (.mo files)
│       │   ├── SimpleThermalMVP.mo
│       │   └── Mechanical/
│       │       ├── package.mo
│       │       ├── Mass.mo
│       │       └── Spring.mo
│       │
│       ├── build/                 # Compiled models (gitignored)
│       │   └── SimpleThermalMVP/
│       │       └── SimpleThermalMVP.c
│       │
│       ├── integration/           # GDScript component wrappers
│       │   ├── thermal_component.gd
│       │   └── README.md
│       │
│       ├── systems/               # Game systems using physics
│       │   ├── thermal_system.gd
│       │   └── life_support_system.gd
│       │
│       ├── scenes/                # Test/demo scenes
│       │   └── thermal_habitat.tscn
│       │
│       ├── build_models.sh        # Model compilation script
│       └── cli.gd                 # CLI interface (optional)
│
└── core/                          # Core LunCo code
    └── ...                        # (existing LunCo core)
```

## Modularity: Addon vs Application

### Addon Layer: `addons/modelica_integration/`

**Purpose:** Generic, reusable Modelica bridge

**Characteristics:**
- **Self-contained**: No dependencies on LunCo specifics
- **Generic API**: Works with any Modelica model
- **Distributed via git submodule**: (future) Can be pulled into any Godot project
- **Compiled binary**: Rust GDExtension (.so/.dll/.dylib)

**Public API:**
- `ModelicaNode` class
- Methods: `load_component()`, `set_input()`, `get_output()`, `step()`, etc.

**Distribution Strategy:**
```bash
# Future: As a git submodule
git submodule add https://github.com/your-org/modelica-integration-addon \
    ./addons/modelica_integration
```

### Application Layer: `apps/modelica/`

**Purpose:** Domain-specific physics for LunCo

**Characteristics:**
- **Domain models**: Thermal, life support, power, etc.
- **Game integration**: Wrappers that fit LunCo's needs
- **Project-specific**: Tailored for space colony simulation
- **Extensible**: Users can add more models

**Components:**
1. **Models** - Physics definitions (.mo files)
2. **Integration** - GDScript wrappers (component API)
3. **Systems** - Game logic using components
4. **Scenes** - Visual representation and testing

## Application Structure (apps/modelica/)

### 1. Models Directory

**Purpose:** Source of truth for physics equations

**Example:**
```
models/
├── SimpleThermalMVP.mo           # Basic thermal model
├── Habitat.mo                     # Complete habitat simulation
├── LifeSupport.mo                 # O2/CO2 system
├── Power/                         # Power systems package
│   ├── package.mo
│   ├── SolarPanel.mo
│   └── Battery.mo
└── Mechanical/                    # Mechanical systems
    ├── package.mo
    ├── Mass.mo
    └── Spring.mo
```

**Build Process:**
```bash
cd apps/modelica
./build_models.sh                  # Compiles all .mo files
```

### 2. Integration Directory

**Purpose:** GDScript wrappers providing clean API

**Pattern:**
- One wrapper per model
- Hides ModelicaNode complexity
- Exposes game-friendly interface
- Emits signals for events

**Example:**
```gdscript
# integration/thermal_component.gd
extends Node
class_name ThermalComponent

signal temperature_changed(temp_celsius: float)

var _modelica_node: ModelicaNode
var heater_on: bool = false

func _ready():
    _modelica_node = ModelicaNode.new()
    add_child(_modelica_node)
    _modelica_node.load_component("SimpleThermalMVP")

func set_heater(on: bool):
    heater_on = on
    _modelica_node.set_bool_input("heaterOn", on)

func get_temperature_celsius() -> float:
    return _modelica_node.get_real_output("temperature") - 273.15
```

### 3. Systems Directory

**Purpose:** Game logic built on physics components

**Pattern:**
- Extends Node3D for scene integration
- Uses component wrappers
- Implements game rules (thermostat, power management, etc.)
- Connects to LunCo's core systems

**Example:**
```gdscript
# systems/thermal_system.gd
extends Node3D
class_name ThermalSystem

var thermal: ThermalComponent

@export var target_temperature: float = 21.0

func _ready():
    thermal = ThermalComponent.new()
    add_child(thermal)

func _process(_delta):
    # Thermostat logic
    if thermal.get_temperature_celsius() < target_temperature:
        thermal.set_heater(true)
    else:
        thermal.set_heater(false)
```

### 4. Scenes Directory

**Purpose:** Visual scenes for testing/demo

**Example:**
```
scenes/
├── thermal_habitat.tscn          # Test thermal system
├── life_support_module.tscn      # Test O2/CO2 system
└── power_grid.tscn               # Test power system
```

## Integration with LunCo Scene Structure

Following LunCo's scene architecture:

```
Simulation (root)
├── Universe                       # All simulated bodies
│   └── Colony
│       └── Habitats
│           └── Habitat1
│               ├── ThermalSystem  # ← Modelica integration
│               ├── LifeSupportSystem
│               └── PowerSystem
│
├── UI                            # All windows/overlays
│   ├── MainMenu
│   └── HabitatMonitor
│       └── ThermalDisplay        # ← Shows thermal data
│
├── SimManager                    # Current simulation state
└── Avatar                        # Player control
```

### Example Integration

```gdscript
# In a habitat scene
extends Node3D

@onready var thermal = $ThermalSystem
@onready var life_support = $LifeSupportSystem

func _ready():
    # Systems auto-initialize their Modelica components
    thermal.temperature_changed.connect(_on_temperature_changed)
    life_support.oxygen_level_changed.connect(_on_oxygen_changed)

func _on_temperature_changed(temp_c: float):
    # Update UI via signal bus
    EventBus.emit_signal("habitat_temperature_updated", name, temp_c)
    
    # Affect colonist comfort
    if temp_c < 15.0:
        apply_cold_penalty()

func _on_oxygen_changed(o2_percent: float):
    EventBus.emit_signal("habitat_oxygen_updated", name, o2_percent)
    
    if o2_percent < 18.0:
        trigger_low_oxygen_alert()
```

## Plugin Distribution Strategy

Following LunCo's git submodule pattern:

### Option 1: Generic Addon as Submodule (Recommended)

**Repository structure:**
```
modelica-integration-addon/        # Standalone repo
├── modelica.gdextension
├── bin/
│   ├── .gitkeep
│   └── README.md (instructions)
├── README.md
└── LICENSE
```

**In lunco-sim:**
```bash
# Add as submodule
git submodule add https://github.com/your-org/modelica-integration-addon \
    ./addons/modelica_integration

# Update
git submodule update --remote addons/modelica_integration
```

**Build process:**
- Addon repo contains only .gdextension config
- Users build binaries locally: `./build.sh`
- Binaries are gitignored
- OR: Provide pre-compiled binaries via releases

### Option 2: Application-Specific (Current)

**Keep everything in lunco-sim:**
- No submodule for addon (monorepo approach)
- Addon lives in `addons/modelica_integration/`
- Built as part of lunco-sim build process
- Simpler for users, less modular

## Development Workflow

### Adding a New Physics System

1. **Create Modelica Model**
```bash
cd apps/modelica/models
vim SolarPanel.mo
```

2. **Build Model**
```bash
cd ..
./build_models.sh SolarPanel
```

3. **Create Component Wrapper**
```gdscript
# integration/solar_panel_component.gd
extends Node
class_name SolarPanelComponent

var _modelica_node: ModelicaNode
var power_output: float = 0.0

func _ready():
    _modelica_node = ModelicaNode.new()
    add_child(_modelica_node)
    _modelica_node.load_component("SolarPanel")

func get_power_output() -> float:
    return _modelica_node.get_real_output("powerOutput")
```

4. **Create Game System**
```gdscript
# systems/power_system.gd
extends Node3D
class_name PowerSystem

var solar_panels: Array[SolarPanelComponent] = []
var total_power: float = 0.0

func add_solar_panel() -> SolarPanelComponent:
    var panel = SolarPanelComponent.new()
    add_child(panel)
    solar_panels.append(panel)
    return panel

func _process(_delta):
    total_power = solar_panels.reduce(
        func(sum, panel): return sum + panel.get_power_output(),
        0.0
    )
```

5. **Test in Scene**
```
scenes/power_grid.tscn:
  [Node3D] PowerGrid
  ├── [PowerSystem]
  │   ├── [SolarPanelComponent] Panel1
  │   └── [SolarPanelComponent] Panel2
  └── [Label3D] PowerDisplay
```

6. **Integrate into LunCo**
- Add to habitat prefab
- Connect to UI
- Link with resource system
- Add to save/load

## Addon Configuration

**File:** `addons/modelica_integration/modelica.gdextension`

```ini
[configuration]
entry_symbol = "gdextension_rust_init"
compatibility_minimum = "4.2"

[libraries]
linux.x86_64 = "res://addons/modelica_integration/bin/libgodot_modelica_integration.so"
macos = "res://addons/modelica_integration/bin/libgodot_modelica_integration.dylib"
windows.x86_64 = "res://addons/modelica_integration/bin/godot_modelica_integration.dll"
```

**Enable in Godot:**
1. Project → Project Settings → Plugins
2. Enable "Modelica Integration"
3. Restart editor if needed

## Best Practices for LunCo Integration

### 1. Follow LunCo's Module Pattern

**Component Wrappers (integration/):**
- Extend `Node`, not `Node3D` (unless spatial features needed)
- Use signals for state changes
- Provide domain-specific helper methods
- Document with `##` doc comments

```gdscript
extends Node
class_name ThermalComponent
## Physics-based thermal simulation for habitats
##
## Wraps SimpleThermalMVP Modelica model to provide
## realistic thermal dynamics including heating, cooling,
## and heat loss to vacuum.

signal temperature_changed(temp_celsius: float)
signal critical_temperature(is_critical: bool)
```

**Game Systems (systems/):**
- Extend `Node3D` for scene integration
- Use component wrappers, not ModelicaNode directly
- Implement game rules and logic
- Connect to LunCo's core via EventBus/signals

```gdscript
extends Node3D
class_name ThermalSystem
## Thermal management system for habitat modules
##
## Manages heating/cooling and monitors temperature
## for colonist comfort and safety.

var thermal: ThermalComponent

func _ready():
    thermal = ThermalComponent.new()
    add_child(thermal)
    
    # Connect to LunCo's event system
    thermal.temperature_changed.connect(_on_temp_changed)

func _on_temp_changed(temp: float):
    # Integrate with LunCo's systems
    EventBus.emit_signal("habitat_status_changed", {
        "module": name,
        "temperature": temp,
        "comfort": thermal.get_comfort_level()
    })
```

### 2. Integrate with LunCo's SimManager

**Register systems with simulation manager:**

```gdscript
# In SimManager or similar
func register_habitat_systems(habitat: Node3D):
    var thermal = habitat.get_node("ThermalSystem")
    var life_support = habitat.get_node("LifeSupportSystem")
    
    # Add to managed systems
    physics_systems.append(thermal)
    physics_systems.append(life_support)
    
    # Connect for save/load
    thermal.connect("state_changed", _on_system_state_changed)

func _on_system_state_changed(system_name: String, state: Dictionary):
    # Track for save system
    system_states[system_name] = state
```

### 3. Use LunCo's Resource System

**Connect physics to game resources:**

```gdscript
# systems/power_system.gd
extends Node3D
class_name PowerSystem

var solar_panels: Array[SolarPanelComponent] = []

func _process(_delta):
    var total_power = calculate_total_power()
    
    # Report to LunCo's resource manager
    ResourceManager.update_resource("electrical_power", total_power)
    
    # Request power for other systems
    var thermal_demand = get_node("../ThermalSystem").get_power_demand()
    ResourceManager.request_resource("electrical_power", thermal_demand)
```

### 4. UI Integration

**Connect to LunCo's UI system:**

```gdscript
# In UI layer (apps/modelica-ui/ or similar)
extends Control
class_name ThermalMonitor

@onready var temp_label = $TempLabel
@onready var comfort_bar = $ComfortBar

var thermal_system: ThermalSystem

func _ready():
    # Get reference from scene tree or SimManager
    thermal_system = get_node("/root/Simulation/Universe/Colony/Habitat1/ThermalSystem")
    
    if thermal_system:
        thermal_system.thermal.temperature_changed.connect(_update_display)

func _update_display(temp_c: float):
    temp_label.text = "%.1f°C" % temp_c
    comfort_bar.value = thermal_system.thermal.get_comfort_level() * 100
```

### 5. State Management for Save/Load

**Implement state serialization:**

```gdscript
# In ThermalComponent
func get_save_data() -> Dictionary:
    return {
        "temperature": _temperature,
        "heater_on": heater_on,
        "model_state": _modelica_node.get_all_outputs()  # If available
    }

func load_save_data(data: Dictionary):
    if _modelica_node:
        _modelica_node.reset_simulation()
        # Note: Need to implement state restoration in ModelicaNode
        heater_on = data.get("heater_on", false)
```

**Integrate with LunCo's save system:**

```gdscript
# In SimManager save/load
func save_game(path: String):
    var save_data = {
        "version": SAVE_VERSION,
        "habitats": []
    }
    
    for habitat in get_habitats():
        var habitat_data = {
            "name": habitat.name,
            "thermal": habitat.get_node("ThermalSystem").thermal.get_save_data(),
            "life_support": habitat.get_node("LifeSupportSystem").get_save_data()
        }
        save_data.habitats.append(habitat_data)
    
    var file = FileAccess.open(path, FileAccess.WRITE)
    file.store_string(JSON.stringify(save_data))
```

## Performance Considerations

### Simulation Update Strategy

**Option 1: Per-Frame Updates (Default)**
```gdscript
# ModelicaNode._process(delta)
# Steps simulation every frame
# Good for: Real-time visualization, simple models
# Bad for: Complex models, many instances
```

**Option 2: Fixed Timestep**
```gdscript
# In ThermalSystem or similar
var _accumulator: float = 0.0
const FIXED_TIMESTEP: float = 0.1  # 100ms

func _process(delta):
    _accumulator += delta
    
    while _accumulator >= FIXED_TIMESTEP:
        thermal._modelica_node.step(FIXED_TIMESTEP)
        _accumulator -= FIXED_TIMESTEP
```

**Option 3: Managed Updates**
```gdscript
# In SimManager
var physics_systems: Array[Node] = []
var update_interval: float = 0.1
var _time_since_update: float = 0.0

func _process(delta):
    _time_since_update += delta
    
    if _time_since_update >= update_interval:
        # Batch update all physics systems
        for system in physics_systems:
            system.physics_update(update_interval)
        _time_since_update = 0.0
```

### Optimization Tips

1. **Reduce Update Frequency**: Physics doesn't need 60 FPS
2. **LOD System**: Update distant systems less frequently
3. **Cache Outputs**: Don't call `get_output()` multiple times per frame
4. **Conditional Updates**: Pause inactive systems

```gdscript
# Example: LOD-based updates
func _process(delta):
    var distance = global_position.distance_to(player.global_position)
    
    if distance < 50.0:  # Close: full rate
        update_interval = 0.05
    elif distance < 200.0:  # Medium: reduced rate
        update_interval = 0.2
    else:  # Far: minimal rate
        update_interval = 1.0
```

## Testing Strategy

### Unit Tests (GDUnit4 or similar)

```gdscript
# test/test_thermal_component.gd
extends GutTest

var thermal: ThermalComponent

func before_each():
    thermal = ThermalComponent.new()
    add_child_autofree(thermal)
    thermal.initialize()

func test_heating_increases_temperature():
    var initial_temp = thermal.get_temperature_celsius()
    thermal.set_heater(true)
    
    # Simulate some time
    for i in 10:
        thermal._modelica_node.step(1.0)
        thermal._update_outputs()
    
    assert_gt(thermal.get_temperature_celsius(), initial_temp)

func test_comfort_level_calculation():
    thermal._temperature = 294.15  # 21°C
    assert_almost_eq(thermal.get_comfort_level(), 1.0, 0.01)
    
    thermal._temperature = 263.15  # -10°C
    assert_eq(thermal.get_comfort_level(), 0.0)
```

### Integration Tests

```gdscript
# test/test_thermal_system.gd
extends GutTest

func test_thermostat_control():
    var scene = load("res://apps/modelica/scenes/thermal_habitat.tscn").instantiate()
    add_child_autofree(scene)
    
    var system = scene.get_node("ThermalSystem")
    system.target_temperature = 20.0
    
    # Run simulation
    for i in 100:
        scene._process(0.1)
    
    # Check that temperature converged
    var final_temp = system.thermal.get_temperature_celsius()
    assert_almost_eq(final_temp, 20.0, 2.0)
```

### Manual Testing Checklist

- [ ] Component loads without errors
- [ ] Temperature changes when heater toggled
- [ ] Signals fire on state changes
- [ ] UI updates reflect component state
- [ ] Save/load preserves state
- [ ] Performance acceptable with multiple instances
- [ ] No memory leaks after adding/removing components

## Debugging Tools

### Runtime Inspector

Use LunCo's object-inspector addon:

```gdscript
# Add to ThermalComponent for debugging
func _get_inspector_properties() -> Dictionary:
    return {
        "Temperature (K)": _temperature,
        "Temperature (°C)": get_temperature_celsius(),
        "Heater On": heater_on,
        "Comfort Level": get_comfort_level(),
        "Initialized": _initialized
    }
```

### Console Commands

Integrate with panku_console:

```gdscript
# Register commands
func _ready():
    if has_node("/root/PankuConsole"):
        var console = get_node("/root/PankuConsole")
        console.register_command("thermal.set_temp", _console_set_temp)
        console.register_command("thermal.toggle_heater", _console_toggle_heater)

func _console_set_temp(args: Array):
    if args.size() > 0:
        _temperature = float(args[0])
        print("Temperature set to %.1f K" % _temperature)

func _console_toggle_heater(args: Array):
    heater_on = !heater_on
    print("Heater: %s" % ("ON" if heater_on else "OFF"))
```

### Debug Visualization

```gdscript
# In ThermalSystem or component
func _draw():
    if Engine.is_editor_hint() or OS.is_debug_build():
        # Draw temperature gradient
        var color = _get_temperature_color()
        draw_sphere(Vector3.ZERO, 0.5, color)
        
        # Draw debug label
        draw_label_3d(global_position + Vector3.UP * 2, 
                     "%.1f°C" % thermal.get_temperature_celsius())

func _get_temperature_color() -> Color:
    var temp = thermal.get_temperature_celsius()
    if temp < 0: return Color.BLUE
    elif temp < 18: return Color.CYAN
    elif temp > 24: return Color.ORANGE
    elif temp > 30: return Color.RED
    else: return Color.GREEN
```

## Documentation Standards

Follow LunCo's documentation practices:

```gdscript
extends Node
class_name ThermalComponent
## Thermal simulation component for habitat modules
##
## This component wraps the SimpleThermalMVP Modelica model to provide
## physics-based thermal simulation including:
## - Heat transfer to/from ambient environment
## - Active heating via electric heater
## - Temperature-based comfort calculations
##
## @tutorial: https://docs.lunco.space/systems/thermal
## @experimental

# Signal documentation
## Emitted when temperature changes by more than 0.01 K
## [param new_temp_kelvin] The new temperature in Kelvin
signal temperature_changed(new_temp_kelvin: float)

## Emitted when heater state changes
## [param is_on] True if heater is now on, false if off
signal heater_state_changed(is_on: bool)

# Property documentation
## Target temperature for automatic control (°C)
@export_range(15.0, 30.0, 0.1, "suffix:°C") var target_temperature: float = 21.0

## Enable automatic thermostat control
@export var auto_control: bool = true
```

## Migration from Legacy System

If migrating from LunCo's existing physics system:

### Phase 1: Parallel Implementation
- Keep old system running
- Add new Modelica system alongside
- Compare outputs for validation

### Phase 2: Feature Parity
- Ensure all old features work in new system
- Update UI to use new APIs
- Migrate save/load format

### Phase 3: Deprecation
- Mark old system as deprecated
- Add migration warnings
- Document upgrade path

### Phase 4: Removal
- Remove old code
- Clean up unused dependencies
- Update all documentation

## Future Enhancements

### Planned Features

1. **Model Hot-Reloading**
   - Rebuild models without restarting Godot
   - Useful for rapid iteration

2. **Visual Model Editor**
   - Integrate with modelica-ui
   - Drag-and-drop model composition

3. **Performance Profiler**
   - Track simulation step times
   - Identify bottlenecks

4. **Network Synchronization**
   - Sync simulations across clients
   - Authoritative server option

5. **State Interpolation**
   - Smooth visual updates
   - Decouple simulation from render rate

## Resources

- **LunCo Architecture**: `LunCo-Architecture.md`
- **Modelica Documentation**: [ModelicaNode Docs](./modelica_node_docs.md)
- **Integration Guide**: [lunco-sim Integration](./integration_guide.md)
- **Build System**: [Build Documentation](./build_system_docs.md)
- **OpenModelica**: https://openmodelica.org/
- **Godot GDExtension**: https://docs.godotengine.org/en/stable/tutorials/scripting/gdextension/

## Support

For issues specific to:
- **Modelica integration**: See project issues
- **LunCo architecture**: See LunCo documentation
- **OpenModelica**: OpenModelica forums
- **Godot**: Godot community forums