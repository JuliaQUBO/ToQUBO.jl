# -*- Variable Terms -*-
×(x::S, y::S) where {S} = Set{S}([x, y])
×(x::Set{S}, y::S) where {S} = union(x, y)
×(x::S, y::Set{S}) where {S} = union(x, y)
×(x::Set{S}, y::Set{S}) where {S} = union(x, y)

# -*- Variable Comparison -*-
@doc raw"""
"""
function varcmp end

varcmp(x::S, y::S) where S = isless(x, y) # fallback

function varmap(f::PBF{S, <:Any}) where S
    Dict{S, Int}(x => i for (i, x) in enumerate(sort(collect(reduce(union, keys(f.Ω))); lt=varcmp)))
end

@doc raw"""
"""
function degree end

function degree(f::PBF)
    maximum(length.(keys(f.Ω)); init=0)
end

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

# -*- Gap & Penalties -*-
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
function gap(f::PBF{S, T}; bound::Symbol=:loose) where {S, T}
    if bound === :loose
        return sum(abs(c) for (ω, c) in f if !isempty(ω); init = zero(T))
    elseif bound === :tight
        error("Not Implemented: See [1] sec 5.1.1 Majorization")
    else
        throw(ArgumentError(": Unknown bound thightness $bound"))
    end
end

const δ = gap

@doc raw"""
    sharpness(f::PBF{S, T}; bound::Symbol=:loose, tol::T = T(1e-6)) where {S, T}
"""
function sharpness(f::PBF{S, T}; bound::Symbol=:loose, tol::T = 1e-6) where {S, T}
    if bound === :none
        one(T)
    elseif bound === :loose
        relaxed_gcd(collect(values(f.Ω)); tol = tol)::T
    elseif bound === :tight
        error("Not Implemented: thightness $bound")
    else
        throw(ArgumentError(": Unknown bound thightness $bound"))
    end
end

const ϵ = sharpness

# -*- Computations with PBF's -*-
function terms(f::PBF{S, T}) where {S, T}
    return keys(f.Ω)
end

const Ω = terms

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
function derivative(f::PBF{S, T}, s::S) where {S, T}
    return PBF{S, T}(ω => f[ω × s] for ω ∈ Ω(f) if (s ∉ ω))
end

function derivative(f::PBF{S, T}, i::Int) where {S, T}
    return derivative(f, varinv(f)[i])
end

const Δ = derivative
const ∂ = derivative

@doc raw"""
    gradient(f::PBF)

Computes the gradient of ``f \in \mathscr{F}`` where the ``i``-th derivative is given by [`derivative`](@ref).
"""
function gradient(f::PBF)
    return [derivative(f, s) for (s, _) ∈ varmap(f)]
end

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
function residual(f::PBF{S, T}, i::S) where {S, T}
    return PBF{S, T}(ω => c for (ω, c) ∈ Ω(f) if (i ∉ ω))
end

function residual(f::PBF{S, T}, i::Int) where {S, T}
    return Θ(f, varinv(f)[i])
end

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
    round(f / ϵ(f; bound = :loose, tol = tol)::T; digits=0)
end