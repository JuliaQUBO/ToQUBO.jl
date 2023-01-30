abstract type CompilerAttribute <: MOI.AbstractOptimizerAttribute end

function MOI.get(::VirtualModel, ::A) where {A<:CompilerAttribute}
    error("Invalid compiler attribute '$A'")
end

function MOI.set(::VirtualModel, ::A, ::Any) where {A<:CompilerAttribute}
    error("Invalid compiler attribute '$A'")
end

function MOI.supports(::VirtualModel, ::CompilerAttribute)
    return true
end

abstract type CompilerVariableAttribute <: MOI.AbstractVariableAttribute end

function MOI.get(::VirtualModel, ::A, ::VI) where {A<:CompilerVariableAttribute}
    error("Invalid compiler variable attribute '$A'")
end

function MOI.set(::VirtualModel, ::A, ::VI, ::Any) where {A<:CompilerVariableAttribute}
    error("Invalid compiler variable attribute '$A'")
end

function MOI.supports(::VirtualModel, ::CompilerVariableAttribute, ::Type{VI})
    return true
end

abstract type CompilerConstraintAttribute <: MOI.AbstractConstraintAttribute end

function MOI.get(::VirtualModel, ::A, ::CI) where {A<:CompilerConstraintAttribute}
    error("Invalid compiler constraint attribute '$A'")
end

function MOI.set(::VirtualModel, ::A, ::CI, ::Any) where {A<:CompilerConstraintAttribute}
    error("Invalid compiler constraint attribute '$A'")
end

function MOI.supports(::VirtualModel, ::CompilerConstraintAttribute, ::Type{<:CI})
    return true
end

@doc raw"""
    QUADRATIZE <: CompilerAttribute

Boolean flag to conditionally perform the quadratization step.
Is automatically set by the compiler when high-order functions are generated.
""" struct QUADRATIZE <: CompilerAttribute end

function MOI.get(model::VirtualModel, ::QUADRATIZE)::Bool
    return get(model.compiler_settings, :quadratize, false)
end

function MOI.set(model::VirtualModel, ::QUADRATIZE, flag::Bool)
    model.compiler_settings[:quadratize] = flag

    return nothing
end

@doc raw"""
    QUADRATIZATION_METHOD <: CompilerAttribute

Defines which quadratization method to use.
Available options are defined in the [`PBO`](@ref) submodule.
""" struct QUADRATIZATION_METHOD <: CompilerAttribute end

function MOI.get(model::VirtualModel, ::QUADRATIZATION_METHOD)
    return get(model.compiler_settings, :quadratization_method, PBO.INFER)
end

function MOI.set(
    model::VirtualModel,
    ::QUADRATIZATION_METHOD,
    ::Type{method},
) where {method<:PBO.QuadratizationMethod}
    model.compiler_settings[:quadratization_method] = method

    return nothing
end

@doc raw"""
    STABLE_QUADRATIZATION <: CompilerAttribute

When set, this boolean flag enables stable quadratization methods, thus yielding predictable results.
This is intended to be used during tests or other situations where deterministic output is desired.
On the other hand, usage in production is not recommended since it requires increased memory and processing resources.
""" struct STABLE_QUADRATIZATION <: CompilerAttribute end

function MOI.get(model::VirtualModel, ::STABLE_QUADRATIZATION)::Bool
    return get(model.compiler_settings, :stable_quadratization, false)
end

function MOI.set(model::VirtualModel, ::STABLE_QUADRATIZATION, flag::Bool)
    model.compiler_settings[:stable_quadratization] = flag

    return nothing
end

@doc raw"""
    DISCRETIZE
""" struct DISCRETIZE <: CompilerAttribute end

struct DEFAULT_VARIABLE_ENCODING <: CompilerAttribute end

function MOI.get(model::VirtualModel, ::DEFAULT_VARIABLE_ENCODING)::Encoding
    return get(model.compiler_settings, :default_variable_encoding, Binary())
end

function MOI.set(model::VirtualModel, ::DEFAULT_VARIABLE_ENCODING, e::Encoding)
    model.compiler_settings[:default_variable_encoding] = e

    return nothing
end

struct VARIABLE_ENCODING <: CompilerVariableAttribute end

function MOI.get(model::VirtualModel, ::VARIABLE_ENCODING, vi::VI)::Encoding
    attr = :variable_encoding

    if !haskey(model.variable_settings, attr) || !haskey(model.variable_settings[attr], vi)
        return MOI.get(model, DEFAULT_VARIABLE_ENCODING())
    else
        return model.variable_settings[attr][vi]
    end
end

function MOI.set(model::VirtualModel, ::VARIABLE_ENCODING, vi::VI, e::Encoding)
    attr = :variable_encoding

    if !haskey(model.variable_settings, attr)
        model.variable_settings[attr] = Dict{VI,Any}(vi => e)
    else
        model.variable_settings[attr][vi] = e
    end

    return nothing
end

struct VARIABLE_ENCODING_PENALTY <: CompilerVariableAttribute end

function MOI.get(model::VirtualModel{T}, ::VARIABLE_ENCODING_PENALTY, vi::VI) where {T}
    return model.θ[vi]::T
end

function MOI.set(
    model::VirtualModel{T},
    ::VARIABLE_ENCODING_PENALTY,
    vi::VI,
    θ::T,
) where {T}
    model.θ[vi] = θ

    return nothing
end

MOI.is_set_by_optimize(::VARIABLE_ENCODING_PENALTY) = true

struct CONSTRAINT_ENCODING_PENALTY <: CompilerConstraintAttribute end

function MOI.get(model::VirtualModel{T}, ::CONSTRAINT_ENCODING_PENALTY, ci::CI) where {T}
    return model.ρ[ci]
end

function MOI.set(
    model::VirtualModel{T},
    ::CONSTRAINT_ENCODING_PENALTY,
    ci::CI,
    ρ::T,
) where {T}
    model.ρ[ci] = ρ

    return nothing
end

MOI.is_set_by_optimize(::CONSTRAINT_ENCODING_PENALTY) = true

# -*- MOI Attribute Forwarding -*- #
# function MOI.get(model::VirtualModel, attr::MOI.AbstractOptimizerAttribute)
#     return MOI.get(model.source_model, attr)
# end

# function MOI.set(model::VirtualModel, attr::MOI.AbstractOptimizerAttribute, value)
#     MOI.set(model.source_model, attr, value)

#     return nothing
# end

# function MOI.get(model::VirtualModel, attr::MOI.AbstractVariableAttribute, vi::VI)
#     return MOI.get(model.optimizer, attr, vi)
# end

# function MOI.set(
#     model::VirtualModel,
#     attr::MOI.AbstractVariableAttribute,
#     vi::VI,
#     value,
# )
#     MOI.set(model.optimizer, attr, vi, value)

#     return nothing
# end

# function MOI.get(model::VirtualModel, attr::MOI.AbstractConstraintAttribute, ci::CI)
#     return MOI.get(model.optimizer, attr, ci)
# end

# function MOI.set(
#     model::VirtualModel,
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
    model::VirtualModel{T},
    ::QUBOTOOLS_NORMAL_FORM,
)::QUBO_NORMAL_FORM{T} where {T}
    target_model = model.target_model

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

@doc raw"""
    ARCHITECTURE <: CompilerAttribute
""" struct ARCHITECTURE <: CompilerAttribute end

function MOI.get(model::VirtualModel, ::ARCHITECTURE)::AbstractArchitecture
    return get(model.compiler_settings, :architecture, GenericArchitecture())
end

function MOI.set(model::VirtualModel, ::DISCRETIZE, arch::AbstractArchitecture)
    model.compiler_settings[:architecture] = arch

    return nothing
end