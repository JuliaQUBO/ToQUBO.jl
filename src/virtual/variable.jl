# -*- Virtual Variable Encoding -*-
abstract type Encoding end

@doc raw"""
# Variable Expansion techniques:

# References:
 * [1] Chancellor, N. (2019). Domain wall encoding of discrete variables for quantum annealing and QAOA. _Quantum Science and Technology_, _4_(4), 045004. [{doi}](https://doi.org/10.1088/2058-9565/ab33c2)
"""
struct VirtualVariable{E<:Encoding, T<:Any}
    x::Union{VI, Nothing}
    y::Vector{VI}
    ξ::PBO.PBF{VI, T}
    h::Union{PBO.PBF{VI, T}, Nothing}
end

# -*- Variable Information -*-
source(v::VirtualVariable) = v.x
target(v::VirtualVariable) = v.y
isslack(v::VirtualVariable) = isnothing(source(v))
expansion(v::VirtualVariable) = v.ξ
penaltyfn(v::VirtualVariable) = v.h

abstract type LinearEncoding end

struct Linear <: LinearEncoding end

struct Unary <: LinearEncoding end

@doc raw"""
Binary Expansion within the closed interval ``[\alpha, \beta]``.

For a given variable ``x \in [\alpha, \beta]`` we approximate it by

```math    
x \approx \alpha + \frac{(\beta - \alpha)}{2^{n} - 1} \sum_{i=0}^{n-1} {2^{i}\, y_i}
```

where ``n`` is the number of bits and ``y_i \in \mathbb{B}``.
"""
struct Binary <: LinearEncoding end

function VirtualVariable{E, T}(
        source::Union{VI, Nothing},
        target::Vector{VI},
        γ::Vector{T},
        α::T = zero(T),
    ) where {E <: LinearEncoding, T}
    @assert length(target) == length(γ)
    
    new{E, T}(
        source,
        target,
        (α + PBO.PBF{VI, T}(yᵢ => γᵢ for (yᵢ, γᵢ) in zip(target, γ))),
        nothing,
    )
end

struct BooleanMirror <: Encoding end

function VirtualVariable{BooleanMirror, T}(source::Union{VI, Nothing}, target::Vector{VI}) where T
    new{BooleanMirror, T}(
        source,
        target,
        PBO.PBF{VI, T}(target),
        nothing,
    )
end

struct OneHot <: Encoding end

function VirtualVariable{OneHot, T}(
        source::Union{VI, Nothing},
        target::Vector{VI},
        γ::Vector{T},
        α::T = zero(T),
    ) where {E <: LinearEncoding, T}
    @assert length(target) == length(γ)

    new{E, T}(
        source,
        target,
        (α + PBO.PBF{VI, T}(yᵢ => γᵢ for (yᵢ, γᵢ) in zip(target, γ))),
        (1 - PBO.PBF{VI, T}(target)) ^ 2,
    )
end

struct DomainWall <: Encoding end

# :: Alias ::
const VV{E, T} = VirtualVariable{E, T}