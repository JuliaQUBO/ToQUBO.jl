
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
function encode(
    var::Function,
    ::OneHot{T},
    γ::AbstractVector{T},
    a::T = zero(T),
) where {T}
    n = length(γ)

    y = var(n)::Vector{VI}
    ξ = PBO.PBF{VI,T}([a; [y[i] => γ[i] for i = 1:n]])
    χ = PBO.PBF{VI,T}([y; -one(T)])^2

    return (y, ξ, χ)
end

# Integer
function encode(
    var::Function,
    ::OneHot{T},
    S::Tuple{T,T},
) where {T}
    ā, b̄ = S
    a, b = ā < b̄ ? (ceil(ā), floor(b̄)) : (ceil(b̄), floor(ā))

    N = floor(Int, b - a)

    if N == 0
        y = VI[]
        ξ = PBO.PBF{VI,T}((a + b) / 2)
        χ = nothing
    else
        y = var(N)::Vector{VI}
        ξ = PBO.PBF{VI,T}([a; [y[i] => (i - one(T)) for i = 1:N]])
        χ = (PBO.PBF{VI,T}(y) - one(T))^2
    end

    return (y, ξ, χ)
end

# Real (fixed)
function encode(
    var::Function,
    ::OneHot{T},
    n::Integer,
    S::Tuple{T,T},
) where {T}
    a, b = S

    @assert n >= 0

    y = var(n)::Vector{VI}
    ξ = if n == 0
        PBO.PBF{VI,T}((a + b) / 2)
    else
        PBO.PBF{VI,T}([a; [y[i] => (i - 1) * (b - a) / (n - 1) for i = 1:n]])
    end
    χ = if n == 0
        nothing
    else
        (PBO.PBF{VI,T}(y) - one(T))^2
    end

    return (y, ξ, χ)
end

# Real (tolerance)
function encode(
    var::Function,
    e::OneHot{T},
    S::Tuple{T,T},
    tol::T
) where {T}
    a, b = S

    @assert tol > zero(T)

    n = ceil(Int, (1 + abs(b - a) / 4tol))

    return encode(var, e, n, S)
end
