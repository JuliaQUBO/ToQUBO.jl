@doc raw"""
    gradient(f::PBF)

Computes the gradient of ``f \in \mathscr{F}`` where the ``i``-th derivative is given by [`derivative`](@ref).
""" function gradient end

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
    discretize(f::PBF{S, T}; tol::T) where {S, T}

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