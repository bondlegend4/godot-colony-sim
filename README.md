# Godot Colony Sim - Modelica Integration

Physics-based simulation for space colony games using OpenModelica and Godot.

## Quick Start
```bash
# Build everything
./build.sh

# Open in Godot
cd lunco-sim && godot --editor .
```

See [Quick Start Guide](docs/quickstart.md) for detailed setup.

## Documentation

- 📖 [Documentation Index](docs/README.md)
- 🚀 [Quick Start](docs/quickstart.md)
- 🏗️ [Architecture](docs/architecture/overview.md)
- 🔧 [Build System](docs/guides/build-system.md)
- 📚 [API Reference](docs/api/modelica-node.md)

## Project Structure
```
├── godot-modelica-rust-integration/  # Rust integration layer
├── lunco-sim/                        # LunCo game project
│   ├── addons/modelica_integration/  # Generic addon
│   └── apps/modelica/                # Physics models & systems
└── docs/                             # Documentation
```

## License

[Your License Here]