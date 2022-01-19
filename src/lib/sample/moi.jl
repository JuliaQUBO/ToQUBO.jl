"""
Necessary methods for an AbstractOptimizer according to [1]

    [1] https://jump.dev/JuMP.jl/stable/moi/tutorials/implementing/
"""

# ::: Implement methods for Optimizer :::
function MOI.empty!(annealer::AbstractAnnealer{T}) where {T}
    annealer.Q = Dict{Tuple{Int, Int}, T}()
    annealer.c = zero(T)

    nothing
end

function MOI.is_empty(annealer::AbstractAnnealer{T}) where {T}
    return isempty(annealer.Q) && annealer.c === zero(T)
end

function MOI.optimize!(annealer::AbstractAnnealer)
    if MOI.is_empty(annealer)
        throw(ErrorException("Empty Annealer"))
    end

    anneal!(annealer)
end

# ::: Implement attributes :::
# -*- SolverName (get) -*-
function MOI.get(::AbstractAnnealer, ::MOI.SolverName)
    return "Annealer"
end

# -*- SolverVersion (get) -*-
function MOI.get(::AbstractAnnealer, ::MOI.SolverVersion)
    return "1.0.0"
end

# -*- RawSolver (get) -*-
function MOI.get(::AbstractAnnealer, ::MOI.RawSolver)
    return ""
end

# -*- Name (get, set, supports) -*-
function MOI.get(annealer::AbstractAnnealer, ::MOI.Name)::String
    return annealer.moi_name
end

function MOI.set(annealer::AbstractAnnealer, ::MOI.Name, name::String)
    annealer.moi_name = name
end

MOI.supports(::AbstractAnnealer, ::MOI.Name) = true

# -*- Silent (get, set, supports) -*-
function MOI.get(annealer::AbstractAnnealer, ::MOI.Silent)
    return annealer.moi_silent
end

function MOI.set(annealer::AbstractAnnealer, ::MOI.Silent, silent::Bool)
    annealer.moi_silent = silent
end

MOI.supports(::AbstractAnnealer, ::MOI.Silent) = true

# -*- TimeLimitSec (get, set, supports) -*-
function MOI.get(annealer::AbstractAnnealer, ::MOI.TimeLimitSec)
    return annealer.moi_time_limit_sec
end

function MOI.set(annealer::AbstractAnnealer, ::MOI.TimeLimitSec, Δt::Float64)
    annealer.moi_time_limit_sec = Δt
end

MOI.supports(::AbstractAnnealer, ::MOI.TimeLimitSec) = true

# -*- RawOptimizerAttribute (get, set, supports) -*-
function MOI.get(annealer::AbstractAnnealer, ::MOI.RawOptimizerAttribute)::Any
    return annealer.moi_raw_optimizer_attribute
end

function MOI.set(annealer::AbstractAnnealer, ::MOI.RawOptimizerAttribute, attr::Any)
    annealer.moi_raw_optimizer_attribute = attr
end

MOI.supports(::AbstractAnnealer, ::MOI.RawOptimizerAttribute) = true

# -*- NumberOfThreads (get, set, supports) -*-
function MOI.get(annealer::AbstractAnnealer, ::MOI.NumberOfThreads)::Int
    return annealer.moi_number_of_threads
end

function MOI.set(annealer::AbstractAnnealer, ::MOI.NumberOfThreads, n::Int)
    annealer.moi_number_of_threads = n
end

MOI.supports(::AbstractAnnealer, ::MOI.NumberOfThreads) = true

# -*- Define supports_constraint -*-
MOI.supports_constraint(::AbstractAnnealer, ::Any, ::Any) = false
MOI.supports_constraint(::AbstractAnnealer, ::Type{MOI.VariableIndex}, ::Type{MOI.ZeroOne}) = true