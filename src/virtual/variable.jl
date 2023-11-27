@doc raw"""
    Variable{T}

"""
struct Variable{T}
    e::Union{VariableEncodingMethod,Nothing}
    x::Union{VI,CI,Nothing}          # Source variable or constraint (if any)
    y::Vector{VI}                    # Target variables
    ξ::PBO.PBF{VI,T}                 # Expansion function
    χ::Union{PBO.PBF{VI,T},Nothing}  # Penalty function (i.e. ‖gᵢ(x)‖ₛ for g(i) ∈ S)

    function Variable{T}(
        e::Union{VariableEncodingMethod,Nothing},
        x::Union{VI,CI,Nothing},
        y::Vector{VI},
        ξ::PBO.PBF{VI,T},
        χ::Union{PBO.PBF{VI,T},Nothing},
    ) where {T}
        return new{T}(e, x, y, ξ, χ)
    end
end

# Virtual mapping interface
source(v::Variable)    = v.x
target(v::Variable)    = v.y
encoding(v::Variable)  = v.e
expansion(v::Variable) = v.ξ
penaltyfn(v::Variable) = v.χ