# ::: Variable Management :::
const 𝒱{T} = VirtualVariable{VI, T}

# -*- Expand: Interpret existing variable through its binary expansion -*-
"""
    expandℝ!(model::QUBOModel{T}, src::VI; bits::Int, name::Symbol, α::T, β::T) where T

Real Expansion
"""
function expandℝ!(model::QUBOModel{T}, src::Union{VI, Nothing}; bits::Int, name::Symbol, α::T, β::T) where T
    model.source[src] = 𝒱{T}(
        (n) -> MOI.add_variables(model, n),
        src;
        tech=:ℝ₂,
        bits=bits,
        name=name,
        α=α,
        β=β
    )
end

function expandℝ(model::QUBOModel{T}, src::Union{VI, Nothing}; bits::Int, name::Symbol, α::T, β::T) where T
    expandℝ!(model, src; bits=bits, name=name, α=α, β=β)
    return model.source[src]
end

"""
    expandℤ!(model::QUBOModel{T}, src::VI; name::Symbol, α::T, β::T) where T

Integer Expansion
"""
function expandℤ!(model::QUBOModel{T}, src::Union{VI, Nothing}; name::Symbol, α::T, β::T) where T
    model.source[src] = 𝒱{T}(
        (n) -> MOI.add_variables(model, n),
        src;
        tech=:ℤ₂,
        name=name,
        α=α,
        β=β
    )
end

function expandℤ(model::QUBOModel{T}, src::Union{VI, Nothing}; name::Symbol, α::T, β::T) where T
    expandℤ!(model, src; name=name, α=α, β=β)
    return model.source[src]
end

"""
    mirror𝔹!(model::QUBOModel{T}, src::Union{VI, Nothing}; name::Symbol) where T

Binary Mirroring
"""
function mirror𝔹!(model::QUBOModel{T}, src::Union{VI, Nothing}; name::Symbol) where T
    model.source[src] = 𝒱{T}(
        (n) -> MOI.add_variables(model, n),
        src;
        tech=:𝔹,
        name=name
    )
end

function mirror𝔹(model::QUBOModel{T}, var::Union{VI, Nothing}; name::Symbol) where T
    mirror𝔹!(model, var, name=name)
    return model.source[var]
end

function vars(model::QUBOModel{T}) where T
    return Vector{𝒱{T}}(model.varvec)
end

function slackvars(model::QUBOModel{T}) where T
    return Vector{𝒱{T}}([v for v in model.varvec if isslack(v)])
end