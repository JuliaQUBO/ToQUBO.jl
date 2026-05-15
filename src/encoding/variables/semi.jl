@doc raw"""
    Semi(e::VariableEncodingMethod)

Wraps another variable encoding method to represent ``x \in \{0\} \cup X``.
If the wrapped method encodes ``X`` as ``\xi[X](y)``, then `Semi` uses an
additional activation bit ``z`` and encodes the semi-domain as
``z \xi[X](y)``.
"""
struct Semi{E<:VariableEncodingMethod} <: VariableEncodingMethod
    e::E
end

function _semi_encode(
    var::Function,
    y::Vector{VI},
    xi::PBO.PBF{VI,T},
    chi::Union{PBO.PBF{VI,T},Nothing},
) where {T}
    z = var(nothing)::VI
    active = PBO.PBF{VI,T}(z)

    return ([y; z], active * xi, isnothing(chi) ? nothing : active * chi)
end

function encode(var::Function, e::Semi, gamma::AbstractVector{T}) where {T}
    return _semi_encode(var, encode(var, e.e, gamma)...)
end

function encode(
    var::Function,
    e::Semi,
    S::Tuple{T,T};
    tol::Union{T,Nothing} = nothing,
) where {T}
    return _semi_encode(var, encode(var, e.e, S; tol)...)
end

function encode(
    var::Function,
    e::Semi,
    S::Tuple{T,T},
    n::Union{Integer,Nothing};
    tol::Union{T,Nothing} = nothing,
) where {T}
    return _semi_encode(var, encode(var, e.e, S, n; tol)...)
end
