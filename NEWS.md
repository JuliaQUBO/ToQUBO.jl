# Release Notes

## Unreleased

## v0.3.0 - 2026-05-23

### Breaking

- Raise the supported Julia floor from 1.9 to 1.10.

### Added

- Add formulation introspection attributes for compiled objectives, Hamiltonians, source-to-target mappings, slack-variable expansions, and constraint penalty functions.
- Add linear constraint penalty method settings with model-level defaults and per-constraint overrides.
- Add semi-variable encoding support for semicontinuous and semiinteger variable domains.
- Encode eligible binary SOS1 constraints with a shared domain-wall representation.
- Add GDP indicator workflow coverage through DisjunctiveProgramming's `Indicator()` reformulation.

### Fixed

- Preserve compile status and configurable feasibility handling for always-feasible and infeasible scalar constraints.
- Avoid unnecessary squared penalties and slack variables for sign-definite constraint residuals.
- Fix parsing and support coverage for affine and quadratic indicator constraints, including interval indicators and variable-objective expansion.
- Tighten MOI support reporting for quadratic forms, SOS1, and indicator constraints.

### Documentation

- Document the maintained GDP support boundary, the historical DisjunctiveToQUBO artifact disposition, and the GDP paper reference.
- Document linear penalty references, semi-variable encodings, SOS1 support, and the new formulation introspection attributes.
- Expand CI to test Julia 1.10 and latest stable Julia on Ubuntu and Windows.
- Allow QUBOTools 0.12 while keeping compatibility with QUBOTools 0.11.
- Require PySA 0.3.4 and QUBOTools 0.12 for the documentation environment so executed solver examples resolve against the modern QUBODrivers/QUBOTools stack.
