struct VirtualVar{S <: Any, T <: Any}
    bits::Int
    offset::Int
    target::Vector{S}
    source::Union{S, Nothing}
    tech::Symbol
    var::Symbol

    # -*- Default Expansion -*-
    function VirtualVar{S, T}(bits::Int, target::Vector{S}, source::Union{S, Nothing}=nothing; offset::Int=0, tech::Symbol=:bin, var::Symbol=:x) where {S, T}
        if length(target) != bits
            error("Virtual Variables need exactly as many target variables as bits")
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

    # -*- Variable Miorroring -*-
    function VirtualVar{S, T}(target::S, source::Union{S, Nothing}=nothing; offset::Int=0, var::Symbol=:x) where {S, T}
        return new{S, T}(1, offset, [target], source, :none, var)
    end
end

# -*- Alias -*-
const VV{S, T} = VirtualVar{S, T}

# -*- Expansion Coefficients -*-
function coefficients(v::VV{S, T})::Vector{T} where {S, T}
    return Vector{T}([coefficient(v, i) for i = 1:v.bits])
end

function coefficient(v::VV{S, T}, i::Int)::T where {S, T}
    if v.tech === :bin
        return convert(T, 2 ^ (i - v.offset - 1))
    else #v.tech === :step || v.tech === :none
        return one(T)
    end
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

function source(v::VV{S, T})::Vector{S} where {S, T}
    return v.source
end

function target(v::VV{S, T})::Vector{S} where {S, T}
    return v.target
end

# -*- IO -*-
function subscript(v::VV)
    return subscript(v.source, var=v.var, par=isslack(v))
end

function Base.show(io::IO, v::VV)
    if isslack(v)
        print(io, v.var)
    else
        print(io, subscript(v.source, var=v.var))
    end
end