const _TOQUBO_METADATA_KEY = "toqubo"
const _REFORMULATION_METADATA_KEY = "reformulation"
const _REFORMULATION_SCHEMA_VERSION = 1

@doc raw"""
    reformulation_metadata(model_or_metadata)

Return JSON-compatible ToQUBO reformulation metadata. For a live
`ToQUBO.Optimizer`, the metadata is generated from the compiled virtual model.
For a `QUBOTools.AbstractModel` or a metadata dictionary, the metadata is read
from `metadata["toqubo"]["reformulation"]`. `QUBOTools.backend` skips this full
metadata payload by default; call `QUBOTools.backend(model; full_metadata = true)`
when a returned QUBOTools model needs embedded reformulation metadata.

The `applied_penalties` section is a convenience view. Its entries duplicate
the applied penalty coefficients also attached to the corresponding variable,
constraint, and slack-variable metadata records.
"""
function reformulation_metadata end

@doc raw"""
    original_variables(model_or_metadata)

Return the original source variable identities in compiler order.

For a live `ToQUBO.Optimizer`, the result is a vector of `MOI.VariableIndex`
values. For serialized metadata or a `QUBOTools.AbstractModel`, the result is a
vector of integer variable ids.
"""
function original_variables end

@doc raw"""
    auxiliary_variables(model_or_metadata)

Return target QUBO variables that are not owned by original source variables.

For a live `ToQUBO.Optimizer`, the result is a vector of `MOI.VariableIndex`
values. For serialized metadata or a `QUBOTools.AbstractModel`, the result is a
vector of integer target variable ids.
"""
function auxiliary_variables end

@doc raw"""
    project_original_state(model_or_metadata, qubo_state)

Project a full QUBO state onto the original source variables using the stored
encoding expansions.

`qubo_state` may be a vector indexed by target QUBO variable id, or a dictionary
keyed by integer target ids, string target ids, or `MOI.VariableIndex` values.
For a live `ToQUBO.Optimizer`, the result is keyed by `MOI.VariableIndex`. For
serialized metadata or a `QUBOTools.AbstractModel`, the result is keyed by
integer source variable ids.
"""
function project_original_state end

function _type_name(x)
    return string(nameof(typeof(x)))
end

function _type_path(x)
    return string(typeof(x))
end

function _sense_metadata(sense::MOI.OptimizationSense)
    if sense === MOI.MIN_SENSE
        return "min"
    elseif sense === MOI.MAX_SENSE
        return "max"
    elseif sense === MOI.FEASIBILITY_SENSE
        return "feasibility"
    else
        return string(sense)
    end
end

function _constraint_ref(ci::MOI.ConstraintIndex{F,S}) where {F,S}
    return Dict{String,Any}(
        "id" => ci.value,
        "function_type" => string(F),
        "set_type" => string(S),
    )
end

function _owner_ref(::Nothing)
    return nothing
end

function _owner_ref(vi::VI)
    return Dict{String,Any}("type" => "source_variable", "id" => vi.value)
end

function _owner_ref(ci::MOI.ConstraintIndex)
    return Dict{String,Any}("type" => "constraint", "constraint" => _constraint_ref(ci))
end

_owner_role(::Nothing) = "quadratization"
_owner_role(::VI) = "source"
_owner_role(::MOI.ConstraintIndex) = "constraint"

function _variable_name(model::MOI.ModelLike, vi::VI)
    try
        name = MOI.get(model, MOI.VariableName(), vi)

        return isempty(name) ? nothing : name
    catch
        return nothing
    end
end

function _term_variable_ids(term)
    if term === nothing || isempty(term)
        return Int[]
    else
        return sort!([vi.value for vi in term])
    end
end

function _pbf_terms(f::PBO.PBF)
    terms = Dict{String,Any}[]

    for (term, coefficient) in f
        iszero(coefficient) && continue

        push!(
            terms,
            Dict{String,Any}(
                "variables" => _term_variable_ids(term),
                "coefficient" => coefficient,
            ),
        )
    end

    sort!(terms; by = term -> (length(term["variables"]), join(term["variables"], ",")))

    return terms
end

function _pbf_variable_ids(f::PBO.PBF)
    ids = Set{Int}()

    for (term, coefficient) in f
        iszero(coefficient) && continue

        union!(ids, _term_variable_ids(term))
    end

    return sort!(collect(ids))
end

function _encoding_metadata(e::Encoding.VariableEncodingMethod)
    return Dict{String,Any}(
        "type" => _type_name(e),
        "julia_type" => _type_path(e),
    )
end

function _constraint_penalty_method_metadata(method::Attributes.ConstraintPenaltyMethod)
    return Dict{String,Any}(
        "type" => _type_name(method),
        "julia_type" => _type_path(method),
    )
end

function _constraint_order(model::MOI.ModelLike)
    constraints = Dict{String,Any}[]

    for (F, S) in MOI.get(model, MOI.ListOfConstraintTypesPresent())
        for ci in MOI.get(model, MOI.ListOfConstraintIndices{F,S}())
            push!(constraints, _constraint_ref(ci))
        end
    end

    sort!(constraints; by = ci -> (ci["id"], ci["function_type"], ci["set_type"]))

    return constraints
end

function _source_metadata(model::Virtual.Model)
    variables = original_variables(model)

    return Dict{String,Any}(
        "num_variables" => length(variables),
        "variable_order" => [vi.value for vi in variables],
        "constraints" => _constraint_order(model.source_model),
    )
end

function _target_metadata(model::Virtual.Model{T}) where {T}
    variables = MOI.get(model.target_model, MOI.ListOfVariableIndices())
    objective = MOI.get(model.target_model, MOI.ObjectiveFunction{SQF{T}}())

    # ToQUBO adds penalty and quadratization terms, but does not rescale the
    # source objective during reformulation.
    return Dict{String,Any}(
        "num_variables" => length(variables),
        "variable_order" => [vi.value for vi in variables],
        "sense" => _sense_metadata(MOI.get(model.target_model, MOI.ObjectiveSense())),
        "scale" => one(T),
        "offset" => objective.constant,
    )
end

function _variable_encoding_entry(model::Virtual.Model, vi::VI)
    entry = Dict{String,Any}(
        "id" => vi.value,
        "name" => _variable_name(model.source_model, vi),
        "encoded" => false,
        "target_variables" => Int[],
        "encoding" => nothing,
        "expansion_variables" => Int[],
        "expansion_terms" => Dict{String,Any}[],
        "penalty" => nothing,
        "penalty_terms" => nothing,
    )

    if haskey(model.source, vi)
        v = model.source[vi]

        entry["encoded"] = true
        entry["target_variables"] = [yi.value for yi in Virtual.target(v)]
        entry["encoding"] = _encoding_metadata(Virtual.encoding(v))
        entry["expansion_variables"] = _pbf_variable_ids(Virtual.expansion(v))
        entry["expansion_terms"] = _pbf_terms(Virtual.expansion(v))

        if haskey(model.h, vi)
            entry["penalty"] = get(model.θ, vi, nothing)
            entry["penalty_terms"] = _pbf_terms(model.h[vi])
        end
    end

    return entry
end

function _original_variable_entries(model::Virtual.Model)
    return [_variable_encoding_entry(model, vi) for vi in original_variables(model)]
end

function _target_variable_entries(model::Virtual.Model)
    entries = Dict{String,Any}[]

    for vi in MOI.get(model.target_model, MOI.ListOfVariableIndices())
        v = get(model.target, vi, nothing)
        owner = isnothing(v) ? nothing : Virtual.source(v)

        push!(
            entries,
            Dict{String,Any}(
                "id" => vi.value,
                "role" => _owner_role(owner),
                "owner" => _owner_ref(owner),
                "encoding" => isnothing(v) ? nothing : _encoding_metadata(Virtual.encoding(v)),
            ),
        )
    end

    sort!(entries; by = entry -> entry["id"])

    return entries
end

function _auxiliary_variable_entries(target_variables)
    return [entry for entry in target_variables if entry["role"] != "source"]
end

function _constraint_sort_key(ci::MOI.ConstraintIndex)
    ref = _constraint_ref(ci)

    return (ref["id"], ref["function_type"], ref["set_type"])
end

function _slack_variable_entries(model::Virtual.Model)
    entries = Dict{String,Any}[]

    for (ci, v) in sort!(collect(model.slack); by = pair -> _constraint_sort_key(first(pair)))
        entry = Dict{String,Any}(
            "constraint" => _constraint_ref(ci),
            "target_variables" => [vi.value for vi in Virtual.target(v)],
            "encoding" => _encoding_metadata(Virtual.encoding(v)),
            "expansion_variables" => _pbf_variable_ids(Virtual.expansion(v)),
            "expansion_terms" => _pbf_terms(Virtual.expansion(v)),
            "penalty" => get(model.η, ci, nothing),
            "penalty_terms" => nothing,
        )

        if haskey(model.s, ci)
            entry["penalty_terms"] = _pbf_terms(model.s[ci])
        end

        push!(entries, entry)
    end

    return entries
end

function _constraint_encoding_entries(model::Virtual.Model)
    entries = Dict{String,Any}[]

    for (ci, terms) in sort!(collect(model.g); by = pair -> _constraint_sort_key(first(pair)))
        push!(
            entries,
            Dict{String,Any}(
                "constraint" => _constraint_ref(ci),
                "method" => _constraint_penalty_method_metadata(
                    Attributes.constraint_encoding_method(model, ci),
                ),
                "penalty" => get(model.ρ, ci, nothing),
                "terms" => _pbf_terms(terms),
            ),
        )
    end

    return entries
end

function _applied_penalty_metadata(model::Virtual.Model)
    constraints = Dict{String,Any}[]

    for (ci, ρ) in sort!(collect(model.ρ); by = pair -> _constraint_sort_key(first(pair)))
        push!(
            constraints,
            Dict{String,Any}(
                "constraint" => _constraint_ref(ci),
                "penalty" => ρ,
            ),
        )
    end

    variables = Dict{String,Any}[]

    for (vi, θ) in sort!(collect(model.θ); by = pair -> first(pair).value)
        push!(
            variables,
            Dict{String,Any}(
                "variable" => vi.value,
                "penalty" => θ,
            ),
        )
    end

    slack_variables = Dict{String,Any}[]

    for (ci, η) in sort!(collect(model.η); by = pair -> _constraint_sort_key(first(pair)))
        push!(
            slack_variables,
            Dict{String,Any}(
                "constraint" => _constraint_ref(ci),
                "penalty" => η,
            ),
        )
    end

    return Dict{String,Any}(
        "constraints" => constraints,
        "variables" => variables,
        "slack_variables" => slack_variables,
    )
end

function reformulation_metadata(model::Virtual.Model)
    target_variables = _target_variable_entries(model)

    return Dict{String,Any}(
        "schema_version" => _REFORMULATION_SCHEMA_VERSION,
        "package" => Dict{String,Any}(
            "name" => "ToQUBO",
            "version" => string(__version__()),
        ),
        "source" => _source_metadata(model),
        "target" => _target_metadata(model),
        "original_variables" => _original_variable_entries(model),
        "target_variables" => target_variables,
        "auxiliary_variables" => _auxiliary_variable_entries(target_variables),
        "slack_variables" => _slack_variable_entries(model),
        "constraint_encodings" => _constraint_encoding_entries(model),
        "applied_penalties" => _applied_penalty_metadata(model),
        "guarantees" => Dict{String,Any}(
            "project_original_state" => true,
            "auxiliary_consistency" => "encoding-specific",
            "auxiliary_repair" => "not provided",
        ),
    )
end

function reformulation_metadata(model::QUBOTools.AbstractModel)
    return reformulation_metadata(QUBOTools.metadata(model))
end

function reformulation_metadata(metadata::AbstractDict)
    if haskey(metadata, _TOQUBO_METADATA_KEY)
        toqubo = metadata[_TOQUBO_METADATA_KEY]

        if toqubo isa AbstractDict && haskey(toqubo, _REFORMULATION_METADATA_KEY)
            return toqubo[_REFORMULATION_METADATA_KEY]
        end
    elseif haskey(metadata, "schema_version") &&
           haskey(metadata, "original_variables") &&
           haskey(metadata, "target_variables")
        return metadata
    end

    error("No ToQUBO reformulation metadata was found")
end

function _attach_reformulation_metadata!(
    target::QUBOTools.AbstractModel,
    source::Virtual.Model,
)
    metadata = QUBOTools.metadata(target)
    toqubo = get!(metadata, _TOQUBO_METADATA_KEY, Dict{String,Any}())

    if !(toqubo isa Dict{String,Any})
        toqubo = Dict{String,Any}("previous" => toqubo)
        metadata[_TOQUBO_METADATA_KEY] = toqubo
    end

    toqubo[_REFORMULATION_METADATA_KEY] = reformulation_metadata(source)

    return target
end

function original_variables(model::Virtual.Model)
    return collect(MOI.get(model.source_model, MOI.ListOfVariableIndices()))
end

function original_variables(model::QUBOTools.AbstractModel)
    return original_variables(reformulation_metadata(model))
end

function original_variables(metadata::AbstractDict)
    data = reformulation_metadata(metadata)

    return [entry["id"] for entry in data["original_variables"]]
end

function auxiliary_variables(model::Virtual.Model)
    data = reformulation_metadata(model)

    return VI[VI(entry["id"]) for entry in data["auxiliary_variables"]]
end

function auxiliary_variables(model::QUBOTools.AbstractModel)
    return auxiliary_variables(reformulation_metadata(model))
end

function auxiliary_variables(metadata::AbstractDict)
    data = reformulation_metadata(metadata)

    return [entry["id"] for entry in data["auxiliary_variables"]]
end

function _state_value(state::AbstractVector, id::Integer)
    if !(1 <= id <= length(state))
        error("QUBO state is missing target variable id $id")
    end

    return state[id]
end

function _state_value(state::AbstractDict, id::Integer)
    if haskey(state, id)
        return state[id]
    elseif haskey(state, VI(id))
        return state[VI(id)]
    elseif haskey(state, string(id))
        return state[string(id)]
    else
        error("QUBO state is missing target variable id $id")
    end
end

function _state_value(state, vi::VI)
    return _state_value(state, vi.value)
end

function _state_value(state::AbstractDict, vi::VI)
    if haskey(state, vi)
        return state[vi]
    else
        return _state_value(state, vi.value)
    end
end

function _evaluate_pbf(f::PBO.PBF{VI,T}, state) where {T}
    value = zero(T)

    for (term, coefficient) in f
        term_value = coefficient

        if term !== nothing
            for vi in term
                term_value *= _state_value(state, vi)
            end
        end

        value += term_value
    end

    return value
end

function _evaluate_serialized_terms(terms::AbstractVector, state)
    value = 0

    for term in terms
        term_value = term["coefficient"]

        for id in term["variables"]
            term_value *= _state_value(state, id)
        end

        value += term_value
    end

    return value
end

function _serialized_entry_encoded(entry::AbstractDict)
    return get(entry, "encoded", !isempty(entry["expansion_terms"]))
end

function project_original_state(model::Virtual.Model, qubo_state)
    values = Dict{VI,Any}()

    for vi in original_variables(model)
        if !haskey(model.source, vi)
            error("Source variable $(vi) has not been encoded")
        end

        values[vi] = _evaluate_pbf(Virtual.expansion(model.source[vi]), qubo_state)
    end

    return values
end

function project_original_state(model::QUBOTools.AbstractModel, qubo_state)
    return project_original_state(reformulation_metadata(model), qubo_state)
end

function project_original_state(metadata::AbstractDict, qubo_state)
    data = reformulation_metadata(metadata)
    values = Dict{Int,Any}()

    for entry in data["original_variables"]
        if !_serialized_entry_encoded(entry)
            error("Source variable $(entry["id"]) has not been encoded")
        end

        values[entry["id"]] = _evaluate_serialized_terms(
            entry["expansion_terms"],
            qubo_state,
        )
    end

    return values
end

function project_original_state(model_or_metadata, sample::QUBOTools.AbstractSample)
    return project_original_state(model_or_metadata, QUBOTools.state(sample))
end
