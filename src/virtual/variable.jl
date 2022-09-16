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
source(v::VirtualVariable)    = v.x
target(v::VirtualVariable)    = v.y
isslack(v::VirtualVariable)   = isnothing(source(v))
expansion(v::VirtualVariable) = v.ξ
penaltyfn(v::VirtualVariable) = v.h

# ~*~ Alias ~*~
const VV{E, T} = VirtualVariable{E, T}