# ::: Variable Management :::

# -*- Add Generic Variable -*-
@doc raw"""

General Interface for variable inclusion on QUBO Models.
"""
function addvar(model::QUBOModel{T}, source::Union{VI, Nothing}, bits::Int; name::Symbol=:x, tech::Symbol=:bin, domain::Tuple{T, T}=(zero(T), one(T))) where T
    # -*- Add MOI Variables to underlying model -*-
    target = MOI.add_variables(model.model, bits)::Vector{VI}

    if source === nothing
        # -*- Slack Variable -*-
        model.slack += 1

        name = Symbol(subscript(model.slack, var=name, par=true))
    elseif name === Symbol()
        name = :v
    end

    # -*- Virtual Variable -*-
    α, β = domain

    v = 𝒱{T}(bits, target, source; tech=tech, name=name, α=α, β=β)

    for vᵢ in target
        # -*- Make Variable Binary -*-
        MOI.add_constraint(model.model, vᵢ, ZO())
        MOI.set(model.model, MOI.VariableName(), vᵢ, subscript(vᵢ, var=name))

        model.target[vᵢ] = v
    end

    push!(model.varvec, v)

    return v
end


# -*- Add Slack Variable -*-
function addslack(model::QUBOModel{T}, bits::Int; name::Symbol=:s, domain::Tuple{T, T}=(zero(T), one(T))) where T
    return addvar(model, nothing, bits, name=name, domain=domain)
end

# -*- Expand: Interpret existing variable through its binary expansion -*-
"""
Real Expansion
"""
function expandℝ!(model::QUBOModel{T}, src::VI, bits::Int; name::Symbol=:x, domain::Tuple{T, T}=(zero(T), one(T))) where T
    model.source[src] = addvar(model, src, bits; name=name, domain=domain, tech=:float)
end



"""
Integer Expansion
"""
function expandℤ!(model::QUBOModel{T}, src::VI, bits::Int; name::Symbol=:x, domain::Tuple{T, T}=(zero(T), one(T))) where T
    model.source[src] = addvar(model, src, bits; name=name, domain=domain, tech=:int)
end



"""
Binary Mirroring
"""
function mirror𝔹!(model::QUBOModel{T}, var::VI; name::Symbol=:x)::𝒱{T} where T
    model.source[src] = addvar(model, src, bits; name=name, tech=:none)
end


function expandℝ(model::QUBOModel{T}, src::VI, bits::Int; name::Symbol=:x, domain::Tuple{T, T}=(zero(T), one(T))) where T
    expandℝ!(model, src, bits, name=name, domain=domain)
    return model.source[src]
end

function expandℤ(model::QUBOModel{T}, src::VI, bits::Int; name::Symbol=:x, domain::Tuple{T, T}=(zero(T), one(T))) where T
    expandℤ!(model, src, bits, name=name, domain=domain)
    return model.source[src]
end

function mirror𝔹(model::QUBOModel{T}, var::VI; name::Symbol=:x)::𝒱{T} where T
    mirror𝔹!(model, var, name=name)
    return model.source[var]
end




function vars(model::QUBOModel{T})::Vector{𝒱{T}} where T
    return Vector{𝒱{T}}(model.varvec)
end

function slackvars(model::QUBOModel{T})::Vector{𝒱{T}} where T
    return Vector{𝒱{T}}([v for v in model.varvec if isslack(v)])
end