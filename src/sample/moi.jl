"""
Necessary methods for an AbstractOptimizer according to [1]

    [1] https://jump.dev/JuMP.jl/stable/moi/tutorials/implementing/
"""

# ::: Implement methods for Optimizer :::
function MOI.empty!(annealer::AbstractAnnealer{V, S, T}) where {V, S, T}
    annealer.Q = Dict{Tuple{V, V}, T}()
    annealer.c = zero(T)

    nothing
end

function MOI.is_empty(annealer::AbstractAnnealer)::Bool
    return isempty(annealer.Q) && annealer.c === zero(T)
end

function MOI.optimize!(annealer::AbstractAnnealer)
    anneal!(annealer)
end

# ::: Implement attributes :::
# -*- SolverName (get) -*-
function MOI.get(annealer::AbstractAnnealer, ::MOI.SolverName)
    return annealer.__solver_name
end

# -*- SolverVersion (get) -*-
function MOI.get(annealer::AbstractAnnealer, ::MOI.SolverVersion)::String
    return annealer.__solver_version
end

# -*- RawSolver (get) -*-
function MOI.get(annealer::AbstractAnnealer, ::MOI.RawSolver)
    return annealer.__raw_solver
end

# -*- Name (get, set, supports) -*-
function MOI.get(annealer::AbstractAnnealer, ::MOI.Name)::String
    return annealer.__name
end

function MOI.set(annealer::AbstractAnnealer, ::MOI.Name, name::String)
    annealer.__name = name
end

MOI.supports(::AbstractAnnealer, ::MOI.Name)::Bool = true

# -*- Silent (get, set, supports) -*-
function MOI.get(annealer::AbstractAnnealer, ::MOI.Silent)::Bool
    return annealer.__silent
end

function MOI.set(annealer::AbstractAnnealer, ::MOI.Silent, silent::Bool)
    annealer.__silent = silent
end

MOI.supports(::AbstractAnnealer, ::MOI.Silent)::Bool = true

# -*- TimeLimitSec (get, set, supports) -*-
function MOI.get(annealer::AbstractAnnealer, ::MOI.TimeLimitSec)::Float64
    return annealer.__time_limit_sec
end

function MOI.set(annealer::AbstractAnnealer, ::MOI.TimeLimitSec, Δt::Float64)
    annealer.__time_limit_sec = Δt
end

MOI.supports(::AbstractAnnealer, ::MOI.TimeLimitSec)::Bool = true

# -*- RawOptimizerAttribute (get, set, supports) -*-
function MOI.get(annealer::AbstractAnnealer, ::MOI.RawOptimizerAttribute)::Any
    return annealer.__raw_optimizer_attribute
end

function MOI.set(annealer::AbstractAnnealer, ::MOI.RawOptimizerAttribute, attr::Any)
    annealer.__raw_optimizer_attribute = attr
end

MOI.supports(::AbstractAnnealer, ::MOI.RawOptimizerAttribute)::Bool = true

# -*- NumberOfThreads (get, set, supports) -*-
function MOI.get(annealer::AbstractAnnealer, ::MOI.NumberOfThreads)::Int
    return annealer.__number_of_threads
end

function MOI.set(annealer::AbstractAnnealer, ::MOI.NumberOfThreads, n::Int)
    annealer.__number_of_threads = n
end

MOI.supports(::AbstractAnnealer, ::MOI.NumberOfThreads)::Bool = true

# -*- Define supports_constraint -*-
MOI.supports_constraint(::AbstractAnnealer, ::Any, ::Any)::Bool = false
MOI.supports_constraint(::AbstractAnnealer, ::Type{MOI.VariableIndex}, ::Type{MOI.ZeroOne})::Bool = true

# -*- The copy_to interface -*-
function MOI.copy_to(annealer::AbstractAnnealer{V, S, T}, model::QUBOModel{T}) where {V, S, T}
    
end