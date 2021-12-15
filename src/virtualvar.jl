@doc raw"""
Original <----> Virtual <----> Output

tech::Symbol
    :bin - Binary expansion i.e. $ y = \sum_{i = 1}^{n} 2^{i-1} x_i $
    :step - Step expansion i.e. $ y = \sum_{i = 1}^{n} x_i $
"""
struct VirtualVar{S <: Any, T <: Any}

    bits::Int
    offset::Int
    source::Vector{S}
    target::Union{S, Nothing}
    tech::Symbol

    function VirtualVar{S, T}(bits::Int, target::Vector{S}, source::Union{S, Nothing}=nothing; offset::Int=0, tech::Symbol=:bin) where {S, T}
    
        if length(vars) != bits
            error("Virtual Variables need exactly as many keys as encoding bits")
        elseif length(vars) == 0
            error("At least one output variable must be provided")
        end

        if !(tech === :step || tech === :bin)
            error("Invalid Expansion technique '$tech'")
        end
        
        return new{S, T}(bits, offset, source, target, tech)
    end

    function VirtualVar{S, T}(var::S, slack::Bool=false) where {S, T}

        bits = 1
        vars = Vector{S}([var])
        tech = :none
        values = Vector{Union{T, Nothing}}([nothing])
        coefficients = Vector{T}([convert(T, 1)])

        return new{S, T}(bits, vars, tech, offset, slack, values, coefficients)
    end
end

function vars(v::VirtualVar{S, T})::Vector{S} where {S, T}
    return Vector{S}(v.target)
end

function Base.keys(v::VirtualVar{S, T})::Vector{S} where {S, T}
    return vars(v)
end

function Base.iterate(v::VirtualVar{S, T}) where {S, T}
    return iterate(zip(vars(v), coefficients(v)))
end

function Base.iterate(v::VirtualVar{S, T}, i::Tuple{Int, Int}) where {S, T}
    return iterate(zip(vars(v), coefficients(v)), i)
end

function coefficients(v::VirtualVar{S, T})::Vector{T} where {S, T}
    if v.tech === :step
        return Vector{T}([1 for i in 1:v.bits])
    elseif v.tech === :bin
        return Vector{T}([2 ^ (i - v.offset) for i in 0:v.bits-1])
    end
end

function values(model::MOI.ModelLike, v::VirtualVar{S, T})::Vector{T} where {S, T}
    return Vector{T}([MOI.get(model, MOI.PrimalValue(), vᵢ) for vᵢ in vars(v)])
end

function value(model::MOI.ModelLike, v::VirtualVar{S, T})::Union{T, Nothing} where {S, T}
    s = convert(T, 0)
    for (cᵢ, xᵢ) in zip(coefficients(v), values(model, v))
        if xᵢ === nothing
            return nothing
        end
        s += cᵢ * xᵢ
    end
    return s
end