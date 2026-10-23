module Attributes

import MathOptInterface as MOI
const MOIU = MOI.Utilities
const MOIB = MOI.Bridges
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

@doc raw"""
    AugmentedLagrangianPenalty(multiplier::Real = 0.0, rho::Real = 1.0)

Composite penalty ``\lambda \ell + \rho \ell^2`` over the constraint residual
``\ell``, the augmented-Lagrangian (method-of-multipliers) shape. Supports
equality and inequality constraints; inequalities are handled slack-free with
the linear term oriented against the infeasible direction, i.e. *iterated
unbalanced penalization* (the exact one-sided Rockafellar term is not
expressible in a QUBO without slacks). `multiplier` (``\lambda``) may take any
finite value — it is the dual estimate the subgradient refinement strategy
updates, starting from zero — while `rho` (``\rho``) must be finite and
strictly positive.

Unlike [`UnbalancedPenalty`](@ref), constraints using this method need no
[`ConstraintEncodingPenaltyHint`](@ref): the compiler applies the
sense sign directly and the coefficients live in the method itself.

Both coefficients are converted to the model's coefficient type when the
penalty is built, so a method built from wider numbers (for example
`BigFloat`) works on a `Float64` model; a value that is not representable as
a finite (and, for `rho`, positive) coefficient raises a compilation error
rather than becoming `Inf` or `0`.

References: M. R. Hestenes (1969); M. J. D. Powell (1969); D. P. Bertsekas,
*Constrained Optimization and Lagrange Multiplier Methods* (1982);
K. Yonaga, M. J. Miyama, M. Ohzeki,
[arXiv:2012.06119](https://arxiv.org/abs/2012.06119).
"""
struct AugmentedLagrangianPenalty{T<:Real} <: ConstraintPenaltyMethod
    multiplier::T
    rho::T

    function AugmentedLagrangianPenalty{T}(multiplier::T, rho::T) where {T<:Real}
        if !isfinite(multiplier)
            throw(ArgumentError("multiplier must be finite"))
        elseif !(isfinite(rho) && rho > zero(T))
            throw(ArgumentError("rho must be finite and positive"))
        end

        return new{T}(multiplier, rho)
    end
end

function AugmentedLagrangianPenalty(multiplier::Real = 0.0, rho::Real = 1.0)
    λ, ρ = promote(multiplier, rho)

    return AugmentedLagrangianPenalty{typeof(λ)}(λ, ρ)
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

function _apply_incumbent_index_map(f::Function, vi::VI)
    try
        return f(vi)
    catch err
        if err isa KeyError
            return VI(-abs(vi.value) - 1)
        end
        rethrow(err)
    end
end

function _apply_incumbent_index_map(index_map::AbstractDict, vi::VI)
    isempty(index_map) && return vi
    return haskey(index_map, vi) ? index_map[vi] : VI(-abs(vi.value) - 1)
end

function _map_incumbent_indices(::Any, ::Nothing)
    return nothing
end

function _map_incumbent_indices(::Any, incumbent)
    return incumbent
end

function _map_incumbent_indices(::Any, incumbent::AbstractVector)
    return copy(incumbent)
end

function _map_incumbent_indices(index_map, incumbent::AbstractDict)
    mapped = Dict{Any,Any}()

    for (k, v) in incumbent
        if k isa VI
            mapped[_apply_incumbent_index_map(index_map, k)] = v
        elseif k isa Integer && !(k isa Bool)
            mapped[_apply_incumbent_index_map(index_map, VI(Int(k)))] = v
        elseif !(k isa Number) && hasproperty(k, :index) && getproperty(k, :index) isa VI
            vi = getproperty(k, :index)::VI
            if hasproperty(k, :model)
                jm = getproperty(k, :model)
                moi_model = hasproperty(jm, :moi_backend) ? getproperty(jm, :moi_backend) : jm
                if moi_model isa MOI.ModelLike && !MOI.is_valid(moi_model, vi)
                    mapped[VI(-abs(vi.value) - 1)] = v
                else
                    mapped[k] = v
                end
                continue
            end
            mapped[_apply_incumbent_index_map(index_map, vi)] = v
        else
            mapped[k] = v
        end
    end

    return mapped
end

abstract type AutomaticPenaltyPolicy end

@doc raw"""
    ObjectiveRangePenalty(incumbent = nothing)

Infer automatic penalty coefficients from a sufficient exact-penalty bound
based on the compiled objective range. When ToQUBO can certify finite objective
bounds and a positive violation gap for a generated nonnegative penalty
function, penalties are inferred as
``scale * sigma * ((objective_range + margin) / epsilon)``.

An optional candidate source assignment `incumbent` (or
[`PenaltyIncumbent`](@ref) / [`VariablePenaltyIncumbent`](@ref)) may be supplied
to tighten the whole-domain bound using a verified feasible incumbent:
- For minimization, let ``L \le f(x)`` hold over the encoded domain and
  ``U_{\text{inc}} = f(x_{\text{inc}})`` be the independently evaluated
  objective of a source-feasible, zero-penalty representable incumbent. Then
  ``\rho_i \epsilon_i > U_{\text{inc}} - L`` for every nonnegative penalty is
  sufficient to place every infeasible assignment strictly above
  ``U_{\text{inc}}``.
- For maximization, the sign-adjusted equivalent uses
  ``|\rho_i| \epsilon_i > U - L_{\text{inc}}``, where ``U \ge f(x)`` holds over
  the encoded domain and ``L_{\text{inc}} = f(x_{\text{inc}})``.

If a supplied candidate is incomplete, stale, infeasible, unrepresentable with
zero generated penalties, or if any source constraint or variable domain is not
enforced across all zero-penalty encoded states, or if the stored coefficients
cannot establish the strict sufficient inequality in exact arithmetic, ToQUBO
declines the tightened incumbent bound, records the reason in
[`PenaltyPolicyMetadata`](@ref), and retains the whole-domain bound (or falls
back to [`LegacyPenalty`](@ref) when the whole-domain bound cannot be
certified).
"""
struct ObjectiveRangePenalty <: AutomaticPenaltyPolicy
    incumbent::Any

    ObjectiveRangePenalty(incumbent) = new(incumbent)
end

ObjectiveRangePenalty(; incumbent = nothing) = ObjectiveRangePenalty(incumbent)

function Base.:(==)(a::ObjectiveRangePenalty, b::ObjectiveRangePenalty)
    return a.incumbent == b.incumbent
end

function MOIU.map_indices(f::Function, policy::ObjectiveRangePenalty)
    return ObjectiveRangePenalty(_map_incumbent_indices(f, policy.incumbent))
end

function MOIU.map_indices(
    variable_map::AbstractDict{T,T},
    policy::ObjectiveRangePenalty,
) where {T<:Union{MOI.VariableIndex,MOI.ConstraintIndex}}
    return ObjectiveRangePenalty(_map_incumbent_indices(variable_map, policy.incumbent))
end

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
with limited precision; for a bounded-coefficient alternative see
[`SubgradientUpdate`](@ref).
"""
struct MultiplicativeUpdate <: PenaltyUpdate
    factor::Float64

    function MultiplicativeUpdate(factor::Real = 10.0)
        # Validate the stored value: a finite `Real` can overflow to `Inf`
        # when converted (e.g. `big"1e400"`), which would feed a non-finite
        # coefficient into compilation.
        f = Float64(factor)

        isfinite(f) && f > 1 ||
            throw(ArgumentError("Penalty update factor must be finite and greater than one"))

        return new(f)
    end
end

@doc raw"""
    SubgradientUpdate(; step = nothing, patience = 3, escalation_factor = 10.0)

Method-of-multipliers penalty refinement for constraints using
[`AugmentedLagrangianPenalty`](@ref). After each solve, every such
constraint's multiplier is updated from the best sample's **signed** residual
``r``: equalities take ``\lambda \gets \lambda + \eta r``, inequalities the
one-sided ``\lambda \gets \max(0, \lambda + \eta r)`` (``r > 0`` when
violated). The step ``\eta`` defaults to the constraint's own ``\rho``, the
classical choice. Multiplier updates converge with **bounded** ``\rho``
(Bertsekas 1982), keeping the QUBO's coefficient range stable across
iterations — the advantage over [`MultiplicativeUpdate`](@ref) on samplers
with limited coefficient precision.

Safeguard: violated constraints' ``\rho`` is escalated by
`escalation_factor` only after `patience` consecutive iterations without a
decrease in the violation norm, then the counter resets. This adapts the
classical escalate-only-when-progress-stalls rule (Bertsekas; Conn–Gould–
Toint's BCL) to sampled binary problems, whose violation norms are quantized
and typically sit unchanged until a constraint flips feasible — a ratio test
on consecutive norms would misfire there on every iteration. Constraints not
using `AugmentedLagrangianPenalty`, and constraint sets other than scalar
`EqualTo`/`LessThan`/`GreaterThan`, are left untouched by this strategy.
"""
struct SubgradientUpdate <: PenaltyUpdate
    step::Union{Float64,Nothing}
    patience::Int
    escalation_factor::Float64

    function SubgradientUpdate(;
        step::Union{Real,Nothing} = nothing,
        patience::Integer = 3,
        escalation_factor::Real = 10.0,
    )
        # Validate the stored values: a finite `Real` can overflow to `Inf`
        # or underflow to `0.0` when narrowed to `Float64`, which would make
        # refinement error mid-loop or silently stop updating.
        η = isnothing(step) ? nothing : Float64(step)
        τ = Float64(escalation_factor)

        isnothing(η) || (isfinite(η) && η > 0) ||
            throw(ArgumentError("step must be finite and positive"))
        patience >= 1 || throw(ArgumentError("patience must be at least one"))
        isfinite(τ) && τ > 1 ||
            throw(ArgumentError("escalation factor must be finite and greater than one"))

        return new(η, Int(patience), τ)
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

function _compiled_objective_components(model::Optimizer{T})::Vector{PBO.PBF{VI,T}} where {T}
    if _is_qubo_fast_path(model)
        return PBO.PBF{VI,T}[_compiled_qubo_objective_from_target(model)]
    end

    return model.f_components
end

@doc raw"""
    CompiledObjectiveFunctions()

Return the vector of pseudo-boolean component objectives parsed from the source
model in their original unweighted, un-flipped form, before scalarization and
penalty terms are added.

For a scalar source objective, the returned vector has length `1` after
compilation. For a vector source objective, the returned vector has one entry
per objective component.
"""
struct CompiledObjectiveFunctions <: CompilerAttribute end

MOI.is_set_by_optimize(::CompiledObjectiveFunctions) = true

function MOI.get(
    model::Optimizer{T},
    ::CompiledObjectiveFunctions,
)::Vector{PBO.PBF{VI,T}} where {T}
    return PBO.PBF{VI,T}[copy(f_i) for f_i in _compiled_objective_components(model)]
end

function compiled_objective_functions(model::Optimizer)
    return MOI.get(model, CompiledObjectiveFunctions())
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

For vector objectives (or when [`ObjectiveWeights`](@ref) /
[`ObjectiveSenses`](@ref) are configured), this returns the scalarized
penalty-free source objective using the configured per-objective weights and
relative sense signs. Use [`ObjectiveFunctionValues`](@ref),
[`SourceObjectiveValues`](@ref), or [`ToQUBO.source_objective_values`](@ref) to
retrieve the vector of unweighted component objective values.

Unlike `MOI.ObjectiveValue`, which reports the target QUBO energy including
penalty terms introduced by the reformulation, this attribute is penalty-free:
it evaluates the original objective on the decoded solution.
"""
struct SourceObjectiveValue <: CompilerAttribute
    result_index::Int

    SourceObjectiveValue(result_index::Integer = 1) = new(Int(result_index))
end

MOI.is_set_by_optimize(::SourceObjectiveValue) = true

@doc raw"""
    ObjectiveFunctionValues(result_index::Integer = 1)

Vector of component source-objective values on sampled result `result_index`,
evaluated by applying each compiled component pseudo-boolean function in
[`CompiledObjectiveFunctions`](@ref) to the sampled target state (without
penalty terms, per-objective weights, or sense sign flips).
"""
struct ObjectiveFunctionValues <: CompilerAttribute
    result_index::Int

    ObjectiveFunctionValues(result_index::Integer = 1) = new(Int(result_index))
end

MOI.is_set_by_optimize(::ObjectiveFunctionValues) = true

function objective_function_values(model::Optimizer, result_index::Integer = 1)
    return MOI.get(model, ObjectiveFunctionValues(result_index))
end

@doc raw"""
    ObjectiveFunctionValue(objective_index::Integer, result_index::Integer = 1)

Value of the `objective_index`-th component source objective on sampled result
`result_index`, evaluated by applying that component's compiled pseudo-boolean
function to the sampled target state (without penalty terms, per-objective
weights, or sense sign flips).
"""
struct ObjectiveFunctionValue <: CompilerAttribute
    objective_index::Int
    result_index::Int

    function ObjectiveFunctionValue(
        objective_index::Integer,
        result_index::Integer = 1,
    )
        objective_index >= 1 ||
            throw(ArgumentError("Objective index must be positive; got $objective_index"))

        return new(Int(objective_index), Int(result_index))
    end
end

MOI.is_set_by_optimize(::ObjectiveFunctionValue) = true

function objective_function_value(
    model::Optimizer,
    objective_index::Integer,
    result_index::Integer = 1,
)
    return MOI.get(model, ObjectiveFunctionValue(objective_index, result_index))
end

@doc raw"""
    SourceObjectiveValues(result_index::Integer = 1)

Vector of unweighted component source-objective values on sampled result
`result_index`. Equivalent to [`ObjectiveFunctionValues`](@ref).
"""
struct SourceObjectiveValues <: CompilerAttribute
    result_index::Int

    SourceObjectiveValues(result_index::Integer = 1) = new(Int(result_index))
end

MOI.is_set_by_optimize(::SourceObjectiveValues) = true

function _validate_objective_weight(::Type{T}, w)::T where {T}
    if !(w isa Real) || w isa Bool || !isfinite(w)
        throw(
            ArgumentError(
                "Objective weight must be a finite real number; got $(repr(w))",
            ),
        )
    end

    wt = try
        convert(T, w)
    catch
        throw(
            ArgumentError(
                "Objective weight $(repr(w)) cannot be converted to coefficient type $T",
            ),
        )
    end

    isfinite(wt) ||
        throw(
            ArgumentError(
                "Objective weight must be finite in coefficient type $T; got $(repr(w))",
            ),
        )

    return wt
end

function _normalize_objective_sense(sense)::MOI.OptimizationSense
    if sense === MOI.MIN_SENSE || sense === :min || sense === QUBOTools.Min
        return MOI.MIN_SENSE
    elseif sense === MOI.MAX_SENSE || sense === :max || sense === QUBOTools.Max
        return MOI.MAX_SENSE
    else
        throw(
            ArgumentError(
                "Objective sense must be `MOI.MIN_SENSE`, `MOI.MAX_SENSE`, `:min`, or `:max`; got $(repr(sense))",
            ),
        )
    end
end

function _has_custom_objective_scalarization(model::Optimizer)::Bool
    has_weights = haskey(model.compiler_settings, :objective_weights)
    weight_dict = get(model.compiler_settings, :objective_weight, nothing)
    has_weight_overrides = !isnothing(weight_dict) && !isempty(weight_dict)
    has_senses = haskey(model.compiler_settings, :objective_senses)
    sense_dict = get(model.compiler_settings, :objective_sense, nothing)
    has_sense_overrides = !isnothing(sense_dict) && !isempty(sense_dict)

    return has_weights || has_weight_overrides || has_senses || has_sense_overrides
end

@doc raw"""
    ObjectiveWeights()

Set or retrieve per-objective scalarization weights for vector (or scalar)
objectives.

Pass a vector or tuple of finite real numbers matching the number of objective
components, or `nothing` to reset to unit weights (`1`). Individual component
weights can also be set or overridden with [`ObjectiveWeight`](@ref). Setting
`ObjectiveWeights()` clears any previous per-index [`ObjectiveWeight`](@ref)
overrides.
"""
struct ObjectiveWeights <: CompilerAttribute end

_attribute_from_key(::Val{:objective_weights}) = ObjectiveWeights

function MOI.get(model::Optimizer{T}, ::ObjectiveWeights)::Union{Vector{T},Nothing} where {T}
    base = get(model.compiler_settings, :objective_weights, nothing)
    isnothing(base) && return nothing

    weights = copy(base::Vector{T})
    overrides = get(model.compiler_settings, :objective_weight, nothing)
    if !isnothing(overrides)
        for (idx, w) in overrides::Dict{Int,T}
            if 1 <= idx <= length(weights)
                weights[idx] = w
            end
        end
    end

    return weights
end

function MOI.set(
    model::Optimizer{T},
    ::ObjectiveWeights,
    weights::Union{AbstractVector,Tuple},
) where {T}
    converted = Vector{T}(undef, length(weights))
    for (i, w) in enumerate(weights)
        converted[i] = _validate_objective_weight(T, w)
    end

    model.compiler_settings[:objective_weights] = converted
    delete!(model.compiler_settings, :objective_weight)

    return nothing
end

function MOI.set(model::Optimizer, ::ObjectiveWeights, ::Nothing)
    delete!(model.compiler_settings, :objective_weights)
    delete!(model.compiler_settings, :objective_weight)

    return nothing
end

function MOI.set(::Optimizer, ::ObjectiveWeights, value::Any)
    throw(
        ArgumentError(
            "`ObjectiveWeights` must be a vector or tuple of finite real numbers, or `nothing`; got $(repr(value))",
        ),
    )
end

function MOI.set(
    uf::MOIU.UniversalFallback,
    attr::ObjectiveWeights,
    value,
)
    if !(value === nothing || value isa Union{AbstractVector,Tuple})
        throw(
            ArgumentError(
                "`ObjectiveWeights` must be a vector or tuple of finite real numbers, or `nothing`; got $(repr(value))",
            ),
        )
    end
    if value !== nothing
        for w in value
            _validate_objective_weight(Float64, w)
        end
    end

    for k in collect(keys(uf.optattr))
        if k isa ObjectiveWeight
            delete!(uf.optattr, k)
        end
    end

    if value === nothing
        delete!(uf.optattr, attr)
    else
        uf.optattr[attr] = value
    end

    return nothing
end

function objective_weights(model::Optimizer)
    return MOI.get(model, ObjectiveWeights())
end

@doc raw"""
    ObjectiveWeight(index::Integer)

Set or retrieve the scalarization weight for the `index`-th objective component
(1-based). Pass `nothing` to clear the override for `index`.
"""
struct ObjectiveWeight <: CompilerAttribute
    index::Int

    function ObjectiveWeight(index::Integer)
        if index isa Bool || index < 1
            throw(
                ArgumentError(
                    "Objective component index must be a positive integer; got $(repr(index))",
                ),
            )
        end

        return new(Int(index))
    end
end

function MOI.get(
    model::Optimizer{T},
    attr::ObjectiveWeight,
)::Union{T,Nothing} where {T}
    overrides = get(model.compiler_settings, :objective_weight, nothing)
    if !isnothing(overrides) && haskey(overrides, attr.index)
        return (overrides::Dict{Int,T})[attr.index]
    end

    base = get(model.compiler_settings, :objective_weights, nothing)
    if !isnothing(base) && 1 <= attr.index <= length(base::Vector{T})
        return (base::Vector{T})[attr.index]
    end

    return nothing
end

function MOI.set(
    model::Optimizer{T},
    attr::ObjectiveWeight,
    weight::Any,
) where {T}
    wt = _validate_objective_weight(T, weight)
    overrides = get!(model.compiler_settings, :objective_weight) do
        return Dict{Int,T}()
    end::Dict{Int,T}
    overrides[attr.index] = wt

    return nothing
end

function MOI.set(model::Optimizer, attr::ObjectiveWeight, ::Nothing)
    overrides = get(model.compiler_settings, :objective_weight, nothing)
    if !isnothing(overrides)
        delete!(overrides, attr.index)
        if isempty(overrides)
            delete!(model.compiler_settings, :objective_weight)
        end
    end

    return nothing
end

function objective_weight(model::Optimizer{T}, index::Integer)::T where {T}
    w = MOI.get(model, ObjectiveWeight(index))
    return isnothing(w) ? one(T) : w
end

@doc raw"""
    ObjectiveSenses()

Set or retrieve per-objective optimization senses (`MOI.MIN_SENSE` / `:min` or
`MOI.MAX_SENSE` / `:max`) for vector (or scalar) objectives.

When unset (`nothing`), each objective component uses the model's optimization
sense (`MOI.MAX_SENSE` when `MOI.ObjectiveSense()` is `MOI.MAX_SENSE`, and
`MOI.MIN_SENSE` otherwise). A component whose sense differs from the target
model's optimization sense has its sign flipped during scalarization. Setting
`ObjectiveSenses()` clears any previous per-index [`ObjectiveSense`](@ref)
overrides.
"""
struct ObjectiveSenses <: CompilerAttribute end

_attribute_from_key(::Val{:objective_senses}) = ObjectiveSenses

function MOI.get(
    model::Optimizer,
    ::ObjectiveSenses,
)::Union{Vector{MOI.OptimizationSense},Nothing}
    base = get(model.compiler_settings, :objective_senses, nothing)
    isnothing(base) && return nothing

    senses = copy(base::Vector{MOI.OptimizationSense})
    overrides = get(model.compiler_settings, :objective_sense, nothing)
    if !isnothing(overrides)
        for (idx, s) in overrides::Dict{Int,MOI.OptimizationSense}
            if 1 <= idx <= length(senses)
                senses[idx] = s
            end
        end
    end

    return senses
end

function MOI.set(
    model::Optimizer,
    ::ObjectiveSenses,
    senses::Union{AbstractVector,Tuple},
)
    converted = Vector{MOI.OptimizationSense}(undef, length(senses))
    for (i, s) in enumerate(senses)
        converted[i] = _normalize_objective_sense(s)
    end

    model.compiler_settings[:objective_senses] = converted
    delete!(model.compiler_settings, :objective_sense)

    return nothing
end

function MOI.set(model::Optimizer, ::ObjectiveSenses, ::Nothing)
    delete!(model.compiler_settings, :objective_senses)
    delete!(model.compiler_settings, :objective_sense)

    return nothing
end

function MOI.set(::Optimizer, ::ObjectiveSenses, value::Any)
    throw(
        ArgumentError(
            "`ObjectiveSenses` must be a vector or tuple of optimization senses, or `nothing`; got $(repr(value))",
        ),
    )
end

function MOI.set(
    uf::MOIU.UniversalFallback,
    attr::ObjectiveSenses,
    value,
)
    if !(value === nothing || value isa Union{AbstractVector,Tuple})
        throw(
            ArgumentError(
                "`ObjectiveSenses` must be a vector or tuple of optimization senses, or `nothing`; got $(repr(value))",
            ),
        )
    end
    if value !== nothing
        for s in value
            _normalize_objective_sense(s)
        end
    end

    for k in collect(keys(uf.optattr))
        if k isa ObjectiveSense
            delete!(uf.optattr, k)
        end
    end

    if value === nothing
        delete!(uf.optattr, attr)
    else
        uf.optattr[attr] = value
    end

    return nothing
end

function objective_senses(model::Optimizer)
    return MOI.get(model, ObjectiveSenses())
end

@doc raw"""
    ObjectiveSense(index::Integer)

Set or retrieve the optimization sense (`MOI.MIN_SENSE` / `:min` or
`MOI.MAX_SENSE` / `:max`) for the `index`-th objective component (1-based).
Pass `nothing` to clear the override for `index`.
"""
struct ObjectiveSense <: CompilerAttribute
    index::Int

    function ObjectiveSense(index::Integer)
        if index isa Bool || index < 1
            throw(
                ArgumentError(
                    "Objective component index must be a positive integer; got $(repr(index))",
                ),
            )
        end

        return new(Int(index))
    end
end

function MOI.get(
    model::Optimizer,
    attr::ObjectiveSense,
)::Union{MOI.OptimizationSense,Nothing}
    overrides = get(model.compiler_settings, :objective_sense, nothing)
    if !isnothing(overrides) && haskey(overrides, attr.index)
        return (overrides::Dict{Int,MOI.OptimizationSense})[attr.index]
    end

    base = get(model.compiler_settings, :objective_senses, nothing)
    if !isnothing(base) &&
       1 <= attr.index <= length(base::Vector{MOI.OptimizationSense})
        return (base::Vector{MOI.OptimizationSense})[attr.index]
    end

    return nothing
end

function MOI.set(
    model::Optimizer,
    attr::ObjectiveSense,
    sense::Any,
)
    s = _normalize_objective_sense(sense)
    overrides = get!(model.compiler_settings, :objective_sense) do
        return Dict{Int,MOI.OptimizationSense}()
    end::Dict{Int,MOI.OptimizationSense}
    overrides[attr.index] = s

    return nothing
end

function MOI.set(model::Optimizer, attr::ObjectiveSense, ::Nothing)
    overrides = get(model.compiler_settings, :objective_sense, nothing)
    if !isnothing(overrides)
        delete!(overrides, attr.index)
        if isempty(overrides)
            delete!(model.compiler_settings, :objective_sense)
        end
    end

    return nothing
end

function objective_sense(model::Optimizer, index::Integer)::MOI.OptimizationSense
    s = MOI.get(model, ObjectiveSense(index))
    if !isnothing(s)
        return s
    end

    return MOI.get(model, MOI.ObjectiveSense()) === MOI.MAX_SENSE ? MOI.MAX_SENSE :
           MOI.MIN_SENSE
end

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
    PenaltyIncumbent()

Set an optional candidate source assignment used by [`ObjectiveRangePenalty`](@ref)
to tighten the automatic exact-penalty bound.

The candidate may be supplied as:
- an `AbstractDict` keyed by `MOI.VariableIndex`, integer source variable ids,
  or JuMP variable references,
- an `AbstractVector` or `Tuple` ordered according to `ToQUBO.original_variables(model)`,
- or `nothing` to clear the candidate.

On each compilation, ToQUBO independently validates that the candidate covers
every source variable with finite values, satisfies every source constraint,
lifts to a binary target representation with zero generated variable,
constraint, and slack penalties, and evaluates the source objective (including
constants and optimization sense) in exact rational arithmetic. Unvalidated
variable primal starts (`MOI.VariablePrimalStart`) are never automatically used
as a penalty certificate.
"""
struct PenaltyIncumbent <: CompilerAttribute end

_attribute_from_key(::Val{:penalty_incumbent}) = PenaltyIncumbent

function MOIU.map_indices(index_map, ::PenaltyIncumbent, incumbent)
    return _map_incumbent_indices(index_map, incumbent)
end

function MOI.get(model::Optimizer, ::PenaltyIncumbent)
    return get(model.compiler_settings, :penalty_incumbent, nothing)
end

function MOI.set(model::Optimizer, ::PenaltyIncumbent, incumbent::Any)
    model.compiler_settings[:penalty_incumbent] = incumbent

    return nothing
end

function MOI.set(model::Optimizer, ::PenaltyIncumbent, ::Nothing)
    delete!(model.compiler_settings, :penalty_incumbent)

    return nothing
end

function penalty_incumbent(model::Optimizer)
    return MOI.get(model, PenaltyIncumbent())
end

@doc raw"""
    PenaltyPolicyMetadata()

Return diagnostic metadata for the automatic penalty policy used during the
last compilation.

The returned dictionary includes the selected automatic policy, objective
bounds (including bound provenance and any verified incumbent tightening),
`incumbent` validation/lifting outcome, `sufficient_bound` certification across
applied coefficients, the legacy objective gap, fallback records, and
`inferred_penalties`. `inferred_penalties` is grouped under `"constraints"`,
`"variables"`, and `"slack_variables"`. Each entry records the source item kind
and id, final automatic coefficient, `epsilon`, `epsilon_source`, scale,
offset, automatic policy, selected policy, sufficiency status, and any fallback
reason.

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
    VariablePenaltyIncumbent()

Set a variable's value in a candidate feasible incumbent used by
[`ObjectiveRangePenalty`](@ref) to tighten automatic exact-penalty bounds.

When any variable has [`VariablePenaltyIncumbent`](@ref) set, every source
variable in the model must be assigned a finite value to form a complete
candidate assignment. Pass `nothing` to clear the variable's candidate value.
See also [`PenaltyIncumbent`](@ref).
"""
struct VariablePenaltyIncumbent <: CompilerVariableAttribute end

_attribute_from_key(::Val{:variable_penalty_incumbent}) = VariablePenaltyIncumbent

function variable_penalty_incumbent(model::Optimizer, vi::VI)
    return MOI.get(model, VariablePenaltyIncumbent(), vi)
end

function MOI.get(model::Optimizer, ::VariablePenaltyIncumbent, vi::VI)
    attr = :variable_penalty_incumbent

    if !haskey(model.variable_settings, attr) || !haskey(model.variable_settings[attr], vi)
        return nothing
    else
        return model.variable_settings[attr][vi]
    end
end

function MOI.set(model::Optimizer, ::VariablePenaltyIncumbent, vi::VI, value::Any)
    attr = :variable_penalty_incumbent

    if !haskey(model.variable_settings, attr)
        model.variable_settings[attr] = Dict{VI,Any}()
    end

    model.variable_settings[attr][vi] = value

    return nothing
end

function MOI.set(
    model::Optimizer,
    ::VariablePenaltyIncumbent,
    vi::VI,
    ::Nothing,
)
    attr = :variable_penalty_incumbent

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

@doc raw"""
    SoftConstraint()

Boolean constraint attribute marking a source constraint as soft for
feasibility analysis and iterative penalty refinement.

Soft constraints still have their residuals and violation magnitudes measured
and reported by [`ToQUBO.violations`](@ref) and
[`ToQUBO.feasibility_report`](@ref), but violating a soft constraint does not
make a sampled result hard-infeasible in [`ToQUBO.is_feasible`](@ref),
`FeasibilityResult.feasible`, `MOI.PrimalStatus`, or
[`AutoFeasibilityReport`](@ref), and does not trigger iterative penalty
escalation under [`MaxPenaltyUpdates`](@ref).

Marking a constraint with `SoftConstraint()` does not remove its compiled
penalty term from the target QUBO or reduce its initial automatically inferred
penalty coefficient. Pair `SoftConstraint()` with
[`ConstraintPenaltyScale`](@ref), [`ConstraintPenaltyOffset`](@ref), or an
explicit [`ConstraintEncodingPenaltyHint`](@ref) to set a bounded preference
weight.

Defaults to `false` (hard constraint). Pass `nothing` to reset to the default.
"""
struct SoftConstraint <: CompilerConstraintAttribute end

_attribute_from_key(::Val{:soft_constraint}) = SoftConstraint

function soft_constraint(model::Optimizer, ci::CI)::Bool
    return MOI.get(model, SoftConstraint(), ci)
end

function MOI.get(
    model::Optimizer,
    ::SoftConstraint,
    ci::CI,
)::Bool
    attr = :soft_constraint

    if !haskey(model.constraint_settings, attr) ||
       !haskey(model.constraint_settings[attr], ci)
        return false
    else
        return model.constraint_settings[attr][ci]::Bool
    end
end

function MOI.set(
    model::Optimizer,
    ::SoftConstraint,
    ci::CI,
    flag::Bool,
)::Nothing
    attr = :soft_constraint

    if !haskey(model.constraint_settings, attr)
        model.constraint_settings[attr] = Dict{CI,Any}()
    end

    model.constraint_settings[attr][ci] = flag

    delete!(model.moi_settings, :feasibility_report)
    delete!(model.moi_settings, :primal_feasibility)

    return nothing
end

function MOI.set(
    model::Optimizer,
    ::SoftConstraint,
    ci::CI,
    ::Nothing,
)::Nothing
    attr = :soft_constraint

    if haskey(model.constraint_settings, attr)
        delete!(model.constraint_settings[attr], ci)
    end

    delete!(model.moi_settings, :feasibility_report)
    delete!(model.moi_settings, :primal_feasibility)

    return nothing
end

function MOI.set(
    ::Optimizer,
    ::SoftConstraint,
    ::CI,
    value::Any,
)
    throw(
        ArgumentError(
            "`SoftConstraint` value must be a `Bool` or `nothing`; got $(repr(value))",
        ),
    )
end

function MOI.get(
    uf::MOIU.UniversalFallback,
    attr::SoftConstraint,
    ci::CI,
)::Bool
    if !MOI.is_valid(uf, ci)
        throw(MOI.InvalidIndex(ci))
    end

    conattr = get(uf.conattr, attr, nothing)
    conattr === nothing && return false
    val = get(conattr, ci, nothing)

    return val === nothing ? false : Bool(val)
end

function MOI.set(
    uf::MOIU.UniversalFallback,
    attr::SoftConstraint,
    ci::CI,
    flag::Bool,
)::Nothing
    if !MOI.is_valid(uf, ci)
        throw(MOI.InvalidIndex(ci))
    end

    conattr = get!(uf.conattr, attr) do
        return Dict{CI,Any}()
    end
    conattr[ci] = flag

    return nothing
end

function MOI.set(
    uf::MOIU.UniversalFallback,
    attr::SoftConstraint,
    ci::CI,
    ::Nothing,
)::Nothing
    if !MOI.is_valid(uf, ci)
        throw(MOI.InvalidIndex(ci))
    end

    conattr = get(uf.conattr, attr, nothing)
    if conattr !== nothing
        delete!(conattr, ci)
        if isempty(conattr)
            delete!(uf.conattr, attr)
        end
    end

    return nothing
end

function MOI.set(
    ::MOIU.UniversalFallback,
    ::SoftConstraint,
    ::CI,
    value::Any,
)
    throw(
        ArgumentError(
            "`SoftConstraint` value must be a `Bool` or `nothing`; got $(repr(value))",
        ),
    )
end

function MOI.supports(
    model::MOI.ModelLike,
    attr::SoftConstraint,
    ::Type{BT},
) where {BT<:MOIB.Constraint.AbstractBridge}
    return all(
        MOI.supports(model, attr, MOI.ConstraintIndex{F,S}) for
        (F, S) in MOIB.added_constraint_types(BT)
    )
end

function MOI.set(
    model::MOI.ModelLike,
    attr::SoftConstraint,
    bridge::MOIB.Constraint.AbstractBridge,
    value,
)
    if !(value isa Bool || value === nothing)
        throw(
            ArgumentError(
                "`SoftConstraint` value must be a `Bool` or `nothing`; got $(repr(value))",
            ),
        )
    end

    for (F, S) in MOIB.added_constraint_types(typeof(bridge))
        for ci in MOI.get(bridge, MOI.ListOfConstraintIndices{F,S}())
            MOI.set(model, attr, ci, value)
        end
    end

    return nothing
end

function MOI.get(
    model::MOI.ModelLike,
    attr::SoftConstraint,
    bridge::MOIB.Constraint.AbstractBridge,
)::Bool
    found = false

    for (F, S) in MOIB.added_constraint_types(typeof(bridge))
        for ci in MOI.get(bridge, MOI.ListOfConstraintIndices{F,S}())
            found = true
            MOI.get(model, attr, ci) || return false
        end
    end

    return found
end

end # module Attributes
