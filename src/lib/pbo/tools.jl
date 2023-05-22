# Relaxed Greatest Common Divisor 
@doc raw"""
    relaxed_gcd(x::T, y::T; tol::T = T(1e-6)) where {T}

We define two real numbers ``x`` and ``y`` to be ``\tau``-comensurable if, for some ``\tau > 0`` there exists a continued fractions convergent ``p_{k} \div q_{k}`` such that

```math
    \left| {q_{k} x - p_{k} y} \right| \le \tau
```
"""
function relaxed_gcd(x::T, y::T; tol::T = 1e-6) where {T}
    x_ = abs(x)
    y_ = abs(y)

    if x_ < y_
        return relaxed_gcd(y_, x_; tol = tol)::T
    elseif y_ < tol
        return x_
    elseif x_ < tol
        return y_
    else
        return (x_ / numerator(rationalize(x_ / y_; tol = tol)))::T
    end
end

function relaxed_gcd(a::AbstractArray{T}; tol::T = 1e-6) where {T}
    if length(a) == 0
        return one(T)
    elseif length(a) == 1
        return first(a)
    else
        return reduce((x, y) -> relaxed_gcd(x, y; tol = tol), a)
    end
end

# Variable Terms 
varmul(x::V, y::V) where {V}           = Set{V}([x, y])
varmul(x::Set{V}, y::V) where {V}      = push!(copy(x), y)
varmul(x::V, y::Set{V}) where {V}      = push!(copy(y), x)
varmul(x::Set{V}, y::Set{V}) where {V} = union(x, y)

const × = varmul # \times[tab]
const ≺ = varlt  # \prec[tab]

@doc raw"""
"""
function degree end

degree(f::PBF) = maximum(length.(keys(f)); init = 0)

# Gap & Penalties 
@doc raw"""
""" function lowerbound end

function lowerbound(f::PBF; bound::Symbol = :loose)
    return lowerbound(f, Val(bound))
end

function lowerbound(f::PBF{<:Any,T}, ::Val{:loose}) where {T}
    return sum(c < zero(T) || isempty(ω) ? c : zero(T) for (ω, c) in f)
end

@doc raw"""
""" function upperbound end

function upperbound(f::PBF; bound::Symbol = :loose)
    return upperbound(f, Val(bound))
end

function upperbound(f::PBF{<:Any,T}, ::Val{:loose}) where {T}
    return sum(c > zero(T) || isempty(ω) ? c : zero(T) for (ω, c) in f)
end

@doc raw"""
""" function bounds end

function bounds(f::PBF; bound::Symbol = :loose)
    return (lowerbound(f; bound), upperbound(f; bound))
end

function gap(f::PBF; bound::Symbol = :loose)
    return gap(f, Val(bound))
end

function gap(f::PBF{V,T}, ::Val{:loose}) where {V,T}
    return sum(abs(c) for (ω, c) in f if !isempty(ω); init = zero(T))
end

function gap(::PBF, ::Val{:tight})
    error("Not Implemented: See [1] sec 5.1.1 Majorization")
end

function sharpness(f::PBF{V,T}; bound::Symbol = :loose, tol::T = 1e-6) where {V,T}
    return sharpness(f, Val(bound), tol)
end

function sharpness(::PBF{V,T}, ::Val{:none}, ::T) where {V,T}
    return one(T)
end

function sharpness(f::PBF{V,T}, ::Val{:loose}, tol::T = 1E-6) where {V,T}
    return relaxed_gcd(collect(values(f)); tol = tol)::T
end

function derivative(f::PBF{V,T}, x::V) where {V,T}
    return PBF{V,T}(ω => f[ω×x] for ω ∈ keys(f) if (x ∉ ω))
end

function gradient(f::PBF{V}, x::Vector{V}) where {V}
    return derivative.(f, x)
end

function residual(f::PBF{V,T}, x::V) where {V,T}
    return PBF{V,T}(ω => c for (ω, c) ∈ keys(f) if (x ∉ ω))
end

function discretize(f::PBF{V,T}; tol::T = 1E-6) where {V,T}
    return discretize!(copy(f); tol = tol)
end

function discretize!(f::PBF{V,T}; tol::T = 1E-6) where {V,T}
    ε = sharpness(f; bound = :loose, tol = tol)

    for (ω, c) in f
        f[ω] = round(c / ε; digits = 0)
    end

    return f
end
