# Creating Component Wrappers Guide

## Purpose

This guide explains how to create GDScript wrapper classes for your Modelica components. Wrappers provide a clean, domain-specific API that hides the low-level ModelicaNode interface.

## Why Create Wrappers?

### Without Wrapper (Bad)
```gdscript
# Game code directly uses ModelicaNode
extends Node3D

var modelica: ModelicaNode

func _ready():
    modelica = ModelicaNode.new()
    modelica.load_component("SimpleThermalMVP")
    add_child(modelica)

func _process(_delta):
    # Hard-coded variable names
    modelica.set_bool_input("heaterOn", true)
    var temp_k = modelica.get_real_output("temperature")
    
    # Manual unit conversion
    var temp_c = temp_k - 273.15
    
    # No signals, just polling
    if temp_c > 25.0:
        print("Too hot!")
```

**Problems:**
- ❌ Variable names exposed to game logic
- ❌ No autocomplete or type safety
- ❌ Manual unit conversions everywhere
- ❌ No signals for state changes
- ❌ Difficult to maintain

### With Wrapper (Good)
```gdscript
# Game code uses domain-specific component
extends Node3D

var thermal: ThermalComponent

func _ready():
    thermal = ThermalComponent.new()
    add_child(thermal)
    thermal.temperature_changed.connect(_on_temp_changed)

func _process(_delta):
    # Clean, semantic API
    thermal.set_heater(should_heat())

func _on_temp_changed(new_temp: float):
    # Already in Celsius, with signal
    if thermal.get_temperature_celsius() > 25.0:
        show_overheating_warning()
```

**Benefits:**
- ✅ Clean, semantic API
- ✅ Type safety and autocomplete
- ✅ Built-in unit conversions
- ✅ Signal-based updates
- ✅ Easy to maintain and test

## Wrapper Template

### Basic Structure

```gdscript
extends Node
class_name ComponentName
## Brief description of what this component simulates
##
## Detailed description including:
## - What physics it models
## - Key features
## - Usage examples

# ============================================================================
# SIGNALS
# ============================================================================

signal state_changed(new_state)
signal error_occurred(error_message: String)

# ============================================================================
# EXPORTED PROPERTIES
# ============================================================================

@export_category("Component Settings")
@export var auto_initialize: bool = true
@export var component_path: String = "ComponentName"

# ============================================================================
# PRIVATE PROPERTIES
# ============================================================================

var _modelica_node: ModelicaNode
var _initialized: bool = false

# State variables (match your Modelica outputs)
var _state_variable: float = 0.0

# ============================================================================
# PUBLIC PROPERTIES (with getters/setters)
# ============================================================================

var some_property: float = 0.0:
    set(value):
        if some_property != value:
            some_property = value
            if _modelica_node:
                _modelica_node.set_real_input("someInput", value)
            state_changed.emit(some_property)
    get:
        return some_property

# ============================================================================
# LIFECYCLE METHODS
# ============================================================================

func _ready():
    if auto_initialize:
        initialize()

func _process(_delta):
    if _initialized:
        _update_outputs()

# ============================================================================
# PUBLIC API
# ============================================================================

## Initialize the component
func initialize() -> bool:
    if _initialized:
        push_warning("Component already initialized")
        return true
    
    _modelica_node = ModelicaNode.new()
    add_child(_modelica_node)
    
    if not _modelica_node.load_component(component_path):
        push_error("Failed to load component: %s" % component_path)
        error_occurred.emit("Failed to load component")
        return false
    
    _initialized = true
    return true

## Reset component to initial state
func reset() -> bool:
    if not _initialized:
        return false
    
    return _modelica_node.reset_simulation()

## Get component status
func get_status() -> Dictionary:
    if not _initialized:
        return {"status": "not_initialized"}
    
    return {
        "status": "operational",
        "state_variable": _state_variable,
        # Add other relevant status info
    }

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _update_outputs():
    """Read outputs from simulation"""
    var new_value = _modelica_node.get_real_output("outputName")
    
    # Only emit signal if value changed significantly
    if abs(new_value - _state_variable) > 0.001:
        _state_variable = new_value
        state_changed.emit(_state_variable)

# ============================================================================
# HELPER METHODS (domain-specific utilities)
# ============================================================================

## Convert to user-friendly units
func get_user_friendly_value() -> float:
    return _state_variable * conversion_factor

## Check if component is in valid state
func is_valid_state() -> bool:
    return _state_variable >= min_value and _state_variable <= max_value
```

## Real Example: ThermalComponent

### Step 1: Plan the Wrapper

**Modelica Model:** SimpleThermalMVP
- **Inputs:** heaterOn (Boolean)
- **Outputs:** temperature (Real, Kelvin), heaterStatus (Real)
- **Parameters:** roomCapacity, ambientTemp, heaterPower, lossCoefficient

**Wrapper Features:**
- Temperature in multiple units (K, °C, °F)
- Comfort level calculation
- Heater control
- Temperature change signals

### Step 2: Implement

```gdscript
extends Node
class_name ThermalComponent
## Thermal simulation component for habitat environments
##
## Wraps SimpleThermalMVP Modelica model to provide thermal dynamics
## simulation including heating, cooling, and ambient heat loss.
##
## Example:
##   var thermal = ThermalComponent.new()
##   add_child(thermal)
##   thermal.temperature_changed.connect(_on_temp_changed)
##   thermal.set_heater(true)

# ============================================================================
# SIGNALS
# ============================================================================

signal temperature_changed(new_temp_kelvin: float)
signal heater_state_changed(is_on: bool)
signal comfort_level_changed(level: float)
signal critical_temperature(temp_celsius: float)

# ============================================================================
# CONSTANTS
# ============================================================================

const COMPONENT_NAME = "SimpleThermalMVP"
const ABSOLUTE_ZERO = 0.0  # Kelvin
const WATER_FREEZING = 273.15  # Kelvin
const COMFORTABLE_MIN = 291.15  # 18°C
const COMFORTABLE_MAX = 297.15  # 24°C
const IDEAL_TEMP = 294.15  # 21°C

# ============================================================================
# EXPORTED PROPERTIES
# ============================================================================

@export_category("Thermal Settings")
@export var auto_initialize: bool = true
@export var initial_temperature: float = 250.0  ## Initial temp in Kelvin

@export_category("Thresholds")
@export var critical_low_temp: float = 263.15  ## -10°C
@export var critical_high_temp: float = 313.15  ## 40°C

# ============================================================================
# PRIVATE PROPERTIES
# ============================================================================

var _modelica_node: ModelicaNode
var _initialized: bool = false

# Current state
var _temperature: float = 250.0  # Kelvin
var _heater_status: float = 0.0
var _last_comfort_level: float = 0.0

# ============================================================================
# PUBLIC PROPERTIES
# ============================================================================

## Current temperature in Kelvin
var temperature: float:
    get: return _temperature

## Heater control
var heater_on: bool = false:
    set(value):
        if heater_on != value:
            heater_on = value
            if _modelica_node and _initialized:
                _modelica_node.set_bool_input("heaterOn", heater_on)
            heater_state_changed.emit(heater_on)

# ============================================================================
# LIFECYCLE METHODS
# ============================================================================

func _ready():
    if auto_initialize:
        initialize()

func _process(_delta):
    if _initialized:
        _update_outputs()
        _check_critical_conditions()

# ============================================================================
# PUBLIC API
# ============================================================================

## Initialize the thermal component
func initialize() -> bool:
    if _initialized:
        push_warning("ThermalComponent already initialized")
        return true
    
    _modelica_node = ModelicaNode.new()
    add_child(_modelica_node)
    
    if not _modelica_node.load_component(COMPONENT_NAME):
        push_error("Failed to load thermal component '%s'" % COMPONENT_NAME)
        return false
    
    _initialized = true
    _temperature = initial_temperature
    
    print("✓ Thermal component initialized at %.1f K (%.1f°C)" % [
        _temperature,
        get_temperature_celsius()
    ])
    
    return true

## Set heater state
func set_heater(on: bool):
    heater_on = on

## Get temperature in Celsius
func get_temperature_celsius() -> float:
    return _temperature - WATER_FREEZING

## Get temperature in Fahrenheit
func get_temperature_fahrenheit() -> float:
    return get_temperature_celsius() * 9.0/5.0 + 32.0

## Check if temperature is in comfortable range
func is_comfortable() -> bool:
    return _temperature >= COMFORTABLE_MIN and _temperature <= COMFORTABLE_MAX

## Get comfort level (0.0 = uninhabitable, 1.0 = perfect)
func get_comfort_level() -> float:
    var temp_diff = abs(_temperature - IDEAL_TEMP)
    
    # Deadly temperatures
    if _temperature < critical_low_temp or _temperature > critical_high_temp:
        return 0.0
    
    # Perfect range (within 3°C of ideal)
    if temp_diff < 3.0:
        return 1.0
    
    # Acceptable range (3-10°C from ideal)
    if temp_diff < 10.0:
        return 1.0 - (temp_diff - 3.0) / 7.0
    
    # Uncomfortable but survivable
    return max(0.0, 0.5 - (temp_diff - 10.0) / 50.0)

## Reset simulation to initial conditions
func reset() -> bool:
    if not _initialized:
        return false
    
    var success = _modelica_node.reset_simulation()
    if success:
        _temperature = initial_temperature
        heater_on = false
    return success

## Get component status dictionary
func get_status() -> Dictionary:
    if not _initialized:
        return {
            "status": "not_initialized",
            "initialized": false
        }
    
    return {
        "status": "operational",
        "initialized": true,
        "temperature_k": _temperature,
        "temperature_c": get_temperature_celsius(),
        "temperature_f": get_temperature_fahrenheit(),
        "heater_on": heater_on,
        "heater_status": _heater_status,
        "comfort_level": get_comfort_level(),
        "is_comfortable": is_comfortable()
    }

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _update_outputs():
    """Read and update outputs from simulation"""
    var new_temp = _modelica_node.get_real_output("temperature")
    var new_heater_status = _modelica_node.get_real_output("heaterStatus")
    
    # Update temperature (with change detection)
    if abs(new_temp - _temperature) > 0.01:  # 0.01 K threshold
        _temperature = new_temp
        temperature_changed.emit(_temperature)
    
    # Update comfort level (if changed significantly)
    var new_comfort = get_comfort_level()
    if abs(new_comfort - _last_comfort_level) > 0.05:  # 5% threshold
        _last_comfort_level = new_comfort
        comfort_level_changed.emit(new_comfort)
    
    # Update heater status
    _heater_status = new_heater_status

func _check_critical_conditions():
    """Check for critical temperature conditions"""
    if _temperature < critical_low_temp:
        critical_temperature.emit(get_temperature_celsius())
    elif _temperature > critical_high_temp:
        critical_temperature.emit(get_temperature_celsius())
```

## Advanced Patterns

### Pattern 1: Multi-Input Component

```gdscript
class_name ElectricalComponent

var voltage: float = 0.0:
    set(value):
        voltage = value
        _update_simulation()

var current: float = 0.0:
    set(value):
        current = value
        _update_simulation()

var load_resistance: float = 1.0:
    set(value):
        load_resistance = max(0.1, value)  # Prevent division by zero
        _update_simulation()

func _update_simulation():
    """Update all inputs at once"""
    if not _modelica_node:
        return
    
    _modelica_node.set_real_input("voltage", voltage)
    _modelica_node.set_real_input("current", current)
    _modelica_node.set_real_input("loadResistance", load_resistance)
```

### Pattern 2: Cached Outputs

```gdscript
class_name PowerComponent

var _output_cache: Dictionary = {}
var _cache_valid: bool = false

func get_power_output() -> float:
    if _cache_valid and _output_cache.has("power"):
        return _output_cache["power"]
    
    _refresh_cache()
    return _output_cache.get("power", 0.0)

func _refresh_cache():
    _output_cache["power"] = _modelica_node.get_real_output("powerOutput")
    _output_cache["efficiency"] = _modelica_node.get_real_output("efficiency")
    _cache_valid = true

func _process(_delta):
    _cache_valid = false  # Invalidate each frame
    _update_outputs()
```

### Pattern 3: Event-Driven Updates

```gdscript
class_name ReactorComponent

signal meltdown_imminent()
signal scram_activated()

var _last_temp: float = 0.0
var _meltdown_threshold: float = 2000.0

func _update_outputs():
    var temp = _modelica_node.get_real_output("coreTemperature")
    
    # Event detection
    if temp > _meltdown_threshold and _last_temp <= _meltdown_threshold:
        meltdown_imminent.emit()
        emergency_scram()
    
    _last_temp = temp

func emergency_scram():
    _modelica_node.set_bool_input("scramSignal", true)
    scram_activated.emit()
```

### Pattern 4: Validation and Constraints

```gdscript
class_name FluidComponent

const MIN_PRESSURE = 0.0
const MAX_PRESSURE = 1000.0
const MIN_FLOW_RATE = 0.0
const MAX_FLOW_RATE = 100.0

var pressure: float = 101.325:
    set(value):
        var clamped = clamp(value, MIN_PRESSURE, MAX_PRESSURE)
        if clamped != value:
            push_warning("Pressure clamped: %.2f -> %.2f" % [value, clamped])
        pressure = clamped
        if _modelica_node:
            _modelica_node.set_real_input("pressure", pressure)

func validate_state() -> bool:
    var p = _modelica_node.get_real_output("pressure")
    var f = _modelica_node.get_real_output("flowRate")
    
    if p < MIN_PRESSURE or p > MAX_PRESSURE:
        push_error("Invalid pressure: %.2f" % p)
        return false
    
    if f < MIN_FLOW_RATE or f > MAX_FLOW_RATE:
        push_error("Invalid flow rate: %.2f" % f)
        return false
    
    return true
```

## Testing Your Wrapper

### Unit Test Template

```gdscript
# test_thermal_component.gd
extends GutTest

var thermal: ThermalComponent

func before_each():
    thermal = ThermalComponent.new()
    add_child_autofree(thermal)
    thermal.initialize()

func test_initialization():
    assert_true(thermal._initialized, "Should be initialized")
    assert_not_null(thermal._modelica_node, "Should have ModelicaNode")

func test_temperature_conversion():
    thermal._temperature = 273.15  # 0°C
    assert_almost_eq(thermal.get_temperature_celsius(), 0.0, 0.01)
    assert_almost_eq(thermal.get_temperature_fahrenheit(), 32.0, 0.1)

func test_heater_control():
    var signal_fired = false
    thermal.heater_state_changed.connect(func(is_on): signal_fired = true)
    
    thermal.set_heater(true)
    assert_true(thermal.heater_on, "Heater should be on")
    assert_true(signal_fired, "Signal should fire")

func test_comfort_calculation():
    thermal._temperature = 294.15  # 21°C (ideal)
    assert_almost_eq(thermal.get_comfort_level(), 1.0, 0.01)
    
    thermal._temperature = 263.15  # -10°C (critical)
    assert_eq(thermal.get_comfort_level(), 0.0)
```

### Manual Test Scene

Create `scenes/tests/test_thermal_component.tscn`:

```gdscript
extends Node3D

@onready var thermal = $ThermalComponent
@onready var label = $Label3D

func _ready():
    print("=== Thermal Component Test ===")
    thermal.temperature_changed.connect(_on_temp_changed)
    thermal.heater_state_changed.connect(_on_heater_changed)

func _process(_delta):
    # Simple thermostat
    if thermal.get_temperature_celsius() < 18.0:
        thermal.set_heater(true)
    elif thermal.get_temperature_celsius() > 24.0:
        thermal.set_heater(false)
    
    # Update display
    label.text = "%.1f°C\nComfort: %.0f%%\nHeater: %s" % [
        thermal.get_temperature_celsius(),
        thermal.get_comfort_level() * 100,
        "ON" if thermal.heater_on else "OFF"
    ]

func _on_temp_changed(temp_k: float):
    print("Temperature: %.1f°C" % (temp_k - 273.15))

func _on_heater_changed(is_on: bool):
    print("Heater: %s" % ("ON" if is_on else "OFF"))
```

## Best Practices Checklist

- [ ] **Signals** for all state changes
- [ ] **Property setters** update simulation automatically
- [ ] **Unit conversions** built into getter methods
- [ ] **Error handling** with graceful fallbacks
- [ ] **Validation** of inputs and outputs
- [ ] **Documentation** with ##  doc comments
- [ ] **Constants** for magic numbers
- [ ] **Status method** for debugging
- [ ] **Reset method** for reusability
- [ ] **Initialize check** in all public methods

## See Also

- [ModelicaNode Documentation](./modelica_node_docs.md)
- [Integration Guide](./integration_guide.md)
- [GDScript Style Guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)