# -*- Relaxed Greatest Common Divisor -*-
@doc raw"""
    relaxed_gcd(x::T, y::T; tol::T = T(1e-6)) where {T <: AbstractFloat}

We define two real numbers ``x`` and ``y`` to be ``\tau``-comensurable if, for some ``\tau > 0`` there exists a continued fractions convergent ``p_{k} \div q_{k}`` such that

```math
    \left| {q_{k} x - p_{k} y} \right| \le \tau
```
"""
function relaxed_gcd(x::T, y::T; tol::T = 1e-6) where {T}
    if abs(x) < abs(y)
        relaxed_gcd(y, x; tol=tol)::T
    elseif abs(y) < tol
        x
    elseif abs(x) < tol
        y
    else
        (x / numerator(rationalize(x / y; tol=tol)))::T
    end
end

function relaxed_gcd(a::AbstractArray{T}; tol::T = 1e-6) where {T}
    if length(a) == 0
        one(T)
    elseif length(a) == 1
        first(a)
    else
        reduce((x, y) -> relaxed_gcd(x, y; tol=tol), a)
    end
end

# -*- Variable Terms -*-
varmul(x::S, y::S) where S = Set{S}([x, y])
varmul(x::Set{S}, y::S) where S = push!(x, y)
varmul(x::S, y::Set{S}) where S = push!(y, x)
varmul(x::Set{S}, y::Set{S}) where S = union(x, y)

const × = varmul # \times

# -*- Variable Comparison -*-
@doc raw"""
"""
function varcmp end 

varcmp(x::S, y::S) where S = isless(x, y) # fallback

const ≺ = varcmp # \prec

@doc raw"""
"""
function varmap end # TODO: memoize

function varmap(f::PBF{S, <:Any}) where S
    Dict{S, Int}(x => i for (i, x) in enumerate(sort(collect(reduce(union, keys(f); init=Set{S}())); lt=varcmp)))
end

@doc raw"""
"""
function degree end # TODO: memoize

degree(f::PBF) = maximum(length.(keys(f)); init=0)

# -*- Gap & Penalties -*-
sup(f::PBF; bound::Symbol=:loose) = sup(f, Val(bound))
sup(f::PBF{<:Any, T}, ::Val{:loose}) where T = sum(c > zero(T) || isempty(ω) ? c : zero(T) for (ω, c) in f)

inf(f::PBF; bound::Symbol=:loose) = inf(f, Val(bound))
inf(f::PBF{<:Any, T}, ::Val{:loose}) where T = sum(c < zero(T) || isempty(ω) ? c : zero(T) for (ω, c) in f)

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

gap(f::PBF; bound::Symbol=:loose) = gap(f, Val(bound))
gap(f::PBF{<:Any, T}, ::Val{:loose}) where T = sum(abs(c) for (ω, c) in f if !isempty(ω); init = zero(T))
gap(::PBF, ::Val{:tight}) = error("Not Implemented: See [1] sec 5.1.1 Majorization")

const δ = gap

@doc raw"""
    sharpness(f::PBF{S, T}; bound::Symbol=:loose, tol::T = T(1e-6)) where {S, T}
"""
function sharpness end

sharpness(f::PBF{<:Any, T}; bound::Symbol=:loose, tol::T=1e-6) where T = sharpness(f, Val(bound), tol)
sharpness(::PBF{<:Any, T}, ::Val{:none}, ::T) where T = one(T)
sharpness(f::PBF{<:Any, T}, ::Val{:loose}, tol::T = 1e-6) where T = relaxed_gcd(collect(values(f.Ω)); tol = tol)::T
sharpness(::PBF{<:Any, T}, ::Val{:tight}, ::T) where T = error("Not Implemented: 'tight' bound")

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

derivative(f::PBF{S, T}, s::S) where {S, T} = PBF{S, T}(ω => f[ω × s] for ω ∈ Ω(f) if (s ∉ ω))

const Δ = derivative
const ∂ = derivative

@doc raw"""
    gradient(f::PBF)

Computes the gradient of ``f \in \mathscr{F}`` where the ``i``-th derivative is given by [`derivative`](@ref).
"""
gradient(f::PBF) = [derivative(f, s) for (s, _) in varmap(f)]

const ∇ = gradient

@doc raw"""
    residual(f::PBF{S, T}, i::S) where {S, T}
    residual(f::PBF{S, T}, i::Int) where {S, T}

The residual of function ``f \in \mathscr{F}`` with respect to the ``i``-th variable.

```math
    \Theta_i f(\mathbf{x}) = f(\mathbf{x}) - \mathbf{x}_i\, \Delta_i f(\mathbf{x}) =
    \sum_{\omega \in \Omega\left[{f}\right] \setminus \left\{{i}\right\}}
    c_{\omega} \prod_{k \in \omega} \mathbf{x}_k
```
"""
residual(f::PBF{S, T}, i::S) where {S, T} = PBF{S, T}(ω => c for (ω, c) ∈ Ω(f) if (i ∉ ω))
residual(f::PBF, i::Int) = residual(f, varinv(f)[i])

const Θ = residual

# -*- Integer Coefficients -*-
@doc raw"""
    discretize(f::PBF{S, T}; tol::T) where {S, T}

For a given function ``f \in \mathscr{F}`` written as

```math
    f\left({\mathbf{x}}\right) = \sum_{\omega \in \Omega\left[{f}\right]} c_\omega \prod_{i \in \omega} \mathbf{x}_i
```

computes an approximate function  ``g : \mathbb{B}^{n} \to \mathbb{Z}`` such that

```math
    \argmin_{\mathbf{x} \in \mathbb{B}^{n}} g\left({\mathbf{x}}\right) = \argmin_{\mathbf{x} \in \mathbb{B}^{n}} f\left({\mathbf{x}}\right)
```

This is done by rationalizing every coefficient ``c_\omega`` according to some tolerance `tol`.

"""
function discretize(f::PBF{<:Any, T}; tol::T = 1e-6) where {T}
    round(f / sharpness(f; bound = :loose, tol = tol); digits=0)
end