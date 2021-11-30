"""
"""

const MOI = MathOptInterface
const MOIU = MOI.Utilities

"""
"""
mutable struct QUBOVar
    # QUBO-specifc
    bits::Int
    offset::Int
    # MOI
    vars::Vector{MOI.VariableIndex}
    function QUBOVar(bits::Int = 1, offset::Int = 0, vars::Vector{MOI.VariableIndex})
        return new(bits, offset, vars)
    end
end

"""
"""
mutable struct Optimizer{T,OT<:MOI.ModelLike} <: MOI.AbstractOptimizer
    # model to be solved
    optimizer::OT # QUBO/MIP Solver

    global_initial_precision::Float64
    # global_target_precision::Float64

    # quadratic solver, usually NLP (has to accpet other conic constraints)

    # quadratic constraint cache
    # quadratic_cache::PureQuadraticModel{T}

    # map between quadratic cache and optimizer data
    # goes from ci{quad,set} to ci{aff,set}
    quad_obj::Union{Nothing,MOI.ScalarQuadraticFunction{T}}
    ci_to_quad_scalar::Dict{CI,MOI.ScalarQuadraticFunction{T}}
    ci_to_quad_vector::Dict{CI,MOI.VectorQuadraticFunction{T}}

    original_variables::Dict{VI,VariableInfo}
    ci_to_var::Dict{CI,VI}

    pair_to_var::Dict{Tuple{VI,VI},VI} # wij variable

    index_cache::Union{Nothing,IndexDataCache{T}}

    has_quad_change::Bool

    fallback_lb::Float64
    fallback_ub::Float64

    allow_soc::Bool

    function Optimizer{T}(optimizer::OT; lb = -Inf, ub = +Inf, global_precision = 1e-4
    ) where {T,OT<:MOI.ModelLike}
        # TODO optimizer must support binary, and affine in less and greater
        return new{T,OT}(
            optimizer,
            global_precision,
            nothing,
            Dict{CI, MOI.ScalarQuadraticFunction{T}}(),
            Dict{CI, MOI.VectorQuadraticFunction{T}}(),
            Dict{VI, VariableInfo}(),
            Dict{CI, VI}(),
            Dict{Tuple{VI, VI}, VI}(),
            nothing,
            false,
            lb,
            ub,
            true,
        )
    end
end

# ------------
# add_variable
# ------------

"""
"""
function MOI.add_variable(model::Optimizer; bits::Int = 1, offset::Int = 0)
    if bits < 1
        error("'bits' must be a positive integer")
    end

    vars = [MOI.add_variable(model.optimizer) for _=1:bits]

    for v in vars
        MOI.add_constraint(model.optimizer, v, MOI.ZeroOne())
    end

    return QUBOVar(bits, offset, vars)
end

# -------------
# add_variables
# -------------

"""
"""
function MOI.add_variables(model::Optimizer, n::Int; bits::Vector{Int}, offset::Vector{Int})
    if length(bits) != n
        error("ERROR")
    end

    if length(offset) != n
        error("ERROR")
    end

    return [MOI.add_variable(model, bits[i], offset[i]) for i = 1:n]
end

"""
"""
function MOI.add_variables(model::Optimizer, n::Int; bits::Int, offset::Vector{Int})
    if length(offset) != n
        error("ERROR")
    end

    return [MOI.add_variable(model, bits, offset[i]) for i = 1:n]
end

"""
"""
function MOI.add_variables(model::Optimizer, n::Int; bits::Vector{Int}, offset::Int)
    if length(bits) != n
        error("ERROR")
    end

    return [MOI.add_variable(model, bits[i], offset) for i = 1:n]
end



"""
"""
function MOI.add_variables(model::Optimizer, n::Int; bits::Int=1, offset::Int=0)
    return [MOI.add_variable(model, bits, offset) for i = 1:n]
end

# ------
# toqubo
# ------

function toqubo(model::MOI.ModelLike)

    con_types = MOI.get(model, MOI.ListOfConstraints())


end