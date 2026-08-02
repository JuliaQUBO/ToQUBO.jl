module Attributes

import MathOptInterface as MOI
const MOIU = MOI.Utilities
const VI   = MOI.VariableIndex
const CI   = MOI.ConstraintIndex

import PseudoBooleanOptimization as PBO
import QUBOTools

import ..ToQUBO: Optimizer, PreQUBOModel, QUBOModel
import ..Encoding
import ..Virtual

function MOIU.map_indices(::Function, e::Encoding.VariableEncodingMethod)
    return e
end

abstract type ConstraintPenaltyMethod end

@doc raw"""
    QuadraticPenalty()

Encode equality constraints with the standard squared residual penalty.

If the parsed residual is provably nonnegative, the compiler may use the
residual directly instead of squaring it. This preserves the same minimizer at
zero while avoiding unnecessary higher-order terms. Automatic penalty inference
is still available for this sign-definite shortcut.
"""
struct QuadraticPenalty <: ConstraintPenaltyMethod end

@doc raw"""
    LinearPenalty()

Encode equality constraints with a signed linear residual penalty.

This method is heuristic: unlike [`QuadraticPenalty`](@ref), it is not
guaranteed to make every infeasible assignment more expensive. Use
[`ConstraintEncodingPenaltyHint`](@ref) to tune the signed penalty strength.
Automatic penalty inference is not available for this method.

This option follows the linear Ising penalty method studied by Mirkarimi et al.
in "Quantum optimization with linear Ising penalty functions for customer data
science" ([doi:10.1103/PhysRevResearch.6.043241](https://doi.org/10.1103/PhysRevResearch.6.043241))
and "Experimental demonstration of improved quantum optimization with linear
Ising penalties" ([doi:10.1088/1367-2630/ad7e4a](https://doi.org/10.1088/1367-2630/ad7e4a)).
"""
struct LinearPenalty <: ConstraintPenaltyMethod end

@doc raw"""
    UnbalancedPenalty(linear = 1.0, quadratic = 0.5)

Encode scalar inequality constraints without a slack variable using an
unbalanced linear-plus-quadratic penalty.

For a `LessThan` residual ``g(x) \leq 0``, the generated penalty is

```math
\lambda_1 g(x) + \lambda_2 g(x)^2,
```

and the linear term is negated for a `GreaterThan` residual
``g(x) \geq 0``. Both coefficients must be finite and positive. The defaults
come from the quadratic Taylor approximation of an exponential barrier.

This method is heuristic: feasible points need not have equal or zero penalty,
so it can change their energy ordering. It requires an explicit
[`ConstraintEncodingPenaltyHint`](@ref) and is not supported for equality
constraints. For affine inequalities it introduces no slack or quadratization
variables; quadratic inequalities can still require quadratization.

This formulation follows the unbalanced penalization method of Montañez-Barrera
et al., "Unbalanced penalization: a new approach to encode inequality
constraints of combinatorial problems for quantum optimization algorithms"
([doi:10.1088/2058-9565/ad35e4](https://doi.org/10.1088/2058-9565/ad35e4)).
"""
struct UnbalancedPenalty{T<:Real} <: ConstraintPenaltyMethod
    linear::T
    quadratic::T

    function UnbalancedPenalty{T}(linear::T, quadratic::T) where {T<:Real}
        if !(isfinite(linear) && linear > zero(T))
            throw(ArgumentError("linear coefficient must be finite and positive"))
        elseif !(isfinite(quadratic) && quadratic > zero(T))
            throw(ArgumentError("quadratic coefficient must be finite and positive"))
        end

        return new{T}(linear, quadratic)
    end
end

function UnbalancedPenalty(linear::Real = 1.0, quadratic::Real = 0.5)
    λ₁, λ₂ = promote(linear, quadratic)

    return UnbalancedPenalty{typeof(λ₁)}(λ₁, λ₂)
end

function MOIU.map_indices(::Function, method::ConstraintPenaltyMethod)
    return method
end

function _attribute_from_key end

_attribute_from_key(key::Symbol) = _attribute_from_key(Val(key))

abstract type CompilerAttribute <: MOI.AbstractOptimizerAttribute end

MOI.supports(::Optimizer, ::A) where {A<:CompilerAttribute} = true

_copy_or_nothing(x) = isnothing(x) ? nothing : copy(x)

function _is_qubo_fast_path(model::Optimizer)
    return get(model.compiler_settings, :qubo_fast_path, false) === true
end

function _compiled_qubo_objective_from_target(model::Optimizer{T}) where {T}
    objective = MOI.get(
        model.target_model,
        MOI.ObjectiveFunction{MOI.ScalarQuadraticFunction{T}}(),
    )
    f = PBO.PBF{VI,T}()

    for term in objective.quadratic_terms
        x = term.variable_1
        y = term.variable_2
        c = term.coefficient

        if x == y
            f[x] += c / 2
        elseif x.value <= y.value
            f[VI[x, y]] += c
        else
            f[VI[y, x]] += c
        end
    end

    for term in objective.affine_terms
        f[term.variable] += term.coefficient
    end

    f[nothing] += objective.constant

    return f
end

abstract type AutomaticPenaltyPolicy end

@doc raw"""
    ObjectiveRangePenalty()

Infer automatic penalty coefficients from a sufficient exact-penalty bound
based on the compiled objective range. When ToQUBO can certify finite objective
bounds and a positive violation gap for a generated nonnegative penalty
function, penalties are inferred as
``scale * sigma * ((objective_range + margin) / epsilon)``.

This is the default policy. If the bound cannot be certified for a particular
penalty function, ToQUBO falls back to [`LegacyPenalty`](@ref) for that
coefficient and records the fallback in reformulation metadata.
"""
struct ObjectiveRangePenalty <: AutomaticPenaltyPolicy end

@doc raw"""
    LegacyPenalty()

Use the historical ToQUBO automatic penalty heuristic
``scale * sigma * (delta / epsilon + beta)``, where `delta` is computed with
`PBO.maxgap` on the compiled source objective. This policy remains available
for compatibility and as a fallback when [`ObjectiveRangePenalty`](@ref) cannot
be certified.
"""
struct LegacyPenalty <: AutomaticPenaltyPolicy end

@doc raw"""
    UBPositivePenalty()

Upper-bound heuristic for objectives with nonnegative coefficients (UB,
Ayodele 2022, Eq. 12): the penalty magnitude is the sum of every non-constant
objective coefficient, i.e. the non-constant contribution to the objective
value at the all-ones point (a constant offset does not affect the bound,
matching Eq. 12's QUBO-matrix formulation). If any
non-constant coefficient is negative the bound is invalid and ToQUBO falls
back to [`LegacyPenalty`](@ref) for that coefficient, recording the reason in
reformulation metadata.

Applied as ``\rho = s \sigma (\lambda + \beta) / \epsilon`` like every
automatic policy, where ``s`` is the penalty scale, ``\sigma`` the sense sign,
``\beta`` the penalty offset, and ``\epsilon`` the penalty function's positive
gap.

Reference: M. Ayodele, *Penalty Weights in QUBO Formulations: Permutation
Problems* (EvoCOP 2022), [arXiv:2206.11040](https://arxiv.org/abs/2206.11040).
"""
struct UBPositivePenalty <: AutomaticPenaltyPolicy end

@doc raw"""
    MaxCoefficientPenalty()

Maximum QUBO coefficient heuristic (MQC, Ayodele 2022, Eq. 13; after Lucas
2014): the penalty magnitude is the largest non-constant objective
coefficient. Falls back to [`LegacyPenalty`](@ref) when the objective has no
non-constant term or its maximum coefficient is not strictly positive.

References: M. Ayodele, [arXiv:2206.11040](https://arxiv.org/abs/2206.11040);
A. Lucas, *Ising formulations of many NP problems*, Front. Phys. 2:5 (2014).
"""
struct MaxCoefficientPenalty <: AutomaticPenaltyPolicy end

@doc raw"""
    VLMPenalty()

Verma–Lewis method (VLM, Verma & Lewis 2022; Ayodele 2022, Eqs. 14–15): the
penalty magnitude is the largest possible one-flip change of the objective,
``\lambda = \max_i \max(W^+_i, W^-_i)``, where for each variable ``i``

```math
W^+_i = c_{\{i\}} + \sum_{T \ni i,\, |T| \ge 2} \max(c_T, 0), \qquad
W^-_i = -c_{\{i\}} - \sum_{T \ni i,\, |T| \ge 2} \min(c_T, 0),
```

with each monomial of the compiled pseudo-Boolean objective credited to every
variable it contains (the degree-``\ge 2`` generalization of the quadratic
row-sum form). Falls back to [`LegacyPenalty`](@ref) when the bound is not
finite and strictly positive.

References: A. Verma and M. Lewis, *Penalty and partitioning techniques to
improve performance of QUBO solvers*, Discrete Optimization 44 (2022),
[doi:10.1016/j.disopt.2020.100594](https://doi.org/10.1016/j.disopt.2020.100594);
M. Ayodele, [arXiv:2206.11040](https://arxiv.org/abs/2206.11040).
"""
struct VLMPenalty <: AutomaticPenaltyPolicy end

@doc raw"""
    MOMCPenalty()

Maximum change in objective over minimum change in constraint (MOMC, Ayodele
2022, Eqs. 16–18), computed **per penalty function**: with ``\lambda_{VLM}``
the [`VLMPenalty`](@ref) bound of the objective and ``\gamma`` the smallest
*strictly positive* one-flip change of this coefficient's penalty function,
the penalty magnitude is ``\lambda = \max(1, \lambda_{VLM} / \gamma)``. Falls
back to [`LegacyPenalty`](@ref) when the objective bound is not finite and
positive or the penalty function has no positive one-flip change.

Unlike the aggregated single-matrix form of the reference, ToQUBO computes one
coefficient per constraint, variable-encoding, and slack-encoding penalty
function.

Reference: M. Ayodele, [arXiv:2206.11040](https://arxiv.org/abs/2206.11040).
"""
struct MOMCPenalty <: AutomaticPenaltyPolicy end

@doc raw"""
    MOCPenalty()

Maximum objective-to-constraint ratio (MOC, Ayodele 2022, Eq. 19), computed
**per penalty function**: pairing the one-flip changes of the objective
(``W^{c,\pm}_i``) with those of this coefficient's penalty function
(``W^{g,\pm}_i``) per variable and flip direction, the penalty magnitude is

```math
\lambda = \max\left(1, \max_{i,\, W^{g}_i > 0} \left| W^{c}_i / W^{g}_i \right| \right).
```

Falls back to [`LegacyPenalty`](@ref) when the penalty function has no
strictly positive one-flip change or the objective bound is not finite.

Reference: M. Ayodele, [arXiv:2206.11040](https://arxiv.org/abs/2206.11040).
"""
struct MOCPenalty <: AutomaticPenaltyPolicy end

@doc raw"""
    PenaltyUpdate

Abstract type for iterative penalty-update strategies used by the
penalty-refinement loop enabled through [`MaxPenaltyUpdates`](@ref).
"""
abstract type PenaltyUpdate end

@doc raw"""
    MultiplicativeUpdate(factor::Real = 10.0)

Multiplicative penalty escalation (the strategy of MQT QAO,
arXiv:2406.12840): after each solve, every source constraint violated by the
best sample has its penalty coefficient magnitude multiplied by `factor`.
Hinted constraints have their [`ConstraintEncodingPenaltyHint`](@ref)
multiplied directly (preserving its sign); automatically inferred constraints
have their [`ConstraintPenaltyScale`](@ref) multiplied, which also escalates
the constraint's slack-encoding penalty. `factor` must be finite and greater
than one.

Escalation raises the QUBO's coefficient range, which real samplers resolve
with limited precision; for a bounded-coefficient alternative see the
subgradient (augmented-Lagrangian) strategy tracked in ToQUBO#233.
"""
struct MultiplicativeUpdate <: PenaltyUpdate
    factor::Float64

    function MultiplicativeUpdate(factor::Real = 10.0)
        isfinite(factor) && factor > 1 ||
            throw(ArgumentError("Penalty update factor must be finite and greater than one"))

        return new(Float64(factor))
    end
end

function MOIU.map_indices(::Function, policy::AutomaticPenaltyPolicy)
    return policy
end

function MOIU.map_indices(::Function, strategy::PenaltyUpdate)
    return strategy
end

function MOIU.map_indices(
    ::AbstractDict{T,T},
    strategy::PenaltyUpdate,
) where {T<:Union{MOI.VariableIndex,MOI.ConstraintIndex}}
    return strategy
end

function MOIU.map_indices(
    ::AbstractDict{T,T},
    policy::AutomaticPenaltyPolicy,
) where {T<:Union{MOI.VariableIndex,MOI.ConstraintIndex}}
    return policy
end

@doc raw"""
    SourceModel()
"""
struct SourceModel <: CompilerAttribute end

MOI.is_set_by_optimize(::SourceModel) = true

function MOI.get(model::Optimizer{T}, ::SourceModel)::PreQUBOModel{T} where {T}
    return model.source_model
end

@doc raw"""
    TargetModel()
"""
struct TargetModel <: CompilerAttribute end

MOI.is_set_by_optimize(::TargetModel) = true

function MOI.get(model::Optimizer{T}, ::TargetModel)::QUBOModel{T} where {T}
    return model.target_model
end

@doc raw"""
    CompiledObjectiveFunction()

Return the pseudo-boolean objective parsed from the source model, before
penalty terms are added.
"""
struct CompiledObjectiveFunction <: CompilerAttribute end

MOI.is_set_by_optimize(::CompiledObjectiveFunction) = true

function MOI.get(
    model::Optimizer{T},
    ::CompiledObjectiveFunction,
)::PBO.PBF{VI,T} where {T}
    if _is_qubo_fast_path(model)
        return _compiled_qubo_objective_from_target(model)
    end

    return copy(model.f)
end

function compiled_objective_function(model::Optimizer)
    return MOI.get(model, CompiledObjectiveFunction())
end

@doc raw"""
    CompiledHamiltonian()

Return the final pseudo-boolean function written to the target QUBO model,
after penalties and quadratization are applied.
"""
struct CompiledHamiltonian <: CompilerAttribute end

MOI.is_set_by_optimize(::CompiledHamiltonian) = true

function MOI.get(
    model::Optimizer{T},
    ::CompiledHamiltonian,
)::PBO.PBF{VI,T} where {T}
    if _is_qubo_fast_path(model)
        return _compiled_qubo_objective_from_target(model)
    end

    return copy(model.H)
end

function compiled_hamiltonian(model::Optimizer)
    return MOI.get(model, CompiledHamiltonian())
end

@doc raw"""
    CompilationTime()
"""
struct CompilationTime <: CompilerAttribute end

_attribute_from_key(::Val{:compilation_time}) = CompilationTime

MOI.is_set_by_optimize(::CompilationTime) = true

function MOI.get(model::Optimizer, ::CompilationTime)::Union{Float64,Nothing}
    return get(model.compiler_settings, :compilation_time, nothing)
end

function MOI.set(model::Optimizer, ::CompilationTime, t::Any)
    model.compiler_settings[:compilation_time] = convert(Float64, t)

    return nothing
end

function MOI.set(model::Optimizer, ::CompilationTime, ::Nothing)
    delete!(model.compiler_settings, :compilation_time)

    return nothing
end

function compilation_time(model::Optimizer)::Union{Float64,Nothing}
    return MOI.get(model, CompilationTime())
end

@doc raw"""
    CompilationStatus()
"""
struct CompilationStatus <: CompilerAttribute end

_attribute_from_key(::Val{:compilation_status}) = CompilationStatus

MOI.is_set_by_optimize(::CompilationStatus) = true

function MOI.get(model::Optimizer, ::CompilationStatus)
    return get(model.compiler_settings, :compilation_status, MOI.OPTIMIZE_NOT_CALLED)
end

function MOI.set(model::Optimizer, ::CompilationStatus, status::MOI.TerminationStatusCode)
    model.compiler_settings[:compilation_status] = status

    return nothing
end

function MOI.set(model::Optimizer, ::CompilationStatus, ::Nothing)
    delete!(model.compiler_settings, :compilation_status)

    return nothing
end

function compilation_status(model::Optimizer)::MOI.TerminationStatusCode
    return MOI.get(model, CompilationStatus())
end

@doc raw"""
    Warnings()
"""
struct Warnings <: CompilerAttribute end

_attribute_from_key(::Val{:warnings}) = Warnings

function MOI.get(model::Optimizer, ::Warnings)::Bool
    return get(model.compiler_settings, :warnings, true)
end

function MOI.set(model::Optimizer, ::Warnings, flag::Bool)
    model.compiler_settings[:warnings] = flag

    return nothing
end

function MOI.set(model::Optimizer, ::Warnings, ::Nothing)
    delete!(model.compiler_settings, :warnings)

    return nothing
end

function warnings(model::Optimizer)::Bool
    return MOI.get(model, Warnings())
end

@doc raw"""
    MaxPenaltyUpdates()

Maximum number of penalty-refinement iterations performed inside a single
`MOI.optimize!` call. When greater than zero, after each solve the best
sample is checked against the source constraints; while any is violated and
the budget is not exhausted, penalties are updated according to
[`PenaltyUpdateStrategy`](@ref), the model is recompiled, and the sampler is
invoked again.

Defaults to `0`, which disables refinement and preserves single-solve
behavior exactly.
"""
struct MaxPenaltyUpdates <: CompilerAttribute end

_attribute_from_key(::Val{:max_penalty_updates}) = MaxPenaltyUpdates

function MOI.get(model::Optimizer, ::MaxPenaltyUpdates)::Int
    return get(model.compiler_settings, :max_penalty_updates, 0)
end

function MOI.set(model::Optimizer, ::MaxPenaltyUpdates, n::Integer)
    n >= 0 || throw(ArgumentError("Maximum number of penalty updates must be nonnegative"))

    model.compiler_settings[:max_penalty_updates] = Int(n)

    return nothing
end

function MOI.set(model::Optimizer, ::MaxPenaltyUpdates, ::Nothing)
    delete!(model.compiler_settings, :max_penalty_updates)

    return nothing
end

function max_penalty_updates(model::Optimizer)::Int
    return MOI.get(model, MaxPenaltyUpdates())
end

@doc raw"""
    PenaltyUpdateStrategy()

The [`PenaltyUpdate`](@ref) strategy applied by the penalty-refinement loop
(see [`MaxPenaltyUpdates`](@ref)). Defaults to [`MultiplicativeUpdate`](@ref)`()`.
"""
struct PenaltyUpdateStrategy <: CompilerAttribute end

_attribute_from_key(::Val{:penalty_update_strategy}) = PenaltyUpdateStrategy

function MOI.get(model::Optimizer, ::PenaltyUpdateStrategy)::PenaltyUpdate
    return get(model.compiler_settings, :penalty_update_strategy, MultiplicativeUpdate())
end

function MOI.set(model::Optimizer, ::PenaltyUpdateStrategy, strategy::PenaltyUpdate)
    model.compiler_settings[:penalty_update_strategy] = strategy

    return nothing
end

function MOI.set(model::Optimizer, ::PenaltyUpdateStrategy, ::Nothing)
    delete!(model.compiler_settings, :penalty_update_strategy)

    return nothing
end

function penalty_update_strategy(model::Optimizer)::PenaltyUpdate
    return MOI.get(model, PenaltyUpdateStrategy())
end

@doc raw"""
    PenaltyUpdateCount()

Number of penalty-refinement iterations performed by the last
`MOI.optimize!` call, or `nothing` before any solve. Zero means the loop was
disabled, the first solve was already feasible, or no result was available.
"""
struct PenaltyUpdateCount <: CompilerAttribute end

MOI.is_set_by_optimize(::PenaltyUpdateCount) = true

function MOI.get(model::Optimizer, ::PenaltyUpdateCount)::Union{Int,Nothing}
    return get(model.compiler_settings, :penalty_update_count, nothing)
end

function penalty_update_count(model::Optimizer)::Union{Int,Nothing}
    return MOI.get(model, PenaltyUpdateCount())
end

@doc raw"""
    PrimalFeasibilityCheck()

When enabled, `MOI.PrimalStatus` reports `MOI.INFEASIBLE_POINT` for sampled
results whose projected source-variable values violate any source constraint,
using the same measurement as `ToQUBO.violations`. Results that satisfy every
source constraint keep the underlying sampler's status.

Enabled by default. Disable to restore the sampler's raw status:

```julia
MOI.set(model, Attributes.PrimalFeasibilityCheck(), false)
```
"""
struct PrimalFeasibilityCheck <: CompilerAttribute end

_attribute_from_key(::Val{:primal_feasibility_check}) = PrimalFeasibilityCheck

function MOI.get(model::Optimizer, ::PrimalFeasibilityCheck)::Bool
    return get(model.compiler_settings, :primal_feasibility_check, true)
end

function MOI.set(model::Optimizer, ::PrimalFeasibilityCheck, flag::Bool)
    model.compiler_settings[:primal_feasibility_check] = flag

    return nothing
end

function MOI.set(model::Optimizer, ::PrimalFeasibilityCheck, ::Nothing)
    delete!(model.compiler_settings, :primal_feasibility_check)

    return nothing
end

function primal_feasibility_check(model::Optimizer)::Bool
    return MOI.get(model, PrimalFeasibilityCheck())
end

@doc raw"""
    AutoFeasibilityReport()

When enabled, `MOI.optimize!` computes a `ToQUBO.FeasibilityReport` over every
sampled result right after the solver returns, caches it for later
`ToQUBO.feasibility_report` calls, and emits a warning (subject to
[`Warnings`](@ref)) when any sampled result violates a source constraint.

Disabled by default.
"""
struct AutoFeasibilityReport <: CompilerAttribute end

_attribute_from_key(::Val{:auto_feasibility_report}) = AutoFeasibilityReport

function MOI.get(model::Optimizer, ::AutoFeasibilityReport)::Bool
    return get(model.compiler_settings, :auto_feasibility_report, false)
end

function MOI.set(model::Optimizer, ::AutoFeasibilityReport, flag::Bool)
    model.compiler_settings[:auto_feasibility_report] = flag

    return nothing
end

function MOI.set(model::Optimizer, ::AutoFeasibilityReport, ::Nothing)
    delete!(model.compiler_settings, :auto_feasibility_report)

    return nothing
end

function auto_feasibility_report(model::Optimizer)::Bool
    return MOI.get(model, AutoFeasibilityReport())
end

@doc raw"""
    SourceObjectiveValue(result_index::Integer = 1)

Value of the source-model objective function evaluated at the projected
source-variable values of sampled result `result_index`.

Unlike `MOI.ObjectiveValue`, which reports the target QUBO energy including
penalty terms introduced by the reformulation, this attribute is penalty-free:
it evaluates the original objective on the decoded solution.
"""
struct SourceObjectiveValue <: CompilerAttribute
    result_index::Int

    SourceObjectiveValue(result_index::Integer = 1) = new(result_index)
end

MOI.is_set_by_optimize(::SourceObjectiveValue) = true

@doc raw"""
    IgnoreFeasibleConstraints()

When set, constraints whose encoded residual is provably always feasible are
ignored instead of being added as penalty terms.
"""
struct IgnoreFeasibleConstraints <: CompilerAttribute end

_attribute_from_key(::Val{:ignore_feasible}) = IgnoreFeasibleConstraints

function MOI.get(model::Optimizer, ::IgnoreFeasibleConstraints)::Bool
    return get(model.compiler_settings, :ignore_feasible, true)
end

function MOI.set(model::Optimizer, ::IgnoreFeasibleConstraints, flag::Bool)
    model.compiler_settings[:ignore_feasible] = flag

    return nothing
end

function MOI.set(model::Optimizer, ::IgnoreFeasibleConstraints, ::Nothing)
    delete!(model.compiler_settings, :ignore_feasible)

    return nothing
end

function ignore_feasible_constraints(model::Optimizer)::Bool
    return MOI.get(model, IgnoreFeasibleConstraints())
end

@doc raw"""
    PenaltyPolicy()

Select the automatic penalty inference policy used when no explicit penalty
hint is set. The default is [`ObjectiveRangePenalty`](@ref), which uses a
certified objective-range exact-penalty bound when available and falls back to
[`LegacyPenalty`](@ref) otherwise.
"""
struct PenaltyPolicy <: CompilerAttribute end

_attribute_from_key(::Val{:penalty_policy}) = PenaltyPolicy

function MOI.get(model::Optimizer, ::PenaltyPolicy)::AutomaticPenaltyPolicy
    return get(model.compiler_settings, :penalty_policy, ObjectiveRangePenalty())
end

function MOI.set(model::Optimizer, ::PenaltyPolicy, policy::AutomaticPenaltyPolicy)
    model.compiler_settings[:penalty_policy] = policy

    return nothing
end

function MOI.set(model::Optimizer, ::PenaltyPolicy, ::Nothing)
    delete!(model.compiler_settings, :penalty_policy)

    return nothing
end

function penalty_policy(model::Optimizer)::AutomaticPenaltyPolicy
    return MOI.get(model, PenaltyPolicy())
end

@doc raw"""
    PenaltyPolicyMetadata()

Return diagnostic metadata for the automatic penalty policy used during the
last compilation.

The returned dictionary includes the selected automatic policy, objective
bounds, the legacy objective gap, fallback records, and `inferred_penalties`.
`inferred_penalties` is grouped under `"constraints"`, `"variables"`, and
`"slack_variables"`. Each entry records the source item kind and id, final
automatic coefficient, `epsilon`, `epsilon_source`, scale, offset, automatic
policy, selected policy, and any fallback reason.

Only automatically inferred coefficients are included in `inferred_penalties`.
Explicit penalty hints bypass automatic inference; use [`AppliedPenalty`](@ref)
or reformulation metadata's `applied_penalties` section when a complete list of
applied coefficients is needed.
"""
struct PenaltyPolicyMetadata <: CompilerAttribute end

MOI.is_set_by_optimize(::PenaltyPolicyMetadata) = true

function MOIU.map_indices(::Any, ::PenaltyPolicyMetadata, metadata::AbstractDict)
    return copy(metadata)
end

function MOIU.map_indices(::Any, ::PenaltyPolicyMetadata, ::Nothing)
    return nothing
end

function MOI.get(model::Optimizer, ::PenaltyPolicyMetadata)
    return get(model.compiler_settings, :penalty_policy_metadata, nothing)
end

function penalty_policy_metadata(model::Optimizer)
    return MOI.get(model, PenaltyPolicyMetadata())
end

@doc raw"""
    PenaltyOffset()

Set the global offset or margin used by automatic penalty inference.

Under [`ObjectiveRangePenalty`](@ref), this is the objective-range margin in
``scale * sigma * ((objective_range + beta) / epsilon)``. Under
[`LegacyPenalty`](@ref), this is the historical additive offset in
``scale * sigma * (delta / epsilon + beta)``. The default is `1.0`.
Use [`ConstraintPenaltyOffset`](@ref) to override this value for a specific
source constraint and its slack-variable encoding penalty.
"""
struct PenaltyOffset <: CompilerAttribute end

_attribute_from_key(::Val{:penalty_offset}) = PenaltyOffset

function MOI.get(model::Optimizer{T}, ::PenaltyOffset)::T where {T}
    return get(model.compiler_settings, :penalty_offset, one(T))
end

function MOI.set(model::Optimizer{T}, ::PenaltyOffset, β::Any) where {T}
    model.compiler_settings[:penalty_offset] = convert(T, β)

    return nothing
end

function MOI.set(model::Optimizer, ::PenaltyOffset, ::Nothing)
    delete!(model.compiler_settings, :penalty_offset)

    return nothing
end

function penalty_offset(model::Optimizer)
    return MOI.get(model, PenaltyOffset())
end

@doc raw"""
    PenaltyScale()

Set the global multiplier applied to automatically inferred penalty
coefficients.

When no explicit penalty hint is set, ToQUBO infers penalty coefficients from
[`PenaltyPolicy`](@ref). The default scale is `1.0`. Use
[`ConstraintPenaltyScale`](@ref) to override this value for a specific source
constraint and its slack-variable encoding penalty.
"""
struct PenaltyScale <: CompilerAttribute end

_attribute_from_key(::Val{:penalty_scale}) = PenaltyScale

function MOI.get(model::Optimizer{T}, ::PenaltyScale)::T where {T}
    return get(model.compiler_settings, :penalty_scale, one(T))
end

function MOI.set(model::Optimizer{T}, ::PenaltyScale, scale::Any) where {T}
    model.compiler_settings[:penalty_scale] = convert(T, scale)

    return nothing
end

function MOI.set(model::Optimizer, ::PenaltyScale, ::Nothing)
    delete!(model.compiler_settings, :penalty_scale)

    return nothing
end

function penalty_scale(model::Optimizer)
    return MOI.get(model, PenaltyScale())
end

@doc raw"""
    ErrorInfeasibleConstraints()

When set, direct scalar constraints whose encoded residual is provably
infeasible stop compilation with `MOI.INFEASIBLE`.

This does not make infeasible inner constraints of indicator constraints fail
the whole model, because those constraints are conditional on the indicator
activation.
"""
struct ErrorInfeasibleConstraints <: CompilerAttribute end

_attribute_from_key(::Val{:error_infeasible}) = ErrorInfeasibleConstraints

function MOI.get(model::Optimizer, ::ErrorInfeasibleConstraints)::Bool
    return get(model.compiler_settings, :error_infeasible, false)
end

function MOI.set(model::Optimizer, ::ErrorInfeasibleConstraints, flag::Bool)
    model.compiler_settings[:error_infeasible] = flag

    return nothing
end

function MOI.set(model::Optimizer, ::ErrorInfeasibleConstraints, ::Nothing)
    delete!(model.compiler_settings, :error_infeasible)

    return nothing
end

function error_infeasible_constraints(model::Optimizer)::Bool
    return MOI.get(model, ErrorInfeasibleConstraints())
end

@doc raw"""
    Optimization()
"""
struct Optimization <: CompilerAttribute end

_attribute_from_key(::Val{:optimization}) = Optimization

function MOI.get(model::Optimizer, ::Optimization)::Integer
    return get(model.compiler_settings, :optimization, 0)
end

function MOI.set(model::Optimizer, ::Optimization, level::Integer)
    @assert level >= 0

    model.compiler_settings[:optimization] = level

    return nothing
end

function MOI.set(model::Optimizer, ::Optimization, ::Nothing)
    delete!(model.compiler_settings, :optimization)

    return nothing
end

function optimization(model::Optimizer)::Integer
    return MOI.get(model, Optimization())
end

@doc raw"""
    Architecture()

Selects which solver architecture to use.
Defaults to `QUBOTools.GenericArchitecture`.
"""
struct Architecture <: CompilerAttribute end

_attribute_from_key(::Val{:architecture}) = Architecture

function MOI.get(model::Optimizer, ::Architecture)::QUBOTools.AbstractArchitecture
    return get(model.compiler_settings, :architecture, QUBOTools.GenericArchitecture())
end

function MOI.set(model::Optimizer, ::Architecture, arch::QUBOTools.AbstractArchitecture)
    model.compiler_settings[:architecture] = arch

    return nothing
end

function MOI.set(model::Optimizer, ::Architecture, ::Nothing)
    delete!(model.compiler_settings, :architecture)

    return nothing
end

function architecture(model::Optimizer)::QUBOTools.AbstractArchitecture
    return MOI.get(model, Architecture())
end

@doc raw"""
    Discretize()

When set, this boolean flag guarantees that every coefficient in the final formulation is an integer.
"""
struct Discretize <: CompilerAttribute end

_attribute_from_key(::Val{:discretize}) = Discretize

function MOI.get(model::Optimizer, ::Discretize)::Bool
    return get(model.compiler_settings, :discretize, true)
end

function MOI.set(model::Optimizer, ::Discretize, flag::Bool)
    model.compiler_settings[:discretize] = flag

    return nothing
end

function MOI.set(model::Optimizer, ::Discretize, ::Nothing)
    delete!(model.compiler_settings, :discretize)

    return nothing
end

function discretize(model::Optimizer)::Bool
    return MOI.get(model, Discretize())
end

@doc raw"""
    DefaultConstraintEncodingMethod()

Fallback method used to reformulate constraints.

Available options are:
- [`QuadraticPenalty`](@ref) (default)
- [`LinearPenalty`](@ref)
- [`UnbalancedPenalty`](@ref) (inequalities only)
"""
struct DefaultConstraintEncodingMethod <: CompilerAttribute end

_attribute_from_key(::Val{:default_constraint_encoding_method}) =
    DefaultConstraintEncodingMethod

function MOI.get(
    model::Optimizer,
    ::DefaultConstraintEncodingMethod,
)::ConstraintPenaltyMethod
    return get(
        model.compiler_settings,
        :default_constraint_encoding_method,
        QuadraticPenalty(),
    )
end

function MOI.set(
    model::Optimizer,
    ::DefaultConstraintEncodingMethod,
    method::ConstraintPenaltyMethod,
)
    model.compiler_settings[:default_constraint_encoding_method] = method

    return nothing
end

function MOI.set(model::Optimizer, ::DefaultConstraintEncodingMethod, ::Nothing)
    delete!(model.compiler_settings, :default_constraint_encoding_method)

    return nothing
end

function default_constraint_encoding_method(model::Optimizer)::ConstraintPenaltyMethod
    return MOI.get(model, DefaultConstraintEncodingMethod())
end

@doc raw"""
    Quadratize()

Boolean flag to conditionally perform the quadratization step.
Is automatically set by the compiler when high-order functions are generated.
"""
struct Quadratize <: CompilerAttribute end

_attribute_from_key(::Val{:quadratize}) = Quadratize

function MOI.get(model::Optimizer, ::Quadratize)::Bool
    return get(model.compiler_settings, :quadratize, false)
end

function MOI.set(model::Optimizer, ::Quadratize, flag::Bool)
    model.compiler_settings[:quadratize] = flag

    return nothing
end

function quadratize(model::Optimizer)::Bool
    return MOI.get(model, Quadratize())
end

@doc raw"""
    QuadratizationMethod()

Defines which quadratization method to use.
Available options are defined in the `PBO` submodule.
"""
struct QuadratizationMethod <: CompilerAttribute end

_attribute_from_key(::Val{:quadratization_method}) = QuadratizationMethod

function MOI.get(model::Optimizer, ::QuadratizationMethod)
    return get(model.compiler_settings, :quadratization_method, PBO.DEFAULT())
end

function MOI.set(model::Optimizer, ::QuadratizationMethod, method::PBO.QuadratizationMethod)
    model.compiler_settings[:quadratization_method] = method

    return nothing
end

function MOI.set(model::Optimizer, ::QuadratizationMethod, ::Nothing)
    delete!(model.compiler_settings, :quadratization_method)

    return nothing
end

function quadratization_method(model::Optimizer)
    return MOI.get(model, QuadratizationMethod())
end

@doc raw"""
    StableQuadratization()

When set, this boolean flag enables stable quadratization methods, thus yielding predictable results.
This is intended to be used during tests or other situations where deterministic output is desired.
On the other hand, usage in production is not recommended since it requires increased memory and processing resources.
"""
struct StableQuadratization <: CompilerAttribute end

_attribute_from_key(::Val{:stable_quadratization}) = StableQuadratization

function MOI.get(model::Optimizer, ::StableQuadratization)::Bool
    return get(model.compiler_settings, :stable_quadratization, false)
end

function MOI.set(model::Optimizer, ::StableQuadratization, flag::Bool)
    model.compiler_settings[:stable_quadratization] = flag

    return nothing
end

function MOI.set(model::Optimizer, ::StableQuadratization, ::Nothing)
    delete!(model.compiler_settings, :stable_quadratization)

    return nothing
end

function stable_quadratization(model::Optimizer)::Bool
    return stable_compilation(model) || MOI.get(model, StableQuadratization())
end

@doc raw"""
    StableCompilation()

When set, this boolean flag enables stable reformulation methods, thus yielding predictable results.
"""
struct StableCompilation <: CompilerAttribute end

_attribute_from_key(::Val{:stable_compilation}) = StableCompilation

function MOI.get(model::Optimizer, ::StableCompilation)::Bool
    return get(model.compiler_settings, :stable_compilation, false)
end

function MOI.set(model::Optimizer, ::StableCompilation, flag::Bool)
    model.compiler_settings[:stable_compilation] = flag

    return nothing
end

function MOI.set(model::Optimizer, ::StableCompilation, ::Nothing)
    delete!(model.compiler_settings, :stable_compilation)

    return nothing
end

function stable_compilation(model::Optimizer)::Bool
    return MOI.get(model, StableCompilation())
end

@doc raw"""
    DefaultVariableEncodingMethod()

Fallback value for [`VariableEncodingMethod`](@ref).
"""
struct DefaultVariableEncodingMethod <: CompilerAttribute end

_attribute_from_key(::Val{:default_variable_encoding_method}) = DefaultVariableEncodingMethod

function MOI.get(
    model::Optimizer,
    ::DefaultVariableEncodingMethod,
)::Encoding.VariableEncodingMethod
    return get(
        model.compiler_settings,
        :default_variable_encoding_method,
        Encoding.Binary(),
    )
end

function MOI.set(
    model::Optimizer,
    ::DefaultVariableEncodingMethod,
    e::Encoding.VariableEncodingMethod,
)
    model.compiler_settings[:default_variable_encoding_method] = e

    return nothing
end

function MOI.set(model::Optimizer, ::DefaultVariableEncodingMethod, ::Nothing)
    delete!(model.compiler_settings, :default_variable_encoding_method)

    return nothing
end

@doc raw"""
    DefaultVariableEncodingATol()

Fallback value for [`VariableEncodingATol`](@ref).

This tolerance is used to infer the number of target binary variables for a
bounded continuous variable when neither [`VariableEncodingBits`](@ref) nor
[`DefaultVariableEncodingBits`](@ref) supplies an explicit bit count. See
[Representation Error](@ref).
"""
struct DefaultVariableEncodingATol <: CompilerAttribute end

_attribute_from_key(::Val{:default_variable_encoding_atol}) = DefaultVariableEncodingATol

function MOI.get(model::Optimizer{T}, ::DefaultVariableEncodingATol)::T where {T}
    return get(model.compiler_settings, :default_variable_encoding_atol, T(1 / 4))
end

function MOI.set(model::Optimizer{T}, ::DefaultVariableEncodingATol, τ::T) where {T}
    model.compiler_settings[:default_variable_encoding_atol] = τ

    return nothing
end

function MOI.set(model::Optimizer, ::DefaultVariableEncodingATol, ::Nothing)
    delete!(model.compiler_settings, :default_variable_encoding_atol)

    return nothing
end

@doc raw"""
    DefaultVariableEncodingBits()

Fallback value for [`VariableEncodingBits`](@ref). When set, this fixes the
number of target binary variables used for bounded continuous variables that do
not have their own [`VariableEncodingBits`](@ref) value.
"""
struct DefaultVariableEncodingBits <: CompilerAttribute end

_attribute_from_key(::Val{:default_variable_encoding_bits}) = DefaultVariableEncodingBits

function MOI.get(model::Optimizer, ::DefaultVariableEncodingBits)::Union{Integer,Nothing}
    return get(model.compiler_settings, :default_variable_encoding_bits, nothing)
end

function MOI.set(model::Optimizer, ::DefaultVariableEncodingBits, n::Integer)
    model.compiler_settings[:default_variable_encoding_bits] = n

    return nothing
end

function MOI.set(model::Optimizer, ::DefaultVariableEncodingBits, ::Nothing)
    delete!(model.compiler_settings, :default_variable_encoding_bits)

    return nothing
end


abstract type CompilerVariableAttribute <: MOI.AbstractVariableAttribute end

MOI.supports(::Optimizer, ::A, ::Type{VI}) where {A<:CompilerVariableAttribute} = true

@doc raw"""
    VariableTargetVariables()

Return the target QUBO variables generated for a source variable.
"""
struct VariableTargetVariables <: CompilerVariableAttribute end

MOI.is_set_by_optimize(::VariableTargetVariables) = true

function MOI.get(
    model::Optimizer,
    ::VariableTargetVariables,
    vi::VI,
)::Union{Vector{VI},Nothing}
    if haskey(model.source, vi)
        return copy(Virtual.target(model.source[vi]))
    else
        return nothing
    end
end

function variable_target_variables(model::Optimizer, vi::VI)
    return MOI.get(model, VariableTargetVariables(), vi)
end

@doc raw"""
    VariableEncodingFunction()

Return the pseudo-boolean expansion used to represent a source variable in
terms of target QUBO variables.
"""
struct VariableEncodingFunction <: CompilerVariableAttribute end

MOI.is_set_by_optimize(::VariableEncodingFunction) = true

function MOI.get(
    model::Optimizer{T},
    ::VariableEncodingFunction,
    vi::VI,
)::Union{PBO.PBF{VI,T},Nothing} where {T}
    if haskey(model.source, vi)
        return copy(Virtual.expansion(model.source[vi]))
    else
        return nothing
    end
end

function variable_encoding_function(model::Optimizer, vi::VI)
    return MOI.get(model, VariableEncodingFunction(), vi)
end

@doc raw"""
    VariableEncodingPenaltyFunction()

Return the pseudo-boolean penalty function generated by a variable encoding,
if that encoding requires one.
"""
struct VariableEncodingPenaltyFunction <: CompilerVariableAttribute end

MOI.is_set_by_optimize(::VariableEncodingPenaltyFunction) = true

function MOI.get(
    model::Optimizer{T},
    ::VariableEncodingPenaltyFunction,
    vi::VI,
)::Union{PBO.PBF{VI,T},Nothing} where {T}
    return _copy_or_nothing(get(model.h, vi, nothing))
end

function variable_encoding_penalty_function(model::Optimizer, vi::VI)
    return MOI.get(model, VariableEncodingPenaltyFunction(), vi)
end

@doc raw"""
    VariableEncodingATol()

Set the tolerance used to infer the number of target binary variables for a
bounded continuous variable when [`VariableEncodingBits`](@ref) is unset. The
compiler falls back to [`DefaultVariableEncodingATol`](@ref) when this attribute
is unset. See [Representation Error](@ref).
"""
struct VariableEncodingATol <: CompilerVariableAttribute end

_attribute_from_key(::Val{:variable_encoding_atol}) = VariableEncodingATol

function MOI.get(
    model::Optimizer{T},
    ::VariableEncodingATol,
    vi::VI,
)::Union{T,Nothing} where {T}
    attr = :variable_encoding_atol

    if haskey(model.variable_settings, attr)
        return get(model.variable_settings[attr], vi, nothing)
    else
        return nothing
    end
end

function MOI.set(model::Optimizer{T}, ::VariableEncodingATol, vi::VI, τ::T) where {T}
    attr = :variable_encoding_atol

    if !haskey(model.variable_settings, attr)
        model.variable_settings[attr] = Dict{VI,Any}()
    end

    model.variable_settings[attr][vi] = τ

    return nothing
end

function MOI.set(model::Optimizer, ::VariableEncodingATol, vi::VI, ::Nothing)
    attr = :variable_encoding_atol

    if haskey(model.variable_settings, attr)
        delete!(model.variable_settings[attr], vi)
    end

    return nothing
end

function variable_encoding_atol(model::Optimizer{T}, vi::VI)::T where {T}
    τ = MOI.get(model, VariableEncodingATol(), vi)

    if τ === nothing
        return MOI.get(model, DefaultVariableEncodingATol())
    else
        return τ
    end
end

@doc raw"""
    VariableEncodingBits()

Set the number of target binary variables used to encode a bounded continuous
variable. This explicit bit count takes precedence over
[`VariableEncodingATol`](@ref).
"""
struct VariableEncodingBits <: CompilerVariableAttribute end

_attribute_from_key(::Val{:variable_encoding_bits}) = VariableEncodingBits

function MOI.get(model::Optimizer, ::VariableEncodingBits, vi::VI)::Union{Integer,Nothing}
    attr = :variable_encoding_bits

    if haskey(model.variable_settings, attr)
        return get(model.variable_settings[attr], vi, nothing)
    else
        return MOI.get(model, DefaultVariableEncodingBits())
    end
end

function MOI.set(model::Optimizer, ::VariableEncodingBits, vi::VI, n::Integer)
    attr = :variable_encoding_bits

    if !haskey(model.variable_settings, attr)
        model.variable_settings[attr] = Dict{VI,Any}()
    end

    model.variable_settings[attr][vi] = n

    return nothing
end

function MOI.set(model::Optimizer, ::VariableEncodingBits, vi::VI, ::Nothing)
    attr = :variable_encoding_bits

    if haskey(model.variable_settings, attr)
        delete!(model.variable_settings[attr], vi)
    end

    return nothing
end

function variable_encoding_bits(model::Optimizer, vi::VI)::Union{Integer,Nothing}
    n = MOI.get(model, VariableEncodingBits(), vi)

    if isnothing(n)
        return MOI.get(model, DefaultVariableEncodingBits())
    else
        return n
    end
end

@doc raw"""
    VariableEncodingSet()

Explicit finite value set for a variable, e.g. `[-1.0, 1.0, 3.0]` or a
non-uniformly spaced grid such as `[0.1, 1.0, 10.0, 100.0]`. The variable is
encoded over the set instead of the bounds-derived domain: every
encoding-feasible target state decodes to a set member, while samples that
violate the set encoding's penalty can decode outside the set — inspect
sample feasibility or the penalty value when consuming raw sample sets.

Requires the variable's [`VariableEncodingMethod`](@ref) to be a set encoding
(`Encoding.OneHot` or `Encoding.DomainWall`); interval encodings such as
`Encoding.Binary`, `Encoding.Unary`, `Encoding.Arithmetic`, and
`Encoding.Bounded` reject value sets at compile time. Integer variables
require integer-valued entries, and every entry must respect the variable's
explicit bounds when such bounds are present. Bounds are otherwise optional:
the set itself defines the domain.

```julia
set_attribute(x, ToQUBO.Attributes.VariableEncodingMethod(), ToQUBO.Encoding.OneHot())
set_attribute(x, ToQUBO.Attributes.VariableEncodingSet(), [-1.0, 1.0, 3.0])
```
"""
struct VariableEncodingSet <: CompilerVariableAttribute end

_attribute_from_key(::Val{:variable_encoding_set}) = VariableEncodingSet

function MOI.get(
    model::Optimizer{T},
    ::VariableEncodingSet,
    vi::VI,
)::Union{Vector{T},Nothing} where {T}
    attr = :variable_encoding_set

    if haskey(model.variable_settings, attr)
        return get(model.variable_settings[attr], vi, nothing)
    else
        return nothing
    end
end

function MOI.set(
    model::Optimizer{T},
    ::VariableEncodingSet,
    vi::VI,
    γ::AbstractVector,
) where {T}
    attr = :variable_encoding_set

    if !haskey(model.variable_settings, attr)
        model.variable_settings[attr] = Dict{VI,Any}()
    end

    model.variable_settings[attr][vi] = Vector{T}(γ)

    return nothing
end

function MOI.set(model::Optimizer, ::VariableEncodingSet, vi::VI, ::Nothing)
    attr = :variable_encoding_set

    if haskey(model.variable_settings, attr)
        delete!(model.variable_settings[attr], vi)
    end

    return nothing
end

function variable_encoding_set(model::Optimizer{T}, vi::VI)::Union{Vector{T},Nothing} where {T}
    return MOI.get(model, VariableEncodingSet(), vi)
end

@doc raw"""
    VariableEncodingMethod()

Available methods are:
- [`Encoding.Binary`](@ref) (default)
- [`Encoding.Unary`](@ref)
- [`Encoding.Arithmetic`](@ref)
- [`Encoding.OneHot`](@ref)
- [`Encoding.DomainWall`](@ref)
- [`Encoding.Bounded`](@ref)

The [`Encoding.Binary`](@ref), [`Encoding.Unary`](@ref) and [`Encoding.Arithmetic`](@ref)
encodings can have their expansion coefficients bounded by wrapping them with the
[`Encoding.Bounded`](@ref) method.
"""
struct VariableEncodingMethod <: CompilerVariableAttribute end

_attribute_from_key(::Val{:variable_encoding_method}) = VariableEncodingMethod

function variable_encoding_method(model::Optimizer, vi::VI)::Encoding.VariableEncodingMethod
    e = MOI.get(model, VariableEncodingMethod(), vi)

    if isnothing(e)
        return MOI.get(model, DefaultVariableEncodingMethod())
    else
        return e
    end
end

function MOI.get(
    model::Optimizer,
    ::VariableEncodingMethod,
    vi::VI,
)::Union{Encoding.VariableEncodingMethod,Nothing}
    attr = :variable_encoding_method

    if !haskey(model.variable_settings, attr) || !haskey(model.variable_settings[attr], vi)
        return nothing
    else
        return model.variable_settings[attr][vi]
    end
end

function MOI.set(
    model::Optimizer,
    ::VariableEncodingMethod,
    vi::VI,
    e::Encoding.VariableEncodingMethod,
)
    attr = :variable_encoding_method

    if !haskey(model.variable_settings, attr)
        model.variable_settings[attr] = Dict{VI,Any}()
    end

    model.variable_settings[attr][vi] = e

    return nothing
end

function MOI.set(model::Optimizer, ::Attributes.VariableEncodingMethod, vi::VI, ::Nothing)
    attr = :variable_encoding_method

    if haskey(model.variable_settings, attr)
        delete!(model.variable_settings[attr], vi)
    end

    return nothing
end

@doc raw"""
    VariableEncodingPenaltyHint()

Set a fixed penalty coefficient for a variable encoding that generates a
penalty function.

When unset, ToQUBO infers the coefficient from [`PenaltyPolicy`](@ref),
[`PenaltyScale`](@ref), [`PenaltyOffset`](@ref), and the generated penalty
function gap. The hint is used as-is and bypasses automatic inference.
"""
struct VariableEncodingPenaltyHint <: CompilerVariableAttribute end

_attribute_from_key(::Val{:variable_encoding_penalty_hint}) = VariableEncodingPenaltyHint

function variable_encoding_penalty_hint(model::Optimizer, vi::VI)
    return MOI.get(model, VariableEncodingPenaltyHint(), vi)
end

function MOI.get(model::Optimizer{T}, ::VariableEncodingPenaltyHint, vi::VI) where {T}
    attr = :variable_encoding_penalty_hint

    if !haskey(model.variable_settings, attr) || !haskey(model.variable_settings[attr], vi)
        return nothing
    else
        return model.variable_settings[attr][vi]::T
    end
end

function MOI.set(model::Optimizer{T}, ::VariableEncodingPenaltyHint, vi::VI, ρ) where {T}
    attr = :variable_encoding_penalty_hint

    if !haskey(model.variable_settings, attr)
        model.variable_settings[attr] = Dict{VI,Any}()
    end

    model.variable_settings[attr][vi] = convert(T, ρ)

    return nothing
end

function MOI.set(
    model::Optimizer{T},
    ::VariableEncodingPenaltyHint,
    vi::VI,
    ::Nothing,
) where {T}
    attr = :variable_encoding_penalty_hint

    if haskey(model.variable_settings, attr)
        delete!(model.variable_settings[attr], vi)
    end

    return nothing
end

@doc raw"""
    VariableEncodingPenalty()

Return the applied variable-encoding penalty coefficient after compilation.

This returns `nothing` when the variable encoding does not generate a penalty
function. Use [`VariableEncodingPenaltyHint`](@ref) before compilation to pin a
specific coefficient.
"""
struct VariableEncodingPenalty <: CompilerVariableAttribute end

MOI.is_set_by_optimize(::VariableEncodingPenalty) = true

function variable_encoding_penalty(model::Optimizer, vi::VI)
    return MOI.get(model, VariableEncodingPenalty(), vi)
end

function MOI.get(model::Optimizer{T}, ::VariableEncodingPenalty, vi::VI) where {T}
    return get(model.θ, vi, nothing)
end

function MOI.set(model::Optimizer{T}, ::VariableEncodingPenalty, vi::VI, θ) where {T}
    model.θ[vi] = convert(T, θ)

    return nothing
end

function MOI.set(
    model::Optimizer{T},
    ::VariableEncodingPenalty,
    vi::VI,
    ::Nothing,
) where {T}
    delete!(model.θ, vi)

    return nothing
end

abstract type CompilerConstraintAttribute <: MOI.AbstractConstraintAttribute end

MOI.supports(::Optimizer, ::A, ::Type{<:CI}) where {A<:CompilerConstraintAttribute} = true

@doc raw"""
    ConstraintEncodingFunction()

Return the pseudo-boolean penalty function generated for a source constraint,
before multiplying by its penalty coefficient.
"""
struct ConstraintEncodingFunction <: CompilerConstraintAttribute end

MOI.is_set_by_optimize(::ConstraintEncodingFunction) = true

function constraint_encoding_function(model::Optimizer, ci::CI)
    return MOI.get(model, ConstraintEncodingFunction(), ci)
end

function MOI.get(
    model::Optimizer{T},
    ::ConstraintEncodingFunction,
    ci::CI,
)::Union{PBO.PBF{VI,T},Nothing} where {T}
    return _copy_or_nothing(get(model.g, ci, nothing))
end

@doc raw"""
    ConstraintEncodingPenaltyHint()

Set a fixed penalty coefficient for a source constraint.

When unset, ToQUBO infers the coefficient from the automatic penalty policy,
unless the constraint uses [`LinearPenalty`](@ref) for an equality or
[`UnbalancedPenalty`](@ref) for an inequality. These heuristic methods require
an explicit hint because their sign and magnitude control whether the residual
discourages infeasible assignments.
"""
struct ConstraintEncodingPenaltyHint <: CompilerConstraintAttribute end

_attribute_from_key(::Val{:constraint_encoding_penalty_hint}) = ConstraintEncodingPenaltyHint

function constraint_encoding_penalty_hint(model::Optimizer, ci::CI)
    return MOI.get(model, ConstraintEncodingPenaltyHint(), ci)
end

function MOI.get(model::Optimizer{T}, ::ConstraintEncodingPenaltyHint, ci::CI) where {T}
    attr = :constraint_encoding_penalty_hint

    if !haskey(model.constraint_settings, attr) ||
       !haskey(model.constraint_settings[attr], ci)
        return nothing
    else
        return model.constraint_settings[attr][ci]::T
    end
end

function MOI.set(
    model::Optimizer{T},
    ::ConstraintEncodingPenaltyHint,
    ci::CI,
    ρ::Any,
) where {T}
    attr = :constraint_encoding_penalty_hint

    if !haskey(model.constraint_settings, attr)
        model.constraint_settings[attr] = Dict{CI,Any}()
    end

    model.constraint_settings[attr][ci] = convert(T, ρ)

    return nothing
end

function MOI.set(
    model::Optimizer{T},
    ::ConstraintEncodingPenaltyHint,
    ci::CI,
    ::Nothing,
) where {T}
    attr = :constraint_encoding_penalty_hint

    if haskey(model.constraint_settings, attr)
        delete!(model.constraint_settings[attr], ci)
    end

    return nothing
end

@doc raw"""
    ConstraintEncodingPenalty()

Return the applied source-constraint penalty coefficient after compilation.

Use [`ConstraintEncodingPenaltyHint`](@ref) before compilation to pin a
specific coefficient, or [`ConstraintPenaltyScale`](@ref) and
[`ConstraintPenaltyOffset`](@ref) to tune automatic inference for one
source constraint.
"""
struct ConstraintEncodingPenalty <: CompilerConstraintAttribute end

MOI.is_set_by_optimize(::ConstraintEncodingPenalty) = true

function constraint_encoding_penalty(model::Optimizer, ci::CI)
    return MOI.get(model, ConstraintEncodingPenalty(), ci)
end

function MOI.get(model::Optimizer{T}, ::ConstraintEncodingPenalty, ci::CI) where {T}
    return get(model.ρ, ci, nothing)
end

function MOI.set(model::Optimizer{T}, ::ConstraintEncodingPenalty, ci::CI, ρ::T) where {T}
    model.ρ[ci] = ρ

    return nothing
end

function MOI.set(
    model::Optimizer{T},
    ::ConstraintEncodingPenalty,
    ci::CI,
    ::Nothing,
) where {T}
    delete!(model.ρ, ci)

    return nothing
end

@doc raw"""
    AppliedPenalty()

Return the applied source-constraint penalty coefficient after compilation.

This is an alias for [`ConstraintEncodingPenalty`](@ref) intended for reporting
code that wants a generic "applied penalty" query.
"""
struct AppliedPenalty <: CompilerConstraintAttribute end

MOI.is_set_by_optimize(::AppliedPenalty) = true

function applied_penalty(model::Optimizer, ci::CI)
    return MOI.get(model, AppliedPenalty(), ci)
end

function MOI.get(model::Optimizer, ::AppliedPenalty, ci::CI)
    return MOI.get(model, ConstraintEncodingPenalty(), ci)
end

@doc raw"""
    ConstraintPenaltyOffset()

Override [`PenaltyOffset`](@ref) for a specific source constraint.

The override applies to automatically inferred source-constraint penalties and
to the slack-variable encoding penalty generated for the same source
constraint. Explicit penalty hints still take precedence.
"""
struct ConstraintPenaltyOffset <: CompilerConstraintAttribute end

_attribute_from_key(::Val{:constraint_penalty_offset}) = ConstraintPenaltyOffset

function MOI.get(model::Optimizer{T}, ::ConstraintPenaltyOffset, ci::CI) where {T}
    attr = :constraint_penalty_offset

    if !haskey(model.constraint_settings, attr) ||
       !haskey(model.constraint_settings[attr], ci)
        return nothing
    else
        return model.constraint_settings[attr][ci]::T
    end
end

function MOI.set(model::Optimizer{T}, ::ConstraintPenaltyOffset, ci::CI, β) where {T}
    attr = :constraint_penalty_offset

    if !haskey(model.constraint_settings, attr)
        model.constraint_settings[attr] = Dict{CI,Any}()
    end

    model.constraint_settings[attr][ci] = convert(T, β)

    return nothing
end

function MOI.set(model::Optimizer, ::ConstraintPenaltyOffset, ci::CI, ::Nothing)
    attr = :constraint_penalty_offset

    if haskey(model.constraint_settings, attr)
        delete!(model.constraint_settings[attr], ci)
    end

    return nothing
end

function constraint_penalty_offset(model::Optimizer, ci::CI)
    β = MOI.get(model, ConstraintPenaltyOffset(), ci)

    if isnothing(β)
        return MOI.get(model, PenaltyOffset())
    else
        return β
    end
end

@doc raw"""
    ConstraintPenaltyScale()

Override [`PenaltyScale`](@ref) for a specific source constraint.

The override applies to automatically inferred source-constraint penalties and
to the slack-variable encoding penalty generated for the same source
constraint. Explicit penalty hints still take precedence.
"""
struct ConstraintPenaltyScale <: CompilerConstraintAttribute end

_attribute_from_key(::Val{:constraint_penalty_scale}) = ConstraintPenaltyScale

function MOI.get(model::Optimizer{T}, ::ConstraintPenaltyScale, ci::CI) where {T}
    attr = :constraint_penalty_scale

    if !haskey(model.constraint_settings, attr) ||
       !haskey(model.constraint_settings[attr], ci)
        return nothing
    else
        return model.constraint_settings[attr][ci]::T
    end
end

function MOI.set(model::Optimizer{T}, ::ConstraintPenaltyScale, ci::CI, scale) where {T}
    attr = :constraint_penalty_scale

    if !haskey(model.constraint_settings, attr)
        model.constraint_settings[attr] = Dict{CI,Any}()
    end

    model.constraint_settings[attr][ci] = convert(T, scale)

    return nothing
end

function MOI.set(model::Optimizer, ::ConstraintPenaltyScale, ci::CI, ::Nothing)
    attr = :constraint_penalty_scale

    if haskey(model.constraint_settings, attr)
        delete!(model.constraint_settings[attr], ci)
    end

    return nothing
end

function constraint_penalty_scale(model::Optimizer, ci::CI)
    scale = MOI.get(model, ConstraintPenaltyScale(), ci)

    if isnothing(scale)
        return MOI.get(model, PenaltyScale())
    else
        return scale
    end
end

@doc raw"""
    ConstraintEncodingMethod()

Sets the method used to reformulate a constraint.

When unset, this falls back to [`DefaultConstraintEncodingMethod`](@ref).
When set to [`LinearPenalty`](@ref), the constraint must also have an explicit
[`ConstraintEncodingPenaltyHint`](@ref). Inequalities use the existing
quadratic slack formulation unless set to [`UnbalancedPenalty`](@ref), which
also requires an explicit hint. `UnbalancedPenalty` is not supported for
equality constraints.
"""
struct ConstraintEncodingMethod <: CompilerConstraintAttribute end

_attribute_from_key(::Val{:constraint_encoding_method}) = ConstraintEncodingMethod

function constraint_encoding_method(model::Optimizer, ci::CI)::ConstraintPenaltyMethod
    method = MOI.get(model, ConstraintEncodingMethod(), ci)

    if isnothing(method)
        return MOI.get(model, DefaultConstraintEncodingMethod())
    else
        return method
    end
end

function MOI.get(
    model::Optimizer,
    ::ConstraintEncodingMethod,
    ci::CI,
)::Union{ConstraintPenaltyMethod,Nothing}
    attr = :constraint_encoding_method

    if !haskey(model.constraint_settings, attr) ||
       !haskey(model.constraint_settings[attr], ci)
        return nothing
    else
        return model.constraint_settings[attr][ci]
    end
end

function MOI.set(
    model::Optimizer,
    ::ConstraintEncodingMethod,
    ci::CI,
    method::ConstraintPenaltyMethod,
)
    attr = :constraint_encoding_method

    if !haskey(model.constraint_settings, attr)
        model.constraint_settings[attr] = Dict{CI,Any}()
    end

    model.constraint_settings[attr][ci] = method

    return nothing
end

function MOI.set(
    model::Optimizer,
    ::ConstraintEncodingMethod,
    ci::CI,
    ::Nothing,
)
    attr = :constraint_encoding_method

    if haskey(model.constraint_settings, attr)
        delete!(model.constraint_settings[attr], ci)
    end

    return nothing
end

@doc raw"""
    SlackVariableEncodingMethod()

Sets the encoding method for slack variables generated by constraints.
"""
struct SlackVariableEncodingMethod <: CompilerConstraintAttribute end

_attribute_from_key(::Val{:slack_variable_encoding_method}) = SlackVariableEncodingMethod

@doc raw"""
    SlackVariableTargetVariables()

Return the target QUBO variables generated for a constraint slack variable.
"""
struct SlackVariableTargetVariables <: CompilerConstraintAttribute end

MOI.is_set_by_optimize(::SlackVariableTargetVariables) = true

function MOI.get(
    model::Optimizer,
    ::SlackVariableTargetVariables,
    ci::CI,
)::Union{Vector{VI},Nothing}
    if haskey(model.slack, ci)
        return copy(Virtual.target(model.slack[ci]))
    else
        return nothing
    end
end

function slack_variable_target_variables(model::Optimizer, ci::CI)
    return MOI.get(model, SlackVariableTargetVariables(), ci)
end

@doc raw"""
    SlackVariableEncodingFunction()

Return the pseudo-boolean expansion used to represent a constraint slack
variable in terms of target QUBO variables.
"""
struct SlackVariableEncodingFunction <: CompilerConstraintAttribute end

MOI.is_set_by_optimize(::SlackVariableEncodingFunction) = true

function MOI.get(
    model::Optimizer{T},
    ::SlackVariableEncodingFunction,
    ci::CI,
)::Union{PBO.PBF{VI,T},Nothing} where {T}
    if haskey(model.slack, ci)
        return copy(Virtual.expansion(model.slack[ci]))
    else
        return nothing
    end
end

function slack_variable_encoding_function(model::Optimizer, ci::CI)
    return MOI.get(model, SlackVariableEncodingFunction(), ci)
end

@doc raw"""
    SlackVariableEncodingPenaltyFunction()

Return the pseudo-boolean penalty function generated by a slack-variable
encoding, if that encoding requires one.
"""
struct SlackVariableEncodingPenaltyFunction <: CompilerConstraintAttribute end

MOI.is_set_by_optimize(::SlackVariableEncodingPenaltyFunction) = true

function MOI.get(
    model::Optimizer{T},
    ::SlackVariableEncodingPenaltyFunction,
    ci::CI,
)::Union{PBO.PBF{VI,T},Nothing} where {T}
    return _copy_or_nothing(get(model.s, ci, nothing))
end

function slack_variable_encoding_penalty_function(model::Optimizer, ci::CI)
    return MOI.get(model, SlackVariableEncodingPenaltyFunction(), ci)
end

function slack_variable_encoding_method(model::Optimizer, ci::CI)::Encoding.VariableEncodingMethod
    e = MOI.get(model, SlackVariableEncodingMethod(), ci)

    if isnothing(e)
        return MOI.get(model, DefaultVariableEncodingMethod())
    else
        return e
    end
end

function MOI.get(
    model::Optimizer,
    ::SlackVariableEncodingMethod,
    ci::CI,
)::Union{Encoding.VariableEncodingMethod,Nothing}
    attr = :slack_variable_encoding_method

    if !haskey(model.constraint_settings, attr) ||
       !haskey(model.constraint_settings[attr], ci)
        return nothing
    else
        return model.constraint_settings[attr][ci]
    end
end

function MOI.set(
    model::Optimizer,
    ::SlackVariableEncodingMethod,
    ci::CI,
    e::Encoding.VariableEncodingMethod,
)
    attr = :slack_variable_encoding_method

    if !haskey(model.constraint_settings, attr)
        model.constraint_settings[attr] = Dict{CI,Any}()
    end

    model.constraint_settings[attr][ci] = e

    return nothing
end

function MOI.set(
    model::Optimizer,
    ::SlackVariableEncodingMethod,
    ci::CI,
    ::Nothing,
)
    attr = :slack_variable_encoding_method

    if haskey(model.constraint_settings, attr)
        delete!(model.constraint_settings[attr], ci)
    end

    return nothing
end

@doc raw"""
    SlackVariableEncodingATol()

Sets the tolerance for slack variables generated by constraints.
"""
struct SlackVariableEncodingATol <: CompilerConstraintAttribute end

_attribute_from_key(::Val{:slack_variable_encoding_atol}) = SlackVariableEncodingATol

function slack_variable_encoding_atol(model::Optimizer, ci::CI)
    return MOI.get(model, SlackVariableEncodingATol(), ci)
end

function MOI.get(
    model::Optimizer{T},
    ::SlackVariableEncodingATol,
    ci::CI,
)::Union{T,Nothing} where {T}
    attr = :slack_variable_encoding_atol

    if !haskey(model.constraint_settings, attr) ||
       !haskey(model.constraint_settings[attr], ci)
        return nothing
    else
        return model.constraint_settings[attr][ci]::T
    end
end

function MOI.set(
    model::Optimizer{T},
    ::SlackVariableEncodingATol,
    ci::CI,
    τ::T,
)::Nothing where {T}
    attr = :slack_variable_encoding_atol

    if !haskey(model.constraint_settings, attr)
        model.constraint_settings[attr] = Dict{CI,Any}()
    end

    model.constraint_settings[attr][ci] = τ

    return nothing
end

function MOI.set(
    model::Optimizer,
    ::SlackVariableEncodingATol,
    ci::CI,
    ::Nothing,
)
    attr = :slack_variable_encoding_atol

    if haskey(model.constraint_settings, attr)
        delete!(model.constraint_settings[attr], ci)
    end

    return nothing
end

@doc raw"""
    SlackVariableEncodingBits()

Sets the number of bits for slack variables generated by constraints.
"""
struct SlackVariableEncodingBits <: CompilerConstraintAttribute end

_attribute_from_key(::Val{:slack_variable_encoding_bits}) = SlackVariableEncodingBits

function slack_variable_encoding_bits(model::Optimizer, ci::CI)
    return MOI.get(model, SlackVariableEncodingBits(), ci)
end

function MOI.get(
    model::Optimizer,
    ::SlackVariableEncodingBits,
    ci::CI,
)::Union{Integer,Nothing}
    attr = :slack_variable_encoding_bits

    if !haskey(model.constraint_settings, attr) ||
       !haskey(model.constraint_settings[attr], ci)
        return nothing
    else
        return model.constraint_settings[attr][ci]
    end
end

function MOI.set(
    model::Optimizer,
    ::SlackVariableEncodingBits,
    ci::CI,
    n::Integer,
)::Nothing
    attr = :slack_variable_encoding_bits

    if !haskey(model.constraint_settings, attr)
        model.constraint_settings[attr] = Dict{CI,Any}()
    end

    model.constraint_settings[attr][ci] = n

    return nothing
end

function MOI.set(
    model::Optimizer,
    ::SlackVariableEncodingBits,
    ci::CI,
    ::Nothing,
)
    attr = :slack_variable_encoding_bits

    if haskey(model.constraint_settings, attr)
        delete!(model.constraint_settings[attr], ci)
    end

    return nothing
end

@doc raw"""
    SlackVariableEncodingPenaltyHint()

Set a fixed penalty coefficient for a slack-variable encoding generated by a
source constraint.

When unset, ToQUBO infers the coefficient from the automatic penalty policy.
[`ConstraintPenaltyScale`](@ref) and [`ConstraintPenaltyOffset`](@ref) apply to
the source constraint and to its generated slack-variable encoding penalty.
"""
struct SlackVariableEncodingPenaltyHint <: CompilerConstraintAttribute end

_attribute_from_key(::Val{:slack_variable_encoding_penalty_hint}) = SlackVariableEncodingPenaltyHint

function slack_variable_encoding_penalty_hint(model::Optimizer, ci::CI)
    return MOI.get(model, SlackVariableEncodingPenaltyHint(), ci)
end

function MOI.get(
    model::Optimizer{T},
    ::SlackVariableEncodingPenaltyHint,
    ci::CI,
)::Union{T,Nothing} where {T}
    attr = :slack_variable_encoding_penalty_hint

    if !haskey(model.constraint_settings, attr) ||
       !haskey(model.constraint_settings[attr], ci)
        return nothing
    else
        return model.constraint_settings[attr][ci]::T
    end
end

function MOI.set(
    model::Optimizer{T},
    ::SlackVariableEncodingPenaltyHint,
    ci::CI,
    ρ::T,
)::Nothing where {T}
    attr = :slack_variable_encoding_penalty_hint

    if !haskey(model.constraint_settings, attr)
        model.constraint_settings[attr] = Dict{CI,Any}()
    end

    model.constraint_settings[attr][ci] = ρ

    return nothing
end

function MOI.set(
    model::Optimizer,
    ::SlackVariableEncodingPenaltyHint,
    ci::CI,
    ::Nothing,
)
    attr = :slack_variable_encoding_penalty_hint

    if haskey(model.constraint_settings, attr)
        delete!(model.constraint_settings[attr], ci)
    end

    return nothing
end

@doc raw"""
    SlackVariableEncodingPenalty()

Return the applied slack-variable encoding penalty coefficient after
compilation.

This returns `nothing` when the constraint does not generate a slack-variable
encoding penalty. Use [`SlackVariableEncodingPenaltyHint`](@ref) before
compilation to pin a specific coefficient.

Slack variables are generated from source constraints, so the applied penalty is
owned by the source constraint index rather than by any generated target
variable.
"""
struct SlackVariableEncodingPenalty <: CompilerConstraintAttribute end

MOI.is_set_by_optimize(::SlackVariableEncodingPenalty) = true

function slack_variable_encoding_penalty(model::Optimizer, ci::CI)
    return MOI.get(model, SlackVariableEncodingPenalty(), ci)
end

function MOI.get(
    model::Optimizer{T},
    ::SlackVariableEncodingPenalty,
    ci::CI,
)::Union{T,Nothing} where {T}
    return get(model.η, ci, nothing)
end

function MOI.set(
    model::Optimizer{T},
    ::SlackVariableEncodingPenalty,
    ci::CI,
    η::Any,
)::Nothing where {T}
    model.η[ci] = convert(T, η)

    return nothing
end

function MOI.set(
    model::Optimizer{T},
    ::SlackVariableEncodingPenalty,
    ci::CI,
    ::Nothing,
)::Nothing where {T}
    delete!(model.η, ci)

    return nothing
end

end # module Attributes
