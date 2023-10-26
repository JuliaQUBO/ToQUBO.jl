@doc raw"""
    Arithmetic{T}()

## Integer
Let ``x \in [a, b] \subset \mathbb{Z}``, ``n = \left\lceil{ \frac{1}{2} {\sqrt{1 + 8 (b - a)}} - \frac{1}{2} }\right\rceil`` and ``\mathbf{y} \in \mathbb{B}^{n}``.

```math
\xi{[a, b]}(\mathbf{y}) = a + \left( {b - a - \frac{n (n - 1)}{2}} \right) y_{n} + \sum_{j = 1}^{n - 1} j y_{j}
```

## Real
Given ``n \in \mathbb{N}`` for ``x \in [a, b] \subset \mathbb{R}``,

```math
\xi{[a, b]}(\mathbf{y}) = a + \frac{b - a}{n (n + 1)} \sum_{j = 1}^{n} j y_{j}
```

### Representation error

Given ``\tau > 0``, for the expected encoding error to be less than or equal to ``\tau``, at least

```math
n \ge \frac{1}{2} \left[ 1 + \sqrt{3 + \frac{(b - a)}{2 \tau})} \right]
```
"""
struct Arithmetic{T} <: IntervalVariableEncodingMethod end

Arithmetic() = Arithmetic{Float64}()

@doc raw"""
    encode(var::Function, ::Arithmetic{T}, S::Tuple{T,T}) where {T}
"""
function encode(var::Function, e::Arithmetic{T}, S::Tuple{T,T}; tol::Union{T,Nothing} = nothing) where {T}
    isnothing(tol) || return encode(var, e, S, nothing; tol)

    a, b = integer_interval(S)

    @assert b > a

    M = trunc(Int, b - a)
    N = ceil(Int, (sqrt(1 + 8M) - 1) / 2)

    if N == 0
        y = VI[]
        ξ = PBO.PBF{VI,T}((a + b) / 2)
    else
        y = var(N)::Vector{VI}
        ξ = PBO.PBF{VI,T}(
            [
                a
                [y[i] => i for i = 1:N-1]
                y[N] => M - N * (N - 1) / 2
            ],
        )
    end

    return (y, ξ, nothing) # No penalty function
end

function encoding_bits(::Arithmetic{T}, S::Tuple{T,T}, tol::T) where {T}
    @assert tol > zero(T)

    a, b = S

    return ceil(Int, (1 + sqrt(3 + abs(b - a) / 2tol)) / 2)
end

# Real (fixed)
function encode(
    var::Function,
    e::Arithmetic{T},
    S::Tuple{T,T},
    n::Union{Integer,Nothing};
    tol::Union{T,Nothing} = nothing,
) where {T}
    @assert !(isnothing(tol) && isnothing(n))

    if isnothing(n)
        n = encoding_bits(e, S, tol)
    end

    @assert n >= 0

    a, b = S

    if n == 0
        y = Vector{VI}()
        ξ = PBO.PBF{VI,T}((a + b) / 2)
    else
        y = var(n)::Vector{VI}
        ξ = PBO.PBF{VI,T}([a; [y[i] => 2i * (b - a) / (n * (n + 1)) for i = 1:n]])
    end

    return (y, ξ, nothing) # No penalty function
end
