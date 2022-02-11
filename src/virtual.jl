module VirtualMapping

using MathOptInterface
const MOI = MathOptInterface
const MOIU = MOI.Utilities
const VI = MOI.VariableIndex

export isempty, length, iterate
export VirtualVariable
export VirtualMOIVariable
export AbstractVirtualModel
export coefficient, coefficients, offset, isslack, source, target, name
export expandℝ!, slackℝ!, expandℤ!, slackℤ!, mirror𝔹!, slack𝔹!

@doc raw"""
    VirtualVariable{S, T}(
        newvar::Function,
        source::Union{S, Nothing};
        bits::Union{Int, Nothing},
        tech::Symbol,
        name::Union{Symbol, Nothing}=nothing,
        α::T=zero(T),
        β::T=one(T)
    ) where {S, T}

The Virtual Variable Mapping

## Variable Expansion techniques:

 * `:𝔹` - Used when a boolean variable is to be mirrored.
 * `:ℤ₂` - Binary expansion for integer variable.
 * `:ℤ₁` - Unary expansion for integer variable.
 * `:ℝ₂` - Binary expansion for real variable.
 * `:ℝ₁` - Unary expansion for real variable.

## References:
 * [1] Chancellor, N. (2019). Domain wall encoding of discrete variables for quantum annealing and QAOA. _Quantum Science and Technology_, _4_(4), 045004. [{doi}](https://doi.org/10.1088/2058-9565/ab33c2)
"""
struct VirtualVariable{S <: Any, T <: Any}

    # -*- Variable Mapping -*-
    target::Vector{S}
    source::Union{S, Nothing}

    # -*- Variable Name -*-
    name::Union{Symbol, Nothing}

    # -*- Binary Expansion -*-
    bits::Int
    tech::Symbol
    semi::Bool

    # -*- Expansion Interval Limits -*-
    α::T # Start
    β::T # End

    # -*- Coefficients -*-
    c::Vector{T}

    # -*- Default Expansion -*-
    function VirtualVariable{S, T}(
            newvar::Function,
            source::Union{S, Nothing};
            bits::Union{Int, Nothing}=nothing,
            tech::Symbol,
            semi::Bool=false,
            name::Union{Symbol, Nothing}=nothing,
            α::T=zero(T),
            β::T=one(T)
        ) where {S, T}

        𝟎 = zero(T)
        𝟏 = one(T)
        𝟐 = convert(T, 2)

        if tech === :𝔹

            if bits !== nothing 
                @warn "'bits' will be ignored since mirroring binary variables always require a single bit"
            end

            if semi
                @warn "'semi'-boolean variables doesn't make sense"
            end

            bits = 1

            return new{S, T}(
                newvar(bits)::Vector{S},
                source,
                name,
                bits,
                tech,
                false,
                𝟎,
                𝟏,
                Vector{T}([𝟏])
            )
        elseif tech === :ℤ₂
            if bits !== nothing
                @warn "'bits' will be ignored since ':ℤ₂' expansion technique depends only on variable bounds."
            end
            
            if α <= β
                a, b = ceil(Int, α), floor(Int, β)
            else
                b, a = floor(Int, α), ceil(Int, β)
            end

            n = b - a
            m = sizeof(Int) << 3 - leading_zeros(n) - 1

            bits = m + 1

            return new{S, T}(
                newvar(bits)::Vector{S},
                source,
                name,
                bits,
                tech,
                semi,
                convert(T, a),
                convert(T, b),
                Vector{T}([𝟐 .^ (0:m-1); n + 𝟏 - 𝟐 ^ m])
            )
        elseif tech === :ℤ₁
            if bits !== nothing
                @warn "'bits' will be ignored since ':ℤ₁' expansion technique depends only on variable bounds."
            end

            if α <= β
                a, b = ceil(Int, α), floor(Int, β)
            else
                b, a = floor(Int, α), ceil(Int, β)
            end

            bits = b - a

            return new{S, T}(
                newvar(bits)::Vector{S},
                source,
                name,
                bits,
                tech,
                semi,
                convert(T, a),
                convert(T, b),
                Vector{T}([𝟏 for i in 1:bits])
            )
        elseif tech === :ℝ₂

            if bits === nothing
                throw(ArgumentError("No value provided for 'bits'"))
            end

            γ = (β - α) / (𝟐 ^ bits - 𝟏)

            return new{S, T}(
                newvar(bits)::Vector{S},
                source,
                name,
                bits,
                tech,
                semi,
                α,
                β,
                Vector{T}(γ .* 𝟐 .^ (0:bits-1))
            )
        elseif tech === :ℝ₁

            if bits === nothing
                throw(ArgumentError("No value provided for 'bits'"))
            end

            γ = (β - α) / (bits - 𝟏)

            return new{S, T}(
                newvar(bits)::Vector{S},
                source,
                name,
                bits,
                tech,
                semi,
                α,
                β,
                Vector{T}([γ for i = 1:bits])
            )
        else
            throw(ArgumentError("Invalid expansion technique '$tech'"))
        end 
    end
end

# -*- Expansion Coefficients -*-
function coefficient(v::VirtualVariable, i::Int)
    return v.c[i]
end

function coefficients(v::VirtualVariable)
    return copy(v.c)
end

function offset(v::VirtualVariable)
    return v.α
end

# -*- Iterator & Length -*-
function Base.isempty(::VirtualVariable)
    return false
end

function Base.length(v::VirtualVariable)
    return v.bits
end

function Base.iterate(v::VirtualVariable{S, T}) where {S, T}
    return ((v.target[1], coefficient(v, 1)), 2)
end

function Base.iterate(v::VirtualVariable{S, T}, i::Int) where {S, T}
    if i > v.bits
        return nothing
    else
        return ((v.target[i], coefficient(v, i)), i + 1)
    end
end

function Base.collect(𝓋::VirtualVariable{S, T}) where {S, T}
    return Dict{S, T}(𝓋ᵢ => c for (𝓋ᵢ, c) ∈ 𝓋)
end

# -*- Variable Information -*-
function isslack(v::VirtualVariable)
    return v.source === nothing
end

function name(v::VirtualVariable)
    return v.name
end

function source(v::VirtualVariable{S, T}) where {S, T}
    return v.source
end

function target(v::VirtualVariable{S, T}) where {S, T}
    return v.target
end

# -*- :: Virtual Model + MOI Integration :: -*-
const VirtualMOIVariable{T} = VirtualVariable{MOI.VariableIndex, T}

abstract type AbstractVirtualModel{T <: Any} <: MOIU.AbstractModelLike{T} end

struct VirtualModel{T} <: AbstractVirtualModel{T}
    # -*- Underlying Model -*-
    source_model::Any
    target_model::Any

    # -*- Virtual Model Interface -*-
    varvec::Vector{VirtualMOIVariable{T}}
    source::Dict{MOI.VariableIndex, VirtualMOIVariable{T}}
    target::Dict{MOI.VariableIndex, VirtualMOIVariable{T}}
end

# ::: Variable Management :::
@doc raw"""
    mapvar!(model::AbstractVirtualModel{T}, 𝓋::VirtualMOIVariable{T}) where {T}

Maps newly created virtual variable `𝓋` within the virtual model structure. It follows these steps:
 
 1. Maps `𝓋`'s source to it in the model's `source` mapping.
 2. For every one of `𝓋`'s targets, maps it to itself and adds a binary constraint to it.
 2. Adds `𝓋` to the end of the model's `varvec`.  
"""
function mapvar!(model::AbstractVirtualModel{T}, 𝓋::VirtualMOIVariable{T}) where {T}
    x = source(𝓋)

    if x !== nothing # not a slack variable
        model.source[x] = 𝓋
    end

    for yᵢ in target(𝓋)
        MOI.add_constraint(model.target_model, yᵢ, MOI.ZeroOne())
        model.target[yᵢ] = 𝓋
    end

    push!(model.varvec, 𝓋)

    return 𝓋
end

@doc raw"""
    expandℝ!(model::QUBOModel{T}, src::VI; bits::Int, name::Symbol, α::T, β::T, semi::Bool) where T

Real Binary Expansion within the closed interval ``[\alpha, \beta]``.

For a given variable ``x \in [\alpha, \beta]`` we approximate it by

```math    
x \approx \alpha + \frac{(\beta - \alpha)}{2^{n} - 1} \sum_{i=0}^{n-1} {2^{i}\, y_i}
```

where ``n`` is the number of bits and ``y_i \in \mathbb{B}``.
"""
function expandℝ!(model::AbstractVirtualModel{T}, src::Union{VI, Nothing}; bits::Int, name::Symbol, α::T, β::T, semi::Bool) where T
    return mapvar!(model, VirtualMOIVariable{T}(
        (n) -> MOI.add_variables(model.target_model, n),
        src;
        tech=:ℝ₂,
        bits=bits,
        name=name,
        α=α,
        β=β,
        semi=semi
    ))
end

@doc raw"""
    slackℝ!(model::AbstractVirtualModel{T}; name::Symbol, α::T, β::T, semi::Bool) where T

Adds real slack variable according to [`expandℝ!`](@ref)'s expansion method.
"""
function slackℝ!(model::AbstractVirtualModel{T}; bits::Int, name::Symbol, α::T, β::T, semi::Bool) where T
    return mapvar!(model, VirtualMOIVariable{T}(
        (n) -> MOI.add_variables(model.target_model, n),
        nothing;
        tech=:ℝ₂,
        bits=bits,
        name=name,
        α=α,
        β=β,
        semi=semi
    ))
end

@doc raw"""
    expandℤ!(model::QUBOModel{T}, src::VI; name::Symbol, α::T, β::T, semi::Bool) where T

Integer Binary Expansion within the closed interval ``[\left\lceil{\alpha}\right\rceil, \left\lfloor{\beta}\right\rfloor]``.
"""
function expandℤ!(model::AbstractVirtualModel{T}, src::Union{VI, Nothing}; name::Symbol, α::T, β::T, semi::Bool) where T
    return mapvar!(model, VirtualMOIVariable{T}(
        (n) -> MOI.add_variables(model.target_model, n),
        src;
        tech=:ℤ₂,
        name=name,
        α=α,
        β=β,
        semi=semi
    ))
end

@doc raw"""
    slackℤ!(model::AbstractVirtualModel{T}; name::Symbol, α::T, β::T) where {T}

Adds integer slack variable according to [`expandℤ!`](@ref)'s expansion method.
"""
function slackℤ!(model::AbstractVirtualModel{T}; name::Symbol, α::T, β::T, semi::Bool) where {T}
    return mapvar!(model, VirtualMOIVariable{T}(
        (n) -> MOI.add_variables(model.target_model, n),
        nothing;
        tech=:ℤ₂,
        name=name,
        α=α,
        β=β,
        semi=semi
    ))
end

@doc raw"""
    mirror𝔹!(model::AbstractVirtualModel{T}, src::Union{VI, Nothing}; name::Symbol) where T

Simply crates a virtual-mapped *Doppelgänger* into the destination model.
"""
function mirror𝔹!(model::AbstractVirtualModel{T}, src::Union{VI, Nothing}; name::Symbol) where T
    return mapvar!(model, VirtualMOIVariable{T}(
        (n) -> MOI.add_variables(model.target_model, n),
        src;
        tech=:𝔹,
        name=name,
        semi=false
    ))
end

function slack𝔹!(model::AbstractVirtualModel{T}; name::Symbol) where {T}
    return mapvar!(model, VirtualMOIVariable{T}(
        (n) -> MOI.add_variables(model.target_model, n),
        nothing;
        tech=:𝔹,
        name=name,
        semi=false
    ))
end

end # module