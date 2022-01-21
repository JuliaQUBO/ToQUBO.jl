module VarMap

export coefficient, coefficients, offset, isslack, source, target, name
export isempty, length, iterate
export VirtualVariable, VV

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

    - `:𝔹`
        Used when a boolean variable is to be mirrored.
    - `:ℤ₂`
        Binary expansion for integer variable.
    - `:ℤ₁`
        Unary expansion for integer variable.
    - `:ℝ₂`
        Binary expansion for real variable.
    - `:ℝ₁`
        Unary expansion for real variable.

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

# -*- Alias -*-
const VV{S, T} = VirtualVariable{S, T}

# -*- Expansion Coefficients -*-
function coefficient(v::VV, i::Int)
    return v.c[i]
end

function coefficients(v::VV)
    return copy(v.c)
end

function offset(v::VV)
    return v.α
end

# -*- Iterator & Length -*-
function Base.isempty(::VV)::Bool
    return false
end

function Base.length(v::VV)::Int
    return v.bits
end

function Base.iterate(v::VV{S, T})::Tuple{Tuple{S, T}, Int} where {S, T}
    return ((v.target[1], coefficient(v, 1)), 2)
end

function Base.iterate(v::VV{S, T}, i::Int)::Union{Nothing, Tuple{Tuple{S, T}, Int}} where {S, T}
    if i > v.bits
        return nothing
    else
        return ((v.target[i], coefficient(v, i)), i + 1)
    end
end

# -*- Variable Information -*-
function isslack(v::VV)
    return v.source === nothing
end

function name(v::VV)
    return v.name
end

function source(v::VV{S, T}) where {S, T}
    return v.source
end

function target(v::VV{S, T}) where {S, T}
    return v.target
end

end # module