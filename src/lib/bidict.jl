"""
"""
mutable struct BiDict{S <: Any, T <: Any} <: AbstractDict{S, T}
    map::Dict{S, T}
    inv::Dict{T, S}
    rev::Union{Missing, BiDict{T, S}}

    function BiDict{S, T}() where {S, T}
        return new{S, T}(Dict{S, T}(), Dict{T, S}(), missing)
    end

    function BiDict{S, T}(map::Dict{S, T}, inv::Dict{T, S}; rev::Union{Missing, BiDict{T, S}}=missing) where {S, T}
        return new{S, T}(map, inv, rev)
    end
end

# -*- Reverse -*-
function Base.:!(b::BiDict{S, T})::BiDict{T, S} where {S, T}
    if b.rev === missing
        b.rev = BiDict{T, S}(b.inv, b.map, rev=b)
    end

    return b.rev
end

# -*- Length & Iteration -*-
function Base.length(b::BiDict{S, T})::Int where {S, T}
    return length(b.map)
end

function Base.iterate(b::BiDict{S, T}) where {S, T}
    return iterate(b.map)
end

function Base.iterate(b::BiDict{S, T}, i::Int) where {S, T}
    return iterate(b.map, i)
end

# -*- Dict Interface -*-
function Base.getindex(b::BiDict{S, T}, k::S) where {S, T}
    return getindex(b.map, k)
end

function Base.getindex(b::BiDict{S, T}, k::S) where {S, T}
    return getindex(b.map, k)
end

function Base.getindex(b::BiDict{S, T}, k::T) where {S, T}
    return getindex(b.inv, k)
end

function Base.setindex!(b::BiDict{T, T}, v::T, k::T) where {T}
    setindex!(b.map, v, k)
    setindex!(b.inv, k, v)
end

function Base.setindex!(b::BiDict{S, T}, v::T, k::S) where {S, T}
    setindex!(b.map, v, k)
    setindex!(b.inv, k, v)
end

function Base.setindex!(b::BiDict{S, T}, v::S, k::T) where {S, T}
    setindex!(b.inv, v, k)
    setindex!(b.map, k, v)
end

function Base.delete!(b::BiDict{T, T}, k::T) where {T}
    delete!(b.inv, getindex(b.map, k))
    delete!(b.map, k)
end

function Base.delete!(b::BiDict{S, T}, k::S) where {S, T}
    delete!(b.inv, getindex(b.map, k))
    delete!(b.map, k)
end

function Base.delete!(b::BiDict{S, T}, v::T) where {S, T}
    delete!(b.map, getindex(b.inv, v))
    delete!(b.inv, v)
end

# -*- IO & Printing -*-
function Base.show(io::IO, b::BiDict{S, T}) where {S, T}
    println(io, b.map)
    println(io, b.inv)
end