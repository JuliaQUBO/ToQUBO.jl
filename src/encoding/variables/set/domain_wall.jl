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

function encode(
    var::Function,
    ::DomainWall{T},
    γ::AbstractVector{T},
) where {T}
    n = length(γ)

    if n == 0
        y = VI[]
        ξ = PBO.PBF{VI,T}()
        χ = nothing
    elseif n == 1
        y = Vector{VI}()
        ξ = PBO.PBF{VI,T}(γ[1])
        χ = nothing
    else
        y = var(n)::Vector{VI}
        ξ = PBO.PBF{VI,T}(y[i] => (γ[i] - γ[i+1]) for i = 1:n)
        χ = 2 * (PBO.PBF{VI,T}(y[2:n]) - PBO.PBF{VI,T}((y[i], y[i-1]) for i = 2:n))
    end

    return (y, ξ, χ)
end
