@doc raw"""
    DomainWall{T}()

The Domain Wall[^Chancellor2019] encoding method is a sequential approach that requires ``n - 1`` bits to represent ``n`` distinct values.

```math
\xi{[\set{\gamma_{j}}_{j \in [n]}]}(\mathbf{y}) = \sum_{j = 1}^{n} \gamma_{j} (y_{j} - y_{j + 1}) ~\textrm{s.t.}~ \sum_{j = 1}^{n} y_{j} \oplus y_{j + 1} = 1, y_{1} = 1, y_{n + 1} = 0
```

where ``\mathbf{y} \in \mathbb{B}^{n + 1}``.

[^Chancellor2019]:
    Nicholas Chancellor, **Domain wall encoding of discrete variables for quantum annealing and QAOA**, *Quantum Science Technology 4*, 2019.
"""
struct DomainWall{T} <: SetVariableEncodingMethod end

# Arbitrary set
function encode(var::Function, e::DomainWall{T}, γ::AbstractVector{T}) where {T}
    p = length(γ)
    n = encoding_bits(e, p)

    if p == 0
        y = VI[]
        ξ = PBO.PBF{VI,T}()
        χ = nothing
    elseif p == 1
        y = Vector{VI}()
        ξ = PBO.PBF{VI,T}(γ[1])
        χ = nothing
    else
        y = var(n)::Vector{VI}
        ξ = PBO.PBF{VI,T}([γ[1]; [y[i] => (γ[i+1] - γ[i]) for i = 1:n]])
        χ = PBO.PBF{VI,T}([[y[i] => 2 for i = 2:n]; [(y[i], y[i+1]) => -2 for i = 1:(n-1)]])
    end

    return (y, ξ, χ)
end

# Integer
function encode(
    var::Function,
    e::E,
    S::Tuple{T,T};
    tol::Union{T,Nothing} = nothing,
) where {T,E<:DomainWall{T}}
    isnothing(tol) || return encode(var, e, S, nothing; tol)

    a, b = integer_interval(S)

    return encode(var, e, collect(a:b))
end

function encoding_points(
    ::E,
    S::Tuple{T,T},
    tol::T,
) where {T,E<:DomainWall{T}}
    a, b = S

    return ceil(Int, ((b - a)^2 / 4tol) + 1)
end

function encoding_points(::DomainWall, n::Integer)
    return n + 1
end

function encoding_bits(e::E, S::Tuple{T,T}, tol::T) where {T,E<:DomainWall{T}}
    p = encoding_points(e, S, tol)

    return encoding_bits(e, p)
end

function encoding_bits(::DomainWall, p::Integer)
    return p - 1
end

# Real
function encode(
    var::Function,
    e::E,
    S::Tuple{T,T},
    n::Union{Integer,Nothing};
    tol::Union{T,Nothing} = nothing,
) where {T,E<:DomainWall{T}}
    @assert !(isnothing(n) && isnothing(tol))

    p = if isnothing(n)
        encoding_points(e, S, tol)
    else
        encoding_points(e, n)
    end

    a, b = S

    Γ = collect(range(a, b; length = p))

    return encode(var, e, Γ)
end
