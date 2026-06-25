# Release Notes

## v0.6.0 - 2026-06-25

### Breaking changes

- Require QUBOTools 0.16; support for QUBOTools 0.15 and earlier is dropped. The QUBO fast-path backend now assembles models through the public QUBOTools v0.16 COO constructor, so older versions can no longer satisfy the dependency.

### Maintenance

- Replace the local mirror of `QUBOTools._build_sparse_forms` with the public `QUBOTools.Model` COO constructor for backend assembly, removing the dependency on QUBOTools normal-form internals (`Form`, `SparseLinearForm`, `SparseQuadraticForm`). Closes the cleanup tracked in JuliaQUBO/QUBOTools.jl#115.
- Drop the now-unused `SparseArrays` dependency.

### Tests

- Add backend-equivalence coverage for sparse and dense TSP-like quadratic models and assert stable variable ordering and index mapping against the QUBOTools backend.

## v0.5.2 - 2026-06-25

### Breaking changes

- No breaking changes.

### Performance

- Reduce NPP QUBO fast-path compiler overhead by accumulating backend linear and quadratic data directly into sparse-array constructor inputs, avoiding the large intermediate `Dict{Tuple{VI,VI},T}` cache build while still writing the target MOI `ScalarQuadraticFunction` and preserving the `QUBOTools.backend(model)` path.

### Maintenance

- Require QUBOTools 0.15, since the QUBO fast path now relies on its sparse normal-form APIs (`Form`, `SparseLinearForm`, `SparseQuadraticForm`); the previous 0.11–0.14 compatibility no longer applies.
- Add a `SparseArrays` compatibility bound.
- Add equivalence coverage for duplicate, reversed, and cancelling quadratic terms so the direct sparse summation path stays equivalent to parsing the target MOI model.

## v0.5.1 - 2026-06-24

### Breaking changes

- No breaking changes.

### Fixed

- Preserve zero-linear QUBO variables in the dense QUBO fast-path backend cache.
- Use PseudoBooleanOptimization's signed quadratization support for maximization models instead of flipping Hamiltonian coefficients in place.

### Documentation

- Clarify continuous-variable bit inference and slack-penalty provenance.
- Stop executing PySA examples in the ToQUBO documentation build so downstream solver-wrapper compatibility does not block ToQUBO releases.

### Maintenance

- Allow PseudoBooleanOptimization 0.3 while retaining compatibility with 0.2.6.
- Allow QUBOTools 0.15 while retaining compatibility with QUBOTools 0.11, 0.12, 0.13, and 0.14.
- Allow the documentation environment to resolve with QUBOTools 0.15 and remove its direct PySA dependency.
- Add release-process guardrails and release-note templates.

## v0.5.0 - 2026-06-22

### Breaking changes

- Use the objective-range policy as the default automatic penalty inference path; downstream checks that assert exact legacy maxgap-derived coefficients should request the legacy fallback policy or update their expectations.

### Added

- Add QOBLib network and routing reformulation benchmark pilots with provenance, comparison metrics, and incumbent feasibility checks.
- Add QOBLib network penalty-scaling diagnostics with source-variable bit counts and applied-penalty attribution by constraint family.
- Add objective-range automatic penalty inference, with legacy maxgap inference available as an explicit fallback policy and diagnostic metadata.
- Record per-inferred penalty gaps, gap sources, selected policies, and final coefficients in penalty policy metadata.

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
