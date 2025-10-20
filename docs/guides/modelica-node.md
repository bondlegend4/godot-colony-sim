# ModelicaNode - Godot Extension Documentation

## Overview

`ModelicaNode` is a Godot 3D node that provides a generic interface to run Modelica physics simulations within the Godot game engine. It wraps any compiled Modelica component and exposes controls through GDScript.

## Architecture

```
ModelicaNode (Rust/GDExtension)
    â†"
GenericModelicaComponent (Rust)
    â†"
ModelicaRuntime (Rust FFI)
    â†"
Compiled Modelica C Code (.so/.dll)
```

## Key Features

- **Generic Component Loading** - Load any compiled Modelica model by name
- **Auto-initialization** - Optionally load and initialize on `_ready()`
- **Real-time Simulation** - Step forward automatically in `_process()`
- **Input/Output Interface** - Set inputs and read outputs via GDScript
- **Error Handling** - Graceful error reporting through Godot's logging

## Class Definition

```rust
#[derive(GodotClass)]
#[class(base=Node3D)]
pub struct ModelicaNode {
    base: Base<Node3D>,
    component: GenericModelicaComponent,
    component_name: GString,
    auto_initialize: bool,
}
```

## Exported Properties

### component_name: String
The name of the Modelica component to load (e.g., "SimpleThermalMVP")

**Editor Usage:**
- Set this in the Godot inspector
- Must match the compiled component name exactly

### auto_initialize: bool
Whether to automatically load and initialize the component when the node becomes ready

**Default:** `true`

**When to disable:**
- You want to delay initialization
- You need to set up parameters first
- You're loading components dynamically

## Lifecycle Methods

### _ready()
Called when the node enters the scene tree.

**Behavior:**
- If `auto_initialize` is true and `component_name` is not empty:
  - Calls `load_component()`
  - Logs errors if loading fails
  
### _process(delta: float)
Called every frame.

**Behavior:**
- Steps the simulation forward by `delta` seconds
- Logs errors if simulation step fails

**Note:** If your simulation needs fixed timesteps, consider using `_physics_process()` instead by modifying the code.

## Public Methods (Callable from GDScript)

### load_component(component_name: String) -> bool

Loads and initializes a Modelica component.

**Parameters:**
- `component_name` - Name of the compiled Modelica component

**Returns:**
- `true` if successful
- `false` if loading or initialization failed

**Example:**
```gdscript
var modelica = ModelicaNode.new()
if modelica.load_component("SimpleThermalMVP"):
    print("Component loaded successfully")
else:
    push_error("Failed to load component")
```

**Side Effects:**
- Prints status messages to console
- Initializes the component to its default state

### set_real_input(name: String, value: float) -> bool

Sets a real (floating-point) input variable in the simulation.

**Parameters:**
- `name` - Variable name (must match Modelica model definition)
- `value` - Value to set

**Returns:**
- `true` if successful
- `false` if variable not found or component not loaded

**Example:**
```gdscript
modelica.set_real_input("ambientTemperature", 273.15)
```

### set_bool_input(name: String, value: bool) -> bool

Sets a boolean input variable in the simulation.

**Parameters:**
- `name` - Variable name
- `value` - Boolean value

**Returns:**
- `true` if successful
- `false` if variable not found or component not loaded

**Example:**
```gdscript
modelica.set_bool_input("heaterOn", true)
```

### get_real_output(name: String) -> float

Reads a real output variable from the simulation.

**Parameters:**
- `name` - Variable name

**Returns:**
- The current value of the variable
- `0.0` if variable not found or component not loaded

**Example:**
```gdscript
var temp = modelica.get_real_output("temperature")
print("Current temperature: %.1f K" % temp)
```

### get_all_outputs() -> Dictionary

Retrieves all output values as a dictionary.

**Returns:**
- Dictionary with variable names as keys and values as floats

**Example:**
```gdscript
var outputs = modelica.get_all_outputs()
for key in outputs.keys():
    print("%s = %f" % [key, outputs[key]])
```

**Note:** Current implementation returns an empty dictionary. This needs to be implemented based on your specific component's outputs.

### reset_simulation() -> bool

Resets the simulation to its initial state.

**Returns:**
- `true` if successful
- `false` if reset failed or component not loaded

**Example:**
```gdscript
modelica.reset_simulation()
```

## Usage Patterns

### Pattern 1: Auto-Initialize in Editor

Set up the node in the Godot scene tree:

```
[Node3D] MyScene
└── [ModelicaNode]
    - component_name: "SimpleThermalMVP"
    - auto_initialize: true
```

Attach a script:
```gdscript
extends Node3D

@onready var thermal = $ModelicaNode

func _process(_delta):
    thermal.set_bool_input("heaterOn", should_heat())
    var temp = thermal.get_real_output("temperature")
    update_display(temp)
```

### Pattern 2: Dynamic Loading

```gdscript
extends Node3D

var modelica_node: ModelicaNode

func _ready():
    modelica_node = ModelicaNode.new()
    modelica_node.auto_initialize = false
    add_child(modelica_node)
    
    # Load component when needed
    if user_selects_thermal_mode():
        modelica_node.load_component("SimpleThermalMVP")
```

### Pattern 3: Multiple Components

```gdscript
extends Node3D

var thermal: ModelicaNode
var power: ModelicaNode

func _ready():
    thermal = ModelicaNode.new()
    thermal.load_component("SimpleThermalMVP")
    add_child(thermal)
    
    power = ModelicaNode.new()
    power.load_component("SolarPanel")
    add_child(power)

func _process(_delta):
    # Components step automatically
    var temp = thermal.get_real_output("temperature")
    var watts = power.get_real_output("powerOutput")
```

## Error Handling

The node uses Godot's error logging system:

**Error Messages:**
- `"Failed to load component: {:?}"` - Component file not found or compilation error
- `"Failed to initialize: {:?}"` - Initialization failed (invalid parameters, etc.)
- `"Simulation step failed: {:?}"` - Runtime error during simulation

**Best Practices:**
```gdscript
func setup_simulation():
    if not modelica.load_component("SimpleThermalMVP"):
        push_error("Critical: Cannot start simulation")
        get_tree().quit()
        return
    
    print("Simulation ready")
```

## Performance Considerations

### Frame Rate Impact
- Each `ModelicaNode` steps its simulation every frame
- For complex models, this may impact performance
- Consider using `_physics_process()` for fixed timestep

### Multiple Components
- Each component runs independently
- Consider implementing a manager node to coordinate stepping
- Future optimization: batch step multiple components

### Memory Usage
- Each component instance allocates its own state
- Reuse nodes when possible rather than creating/destroying

## Limitations

1. **No Component Introspection**
   - Cannot query available inputs/outputs at runtime
   - Must know variable names in advance

2. **Limited Output Access**
   - `get_all_outputs()` currently returns empty dictionary
   - Need to implement based on component metadata

3. **No Solver Configuration**
   - Uses default solver settings
   - Cannot adjust tolerance, solver type, etc.

4. **Platform Specific**
   - Requires compiled Modelica components for target platform
   - Must rebuild for Linux/Windows/macOS

## Troubleshooting

### Component Won't Load

**Symptoms:** `load_component()` returns false

**Possible Causes:**
1. Component not compiled
2. Wrong component name
3. Component not in library path

**Solutions:**
```bash
# Verify component exists
ls lunco-sim/apps/modelica/build/SimpleThermalMVP/

# Rebuild component
cd lunco-sim/apps/modelica
./build_models.sh
```

### Simulation Freezes

**Symptoms:** Game freezes when simulation runs

**Possible Causes:**
1. Stiff system requiring small timesteps
2. Unstable numerical solution
3. Division by zero or NaN propagation

**Solutions:**
- Add error checking in `_process()`
- Limit maximum timestep
- Add safety bounds to inputs

### Values Not Updating

**Symptoms:** `get_real_output()` returns same value

**Possible Causes:**
1. Simulation not stepping (check `_process()` is called)
2. Component not initialized
3. Inputs not being set

**Debug:**
```gdscript
func _process(delta):
    print("Delta: ", delta)
    print("Temp before: ", modelica.get_real_output("temperature"))
    # Check if value changes between frames
```

## Integration with lunco-sim

See `apps/modelica/integration/thermal_component.gd` for a complete example of wrapping `ModelicaNode` in a game-specific component.

**Recommended Pattern:**
1. `ModelicaNode` - Generic low-level interface (this class)
2. `ThermalComponent` - Game-specific wrapper with signals and helpers
3. `ThermalSystem` - Game logic layer with UI and controls

## Future Enhancements

- [ ] Implement `get_all_outputs()` using component metadata
- [ ] Add solver configuration options
- [ ] Support for `_physics_process()` fixed timestep
- [ ] Component introspection API
- [ ] Batch stepping for multiple components
- [ ] State serialization for save/load
- [ ] Performance profiling hooks

## See Also

- `GenericModelicaComponent` - Underlying component wrapper
- `modelica-rust-ffi` - FFI layer to Modelica runtime
- `apps/modelica/integration/` - Game-specific wrappers