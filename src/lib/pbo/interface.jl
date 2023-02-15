
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

const δ = gap

@doc raw"""
    sharpness(f::PBF{S, T}; bound::Symbol=:loose, tol::T = T(1e-6)) where {S, T}
"""
function sharpness end

const ϵ = sharpness

@doc raw"""
    derivative(f::PBF{V,T}, x::V) where {V,T}

The partial derivate of function ``f \in \mathscr{F}`` with respect to the ``x`` variable.

```math
    \Delta_i f(\mathbf{x}) = \frac{\partial f(\mathbf{x})}{\partial \mathbf{x}_i} =
    \sum_{\omega \in \Omega\left[{f}\right] \setminus \left\{{i}\right\}}
    c_{\omega \cup \left\{{i}\right\}} \prod_{k \in \omega} \mathbf{x}_k
```
"""
function derivative end

const Δ = derivative
const ∂ = derivative

@doc raw"""
    gradient(f::PBF)

Computes the gradient of ``f \in \mathscr{F}`` where the ``i``-th derivative is given by [`derivative`](@ref).
""" function gradient end

const ∇ = gradient

@doc raw"""
    residual(f::PBF{S, T}, x::S) where {S, T}

The residual of ``f \in \mathscr{F}`` with respect to ``x``.

```math
    \Theta_i f(\mathbf{x}) = f(\mathbf{x}) - \mathbf{x}_i\, \Delta_i f(\mathbf{x}) =
    \sum_{\omega \in \Omega\left[{f}\right] \setminus \left\{{i}\right\}}
    c_{\omega} \prod_{k \in \omega} \mathbf{x}_k
```
""" function residual end

const Θ = residual

@doc raw"""
    discretize(f::PBF{V,T}; tol::T) where {V,T}

For a given function ``f \in \mathscr{F}`` written as

```math
    f\left({\mathbf{x}}\right) = \sum_{\omega \in \Omega\left[{f}\right]} c_\omega \prod_{i \in \omega} \mathbf{x}_i
```

computes an approximate function  ``g : \mathbb{B}^{n} \to \mathbb{Z}`` such that

```math
    \text{argmin}_{\mathbf{x} \in \mathbb{B}^{n}} g\left({\mathbf{x}}\right) = \text{argmin}_{\mathbf{x} \in \mathbb{B}^{n}} f\left({\mathbf{x}}\right)
```

This is done by rationalizing every coefficient ``c_\omega`` according to some tolerance `tol`.

""" function discretize end

@doc raw"""
    discretize!(f::PBF{V,T}; tol::T) where {V,T}

In-place version of [`discretize`](@ref).
""" function discretize! end