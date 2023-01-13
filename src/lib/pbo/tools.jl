# -*- Relaxed Greatest Common Divisor -*-
@doc raw"""
    relaxed_gcd(x::T, y::T; tol::T = T(1e-6)) where {T <: AbstractFloat}

We define two real numbers ``x`` and ``y`` to be ``\tau``-comensurable if, for some ``\tau > 0`` there exists a continued fractions convergent ``p_{k} \div q_{k}`` such that

```math
    \left| {q_{k} x - p_{k} y} \right| \le \tau
```
"""
function relaxed_gcd(x::T, y::T; tol::T = 1e-6) where {T<:Number}
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

function relaxed_gcd(a::AbstractArray{T}; tol::T = 1e-6) where {T<:Number}
    if length(a) == 0
        one(T)
    elseif length(a) == 1
        first(a)
    else
        reduce((x, y) -> relaxed_gcd(x, y; tol = tol), a)
    end
end

# -*- Variable Terms -*-
varmul(x::S, y::S) where {S} = Set{S}([x, y])
varmul(x::Set{S}, y::S) where {S} = push!(copy(x), y)
varmul(x::S, y::Set{S}) where {S} = push!(copy(y), x)
varmul(x::Set{S}, y::Set{S}) where {S} = union(x, y)

const × = varmul # \times
const ≺ = varlt # \prec, from QUBOTools

@doc raw"""
"""
function degree end # TODO: memoize

degree(f::PBF) = maximum(length.(keys(f)); init = 0)

# -*- Gap & Penalties -*-
@doc raw"""
""" function lowerbound end

lowerbound(f::PBF; bound::Symbol = :loose) = lowerbound(f, Val(bound))
lowerbound(f::PBF{<:Any,T}, ::Val{:loose}) where {T} =
    sum(c < zero(T) || isempty(ω) ? c : zero(T) for (ω, c) in f)

@doc raw"""
""" function upperbound end

upperbound(f::PBF; bound::Symbol = :loose) = upperbound(f, Val(bound))
upperbound(f::PBF{<:Any,T}, ::Val{:loose}) where {T} =
    sum(c > zero(T) || isempty(ω) ? c : zero(T) for (ω, c) in f)

@doc raw"""
""" function bounds end

bounds(f::PBF; bound::Symbol = :loose) =
    (lowerbound(f; bound = bound), upperbound(f; bound = bound))

@doc raw"""
    gap(f::PBF{S, T}; bound::Symbol=:loose) where {S, T}

Computes the least upper bound for the greatest variantion possible under some `` f \in \mathscr{F} `` i. e.

```math
\begin{array}{r l}
    \min        & M \\
    \text{s.t.} & \left|{f(\mathbf{x}) - f(\mathbf{y})}\right| \le M ~~ \forall \mathbf{x}, \mathbf{y} \in \mathbb{B}^{n} 
\end{array}
```

A simple approach, avaiable using the `bound=:loose` parameter, is to define
```math
M \triangleq \sum_{\omega \neq \varnothing} \left|{c_\omega}\right|
```
"""
function gap end

gap(f::PBF; bound::Symbol = :loose) = gap(f, Val(bound))
gap(f::PBF{<:Any,T}, ::Val{:loose}) where {T} =
    sum(abs(c) for (ω, c) in f if !isempty(ω); init = zero(T))
gap(::PBF, ::Val{:tight}) = error("Not Implemented: See [1] sec 5.1.1 Majorization")

const δ = gap

@doc raw"""
    sharpness(f::PBF{S, T}; bound::Symbol=:loose, tol::T = T(1e-6)) where {S, T}
"""
function sharpness end

function sharpness(f::PBF{S,T}; bound::Symbol = :loose, tol::T = 1e-6) where {S,T}
    return sharpness(f, Val(bound), tol)
end

function sharpness(::PBF{S,T}, ::Val{:none}, ::T) where {S,T}
    return one(T)
end

function sharpness(f::PBF{S,T}, ::Val{:loose}, tol::T = 1E-6) where {S,T}
    return relaxed_gcd(collect(values(f)); tol = tol)::T
end

const ϵ = sharpness

@doc raw"""
    derivative(f::PBF{S, T}, i::S) where {S, T}
    derivative(f::PBF{S, T}, i::Int) where {S, T}

The partial derivate of function ``f \in \mathscr{F}`` with respect to the ``i``-th variable.

```math
    \Delta_i f(\mathbf{x}) = \frac{\partial f(\mathbf{x})}{\partial \mathbf{x}_i} =
    \sum_{\omega \in \Omega\left[{f}\right] \setminus \left\{{i}\right\}}
    c_{\omega \cup \left\{{i}\right\}} \prod_{k \in \omega} \mathbf{x}_k
```
"""
function derivative end

function derivative(f::PBF{S,T}, s::S) where {S,T}
    return PBF{S,T}(ω => f[ω×s] for ω ∈ keys(f) if (s ∉ ω))
end

const Δ = derivative
const ∂ = derivative

function gradient(f::PBF{S,<:Any}, x::Vector{S}) where {S}
    return [derivative(f, x) for (s, _) in varmap(f)]
end

const ∇ = gradient

residual(f::PBF{S,T}, i::S) where {S,T} = PBF{S,T}(ω => c for (ω, c) ∈ keys(f) if (i ∉ ω))
residual(f::PBF, i::Int) = residual(f, varinv(f)[i])

function discretize(f::PBF{S,T}; tol::T = 1E-6) where {S,T}
    return discretize!(copy(f); tol = tol)
end

function discretize!(f::PBF{S,T}; tol::T = 1E-6) where {S,T}
    ε = sharpness(f; bound = :loose, tol = tol)

    for (ω, c) in f
        f[ω] = round(c / ε; digits = 0)
    end

    return f
end