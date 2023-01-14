abstract type CompilerAttribute <: MOI.AbstractOptimizerAttribute end

struct QUADRATIZE <: CompilerAttribute end

function MOI.get(model::VirtualQUBOModel, ::QUADRATIZE)::Bool
    return get(model.compiler_settings, :quadratize, false)
end

function MOI.set(model::VirtualQUBOModel, ::QUADRATIZE, flag::Bool)
    model.compiler_settings[:quadratize] = flag

    return nothing
end

struct QUADRATIZATION_METHOD <: CompilerAttribute end

function MOI.get(model::VirtualQUBOModel, ::QUADRATIZATION_METHOD)
    return get(model.compiler_settings, :quadratization_method, PBO.INFER)
end

function MOI.set(
    model::VirtualQUBOModel,
    ::QUADRATIZATION_METHOD,
    ::Type{method},
) where {method<:PBO.QuadratizationMethod}
    model.compiler_settings[:quadratization_method] = method

    return nothing
end

struct STABLE_QUADRATIZATION <: CompilerAttribute end

function MOI.get(model::VirtualQUBOModel, ::STABLE_QUADRATIZATION)::Bool
    return get(model.compiler_settings, :stable_quadratization, false)
end

function MOI.set(model::VirtualQUBOModel, ::STABLE_QUADRATIZATION, flag::Bool)
    model.compiler_settings[:stable_quadratization] = flag

    return nothing
end

struct DISCRETIZE <: CompilerAttribute end

function MOI.get(model::VirtualQUBOModel, ::DISCRETIZE)::Bool
    return get(model.compiler_settings, :discretize, false)
end

function MOI.set(model::VirtualQUBOModel, ::DISCRETIZE, flag::Bool)
    model.compiler_settings[:discretize] = flag

    return nothing
end

struct DEFAULT_VARIABLE_ENCODING <: CompilerAttribute end

function MOI.get(model::VirtualQUBOModel, ::DEFAULT_VARIABLE_ENCODING)::Encoding
    return get(model.compiler_settings, :default_variable_encoding, Binary())
end

function MOI.set(model::VirtualQUBOModel, ::DEFAULT_VARIABLE_ENCODING, e::Encoding)
    model.compiler_settings[:default_variable_encoding] = e

    return nothing
end

abstract type CompilerVariableAttribute <: CompilerAttribute end

struct VARIABLE_ENCODING <: CompilerVariableAttribute end

function MOI.get(model::VirtualQUBOModel, ::VARIABLE_ENCODING, vi::VI)::Encoding
    attr = :variable_encoding

    if !haskey(model.variable_settings, attr) || !haskey(model.variable_settings[attr], vi)
        return MOI.get(model, DEFAULT_VARIABLE_ENCODING())
    else
        return model.variable_settings[attr][vi]
    end
end

function MOI.set(model::VirtualQUBOModel, ::VARIABLE_ENCODING, vi::VI, e::Encoding)
    attr = :variable_encoding

    if !haskey(model.variable_settings, attr)
        model.variable_settings[attr] = Dict{VI,Any}(vi => e)
    else
        model.variable_settings[attr][vi] = e
    end

    return nothing
end

struct VARIABLE_ENCODING_PENALTY <: CompilerVariableAttribute end

function MOI.get(model::VirtualQUBOModel{T}, ::VARIABLE_ENCODING_PENALTY, vi::VI) where {T}
    return model.θ[vi]::T
end

function MOI.set(
    model::VirtualQUBOModel{T},
    ::VARIABLE_ENCODING_PENALTY,
    vi::VI,
    θ::T,
) where {T}
    model.θ[vi] = θ

    return nothing
end

abstract type CompilerConstraintAttribute <: MOI.AbstractConstraintAttribute end

struct CONSTRAINT_PENALTY <: CompilerConstraintAttribute end

function MOI.get(model::VirtualQUBOModel{T}, ::CONSTRAINT_PENALTY, ci::CI) where {T}
    return model.ρ[ci]
end

function MOI.set(model::VirtualQUBOModel{T}, ::CONSTRAINT_PENALTY, ci::CI, ρ::T) where {T}
    model.ρ[ci] = ρ

    return nothing
end

# -*- MOI Attribute Forwarding -*- #
# function MOI.get(model::VirtualQUBOModel, attr::MOI.AbstractOptimizerAttribute)
#     return MOI.get(MOI.get(model, SourceModel()), attr)
# end

# function MOI.set(model::VirtualQUBOModel, attr::MOI.AbstractOptimizerAttribute, value)
#     MOI.set(MOI.get(model, SourceModel()), attr, value)

#     return nothing
# end

# function MOI.get(model::VirtualQUBOModel, attr::MOI.AbstractVariableAttribute, vi::VI)
#     return MOI.get(model.optimizer, attr, vi)
# end

# function MOI.set(
#     model::VirtualQUBOModel,
#     attr::MOI.AbstractVariableAttribute,
#     vi::VI,
#     value,
# )
#     MOI.set(model.optimizer, attr, vi, value)

#     return nothing
# end

# function MOI.get(model::VirtualQUBOModel, attr::MOI.AbstractConstraintAttribute, ci::CI)
#     return MOI.get(model.optimizer, attr, ci)
# end

# function MOI.set(
#     model::VirtualQUBOModel,
#     attr::MOI.AbstractConstraintAttribute,
#     ci::CI,
#     value,
# )
#     MOI.set(model.optimizer, attr, ci, value)

#     return nothing
# end

const QUBO_NORMAL_FORM{T} = Tuple{Int,Dict{Int,T},Dict{Tuple{Int,Int},T},T,T}

struct QUBOTOOLS_NORMAL_FORM <: CompilerAttribute end

function MOI.get(
    model::VirtualQUBOModel{T},
    ::QUBOTOOLS_NORMAL_FORM,
)::QUBO_NORMAL_FORM{T} where {T}
    target_model = MOI.get(model, TargetModel())

    n = MOI.get(target_model, MOI.NumberOfVariables())
    F = MOI.get(target_model, MOI.ObjectiveFunctionType())
    f = MOI.get(target_model, MOI.ObjectiveFunction{F}())

    linear_terms    = sizehint!(Dict{Int,T}(), length(f.affine_terms))
    quadratic_terms = sizehint!(Dict{Tuple{Int,Int},T}(), length(f.quadratic_terms))

    for a in f.affine_terms
        c = a.coefficient
        i = a.variable.value

        linear_terms[i] = get(linear_terms, i, zero(T)) + c
    end

    for q in f.quadratic_terms
        c = q.coefficient
        i = q.variable_1.value
        j = q.variable_2.value

        if i == j
            linear_terms[i] = get(linear_terms, i, zero(T)) + c / 2
        elseif i > j
            quadratic_terms[(j, i)] = get(quadratic_terms, (j, i), zero(T)) + c
        else
            quadratic_terms[(i, j)] = get(quadratic_terms, (i, j), zero(T)) + c
        end
    end

    scale  = one(T)
    offset = f.constant

    return (n, linear_terms, quadratic_terms, scale, offset)
end

# MOIU.map_indices(::Any, x::QUBO_NORMAL_FORM{T}) where {T} = x
MOIU.map_indices(::MOIU.IndexMap, x::QUBO_NORMAL_FORM{T}) where {T} = x
