@doc raw"""


tech:

    :bin - Binary expansion i.e. $ y = \sum_{i = 1}^{n} 2^{i-1} x_i $
    :step - Step expansion i.e. $ y = \sum_{i = 1}^{n} x_i $
"""
struct VirtualVar{S <: Any, T <: Any}

    bits::Int
    vars::Vector{S}
    tech::Symbol
    offset::Int 
    slack::Bool 
    values::Vector{Union{T, Nothing}}

    function VirtualVar{T}(bits::Int, vars::Vector{S}; tech::Symbol=:bin, offset::Int=0, slack::Bool=false) where T
        
        if length(vars) != bits
            error("Virtual Variables need exactly as many keys as encoding bits")
        end

        if !(tech === :bin || tech === :step)
            error("Invalid Expansion technique '$tech'")
        end

        values = [nothing for _ in 1:bits]

        return new{T}(bits, vars, tech, offset, slack, values)
    end
end

function coefficients(v::VirtualVar{S, T})::Vector{Tuple{S, T}} where {S, T}
    if v.tech === :step
        a = convert(T, 1)
        return [(v.vars[i], a) for i in 1:v.bits]
    elseif v.tech === :bin
        a = convert(T, 2)
        return [(v.vars[i], a ^ (i - v.offset - 1)) for i in 1:v.bits]
    end
end

function vars(v::VirtualVar)
    return v.vars
end

"""
"""
mutable struct QUBOModel{T <: Any} <: MOIU.AbstractModelLike{T}

    model::MOIU.Model{T}
    varmap::Dict{VI, VirtualVar}
    quantum::Bool

    function QUBOModel{T}(; quantum::Bool=false) where T
        return new{T}(MOIU.Model{T}(), MOIU.IndexMap(), quantum)
    end
end

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

function MOI.get(model::QUBOModel, attr::MOIObjective)
    return MOI.get(model.model, attr)
end

function MOI.get(model::QUBOModel, attr::MOIVariables)
    return MOI.get(model.model, attr)
end

function MOI.get(model::QUBOModel, attr::MOIConstraints)
    return MOI.get(model.model, attr)
end

function MOI.set(model::QUBOModel, attr::MOI.ObjectiveSense, sense::MOI.OptimizationSense)
    return MOI.set(model.model, attr, sense)
end

function value(model::QUBOModel{T}, v::VirtualVar{T}) where T
    s = convert(T, 0)
    for (cᵢ, vᵢ) in expand(v)
        xᵢ = MOI.get(model, MOI.VariablePrimal(), vᵢ)
        s += cᵢ * xᵢ
    end
    return s
end

function addvar(bits::Int, model::QUBOModel{T}; slack::Bool=false)::VirtualVar{T} where T

    vars = MOI.add_variables(model, bits)

    v = VirtualVar(bits, vars, base=2, offset=0, slack=slack)

    for vᵢ in vars
        MOI.add_constraint(model, vᵢ, MOI.ZeroOne())
        model.varmap[vᵢ] = v
    end

    return v
end

"""
"""
function addslack(model::QUBOModel{T}, c::T)::VirtualVar{T} where T
    bits = ndigits(ceil(Int, log(2, c)), base=2)
    return addvar(model, bits)
end

"""
"""
function addslack(bits::Int, model::QUBOModel{T})::VirtualVar{T} where T
    return addvar(bits, model, slack=true)
end

"""
"""
function expand()

end