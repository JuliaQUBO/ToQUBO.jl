
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

OneHot() = OneHot{Float64}()

# Arbitrary set
function encode(var::Function, e::OneHot{T}, γ::AbstractVector{T}) where {T}
    p = length(γ)
    n = encoding_bits(e, p)

    if p == 0
        y = Vector{VI}()
        ξ = PBO.PBF{VI,T}()
        χ = nothing
    elseif p == 1
        y = Vector{VI}()
        ξ = PBO.PBF{VI,T}(γ[1])
        χ = nothing
    else
        y = var(n)::Vector{VI}
        ξ = PBO.PBF{VI,T}([y[i] => γ[i] for i = 1:p])
        χ = PBO.PBF{VI,T}([y; -1])^2
    end

    return (y, ξ, χ)
end

# Integer
function encode(
    var::Function,
    e::E,
    S::Tuple{T,T};
    tol::Union{T,Nothing} = nothing,
) where {T,E<:OneHot{T}}
    isnothing(tol) || return encode(var, e, S, nothing; tol)

    a, b = integer_interval(S)

    return encode(var, e, collect(a:b))
end

function encoding_points(
    ::E,
    S::Tuple{T,T},
    tol::T,
) where {T,E<:OneHot{T}}
    a, b = S

    return ceil(Int, ((b - a)^2 / 4tol) + 1)
end

function encoding_points(::OneHot, n::Integer)
    return n
end

function encoding_bits(e::E, S::Tuple{T,T}, tol::T) where {T,E<:OneHot{T}}
    return encoding_points(e, S, tol)
end

function encoding_bits(::OneHot, p::Integer)
    return p
end

# Real
function encode(
    var::Function,
    e::E,
    S::Tuple{T,T},
    n::Union{Integer,Nothing};
    tol::Union{T,Nothing} = nothing,
) where {T,E<:OneHot{T}}
    @assert !(isnothing(n) && isnothing(tol))

    p = if isnothing(n)
        encoding_points(e, S, tol)
    else
        encoding_points(e, n)
    end

    a, b = S

    Γ = if p == 1
        T[(a + b) / 2]
    else
        collect(T, range(a, b; length = p))
    end

    return encode(var, e, Γ)
end
