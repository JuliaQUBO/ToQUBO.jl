# Release Notes

## Unreleased

### Fixed

- Rebuild generated encodings, slack, auxiliary variables and target coefficients on every compilation, so ordinary repeated solves and changed encoding settings match a fresh compilation. Invalidate prior child results and feasibility caches before recompiling, including when compilation fails, while preserving source data, optimizer settings and penalty attributes updated by refinement.

## v0.7.0 - 2026-10-08

### Breaking changes

- Enable `Attributes.PrimalFeasibilityCheck()` by default: `MOI.PrimalStatus` now reports `INFEASIBLE_POINT` for samples whose decoded values violate source constraints, using the shared absolute tolerance `1e-6`. Set this attribute to `false` and re-optimize to restore the child sampler's raw status. `MOI.ObjectiveValue` continues to report the penalized target QUBO energy.

### Added

- Add `source_objective_value(model; result)` and `Attributes.SourceObjectiveValue(result_index)` to evaluate the original objective on decoded source values without reformulation penalties. Add opt-in `Attributes.AutoFeasibilityReport()` to cache a report over all results and warn about source-infeasible samples; invalidate feasibility caches on recompilation and repeated solves.
- Add opt-in iterative penalty refinement through `Attributes.MaxPenaltyUpdates()`, `PenaltyUpdateStrategy()`, and `PenaltyUpdateCount()`. The default update budget is zero, preserving a single child solve. `MultiplicativeUpdate(factor = 10.0)` escalates violated constraints' hints or inferred scales, preserves objective-sense signs, recompiles before each new child solve, and stops on feasibility, update-budget exhaustion, empty results, or violations without an updatable constraint penalty. The update budget does not impose a whole-refinement time limit; `CompilationTime()` reports the last compilation only. Refinement writes updated hints, scales, and method multipliers back to the model; later solves start from those settings unless the user explicitly resets the attributes.
- Add `AugmentedLagrangianPenalty(multiplier, rho)` and `SubgradientUpdate(; step, patience, escalation_factor)` for signed multiplier updates on scalar equalities and one-sided updates on scalar inequalities. Inequalities use slack-free iterated unbalanced penalization, which can change feasible energy ordering; this is not an exact one-sided augmented-Lagrangian term or a general convergence guarantee. The strategy updates only supported constraints using this method and escalates `rho` after stalled progress.
- Add opt-in static automatic penalty policies `UBPositivePenalty`, `MaxCoefficientPenalty`, `VLMPenalty`, `MOMCPenalty`, and `MOCPenalty`, with per-constraint, variable-encoding and slack-encoding coefficients, shared objective scans, and recorded fallback reasons. `ObjectiveRangePenalty()` remains the default; unsupported or uncertifiable heuristic cases fall back to `LegacyPenalty()`. Heuristics do not guarantee source feasibility.
- Add `Attributes.VariableEncodingSet()` for explicit finite values of integer or continuous variables encoded with `Encoding.OneHot` or `Encoding.DomainWall`. Validate nonempty, finite, unique values against declared bounds and integer domains; reject unsupported encoding methods and binary, semi-variable, and SOS1 fast-path uses. Encoding-violating raw samples can decode outside the selected set; source feasibility alone does not certify finite-set membership when the set is narrower than the declared source domain.

### Fixed

- Normalize integral constraint residuals by an exact positive arbitrary-precision integer GCD before penalty and integer-slack construction, avoiding term-order-dependent approximate normalization across Julia versions. Preserve zero residuals, sign and roots; fractional residuals retain approximate discretization. This can change compiled target coefficients and slack-variable counts for affected integral constraints.
- Convert coefficients carried by constraint penalty methods to the model's numeric type and reject nonfinite or nonpositive converted values where required. Validate narrowed refinement factors and steps, including overflow and underflow.

### Documentation

- Document source-feasibility result semantics, penalty-free source objectives, static penalty policies, finite value sets, and iterative refinement with its limits.
- Cite the published QUBO.jl article and prepare the reserved version DOI `10.5281/zenodo.23226920` under successor concept DOI `10.5281/zenodo.21763525`, preserving predecessor provenance. The version DOI resolves once the matching release archive is published on Zenodo; keep the legacy GitHub-Zenodo integration disabled.

### Maintenance

- Keep Julia 1.10, QUBOTools 0.16, and PseudoBooleanOptimization 0.2.6/0.3 compatibility. Add explicit Julia 1.10 stdlib bounds for Random and the test environment; allow DisjunctiveProgramming 0.7 in documentation and tests while retaining 0.5/0.6.
- Validate citation schema and synchronized release/citation metadata in CI. Update GitHub Actions dependencies, lint workflows, and add guarded Dependabot merge automation and serialized documentation publishing while retaining Julia 1.10/current on Ubuntu and Windows.

### Tests

- Cover source-feasibility statuses and opt-out, source objectives, feasibility cache/report behavior, refinement escalation and stopping, signed subgradient updates and coefficient conversion, finite-set encoding/rejections, static penalty heuristics and fallback metadata, and exact integer normalization across coefficient orders and numeric types.

## v0.6.1 - 2026-07-21

### Breaking changes

- No breaking changes.

### Added

- Add `Attributes.UnbalancedPenalty(linear, quadratic)` as an opt-in, slack-free encoding for scalar `LessThan`, `GreaterThan`, and `Interval` constraints. The method preserves quadratization for quadratic source constraints and requires an explicit `ConstraintEncodingPenaltyHint` because it can change the energy ordering of feasible assignments.

### Documentation

- Explain scalar equality, inequality, interval, sign-definite, and quadratization reformulations, including when generated slack variables are introduced.
- Clarify bounded continuous-variable bit inference, Neal finite-run penalty tuning, and the distinction between integral and continuous slack encodings.
- Document the continuous-slack residual floor and the penalty-contrast condition required to separate feasible and infeasible assignments.

### Analysis

- Add reproducible dense NPP-like profiling that separates JuMP model construction, compilation, and backend extraction costs.
- Add an executable slack-resolution analysis and generated report covering grid spacing, feasible residual floors, penalty contrast, and seeded sampler behavior.

### Maintenance

- Standardize CI caching and dependency-maintenance configuration, limit coverage processing to one canonical matrix job, and retain the complete Julia 1.10/current × Ubuntu/Windows test matrix.
- Make compatibility and release checks robust to supported Dependabot range expansions.

### Tests

- Cover unbalanced-penalty orientation, interval behavior, quadratization, validation, unsupported equalities, and the new documentation and analysis contracts.

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
