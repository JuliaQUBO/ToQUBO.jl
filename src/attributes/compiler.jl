module Attributes

import MathOptInterface as MOI
const MOIU = MOI.Utilities
const VI   = MOI.VariableIndex
const CI   = MOI.ConstraintIndex

import PseudoBooleanOptimization as PBO
import QUBOTools

import ..ToQUBO: Optimizer
import ..Encoding
import ..Virtual

function MOIU.map_indices(::Function, e::Encoding.VariableEncodingMethod)
    return e
end

abstract type CompilerAttribute <: MOI.AbstractOptimizerAttribute end

MOI.supports(::Optimizer, ::A) where {A<:CompilerAttribute} = true

@doc raw"""
    Warnings()
"""
struct Warnings <: CompilerAttribute end

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
    Optimization()
"""
struct Optimization <: CompilerAttribute end

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

function MOI.get(model::Optimizer, ::Discretize)::Bool
    return get(model.compiler_settings, :discretize, false)
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
    Quadratize()

Boolean flag to conditionally perform the quadratization step.
Is automatically set by the compiler when high-order functions are generated.
"""
struct Quadratize <: CompilerAttribute end

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

function MOI.get(model::Optimizer, ::QuadratizationMethod)
    return get(model.compiler_settings, :quadratization_method, PBO.DEFAULT())
end

function MOI.set(
    model::Optimizer,
    ::QuadratizationMethod,
    method::PBO.QuadratizationMethod,
)
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

function MOI.get(
    model::Optimizer,
    ::DefaultVariableEncodingMethod,
)::Encoding.VariableEncodingMethod
    return get(model.compiler_settings, :default_variable_encoding_method, Encoding.Binary())
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
"""
struct DefaultVariableEncodingATol <: CompilerAttribute end

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
"""
struct DefaultVariableEncodingBits <: CompilerAttribute end

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
    VariableEncodingATol()
"""
struct VariableEncodingATol <: CompilerVariableAttribute end

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
"""
struct VariableEncodingBits <: CompilerVariableAttribute end

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
        model.variable_settings[attr] = Dict{VI,Any}(vi => n)
    else
        model.variable_settings[attr][vi] = n
    end

    return nothing
end

function MOI.set(model::Optimizer, ::VariableEncodingBits, vi::VI, ::Nothing)
    attr = :variable_encoding_bits

    if haskey(model.variable_settings, attr)
        delete!(model.variable_settings[attr], vi)

        if isempty(model.variable_settings[attr])
            delete!(model.variable_settings, attr)
        end
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
        model.variable_settings[attr] = Dict{VI,Any}(vi => e)
    else
        model.variable_settings[attr][vi] = e
    end

    return nothing
end

function MOI.set(model::Optimizer, ::Attributes.VariableEncodingMethod, vi::VI, ::Nothing)
    attr = :variable_encoding_method

    if haskey(model.variable_settings, attr)
        delete!(model.variable_settings[attr], vi)

        if isempty(model.variable_settings[attr])
            delete!(model.variable_settings, attr)
        end
    end

    return nothing
end

@doc raw"""
    VariableEncodingPenalty()

Allows the user to set and retrieve the coefficients used for encoding variables when additional
constraints are involved.
"""
struct VariableEncodingPenalty <: CompilerVariableAttribute end

function variable_encoding_penalty(model::Optimizer, vi::VI)
    return MOI.get(model, VariableEncodingPenalty(), vi)
end

function MOI.get(model::Optimizer{T}, ::VariableEncodingPenalty, vi::VI) where {T}
    return get(model.θ, vi, nothing)
end

function MOI.set(model::Optimizer{T}, ::VariableEncodingPenalty, vi::VI, θ::T) where {T}
    model.θ[vi] = θ

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
    ConstraintEncodingPenalty()

Allows the user to set and retrieve the coefficients used for encoding constraints.
"""
struct ConstraintEncodingPenalty <: CompilerConstraintAttribute end

MOI.supports(::Optimizer, ::ConstraintEncodingPenalty, ::Type{<:CI}) = true
MOI.is_set_by_optimize(::ConstraintEncodingPenalty)                  = true
MOI.is_copyable(::ConstraintEncodingPenalty)                         = true

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

end # module Attributes
