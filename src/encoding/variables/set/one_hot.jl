
@doc raw"""
    OneHot{T}()

The one-hot encoding is a linear technique used to represent a variable ``x \in \set{\gamma_{j}}_{j \in [n]}``.

The associated encoding function is combined with a constraint assuring that only one and exactly one of the expansion's variables ``y_{j}`` is activated at a time.

```math
\xi[\set{\gamma_{j}}_{j \in [n]}](\mathbf{y}) = \sum_{j = 1}^{n} \gamma_{j} y_{j} ~\textrm{s.t.}~ \sum_{j = 1}^{n} y_{j} = 1
```

When a variable is encoded following this approach, a penalty term of the form

```math
\rho \left[ \sum_{j = 1}^{n} y_{j} - 1 \right]^{2}
```

is added to the objective function.

"""
struct OneHot{T} <: SetVariableEncodingMethod end

# Arbitrary set
function encode(var::Function, ::OneHot{T}, γ::AbstractVector{T}) where {T}
    n = length(γ)

    y = var(n)::Vector{VI}
    ξ = PBO.PBF{VI,T}([a; [y[i] => γ[i] for i = 1:n]])
    χ = PBO.PBF{VI,T}([y; -one(T)])^2

    return (y, ξ, χ)
end
