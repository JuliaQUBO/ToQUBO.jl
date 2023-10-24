@doc raw"""
    Binary{T}()

## Integer

Let ``x \in [a, b] \subset \mathbb{Z}``, ``n = \left\lceil \log_{2}(b - a) + 1 \right\rceil`` and ``\mathbf{y} \in \mathbb{B}^{n}``.

```math
\xi{[a, b]}(\mathbf{y}) = a + \left(b - a - 2^{n - 1} + 1\right) y_{n} + \sum_{j = 1}^{n - 1} 2^{j - 1} y_{j}
```

## Real

Given ``n \in \mathbb{N}`` for ``x \in [a, b] \subset \mathbb{R}``,

```math
\xi{[a, b]}(\mathbf{y}) = a + \frac{b - a}{2^{n} - 1} \sum_{j = 1}^{n} 2^{j - 1} y_{j}
```

### Encoding error

Given ``\tau > 0``, for the expected encoding error to be less than or equal to ``\tau``, at least

```math
n \ge \log_{2} \left[1 + \frac{b - a}{4 \tau}\right]
```

binary variables become necessary.
"""
struct Binary{T} <: IntervalVariableEncodingMethod end

Binary() = Binary{Float64}()

# Integer
function encode(var::Function, e::Binary{T}, S::Tuple{T,T}; tol::Union{T,Nothing} = nothing) where {T}
    isnothing(tol) || return encode(var, e, S, nothing; tol)

    a, b = integer_interval(S)

    @assert b > a

    M = trunc(Int, b - a)
    N = ceil(Int, log2(M + 1))

    if N == 0
        y = VI[]
        ξ = PBO.PBF{VI,T}((a + b) / 2)
    else
        y = var(N)::Vector{VI}
        ξ = PBO.PBF{VI,T}(
            [
                a
                [y[i] => 2^(i - 1) for i = 1:N-1]
                y[N] => M - 2^(N - 1) + 1
            ],
        )
    end

    return (y, ξ, nothing) # No penalty function
end

# @doc raw"""
#     encode(var::Function, e::Bounded{Binary{T},T}, S::Tuple{T,T}) where {T}

# Given ``\mu > 0``, let ``x \in [a, b] \subset \mathbb{Z}`` and ``n = b - a``.

# First,

# ```math
# \begin{align*}
#             2^{k - 1} &\leq \mu \\
#            \implies k &=    \left\lfloor\log_{2} \mu + 1 \right\rfloor
# \end{align*}
# ```

# Since

# ```math
# \sum_{j = 1}^{k} 2^{j - 1} = \sum_{j = 0}^{k - 1} 2^{j} = 2^{k} - 1
# ```

# then, for ``r \in \mathbb{N}``

# ```math
# n = 2^{k} - 1 + r \times \mu + \epsilon \implies r = \left\lfloor \frac{n - 2^{k} + 1}{\mu} \right\rfloor
# ```

# and

# ```math
# \epsilon = n - 2^{k} + 1 - r \times \mu
# ```

# Therefore,

# ```math
# \xi_{\mu}{[a, b]}(\mathbf{y}) = \sum_{j = 1} \gamma_{j} y_{j}
# ```

# where

# ```math
# \gamma_{j} = \left\lbrace\begin{array}{cl}
#     2^{j} & \text{if } 1 \le j \le k   \\
#     \mu   & \text{if } k < j < r + k   \\
#     n - 2^k + 1 - r \times \mu & \text{otherwise}
# \end{array}\right.
# """
# function encode(var::Function, e::Bounded{Binary{T},T}, S::Tuple{T,T}) where {T}
#     a, b = integer_interval(S)

#     n = round(Int, b - a)
#     k = floor(Int, log2(e.μ) + 1)
#     m = 2^k - 1
#     r = floor(Int, (n - m) / e.μ)
#     ϵ = n - m - r * e.μ

#     γ = if iszero(ϵ)
#         T[[2^(j - 1) for j = 1:k]; fill(e.μ, r)]
#     else
#         T[[2^(j - 1) for j = 1:k]; ϵ; fill(e.μ, r)]
#     end

#     N = length(γ)

#     if N == 0
#         y = VI[]
#         ξ = PBO.PBF{VI,T}((a + b) / 2)
#     else
#         y = var(N)::Vector{VI}
#         ξ = PBO.PBF{VI,T}([a; [y[i] => γ[i] for i = 1:N]])
#     end

#     return (y, ξ, nothing) # No penalty function
# end

function encoding_bits(::Binary{T}, S::Tuple{T,T}, tol::T) where {T}
    @assert tol > zero(T)

    a, b = S

    return ceil(Int, log2(1 + abs(b - a) / 4tol))
end

# Real
function encode(
    var::Function,
    e::Binary{T},
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
        ξ = PBO.PBF{VI,T}([a; [y[i] => (b - a) * 2^(i - 1) / (2^n - 1) for i = 1:n]])
    end

    return (y, ξ, nothing) # No penalty function
end
