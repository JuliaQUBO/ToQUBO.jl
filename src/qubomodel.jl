# -*- Constants -*-
const MOIObjective = Union{
    MOI.ObjectiveFunctionType,
    MOI.ObjectiveSense,
    MOI.ObjectiveFunction
}

const MOIVariables = Union{
    MOI.ListOfVariableIndices
}

const MOIConstraints = Union{
    MOI.ListOfConstraintTypesPresent
}

"""
"""
mutable struct QUBOModel{T <: Any} <: MOIU.AbstractModelLike{T}

    model::MOIU.Model{T}
    varmap::Dict{VI, VirtualVar}
    virmap::Dict{VI, VirtualVar}
    varvec::Vector{VirtualVar}
    quantum::Bool

    function QUBOModel{T}(; quantum::Bool=false) where T

        model = MOIU.Model{T}()
        varmap = Dict{VI, VirtualVar}()
        virmap = Dict{VI, VirtualVar}()
        varvec = Vector{VirtualVar}()
        return new{T}(model, varmap, virmap, varvec, quantum)
    end
end

function addvar(model::QUBOModel{T}, bits::Int; offset::Int=0, slack::Bool=false)::VirtualVar{VI, T} where T

    vars = MOI.add_variables(model.model, bits)

    v = VirtualVar{VI, T}(bits, vars, tech=:bin, offset=offset, slack=slack)

    for vᵢ in vars
        MOI.add_constraint(model.model, vᵢ, MOI.ZeroOne())
        model.virmap[vᵢ] = v
    end

    push!(model.varvec, v)

    return v
end

"""
"""
function addslack(model::QUBOModel{T}, bits::Int)::VirtualVar{VI, T} where T
    return addvar(model, bits, slack=true)
end

"""
"""
function expand(model::QUBOModel{T}, var::VI, bits::Int; offset::Int=0)::VirtualVar{VI, T} where T
    model.varmap[var] = addvar(model, bits, offset=offset)
    return model.varmap[var]
end

"""
"""
function isqubo(model::QUBOModel)::Bool
    return isqubo(model.model)
end

"""
"""
function vars(model::QUBOModel)::Vector{VirtualVar}
    return model.varvec
end

"""
"""
function slackvars(model::QUBOModel)::Vector{VirtualVar}
    return Vector{VirtualVar}([v for v in model.varvec if v.slack])
end