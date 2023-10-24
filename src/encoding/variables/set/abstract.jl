# Integer
function encode(var::Function, e::E, S::Tuple{T,T}; tol::Union{T,Nothing} = nothing) where {T,E<:Union{OneHot{T},DomainWall{T}}}
    isnothing(tol) || return encode(var, e, S, nothing; tol)

    a, b = integer_interval(S)

    return encode(var, e, collect(a:b))
end