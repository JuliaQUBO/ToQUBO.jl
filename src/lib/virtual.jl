module VirtualMapping

export coefficient, coefficients, offset, isslack, source, target, name
export isempty, length, iterate
export VirtualVariable

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
            name::Union{Symbol, Nothing}=nothing,
            α::T=zero(T),
            β::T=one(T)
        ) where {S, T}

        𝟎 = zero(T)
        𝟏 = one(T)
        𝟐 = 𝟏 + 𝟏

        if tech === :𝔹

            if bits !== nothing 
                @warn "'bits' will be ignored since mirroring binary variables always require a single bit."
            end

            bits = 1

            return new{S, T}(
                newvar(bits)::Vector{S},
                source,
                name,
                bits,
                tech,
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

end # module