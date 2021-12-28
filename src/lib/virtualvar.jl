module VirtualVars

export VirtualVar
export coefficients, isslack
export iterate, vars, domain

@doc raw"""
   xᵢ <- .source::Union{S, Nothing} <- yᵢ -> .target::Vector{S} -> [yᵢ₁, ..., yᵢₙ]

tech::Symbol
    :bin - Binary expansion i.e. $ y = \sum_{i = 1}^{n} 2^{i-1} x_i $
    :step - Step expansion i.e. $ y = \sum_{i = 1}^{n} x_i $
"""
struct VirtualVar{S <: Any, T <: Any}

    bits::Int
    offset::Int
    target::Vector{S}
    source::Union{S, Nothing}
    tech::Symbol
    var::Symbol

    function VirtualVar{S, T}(bits::Int, target::Vector{S}, source::Union{S, Nothing}=nothing; offset::Int=0, tech::Symbol=:bin, var::Symbol=:x) where {S, T}
    
        if length(target) != bits
            error("Virtual Variables need exactly as many keys as encoding bits")
        elseif bits == 0
            error("At least one output variable must be provided")
        end

        if (tech !== :step && tech !== :bin)
            error("Unknown expansion technique '$tech'")
        elseif (tech === :none && bits != 1)
            error("Expansion technique 'none' is only suited for one-bit expansions")
        end
        
        return new{S, T}(bits, offset, target, source, tech, var)
    end

    function VirtualVar{S, T}(target::S, source::Union{S, Nothing}=nothing; offset::Int=0, var::Symbol=:x) where {S, T}
        return new{S, T}(1, offset, [target], source, :none, var)
    end
end

"""
"""
function vars(v::VirtualVar{S, T})::Vector{S} where {S, T}
    return Vector{S}(v.target)
end

"""
"""
function domain(v::VirtualVar{S, T})::Tuple{T, T} where {S, T}
    if v.tech === :step
        return Tuple{T, T}(0, v.bits)
    elseif v.tech === :bin
        return Tuple{T, T}(2 ^ (-v.offset - 1), 2 ^ (v.bits - v.offset - 1))
    else # v.tech === :none
        return Tuple{T, T}(0, 1)
    end
end

"""
"""
function Base.iterate(v::VirtualVar)
    return iterate(zip(vars(v), coefficients(v)))
end

"""
"""
function Base.iterate(v::VirtualVar, i::Tuple{Int, Int})
    return iterate(zip(vars(v), coefficients(v)), i)
end

"""
"""
function isslack(v::VirtualVar)::Bool
    return v.source === nothing
end

"""
"""
function coefficients(v::VirtualVar{S, T})::Vector{T} where {S, T}
    if v.tech === :step
        return Vector{T}([1 for i in 1:v.bits])
    elseif v.tech === :bin
        return Vector{T}([2 ^ (i - v.offset) for i in 0:v.bits-1])
    else # v.tech === :none
        return Vector{T}([1])
    end
end

end # module