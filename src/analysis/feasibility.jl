# Default absolute tolerance shared by every feasibility measurement so that
# `violations`, `is_feasible`, `feasibility_report`, and the automatic
# `MOI.PrimalStatus` check agree on what counts as a violation.
const _FEASIBILITY_ATOL = 1e-6

@doc raw"""
    ConstraintViolation

A measured source-constraint residual for one sampled result.

`constraint` is the source `MOI.ConstraintIndex`, `function_type` and
`set_type` identify the constraint family, `value` is the original constraint
function evaluated on the projected source-variable values, `raw_residual` is
the set-specific residual before applying tolerances, `violation` is the
nonnegative distance to the set, `variable_values` contains the projected
values for variables referenced by the constraint function, and `soft`
indicates whether the constraint was marked with
[`Attributes.SoftConstraint`](@ref).
"""
struct ConstraintViolation
    constraint::MOI.ConstraintIndex
    function_type::DataType
    set_type::DataType
    value::Any
    raw_residual::Any
    violation::Float64
    variable_values::Dict{VI,Any}
    soft::Bool
end

function ConstraintViolation(
    constraint::MOI.ConstraintIndex,
    function_type::DataType,
    set_type::DataType,
    value,
    raw_residual,
    violation::Real,
    variable_values::Dict{VI,Any},
)
    return ConstraintViolation(
        constraint,
        function_type,
        set_type,
        value,
        raw_residual,
        Float64(violation),
        variable_values,
        false,
    )
end

const ConstraintTypeSummary = NamedTuple{
    (:count, :violation_count, :max_violation, :total_violation),
    Tuple{Int,Int,Float64,Float64},
}

@doc raw"""
    FeasibilityResult

Summary of source-constraint feasibility for one sampled result.

`feasible`, `violation_count`, `max_violation`, `total_violation`, and
`by_constraint_type` summarize hard source constraints (`soft == false`).
`soft_violation_count`, `soft_max_violation`, `soft_total_violation`, and
`soft_by_constraint_type` summarize constraints marked with
[`Attributes.SoftConstraint`](@ref).
"""
struct FeasibilityResult
    result::Int
    feasible::Bool
    violation_count::Int
    max_violation::Float64
    total_violation::Float64
    by_constraint_type::Dict{String,ConstraintTypeSummary}
    soft_violation_count::Int
    soft_max_violation::Float64
    soft_total_violation::Float64
    soft_by_constraint_type::Dict{String,ConstraintTypeSummary}
end

function FeasibilityResult(
    result::Integer,
    feasible::Bool,
    violation_count::Integer,
    max_violation::Real,
    total_violation::Real,
    by_constraint_type::Dict{String,ConstraintTypeSummary},
)
    return FeasibilityResult(
        Int(result),
        feasible,
        Int(violation_count),
        Float64(max_violation),
        Float64(total_violation),
        by_constraint_type,
        0,
        0.0,
        0.0,
        Dict{String,ConstraintTypeSummary}(),
    )
end

@doc raw"""
    FeasibilityReport

Per-result source-constraint feasibility summary returned by
[`feasibility_report`](@ref).

`feasible_count`, `max_violation`, and `total_violation` summarize hard source
constraints across the selected results, while `soft_violation_count`,
`soft_max_violation`, and `soft_total_violation` summarize constraints marked
with [`Attributes.SoftConstraint`](@ref).
"""
struct FeasibilityReport
    result_count::Int
    feasible_count::Int
    max_violation::Float64
    total_violation::Float64
    soft_violation_count::Int
    soft_max_violation::Float64
    soft_total_violation::Float64
    results::Vector{FeasibilityResult}
end

function FeasibilityReport(
    result_count::Integer,
    feasible_count::Integer,
    max_violation::Real,
    total_violation::Real,
    results::Vector{FeasibilityResult},
)
    soft_violation_count = sum(r.soft_violation_count for r in results; init = 0)
    soft_max_violation =
        isempty(results) ? 0.0 : maximum(r.soft_max_violation for r in results)
    soft_total_violation = sum(r.soft_total_violation for r in results; init = 0.0)

    return FeasibilityReport(
        Int(result_count),
        Int(feasible_count),
        Float64(max_violation),
        Float64(total_violation),
        soft_violation_count,
        soft_max_violation,
        soft_total_violation,
        results,
    )
end

@doc raw"""
    violations(model; result::Int = 1, atol::Real = _FEASIBILITY_ATOL, include_soft::Bool = true)

Return source constraints violated by sampled result `result`.

The sampled QUBO result is projected back to the original source variables
using the compiler's virtual mapping, then each source constraint is evaluated
and measured against its MOI set. Scalar sets use
`MOI.Utilities.distance_to_set`. Indicator constraints are considered violated
only when their activation value triggers the inner set; SOS1 constraints use
the distance to the nearest one-nonzero vector under the ``\ell_1`` projection
convention.

Violated constraints marked with [`Attributes.SoftConstraint`](@ref) have
`measurement.soft == true` and are included by default (`include_soft = true`).
Pass `include_soft = false` to return only hard-constraint violations.
"""
function violations(
    model;
    result::Integer = 1,
    atol::Real = _FEASIBILITY_ATOL,
    include_soft::Bool = true,
)
    return violations(_toqubo_model(model); result, atol, include_soft)
end

function violations(
    model::Virtual.Model;
    result::Integer = 1,
    atol::Real = _FEASIBILITY_ATOL,
    include_soft::Bool = true,
)
    tol = Float64(atol)

    return filter(
        measurement ->
            (include_soft || !measurement.soft) && measurement.violation > tol,
        _constraint_measurements(model, Int(result)),
    )
end

@doc raw"""
    is_feasible(model; result::Int = 1, atol::Real = _FEASIBILITY_ATOL)

Return `true` if every hard source constraint (those not marked with
[`Attributes.SoftConstraint`](@ref)) is satisfied by sampled result `result`
within absolute tolerance `atol`.
"""
function is_feasible(model; result::Integer = 1, atol::Real = _FEASIBILITY_ATOL)
    return isempty(violations(model; result, atol, include_soft = false))
end

@doc raw"""
    feasibility_report(model; result = nothing, atol::Real = _FEASIBILITY_ATOL)

Return a [`FeasibilityReport`](@ref) summarizing source-constraint feasibility.

If `result` is `nothing`, all available solver results are summarized. Pass an
integer or iterable of result indices to summarize selected samples.
"""
function feasibility_report(model; result = nothing, atol::Real = _FEASIBILITY_ATOL)
    return feasibility_report(_toqubo_model(model); result, atol)
end

function feasibility_report(model::Virtual.Model; result = nothing, atol::Real = _FEASIBILITY_ATOL)
    default_request = _is_default_report_request(result, atol)

    if default_request
        cached = get(model.moi_settings, :feasibility_report, nothing)

        if cached isa FeasibilityReport
            return cached
        end
    end

    results = [
        _feasibility_result(model, i, Float64(atol)) for i in _result_indices(model, result)
    ]

    max_violation = isempty(results) ? 0.0 : maximum(r.max_violation for r in results)
    total_violation = sum(r.total_violation for r in results; init = 0.0)
    soft_violation_count = sum(r.soft_violation_count for r in results; init = 0)
    soft_max_violation =
        isempty(results) ? 0.0 : maximum(r.soft_max_violation for r in results)
    soft_total_violation = sum(r.soft_total_violation for r in results; init = 0.0)

    report = FeasibilityReport(
        length(results),
        count(r -> r.feasible, results),
        max_violation,
        total_violation,
        soft_violation_count,
        soft_max_violation,
        soft_total_violation,
        results,
    )

    if default_request
        model.moi_settings[:feasibility_report] = report
    end

    return report
end

_is_default_report_request(result, atol) =
    result === nothing && Float64(atol) == _FEASIBILITY_ATOL

function _toqubo_model(model::Virtual.Model)
    return model
end

function _toqubo_model(model)
    backend = _unsafe_backend(model)

    if !isnothing(backend) && backend !== model
        return _toqubo_model(backend)
    end

    error(
        "Feasibility analysis requires a ToQUBO.Optimizer result. " *
        "For JuMP models, load JuMP and pass the JuMP.Model directly.",
    )
end

function _unsafe_backend(model)
    mod = parentmodule(typeof(model))

    if !isdefined(mod, :unsafe_backend)
        return nothing
    end

    unsafe_backend = getfield(mod, :unsafe_backend)

    if !(unsafe_backend isa Function)
        return nothing
    end

    if !hasmethod(unsafe_backend, Tuple{typeof(model)})
        return nothing
    end

    return unsafe_backend(model)
end

function _result_count(model::Virtual.Model)
    return MOI.get(model, MOI.ResultCount())
end

function _check_result_index(model::Virtual.Model, result::Int)
    result >= 1 || error("Result index must be positive; got $result")

    n = _result_count(model)

    if n == 0
        error("No primal results are available; optimize with a QUBO solver first")
    elseif result > n
        error("Result index $result is unavailable; model has $n result(s)")
    end

    return nothing
end

function _result_indices(model::Virtual.Model, ::Nothing)
    n = _result_count(model)

    n > 0 || error("No primal results are available; optimize with a QUBO solver first")

    return collect(1:n)
end

function _result_indices(model::Virtual.Model, result::Integer)
    index = Int(result)

    _check_result_index(model, index)

    return [index]
end

function _result_indices(model::Virtual.Model, results)
    indices = Int.(collect(results))

    for index in indices
        _check_result_index(model, index)
    end

    return indices
end

function _projected_result_values(model::Virtual.Model, result::Int)
    _check_result_index(model, result)

    attr = MOI.VariablePrimal(result)

    return Dict{VI,Any}(
        vi => MOI.get(model, attr, vi) for vi in MOI.get(model.source_model, MOI.ListOfVariableIndices())
    )
end

function _constraint_measurements(model::Virtual.Model, result::Int)
    values = _projected_result_values(model, result)
    measurements = ConstraintViolation[]

    for (F, S) in MOI.get(model.source_model, MOI.ListOfConstraintTypesPresent())
        for ci in MOI.get(model.source_model, MOI.ListOfConstraintIndices{F,S}())
            f = MOI.get(model.source_model, MOI.ConstraintFunction(), ci)
            s = MOI.get(model.source_model, MOI.ConstraintSet(), ci)
            soft = Attributes.soft_constraint(model, ci)

            push!(
                measurements,
                _constraint_violation(model.source_model, ci, f, s, values; soft),
            )
        end
    end

    sort!(
        measurements;
        by = measurement -> (
            measurement.constraint.value,
            string(measurement.function_type),
            string(measurement.set_type),
        ),
    )

    return measurements
end

function _feasibility_result(model::Virtual.Model, result::Int, atol::Float64)
    measurements = _constraint_measurements(model, result)
    hard_measurements = filter(m -> !m.soft, measurements)
    soft_measurements = filter(m -> m.soft, measurements)

    max_violation =
        isempty(hard_measurements) ? 0.0 : maximum(m.violation for m in hard_measurements)
    total_violation = sum(m.violation for m in hard_measurements; init = 0.0)
    violation_count = count(m -> m.violation > atol, hard_measurements)

    soft_max_violation =
        isempty(soft_measurements) ? 0.0 : maximum(m.violation for m in soft_measurements)
    soft_total_violation = sum(m.violation for m in soft_measurements; init = 0.0)
    soft_violation_count = count(m -> m.violation > atol, soft_measurements)

    return FeasibilityResult(
        result,
        max_violation <= atol,
        violation_count,
        max_violation,
        total_violation,
        _summarize_by_constraint_type(hard_measurements, atol),
        soft_violation_count,
        soft_max_violation,
        soft_total_violation,
        _summarize_by_constraint_type(soft_measurements, atol),
    )
end

function _constraint_type_label(measurement::ConstraintViolation)
    return "$(measurement.function_type) in $(measurement.set_type)"
end

function _summarize_by_constraint_type(measurements, atol::Float64)
    summary = Dict{String,ConstraintTypeSummary}()

    for measurement in measurements
        key = _constraint_type_label(measurement)
        previous = get(
            summary,
            key,
            _empty_constraint_type_summary(),
        )
        violation_count = previous.violation_count + (measurement.violation > atol ? 1 : 0)

        summary[key] = (
            count = previous.count + 1,
            violation_count = violation_count,
            max_violation = max(previous.max_violation, measurement.violation),
            total_violation = previous.total_violation + measurement.violation,
        )
    end

    return summary
end

function _empty_constraint_type_summary()::ConstraintTypeSummary
    return (count = 0, violation_count = 0, max_violation = 0.0, total_violation = 0.0)
end

function _constraint_violation(
    source_model::MOI.ModelLike,
    ci::MOI.ConstraintIndex{F,S},
    f::F,
    set::S,
    values::AbstractDict{VI};
    soft::Bool = false,
) where {F,S}
    value = MOIU.eval_variables(source_model, f) do vi
        return _projected_value(values, vi)
    end

    violation, raw_residual = _violation_and_residual(value, set)

    return ConstraintViolation(
        ci,
        F,
        S,
        value,
        raw_residual,
        Float64(violation),
        _referenced_variable_values(f, values),
        soft,
    )
end

function _projected_value(values::AbstractDict{VI}, vi::VI)
    haskey(values, vi) || error("Projected source state is missing variable $vi")

    return values[vi]
end

_set_value(value, ::MOI.LessThan{T}) where {T} = convert(T, value)
_set_value(value, ::MOI.GreaterThan{T}) where {T} = convert(T, value)
_set_value(value, ::MOI.EqualTo{T}) where {T} = convert(T, value)
_set_value(value, ::MOI.Interval{T}) where {T} = convert(T, value)
_set_value(value, ::MOI.Semicontinuous{T}) where {T} = convert(T, value)
_set_value(value, ::MOI.Semiinteger{T}) where {T} = convert(T, value)
_set_value(value, set) = value

function _distance_to_set(value, set)
    return MOIU.distance_to_set(_set_value(value, set), set)
end

function _violation_and_residual(value, set)
    return _distance_to_set(value, set), _raw_residual(value, set)
end

_raw_residual(value, set) = _distance_to_set(value, set)
_raw_residual(value, set::MOI.LessThan) = _set_value(value, set) - set.upper
_raw_residual(value, set::MOI.GreaterThan) = set.lower - _set_value(value, set)
_raw_residual(value, set::MOI.EqualTo) = _set_value(value, set) - set.value

function _raw_residual(value, set::MOI.Interval)
    x = _set_value(value, set)

    if x < set.lower
        return set.lower - x
    elseif x > set.upper
        return x - set.upper
    else
        return zero(x)
    end
end

function _violation_and_residual(value::AbstractVector, set::MOI.SOS1)
    magnitudes = abs.(value)

    if isempty(magnitudes)
        return 0.0, 0.0
    end

    residual = sum(magnitudes; init = zero(eltype(magnitudes))) - maximum(magnitudes)

    return residual, residual
end

function _violation_and_residual(value::AbstractVector, set::MOI.Indicator{A,S}) where {A,S}
    active = if A === MOI.ACTIVATE_ON_ONE
        value[1] >= 0.5
    elseif A === MOI.ACTIVATE_ON_ZERO
        value[1] < 0.5
    else
        error("Unsupported indicator activation type $A")
    end

    if !active
        return 0.0, 0.0
    end

    inner_value = length(value) == 2 ? value[2] : value[2:end]

    return _violation_and_residual(inner_value, set.set)
end

_function_variables(vi::VI) = VI[vi]

function _function_variables(f::MOI.ScalarAffineFunction)
    return _sort_variables([term.variable for term in f.terms])
end

function _function_variables(f::MOI.ScalarQuadraticFunction)
    variables = VI[]

    append!(variables, [term.variable for term in f.affine_terms])

    for term in f.quadratic_terms
        push!(variables, term.variable_1)
        push!(variables, term.variable_2)
    end

    return _sort_variables(variables)
end

function _function_variables(f::MOI.ScalarNonlinearFunction)
    variables = VI[]
    Compiler._collect_snf_variables!(variables, f)

    return _sort_variables(variables)
end

function _function_variables(f::MOI.VectorOfVariables)
    return _sort_variables(f.variables)
end

function _function_variables(f::MOI.VectorAffineFunction)
    return _sort_variables([term.scalar_term.variable for term in f.terms])
end

function _function_variables(f::MOI.VectorQuadraticFunction)
    variables = VI[]

    append!(variables, [term.scalar_term.variable for term in f.affine_terms])

    for term in f.quadratic_terms
        push!(variables, term.scalar_term.variable_1)
        push!(variables, term.scalar_term.variable_2)
    end

    return _sort_variables(variables)
end

_function_variables(::MOI.AbstractFunction) = VI[]

function _sort_variables(variables)
    return sort!(collect(Set(variables)); by = vi -> vi.value)
end

function _referenced_variable_values(f::MOI.AbstractFunction, values::AbstractDict{VI})
    return Dict{VI,Any}(vi => _projected_value(values, vi) for vi in _function_variables(f))
end

# Feasibility conclusions are cached per solve; `MOI.optimize!` and
# `Compiler.reset!` clear these entries before results can change.
function _reset_feasibility_caches!(model::Virtual.Model)
    delete!(model.moi_settings, :feasibility_report)
    delete!(model.moi_settings, :primal_feasibility)

    return nothing
end

function _result_is_feasible(model::Virtual.Model, result::Integer)
    cache = get!(model.moi_settings, :primal_feasibility, Dict{Int,Bool}())::Dict{Int,Bool}

    return get!(cache, Int(result)) do
        is_feasible(model; result, atol = _FEASIBILITY_ATOL)
    end
end

function _auto_feasibility_report!(model::Virtual.Model)
    MOI.get(model, Attributes.AutoFeasibilityReport()) || return nothing

    isnothing(model.optimizer) && return nothing

    _result_count(model) > 0 || return nothing

    report = feasibility_report(model)

    if report.feasible_count < report.result_count && Attributes.warnings(model)
        infeasible_count = report.result_count - report.feasible_count

        @warn(
            "$(infeasible_count) of $(report.result_count) sampled result(s) violate source constraints " *
            "(max violation ≈ $(report.max_violation)). Inspect `ToQUBO.feasibility_report(model)` or " *
            "`ToQUBO.violations(model; result = i)`, and consider raising the affected constraint penalties.",
        )
    end

    return nothing
end

function MOI.get(
    model::Virtual.Model{T},
    attr::Attributes.SourceObjectiveValue,
) where {T}
    result = attr.result_index

    # MOI-conventional error for result-indexed attributes, matching
    # `MOI.ObjectiveValue`/`MOI.VariablePrimal`; the kwarg-based analysis
    # helpers keep their plain errors.
    MOI.check_result_index_bounds(model, attr)

    values = _projected_result_values(model, result)

    F = MOI.get(model.source_model, MOI.ObjectiveFunctionType())
    f = MOI.get(model.source_model, MOI.ObjectiveFunction{F}())

    value = MOIU.eval_variables(model.source_model, f) do vi
        return _projected_value(values, vi)
    end

    if !(value isa AbstractVector) && !Attributes._has_custom_objective_scalarization(model)
        return convert(T, value)
    end

    comp_vals = value isa AbstractVector ? value : (value,)
    isempty(comp_vals) && return zero(T)

    target_sense = MOI.get(model, MOI.ObjectiveSense()) === MOI.MAX_SENSE ?
        MOI.MAX_SENSE : MOI.MIN_SENSE
    total = zero(T)

    for (i, val_i) in enumerate(comp_vals)
        w_i = Attributes.objective_weight(model, i)
        s_i = Attributes.objective_sense(model, i)
        rel_sign = s_i === target_sense ? one(T) : -one(T)
        total += (rel_sign * w_i) * convert(T, val_i)
    end

    return total
end

@doc raw"""
    source_objective_value(model; result::Integer = 1)
    source_objective_value(model, objective_index::Integer; result::Integer = 1)

Return the source-model objective function evaluated at the projected
source-variable values of sampled result `result`.

When `objective_index` is omitted, returns the scalar (or scalarized)
penalty-free source objective value. When `objective_index` is provided, returns
the unweighted value of the `objective_index`-th objective component.

Unlike `objective_value`/`MOI.ObjectiveValue`, which report the target QUBO
energy including penalty terms introduced by the reformulation, this value is
penalty-free: it is the original objective at the decoded solution.
"""
function source_objective_value(model; result::Integer = 1)
    return source_objective_value(_toqubo_model(model); result)
end

function source_objective_value(model::Virtual.Model; result::Integer = 1)
    return MOI.get(model, Attributes.SourceObjectiveValue(Int(result)))
end

function source_objective_value(
    model,
    objective_index::Integer;
    result::Integer = 1,
)
    return source_objective_value(_toqubo_model(model), objective_index; result)
end

function source_objective_value(
    model::Virtual.Model,
    objective_index::Integer;
    result::Integer = 1,
)
    return MOI.get(
        model,
        Attributes.ObjectiveFunctionValue(Int(objective_index), Int(result)),
    )
end

@doc raw"""
    source_objective_values(model; result::Integer = 1)

Return the vector of unweighted component source-objective values on sampled
result `result`, evaluated by applying each compiled component pseudo-boolean
function to the sampled target state.
"""
function source_objective_values(model; result::Integer = 1)
    return source_objective_values(_toqubo_model(model); result)
end

function source_objective_values(model::Virtual.Model; result::Integer = 1)
    return MOI.get(model, Attributes.ObjectiveFunctionValues(Int(result)))
end
