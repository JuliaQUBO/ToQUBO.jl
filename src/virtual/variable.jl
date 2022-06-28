# -*- Virtual Variable Encoding -*-
abstract type Encoding end

@doc raw"""
# Variable Expansion methods:
    - Linear
    - Unary
    - Binary
    - One Hot
    - Domain Wall

# References:
 * [1] Chancellor, N. (2019). Domain wall encoding of discrete variables for quantum annealing and QAOA. _Quantum Science and Technology_, _4_(4), 045004. [{doi}](https://doi.org/10.1088/2058-9565/ab33c2)
"""
struct VirtualVariable{E<:Encoding, T}
    x::Union{VI, Nothing}             # Source variable (if there is one)
    y::Vector{VI}                     # Target variables
    ξ::PBO.PBF{VI, T}                 # Expansion function
    h::Union{PBO.PBF{VI, T}, Nothing} # Penalty function (i.e. ‖gᵢ(x)‖ₛ for g(i) ∈ S)

    function VirtualVariable{E, T}(
            x::Union{VI, Nothing},
            y::Vector{VI},
            ξ::PBO.PBF{VI, T},
            h::Union{PBO.PBF{VI, T}, Nothing},
        ) where {E <: Encoding, T}
        new{E, T}(x, y, ξ, h)
    end
end

# -*- Variable Information -*-
source(v::VirtualVariable) = v.x
target(v::VirtualVariable) = v.y
isslack(v::VirtualVariable) = isnothing(source(v))
expansion(v::VirtualVariable) = v.ξ
penaltyfn(v::VirtualVariable) = v.h

abstract type LinearEncoding <: Encoding end

@doc raw"""
""" struct Mirror <: LinearEncoding end
@doc raw"""
""" struct Linear <: LinearEncoding end
@doc raw"""
""" struct Unary <: LinearEncoding end

@doc raw"""
Binary Expansion within the closed interval ``[\alpha, \beta]``.

For a given variable ``x \in [\alpha, \beta]`` we approximate it by

```math    
x \approx \alpha + \frac{(\beta - \alpha)}{2^{n} - 1} \sum_{i=0}^{n-1} {2^{i}\, y_i}
```

where ``n`` is the number of bits and ``y_i \in \mathbb{B}``.
""" struct Binary <: LinearEncoding end

function VirtualVariable{E, T}(
        x::Union{VI, Nothing},
        y::Vector{VI},
        γ::Vector{T},
        α::T = zero(T),
    ) where {E <: LinearEncoding, T}
    @assert (n = length(y)) == length(γ)
    
    VirtualVariable{E, T}(
        x,
        y,
        (α + PBO.PBF{VI, T}(y[i] => γ[i] for i = 1:n)),
        nothing,
    )
end

@doc raw"""
""" struct OneHot <: LinearEncoding end

function VirtualVariable{OneHot, T}(
        x::Union{VI, Nothing},
        y::Vector{VI},
        γ::Vector{T},
        α::T = zero(T),
    ) where T
    @assert (n = length(y)) == length(γ)

    VirtualVariable{OneHot, T}(
        x,
        y,
        (α + PBO.PBF{VI, T}(y[i] => γ[i] for i = 1:n)),
        (one(T) - PBO.PBF{VI, T}(y)) ^ 2,
    )
end

abstract type SequentialEncoding <: Encoding end

struct DomainWall <: SequentialEncoding end

function VirtualVariable{DomainWall, T}(
        x::Union{VI, Nothing},
        y::Vector{VI},
        γ::Vector{T},
        α::T = zero(T),
    ) where T
    @assert (n = length(y)) + 1 == length(γ)

    ξ = PBO.PBF{VI, T}(y[i] => (γ[i] - γ[i+1]) for i = 1:n)
    h = 2.0 * (PBO.PBF{VI, T}(y[2:n]) - PBO.PBF{VI, T}([Set{VI}([y[i], y[i-1]]) for i = 2:n]))

    VirtualVariable{DomainWall, T}(x, y, ξ, h)
end

# :: Alias ::
const VV{E, T} = VirtualVariable{E, T}