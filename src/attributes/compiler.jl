module Attributes

import ..ToQUBO:
    ToQUBO,
    Unary,
    Binary,
    Arithmetic,
    OneHot,
    DomainWall,
    Bounded

import MathOptInterface as MOI
const MOIU = MOI.Utilities
const VI = MOI.VariableIndex
const CI = MOI.ConstraintIndex

abstract type CompilerAttribute <: MOI.AbstractOptimizerAttribute end

export
    Architecture,
    Discretize,
    Quadratize,
    QuadratizationMethod,
    StableQuadratization,
    DefaultVariableEncodingATol,
    DefaultVariableEncodingBits,
    DefaultVariableEncodingMethod,
    VariableEncodingATol,
    VariableEncodingBits,
    VariableEncodingMethod,
    VariableEncodingPenalty,
    ConstraintEncodingPenalty,
    QUBONormalForm

@doc raw"""
    Architecture()
""" struct Architecture <: CompilerAttribute end

function MOI.get(model::ToQUBO.VirtualModel, ::Architecture)::ToQUBO.AbstractArchitecture
    return get(model.compiler_settings, :architecture, ToQUBO.GenericArchitecture())
end

function MOI.set(model::ToQUBO.VirtualModel, ::Architecture, arch::ToQUBO.AbstractArchitecture)
    model.compiler_settings[:architecture] = arch

    return nothing
end

@doc raw"""
    Discretize()

When set, this boolean flag guarantees that every coefficient in the final formulation is an integer.
""" struct Discretize <: CompilerAttribute end

function MOI.get(model::ToQUBO.VirtualModel, ::Discretize, flag::Bool)::Bool
    return get(model.compiler_settings, :discretize, false)
end

function MOI.set(model::ToQUBO.VirtualModel, ::Discretize, flag::Bool)
    model.compiler_settings[:discretize] = flag

    return nothing
end

@doc raw"""
    Quadratize()

Boolean flag to conditionally perform the quadratization step.
Is automatically set by the compiler when high-order functions are generated.
""" struct Quadratize <: CompilerAttribute end

function MOI.get(model::ToQUBO.VirtualModel, ::Quadratize)::Bool
    return get(model.compiler_settings, :quadratize, false)
end

function MOI.set(model::ToQUBO.VirtualModel, ::Quadratize, flag::Bool)
    model.compiler_settings[:quadratize] = flag

    return nothing
end

@doc raw"""
    QuadratizationMethod()

Defines which quadratization method to use.
Available options are defined in the `PBO` submodule.
""" struct QuadratizationMethod <: CompilerAttribute end

function MOI.get(model::ToQUBO.VirtualModel, ::QuadratizationMethod)
    return get(model.compiler_settings, :QuadratizationMethod, ToQUBO.PBO.INFER)
end

function MOI.set(
    model::ToQUBO.VirtualModel,
    ::QuadratizationMethod,
    ::Type{method},
) where {method<:ToQUBO.PBO.QuadratizationMethod}
    model.compiler_settings[:QuadratizationMethod] = method

    return nothing
end

@doc raw"""
    StableQuadratization()

When set, this boolean flag enables stable quadratization methods, thus yielding predictable results.
This is intended to be used during tests or other situations where deterministic output is desired.
On the other hand, usage in production is not recommended since it requires increased memory and processing resources.
""" struct StableQuadratization <: CompilerAttribute end

function MOI.get(model::ToQUBO.VirtualModel, ::StableQuadratization)::Bool
    return get(model.compiler_settings, :stable_quadratization, false)
end

function MOI.set(model::ToQUBO.VirtualModel, ::StableQuadratization, flag::Bool)
    model.compiler_settings[:stable_quadratization] = flag

    return nothing
end

@doc raw"""
    DefaultVariableEncodingMethod()
""" struct DefaultVariableEncodingMethod <: CompilerAttribute end

function MOI.get(model::ToQUBO.VirtualModel, ::DefaultVariableEncodingMethod)::ToQUBO.Encoding
    return get(model.compiler_settings, :default_variable_encoding_method, ToQUBO.Binary())
end

function MOI.set(model::ToQUBO.VirtualModel, ::DefaultVariableEncodingMethod, e::ToQUBO.Encoding)
    model.compiler_settings[:default_variable_encoding_method] = e

    return nothing
end

@doc raw"""
    DefaultVariableEncodingATol()
""" struct DefaultVariableEncodingATol <: CompilerAttribute end

function MOI.get(model::ToQUBO.VirtualModel{T}, ::DefaultVariableEncodingATol)::T where {T}
    return get(model.compiler_settings, :default_variable_encoding_atol, T(1E-2))
end

function MOI.set(model::ToQUBO.VirtualModel{T}, ::DefaultVariableEncodingATol, τ::T) where {T}
    model.compiler_settings[:default_variable_encoding_atol] = τ

    return nothing
end

abstract type CompilerVariableAttribute <: MOI.AbstractVariableAttribute end

@doc raw"""
    VariableEncodingATol()
""" struct VariableEncodingATol <: CompilerVariableAttribute end

function MOI.get(model::ToQUBO.VirtualModel{T}, ::VariableEncodingATol, vi::VI)::T where {T}
    attr = :variable_encoding_atol

    if !haskey(model.variable_settings, attr) || !haskey(model.variable_settings[attr], vi)
        return MOI.get(model, DefaultVariableEncodingATol())
    else
        return model.variable_settings[attr][vi]
    end
end

function MOI.set(model::ToQUBO.VirtualModel{T}, ::VariableEncodingATol, vi::VI, τ::T) where {T}
    attr = :variable_encoding_atol

    if !haskey(model.variable_settings, attr)
        model.variable_settings[attr] = Dict{VI,Any}(vi => τ)
    else
        model.variable_settings[attr][vi] = τ
    end

    return nothing
end

@doc raw"""
    DefaultVariableEncodingBits()
""" struct DefaultVariableEncodingBits <: CompilerAttribute end

function MOI.get(model::ToQUBO.VirtualModel, ::DefaultVariableEncodingBits)::Union{Integer,Nothing}
    return get(model.compiler_settings, :default_variable_encoding_bits, nothing)
end

function MOI.set(model::ToQUBO.VirtualModel, ::DefaultVariableEncodingBits, n::Union{Integer,Nothing})
    model.compiler_settings[:default_variable_encoding_bits] = n

    return nothing
end

@doc raw"""
    VariableEncodingBits()
""" struct VariableEncodingBits <: CompilerVariableAttribute end

function MOI.get(model::ToQUBO.VirtualModel, ::VariableEncodingBits, vi::VI)::Union{Integer,Nothing}
    attr = :variable_encoding_bits

    if !haskey(model.variable_settings, attr) || !haskey(model.variable_settings[attr], vi)
        return MOI.get(model, DefaultVariableEncodingBits())
    else
        return model.variable_settings[attr][vi]
    end
end

function MOI.set(model::ToQUBO.VirtualModel, ::VariableEncodingBits, vi::VI, n::Union{Integer,Nothing})
    attr = :variable_encoding_bits

    if !haskey(model.variable_settings, attr)
        model.variable_settings[attr] = Dict{VI,Any}(vi => n)
    else
        model.variable_settings[attr][vi] = n
    end

    return nothing
end

@doc raw"""
    VariableEncodingMethod()

Available methods are:
- [`Binary`](@ref) (default)
- [`Unary`](@ref)
- [`Arithmetic`](@ref)
- [`OneHot`](@ref)
- [`DomainWall`](@ref)
- [`Bounded`](@ref)

The [`Binary`](@ref), [`Unary`](@ref) and [`Arithmetic`](@ref) encodings can have their
expansion coefficients bounded by parametrizing the [`Bounded`](@ref) encoding.
""" struct VariableEncodingMethod <: CompilerVariableAttribute end

function MOI.get(model::ToQUBO.VirtualModel, ::VariableEncodingMethod, vi::VI)::ToQUBO.Encoding
    attr = :variable_encoding_method

    if !haskey(model.variable_settings, attr) || !haskey(model.variable_settings[attr], vi)
        return MOI.get(model, DefaultVariableEncodingMethod())
    else
        return model.variable_settings[attr][vi]
    end
end

function MOI.set(model::ToQUBO.VirtualModel, ::VariableEncodingMethod, vi::VI, e::ToQUBO.Encoding)
    attr = :variable_encoding_method

    if !haskey(model.variable_settings, attr)
        model.variable_settings[attr] = Dict{VI,Any}(vi => e)
    else
        model.variable_settings[attr][vi] = e
    end

    return nothing
end

@doc raw"""
    VariableEncodingPenalty()

Allows the user to set and retrieve the coefficients used for encoding variables when additional
constraints are involved.
""" struct VariableEncodingPenalty <: CompilerVariableAttribute end

function MOI.get(model::ToQUBO.VirtualModel{T}, ::VariableEncodingPenalty, vi::VI) where {T}
    return model.θ[vi]::T
end

function MOI.set(
    model::ToQUBO.VirtualModel{T},
    ::VariableEncodingPenalty,
    vi::VI,
    θ::T,
) where {T}
    model.θ[vi] = θ

    return nothing
end

MOI.is_set_by_optimize(::VariableEncodingPenalty) = true

abstract type CompilerConstraintAttribute <: MOI.AbstractConstraintAttribute end

@doc raw"""
    ConstraintEncodingPenalty()

Allows the user to set and retrieve the coefficients used for encoding constraints.
""" struct ConstraintEncodingPenalty <: CompilerConstraintAttribute end

function MOI.get(model::ToQUBO.VirtualModel{T}, ::ConstraintEncodingPenalty, ci::CI) where {T}
    return model.ρ[ci]
end

function MOI.set(
    model::ToQUBO.VirtualModel{T},
    ::ConstraintEncodingPenalty,
    ci::CI,
    ρ::T,
) where {T}
    model.ρ[ci] = ρ

    return nothing
end

MOI.is_set_by_optimize(::ConstraintEncodingPenalty) = true

@doc raw"""
    QUBONormalForm()
""" struct QUBONormalForm <: CompilerAttribute end

function MOI.get(
    model::ToQUBO.VirtualModel{T},
    ::QUBONormalForm,
)::ToQUBO.QUBO_NORMAL_FORM{T} where {T}
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

MOIU.map_indices(::MOIU.IndexMap, x::ToQUBO.QUBO_NORMAL_FORM{T}) where {T} = x

end # module Settings