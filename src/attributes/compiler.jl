abstract type CompilerAttribute <: MOI.AbstractOptimizerAttribute end

@doc raw"""
    ARCHITECTURE()
""" struct ARCHITECTURE <: CompilerAttribute end

function MOI.get(model::VirtualModel, ::ARCHITECTURE)::AbstractArchitecture
    return get(model.compiler_settings, :architecture, GenericArchitecture())
end

function MOI.set(model::VirtualModel, ::ARCHITECTURE, arch::AbstractArchitecture)
    model.compiler_settings[:architecture] = arch

    return nothing
end

@doc raw"""
    DISCRETIZE()

When set, this boolean flag guarantees that every coefficient in the final formulation is an integer.
""" struct DISCRETIZE <: CompilerAttribute end

function MOI.get(model::VirtualModel, ::DISCRETIZE, flag::Bool)::Bool
    return get(model.compiler_settings, :discretize, false)
end

function MOI.set(model::VirtualModel, ::DISCRETIZE, flag::Bool)
    model.compiler_settings[:discretize] = flag

    return nothing
end

@doc raw"""
    QUADRATIZE()

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
    QUADRATIZATION_METHOD()

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
    STABLE_QUADRATIZATION()

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
    DEFAULT_VARIABLE_ENCODING_METHOD()
""" struct DEFAULT_VARIABLE_ENCODING_METHOD <: CompilerAttribute end

function MOI.get(model::VirtualModel, ::DEFAULT_VARIABLE_ENCODING_METHOD)::Encoding
    return get(model.compiler_settings, :default_variable_encoding_method, Binary())
end

function MOI.set(model::VirtualModel, ::DEFAULT_VARIABLE_ENCODING_METHOD, e::Encoding)
    model.compiler_settings[:default_variable_encoding_method] = e

    return nothing
end

@doc raw"""
    DEFAULT_VARIABLE_ENCODING_ATOL()
""" struct DEFAULT_VARIABLE_ENCODING_ATOL <: CompilerAttribute end

function MOI.get(model::VirtualModel{T}, ::DEFAULT_VARIABLE_ENCODING_ATOL)::T where {T}
    return get(model.compiler_settings, :default_variable_encoding_atol, T(1E-2))
end

function MOI.set(model::VirtualModel{T}, ::DEFAULT_VARIABLE_ENCODING_ATOL, τ::T) where {T}
    model.compiler_settings[:default_variable_encoding_atol] = τ

    return nothing
end

abstract type CompilerVariableAttribute <: MOI.AbstractVariableAttribute end

@doc raw"""
    VARIABLE_ENCODING_ATOL()
""" struct VARIABLE_ENCODING_ATOL <: CompilerVariableAttribute end

function MOI.get(model::VirtualModel{T}, ::VARIABLE_ENCODING_ATOL, vi::VI)::T where {T}
    attr = :variable_encoding_atol

    if !haskey(model.variable_settings, attr) || !haskey(model.variable_settings[attr], vi)
        return MOI.get(model, DEFAULT_VARIABLE_ENCODING_ATOL())
    else
        return model.variable_settings[attr][vi]
    end
end

function MOI.set(model::VirtualModel{T}, ::VARIABLE_ENCODING_ATOL, vi::VI, τ::T) where {T}
    attr = :variable_encoding_atol

    if !haskey(model.variable_settings, attr)
        model.variable_settings[attr] = Dict{VI,Any}(vi => τ)
    else
        model.variable_settings[attr][vi] = τ
    end

    return nothing
end

@doc raw"""
    VARIABLE_ENCODING_METHOD()

Available methods are:
- [`Binary`](@ref) (default)
- [`Unary`](@ref)
- [`Arithmetic`](@ref)
- [`OneHot`](@ref)
- [`DomainWall`](@ref)
- [`Bounded`](@ref)

The [`Binary`](@ref), [`Unary`](@ref) and [`Arithmetic`](@ref) encodings can have their
expansion coefficients bounded by parametrizing the [`Bounded`](@ref) encoding.
""" struct VARIABLE_ENCODING_METHOD <: CompilerVariableAttribute end

function MOI.get(model::VirtualModel, ::VARIABLE_ENCODING_METHOD, vi::VI)::Encoding
    attr = :variable_encoding_method

    if !haskey(model.variable_settings, attr) || !haskey(model.variable_settings[attr], vi)
        return MOI.get(model, DEFAULT_VARIABLE_ENCODING_METHOD())
    else
        return model.variable_settings[attr][vi]
    end
end

function MOI.set(model::VirtualModel, ::VARIABLE_ENCODING_METHOD, vi::VI, e::Encoding)
    attr = :variable_encoding_method

    if !haskey(model.variable_settings, attr)
        model.variable_settings[attr] = Dict{VI,Any}(vi => e)
    else
        model.variable_settings[attr][vi] = e
    end

    return nothing
end

@doc raw"""
    VARIABLE_ENCODING_PENALTY()

Allows the user to set and retrieve the coefficients used for encoding variables when additional
constraints are involved.
""" struct VARIABLE_ENCODING_PENALTY <: CompilerVariableAttribute end

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

abstract type CompilerConstraintAttribute <: MOI.AbstractConstraintAttribute end

@doc raw"""
    CONSTRAINT_ENCODING_PENALTY()

Allows the user to set and retrieve the coefficients used for encoding constraints.
""" struct CONSTRAINT_ENCODING_PENALTY <: CompilerConstraintAttribute end

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
