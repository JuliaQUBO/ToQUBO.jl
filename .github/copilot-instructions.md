# Copilot Instructions for ToQUBO.jl

## Project Overview

ToQUBO.jl is a Julia package that reformulates general optimization problems into QUBO (Quadratic Unconstrained Binary Optimization) instances. It provides a MathOptInterface (MOI) layer that automatically maps between input and output models, enabling seamless JuMP modeling for quantum annealing and other physics-inspired solution methods.

## Development Guidelines

### Language and Framework

- This is a Julia project (minimum version 1.9)
- Uses MathOptInterface (MOI) for optimization modeling
- Integrates with JuMP for high-level modeling
- Depends on PseudoBooleanOptimization and QUBOTools packages

### Code Style

- Follow the Julia style guide
- Use the project's JuliaFormatter configuration (`.JuliaFormatter.toml`)
- Align assignments, pair arrows, and matrices as configured
- Use type aliases defined in `src/ToQUBO.jl` (e.g., `SAF`, `SQF`, `VI`, `CI`)

### Testing

- Run tests with `julia --project -e 'using Pkg; Pkg.test()'`
- Tests are located in the `test/` directory
- Unit tests are in `test/unit/`
- Integration tests are in `test/integration/`

### Project Structure

- `src/` - Main source code
  - `ToQUBO.jl` - Main module entry point
  - `encoding/` - Variable encoding implementations
  - `model/` - QUBO and PreQUBO model definitions
  - `virtual/` - Virtual variable mapping
  - `compiler/` - Compilation logic
  - `attributes/` - MOI attributes
- `test/` - Test suite
- `docs/` - Documentation

### Key Concepts

- **QUBO**: Quadratic Unconstrained Binary Optimization
- **MOI**: MathOptInterface - Julia's standard optimization interface
- **Encoding**: Methods to represent variables in binary form (e.g., Unary, Binary, Arithmetic, Bounded)
- **Virtual Variables**: Mapping between original model variables and QUBO variables

### Dependencies

When modifying dependencies, update `Project.toml` and ensure compatibility with:
- MathOptInterface 1.x
- PseudoBooleanOptimization 0.2.x
- QUBOTools 0.10.x

### Documentation

- Documentation source files are in `docs/src/`
- Build docs with `julia --project=docs docs/make.jl`

## Common Tasks

### Adding a New Constraint Type

1. Add the constraint handler in the appropriate `src/compiler/` file
2. Update the constraint support in `src/wrapper.jl`
3. Add tests in `test/unit/` and `test/integration/`
4. Update the README.md constraint table if applicable

### Adding a New Encoding Method

1. Implement the encoding in `src/encoding/`
2. Register it in `src/encoding/encoding.jl`
3. Add comprehensive tests
4. Document the encoding method
