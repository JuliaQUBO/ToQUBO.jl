module VarMap

export coefficient, coefficients, isslack, source, target, name
export isempty, length, iterate
export VirtualVar, VV

struct VirtualVar{S <: Any, T <: Any}

    # -*- Variable Mapping -*-
    target::Vector{S}
    source::Union{S, Nothing}

    # -*- Variable Name -*-
    name::Symbol

    # -*- Binary Expansion -*-
    bits::Int
    tech::Symbol

    # -*- Expansion Interval Limits -*-
    α::T
    β::T

    # -*- Default Expansion -*-
    function VirtualVar{S, T}(bits::Int, target::Vector{S}, source::Union{S, Nothing}=nothing; tech::Symbol=:bin, name::Symbol=:x, α::T=zero(T), β::T=one(T)) where {S, T}
        
        if length(target) != bits
            error("Virtual Variables need exactly as many target variables as bits")
        elseif bits == 0
            error("At least one output variable must be provided")
        end

        if tech === :bin || tech === :step
            nothing
        elseif tech === :none
            if bits !== 1
                error("Expansion technique 'none' is only suited for one-bit expansions")
            elseif α !== zero(T)
                error("Expansion technique 'none' requires 'α' to be zero")
            end
        else
            error("Unknown expansion technique '$tech'")
        end
        
        return new{S, T}(target, source, name, bits, tech, α, β)
    end

    # -*- Binary Variable Mirroring -*-
    function VirtualVar{S, T}(target::S, source::Union{S, Nothing}=nothing; name::Symbol=:x) where {S, T}
        bits = 1
        tech = :none
        (α, β) = (zero(T), one(T))
        target = Vector{S}([target])
        return new{S, T}(target, source, name, bits, tech, α, β)
    end
end

# -*- Alias -*-
const VV{S, T} = VirtualVar{S, T}

# -*- Expansion Coefficients -*-
function coefficient(v::VV{S, T}, i::Int)::T where {S, T}
    if v.tech === :bin
        # x ∈ [0, 1]
        x = 2.0 ^ (i - 1.0) / (2.0 ^ v.bits - 1.0)
        # y ∈ [α, β]
        y = (v.β - v.α) * x + v.α
        return y
    elseif v.tech === :step
        # x ∈ [0, 1]
        x = (i - 1.0) / (v.bits - 1.0)
        # y ∈ [α, β]
        y = (v.β - v.α) * x + v.α
        return y
    elseif v.tech === :none
        return one(T)
    else
        error("Error: Unknown expansion technique '$(v.tech)'")
    end
end

function coefficients(v::VV{S, T})::Vector{T} where {S, T}
    return Vector{T}([coefficient(v, i) for i = 1:v.bits])
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
function isslack(v::VV)::Bool
    return v.source === nothing
end

function name(v::VV)::Symbol
    return v.name
end

function source(v::VV{S, T})::Vector{S} where {S, T}
    return v.source
end

function target(v::VV{S, T})::Vector{S} where {S, T}
    return v.target
end

end # module