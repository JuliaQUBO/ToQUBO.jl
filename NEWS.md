# Release Notes

## Unreleased

### Added

- Add QOBLib network and routing reformulation benchmark pilots with provenance, comparison metrics, and incumbent feasibility checks.
- Add QOBLib network penalty-scaling diagnostics with source-variable bit counts and applied-penalty attribution by constraint family.

### Maintenance

- Allow QUBOTools 0.14 while keeping package compatibility with QUBOTools 0.11, 0.12, and 0.13.

## v0.4.1 - 2026-06-19

### Added

- Add public post-sampling feasibility helpers for source-constraint violations, per-result feasibility checks, and feasibility summaries.
- Add configurable penalty heuristic scaling and offset controls, with applied-penalty reporting.
- Add a QOBLib Birkhoff reformulation benchmark pilot with provenance, comparison metrics, and coefficient-range attribution.

### Maintenance

- Allow QUBODrivers 0.6 in the test environment.

## v0.4.0 - 2026-06-07

### Added

- Add public reformulation metadata helpers for original and auxiliary variables, serialized QUBOTools metadata, and projection of QUBO states back to source variables.

### Maintenance

- Allow QUBOTools 0.13 while keeping package compatibility with QUBOTools 0.11 and 0.12.

## v0.3.1 - 2026-06-03

### Maintenance

- Add Dependabot configuration for the root, documentation, and test Julia environments, plus GitHub Actions workflow updates.
- Update GitHub Actions dependencies, including `actions/checkout`, `actions/setup-python`, `codecov/codecov-action`, and `julia-actions/setup-julia`.
- Skip documentation deployment for Dependabot-triggered pull requests while still building the documentation.
- Add compatibility checks covering the Dependabot configuration and maintenance environments.
- Allow `TOML` 1.0.3 and QUBODrivers 0.5 in the relevant maintenance environments.
- Clean legacy repository and default-branch references.

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
